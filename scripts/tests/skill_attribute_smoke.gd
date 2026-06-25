extends SceneTree
## Headless smoke test for skill->governing-attribute lookup.
##
## Replicates the logic of _load_skill_attributes() and _attribute_for_skill()
## from scripts/net/network_manager.gd against res://data/weg_skill_catalog.json.
##
## The catalog shape is:
##   { "skills": { "<attribute>": [ { "key": "...", "attribute": "...", ... }, ... ] } }
##
## _load_skill_attributes() iterates groups[attribute] entries and maps
##   out[entry.key] = entry.attribute   (entry.attribute always equals the outer key
##   in the current catalog, but the code uses the per-entry field, not the outer key).
##
## _attribute_for_skill() does _skill_attr.get(skill, "dexterity") — unknown key
## falls back to "dexterity".

const SKILL_CATALOG_PATH = "res://data/weg_skill_catalog.json"

var _failures: Array[String] = []

func _init() -> void:
	# --- load catalog exactly as network_manager._load_skill_attributes() does ---
	if not FileAccess.file_exists(SKILL_CATALOG_PATH):
		_failures.append("catalog file missing: " + SKILL_CATALOG_PATH)
		_finish()
		return

	var file = FileAccess.open(SKILL_CATALOG_PATH, FileAccess.READ)
	if file == null:
		_failures.append("catalog file could not be opened: " + SKILL_CATALOG_PATH)
		_finish()
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("catalog file did not parse as Dictionary")
		_finish()
		return

	# Build the skill->attribute map (mirrors _load_skill_attributes verbatim)
	var skill_attr: Dictionary = {}
	var groups: Dictionary = (parsed as Dictionary).get("skills", {})
	for attribute in groups:
		for entry in groups[attribute]:
			if typeof(entry) == TYPE_DICTIONARY:
				skill_attr[String((entry as Dictionary).get("key", ""))] = \
					String((entry as Dictionary).get("attribute", attribute))

	# _attribute_for_skill() helper (mirrors line 381 of network_manager.gd)
	# Returns "dexterity" for unknown keys.

	# --- sanity: map is not empty ---
	_assert_true(skill_attr.size() > 0, "skill_attr map is non-empty after load")

	# --- known DEX skills ---
	_assert_equal(skill_attr.get("blaster", ""), "dexterity",
		"blaster -> dexterity")
	_assert_equal(skill_attr.get("dodge", ""), "dexterity",
		"dodge -> dexterity")
	_assert_equal(skill_attr.get("lightsaber", ""), "dexterity",
		"lightsaber -> dexterity")
	_assert_equal(skill_attr.get("melee_combat", ""), "dexterity",
		"melee_combat -> dexterity")

	# --- known MECHANICAL skills ---
	_assert_equal(skill_attr.get("starship_gunnery", ""), "mechanical",
		"starship_gunnery -> mechanical")
	_assert_equal(skill_attr.get("starfighter_piloting", ""), "mechanical",
		"starfighter_piloting -> mechanical")
	_assert_equal(skill_attr.get("astrogation", ""), "mechanical",
		"astrogation -> mechanical")

	# --- known KNOWLEDGE skills ---
	_assert_equal(skill_attr.get("streetwise", ""), "knowledge",
		"streetwise -> knowledge")
	_assert_equal(skill_attr.get("willpower", ""), "knowledge",
		"willpower -> knowledge")

	# --- known PERCEPTION skills ---
	_assert_equal(skill_attr.get("command", ""), "perception",
		"command -> perception")
	_assert_equal(skill_attr.get("bargain", ""), "perception",
		"bargain -> perception")

	# --- known STRENGTH skills ---
	_assert_equal(skill_attr.get("brawling", ""), "strength",
		"brawling -> strength")
	_assert_equal(skill_attr.get("stamina", ""), "strength",
		"stamina -> strength")

	# --- known TECHNICAL skills ---
	_assert_equal(skill_attr.get("first_aid", ""), "technical",
		"first_aid -> technical")
	_assert_equal(skill_attr.get("security", ""), "technical",
		"security -> technical")
	_assert_equal(skill_attr.get("computer_programming_repair", ""), "technical",
		"computer_programming_repair -> technical")

	# --- catalog completeness: all six attributes must be represented ---
	var seen_attributes: Dictionary = {}
	for sk in skill_attr:
		seen_attributes[skill_attr[sk]] = true
	for attr in ["dexterity", "knowledge", "mechanical", "perception", "strength", "technical"]:
		_assert_true(seen_attributes.has(attr), "attribute group present: " + attr)

	# --- total skill count matches catalog (76 skills: the 75 ported from
	# SW_MUSH plus powersuit_operation added per 2026-06-13 design note) ---
	_assert_equal(skill_attr.size(), 76, "catalog loads exactly 76 skills")

	# --- unknown skill falls back to "dexterity" (mirrors _attribute_for_skill) ---
	var unknown_attr: String = String(skill_attr.get("totally_unknown_skill", "dexterity"))
	_assert_equal(unknown_attr, "dexterity",
		"unknown skill default is dexterity")

	# --- key collision guard: each entry's "attribute" field matches its group key ---
	# The catalog currently stores attribute on each entry AND as the outer key;
	# both must agree or _load_skill_attributes would silently return the wrong attribute.
	var mismatch_count: int = 0
	for outer_attr in groups:
		for entry in groups[outer_attr]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var entry_attr: String = String((entry as Dictionary).get("attribute", outer_attr))
			if entry_attr != outer_attr:
				mismatch_count += 1
	_assert_equal(mismatch_count, 0,
		"no entry has a per-entry attribute that disagrees with its group key")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("skill_attribute_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true, got false" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
