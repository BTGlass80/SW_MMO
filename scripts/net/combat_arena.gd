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
const DerivedStats := preload("res://scripts/rules/derived_stats_model.gd")
const DISABLED_SEVERITY := 3
# DIV-0016: non-lethal sparring ceiling. The shared training target's return fire can stun(1) or
# wound(2) a player but NEVER incapacitate(3+) — keeping them out of the owner-gated death/respawn
# band (DIV-0006) and inside the healable, self-recoverable tiers (DIV-0012/0013).
const SPARRING_MAX_SEVERITY := 2

var _rules: Object
var _ground := GroundCombatModel.new()
var _windows := ActionWindowModel.new()
var _derived := DerivedStats.new()

var _target_pools: Dictionary = {}         # shared target side (from combat data)
var _default_player_pools: Dictionary = {} # fallback player side (trainee), used when no sheet
var _default_weapon_damage := "4D"         # fallback blaster damage when a player has no equipped weapon
var _weapons: Dictionary = {}              # weapon catalog (key -> {damage, ...})
var _armors: Dictionary = {}               # armor catalog (key -> {protection_*, coverage})
var _target_profile: Dictionary = {}

var _players: Dictionary = {}         # peer_id -> {state: Dictionary, name: String}
var _target_state: Dictionary = {}    # shared training target {wound_severity, armor_quality_pips, name}
var _intents: Dictionary = {}         # peer_id -> normalized intent for the current window
var _window_index := 0
# S6 / DIV-0017: per-player LETHAL flag (skip the DIV-0016 sparring clamp so return fire deals REAL,
# uncapped damage) + per-player HOSTILE TARGET assignment (which target this player fights instead of
# the shared training dummy). Both default OFF/absent, so a player with neither set is byte-identical
# to the pre-S6 sparring arena. The network layer sets these per ZONE (lawless/contested = lethal) and
# per active spawn (creature = the hostile target).
var _player_lethal: Dictionary = {}   # peer_id -> true: lift the sparring cap for this player
var _player_target: Dictionary = {}   # peer_id -> hostile target_key ("" / absent = the shared dummy)
var _hostile_targets: Dictionary = {} # target_key -> {state, pools(target_*), profile{distance,cover_level,name}, spawn}

func _init(rules: Object, combat_data: Dictionary, target_id: String = "b1_training_silhouette", weapon_catalog: Dictionary = {}, armor_catalog: Dictionary = {}) -> void:
	_rules = rules
	_weapons = weapon_catalog
	_armors = armor_catalog
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
	_default_weapon_damage = String(trainee_weapon.get("damage", "4D"))
	# Shared target side (every player fights the same training target for now).
	_target_pools = {
		"target_soak_pool": _rules.parse_pool(String(target.get("soak", "2D"))),
		"target_attack_pool": _rules.parse_pool(String(target.get("blaster", "3D"))),
		"target_damage_pool": _rules.parse_pool(String(target_weapon.get("damage", "3D"))),
		"target_armor": {},
		"target_scale": String(target.get("scale", "character")),
		# DIV-0016: a sparring target (stun_return_fire:false) returns fire as a REAL wound (capped
		# at SPARRING_MAX_SEVERITY in resolve_window); every other target defaults to pure WEG stun.
		"target_stun_mode": bool(target.get("stun_return_fire", true)),
	}
	# Fallback player side (the trainee) used when a player has no character sheet.
	_default_player_pools = {
		"attacker_pool": _rules.parse_pool(String(trainee.get("blaster", "4D"))),
		"damage_pool": _rules.parse_pool(String(trainee_weapon.get("damage", "4D"))),
		"player_dodge_pool": _rules.parse_pool(String(trainee.get("dodge", "3D"))),
		"player_soak_pool": _rules.parse_pool(String(trainee.get("soak", "3D"))),
		# WEG: Perception drives combat initiative. No-sheet fallback keeps the old fixed 3D.
		"perception_pool": _rules.parse_pool(String(trainee.get("perception", "3D"))),
		"player_armor": armors.get(String(trainee.get("armor", "")), {}),
		"attacker_scale": String(trainee.get("scale", "character")),
	}

func reset_target() -> void:
	_target_state = {
		"wound_severity": 0,
		"armor_quality_pips": 0,
		"name": String(_target_profile.get("name", "B1 Training Remote")),
	}
	_window_index = 0

