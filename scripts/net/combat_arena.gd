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
const PvpRules := preload("res://scripts/rules/pvp_rules_model.gd")  # DIV-0019: player-target remap
const WoundLadder := preload("res://scripts/rules/wound_ladder_model.gd")  # G2: cumulative WEG wound escalation
const CreatureSpecialAttack := preload("res://scripts/rules/creature_special_attack_model.gd")  # DIV-0024: venom/restraint riders
const ArmorConditionModel := preload("res://scripts/rules/armor_condition_model.gd")  # DIV-0024: restraint crush soak (armor applies)
const PVP_DISTANCE := 12.0  # DIV-0019: nominal inter-player range (positional range is a follow-up)
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
var _hostile_targets: Dictionary = {} # target_key -> {state, pools(target_*), profile{distance,cover_level,name}, spawn, rider}
# DIV-0024: monotonic combat-window counter for venom/restraint STATUS timing. Unlike _window_index (which
# only advances on windows that HAD queued intents, via resolve_window), this advances EVERY window because
# tick_status_effects is called unconditionally by the net layer — so a poison schedule's absolute rounds
# count REAL elapsed windows (honoring onset) even across idle windows where no one fired.
var _status_window := 0

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
	for key in ["player_character_points", "player_force_points", "player_wound_severity", "player_armor_quality_pips", "player_cover_level"]:
		if combat_state.has(key):
			st[key] = int(combat_state[key])
	# G2: carry the wound LEVEL string (cross-window source of truth for cumulative escalation; the int
	# collapses wounded/wounded_twice). Seed from the record's wound_state when provided, else derive.
	if combat_state.has("player_wound_level"):
		st["player_wound_level"] = String(combat_state["player_wound_level"])
	elif combat_state.has("player_wound_severity"):
		st["player_wound_level"] = WoundLadder.level_for_severity(int(combat_state["player_wound_severity"]))
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

## Register a hostile creature as a lethal target the arena can resolve against. `pools` is the
## target_* pool shape (hostile_npc_model.attack_pools_from_creature); `profile` carries
## {distance, cover_level, name}; `spawn` is the originating creature_spawn_model roll (kept for loot).
## `rider` (DIV-0024, optional, default {}) is the pre-baked CreatureSpecialAttackModel.describe_spawn bundle
## ({has_special_attack, poison, poison_schedule, restraint}) for this creature. The net layer computes it
## with a SERVER-owned seed at spawn; the arena seeds it onto a victim on a landed hit. Deep-copied so a
## per-victim status never aliases the shared bundle (matches the model's deep-copy discipline).
func register_hostile_target(target_key: String, pools: Dictionary, profile: Dictionary, spawn: Dictionary = {}, rider: Dictionary = {}) -> void:
	if target_key == "":
		return
	_hostile_targets[target_key] = {
		"state": {"wound_severity": 0, "armor_quality_pips": 0, "name": String(profile.get("name", target_key))},
		"pools": pools.duplicate(true),
		"profile": profile.duplicate(true),
		"spawn": spawn.duplicate(true),
		"rider": rider.duplicate(true),
	}

func has_hostile_target(target_key: String) -> bool:
	return _hostile_targets.has(target_key)

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
		"target_peer": maxi(int(intent.get("target_peer", 0)), 0),  # DIV-0019: 0 = shared dummy/creature (unchanged path)
	}

func pending_intent_count() -> int:
	return _intents.size()

## G4 (DIV-0017): the peer_ids that queued a fire intent THIS window (the provoked shooters). The net
## layer captures this BEFORE resolve_window clears intents so its unprovoked hostile-fire pass can
## EXCLUDE anyone who fired — each player takes exactly ONE combat path per window (their own return-fire
## exchange OR an unprovoked incoming hit, never both).
func pending_shooter_ids() -> Array:
	return _intents.keys()

## Drop a player's queued intent for the current window WITHOUT resolving it. Used when the player
## leaves the zone mid-window: a WEG action window pins you in place, so leaving cancels the queued
## shot rather than letting it resolve (and mis-credit its envelope + faction/territory influence)
## in a zone the player traveled to. No-op if the player has no pending intent.
func clear_intent(peer_id: int) -> void:
	_intents.erase(peer_id)

