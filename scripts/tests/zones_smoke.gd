extends SceneTree
## Headless smoke for the seeded multi-zone roster (E21). Verifies the data file
## (>=3 zones, unique ids, valid bases, a secured + contested + lawless present, a
## real default_zone) AND that the ZoneState Director registers + ticks ALL of them
## deterministically. Mirrors how network_manager._load_zones seeds the world.

const ZONES_PATH := "res://data/zones_clone_wars.json"
const ZoneState := preload("res://scripts/net/zone_state.gd")
const TerritoryModel := preload("res://scripts/net/territory_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var data := _load_json(ZONES_PATH)
	var list: Array = data.get("zones", [])
	_assert_true(list.size() >= 3, "at least three zones seeded (got %d)" % list.size())

	var ids := {}
	var bases := {}
	for entry in list:
		_assert_true(typeof(entry) == TYPE_DICTIONARY, "zone entry is a dictionary")
		var z: Dictionary = entry
		var zid := String(z.get("zone_id", ""))
		_assert_true(zid != "", "zone has a non-empty id")
		_assert_true(not ids.has(zid), "zone id is unique: %s" % zid)
		ids[zid] = true
		var base := String(z.get("security_base", ""))
		_assert_true(ZoneState.TIERS.has(base), "zone %s has a valid security base (%s)" % [zid, base])
		bases[base] = true

	_assert_true(bases.has("secured"), "a secured zone exists")
	_assert_true(bases.has("contested"), "a contested zone exists")
	_assert_true(bases.has("lawless"), "a lawless zone exists")

	var default_zone := String(data.get("default_zone", ""))
	_assert_true(ids.has(default_zone), "default_zone names a real zone (%s)" % default_zone)

	# The Director registers and ticks every zone (mirrors _load_zones + director_tick).
	var dir: ZoneState = ZoneState.new()
	for entry in list:
		var z: Dictionary = entry
		dir.add_zone(String(z.get("zone_id", "")), String(z.get("security_base", "secured")),
			z.get("influence", {}), z.get("baseline", {}), String(z.get("display_name", "")))
	_assert_equal(dir.zones.size(), list.size(), "every zone registered in the director")
	dir.director_tick()
	for zid in ids.keys():
		_assert_equal(int(dir.get_zone(String(zid)).get("tick", -1)), 1, "zone %s advanced one Director tick" % zid)

	# A contested/lawless zone is claimable (territory precondition); secured is not.
	var claimable := 0
	for entry in list:
		var z: Dictionary = entry
		if TerritoryModel.CLAIMABLE_BASES.has(String(z.get("security_base", ""))):
			claimable += 1
	_assert_true(claimable >= 1, "at least one claimable (contested/lawless) zone exists")
	_assert_true(not TerritoryModel.CLAIMABLE_BASES.has("secured"), "secured zones are not claimable")

	# Determinism: two identical loads tick to the same posture.
	var a: ZoneState = ZoneState.new()
	var b: ZoneState = ZoneState.new()
	for d in [a, b]:
		for entry in list:
			var z: Dictionary = entry
			d.add_zone(String(z.get("zone_id", "")), String(z.get("security_base", "secured")),
				z.get("influence", {}), z.get("baseline", {}), String(z.get("display_name", "")))
		for i in range(5):
			d.director_tick()
	for zid in ids.keys():
		_assert_equal(a.get_zone(String(zid)).get("influence"), b.get_zone(String(zid)).get("influence"),
			"zone %s ticks deterministically" % zid)

	if _failures.is_empty():
		print("zones_smoke: OK")
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

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
