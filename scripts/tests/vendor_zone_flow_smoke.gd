extends SceneTree
## Flow guard for the per-zone vendor variety COMPOSITION wired into network_manager
## (Overnight A/B: "wire per-zone vendor stock live" — shops differ by zone). network_manager
## is a Node autoload that is not headlessly instantiable, so — like economy_flow_smoke — this
## mirrors its `_zone_stock_keys()` helper and the per-zone allow-list filter loop inside
## `submit_vendor_list()` (see scripts/net/network_manager.gd) around the REAL VendorModel,
## which supplies the full stocked catalog that filter starts from. vendor_model_smoke covers
## VendorModel's own math; this locks the per-zone data-driven filtering composition on top of
## it, over the real data/vendor_stock_by_zone.json + weapons/armor catalogs.

const VendorModel := preload("res://scripts/rules/vendor_model.gd")

var _failures: Array[String] = []

# --- faithful mirror of network_manager._zone_stock_keys ---
func _zone_stock_keys(vendor_stock_by_zone: Dictionary, zone_id: String) -> Dictionary:
	var out := {}
	var z: Dictionary = vendor_stock_by_zone.get(zone_id, {})
	for k in z.get("item_keys", []):
		out[String(k)] = true
	return out

# --- faithful mirror of submit_vendor_list's per-zone filter loop over the full stocked catalog
# ("allowed" empty -> the whole catalog passes through unfiltered) ---
func _filtered_stock_keys(full_stock: Array, vendor_stock_by_zone: Dictionary, zone_id: String) -> Array:
	var allowed := _zone_stock_keys(vendor_stock_by_zone, zone_id)
	var keys: Array = []
	for item in full_stock:
		var key := String((item as Dictionary)["key"])
		if not allowed.is_empty() and not allowed.has(key):
			continue  # this zone's vendor doesn't carry it
		keys.append(key)
	return keys

func _key_set(keys: Array) -> Dictionary:
	var out := {}
	for k in keys:
		out[String(k)] = true
	return out

func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
	return true

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	_assert_true(f != null, "%s opens" % path)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _init() -> void:
	var weapons_root := _load_json("res://data/weapons_clone_wars.json")
	var armor_root := _load_json("res://data/armor_clone_wars.json")
	var vendor_zone_root := _load_json("res://data/vendor_stock_by_zone.json")
	var weapons: Dictionary = weapons_root.get("weapons", {})
	var armor: Dictionary = armor_root.get("armor", {})
	var vendor_stock_by_zone: Dictionary = vendor_zone_root.get("vendor_stock_by_zone", {})
	_assert_true(not weapons.is_empty() and not armor.is_empty() and not vendor_stock_by_zone.is_empty(),
		"weapons, armor and vendor_stock_by_zone all parse non-empty")
	_assert_true(vendor_stock_by_zone.size() >= 2, "at least two curated zones exist to compare")

	var vendor := VendorModel.new()
	# The REAL stocked catalog submit_vendor_list starts from before applying the per-zone filter.
	var full_stock: Array = vendor.list_stock({"weapons": weapons}, {"armor": armor})
	var full_keys := _key_set(full_stock.map(func(it): return String((it as Dictionary)["key"])))
	_assert_true(full_keys.size() >= 10, "the stocked catalog is non-trivial (got %d items)" % full_keys.size())

	# --- every item_key referenced by every curated zone exists in the catalog AND is vendor_stocked
	# (list_stock only ever returns vendor_stocked, non-contraband entries, so membership in
	# full_keys proves both at once) ---
	for zone_id in vendor_stock_by_zone:
		var z: Dictionary = vendor_stock_by_zone[zone_id]
		for k in z.get("item_keys", []):
			_assert_true(full_keys.has(String(k)), "zone '%s' item_key '%s' exists in the catalog and is vendor_stocked" % [zone_id, String(k)])

	# --- each curated zone's filtered stock == exactly its item_keys ∩ the stocked catalog ---
	var counts := {}
	for zone_id in vendor_stock_by_zone:
		var z: Dictionary = vendor_stock_by_zone[zone_id]
		var declared := _key_set(z.get("item_keys", []))
		var expected := {}
		for k in declared:
			if full_keys.has(k):
				expected[k] = true
		var got_keys := _filtered_stock_keys(full_stock, vendor_stock_by_zone, zone_id)
		var got_set := _key_set(got_keys)
		_assert_true(_same_keys(got_set, expected),
			"zone '%s' filtered stock (%s) == item_keys ∩ stocked catalog (%s)" % [zone_id, str(got_set.keys()), str(expected.keys())])
		counts[zone_id] = got_keys.size()

	# --- an UNKNOWN zone falls back to the FULL stocked catalog (empty allowed-set => all items) ---
	var unknown_zone_id := "some_unmapped_zone_id_not_in_vendor_stock_by_zone"
	_assert_true(not vendor_stock_by_zone.has(unknown_zone_id), "sanity: the probe zone id is genuinely unknown")
	var unknown_got := _filtered_stock_keys(full_stock, vendor_stock_by_zone, unknown_zone_id)
	_assert_equal(unknown_got.size(), full_keys.size(), "unknown zone's stock count == the full stocked catalog size")
	_assert_true(_same_keys(_key_set(unknown_got), full_keys), "unknown zone's stock is exactly the full stocked catalog")

	# --- per-zone variety is real: item counts differ across zones (proves it isn't a no-op filter) ---
	var count_values: Array = counts.values()
	var min_c: int = int(count_values[0])
	var max_c: int = int(count_values[0])
	for c in count_values:
		min_c = mini(min_c, int(c))
		max_c = maxi(max_c, int(c))
	_assert_true(min_c != max_c, "vendor stock counts differ across zones (got %s)" % str(counts))

	if _failures.is_empty():
		print("vendor_zone_flow_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
