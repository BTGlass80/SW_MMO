extends SceneTree

const SPECIES_DATA_PATH = "res://data/species_clone_wars.json"

var _failures = []

func _init() -> void:
	var rules_script = load("res://scripts/rules/d6_rules.gd")
	var rules = rules_script.new()
	var model_script = load("res://scripts/rules/derived_stats_model.gd")
	var model = model_script.new()

	# Small in-test sheet literal (do NOT depend on chargen).
	var sheet = {
		"name": "Test Trainee",
		"species": "human",
		"attributes": {
			"dexterity": "3D",
			"knowledge": "2D",
			"mechanical": "2D",
			"perception": "3D",
			"strength": "3D",
			"technical": "2D",
		},
	}

	# A second sheet to verify the STR dice count for a "3D+2" Strength.
	var strong_sheet = {
		"name": "Test Brawler",
		"species": "wookiee",
		"attributes": {
			"strength": "3D+2",
		},
	}

	var species_data = _load_json(SPECIES_DATA_PATH)

	# move_for_species: real "human" move from data == 10.
	_assert_equal(model.move_for_species(species_data, "human"), 10, "human move from species data")
	# Canonicalization works for label-cased species too.
	_assert_equal(model.move_for_species(species_data, "Human"), 10, "human move via Human label")
	# Missing species defaults to 10.
	_assert_equal(model.move_for_species(species_data, "ewok"), 10, "missing species defaults to 10 move")
	# Empty / malformed data defaults to 10.
	_assert_equal(model.move_for_species({}, "human"), 10, "empty species data defaults to 10 move")

	# base_soak == STR pool ("3D").
	var soak = model.base_soak(rules, sheet)
	_assert_equal(rules.pool_to_string(soak), "3D", "base soak equals strength pool")

	# strength_melee_bonus == STR pool ("3D").
	var melee_bonus = model.strength_melee_bonus(rules, sheet)
	_assert_equal(rules.pool_to_string(melee_bonus), "3D", "strength melee bonus equals strength pool")

	# melee_damage_pool with empty bonus == STR pool.
	var melee_no_bonus = model.melee_damage_pool(rules, sheet, "")
	_assert_equal(rules.pool_to_string(melee_no_bonus), "3D", "melee damage with no weapon bonus equals strength")

	# melee_damage_pool with "+2" adds two pips ("3D" -> "3D+2").
	var melee_plus2 = model.melee_damage_pool(rules, sheet, "+2")
	_assert_equal(rules.pool_to_string(melee_plus2), "3D+2", "melee damage adds +2 pip weapon bonus")

	# melee_damage_pool with "1D" weapon STR-bonus adds a die ("3D" -> "4D").
	var melee_plus1d = model.melee_damage_pool(rules, sheet, "1D")
	_assert_equal(rules.pool_to_string(melee_plus1d), "4D", "melee damage adds 1D weapon bonus")

	# stun_knockout_threshold == STR dice count (3 for "3D").
	_assert_equal(model.stun_knockout_threshold(rules, sheet), 3, "stun knockout threshold equals strength dice (3D)")

	# stun_knockout_threshold counts dice only, ignoring pips (3 for "3D+2").
	_assert_equal(model.stun_knockout_threshold(rules, strong_sheet), 3, "stun knockout threshold ignores pips (3D+2 -> 3)")

	rules.free()
	if _failures.is_empty():
		print("derived_stats_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _load_json(path):
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % path)
		return {}
	return parsed

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
