extends SceneTree
## Headless smoke for the equipment / inventory model (E22 / D3). Verifies the pure
## equip-swap validation the server's submit_equip RPC drives: a valid OWNED swap
## updates equipment (non-mutating) and changes the weapon's damage source; bad slot /
## unknown item / unowned item are rejected; and the no-inventory fallback owns equipped
## gear. Mirrors what submit_equip does (network_manager is a Node autoload, untestable).

const Equipment := preload("res://scripts/rules/equipment_model.gd")
const Chargen := preload("res://scripts/rules/chargen_model.gd")
const WEAPONS_PATH := "res://data/weapons_clone_wars.json"
const ARMOR_PATH := "res://data/armor_clone_wars.json"
const SPECIES_PATH := "res://data/species_clone_wars.json"

var _failures: Array[String] = []

func _init() -> void:
	var rules: Object = load("res://scripts/rules/d6_rules.gd").new()
	var weapons: Dictionary = _load_container(WEAPONS_PATH, "weapons")
	var armor: Dictionary = _load_container(ARMOR_PATH, "armor")
	var human: Dictionary = (_load_json(SPECIES_PATH).get("species", {}) as Dictionary).get("human", {})
	var sheet: Dictionary = Chargen.default_sheet(rules, human)

	# Starter inventory + equipment.
	_assert_true((sheet.get("inventory", []) as Array).has("hold_out_blaster"), "starter inventory owns an alt weapon")
	_assert_true((sheet.get("inventory", []) as Array).has("blast_helmet"), "starter inventory owns an alt armor")
	_assert_equal(String((sheet.get("equipment", {}) as Dictionary).get("weapon", "")), "blaster_pistol", "starts equipped with the blaster pistol")

	# Valid weapon swap (owned + in catalog): accepted, non-mutating, equipment updated.
	var r: Dictionary = Equipment.equip(sheet, "weapon", "hold_out_blaster", weapons, armor)
	_assert_true(bool(r["ok"]), "valid owned weapon swap accepted")
	_assert_equal(String((r["sheet"]["equipment"] as Dictionary)["weapon"]), "hold_out_blaster", "equipment updated to the new weapon")
	_assert_equal(String((sheet["equipment"] as Dictionary)["weapon"]), "blaster_pistol", "equip is non-mutating (original sheet unchanged)")
	# The swap changes the damage source (the read-path builds damage from this).
	_assert_true(String(weapons["blaster_pistol"]["damage"]) != String(weapons["hold_out_blaster"]["damage"]),
		"the swapped weapon has a different damage code")

	# Valid armor swap.
	var ra: Dictionary = Equipment.equip(sheet, "armor", "blast_helmet", weapons, armor)
	_assert_true(bool(ra["ok"]), "valid owned armor swap accepted")
	_assert_equal(String((ra["sheet"]["equipment"] as Dictionary)["armor"]), "blast_helmet", "armor slot updated")

	# Rejections.
	var bad_slot: Dictionary = Equipment.equip(sheet, "boots", "blaster_pistol", weapons, armor)
	_assert_true(not bool(bad_slot["ok"]) and String(bad_slot["reason"]) == "bad_slot", "unknown slot rejected (bad_slot)")
	var unknown: Dictionary = Equipment.equip(sheet, "weapon", "nonexistent_blaster", weapons, armor)
	_assert_true(not bool(unknown["ok"]) and String(unknown["reason"]) == "unknown_item", "item not in catalog rejected (unknown_item)")

	# Not-owned: blaster_rifle is a REAL catalog weapon but NOT in the starter inventory.
	_assert_true(weapons.has("blaster_rifle"), "data sanity: blaster_rifle is a real weapon")
	_assert_true(not (sheet.get("inventory", []) as Array).has("blaster_rifle"), "data sanity: blaster_rifle not owned at start")
	var unowned: Dictionary = Equipment.equip(sheet, "weapon", "blaster_rifle", weapons, armor)
	_assert_true(not bool(unowned["ok"]) and String(unowned["reason"]) == "not_owned", "unowned item rejected (not_owned)")

	# No-inventory fallback: a pre-inventory save still owns its equipped gear.
	var bare: Dictionary = {"equipment": {"weapon": "blaster_pistol", "armor": "blast_vest"}}
	_assert_true(Equipment.owns_item(bare, "blaster_pistol"), "fallback owns the equipped weapon")
	_assert_true(not Equipment.owns_item(bare, "hold_out_blaster"), "fallback does not own un-equipped items")
	_assert_true(bool(Equipment.equip(bare, "weapon", "blaster_pistol", weapons, armor)["ok"]), "fallback can re-equip the equipped weapon")

	if rules.has_method("free"):
		rules.free()

	if _failures.is_empty():
		print("equip_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _load_json(path: String) -> Dictionary:
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

func _load_container(path: String, key: String) -> Dictionary:
	var data := _load_json(path)
	var inner: Variant = data.get(key, {})
	return inner if typeof(inner) == TYPE_DICTIONARY else {}

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