## DIV-0019: {shooter_peer: target_peer} for every queued intent naming a player (target_peer != 0).
## The net layer re-validates each pair (same-zone + still-lawless) into a {shooter: true} auth map.
func pending_pvp_targets() -> Dictionary:
	var out := {}
	for pid in _intents:
		var t := int((_intents[pid] as Dictionary).get("target_peer", 0))
		if t != 0:
			out[pid] = t
	return out

## DIV-0019: drop every queued intent aimed AT peer_id (mirror of clear_intent). Called when a
## targeted player leaves the zone or disconnects mid-window so a shot at them can't resolve.
func clear_intents_targeting(peer_id: int) -> void:
	for pid in _intents.keys():
		if int((_intents[pid] as Dictionary).get("target_peer", 0)) == peer_id:
			_intents.erase(pid)

## Resolve every queued intent for one action window, in WEG initiative order. Each shooter fights
## their assigned target: a PvP player target (intent.target_peer, authorized in `pvp_gate` — a
## {shooter_peer: true} map the net layer builds from live zone/security state), else their hostile
## creature, else the shared training dummy. Returns {window, envelopes, target_state, target_disabled,
## casualties}. seed_base is the server-owned per-window seed.
func resolve_window(seed_base: int, pvp_gate: Dictionary = {}) -> Dictionary:
	var envelopes: Array = []
	var casualties := {}  # DIV-0019: target_peer -> {peer, severity, killer} for players taken out this window
	if _intents.is_empty():
		return {"window": _window_index, "envelopes": envelopes, "target_state": target_state(), "target_disabled": target_disabled(), "casualties": []}

	var shooters: Array = _intents.keys()
	var order := _initiative_order(shooters, seed_base)
	var window_state := _build_resolution_window(order)

	var i := 0
	for peer_id in order:
		var record: Dictionary = _players[peer_id]
		# DIV-0019 (WEG + clamp-heal guard): a shooter dropped to disabled by a higher-initiative
		# opponent EARLIER this window is OUT and cannot act. Hoisted ABOVE the target branch (before
		# _apply_intent) so it also defuses the sparring-clamp-heal exploit for a dummy-firing victim.
		var prior_severity := int((record["state"] as Dictionary).get("player_wound_severity", 0))
		if prior_severity >= DISABLED_SEVERITY:
			i += 1
			continue
		var intent: Dictionary = _intents[peer_id]
		var target_peer := int(intent.get("target_peer", 0))
		var is_pvp: bool = target_peer != 0 and target_peer != peer_id and bool(pvp_gate.get(peer_id, false)) and _players.has(target_peer)
		# A named PvP target that FAILED the resolve-time gate (fled / zone-flipped / gone): DROP the
		# shot. It never falls through to the shared dummy.
		if target_peer != 0 and not is_pvp:
			i += 1
			continue
		record["state"] = _apply_intent(record["state"], intent)
		var exchange_seed := seed_base + (i + 1) * 7919
		var window_for_shooter := window_state.duplicate(true)
		window_for_shooter["active_ids"] = [str(peer_id)]
		window_for_shooter["declaration_count"] = 1
		# Which target does THIS shooter fight? A PvP player (DIV-0019, authorized) > a hostile creature
		# (S6/DIV-0017) > the shared training dummy. `lethal` gates the DIV-0016 sparring clamp.
		var target_key := ""
		var tstate: Dictionary
		var tpools: Dictionary
		var distance := PVP_DISTANCE
		var cover := 0
		var lethal := false
		# G3 (DIV-0019): the DEFENDER's declared reaction dodge stance, passed into resolve_exchange so a
		# PvP victim's dodge/full_dodge actually raises the attacker's difficulty (was absent: shot got {}).
		var defender_defense_stance := GroundCombatModel.DEFENSE_NONE
		if is_pvp:
			var def_record: Dictionary = _players[target_peer]
			tstate = PvpRules.defender_target_state(def_record["state"], String(def_record["name"]))
			tpools = PvpRules.defender_target_pools(def_record["pools"])
			# G3: read the defender's cover from PERSISTENT state (a maintained crouch decays to quarter
			# cover and lingers across windows), falling back to THIS window's queued intent when the
			# persistent value is 0 (the defender may only just have declared it and not yet had their
			# own _apply_intent run if they act later in initiative order).
			var def_state: Dictionary = def_record["state"]
			var def_intent: Dictionary = _intents.get(target_peer, {})
			var persistent_cover := int(def_state.get("player_cover_level", 0))
			cover = clampi(persistent_cover if persistent_cover > 0 else int(def_intent.get("cover", 0)), 0, 4)
			# G3: the defender's DECLARED reaction dodge (from their queued intent) — full_dodge wins if both.
			defender_defense_stance = (
				GroundCombatModel.DEFENSE_FULL_DODGE if bool(def_intent.get("full_dodge", false))
				else GroundCombatModel.DEFENSE_DODGE if bool(def_intent.get("dodge", false))
				else GroundCombatModel.DEFENSE_NONE
			)
			lethal = true  # PvP is always lethal — the sparring clamp is skipped
		else:
			target_key = String(_player_target.get(peer_id, ""))
			var use_hostile := target_key != "" and _hostile_targets.has(target_key)
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
			distance = float(tprofile.get("distance", PVP_DISTANCE))
			cover = int(tprofile.get("cover_level", 0))
			lethal = bool(_player_lethal.get(peer_id, false))
		# This shooter's own pools (from their sheet) + the resolved target side.
		var pools: Dictionary = (record.get("pools", _default_player_pools) as Dictionary).duplicate(true)
		pools.merge(tpools)
		if is_pvp:
			# DIV-0019 (P2 flag): a DECLARED duel (defender also queued an intent) resolves as one attack
			# each — suppress the dummy-style auto return-fire here; a passive victim (no intent) still
			# reaction-fires once. Prevents double-counting each side's offense per window.
			pools["suppress_return_fire"] = _intents.has(target_peer)
		var result: Dictionary = _ground.resolve_exchange_with_action_window(
			_rules, record["state"], tstate, pools, distance, cover, window_for_shooter, exchange_seed, defender_defense_stance)
		# DIV-0016 clamp — UNLESS lethal (DIV-0017 hostile PvE / DIV-0019 PvP). Floor-aware: the cap can
		# only LOWER toward SPARRING_MAX, never below where the player already was, so a PvP-wounded
		# player who also fired the dummy is never healed by the clamp (the must-fix).
		var next_pstate: Dictionary = result.get("state", record["state"])
		if not lethal:
			next_pstate["player_wound_severity"] = mini(int(next_pstate.get("player_wound_severity", 0)), maxi(SPARRING_MAX_SEVERITY, prior_severity))
		# HIGH (audit 2026-07-03): resolve_exchange advances the shooter's player_wound_severity from its OWN
		# return-fire wound but NOT player_wound_level. The stale level then corrupts persistence (apply_combat
		# prefers the level string -> a wound saves as "healthy" and is erased on relog), the PvP escalate base
		# (a downed player revived by any potshot), and the downed reconstruction on relogin. Keep them coherent,
		# advance-only (never de-escalate — the sparring clamp may LOWER severity). Mirrors resolve_hostile_aggression.
		var shooter_sev := int(next_pstate.get("player_wound_severity", 0))
		if shooter_sev > prior_severity:
			next_pstate["player_wound_level"] = WoundLadder.level_for_severity(shooter_sev)
		record["state"] = next_pstate
		# DIV-0024: the COMMON venom/restraint path — a player who provoked a hostile takes its RETURN FIRE;
		# if that shot LANDS (hit==true), the creature injects its rider onto the shooter. Only the PvE
		# hostile branch carries a rider (target_key != "" here => a registered hostile; the shared dummy is
		# "" and PvP has none). _seed_status_from_rider self-guards a now-downed shooter (downed loop owns them).
		if not is_pvp and target_key != "" and bool((result.get("return_fire", {}) as Dictionary).get("hit", false)):
			_seed_status_from_rider(record["state"], target_key)
		# Write the resolved target's new state back to the RIGHT target.
		var new_tstate: Dictionary = result.get("target_state", tstate)
		if is_pvp:
			# Land the shot on the TARGET PLAYER's live state (accumulate; the single field every
			# downstream surface reads). NOT _target_state, NOT the shooter.
			var def2: Dictionary = _players[target_peer]
			var def_state: Dictionary = def2["state"]
			var prior_def := int(def_state.get("player_wound_severity", 0))
			# G2 (DIV-0006/0019): near-peer PvP ACCUMULATES up the WEG wound ladder instead of
			# highest-hit-wins, so two sub-lethal hits put a player down rather than leaving them
			# wounded forever. Cross the int<->ladder boundary via the LEVEL STRING (the int collapses
			# wounded/wounded_twice); feed escalate() the RAW single-hit severity from THIS exchange
			# (this_hit_severity) so a small hit deepens by one ladder rung instead of double-counting
			# the target's already-projected prior wound.
			var prior_level := String(def_state.get("player_wound_level", WoundLadder.level_for_severity(prior_def)))
			var incoming_hit := int(new_tstate.get("this_hit_severity", 0))
			var new_level := WoundLadder.escalate(prior_level, incoming_hit)
			def_state["player_wound_level"] = new_level
			def_state["player_wound_severity"] = WoundLadder.severity_for_level(new_level)
			def_state["player_armor_quality_pips"] = int(new_tstate.get("armor_quality_pips", def_state.get("player_armor_quality_pips", 0)))
			def2["state"] = def_state
			var new_def := int(def_state["player_wound_severity"])
			# Tiered casualty (dedup by peer; keeps the highest severity + the killer who reached it).
			if new_def >= DISABLED_SEVERITY and new_def > prior_def:
				casualties[target_peer] = {"peer": target_peer, "severity": new_def, "killer": peer_id}
		elif target_key != "":
			(_hostile_targets[target_key] as Dictionary)["state"] = new_tstate
		else:
			_target_state = new_tstate
		var envelope: Dictionary = CombatEventEnvelopeModel.envelope_for_result(result, "ground_range", "local")
		envelope["shooter_id"] = peer_id
		envelope["shooter_name"] = String(record["name"])
		envelope["target_name"] = String(new_tstate.get("name", ""))
		envelope["target_wound_severity"] = int(new_tstate.get("wound_severity", 0))
		envelope["target_disabled"] = int(new_tstate.get("wound_severity", 0)) >= DISABLED_SEVERITY
		if is_pvp:
			envelope["pvp"] = true
			envelope["target_peer_id"] = target_peer
			envelope["target_key"] = ""
			envelope["lethal"] = true
		else:
			envelope["target_key"] = target_key  # "" = the shared training dummy
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
		"casualties": casualties.values(),  # DIV-0019: [{peer, severity, killer}, ...] taken out this window
	}

