extends SceneTree
## Coverage guard for _build_snapshot's PER-PEER enrichment (network_manager.gd:1144-1170):
## the per-player wound+axis fields AND the territory block (org_id/treasury/claims_in_zone +
## your_rank/rank_claim/rank_city/org_members_online). snapshot_merge_smoke covers the zone merge
## and wire_roundtrip_smoke covers the raw WorldState+envelope shape, but this enrichment — which
## the client org HUD (_update_org) + faction nameplates (_update_nameplate) render — had NO test,
## so a silent field rename/drop or an int->float widening over the wire would break those displays
## with a green gate. network_manager is a non-instantiable Node autoload, so (like the
## claim_flow/auth_flow guards) this mirrors the enrichment with the REAL WorldState /
## TerritoryModel / OrgModel / PersistenceStore + a JSON round-trip, locking the fields + types.

const WorldState = preload("res://scripts/net/world_state.gd")
const TerritoryModel = preload("res://scripts/net/territory_model.gd")
const OrgModel = preload("res://scripts/net/org_model.gd")
const PersistenceStore = preload("res://scripts/net/persistence_store.gd")

const ZONE := "tatooine.dune_sea"

var _failures: Array[String] = []

# Faithful mirror of _territory_summary (network_manager.gd:832-846).
func _territory_summary(territory, org_id: String, zone_id: String) -> Dictionary:
	var claims_here: Array = []
	for cid in territory.claims:
		var c: Dictionary = territory.claims[cid]
		if String(c.get("zone_id", "")) == zone_id:
			claims_here.append({
				"node_id": String(c.get("node_id", "")),
				"org_id": String(c.get("org_id", "")),
				"tier": String(c.get("influence_tier_at_claim", "")),
			})
	return {
		"org_id": org_id,
		"treasury": territory.get_org_credits(org_id),
		"claims_in_zone": claims_here,
	}

func _init() -> void:
	var org_id := "org_hutt_cartel"
	var territory = TerritoryModel.new()
	# A claim in the lawless zone, then one income tick so the treasury is non-zero.
	territory.claim_node("%s::node_a" % org_id, "node_a", ZONE, org_id, "lawless", 50)
	territory.accrue_income()

	# Per-peer maps as register_account populates them: two Hutt members + one Republic member.
	var peer_orgs := {1: org_id, 2: org_id, 3: "org_republic"}
	var peer_axes := {1: "hutt", 2: "hutt", 3: "republic"}
	var peer_ranks := {1: 3, 2: 1, 3: 4}
	var wound_sev := {1: 2, 2: 0}  # peer 1 wounded, peer 2 healthy (in-arena players)

	# Base players list as WorldState.snapshot() produces it.
	var state: WorldState = WorldState.new()
	state.add_player(1, "Greedo")
	state.add_player(2, "Bossk")
	state.tick(1.0 / 20.0)
	var snap: Dictionary = state.snapshot()

	# --- Mirror the per-player enrichment (network_manager.gd:1144-1150) ---
	for p in snap.get("players", []):
		var ppid := int((p as Dictionary).get("id", 0))
		if wound_sev.has(ppid):
			(p as Dictionary)["wound"] = PersistenceStore.wound_state_for_severity(int(wound_sev[ppid]))
		var pax := String(peer_axes.get(ppid, ""))
		if pax != "":
			(p as Dictionary)["axis"] = pax

	# --- Mirror the territory block (network_manager.gd:1153-1170) for viewer peer 1 ---
	var viewer := 1
	var my_org := String(peer_orgs.get(viewer, ""))
	var tsum := _territory_summary(territory, my_org, ZONE)
	tsum["your_rank"] = int(peer_ranks.get(viewer, 0))
	tsum["rank_claim"] = OrgModel.RANK_CLAIM
	tsum["rank_city"] = OrgModel.RANK_CITY
	var members_online := 0
	if my_org != "":
		for pid in peer_orgs:
			if String(peer_orgs[pid]) == my_org:
				members_online += 1
	tsum["org_members_online"] = members_online
	snap["territory"] = tsum

	# --- JSON round-trip: the wire path (the real RPC widens ints to float). ---
	var wire: Variant = JSON.parse_string(JSON.stringify(snap))
	_assert_true(typeof(wire) == TYPE_DICTIONARY, "snapshot round-trips through JSON as a dict")
	var rt: Dictionary = wire

	# --- Per-player enrichment survives the wire ---
	var players: Array = rt.get("players", [])
	_assert_equal(players.size(), 2, "two players in the round-tripped snapshot")
	var by_id := {}
	for p in players:
		by_id[int((p as Dictionary).get("id", 0))] = p
	_assert_true((by_id[1] as Dictionary).has("axis"), "org member's player entry carries axis")
	_assert_equal(String((by_id[1] as Dictionary).get("axis", "")), "hutt", "axis is the member's faction")
	_assert_true((by_id[1] as Dictionary).has("wound"), "in-arena player entry carries wound")
	_assert_equal(String((by_id[1] as Dictionary).get("wound", "")), PersistenceStore.wound_state_for_severity(2), "wound matches the severity mapping")

	# --- Territory block survives with the right fields + types ---
	_assert_true(rt.has("territory"), "snapshot carries a territory block")
	var ter: Dictionary = rt.get("territory", {})
	_assert_equal(String(ter.get("org_id", "")), org_id, "territory org_id")
	_assert_true(int(ter.get("treasury", -1)) > 0, "treasury accrued and is int-coercible after the wire")
	_assert_equal(int(ter.get("your_rank", -1)), 3, "your_rank surfaced")
	_assert_equal(int(ter.get("rank_claim", -1)), OrgModel.RANK_CLAIM, "rank_claim rides the real OrgModel constant")
	_assert_equal(int(ter.get("rank_city", -1)), OrgModel.RANK_CITY, "rank_city rides the real OrgModel constant")
	_assert_equal(int(ter.get("org_members_online", -1)), 2, "org_members_online counts same-org connected peers")
	var claims_in_zone: Array = ter.get("claims_in_zone", [])
	_assert_equal(claims_in_zone.size(), 1, "the in-zone claim is surfaced")
	var claim0: Dictionary = claims_in_zone[0]
	for key in ["node_id", "org_id", "tier"]:
		_assert_true(claim0.has(key), "claim entry has '%s'" % key)
	_assert_equal(String(claim0.get("node_id", "")), "node_a", "claim node_id surfaced")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("snapshot_enrichment_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true, got false" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
