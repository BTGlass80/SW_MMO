extends SceneTree
## Flow guard for the named-NPC placement COMPOSITION wired into network_manager (Overnight A:
## "populate Mos Eisley — render named NPCs per zone", server + client). network_manager is a
## Node autoload that is not headlessly instantiable, so — like vendor_zone_flow_smoke — this
## mirrors its `_load_named_npcs()` grouping/placement and its `_npc_kind()` role->kind mapping
## (see scripts/net/network_manager.gd) over the REAL data/npcs_clone_wars.json +
## data/zones_clone_wars.json. npc_builder_smoke covers the mesh builder itself; this locks the
## server-side grouping/placement/kind-mapping composition that feeds it, cross-checked against
## npc_builder.gd's own supported-kind set (KIND_LABELS).

const WorldState := preload("res://scripts/net/world_state.gd")
const NpcBuilder := preload("res://scripts/world/npc_builder.gd")  # ground truth for "a valid npc_builder kind"

var _failures: Array[String] = []

# --- faithful mirror of network_manager._npc_kind ---
func _npc_kind(npc: Dictionary) -> String:
	if bool(npc.get("vendor", false)):
		return "vendor"
	var role := String(npc.get("role", "")).to_lower()
	for pair in [["bounty", "hunter"], ["hunter", "hunter"], ["liaison", "official"], ["customs", "official"], ["official", "official"], ["officer", "official"], ["enforcer", "thug"], ["thug", "thug"], ["guard", "thug"], ["mechanic", "mechanic"], ["tech", "mechanic"], ["broker", "broker"], ["fixer", "broker"], ["slicer", "broker"], ["pilot", "pilot"], ["merchant", "vendor"], ["trader", "vendor"], ["barkeep", "vendor"], ["bartender", "vendor"]]:
		if role.find(String(pair[0])) >= 0:
			return String(pair[1])
	return "civilian"

# --- faithful mirror of _load_named_npcs' deterministic hash-based scatter placement ---
func _npc_pos(id: String) -> Dictionary:
	var h := absi(hash(id))
	var angle := fposmod(float(h) * 0.6180339887, 1.0) * TAU
	var radius := 8.0 + fposmod(float(h / 7) * 0.381966011, 1.0) * 30.0
	return {"x": cos(angle) * radius, "y": WorldState.GROUND_Y, "z": sin(angle) * radius}

# --- faithful mirror of network_manager._load_named_npcs' per-zone grouping ---
func _load_named_npcs(npcs_data: Dictionary) -> Dictionary:
	var by_zone := {}
	for entry in npcs_data.get("npcs", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var npc: Dictionary = entry
		var zone_id := String(npc.get("zone_id", ""))
		if zone_id == "":
			continue
		var id := String(npc.get("id", ""))
		if not by_zone.has(zone_id):
			by_zone[zone_id] = []
		(by_zone[zone_id] as Array).append({
			"id": id,
			"name": String(npc.get("name", id)),
			"role": String(npc.get("role", "")),
			"faction_axis": String(npc.get("faction_axis", "independent")),
			"kind": _npc_kind(npc),
			"pos": _npc_pos(id),
		})
	return by_zone

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	_assert_true(f != null, "%s opens" % path)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _init() -> void:
	var npcs_data := _load_json("res://data/npcs_clone_wars.json")
	var zones_data := _load_json("res://data/zones_clone_wars.json")
	var raw_npcs: Array = npcs_data.get("npcs", [])
	_assert_true(raw_npcs.size() >= 1, "npcs data parses at least one entry")

	# Real loaded zones: network_manager._load_zones() adds exactly one zone per non-empty
	# zone_id entry in zones_clone_wars.json's "zones" list (no further filtering).
	var real_zones := {}
	for z in zones_data.get("zones", []):
		if typeof(z) == TYPE_DICTIONARY:
			var zid := String((z as Dictionary).get("zone_id", ""))
			if zid != "":
				real_zones[zid] = true
	_assert_true(real_zones.size() >= 1, "zones data parses at least one real zone")

	var by_zone := _load_named_npcs(npcs_data)

	# --- every NPC groups under a REAL loaded zone ---
	for zone_id in by_zone:
		_assert_true(real_zones.has(zone_id), "grouped zone '%s' is a real loaded zone" % zone_id)

	# --- the per-zone grouping counts sum to the total NPC count ---
	var grouped_total := 0
	for zone_id in by_zone:
		grouped_total += (by_zone[zone_id] as Array).size()
	_assert_equal(grouped_total, raw_npcs.size(), "per-zone grouping counts sum to the total NPC count")

	# --- per-NPC checks: valid npc_builder kind, deterministic + finite position ---
	var supported_kinds: Dictionary = NpcBuilder.KIND_LABELS  # cross-check ground truth
	var checked := 0
	for zone_id in by_zone:
		for entry in (by_zone[zone_id] as Array):
			var e: Dictionary = entry
			checked += 1
			var kind := String(e["kind"])
			_assert_true(supported_kinds.has(kind), "NPC '%s' kind '%s' is a real npc_builder kind" % [String(e["id"]), kind])
			var pos1: Dictionary = e["pos"]
			var pos2 := _npc_pos(String(e["id"]))  # recompute from scratch: same id must yield the same pos
			_assert_true(
				float(pos1["x"]) == float(pos2["x"]) and float(pos1["y"]) == float(pos2["y"]) and float(pos1["z"]) == float(pos2["z"]),
				"NPC '%s' position is deterministic (same id -> same pos)" % String(e["id"]))
			_assert_true(
				is_finite(float(pos1["x"])) and is_finite(float(pos1["y"])) and is_finite(float(pos1["z"])),
				"NPC '%s' position (%s) is finite" % [String(e["id"]), str(pos1)])
	_assert_equal(checked, raw_npcs.size(), "sanity: every raw NPC was visited exactly once across zone groups")

	# --- a vendor:true NPC maps to "vendor" (checked against the real data so it isn't vacuous) ---
	var saw_real_vendor := false
	for entry in raw_npcs:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var npc: Dictionary = entry
		if bool(npc.get("vendor", false)):
			saw_real_vendor = true
			_assert_equal(_npc_kind(npc), "vendor", "vendor:true NPC '%s' maps to kind 'vendor'" % String(npc.get("id", "?")))
	_assert_true(saw_real_vendor, "the real data actually contains at least one vendor:true NPC")

	if _failures.is_empty():
		print("named_npc_flow_smoke: OK")
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