func register_player(peer_id: int, display_name: String = "", sheet: Dictionary = {}) -> void:
	_players[peer_id] = {
		"state": _ground.initial_state(),
		"name": display_name if display_name != "" else "Spacer-%d" % peer_id,
		"pools": _pools_from_sheet(sheet) if not sheet.is_empty() else _default_player_pools.duplicate(true),
	}

## Rebuild a registered player's combat pools from their character sheet (WEG R&E:
## attack = governing attribute + skill bonus; soak = Strength). Damage stays a default
## starter weapon until an inventory/equipment system exists.
func set_player_sheet(peer_id: int, sheet: Dictionary) -> void:
	if not _players.has(peer_id) or sheet.is_empty():
		return
	(_players[peer_id] as Dictionary)["pools"] = _pools_from_sheet(sheet)

func _pools_from_sheet(sheet: Dictionary) -> Dictionary:
	var attrs: Dictionary = sheet.get("attributes", {})
	var skills: Dictionary = sheet.get("skills", {})
	var dex := String(attrs.get("dexterity", "2D"))
	var dodge_bonus := String(skills.get("dodge", "0D"))
	# Equipped weapon damage + armor profile (fallbacks when no equipment / catalog).
	var equipment: Dictionary = sheet.get("equipment", {})
	var weapon: Dictionary = _weapons.get(String(equipment.get("weapon", "")), {})
	var armor: Dictionary = _armors.get(String(equipment.get("armor", "")), {})
	# Attack uses the EQUIPPED weapon's OWN skill (blaster / melee_combat / bowcaster / …), not
	# always blaster; untrained -> just the governing attribute (DEX).
	var weapon_skill := String(weapon.get("skill", "blaster"))
	var attack_bonus := String(skills.get(weapon_skill, "0D"))
	# Damage: a "STR+ND" melee weapon resolves as STR + the weapon bonus via the (now-wired)
	# derived-stats melee model; a ranged weapon's damage is a flat pool. This fixes melee
	# weapons dealing 0D — parse_pool can't read "STR+3D" (int("STR+3")==0).
	var str_pool: Dictionary = _rules.parse_pool(String(attrs.get("strength", "2D")))
	var damage_text := String(weapon.get("damage", _default_weapon_damage))
	var damage_pool: Dictionary
	# Force-Point doubling of the DAMAGE pool (WEG Guide_01): a ranged weapon doubles its whole flat
	# pool; a MELEE weapon (STR + bonus) doubles only the STR portion (not the weapon bonus), i.e.
	# 2*STR + bonus = damage_pool + STR. Precomputed here so the rules model can pick the right one.
	var damage_pool_fp: Dictionary
	if damage_text.to_upper().begins_with("STR"):
		var bonus := damage_text.substr(3)
		if bonus.begins_with("+"):
			bonus = bonus.substr(1)
		damage_pool = _derived.melee_damage_pool(_rules, sheet, bonus)
		damage_pool_fp = _rules.add_pools(damage_pool, str_pool)  # double STR only
	else:
		damage_pool = _rules.parse_pool(damage_text)
		damage_pool_fp = _rules.apply_force_point(damage_pool)     # double the flat ranged pool
	return {
		"attacker_pool": _rules.add_pools(_rules.parse_pool(dex), _rules.parse_pool(attack_bonus)),
		"damage_pool": damage_pool,
		"damage_pool_fp": damage_pool_fp,
		"player_dodge_pool": _rules.add_pools(_rules.parse_pool(dex), _rules.parse_pool(dodge_bonus)),
		"player_soak_pool": _rules.parse_pool(String(attrs.get("strength", "2D"))),
		# WEG: combat initiative = a Perception roll, so the character's own Perception drives who
		# acts first (previously a hardcoded 3D for everyone — the attribute was ignored).
		"perception_pool": _rules.parse_pool(String(attrs.get("perception", "2D"))),
		"player_armor": armor,
		"attacker_scale": "character",
	}

## The player's current attack dice pool as a string (for tests / inspection).
func attacker_pool_text(peer_id: int) -> String:
	var pools: Dictionary = (_players.get(peer_id, {}) as Dictionary).get("pools", {})
	return String(_rules.pool_to_string(pools.get("attacker_pool", {"dice": 0, "pips": 0})))

## The player's current weapon damage dice pool as a string (for tests / inspection).
func damage_pool_text(peer_id: int) -> String:
	var pools: Dictionary = (_players.get(peer_id, {}) as Dictionary).get("pools", {})
	return String(_rules.pool_to_string(pools.get("damage_pool", {"dice": 0, "pips": 0})))