## G4 (DIV-0017): resolve ONE action window of UNPROVOKED fire from a zone's hostile target at a set of
## same-zone players who did NOT declare a shot this window (the net layer selects the idle victims). The
## hostile is the ATTACKER; each victim only takes INCOMING fire via the (already-smoked) multi-attacker
## resolve_incoming_fire_window — they do NOT attack back here, so a player who WANTS to fight the hostile
## submits a fire intent and goes through resolve_window instead (no victim is double-hit). LETHAL like
## every hostile: target_stun_mode=false (from the creature pools) means REAL wounds, and there is no
## DIV-0016 sparring clamp on this path (that clamp lives only in resolve_window's provoked branch).
## Returns {envelopes, casualties:[{peer, severity, killer}]}; killer is 0 (a creature — no player credit).
## seed_base is the server-owned per-window seed. No-op if the target is absent or already disabled.
func resolve_hostile_aggression(target_key: String, victim_ids: Array, seed_base: int) -> Dictionary:
	var envelopes: Array = []
	var casualties := {}
	if not _hostile_targets.has(target_key):
		return {"envelopes": envelopes, "casualties": []}
	var hrec: Dictionary = _hostile_targets[target_key]
	var hstate: Dictionary = hrec["state"]
	if int(hstate.get("wound_severity", 0)) >= DISABLED_SEVERITY:
		return {"envelopes": envelopes, "casualties": []}  # a downed hostile does not fire
	var hpools: Dictionary = hrec["pools"]
	var hprofile: Dictionary = hrec["profile"]
	var hname := String(hprofile.get("name", target_key))
	var distance := float(hprofile.get("distance", PVP_DISTANCE))
	var hostile_severity := int(hstate.get("wound_severity", 0))
	var i := 0
	for victim in victim_ids:
		if not _players.has(victim):
			i += 1
			continue
		var record: Dictionary = _players[victim]
		var vstate: Dictionary = record["state"]
		var prior := int(vstate.get("player_wound_severity", 0))
		if prior >= DISABLED_SEVERITY:
			i += 1
			continue  # already out — a downed victim is the bleed-out/yield/medic loop's domain, not the hostile's
		# The victim's OWN defensive pools (soak / dodge / armor / scale) + the hostile's attack side.
		var pools: Dictionary = (record.get("pools", _default_player_pools) as Dictionary).duplicate(true)
		pools.merge(hpools)  # target_attack_pool / target_damage_pool / target_soak_pool / target_scale / target_stun_mode=false
		# One incoming attack from the hostile creature this window (the smoked multi-attacker contract).
		var incoming: Array = [{
			"source_id": target_key,
			"source_name": hname,
			"attack_pool": hpools.get("target_attack_pool", {"dice": 3, "pips": 0}),
			"damage_pool": hpools.get("target_damage_pool", {"dice": 3, "pips": 0}),
			"scale": String(hpools.get("target_scale", "creature")),
			"distance": distance,
			# G4 fix (verify: attack-correctness): the VICTIM's own cover protects them on the incoming
			# shot (like the provoked return-fire path), NOT the hostile's profile cover — so a player who
			# crouched then stopped firing keeps their cover bonus vs an unprovoked attack.
			"cover_level": int(vstate.get("player_cover_level", 0)),
			"wound_severity": hostile_severity,  # the hostile's own wound penalty on its shot
		}]
		var exchange_seed := seed_base + (i + 1) * 6607
		var result: Dictionary = _ground.resolve_incoming_fire_window(_rules, vstate, pools, incoming, exchange_seed)
		var new_vstate: Dictionary = result.get("state", vstate)
		var new_sev := int(new_vstate.get("player_wound_severity", prior))
		# Keep the wound LEVEL string coherent with the severity (mirrors set_player_combat's severity->level
		# derivation) so a later PvP escalate() reads a sane ladder base. Only advances (never de-escalates).
		if new_sev > prior:
			new_vstate["player_wound_level"] = WoundLadder.level_for_severity(new_sev)
		record["state"] = new_vstate
		# DIV-0024: an UNPROVOKED hostile bite/sting that LANDS injects its rider onto the victim (same
		# seed-on-hit rule as the return-fire path). Detect a connecting shot via the per-attack hit flag.
		var landed := false
		for inc in result.get("incoming", []):
			if bool((inc as Dictionary).get("hit", false)):
				landed = true
				break
		if landed:
			_seed_status_from_rider(record["state"], target_key)
		# Envelope so same-zone clients render the incoming fire (subject = the victim who took it).
		var envelope: Dictionary = CombatEventEnvelopeModel.envelope_for_result(result, "ground_range", "local")
		envelope["shooter_id"] = victim
		envelope["shooter_name"] = String(record["name"])
		envelope["target_name"] = hname
		envelope["target_key"] = target_key
		envelope["lethal"] = true
		envelope["unprovoked"] = true  # G4: a hostile-INITIATED exchange, not the victim's own return-fire shot
		envelopes.append(envelope)
		if new_sev >= DISABLED_SEVERITY and new_sev > prior:
			casualties[victim] = {"peer": victim, "severity": new_sev, "killer": 0}
		i += 1
	return {"envelopes": envelopes, "casualties": casualties.values()}

