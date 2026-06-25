extends SceneTree
## Headless smoke test for the WEG chargen rules (C1).
## Verifies the 18D attribute budget (exact), species min/max ranges, the 7D skill
## budget (max), the produced sheet shape, and the deterministic default build.

const Chargen := preload("res://scripts/rules/chargen_model.gd")
const SPECIES_PATH := "res://data/species_clone_wars.json"

var _failures: Array[String] = []
var _rules: Object
var _species: Dictionary

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	_species = _load_species()
	var human: Dictionary = _species.get("human", {})
	_assert_true(not human.is_empty(), "human species loaded")

	# A valid 18D build: all six attributes at 3D (6 x 3D = 18D), within human 2D-4D.
	var ok := Chargen.validate_build(_rules, human, _uniform("3D"))
	_assert_true(bool(ok["valid"]), "all-3D human build is valid")
	var sheet: Dictionary = ok["sheet"]
	for key in ["attributes", "skills", "character_points", "force_points", "force_sensitive", "wound_state", "credits", "equipment"]:
		_assert_true(sheet.has(key), "sheet has '%s'" % key)
	_assert_true(String((sheet["equipment"] as Dictionary).get("weapon", "")) != "", "starter equipment includes a weapon")
	_assert_equal(int(sheet["character_points"]), 5, "starting CP 5")
	_assert_equal(int(sheet["force_points"]), 1, "starting FP 1")
	_assert_equal(bool(sheet["force_sensitive"]), false, "force-sensitivity defaults false")
	_assert_equal(String(sheet["wound_state"]), "healthy", "starts healthy")

	# Over budget (all 4D = 24D) and under budget (all 2D = 12D) are rejected.
	_assert_true(not bool(Chargen.validate_build(_rules, human, _uniform("4D"))["valid"]), "24D over budget rejected")
	_assert_true(not bool(Chargen.validate_build(_rules, human, _uniform("2D"))["valid"]), "12D under budget rejected")

	# Exactly 18D total but an attribute over the species max is rejected on range.
	var out_of_range := {"dexterity": "5D", "knowledge": "3D", "mechanical": "3D", "perception": "3D", "strength": "2D", "technical": "2D"}
	var oor := Chargen.validate_build(_rules, human, out_of_range)
	_assert_true(not bool(oor["valid"]), "attribute over species max rejected")
	_assert_true(_errors_mention(oor, "maximum"), "range error names the maximum")

	# A missing attribute is rejected.
	var missing := _uniform("3D")
	missing.erase("technical")
	_assert_true(not bool(Chargen.validate_build(_rules, human, missing)["valid"]), "missing attribute rejected")

	# Skills: within the 7D budget valid; over it rejected.
	var with_skills := Chargen.validate_build(_rules, human, _uniform("3D"), {"blaster": "2D", "dodge": "1D+1"})
	_assert_true(bool(with_skills["valid"]), "skills within 7D are valid")
	_assert_equal(int(with_skills["skill_pips_spent"]), 10, "skill pips counted (2D + 1D+1 = 10)")
	var over_skills := Chargen.validate_build(_rules, human, _uniform("3D"), {"blaster": "5D", "dodge": "5D"})
	_assert_true(not bool(over_skills["valid"]), "skills over the 7D budget rejected")

	# Default build is valid for a uniform species (human -> all 3D) and a skewed one.
	var human_default := Chargen.default_build(_rules, human)
	_assert_true(bool(Chargen.validate_build(_rules, human, human_default)["valid"]), "default human build is valid")
	_assert_equal(String(human_default["dexterity"]), "3D", "uniform species default is the midpoint (3D)")
	if _species.has("wookiee"):
		var wk_default := Chargen.default_build(_rules, _species["wookiee"])
		_assert_true(bool(Chargen.validate_build(_rules, _species["wookiee"], wk_default)["valid"]), "default build respects a skewed species' ranges")

	if _rules.has_method("free"):
		_rules.free()
	_finish()

func _uniform(code: String) -> Dictionary:
	var d := {}
	for a in Chargen.ATTRS:
		d[a] = code
	return d

func _errors_mention(result: Dictionary, needle: String) -> bool:
	for e in result.get("errors", []):
		if String(e).to_lower().contains(needle.to_lower()):
			return true
	return false

func _load_species() -> Dictionary:
	var file := FileAccess.open(SPECIES_PATH, FileAccess.READ)
	if file == null:
		_failures.append("species file opens")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("species parses")
		return {}
	return (parsed as Dictionary).get("species", {})

func _finish() -> void:
	if _failures.is_empty():
		print("chargen_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
