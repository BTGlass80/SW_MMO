extends RefCounted
## Server-authoritative ground combat arena (M1.3).
##
## Owns the shared encounter (a training target) and per-player combat state,
## queues client fire INTENTS, and resolves them in WEG ~5s action windows using
## the existing pure rules: ActionWindowModel (initiative + declarations) and
## GroundCombatModel (the full attack/damage/return-fire resolution), with a
## SERVER-OWNED seed. Output is the existing versioned combat envelope, one per
## shooter, ready to broadcast.
##
## Pure/socket-free so it is headlessly unit-testable. NetworkManager wraps it with
## the fire-intent RPC, a window timer, and the envelope broadcast. This is where
## the seed and every die now live on the server, not the client.

const GroundCombatModel := preload("res://scripts/rules/ground_combat_model.gd")
const ActionWindowModel := preload("res://scripts/rules/action_window_model.gd")
const CombatEventEnvelopeModel := preload("res://scripts/rules/combat_event_envelope_model.gd")
const DISABLED_SEVERITY := 3

var _rules: Object
var _ground := GroundCombatModel.new()
var _windows := ActionWindowModel.new()

var _player_pools: Dictionary = {}    # shared matchup pools (player vs training target)
var _target_profile: Dictionary = {}

var _players: Dictionary = {}         # peer_id -> {state: Dictionary, name: String}
var _target_state: Dictionary = {}    # shared training target {wound_severity, armor_quality_pips, name}
var _intents: Dictionary = {}         # peer_id -> normalized intent for the current window
var _window_index := 0

func _init(rules: Object, combat_data: Dictionary, target_id: String = "b1_training_silhouette") -> void:
	_rules = rules
	_build_pools(combat_data, target_id)
	reset_target()

func _build_pools(combat_data: Dictionary, target_id: String) -> void:
	var trainee: Dictionary = combat_data.get("range_trainee", {})
	var weapons: Dictionary = combat_data.get("weapons", {})
	var armors: Dictionary = combat_data.get("armors", {})
	var targets: Dictionary = combat_data.get("targets", {})
	var target: Dictionary = targets.get(target_id, {})
	var trainee_weapon: Dictionary = weapons.get(String(trainee.get("weapon", "")), {})
	var target_weapon: Dictionary = weapons.get(String(target.get("weapon", "")), {})
	_target_profile = target
	_player_pools = {
		"attacker_pool": _rules.parse_pool(String(trainee.get("blaster", "4D"))),
		"damage_pool": _rules.parse_pool(String(trainee_weapon.get("damage", "4D"))),
		"player_dodge_pool": _rules.parse_pool(String(trainee.get("dodge", "3D"))),
		"player_soak_pool": _rules.parse_pool(String(trainee.get("soak", "3D"))),
		"player_armor": armors.get(String(trainee.get("armor", "")), {}),
		"target_soak_pool": _rules.parse_pool(String(target.get("soak", "2D"))),
		"target_attack_pool": _rules.parse_pool(String(target.get("blaster", "3D"))),
		"target_damage_pool": _rules.parse_pool(String(target_weapon.get("damage", "3D"))),
		"target_armor": {},
		"attacker_scale": String(trainee.get("scale", "character")),
		"target_scale": String(target.get("scale", "character")),
	}

func reset_target() -> void:
	_target_state = {
		"wound_severity": 0,
		"armor_quality_pips": 0,
		"name": String(_target_profile.get("name", "B1 Training Remote")),
	}
	_window_index = 0

func register_player(peer_id: int, display_name: String = "") -> void:
	_players[peer_id] = {
		"state": _ground.initial_state(),
		"name": display_name if display_name != "" else "Spacer-%d" % peer_id,
	}

func remove_player(peer_id: int) -> void:
	_players.erase(peer_id)
	_intents.erase(peer_id)

func has_player(peer_id: int) -> bool:
	return _players.has(peer_id)

func player_state(peer_id: int) -> Dictionary:
	return (_players.get(peer_id, {}) as Dictionary).get("state", {})

## Update a player's display name (used as shooter_name in combat envelopes).
func set_player_name(peer_id: int, display_name: String) -> void:
	if _players.has(peer_id) and display_name.strip_edges() != "":
		(_players[peer_id] as Dictionary)["name"] = display_name

## Apply a restored combat state (from persistence) onto a registered player.
func set_player_combat(peer_id: int, combat_state: Dictionary) -> void:
	if not _players.has(peer_id):
		return
	var record: Dictionary = _players[peer_id]
	var st: Dictionary = record.get("state", {})
	for key in ["player_character_points", "player_force_points", "player_wound_severity", "player_armor_quality_pips"]:
		if combat_state.has(key):
			st[key] = int(combat_state[key])
	record["state"] = st