# --- DIV-0024: creature venom/restraint STATUS riders ---
## The monotonic combat-window counter (for tests / inspection). Advances once per tick_status_effects call.
func current_status_window() -> int:
	return _status_window

## Compact per-player status readout for the snapshot ({poison_rounds_left:int, restrained:bool, source}).
## poison_rounds_left = scheduled ticks still ahead of the current window; source is the injecting creature.
func player_status_summary(peer_id: int) -> Dictionary:
	var out := {"poison_rounds_left": 0, "restrained": false, "source": ""}
	if not _players.has(peer_id):
		return out
	var pstate: Dictionary = (_players[peer_id] as Dictionary).get("state", {})
	if pstate.has("status_poison"):
		var st: Dictionary = pstate["status_poison"]
		# The NEXT tick_status_effects call fires round == (_status_window - applied), so ticks still to come
		# are those with round >= that value (">=", not ">", keeps the count in step with actual application).
		var relative := _status_window - int(st.get("applied_window", _status_window))
		var left := 0
		for t in st.get("schedule", []):
			if int((t as Dictionary).get("round", 0)) >= relative:
				left += 1
		out["poison_rounds_left"] = left
		out["source"] = String(st.get("source_name", ""))
	if pstate.has("status_restraint"):
		out["restrained"] = true
		if String(out["source"]) == "":
			out["source"] = String((pstate["status_restraint"] as Dictionary).get("source_name", "held"))
	return out

