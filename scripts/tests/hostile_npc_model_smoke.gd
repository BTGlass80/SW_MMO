extends SceneTree
## Smoke for the pure hostile-NPC mapping (Wave F / DIV-0017): a creature spawn maps to the arena
## target_* pool shape (attack from the natural-attack skill, STR-relative damage resolution, soak
## = Strength, real-damage stun mode), and the lawless-only lethality gate.

const HostileNpc = preload("res://scripts/rules/hostile_npc_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var rules = load("res://scripts/rules/d6_rules.gd").new()

	# A Tusken-like melee creature: STR 3D, melee_combat 4D, gaderffii STR+1D.
	var spawn := {
		"hostile": true, "scale": "creature", "pack_size": 2,
		"char_sheet": {"attributes": {"strength": "3D"}, "skills": {"melee_combat": "4D"}},
		"natural_attack": {"to_hit_skill": "melee_combat", "damage": "STR+1D"},
	}
	var pools: Dictionary = HostileNpc.attack_pools_from_creature(rules, spawn)
	_assert_equal(rules.pool_to_string(pools["target_attack_pool"]), "4D", "attack pool = the natural-attack skill (melee_combat 4D)")
	_assert_equal(rules.pool_to_string(pools["target_damage_pool"]), "4D", "STR+1D damage resolves to 3D + 1D = 4D")
	_assert_equal(rules.pool_to_string(pools["target_soak_pool"]), "3D", "soak pool = Strength (3D)")
	_assert_equal(String(pools["target_scale"]), "creature", "scale carried from the spawn")
	_assert_equal(bool(pools["target_stun_mode"]), false, "a hostile creature deals REAL damage (stun_mode false)")

	# STR-relative with pips ("STR+2") and a flat damage code ("5D").
	var spawn_pips := {"char_sheet": {"attributes": {"strength": "3D"}, "skills": {"claw": "2D"}},
		"natural_attack": {"to_hit_skill": "claw", "damage": "STR+2"}}
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_pips)["target_damage_pool"]), "3D+2", "STR+2 resolves to 3D+2")
	var spawn_flat := {"char_sheet": {"attributes": {"strength": "2D"}, "skills": {"blaster": "3D+1"}},
		"natural_attack": {"to_hit_skill": "blaster", "damage": "5D"}}
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_flat)["target_damage_pool"]), "5D", "a flat damage code parses directly")
	_assert_equal(rules.pool_to_string(HostileNpc.attack_pools_from_creature(rules, spawn_flat)["target_attack_pool"]), "3D+1", "attack pool honors pips (3D+1)")

	# Missing natural-attack skill -> a modest 3D default (no crash).
	var spawn_bare := {"char_sheet": {"attributes": {"strength": "1D"}}, "natural_attack": {"damage": "STR"}}
	var bare: Dictionary = HostileNpc.attack_pools_from_creature(rules, spawn_bare)
	_assert_equal(rules.pool_to_string(bare["target_attack_pool"]), "3D", "no listed skill -> 3D default")
	_assert_equal(rules.pool_to_string(bare["target_damage_pool"]), "1D", "bare STR damage = Strength (1D)")

	# --- lethality gate: lawless-only by default; tunable ---
	_assert_equal(HostileNpc.is_lethal_zone("lawless"), true, "lawless is lethal")
	_assert_equal(HostileNpc.is_lethal_zone("secured"), false, "secured is NOT lethal (starter zones safe)")
	_assert_equal(HostileNpc.is_lethal_zone("contested"), false, "contested is not lethal by default")
	_assert_equal(HostileNpc.is_lethal_zone("contested", ["lawless", "contested"]), true, "contested lethal when configured")

	rules.free()  # d6_rules extends Node
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("hostile_npc_model_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