func target_state() -> Dictionary:
	return _target_state.duplicate(true)

func target_disabled() -> bool:
	return int(_target_state.get("wound_severity", 0)) >= DISABLED_SEVERITY

## Record a player's fire intent for the current window. Clamped server-side.
func submit_fire_intent(peer_id: int, intent: Dictionary) -> void:
	if not _players.has(peer_id):
		return
	_intents[peer_id] = {
		"aim": clampi(int(intent.get("aim", 0)), 0, 3),
		"cover": clampi(int(intent.get("cover", 0)), 0, 4),
		"cp": clampi(int(intent.get("cp", 0)), 0, 5),
		"fp": bool(intent.get("fp", false)),
	}

func pending_intent_count() -> int:
	return _intents.size()

## Resolve every queued intent for one action window, in WEG initiative order,
## against the shared target. Returns {window, envelopes:[...], target_state,
## target_disabled}. seed_base is the server-owned per-window seed.
func resolve_window(seed_base: int) -> Dictionary:
	var envelopes: Array = []
	if _intents.is_empty():
		return {"window": _window_index, "envelopes": envelopes, "target_state": target_state(), "target_disabled": target_disabled()}

	var shooters: Array = _intents.keys()
	var order := _initiative_order(shooters, seed_base)
	var window_state := _build_resolution_window(order)

	var i := 0
	for peer_id in order:
		var record: Dictionary = _players[peer_id]
		var intent: Dictionary = _intents[peer_id]
		record["state"] = _apply_intent(record["state"], intent)
		var exchange_seed := seed_base + (i + 1) * 7919
		var window_for_shooter := window_state.duplicate(true)
		window_for_shooter["active_ids"] = [str(peer_id)]
		window_for_shooter["declaration_count"] = 1
		var result: Dictionary = _ground.resolve_exchange_with_action_window(
			_rules,
			record["state"],
			_target_state,
			_player_pools,
			float(_target_profile.get("distance", 12.0)),
			int(_target_profile.get("cover_level", 0)),
			window_for_shooter,
			exchange_seed
		)
		record["state"] = result.get("state", record["state"])
		_target_state = result.get("target_state", _target_state)
		var envelope: Dictionary = CombatEventEnvelopeModel.envelope_for_result(result, "ground_range", "local")
		envelope["shooter_id"] = peer_id
		envelope["shooter_name"] = String(record["name"])
		envelope["target_name"] = String(_target_state.get("name", ""))
		envelope["target_wound_severity"] = int(_target_state.get("wound_severity", 0))
		envelopes.append(envelope)
		i += 1

	_intents.clear()
	_window_index += 1
	return {
		"window": _window_index,
		"envelopes": envelopes,
		"target_state": target_state(),
		"target_disabled": target_disabled(),
	}

func _apply_intent(state: Dictionary, intent: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next["aim_bonus_dice"] = clampi(int(intent.get("aim", 0)), 0, 3)
	next["player_cover_level"] = clampi(int(intent.get("cover", 0)), 0, 4)
	next["player_defense"] = GroundCombatModel.DEFENSE_NONE
	next = _ground.queue_attack_cp(next, int(intent.get("cp", 0)))
	if bool(intent.get("fp", false)):
		next = _ground.activate_force_point(next)
	return next

func _initiative_order(shooters: Array, seed_base: int) -> Array:
	var participants: Array = []
	for peer_id in shooters:
		participants.append({
			"id": str(peer_id),
			"name": String((_players[peer_id] as Dictionary).get("name", "")),
			"side": "player",
			"perception_pool": {"dice": 3, "pips": 0},
			"active": true,
		})
	var init_result: Dictionary = _windows.resolve_initiative(_rules, _windows.initial_state(), participants, seed_base)
	var ordered_ids: Array = init_result.get("initiative_order", [])
	var order: Array = []
	for id_string in ordered_ids:
		for peer_id in shooters:
			if str(peer_id) == String(id_string):
				order.append(peer_id)
	# Any shooter not represented in the initiative order still resolves last.
	for peer_id in shooters:
		if not order.has(peer_id):
			order.append(peer_id)
	return order

func _build_resolution_window(order: Array) -> Dictionary:
	var state: Dictionary = _windows.initial_state()
	var active_ids: Array = []
	for peer_id in order:
		active_ids.append(str(peer_id))
		state = _windows.declare_actions(state, str(peer_id), ["attack"])["state"]
	state = _windows.begin_resolution(state)
	state["ready"] = _windows.ready_for_resolution(state, active_ids)
	state["active_ids"] = active_ids
	state["declaration_count"] = active_ids.size()
	state["errors"] = []
	return state