## DIV-0024 (audit fix 2026-07-03): erase a player's venom/restraint status. The death/respawn path MUST
## call this: a player instant-killed (sev 5) while carrying an active schedule respawns at severity 2 —
## BELOW the tick loop's DISABLED_SEVERITY skip guard — so without an explicit clear the pre-death schedule
## keeps ticking the freshly respawned body (re-downing it, an extra death penalty). tick_status_effects
## already self-clears a DOWNED (sev 3-4) victim; this covers the respawn that drops severity below the guard.
func clear_status(peer_id: int) -> void:
	if not _players.has(peer_id):
		return
	var st: Dictionary = (_players[peer_id] as Dictionary).get("state", {})
	st.erase("status_poison")
	st.erase("status_restraint")

## Seed a hostile's baked venom/restraint rider onto a victim who just took a LANDED hit. Never seeds a
## victim already downed (>=DISABLED_SEVERITY — the DIV-0027 downed loop owns them). A re-bite REFRESHES the
## poison schedule (replaces, never stacks). Deep-copies everything it stashes so a per-victim status never
## aliases the shared baked rider / creatures_data (the model's aliasing discipline).
func _seed_status_from_rider(victim_state: Dictionary, target_key: String) -> void:
	if not _hostile_targets.has(target_key):
		return
	var hrec: Dictionary = _hostile_targets[target_key]
	var rider: Dictionary = hrec.get("rider", {})
	if rider.is_empty() or not bool(rider.get("has_special_attack", false)):
		return
	if int(victim_state.get("player_wound_severity", 0)) >= DISABLED_SEVERITY:
		return
	var source_name := String((hrec.get("profile", {}) as Dictionary).get("name", target_key))
	var schedule: Array = rider.get("poison_schedule", [])
	if not schedule.is_empty():
		# Re-bite REFRESH (documented no-stack): replace any active poison with a fresh schedule stamped NOW.
		victim_state["status_poison"] = {
			"schedule": schedule.duplicate(true),
			"applied_window": _status_window,
			"source_name": source_name,
		}
	var restraint: Dictionary = rider.get("restraint", {})
	if not restraint.is_empty():
		var creature_str: Dictionary = (hrec.get("pools", {}) as Dictionary).get("target_soak_pool", {"dice": 2, "pips": 0})
		victim_state["status_restraint"] = {
			"descriptor": restraint.duplicate(true),
			"source_key": target_key,
			"source_name": source_name,
			"source_str_pool": (creature_str as Dictionary).duplicate(true),
		}

