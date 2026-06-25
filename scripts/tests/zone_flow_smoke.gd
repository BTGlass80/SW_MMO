extends SceneTree
## Regression guard for the zone subsystem's network_manager COMPOSITION (F11 travel /
## DIV-0014 + F13 zone-scoped visibility), which is otherwise only two-process verified.
## network_manager is a Node autoload that is not headlessly instantiable, so — like
## claim_flow / auth_flow / heal_flow — this replicates the three zone wirings and locks:
##   1. submit_change_zone precedence: unregistered -> unknown_zone -> already_here -> travel
##      (on travel: update _peer_zones AND persist record.zone).
##   2. register zone resolution: explicit build.zone wins; else fall back to the persisted
##      record.zone; an invalid zone is ignored (keeps the current zone).
##   3. zone-scoped player visibility: a viewer sees ONLY same-zone players (incl. itself).

var _failures: Array[String] = []

func _fresh() -> Dictionary:
	return {
		"valid_zones": {"spaceport": true, "dune_sea": true, "market": true},
		"default_zone": "spaceport",
		"peer_characters": {},
		"peer_zones": {},
		"records": {},
	}

func _register_peer(st: Dictionary, peer: int, char_id: String, zone: String) -> void:
	st["peer_characters"][peer] = char_id
	st["peer_zones"][peer] = zone
	st["records"][char_id] = {"sheet": {}}

# Mirror of submit_change_zone's precedence (DIV-0014).
func _change_zone(st: Dictionary, peer: int, zone_id: String) -> Dictionary:
	if String(st["peer_characters"].get(peer, "")) == "":
		return {"ok": false, "reason": "unregistered"}
	if not st["valid_zones"].has(zone_id):
		return {"ok": false, "reason": "unknown_zone"}
	if String(st["peer_zones"].get(peer, st["default_zone"])) == zone_id:
		return {"ok": false, "reason": "already_here"}
	st["peer_zones"][peer] = zone_id
	var cid := String(st["peer_characters"][peer])
	if st["records"].has(cid):
		(st["records"][cid] as Dictionary)["zone"] = zone_id  # persist for next-login restore
	return {"ok": true, "reason": "", "zone_id": zone_id}

# Mirror of register_account's zone resolution (build.zone || record.zone, validity-gated).
func _resolve_register_zone(st: Dictionary, peer: int, build_zone: String, record: Dictionary) -> String:
	var requested := build_zone
	if requested == "":
		requested = String(record.get("zone", ""))
	if requested != "" and st["valid_zones"].has(requested):
		st["peer_zones"][peer] = requested
	return String(st["peer_zones"].get(peer, st["default_zone"]))

# Mirror of _build_snapshot's same-zone player filter (F13).
func _visible(st: Dictionary, viewer: int, players: Array) -> Array:
	var viewer_zone := String(st["peer_zones"].get(viewer, st["default_zone"]))
	var out: Array = []
	for p in players:
		if String(st["peer_zones"].get(int((p as Dictionary).get("id", 0)), st["default_zone"])) == viewer_zone:
			out.append(p)
	return out

func _init() -> void:
	# --- 1. submit_change_zone precedence ---
	var st: Dictionary = _fresh()
	_register_peer(st, 10, "alice", "spaceport")
	_assert_eq(_change_zone(st, 99, "dune_sea")["reason"], "unregistered", "unregistered peer -> unregistered")
	_assert_eq(_change_zone(st, 10, "nowhere")["reason"], "unknown_zone", "bad zone -> unknown_zone")
	_assert_eq(_change_zone(st, 10, "spaceport")["reason"], "already_here", "current zone -> already_here")
	var ok: Dictionary = _change_zone(st, 10, "dune_sea")
	_assert_true(bool(ok["ok"]), "valid travel -> ok")
	_assert_eq(String(st["peer_zones"][10]), "dune_sea", "travel updates _peer_zones")
	_assert_eq(String((st["records"]["alice"] as Dictionary).get("zone", "")), "dune_sea", "travel persists record.zone")
	# unknown precedes already_here: a bad zone is rejected even if it equals nothing
	_assert_eq(_change_zone(st, 10, "dune_sea")["reason"], "already_here", "now in dune_sea -> already_here")

	# --- 2. register zone resolution ---
	var st2: Dictionary = _fresh()
	st2["peer_zones"][20] = "spaceport"  # default assigned at connect
	# explicit build.zone wins
	_assert_eq(_resolve_register_zone(st2, 20, "market", {}), "market", "explicit build.zone wins")
	# empty build -> fall back to the persisted record.zone
	st2["peer_zones"][20] = "spaceport"
	_assert_eq(_resolve_register_zone(st2, 20, "", {"zone": "dune_sea"}), "dune_sea", "empty build -> record.zone restore")
	# an invalid requested zone is ignored (keeps the current zone)
	st2["peer_zones"][20] = "spaceport"
	_assert_eq(_resolve_register_zone(st2, 20, "atlantis", {}), "spaceport", "invalid zone ignored -> keeps current")
	# neither build nor record -> stays at the connect default
	st2["peer_zones"][21] = "spaceport"
	_assert_eq(_resolve_register_zone(st2, 21, "", {}), "spaceport", "no zone given -> default")

	# --- 3. zone-scoped visibility ---
	var st3: Dictionary = _fresh()
	st3["peer_zones"] = {1: "spaceport", 2: "spaceport", 3: "dune_sea"}
	var roster := [{"id": 1}, {"id": 2}, {"id": 3}]
	var seen_by_1 := _visible(st3, 1, roster)
	_assert_eq(seen_by_1.size(), 2, "spaceport viewer sees the 2 spaceport players")
	_assert_true(_ids(seen_by_1).has(1) and _ids(seen_by_1).has(2) and not _ids(seen_by_1).has(3), "viewer sees self + same-zone, not cross-zone")
	var seen_by_3 := _visible(st3, 3, roster)
	_assert_eq(seen_by_3.size(), 1, "the lone dune_sea viewer sees only itself")
	_assert_true(_ids(seen_by_3).has(3), "lone viewer sees itself")

	if _failures.is_empty():
		print("zone_flow_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _ids(players: Array) -> Array:
	var out: Array = []
	for p in players:
		out.append(int((p as Dictionary).get("id", 0)))
	return out

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
