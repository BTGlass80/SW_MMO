extends SceneTree
## Headless smoke test for the chargen reserved / canonical-name policy (Wave G item G7).
##
## Players can otherwise self-name as canonical Star Wars figures (e.g. "Ahsoka"), which
## pollutes the era/canon grep and breaks the project's "Canonical Clone Wars figures never
## appear as open-world NPCs" invariant (ported from C:\SW_MUSH\CLAUDE.md and
## C:\SW_MUSH\engine\chargen_validator.py, one-way / read-only). This asserts
## `ChargenModel.is_reserved_name` rejects the famous figures (case-insensitively), accepts
## ordinary original names, does not false-positive on substrings, and that the chargen
## `validate_build` path itself rejects a build that names a reserved figure.

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

	# --- Reserved names are rejected, case-insensitively. ---
	for reserved_case in ["Ahsoka", "ahsoka", "AHSOKA", "aHsOka"]:
		_assert_true(Chargen.is_reserved_name(reserved_case), "'%s' is reserved" % reserved_case)
	for reserved_case in ["Kenobi", "kenobi", "KENOBI"]:
		_assert_true(Chargen.is_reserved_name(reserved_case), "'%s' is reserved" % reserved_case)
	for reserved_case in ["Skywalker", "skywalker", "SkyWalker"]:
		_assert_true(Chargen.is_reserved_name(reserved_case), "'%s' is reserved" % reserved_case)
	for reserved_case in ["Grievous", "grievous", "GRIEVOUS"]:
		_assert_true(Chargen.is_reserved_name(reserved_case), "'%s' is reserved" % reserved_case)
	for reserved_case in ["Dooku", "dooku", "DOOKU"]:
		_assert_true(Chargen.is_reserved_name(reserved_case), "'%s' is reserved" % reserved_case)

	# Reserved names still trip when embedded as a whole token/word inside a longer name.
	_assert_true(Chargen.is_reserved_name("Ahsoka Nobody"), "reserved first token in a full name")
	_assert_true(Chargen.is_reserved_name("Master Kenobi"), "reserved surname preceded by a title")
	_assert_true(Chargen.is_reserved_name("Obi-Wan Kenobi"), "full canonical name rejected")
	_assert_true(Chargen.is_reserved_name("shaak ti"), "multi-word reserved entry matches full name")
	_assert_true(Chargen.is_reserved_name("Shaak Ti"), "multi-word reserved entry matches full name, mixed case")

	# --- Ordinary original names are accepted (no false positives). ---
	for ok_name in ["Vesh Talro", "Mara Jynn", "Rennick"]:
		_assert_true(not Chargen.is_reserved_name(ok_name), "'%s' is not reserved" % ok_name)

	# --- Substrings of a reserved word must NOT false-positive (whole-token match only). ---
	for substring_name in ["Kenobiwan", "Reximus", "Skywalkerton", "Solomon"]:
		_assert_true(not Chargen.is_reserved_name(substring_name),
			"'%s' merely contains a reserved word and must not be rejected" % substring_name)

	# Empty / blank names are not flagged as reserved (that's a separate "name required"
	# concern, not this policy's job).
	_assert_true(not Chargen.is_reserved_name(""), "empty name is not reserved")
	_assert_true(not Chargen.is_reserved_name("   "), "blank name is not reserved")

	# --- The chargen validation path itself enforces the policy. ---
	var uniform_3d := {}
	for a in Chargen.ATTRS:
		uniform_3d[a] = "3D"

	var reserved_build := Chargen.validate_build(_rules, human, uniform_3d, {}, "Ahsoka")
	_assert_true(not bool(reserved_build["valid"]), "build named 'Ahsoka' is rejected")
	_assert_true(_errors_mention(reserved_build, "reserved"), "rejection names the reserved-name reason")

	var ok_build := Chargen.validate_build(_rules, human, uniform_3d, {}, "Vesh Talro")
	_assert_true(bool(ok_build["valid"]), "build named 'Vesh Talro' is valid")

	# A build with no name supplied (default "") is unaffected by the name policy — the
	# 18D allocation alone still determines validity.
	var no_name_build := Chargen.validate_build(_rules, human, uniform_3d)
	_assert_true(bool(no_name_build["valid"]), "build with no name argument is unaffected by the name policy")

	if _rules.has_method("free"):
		_rules.free()
	_finish()

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
		print("name_policy_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)