## Advance every player's active venom/restraint status ONE combat window. The net layer calls this ONCE
## per window (like _tick_hostile_aggression / _tick_downed), AFTER the provoked + unprovoked fire passes
## have seeded new status. Owns the monotonic _status_window advance. Returns {envelopes, casualties} where
## each casualty is {peer, severity, killer:0} (a creature — no player credit); the net layer routes them
## through the SAME DIV-0027 downed/death tiering as window/aggression takeouts. seed_base is server-owned.
func tick_status_effects(seed_base: int) -> Dictionary:
	var envelopes: Array = []
	var casualties := {}
	var window := _status_window
	var i := 0
	for peer_id in _players.keys():
		var record: Dictionary = _players[peer_id]
		var pstate: Dictionary = record["state"]
		# A downed victim is the DIV-0027 loop's domain — never tick; drop any lingering status.
		if int(pstate.get("player_wound_severity", 0)) >= DISABLED_SEVERITY:
			pstate.erase("status_poison")
			pstate.erase("status_restraint")
			i += 1
			continue
		var victim_seed := seed_base + (i + 1) * 2749
		if pstate.has("status_poison"):
			if _tick_poison(peer_id, record, pstate, window, victim_seed, envelopes, casualties):
				i += 1
				continue  # downed by venom this window -> restraint waits for the downed loop
		if pstate.has("status_restraint"):
			_tick_restraint(peer_id, record, pstate, victim_seed + 104729, envelopes, casualties)
		i += 1
	_status_window = window + 1
	return {"envelopes": envelopes, "casualties": casualties.values()}

