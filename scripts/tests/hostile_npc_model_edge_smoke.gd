extends SceneTree
## HARDENING smoke for the pure hostile-NPC mapping (scripts/rules/hostile_npc_model.gd). Adversarial
## edge-case coverage beyond hostile_npc_model_smoke.gd: lowercase / mixed-case "STR"-relative damage
## codes, a completely missing natural_attack block, an explicitly-empty to_hit_skill, a missing
## strength attribute, and the lethality gate with an empty tier list. All-static, deterministic.

const HostileNpc = preload("res://scripts/rules/hostile_npc_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var rules = load("res://scripts/rules/d6_rules.gd").new()

	# --- lowercase / mixed-case STR-relative damage codes resolve the same as uppercase ---
	var spawn_lower := {"char_sheet": {"attributes": {"strength": "3D"}, "skills": {"claw": "2D"}},
		"natural_attack": {"to_hit_skill": "claw", "damage": "str+1d"}}
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_lower)["target_damage_pool"]), "4D", "lowercase 'str+1d' resolves the same as 'STR+1D'")

	var spawn_mixed := {"char_sheet": {"attributes": {"strength": "2D"}, "skills": {"claw": "2D"}},
		"natural_attack": {"to_hit_skill": "claw", "damage": "Str+2"}}
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_mixed)["target_damage_pool"]), "2D+2", "mixed-case 'Str+2' resolves correctly")

	var spawn_bare_lower := {"char_sheet": {"attributes": {"strength": "4D"}}, "natural_attack": {"damage": "str"}}
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_bare_lower)["target_damage_pool"]), "4D", "bare lowercase 'str' resolves to Strength directly")

	# --- completely missing natural_attack block: defaults gracefully to a flat 3D damage code ---
	var spawn_no_attack := {"char_sheet": {"attributes": {"strength": "3D"}, "skills": {"melee_combat": "4D"}}}
	var pools_no_attack: Dictionary = HostileNpc.attack_pools_from_creature(rules, spawn_no_attack)
	_assert_equal(rules.pool_to_string(pools_no_attack["target_damage_pool"]), "3D", "a missing natural_attack block defaults damage to a flat 3D (not STR-relative)")
	_assert_equal(rules.pool_to_string(pools_no_attack["target_attack_pool"]), "3D", "a missing natural_attack block also defaults the to-hit pool to 3D (no listed skill)")

	# --- explicitly-empty to_hit_skill (present but blank) falls back to the 3D default, not a crash ---
	var spawn_blank_skill := {"char_sheet": {"attributes": {"strength": "2D"}, "skills": {"claw": "4D"}},
		"natural_attack": {"to_hit_skill": "", "damage": "2D"}}
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_blank_skill)["target_attack_pool"]), "3D", "an explicitly blank to_hit_skill falls back to the 3D default rather than an empty pool")

	# --- missing strength attribute entirely defaults to 2D (rules.gd contract via .get fallback) ---
	var spawn_no_str := {"char_sheet": {"attributes": {}, "skills": {"claw": "3D"}},
		"natural_attack": {"to_hit_skill": "claw", "damage": "STR"}}
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_no_str)["target_soak_pool"]), "2D", "a missing strength attribute defaults to 2D")
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_no_str)["target_damage_pool"]), "2D", "bare STR damage with a missing strength attribute also resolves to the 2D default")

	# --- target_armor is always an empty dict (v1: natural armor not modeled) ---
	_assert_equal((pools_no_attack["target_armor"] as Dictionary).is_empty(), true, "target_armor is always empty in v1")

	# --- lethality gate: an empty tier override means NOTHING is lethal ---
	_assert_equal(HostileNpc.is_lethal_zone("lawless", []), false, "an empty lethal_tiers override closes lethality everywhere")
	_assert_equal(HostileNpc.is_lethal_zone("", []), false, "an empty security tier is never lethal")

	rules.free()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("hostile_npc_model_edge_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
