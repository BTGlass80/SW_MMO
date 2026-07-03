extends SceneTree
## G3 (DIV-0019): PvP defenders can DODGE. Before this, a player-vs-player primary attack passed an
## EMPTY defense into resolve_ranged_attack, so a victim's declared dodge/full_dodge did nothing —
## defense was armor + Strength soak only. This smoke proves the WEG reaction layer is now present in
## PvP too, at both the pure-model seam and end-to-end through combat_arena.resolve_window.
##
## Asserts:
##   1. (pure) a FULL_DODGE defender strictly RAISES the attacker's effective difficulty vs no dodge
##      (same seed) and the attack carries a real dodge roll; DEFENSE_NONE is byte-identical to before.
##   2. (pure) both a declared DODGE and a FULL_DODGE defender REDUCE the attacker's hit rate over a
##      fixed seed sweep (deterministic).
##   3. (arena) a FULL_DODGE defender SKIPS their own attack AND their dodge applies to the incoming
##      shot, cutting the attacker's hit count vs an undodged defender.
## All seeds fixed; RNG lives on the model.

const GroundCombat := preload("res://scripts/rules/ground_combat_model.gd")
const CombatArena := preload("res://scripts/net/combat_arena.gd")

var _failures: Array[String] = []
var _rules: Object

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	var model := GroundCombat.new()

	# --- 1. pure model: a FULL_DODGE defender raises the attacker's difficulty (single fixed seed) ---
	var pools := _pvp_pools()
	var seed := 424242
	var none: Dictionary = model.resolve_exchange(_rules, model.initial_state(), {"wound_severity": 0}, pools, 12.0, 0, seed, GroundCombat.DEFENSE_NONE)
	var full: Dictionary = model.resolve_exchange(_rules, model.initial_state(), {"wound_severity": 0}, pools, 12.0, 0, seed, GroundCombat.DEFENSE_FULL_DODGE)
	var none_diff := int((none.get("attack", {}) as Dictionary).get("difficulty", 0))
	var full_diff := int((full.get("attack", {}) as Dictionary).get("difficulty", 0))
	_assert_true(full_diff > none_diff, "a full-dodge defender RAISES the attacker's difficulty (%d > %d)" % [full_diff, none_diff])
	var full_def: Dictionary = (full.get("attack", {}) as Dictionary).get("defense", {})
	_assert_equal(String(full_def.get("type", "")), "full_dodge", "the full-dodge defense is carried on the attack")
	_assert_true(int(full_def.get("value", 0)) >= 1, "the defender rolled a real dodge value (>= 1)")
	_assert_equal(bool(full_def.get("replaces", true)), false, "full_dodge ADDS to the range difficulty (does not replace it)")
	var none_def: Dictionary = (none.get("attack", {}) as Dictionary).get("defense", {})
	_assert_equal(String(none_def.get("type", "none")), "none", "no declared dodge -> no defense on the attack (unchanged path)")

	# Byte-identity guard: DEFENSE_NONE must be identical to the pre-G3 call that omitted the arg.
	var legacy: Dictionary = model.resolve_exchange(_rules, model.initial_state(), {"wound_severity": 0}, pools, 12.0, 0, seed)
	_assert_equal(int((legacy.get("attack", {}) as Dictionary).get("difficulty", 0)), none_diff, "omitting the stance arg == DEFENSE_NONE (no behavior/RNG drift for PvE)")

	# --- 2. pure model: dodge + full_dodge both cut the attacker's hit rate over a seed sweep ---
	var none_hits := 0
	var dodge_hits := 0
	var full_hits := 0
	for s in range(40):
		var seed2 := 9000 + s
		if bool((model.resolve_exchange(_rules, model.initial_state(), {"wound_severity": 0}, pools, 12.0, 0, seed2, GroundCombat.DEFENSE_NONE).get("attack", {}) as Dictionary).get("success", false)):
			none_hits += 1
		if bool((model.resolve_exchange(_rules, model.initial_state(), {"wound_severity": 0}, pools, 12.0, 0, seed2, GroundCombat.DEFENSE_DODGE).get("attack", {}) as Dictionary).get("success", false)):
			dodge_hits += 1
		if bool((model.resolve_exchange(_rules, model.initial_state(), {"wound_severity": 0}, pools, 12.0, 0, seed2, GroundCombat.DEFENSE_FULL_DODGE).get("attack", {}) as Dictionary).get("success", false)):
			full_hits += 1
	_assert_true(none_hits >= 30, "an undodged attacker lands most shots (%d/40)" % none_hits)
	_assert_true(full_hits < none_hits, "a full-dodge defender reduces the attacker's hit count (%d < %d)" % [full_hits, none_hits])
	_assert_true(dodge_hits < none_hits, "a declared-dodge defender reduces the attacker's hit count (%d < %d)" % [dodge_hits, none_hits])

	# --- 3. arena: a full-dodge defender skips their OWN attack AND dodges the incoming shot ---
	var nd_hits := 0
	var fd_hits := 0
	var saw_skip := false
	var saw_b_attack := false
	for w in range(30):
		var nd := _one_window(4200 + w, false)  # B declares NO dodge (B still attacks A)
		var fd := _one_window(4200 + w, true)   # B declares FULL_DODGE
		if bool(nd["a_hit"]):
			nd_hits += 1
		if bool(fd["a_hit"]):
			fd_hits += 1
		if bool(fd["b_skipped"]):
			saw_skip = true
		# the full-dodge defender NEVER fires their own attack this window
		_assert_true(not bool(fd["b_attacked"]), "a full-dodge defender does NOT resolve their own attack")
		if bool(nd["b_attacked"]):
			saw_b_attack = true
	_assert_true(nd_hits >= 20, "the attacker reliably hits an undodging PvP defender (%d/30)" % nd_hits)
	_assert_true(fd_hits < nd_hits, "a full-dodge PvP defender is hit less often than an undodging one (%d < %d)" % [fd_hits, nd_hits])
	_assert_true(saw_skip, "a full-dodge defender emits a player_full_dodge (own attack skipped)")
	_assert_true(saw_b_attack, "the undodging control defender DOES fire their own attack (proves the skip is the dodge, not the setup)")

	if _rules.has_method("free"):
		_rules.free()
	if _failures.is_empty():
		print("pvp_dodge_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

# A strong attacker vs a defender carrying a HUGE dodge pool (target_dodge_pool); return fire suppressed
# so the assertions isolate the primary attack. Scales equal, no armor.
func _pvp_pools() -> Dictionary:
	return {
		"attacker_pool": {"dice": 8, "pips": 0},
		"damage_pool": {"dice": 5, "pips": 0},
		"player_dodge_pool": {"dice": 3, "pips": 0},
		"player_soak_pool": {"dice": 3, "pips": 0},
		"player_armor": {},
		"attacker_scale": "character",
		"target_attack_pool": {"dice": 3, "pips": 0},
		"target_damage_pool": {"dice": 3, "pips": 0},
		"target_soak_pool": {"dice": 3, "pips": 0},
		"target_dodge_pool": {"dice": 12, "pips": 0},
		"target_armor": {},
		"target_scale": "character",
		"suppress_return_fire": true,
	}

# Resolve one arena window: A (peer 2) fires at B (peer 3). When b_full_dodge, B declares full_dodge;
# otherwise B declares a plain attack back. Returns whether A's shot hit B and what B did.
func _one_window(seed: int, b_full_dodge: bool) -> Dictionary:
	var arena := CombatArena.new(_rules, _combat_data(), "b1_training_silhouette", _weapons(), {})
	arena.register_player(2, "Ganker", _ganker())
	arena.register_player(3, "Dancer", _dancer())
	arena.submit_fire_intent(2, {"aim": 3, "target_peer": 3})
	if b_full_dodge:
		arena.submit_fire_intent(3, {"full_dodge": true, "target_peer": 2})
	else:
		arena.submit_fire_intent(3, {"aim": 0, "target_peer": 2})
	var res: Dictionary = arena.resolve_window(seed, {2: true, 3: true})
	var out := {"a_hit": false, "b_skipped": false, "b_attacked": false}
	for env in res.get("envelopes", []):
		var e: Dictionary = env
		var shooter := int(e.get("shooter_id", 0))
		var types: Array = e.get("event_types", [])
		if shooter == 2:
			for ev in e.get("events", []):
				if String((ev as Dictionary).get("type", "")) == "player_attack":
					out["a_hit"] = bool((ev as Dictionary).get("success", false))
		elif shooter == 3:
			out["b_skipped"] = types.has("player_full_dodge")
			out["b_attacked"] = types.has("player_attack")
	return out

func _ganker() -> Dictionary:
	# High to-hit (DEX + blaster), but a LOW-damage weapon on purpose: the dodge acts on the to-hit,
	# and the undodging control defender must SURVIVE the shot to fire back (proving the full-dodge skip
	# is the stance, not the defender being one-shot before their turn).
	return {"attributes": {"dexterity": "4D", "strength": "3D", "perception": "5D"}, "skills": {"blaster": "4D"}, "equipment": {"weapon": "pea_shooter"}}

func _dancer() -> Dictionary:
	# A fragile defender whose survival is PURELY the reaction dodge (big dodge, no armor).
	return {"attributes": {"dexterity": "4D", "strength": "2D", "perception": "1D"}, "skills": {"dodge": "8D", "blaster": "1D"}, "equipment": {"weapon": "pea_shooter"}}

func _weapons() -> Dictionary:
	return {"hand_cannon": {"damage": "12D", "skill": "blaster"}, "pea_shooter": {"damage": "2D", "skill": "blaster"}}

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {"blaster": "4D+1", "dodge": "4D", "soak": "3D", "weapon": "training_blaster", "armor": "", "scale": "character"},
		"weapons": {"training_blaster": {"damage": "4D"}},
		"armors": {},
		"targets": {"b1_training_silhouette": {"blaster": "3D", "weapon": "training_blaster", "soak": "2D", "scale": "character", "distance": 12.0, "cover_level": 0, "name": "B1 Training Remote"}},
	}

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