# Apply the poison tick DUE this window (absolute round == window - applied_window). Venom is INTERNAL:
# armor does NOT protect — the body resists with BARE Strength (player_soak_pool) only. LETHAL (no DIV-0016
# sparring clamp); accumulates up the WEG wound ladder. Returns true if the victim was DOWNED this tick.
func _tick_poison(peer_id: int, record: Dictionary, pstate: Dictionary, window: int, seed: int, envelopes: Array, casualties: Dictionary) -> bool:
	var status: Dictionary = pstate["status_poison"]
	var schedule: Array = status.get("schedule", [])
	var applied := int(status.get("applied_window", window))
	var relative := window - applied
	var due: Dictionary = {}
	var last_round := 0
	for t in schedule:
		var r := int((t as Dictionary).get("round", 0))
		last_round = maxi(last_round, r)
		if r == relative:
			due = t
	var rounds_left := 0
	for t in schedule:
		if int((t as Dictionary).get("round", 0)) > relative:
			rounds_left += 1
	if due.is_empty():
		if relative >= last_round:
			pstate.erase("status_poison")  # onset window(s) elapsed with no ticks left -> clear (safety)
		return false
	# Real WEG damage-vs-soak: the venom's OWN damage pool vs bare Strength. Deterministic (server seed).
	var pools: Dictionary = record.get("pools", _default_player_pools)
	var soak_pool: Dictionary = pools.get("player_soak_pool", {"dice": 2, "pips": 0})
	var damage_pool: Dictionary = due.get("pool", {"dice": 0, "pips": 0})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var damage: Dictionary = _rules.resolve_damage(damage_pool, soak_pool, rng)  # stun_mode=false => a REAL wound
	var hit_sev := int((damage.get("wound", {}) as Dictionary).get("severity", 0))
	var prior := int(pstate.get("player_wound_severity", 0))
	var prior_level := String(pstate.get("player_wound_level", WoundLadder.level_for_severity(prior)))
	var new_level := WoundLadder.escalate(prior_level, hit_sev)
	pstate["player_wound_level"] = new_level
	var new_sev := WoundLadder.severity_for_level(new_level)
	pstate["player_wound_severity"] = new_sev
	var source_name := String(status.get("source_name", "venom"))
	var envelope := {
		"type": "status_effect", "status": "poison", "kind": "poison",
		"shooter_id": peer_id, "subject_id": peer_id,
		"source_name": source_name, "target_name": source_name, "lethal": true,
		"round": int(due.get("round", relative)),
		"damage_total": int((damage.get("damage_roll", {}) as Dictionary).get("total", 0)),
		"soak_total": int((damage.get("soak_roll", {}) as Dictionary).get("total", 0)),
		"wound_key": String((damage.get("wound", {}) as Dictionary).get("key", "no_damage")),
		"severity": new_sev, "this_hit_severity": hit_sev, "rounds_left": rounds_left,
	}
	envelopes.append(envelope)
	if new_sev >= DISABLED_SEVERITY and new_sev > prior:
		casualties[peer_id] = {"peer": peer_id, "severity": new_sev, "killer": 0}
		pstate.erase("status_poison")     # downed -> stop; downed loop owns them
		pstate.erase("status_restraint")
		return true
	if relative >= last_round:
		pstate.erase("status_poison")  # last scheduled tick applied -> venom runs its course
	return false

