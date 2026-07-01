extends SceneTree
## Drift guard: data/schemas/player_persistence.schema.json must declare EVERY top-level key the live
## save path can write (the root is additionalProperties:false). This caught real drift: the code
## persists top-level `zone` (submit_change_zone, DIV-0014) + `account_secret` (register_account, E26)
## that the schema previously forbade. The test fails the gate if a future field is added to the
## record without being declared in the schema, OR if a schema-required root field is dropped from
## default_record — keeping the persistence contract honest until the planned accounts/SQLite shape.

const PersistenceStore = preload("res://scripts/net/persistence_store.gd")
const ChargenModel = preload("res://scripts/rules/chargen_model.gd")
const EconomyModel = preload("res://scripts/rules/economy_model.gd")
const SCHEMA_PATH := "res://data/schemas/player_persistence.schema.json"

var _failures: Array[String] = []

func _init() -> void:
	# --- Load the schema's declared root property names + required list ---
	var schema: Dictionary = {}
	var f := FileAccess.open(SCHEMA_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			schema = parsed
	_assert_true(not schema.is_empty(), "persistence schema parses as a dict")
	_assert_equal(bool(schema.get("additionalProperties", true)), false, "schema root forbids undeclared props (additionalProperties:false)")
	var declared := {}
	for k in (schema.get("properties", {}) as Dictionary):
		declared[k] = true
	var required: Array = schema.get("required", [])

	# --- Build a record exactly as the live server does: default_record + the top-level mutations the
	#     net layer applies (travel zone, account secret, save timestamp, org/city/world_hooks/species)
	#     + apply_position/apply_combat. ---
	var store = PersistenceStore.new("user://schema_test")
	var record: Dictionary = store.default_record("char_x", "acct_x", "Tester", Vector3(1, 1.2, 2))
	record["zone"] = "tatooine.dune_sea"               # submit_change_zone (DIV-0014)
	record["account_secret"] = "abc123"                # register_account (E26)
	record["last_saved_unix"] = 0.0                    # stamped on save (F56 atomic write)
	record["org"] = {"faction_id": "org_hutt_cartel"}  # build.org / loaded membership
	record["city_role"] = null                         # loaded city role (may be null)
	record["world_hooks"] = {"pending_zone_influence": []}
	record["species"] = "Human"
	record = PersistenceStore.apply_position(record, Vector3(3, 1.2, 4), 0.5)
	record = PersistenceStore.apply_combat(record, {"player_wound_severity": 1})

	# Every top-level key the code produced MUST be declared in the schema (additionalProperties:false).
	for key in record:
		_assert_true(declared.has(key), "live record key '%s' is declared in the schema" % String(key))
	# The two fields that drifted are explicitly covered.
	_assert_true(declared.has("zone"), "schema declares the live `zone` field")
	_assert_true(declared.has("account_secret"), "schema declares the `account_secret` field")

	# Every schema-required root key MUST be produced by a fresh default_record (a new char conforms).
	var base: Dictionary = store.default_record("char_y", "acct_y", "Base", Vector3.ZERO)
	for req in required:
		_assert_true(base.has(req), "default_record produces the schema-required key '%s'" % String(req))

	# --- SHEET-level drift: the schema's sheet is additionalProperties:false, so EVERY key a real
	#     chargen sheet produces (equipment/inventory/force_skills/credits/...) must be declared. ---
	var sheet_schema: Dictionary = (schema.get("properties", {}) as Dictionary).get("sheet", {})
	_assert_equal(bool(sheet_schema.get("additionalProperties", true)), false, "schema sheet forbids undeclared props")
	var sheet_declared := {}
	for k in (sheet_schema.get("properties", {}) as Dictionary):
		sheet_declared[k] = true
	var d6 = load("res://scripts/rules/d6_rules.gd").new()
	var chargen_sheet: Dictionary = ChargenModel.build_sheet(d6, {"dexterity": "3D", "knowledge": "2D", "mechanical": "2D", "perception": "3D", "strength": "2D", "technical": "2D"}, {"blaster": "4D"})
	for key in chargen_sheet:
		_assert_true(sheet_declared.has(key), "chargen sheet key '%s' is declared in the schema sheet" % String(key))
	_assert_true(sheet_declared.has("inventory"), "schema sheet declares inventory (E22 + Wave F economy)")
	_assert_true(sheet_declared.has("equipment"), "schema sheet declares equipment")
	_assert_equal(int(chargen_sheet.get("credits", -1)), int(EconomyModel.STARTING_CREDITS), "chargen seeds STARTING_CREDITS (1000)")
	d6.free()  # d6_rules extends Node — free it or the gate flags a leaked ObjectDB instance

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("persistence_schema_smoke: OK")
		quit(0)
	else:
		for fail in _failures:
			printerr(fail)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
