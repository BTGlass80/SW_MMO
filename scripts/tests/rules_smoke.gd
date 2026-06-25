extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	var rules_script: GDScript = load("res://scripts/rules/d6_rules.gd")
	var rules: Node = rules_script.new()

	_assert_equal(rules.pool_to_string(rules.parse_pool("3D+4")), "4D+1", "pips normalize upward")
	_assert_equal(rules.pool_to_string(rules.add_pips({"dice": 2, "pips": 2}, 1)), "3D", "pips roll into dice")
	_assert_equal(rules.pool_to_string(rules.add_pools({"dice": 4, "pips": 1}, {"dice": 3, "pips": 0})), "7D+1", "aim dice add to attack pool")
	_assert_equal(rules.pool_to_string(rules.subtract_pools({"dice": 4, "pips": 1}, {"dice": 1, "pips": 2})), "2D+2", "pool subtraction preserves pips")
	_assert_equal(rules.pool_to_string(rules.apply_multi_action_penalty({"dice": 4, "pips": 1}, 2)), "3D+1", "one extra action removes 1D")
	_assert_equal(rules.pool_to_string(rules.apply_multi_action_penalty({"dice": 1, "pips": 2}, 4)), "0D", "excess multi-action penalty bottoms out at 0D")
	_assert_equal(rules.pool_to_string(rules.apply_wound_penalty({"dice": 4, "pips": 1}, 1)), "3D+1", "wound penalty removes dice")
	_assert_equal(rules.pool_to_string(rules.apply_wound_penalty({"dice": 1, "pips": 2}, 3)), "0D", "excess wound penalty bottoms out at 0D")
	_assert_equal(rules.pool_to_string(rules.apply_force_point({"dice": 4, "pips": 1})), "8D+2", "force point doubles dice and pips")
	_assert_equal(rules.scale_value("Starfighter"), 6, "starfighter scale value")
	_assert_equal(rules.scale_difference("speeder", "walker"), 2, "speeder to walker adjusted modifier")
	_assert_equal(rules.pool_to_string(rules.apply_scale_to_attack_pool({"dice": 3, "pips": 1}, "speeder", "walker")), "5D+1", "lower scale adds adjusted modifier to attack")
	_assert_equal(rules.pool_to_string(rules.apply_scale_to_dodge_pool({"dice": 2, "pips": 0}, "speeder", "walker")), "2D", "higher scale target dodge is unchanged")
	_assert_equal(rules.pool_to_string(rules.apply_scale_to_damage_pool({"dice": 3, "pips": 1}, "speeder", "walker")), "3D+1", "lower scale weapon damage is unchanged")
	_assert_equal(rules.pool_to_string(rules.apply_scale_to_soak_pool({"dice": 6, "pips": 0}, "speeder", "walker")), "8D", "higher scale target adds adjusted modifier to soak")
	_assert_equal(rules.pool_to_string(rules.apply_scale_to_attack_pool({"dice": 4, "pips": 0}, "walker", "speeder")), "4D", "higher scale attack pool is unchanged")
	_assert_equal(rules.pool_to_string(rules.apply_scale_to_dodge_pool({"dice": 3, "pips": 0}, "walker", "speeder")), "5D", "lower scale target adds adjusted modifier to dodge")
	_assert_equal(rules.pool_to_string(rules.apply_scale_to_damage_pool({"dice": 5, "pips": 0}, "walker", "speeder")), "7D", "higher scale weapon adds adjusted modifier to damage")
	_assert_equal(rules.pool_to_string(rules.apply_scale_to_soak_pool({"dice": 2, "pips": 1}, "walker", "speeder")), "2D+1", "lower scale target soak is unchanged")
	var blast_vest := {
		"protection_physical": "1D",
		"protection_energy": "0D+1",
		"dexterity_penalty": "-1D",
	}
	_assert_equal(rules.pool_to_string(rules.armor_protection_pool(blast_vest, "physical")), "1D", "armor physical protection")
	_assert_equal(rules.pool_to_string(rules.armor_protection_pool(blast_vest, "energy")), "0D+1", "armor energy protection")
	_assert_equal(rules.pool_to_string(rules.armor_dexterity_penalty_pool(blast_vest)), "1D", "signed armor dex penalty parses as magnitude")
	_assert_equal(rules.pool_to_string(rules.apply_armor_dexterity_penalty({"dice": 4, "pips": 1}, blast_vest)), "3D+1", "armor dex penalty reduces dex skill pool")
	_assert_equal(rules.pool_to_string(rules.apply_armor_to_soak({"dice": 3, "pips": 0}, blast_vest, "energy")), "3D+1", "armor energy protection adds to soak")
	_assert_equal(rules.pool_to_string(rules.apply_armor_to_soak({"dice": 3, "pips": 0}, blast_vest, "physical", 2)), "4D+2", "armor quality pips amplify armor protection")

	var short_band: Dictionary = rules.range_band_for_distance(12.0)
	_assert_equal(short_band["name"], "Short", "12m is short range")
	_assert_equal(short_band["difficulty"], 10, "short range difficulty")

	var medium_band: Dictionary = rules.range_band_for_distance(24.0)
	_assert_equal(medium_band["name"], "Medium", "24m is medium range")
	_assert_equal(medium_band["difficulty"], 15, "medium range difficulty")

	var full_cover: Dictionary = rules.resolve_ranged_attack({"dice": 4, "pips": 1}, 12.0, 4)
	_assert_equal(full_cover["blocked"], true, "full cover blocks targeting")

	var cp_rng := RandomNumberGenerator.new()
	cp_rng.seed = 17
	var cp_dice: Dictionary = rules.roll_cp_dice(2, cp_rng)
	_assert_equal(cp_dice["count"], 2, "cp dice count")
	_assert_equal(int(cp_dice["total"]) > 0, true, "cp dice add a positive bonus")

	var no_cp_rng := RandomNumberGenerator.new()
	no_cp_rng.seed = 22
	var with_cp_rng := RandomNumberGenerator.new()
	with_cp_rng.seed = 22
	var no_cp_attack: Dictionary = rules.resolve_ranged_attack({"dice": 0, "pips": 0}, 12.0, 0, no_cp_rng)
	var cp_attack: Dictionary = rules.resolve_ranged_attack({"dice": 0, "pips": 0}, 12.0, 0, with_cp_rng, {}, 1)
	_assert_equal(cp_attack["attack"]["total"], no_cp_attack["attack"]["total"], "attack cp does not change base roll")
	_assert_equal(cp_attack["margin"] > no_cp_attack["margin"], true, "attack cp increases margin")

	var no_soak_cp_rng := RandomNumberGenerator.new()
	no_soak_cp_rng.seed = 33
	var soak_cp_rng := RandomNumberGenerator.new()
	soak_cp_rng.seed = 33
	var no_soak_cp_damage: Dictionary = rules.resolve_damage({"dice": 4, "pips": 0}, {"dice": 0, "pips": 0}, no_soak_cp_rng, false, 0)
	var soak_cp_damage: Dictionary = rules.resolve_damage({"dice": 4, "pips": 0}, {"dice": 0, "pips": 0}, soak_cp_rng, false, 1)
	_assert_equal(soak_cp_damage["damage_roll"]["total"], no_soak_cp_damage["damage_roll"]["total"], "soak cp does not change damage roll")
	_assert_equal(soak_cp_damage["margin"] < no_soak_cp_damage["margin"], true, "soak cp reduces damage margin")

	var dodge_rng := RandomNumberGenerator.new()
	dodge_rng.seed = 11
	var normal_dodge: Dictionary = rules.resolve_ranged_attack(
		{"dice": 0, "pips": 0},
		12.0,
		0,
		dodge_rng,
		{"type": "dodge", "pool": {"dice": 4, "pips": 0}, "action_count": 2}
	)
	_assert_equal(normal_dodge["defense"]["type"], "dodge", "normal dodge defense type")
	_assert_equal(normal_dodge["defense"]["replaces"], true, "normal dodge replaces range difficulty")
	_assert_equal(normal_dodge["defense"]["roll"]["pool"], "3D", "normal dodge applies multi-action penalty")
	_assert_equal(normal_dodge["difficulty"], normal_dodge["defense"]["value"], "normal dodge difficulty is defense roll without cover")

	var full_dodge_rng := RandomNumberGenerator.new()
	full_dodge_rng.seed = 11
	var full_dodge: Dictionary = rules.resolve_ranged_attack(
		{"dice": 0, "pips": 0},
		12.0,
		0,
		full_dodge_rng,
		{"type": "full_dodge", "pool": {"dice": 4, "pips": 0}, "action_count": 1}
	)
	_assert_equal(full_dodge["defense"]["type"], "full_dodge", "full dodge defense type")
	_assert_equal(full_dodge["defense"]["replaces"], false, "full dodge adds to range difficulty")
	_assert_equal(full_dodge["defense"]["roll"]["pool"], "4D", "full dodge keeps full dodge pool")
	_assert_equal(full_dodge["difficulty"], 10 + int(full_dodge["defense"]["value"]), "full dodge adds to short-range difficulty")

	var defense_cache_rng := RandomNumberGenerator.new()
	defense_cache_rng.seed = 44
	var cached_defense: Dictionary = rules.prepare_ranged_defense(
		{"type": "dodge", "pool": {"dice": 4, "pips": 0}, "action_count": 2},
		defense_cache_rng
	)
	_assert_equal(cached_defense.has("cached_roll"), true, "prepared defense stores cached roll")
	_assert_equal(cached_defense["cached_roll"]["pool"], "3D", "prepared normal dodge applies multi-action penalty once")
	var incoming_a_rng := RandomNumberGenerator.new()
	incoming_a_rng.seed = 45
	var incoming_b_rng := RandomNumberGenerator.new()
	incoming_b_rng.seed = 46
	var incoming_a: Dictionary = rules.resolve_ranged_attack({"dice": 3, "pips": 0}, 12.0, 0, incoming_a_rng, cached_defense)
	var incoming_b: Dictionary = rules.resolve_ranged_attack({"dice": 3, "pips": 0}, 12.0, 0, incoming_b_rng, cached_defense)
	_assert_equal(incoming_a["defense"]["value"], cached_defense["value"], "first incoming shot uses cached dodge")
	_assert_equal(incoming_b["defense"]["value"], cached_defense["value"], "second incoming shot reuses cached dodge")
	_assert_equal(incoming_a["difficulty"], incoming_b["difficulty"], "cached normal dodge gives same difficulty across incoming shots")

	var no_cover: Dictionary = rules.roll_cover_bonus(0)
	_assert_equal(no_cover["bonus"], 0, "no cover has no bonus")
	_assert_equal(no_cover["blocks_targeting"], false, "no cover does not block")

	_assert_equal(rules.wound_for_damage_margin(0)["key"], "no_damage", "zero damage margin")
	_assert_equal(rules.wound_for_damage_margin(3)["key"], "stunned", "stun damage margin")
	_assert_equal(rules.wound_for_damage_margin(8)["key"], "wounded", "wound damage margin")
	_assert_equal(rules.wound_for_damage_margin(12)["key"], "incapacitated", "incapacitated damage margin")
	_assert_equal(rules.wound_for_damage_margin(15)["key"], "mortally_wounded", "mortal damage margin")
	_assert_equal(rules.wound_for_damage_margin(16)["key"], "killed", "killed damage margin")

	var high_stun_rng := RandomNumberGenerator.new()
	high_stun_rng.seed = 7
	var stun_damage: Dictionary = rules.resolve_damage({"dice": 8, "pips": 0}, {"dice": 1, "pips": 0}, high_stun_rng, true)
	_assert_equal(stun_damage["wound"]["key"], "stunned_unconscious", "stun mode caps severe damage")

	rules.free()
	rules_script = null

	if _failures.is_empty():
		print("rules_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
