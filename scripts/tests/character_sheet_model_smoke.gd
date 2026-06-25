extends SceneTree

const CHARACTER_DATA_PATH = "res://data/prototype_characters.json"
const SKILL_CATALOG_PATH = "res://data/prototype_skill_catalog.json"
const COMBATANT_DATA_PATH = "res://data/prototype_combatants.json"

var _failures = []

func _init() -> void:
	var rules_script = load("res://scripts/rules/d6_rules.gd")
	var rules = rules_script.new()
	var model_script = load("res://scripts/rules/character_sheet_model.gd")
	var model = model_script.new()

	var catalog = _load_json(SKILL_CATALOG_PATH)
	var character_data = _load_json(CHARACTER_DATA_PATH)
	var gear = _load_json(COMBATANT_DATA_PATH)
	var character_map = character_data.get("characters", {})
	var sheet = character_map.get("range_trainee", {})

	_assert_equal(model.canonical_key("Starship Gunnery"), "starship_gunnery", "canonical skill key")
	_assert_equal(model.skill_attribute(catalog, "Blaster"), "dexterity", "blaster parent attribute")

	var dex_pool = model.attribute_pool(rules, sheet, "dexterity")
	_assert_equal(rules.pool_to_string(dex_pool), "3D", "dexterity attribute pool")

	var blaster_pool = model.skill_pool(rules, sheet, catalog, "blaster")
	_assert_equal(rules.pool_to_string(blaster_pool), "4D+1", "blaster skill pool from attribute plus bonus")

	var dodge_pool = model.skill_pool(rules, sheet, catalog, "dodge")
	_assert_equal(rules.pool_to_string(dodge_pool), "4D", "dodge skill pool from attribute plus bonus")

	var sensors_pool = model.skill_pool(rules, sheet, catalog, "sensors")
	_assert_equal(rules.pool_to_string(sensors_pool), "4D", "sensors mechanical skill pool")

	var unknown_pool = model.skill_pool(rules, sheet, catalog, "unknown")
	_assert_equal(rules.pool_to_string(unknown_pool), "0D", "unknown skill has no pool")

	var combat_pools = model.combat_pools_from_sheet(rules, sheet, catalog, gear)
	var player_armor = combat_pools.get("player_armor", {})
	_assert_equal(rules.pool_to_string(combat_pools["attacker_pool"]), "4D+1", "combat attacker pool")
	_assert_equal(rules.pool_to_string(combat_pools["player_dodge_pool"]), "4D", "combat dodge pool")
	_assert_equal(rules.pool_to_string(combat_pools["damage_pool"]), "4D", "combat weapon damage")
	_assert_equal(rules.pool_to_string(combat_pools["player_soak_pool"]), "3D", "combat strength soak")
	_assert_equal(player_armor.get("name", ""), "Training Blast Vest", "combat armor lookup")
	_assert_equal(combat_pools["character_points"], 5, "combat character points")
	_assert_equal(combat_pools["force_points"], 1, "combat force points")

	var armor_lines: PackedStringArray = model.armor_summary_lines(player_armor, -1)
	_assert_equal(armor_lines.size(), 3, "armor summary line count")
	_assert_equal(armor_lines[0], "Armor: Training Blast Vest E0D+1 P1D Dex0D", "armor summary protection")
	_assert_equal(armor_lines[1], "Coverage: torso", "armor summary coverage")
	_assert_equal(armor_lines[2], "Quality: -1 pips", "armor summary quality")
	_assert_equal(model.armor_summary_lines({}, 0)[0], "Armor: None", "empty armor summary")

	rules.free()
	if _failures.is_empty():
		print("character_sheet_model_smoke: OK")
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
