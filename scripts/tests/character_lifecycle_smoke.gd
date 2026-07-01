extends SceneTree
## Smoke test: chargen -> persistence -> reload round-trip (E18).
##
## Exercises:
##   ChargenModel.default_sheet()   -- build a fresh starting sheet from species data
##   ChargenModel.validate_build()  -- validate an explicit allocation
##   PersistenceStore.save_record() -- save to a throwaway user:// path
##   PersistenceStore.load_record() -- reload and assert field-for-field parity
##   PersistenceStore.apply_combat() / combat_from_record() -- sheet-state helpers
##   wound_state_for_severity / severity_for_wound_state -- codec round-trip
##
## Uses a throwaway subdirectory inside user://  (never user://persistence) and
## removes it when done.  No RNG randomize() is called; seeding is explicit.

const SPECIES_PATH := "res://data/species_clone_wars.json"
const THROWAWAY_DIR := "user://test_lifecycle_smoke_tmp"

var _failures: Array[String] = []

func _init() -> void:
	# Load scripts (never use := on untyped load results).
	var rules_script = load("res://scripts/rules/d6_rules.gd")
	var chargen_script = load("res://scripts/rules/chargen_model.gd")
	var store_script = load("res://scripts/net/persistence_store.gd")

	var rules = rules_script.new()
	# chargen_model and persistence_store are RefCounted; they hold no Node state.
	# We do not call .new() on chargen_model since all its methods are static —
	# we call them directly on the class (loaded script).

	# ------------------------------------------------------------------ #
	# 1. Load species data
	# ------------------------------------------------------------------ #
	var species_data = _load_json(SPECIES_PATH)
	_assert_true(not species_data.is_empty(), "species data loaded from disk")
	var species_map = species_data.get("species", {})
	_assert_true(species_map.has("human"), "species map has human entry")

	var human_species = species_map.get("human", {})

	# ------------------------------------------------------------------ #
	# 2. Build a default sheet for a Human
	# ------------------------------------------------------------------ #
	var sheet = chargen_script.default_sheet(rules, human_species)
	_assert_true(not sheet.is_empty(), "default_sheet returns non-empty dict")

	# WEG R&E starting values (chargen_model.gd lines 19-20, 86-87)
	_assert_equal(sheet.get("character_points"), 5,          "default sheet CP == 5")
	_assert_equal(sheet.get("force_points"),     1,          "default sheet FP == 1")
	_assert_equal(sheet.get("wound_state"),      "healthy",  "default sheet wound_state == healthy")
	_assert_equal(sheet.get("force_sensitive"),  false,      "default sheet force_sensitive == false")
	_assert_equal(sheet.get("credits"),          1000,       "default sheet credits == 1000 (Wave F WEG-anchored economy)")

	# Equipment block (chargen_model.gd line 86 STARTER_WEAPON / STARTER_ARMOR)
	var equip = sheet.get("equipment", {})
	_assert_equal(equip.get("weapon"), "blaster_pistol", "default equipment weapon")
	_assert_equal(equip.get("armor"),  "blast_vest",     "default equipment armor")

	# Attributes block must contain all six attributes (chargen_model.gd ATTRS)
	var attrs = sheet.get("attributes", {})
	for attr in ["dexterity", "knowledge", "mechanical", "perception", "strength", "technical"]:
		_assert_true(attrs.has(attr), "default sheet has attribute: %s" % attr)

	# All six attributes together must total exactly 18D (54 pips)
	var total_pips := 0
	for attr in attrs:
		var pool = rules.parse_pool(String(attrs[attr]))
		total_pips += int(pool["dice"]) * 3 + int(pool["pips"])
	_assert_equal(total_pips, 54, "default Human allocation totals exactly 18D (54 pips)")

	# Human ranges: every attribute min "2D" max "4D" — each pip value in [6..12]
	for attr in attrs:
		var pool = rules.parse_pool(String(attrs[attr]))
		var pips_val = int(pool["dice"]) * 3 + int(pool["pips"])
		_assert_true(pips_val >= 6,  "human %s >= 2D minimum" % attr)
		_assert_true(pips_val <= 12, "human %s <= 4D maximum" % attr)

	# Force skills block (force_skills_model.initial_force_skills shape)
	var fs = sheet.get("force_skills", {})
	_assert_true(fs.has("control"), "default sheet has force_skills.control")
	_assert_true(fs.has("sense"),   "default sheet has force_skills.sense")
	_assert_true(fs.has("alter"),   "default sheet has force_skills.alter")
	_assert_equal(fs.get("control"), "0D", "force_skills.control default is 0D")

	# ------------------------------------------------------------------ #
	# 3. validate_build() with an explicit valid Human allocation
	# ------------------------------------------------------------------ #
	# Exact Human allocation: each of six attributes at exactly 3D (9 pips * 6 = 54)
	var three_d_attrs = {
		"dexterity":  "3D",
		"knowledge":  "3D",
		"mechanical": "3D",
		"perception": "3D",
		"strength":   "3D",
		"technical":  "3D",
	}
	# Skill budget: 7 pips (2D+1) on blaster (within 21-pip max)
	var skills_explicit = {"blaster": "2D+1"}
	var result = chargen_script.validate_build(rules, human_species, three_d_attrs, skills_explicit)

	_assert_equal(result.get("valid"), true, "valid 3D allocation is accepted")
	_assert_true(result.get("errors", []).is_empty(), "no errors on valid allocation")
	_assert_equal(result.get("skill_pips_spent"), 7, "2D+1 skill costs 7 pips")

	var built_sheet = result.get("sheet", {})
	_assert_false(built_sheet.is_empty(), "validate_build returns a sheet when valid")
	_assert_equal(built_sheet.get("character_points"), 5, "validate_build sheet CP == 5")
	_assert_equal(built_sheet.get("force_points"),     1, "validate_build sheet FP == 1")

	# Skills dict must contain blaster
	var sk = built_sheet.get("skills", {})
	_assert_true(sk.has("blaster"), "built sheet has blaster skill")
	_assert_equal(sk.get("blaster"), "2D+1", "blaster stored as 2D+1")

	# ------------------------------------------------------------------ #
	# 4. validate_build() error paths
	# ------------------------------------------------------------------ #
	# 4a. Wrong total (only 17D = 51 pips)
	var short_attrs = {
		"dexterity":  "3D",
		"knowledge":  "3D",
		"mechanical": "3D",
		"perception": "3D",
		"strength":   "3D",
		"technical":  "2D",   # one pip short
	}
	var short_result = chargen_script.validate_build(rules, human_species, short_attrs)
	_assert_equal(short_result.get("valid"), false, "51-pip allocation rejected")
	_assert_false(short_result.get("errors", []).is_empty(), "error list non-empty for bad total")

	# 4b. Skill budget overspend (22 pips > 21 allowed)
	var overbudget_skills = {"blaster": "7D+1"}  # 22 pips
	var over_result = chargen_script.validate_build(rules, human_species, three_d_attrs, overbudget_skills)
	_assert_equal(over_result.get("valid"), false, "7D+1 skill budget overspend rejected")

	# ------------------------------------------------------------------ #
	# 5. PersistenceStore save + load round-trip
	# ------------------------------------------------------------------ #
	# Use a throwaway subdirectory so we never pollute user://persistence.
	var store = store_script.new(THROWAWAY_DIR)

	# Build a full record wrapping the chargen sheet.
	var char_id := "test_char_smoke_001"
	var record = {
		"schema_version": 1,
		"character_id": char_id,
		"account_id":   "test_account_001",
		"name":         "Jaina Solo",
		"position": {
			"zone_id": "tatooine.mos_eisley.spaceport",
			"pos":     {"x": 1.0, "y": 0.0, "z": -2.5},
			"yaw":     1.57,
		},
		"sheet": sheet,
		"created_unix": 0,
		"extra": {},
	}

	# Verify no record exists before save.
	_assert_false(store.has_record(char_id), "no record before first save")

	var saved = store.save_record(char_id, record)
	_assert_true(saved, "save_record returns true on success")
	_assert_true(store.has_record(char_id), "has_record true after save")

	# ------------------------------------------------------------------ #
	# 6. Reload and assert field parity
	# ------------------------------------------------------------------ #
	var loaded = store.load_record(char_id)
	_assert_false(loaded.is_empty(), "load_record returns non-empty dict")
	_assert_equal(loaded.get("character_id"), char_id,         "round-trip character_id")
	_assert_equal(loaded.get("account_id"),   "test_account_001", "round-trip account_id")
	_assert_equal(loaded.get("name"),         "Jaina Solo",    "round-trip name")
	_assert_equal(loaded.get("schema_version"), 1,             "round-trip schema_version")

	# sheet fields
	var l_sheet = loaded.get("sheet", {})
	_assert_equal(l_sheet.get("character_points"), 5,         "round-trip CP")
	_assert_equal(l_sheet.get("force_points"),     1,         "round-trip FP")
	_assert_equal(l_sheet.get("wound_state"),      "healthy", "round-trip wound_state")
	_assert_equal(l_sheet.get("force_sensitive"),  false,     "round-trip force_sensitive")
	_assert_equal(l_sheet.get("credits"),          1000,      "round-trip credits (Wave F starting 1000)")

	var l_equip = l_sheet.get("equipment", {})
	_assert_equal(l_equip.get("weapon"), "blaster_pistol", "round-trip equipment.weapon")
	_assert_equal(l_equip.get("armor"),  "blast_vest",     "round-trip equipment.armor")

	var l_attrs = l_sheet.get("attributes", {})
	for attr in ["dexterity", "knowledge", "mechanical", "perception", "strength", "technical"]:
		_assert_true(l_attrs.has(attr), "round-trip sheet has attribute: %s" % attr)

	# position round-trip
	var l_pos_block = loaded.get("position", {})
	_assert_equal(l_pos_block.get("zone_id"), "tatooine.mos_eisley.spaceport", "round-trip zone_id")
	var l_pos = l_pos_block.get("pos", {})
	_assert_approx(float(l_pos.get("x", -9999.0)), 1.0,  "round-trip pos.x")
	_assert_approx(float(l_pos.get("z", -9999.0)), -2.5, "round-trip pos.z")
	_assert_approx(float(l_pos_block.get("yaw", -9999.0)), 1.57, "round-trip yaw")

	# save_record stamps last_saved_unix
	_assert_true(loaded.has("last_saved_unix"), "save_record stamps last_saved_unix")
	_assert_true(int(loaded.get("last_saved_unix", 0)) > 0, "last_saved_unix is a positive timestamp")

	# ------------------------------------------------------------------ #
	# 7. record_pos / record_yaw static helpers
	# ------------------------------------------------------------------ #
	var rp = store_script.record_pos(loaded, Vector3.ZERO)
	_assert_approx(rp.x,  1.0,  "record_pos extracts x")
	_assert_approx(rp.z, -2.5,  "record_pos extracts z")

	var ry = store_script.record_yaw(loaded, 0.0)
	_assert_approx(ry, 1.57, "record_yaw extracts yaw")

	# ------------------------------------------------------------------ #
	# 8. apply_combat / combat_from_record round-trip
	# ------------------------------------------------------------------ #
	# Simulate a combat result: 1 wound (severity 2), spent 1 CP, spent 0 FP.
	var combat_state = {
		"player_character_points": 4,
		"player_force_points":     1,
		"player_wound_severity":   2,
	}
	var after_combat = store_script.apply_combat(loaded, combat_state)
	var ac_sheet = after_combat.get("sheet", {})
	_assert_equal(ac_sheet.get("character_points"), 4,        "apply_combat updates CP")
	_assert_equal(ac_sheet.get("force_points"),     1,        "apply_combat preserves FP")
	_assert_equal(ac_sheet.get("wound_state"),      "wounded","apply_combat maps severity 2 -> wounded")

	# combat_from_record reads back those fields.
	var cstate = store_script.combat_from_record(after_combat)
	_assert_equal(cstate.get("player_character_points"), 4, "combat_from_record CP")
	_assert_equal(cstate.get("player_force_points"),     1, "combat_from_record FP")
	_assert_equal(cstate.get("player_wound_severity"),   2, "combat_from_record wound_severity")

	# ------------------------------------------------------------------ #
	# 9. wound_state_for_severity / severity_for_wound_state codec
	# ------------------------------------------------------------------ #
	var ws_pairs = [
		[0, "healthy"],
		[1, "stunned"],
		[2, "wounded"],
		[3, "incapacitated"],
		[4, "mortally_wounded"],
		[5, "dead"],
	]
	for pair in ws_pairs:
		var sev = pair[0]
		var ws  = pair[1]
		_assert_equal(store_script.wound_state_for_severity(sev), ws,
				"wound_state_for_severity(%d) == %s" % [sev, ws])
		# severity_for_wound_state("wounded_twice") also maps to 2 (persistence_store.gd line 128)
		if ws != "wounded":
			_assert_equal(store_script.severity_for_wound_state(ws), sev,
					"severity_for_wound_state(%s) == %d" % [ws, sev])
	# wounded_twice also maps to 2
	_assert_equal(store_script.severity_for_wound_state("wounded_twice"), 2,
			"severity_for_wound_state(wounded_twice) == 2")
	# unknown state falls back to 0
	_assert_equal(store_script.severity_for_wound_state("unknown_state"), 0,
			"severity_for_wound_state(unknown) fallback == 0")

	# ------------------------------------------------------------------ #
	# 10. apply_position static helper
	# ------------------------------------------------------------------ #
	var new_pos := Vector3(10.0, 0.0, 5.0)
	var new_yaw := 3.14
	var after_move = store_script.apply_position(loaded, new_pos, new_yaw)
	var am_pos_block = after_move.get("position", {})
	_assert_equal(am_pos_block.get("zone_id"), "tatooine.mos_eisley.spaceport",
			"apply_position preserves zone_id")
	var am_pos = am_pos_block.get("pos", {})
	_assert_approx(float(am_pos.get("x", -9999.0)), 10.0, "apply_position new x")
	_assert_approx(float(am_pos.get("z", -9999.0)), 5.0,  "apply_position new z")
	_assert_approx(float(am_pos_block.get("yaw", -9999.0)), 3.14, "apply_position new yaw")

	# ------------------------------------------------------------------ #
	# 11. Overwrite and reload (second save)
	# ------------------------------------------------------------------ #
	var updated_record = after_combat.duplicate(true)
	var second_save = store.save_record(char_id, updated_record)
	_assert_true(second_save, "second save_record returns true")
	var reloaded2 = store.load_record(char_id)
	var r2_sheet = reloaded2.get("sheet", {})
	_assert_equal(r2_sheet.get("character_points"), 4, "second load shows updated CP")
	_assert_equal(r2_sheet.get("wound_state"), "wounded", "second load shows wounded state")

	# ------------------------------------------------------------------ #
	# 12. load_or_create: existing record is returned as-is
	# ------------------------------------------------------------------ #
	var loc = store.load_or_create(char_id, "test_account_001", "Jaina Solo", Vector3.ZERO)
	_assert_equal(loc.get("character_id"), char_id, "load_or_create returns existing record")

	# load_or_create for unknown id creates a default record
	var fresh = store.load_or_create("nonexistent_char", "acct", "Ghost", Vector3(0.0, 0.0, 0.0))
	_assert_equal(fresh.get("character_id"), "nonexistent_char", "load_or_create default char_id")
	_assert_equal(fresh.get("name"), "Ghost", "load_or_create default name")
	var fresh_sheet = fresh.get("sheet", {})
	_assert_equal(fresh_sheet.get("character_points"), 5, "load_or_create default CP == 5")
	_assert_equal(fresh_sheet.get("force_points"),     1, "load_or_create default FP == 1")
	_assert_equal(fresh_sheet.get("wound_state"), "healthy", "load_or_create default wound_state")

	# ------------------------------------------------------------------ #
	# 13. Wookiee species: validate default_build stays in species range
	# ------------------------------------------------------------------ #
	var wookiee_species = species_map.get("wookiee", {})
	_assert_true(not wookiee_species.is_empty(), "wookiee species entry exists")
	var wookiee_sheet = chargen_script.default_sheet(rules, wookiee_species)
	var w_attrs = wookiee_sheet.get("attributes", {})
	# Wookiee strength min "3D" (9 pips) max "6D" (18 pips)
	var w_str_pool = rules.parse_pool(String(w_attrs.get("strength", "0D")))
	var w_str_pips = int(w_str_pool["dice"]) * 3 + int(w_str_pool["pips"])
	_assert_true(w_str_pips >= 9,  "wookiee strength >= 3D (species minimum)")
	_assert_true(w_str_pips <= 18, "wookiee strength <= 6D (species maximum)")

	# Total pips still 54
	var w_total := 0
	for attr in w_attrs:
		var wp = rules.parse_pool(String(w_attrs[attr]))
		w_total += int(wp["dice"]) * 3 + int(wp["pips"])
	_assert_equal(w_total, 54, "wookiee default allocation totals exactly 18D")

	# ------------------------------------------------------------------ #
	# 14. Cleanup throwaway directory
	# ------------------------------------------------------------------ #
	var record_file := THROWAWAY_DIR + "/test_char_smoke_001.json"
	DirAccess.remove_absolute(record_file)
	DirAccess.remove_absolute(THROWAWAY_DIR)

	# ------------------------------------------------------------------ #
	# Finish
	# ------------------------------------------------------------------ #
	rules.free()

	if _failures.is_empty():
		print("character_lifecycle_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


# ---- helpers -------------------------------------------------------

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_failures.append("file not found: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("cannot open: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("not a JSON object: %s" % path)
		return {}
	return parsed

func _assert_true(cond: bool, label: String) -> void:
	if not cond:
		_failures.append("%s: expected true" % label)

func _assert_false(cond: bool, label: String) -> void:
	if cond:
		_failures.append("%s: expected false" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_approx(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s: expected ~%f, got %f" % [label, expected, actual])