## The player's Perception (initiative) dice pool as a string (for tests / inspection).
func perception_pool_text(peer_id: int) -> String:
	var pools: Dictionary = (_players.get(peer_id, {}) as Dictionary).get("pools", {})
	return String(_rules.pool_to_string(pools.get("perception_pool", {"dice": 0, "pips": 0})))

## The player's Force-Point-doubled damage pool as a string (F55; for tests / inspection).
func damage_pool_fp_text(peer_id: int) -> String:
	var pools: Dictionary = (_players.get(peer_id, {}) as Dictionary).get("pools", {})
	return String(_rules.pool_to_string(pools.get("damage_pool_fp", {"dice": 0, "pips": 0})))

func remove_player(peer_id: int) -> void:
	_players.erase(peer_id)
	_intents.erase(peer_id)
	_player_lethal.erase(peer_id)
	_player_target.erase(peer_id)

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

# --- S6 / DIV-0017: lethal flag + hostile targets ---
## Lift (or restore) the DIV-0016 sparring clamp for one player. lethal=true => return fire deals REAL
## uncapped damage (lawless/contested zones). Default false = the sparring cap holds.
func set_player_lethal(peer_id: int, lethal: bool) -> void:
	if lethal:
		_player_lethal[peer_id] = true
	else:
		_player_lethal.erase(peer_id)

func is_player_lethal(peer_id: int) -> bool:
	return bool(_player_lethal.get(peer_id, false))

## Register a hostile creature as a lethal target the arena can resolve against. `pools` is the
## target_* pool shape (hostile_npc_model.attack_pools_from_creature); `profile` carries
## {distance, cover_level, name}; `spawn` is the originating creature_spawn_model roll (kept for loot).
func register_hostile_target(target_key: String, pools: Dictionary, profile: Dictionary, spawn: Dictionary = {}) -> void:
	if target_key == "":
		return
	_hostile_targets[target_key] = {
		"state": {"wound_severity": 0, "armor_quality_pips": 0, "name": String(profile.get("name", target_key))},
		"pools": pools.duplicate(true),
		"profile": profile.duplicate(true),
		"spawn": spawn.duplicate(true),
	}

func has_hostile_target(target_key: String) -> bool:
	return _hostile_targets.has(target_key)

func hostile_target_keys() -> Array:
	return _hostile_targets.keys()

func hostile_target_state(target_key: String) -> Dictionary:
	return ((_hostile_targets.get(target_key, {}) as Dictionary).get("state", {}) as Dictionary).duplicate(true)

func hostile_target_spawn(target_key: String) -> Dictionary:
	return ((_hostile_targets.get(target_key, {}) as Dictionary).get("spawn", {}) as Dictionary).duplicate(true)

func hostile_target_disabled(target_key: String) -> bool:
	return int(((_hostile_targets.get(target_key, {}) as Dictionary).get("state", {}) as Dictionary).get("wound_severity", 0)) >= DISABLED_SEVERITY

## Despawn a hostile target; any player still pointed at it falls back to the shared training dummy.
func remove_hostile_target(target_key: String) -> void:
	_hostile_targets.erase(target_key)
	for pid in _player_target.keys():
		if String(_player_target[pid]) == target_key:
			_player_target.erase(pid)

## Point a player at a hostile target (must be registered) or, with "", back to the shared dummy.
func set_player_target(peer_id: int, target_key: String) -> void:
	if target_key != "" and _hostile_targets.has(target_key):
		_player_target[peer_id] = target_key
	else:
		_player_target.erase(peer_id)

func player_target_key(peer_id: int) -> String:
	return String(_player_target.get(peer_id, ""))

## Record a player's fire intent for the current window. Clamped server-side.
func submit_fire_intent(peer_id: int, intent: Dictionary) -> void:
	if not _players.has(peer_id):
		return
	# WEG: an INCAPACITATED / mortally wounded / dead character is OUT and CANNOT act (the
	# wound ladder models their penalty as 0D precisely because they don't act, so the
	# penalty alone wouldn't stop them). Drop the intent — they can't fire until healed.
	if int(((_players[peer_id] as Dictionary).get("state", {}) as Dictionary).get("player_wound_severity", 0)) >= DISABLED_SEVERITY:
		return
	_intents[peer_id] = {
		"aim": clampi(int(intent.get("aim", 0)), 0, 3),
		"cover": clampi(int(intent.get("cover", 0)), 0, 4),
		"cp": clampi(int(intent.get("cp", 0)), 0, 5),
		"fp": bool(intent.get("fp", false)),
		"full_dodge": bool(intent.get("full_dodge", false)),  # F51: defensive stance — forgo the attack, max dodge
		"dodge": bool(intent.get("dodge", false)),            # F52: active dodge WHILE attacking (-1D multi-action)
	}

