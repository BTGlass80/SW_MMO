extends SceneTree
## Headless smoke test for the curated Clone Wars content drop (skills, species,
## weapons, armor) ported one-way from the read-only SW_MUSH. Validates each file
## parses, carries provenance, and has the expected shape, so the data cannot
## silently rot as the game consumes it. Does NOT assert exact counts beyond floors
## (content will grow).

const SKILL_CATALOG := "res://data/weg_skill_catalog.json"
const SPECIES := "res://data/species_clone_wars.json"
const WEAPONS := "res://data/weapons_clone_wars.json"
const ARMOR := "res://data/armor_clone_wars.json"
const STARSHIPS := "res://data/starships_clone_wars.json"
const DROIDS := "res://data/droids_clone_wars.json"
const CREATURES := "res://data/creatures_clone_wars.json"
const ATTRIBUTES := ["dexterity", "knowledge", "mechanical", "perception", "strength", "technical"]
# GCW/Imperial-era craft that must NOT appear in the Clone Wars starship roster.
const FORBIDDEN_SHIPS := ["x_wing", "a_wing", "b_wing", "tie_fighter", "tie_interceptor", "tie_bomber", "lambda_shuttle", "imperial_star_destroyer"]

var _failures: Array[String] = []

func _init() -> void:
	var skills := _load(SKILL_CATALOG)
	var species := _load(SPECIES)
	var weapons := _load(WEAPONS)
	var armor := _load(ARMOR)

	for d in [skills, species, weapons, armor]:
		_assert_true(d.has("source") or d.has("source_policy"), "content file carries provenance")

	# Skill catalog: grouped by the six WEG attributes; a known skill is present.
	var groups: Dictionary = skills.get("skills", {})
	var total := 0
	for attribute in ATTRIBUTES:
		_assert_true(groups.has(attribute), "skill catalog has '%s' group" % attribute)
		var list: Array = groups.get(attribute, [])
		total += list.size()
	_assert_true(total >= 70, "skill catalog has the full WEG skill list (got %d)" % total)
	_assert_true(_skill_attribute(groups, "blaster") == "dexterity", "blaster is a dexterity skill")
	_assert_true(_skill_attribute(groups, "starship_gunnery") == "mechanical", "starship gunnery is mechanical")

	# Species: keyed dict including the human baseline; entries have names.
	var species_map: Dictionary = species.get("species", {})
	_assert_true(species_map.size() >= 6, "at least six playable species (got %d)" % species_map.size())
	_assert_true(species_map.has("human"), "human species present")
	for key in species_map:
		_assert_true(String((species_map[key] as Dictionary).get("name", "")) != "", "species '%s' has a name" % key)

	# Weapons: damage + damage type on every entry.
	var weapon_map: Dictionary = weapons.get("weapons", {})
	_assert_true(weapon_map.size() >= 20, "at least twenty weapons (got %d)" % weapon_map.size())
	for key in weapon_map:
		var w: Dictionary = weapon_map[key]
		_assert_true(String(w.get("damage", "")) != "", "weapon '%s' has damage" % key)
		_assert_true(String(w.get("damage_type", "")) != "", "weapon '%s' has a damage type" % key)

	# Armor: coverage + at least one protection band on every entry.
	var armor_map: Dictionary = armor.get("armor", {})
	_assert_true(armor_map.size() >= 10, "at least ten armors (got %d)" % armor_map.size())
	for key in armor_map:
		var a: Dictionary = armor_map[key]
		_assert_true((a.get("coverage", []) as Array).size() > 0, "armor '%s' has coverage" % key)
		_assert_true(a.has("protection_energy") or a.has("protection_physical"), "armor '%s' has protection" % key)

	# Content drop 2: starships, droids, creatures.
	var starships := _load(STARSHIPS)
	var droids := _load(DROIDS)
	var creatures := _load(CREATURES)
	for d in [starships, droids, creatures]:
		_assert_true(d.has("source") or d.has("source_policy"), "drop-2 file carries provenance")

	var ship_map: Dictionary = starships.get("starships", {})
	_assert_true(ship_map.size() >= 5, "at least five starships (got %d)" % ship_map.size())
	for key in ship_map:
		var s: Dictionary = ship_map[key]
		_assert_true(String(s.get("scale", "")) != "" and String(s.get("hull", "")) != "", "starship '%s' has scale + hull" % key)
		_assert_true(not FORBIDDEN_SHIPS.has(key), "no GCW/Imperial-era ship '%s' in the Clone Wars roster" % key)

	var droid_map: Dictionary = droids.get("droids", {})
	_assert_true(droid_map.size() >= 3, "at least three droids (got %d)" % droid_map.size())
	for key in droid_map:
		_assert_true(String((droid_map[key] as Dictionary).get("name", "")) != "", "droid '%s' has a name" % key)

	var creature_map: Dictionary = creatures.get("creatures", {})
	_assert_true(creature_map.size() >= 15, "at least fifteen creatures (got %d)" % creature_map.size())
	for key in creature_map:
		var c: Dictionary = creature_map[key]
		_assert_true(String(c.get("name", "")) != "" and String(c.get("scale", "")) != "", "creature '%s' has name + scale" % key)

	_finish()

func _skill_attribute(groups: Dictionary, skill_key: String) -> String:
	for attribute in groups:
		for entry in groups[attribute]:
			if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("key", "")) == skill_key:
				return String((entry as Dictionary).get("attribute", attribute))
	return ""

func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % path)
		return {}
	return parsed

func _finish() -> void:
	if _failures.is_empty():
		print("content_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)