# Resolve ONE window of a restraint hold: an opposed BREAK check (victim STR vs the creature's STR — WEG
# max(brawling,STR) approximated by STR, as brawling isn't separately tracked in the combat pools). On the
# victim WIN -> break free + clear. On the LOSE -> if the descriptor carries hold_damage, resolve it (STR-
# relative) vs the victim's Strength+ARMOR soak (crush is external, armor DOES protect) and accumulate up
# the ladder; a hold-crush can DOWN the victim (casualty, killer 0). Auto-resolved (no client RPC in v1).
func _tick_restraint(peer_id: int, record: Dictionary, pstate: Dictionary, seed: int, envelopes: Array, casualties: Dictionary) -> void:
	var status: Dictionary = pstate["status_restraint"]
	var descriptor: Dictionary = status.get("descriptor", {})
	var source_name := String(status.get("source_name", "a grasp"))
	var pools: Dictionary = record.get("pools", _default_player_pools)
	var victim_str: Dictionary = pools.get("player_soak_pool", {"dice": 2, "pips": 0})
	var creature_str: Dictionary = status.get("source_str_pool", {"dice": 2, "pips": 0})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var victim_total := int(_rules.roll_pool(victim_str, rng).get("total", 0))
	var creature_total := int(_rules.roll_pool(creature_str, rng).get("total", 0))
	var broke := victim_total > creature_total  # holder wins ties (stays gripped)
	var envelope := {
		"type": "status_effect", "status": "restraint", "kind": String(descriptor.get("kind", "grapple")),
		"shooter_id": peer_id, "subject_id": peer_id,
		"source_name": source_name, "target_name": source_name, "lethal": true,
		"break_check": String(descriptor.get("break_check", "opposed brawling/STR")),
		"victim_roll": victim_total, "opposed_roll": creature_total,
	}
	if broke:
		pstate.erase("status_restraint")
		envelope["broke_free"] = true
		envelope["restrained"] = false
		envelopes.append(envelope)
		return
	envelope["broke_free"] = false
	envelope["restrained"] = true
	if bool(descriptor.get("has_hold_damage", false)):
		var hold_pool: Dictionary = CreatureSpecialAttack.resolve_hold_damage_pool(_rules, descriptor, creature_str)
		var armor_profile: Dictionary = pools.get("player_armor", {})
		var armor: Dictionary = ArmorConditionModel.armor_for_location(armor_profile, "torso")
		var quality_pips := int(pstate.get("player_armor_quality_pips", 0))
		var soak_pool: Dictionary = _rules.apply_armor_to_soak(victim_str, armor, "physical", quality_pips)
		var damage: Dictionary = _rules.resolve_damage(hold_pool, soak_pool, rng)
		var hit_sev := int((damage.get("wound", {}) as Dictionary).get("severity", 0))
		var prior := int(pstate.get("player_wound_severity", 0))
		var prior_level := String(pstate.get("player_wound_level", WoundLadder.level_for_severity(prior)))
		var new_level := WoundLadder.escalate(prior_level, hit_sev)
		pstate["player_wound_level"] = new_level
		var new_sev := WoundLadder.severity_for_level(new_level)
		pstate["player_wound_severity"] = new_sev
		envelope["hold_damage"] = String(descriptor.get("hold_damage", ""))
		envelope["damage_total"] = int((damage.get("damage_roll", {}) as Dictionary).get("total", 0))
		envelope["severity"] = new_sev
		envelope["this_hit_severity"] = hit_sev
		if new_sev >= DISABLED_SEVERITY and new_sev > prior:
			casualties[peer_id] = {"peer": peer_id, "severity": new_sev, "killer": 0}
			pstate.erase("status_restraint")
	envelopes.append(envelope)

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