func pending_intent_count() -> int:
	return _intents.size()

## Drop a player's queued intent for the current window WITHOUT resolving it. Used when the player
## leaves the zone mid-window: a WEG action window pins you in place, so leaving cancels the queued
## shot rather than letting it resolve (and mis-credit its envelope + faction/territory influence)
## in a zone the player traveled to. No-op if the player has no pending intent.
func clear_intent(peer_id: int) -> void:
	_intents.erase(peer_id)

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
		# S6/DIV-0017: which target does THIS shooter fight? A registered hostile creature (assigned by
		# the network layer per zone/spawn) if present, else the shared training dummy. `lethal` gates
		# the DIV-0016 sparring clamp: true (lawless/contested) => REAL uncapped return fire.
		var target_key := String(_player_target.get(peer_id, ""))
		var use_hostile := target_key != "" and _hostile_targets.has(target_key)
		var tstate: Dictionary
		var tpools: Dictionary
		var tprofile: Dictionary
		if use_hostile:
			var hrec: Dictionary = _hostile_targets[target_key]
			tstate = hrec["state"]
			tpools = hrec["pools"]
			tprofile = hrec["profile"]
		else:
			tstate = _target_state
			tpools = _target_pools
			tprofile = _target_profile
		var lethal := bool(_player_lethal.get(peer_id, false))
		# This shooter's own pools (from their sheet) + the resolved target side.
		var pools: Dictionary = (record.get("pools", _default_player_pools) as Dictionary).duplicate(true)
		pools.merge(tpools)
		var result: Dictionary = _ground.resolve_exchange_with_action_window(
			_rules,
			record["state"],
			tstate,
			pools,
			float(tprofile.get("distance", 12.0)),
			int(tprofile.get("cover_level", 0)),
			window_for_shooter,
			exchange_seed
		)
		# DIV-0016: clamp the player's resulting wound to the non-lethal sparring ceiling at the SINGLE
		# server-side chokepoint — UNLESS this is a lethal encounter (DIV-0017: hostile PvE in a
		# lawless/contested zone), where return fire deals real, uncapped damage up to 'dead'.
		# record["state"] (player_state(peer)) is the sole accessor every downstream surface reads —
		# snapshot you.wound (F9) + per-player nameplate wound (F17) + persistence.
		var next_pstate: Dictionary = result.get("state", record["state"])
		if not lethal:
			next_pstate["player_wound_severity"] = mini(int(next_pstate.get("player_wound_severity", 0)), SPARRING_MAX_SEVERITY)
		record["state"] = next_pstate
		# Write the resolved target's new state back to the RIGHT target (the hostile record or the
		# shared dummy), so each hostile encounter accumulates independently.
		var new_tstate: Dictionary = result.get("target_state", tstate)
		if use_hostile:
			(_hostile_targets[target_key] as Dictionary)["state"] = new_tstate
		else:
			_target_state = new_tstate
		var envelope: Dictionary = CombatEventEnvelopeModel.envelope_for_result(result, "ground_range", "local")
		envelope["shooter_id"] = peer_id
		envelope["shooter_name"] = String(record["name"])
		envelope["target_name"] = String(new_tstate.get("name", ""))
		envelope["target_wound_severity"] = int(new_tstate.get("wound_severity", 0))
		envelope["target_key"] = target_key  # "" = the shared training dummy
		envelope["target_disabled"] = int(new_tstate.get("wound_severity", 0)) >= DISABLED_SEVERITY
		envelope["lethal"] = lethal
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
	# Defense stance (WEG): full_dodge = forgo the attack for max dodge (F51); dodge = attack AND
	# actively dodge at a -1D multi-action penalty (F52); else none. full_dodge wins if both set.
	next["player_defense"] = (
		GroundCombatModel.DEFENSE_FULL_DODGE if bool(intent.get("full_dodge", false))
		else GroundCombatModel.DEFENSE_DODGE if bool(intent.get("dodge", false))
		else GroundCombatModel.DEFENSE_NONE
	)
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
			# WEG: initiative = the character's own Perception roll (not a fixed 3D for all).
			"perception_pool": ((_players[peer_id] as Dictionary).get("pools", {}) as Dictionary).get("perception_pool", {"dice": 3, "pips": 0}),
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
