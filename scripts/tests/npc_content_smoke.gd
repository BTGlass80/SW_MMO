extends SceneTree
## Headless smoke test for the World-Depth curated content drop: named Mos Eisley
## NPCs (data/npcs_clone_wars.json) and per-zone vendor stock variety
## (data/vendor_stock_by_zone.json), both ported one-way from the read-only
## SW_MUSH. Validates shape, cross-references against the real loaded zone
## roster and the real vendor_stocked weapon/armor catalogs, faction_axis
## enum membership, and that no old-era (Imperial/Rebel/etc.) contamination
## has crept into any NPC-facing text.

const NPCS_PATH := "res://data/npcs_clone_wars.json"
const VENDOR_STOCK_PATH := "res://data/vendor_stock_by_zone.json"
const ZONES_PATH := "res://data/zones_clone_wars.json"
const WEAPONS_PATH := "res://data/weapons_clone_wars.json"
const ARMOR_PATH := "res://data/armor_clone_wars.json"

const VALID_FACTION_AXES := ["republic", "cis", "hutt", "independent", "bounty_hunters_guild"]

# Case-insensitive forbidden old-era terms. Checked against name/role/description/
# dialogue_lines/flavor_note for every NPC and vendor zone entry.
const FORBIDDEN_TERMS := [
	"empire", "imperial", "stormtrooper", "rebel", "alliance",
	"darth", "sith", "vader", "palpatine", "death star",
]

var _failures: Array[String] = []

func _init() -> void:
	var npc_data := _load_json(NPCS_PATH)
	var vendor_data := _load_json(VENDOR_STOCK_PATH)
	var zones_data := _load_json(ZONES_PATH)
	var weapons_data := _load_json(WEAPONS_PATH)
	var armor_data := _load_json(ARMOR_PATH)

	for d in [npc_data, vendor_data]:
		_assert_true(d.has("source_policy"), "content file carries source_policy provenance")

	var real_zone_ids := _real_zone_ids(zones_data)
	_assert_true(real_zone_ids.size() >= 3, "loaded at least three real zones to validate against")

	# --- NPCs ---------------------------------------------------------------
	var npcs: Array = npc_data.get("npcs", [])
	_assert_true(npcs.size() >= 8 and npcs.size() <= 15, "NPC roster is curated in the 8-15 range (got %d)" % npcs.size())

	var seen_ids := {}
	var npc_ids := {}
	var zones_covered := {}
	for entry in npcs:
		_assert_true(typeof(entry) == TYPE_DICTIONARY, "npc entry is a dictionary")
		var npc: Dictionary = entry
		var id := String(npc.get("id", ""))
		var name := String(npc.get("name", ""))
		var species := String(npc.get("species", ""))
		var zone_id := String(npc.get("zone_id", ""))
		var role := String(npc.get("role", ""))
		var faction_axis := String(npc.get("faction_axis", ""))
		var description := String(npc.get("description", ""))

		_assert_true(id != "", "npc has a non-empty id")
		_assert_true(not seen_ids.has(id), "npc id is unique: %s" % id)
		seen_ids[id] = true
		npc_ids[id] = true

		_assert_true(name != "", "npc '%s' has a non-empty name" % id)
		_assert_true(species != "", "npc '%s' has a non-empty species" % id)
		_assert_true(role != "", "npc '%s' has a non-empty role" % id)
		_assert_true(description != "", "npc '%s' has a non-empty description" % id)

		_assert_true(real_zone_ids.has(zone_id), "npc '%s' zone_id '%s' is a real loaded zone" % [id, zone_id])
		zones_covered[zone_id] = true

		_assert_true(VALID_FACTION_AXES.has(faction_axis), "npc '%s' faction_axis '%s' is one of the five valid axes" % [id, faction_axis])

		var lines: Array = npc.get("dialogue_lines", [])
		if npc.has("dialogue_lines"):
			_assert_true(lines.size() >= 2 and lines.size() <= 4, "npc '%s' has 2-4 dialogue_lines (got %d)" % [id, lines.size()])
			for line in lines:
				_assert_true(String(line) != "", "npc '%s' dialogue line is non-empty text" % id)

		_scan_forbidden_terms(name, "npc '%s' name" % id)
		_scan_forbidden_terms(role, "npc '%s' role" % id)
		_scan_forbidden_terms(description, "npc '%s' description" % id)
		for line in lines:
			_scan_forbidden_terms(String(line), "npc '%s' dialogue line" % id)

	_assert_true(zones_covered.size() >= 3, "NPCs span at least three of the loaded zones (got %d)" % zones_covered.size())

	# --- Vendor stock by zone ------------------------------------------------
	var vendor_stocked_keys := _vendor_stocked_keys(weapons_data, armor_data)
	_assert_true(vendor_stocked_keys.size() > 0, "sanity: at least one vendor_stocked item exists in the weapons/armor catalogs")

	var vendor_stock: Dictionary = vendor_data.get("vendor_stock_by_zone", {})
	_assert_true(vendor_stock.size() >= 3, "vendor stock defined for at least three zones (got %d)" % vendor_stock.size())

	for zone_key in vendor_stock:
		_assert_true(real_zone_ids.has(String(zone_key)), "vendor_stock zone_id '%s' is a real loaded zone" % zone_key)
		var zone_entry: Dictionary = vendor_stock[zone_key]
		var item_keys: Array = zone_entry.get("item_keys", [])
		_assert_true(item_keys.size() > 0, "vendor stock for zone '%s' has at least one item" % zone_key)
		for item_key in item_keys:
			var key := String(item_key)
			_assert_true(vendor_stocked_keys.has(key), "vendor stock item '%s' (zone '%s') exists and is vendor_stocked in weapons/armor catalogs" % [key, zone_key])
		_scan_forbidden_terms(String(zone_entry.get("flavor_note", "")), "vendor zone '%s' flavor_note" % zone_key)

		# Optional cross-reference: any vendor_npc_ids must resolve to a real NPC.
		var vendor_npc_ids: Array = zone_entry.get("vendor_npc_ids", [])
		for npc_id in vendor_npc_ids:
			_assert_true(npc_ids.has(String(npc_id)), "vendor_npc_ids entry '%s' (zone '%s') resolves to a real npc" % [npc_id, zone_key])

	_finish()

func _real_zone_ids(zones_data: Dictionary) -> Dictionary:
	var ids := {}
	var list: Array = zones_data.get("zones", [])
	for entry in list:
		if typeof(entry) == TYPE_DICTIONARY:
			var zid := String((entry as Dictionary).get("zone_id", ""))
			if zid != "":
				ids[zid] = true
	return ids

func _vendor_stocked_keys(weapons_data: Dictionary, armor_data: Dictionary) -> Dictionary:
	var keys := {}
	var weapons: Dictionary = weapons_data.get("weapons", {})
	for key in weapons:
		var w: Dictionary = weapons[key]
		if bool(w.get("vendor_stocked", false)):
			keys[String(key)] = true
	var armors: Dictionary = armor_data.get("armor", {})
	for key in armors:
		var a: Dictionary = armors[key]
		if bool(a.get("vendor_stocked", false)):
			keys[String(key)] = true
	return keys

func _scan_forbidden_terms(text: String, label: String) -> void:
	if text == "":
		return
	var lower := text.to_lower()
	for term in FORBIDDEN_TERMS:
		if lower.contains(term):
			_failures.append("%s contains forbidden old-era term '%s': %s" % [label, term, text])

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

func _finish() -> void:
	if _failures.is_empty():
		print("npc_content_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)
