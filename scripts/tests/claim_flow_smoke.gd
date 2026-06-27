extends SceneTree
## Regression guard for the server's submit_claim_node VALIDATION PRECEDENCE (E23 + the
## int-coercion fix). network_manager is a Node autoload that is not headlessly
## instantiable, so — like the E15-E20 guards — this replicates its claim-command
## composition with the REAL OrgModel + TerritoryModel and locks the reason ordering:
##   no_org -> (membership/rank from org-model) -> secured_zone -> influence ->
##   node_unavailable (already claimed). org_model_smoke/territory_smoke cover the pure
## pieces; this covers the network_manager COMPOSITION around them.

const OrgModel := preload("res://scripts/net/org_model.gd")
const TerritoryModel := preload("res://scripts/net/territory_model.gd")

var _failures: Array[String] = []

# Faithful mirror of register_account's build.org branch (network_manager.gd register_account,
# gated by allow_test_org): returns the {org, seed_influence} the server would apply for a given
# allow_test_org flag + client-supplied build.org. On a real server (flag off) a client cannot
# self-assign org identity/rank/influence over the wire.
func _apply_build_org(allow_test_org: bool, build_org: Dictionary) -> Dictionary:
	if allow_test_org and not build_org.is_empty() and String(build_org.get("faction_id", "")) != "":
		return {
			"org": {
				"faction_id": String(build_org.get("faction_id", "")),
				"faction_axis": String(build_org.get("faction_axis", "independent")),
				"faction_rank": int(build_org.get("faction_rank", 1)),
				"faction_rep": int(build_org.get("faction_rep", 0)),
				"guild_ids": [],
			},
			"seed_influence": maxi(int(build_org.get("influence", 0)), 0),
		}
	return {"org": {}, "seed_influence": 0}

# Faithful mirror of submit_claim_node's validation chain (server-side).
func _claim_outcome(org_model, territory, org: Dictionary, node_id: String, security_base: String, org_influence: int) -> Dictionary:
	if org.is_empty():
		return {"ok": false, "reason": "no_org"}
	var check: Dictionary = org_model.can_claim_command(org, security_base, org_influence)
	if not bool(check["allowed"]):
		return {"ok": false, "reason": String(check["reason"])}
	var claim_id := "%s::%s" % [String(org.get("faction_id", "")), node_id]
	var claim: Dictionary = territory.claim_node(claim_id, node_id, "zone.test", String(org.get("faction_id", "")), security_base, org_influence)
	if claim.is_empty():
		return {"ok": false, "reason": "node_unavailable"}
	return {"ok": true, "reason": ""}

func _init() -> void:
	var org_model = OrgModel.new()
	var territory = TerritoryModel.new()
	var floor_infl := int(TerritoryModel.CLAIM_MIN_INFLUENCE)
	var rank3 := {"faction_id": "org_hutt_cartel", "faction_axis": "hutt", "faction_rank": 3, "faction_rep": 0, "guild_ids": []}
	var rank1 := rank3.duplicate()
	rank1["faction_rank"] = 1

	# Empty org -> no_org (the network_manager-specific guard, not in org_model).
	_assert_equal(String(_claim_outcome(org_model, territory, {}, "n1", "lawless", floor_infl)["reason"]), "no_org", "empty org -> no_org")

	# Rank below the claim rank -> rank; rank precedence even in a secured zone.
	_assert_equal(String(_claim_outcome(org_model, territory, rank1, "n1", "lawless", floor_infl)["reason"]), "rank", "rank < claim rank -> rank")
	_assert_equal(String(_claim_outcome(org_model, territory, rank1, "n2", "secured", floor_infl)["reason"]), "rank", "rank precedence over secured_zone")

	# Rank ok but secured zone -> secured_zone.
	_assert_equal(String(_claim_outcome(org_model, territory, rank3, "n3", "secured", floor_infl)["reason"]), "secured_zone", "secured zone not claimable")

	# Rank ok, claimable zone, influence below the floor -> influence.
	_assert_equal(String(_claim_outcome(org_model, territory, rank3, "n4", "lawless", floor_infl - 1)["reason"]), "influence", "influence below floor -> influence")

	# All preconditions met -> claim succeeds.
	var ok: Dictionary = _claim_outcome(org_model, territory, rank3, "n4", "lawless", floor_infl)
	_assert_true(bool(ok["ok"]), "rank3 + lawless + floor influence -> claim ok")

	# Re-claiming the now-owned node -> node_unavailable (composition over territory_model).
	_assert_equal(String(_claim_outcome(org_model, territory, rank3, "n4", "lawless", floor_infl)["reason"]), "node_unavailable", "already-claimed node -> node_unavailable")

	# A contested zone at the floor is also claimable.
	_assert_true(bool(_claim_outcome(org_model, territory, rank3, "n5", "contested", floor_infl)["ok"]), "contested zone is claimable")

	# F63: the EARN half of the loop (the tests above are the CLAIM half, given influence). A member's
	# kill-in-zone accrues KILL_TERRITORY_INFLUENCE org territory-influence (network_manager
	# _accrue_territory_influence: earned = max(0, current + gain), unbounded above), so a claim is
	# earnable through PLAY. Mirror the accrual and lock the earn->floor->claim crossing.
	var kill_gain := int(TerritoryModel.KILL_TERRITORY_INFLUENCE)
	_assert_true(kill_gain > 0, "kill territory-influence gain is positive")
	# Just below the floor -> a claim is rejected for influence (not yet earned).
	_assert_equal(String(_claim_outcome(org_model, territory, rank3, "earn_node", "lawless", floor_infl - 1)["reason"]), "influence", "one short of the floor -> influence")
	# Accrue from zero; the floor is crossed at exactly ceil(floor/gain) kills, not one fewer.
	var kills_to_claim := int(ceil(float(floor_infl) / float(kill_gain)))
	var earned := 0
	for _k in range(kills_to_claim):
		earned = maxi(earned + kill_gain, 0)
	_assert_true(earned >= floor_infl, "%d kills reach the claim floor %d (earned %d)" % [kills_to_claim, floor_infl, earned])
	_assert_true((kills_to_claim - 1) * kill_gain < floor_infl, "one fewer kill stays below the floor (crossing is at exactly %d kills)" % kills_to_claim)
	# At the crossing the play-earned influence claims a fresh node end-to-end.
	_assert_true(bool(_claim_outcome(org_model, territory, rank3, "earn_node", "lawless", earned)["ok"]), "%d kills' earned influence (%d) claims the node" % [kills_to_claim, earned])

	# SECURITY: the register_account build.org self-grant affordance is gated by allow_test_org.
	# A malicious client tries to self-onboard a rank-99 Hutt with claim-floor+ influence over the wire.
	var malicious := {"faction_id": "org_hutt_cartel", "faction_axis": "hutt", "faction_rank": 99, "faction_rep": 0, "influence": 1000}
	# On a REAL server (flag off) the build.org is IGNORED -> no org, no seeded influence ...
	var guard_off := _apply_build_org(false, malicious)
	_assert_true((guard_off["org"] as Dictionary).is_empty(), "allow_test_org off -> client build.org grants no org")
	_assert_equal(int(guard_off["seed_influence"]), 0, "allow_test_org off -> no seeded territory influence")
	# ... so the self-granted org is unclaimable: the claim chain rejects at the no_org guard.
	_assert_equal(String(_claim_outcome(org_model, territory, guard_off["org"], "spoof_node", "lawless", int(guard_off["seed_influence"]))["reason"]), "no_org", "self-granted org cannot claim on a real server (no_org)")
	# In TEST mode (flag on, the two-process harness) the affordance still works as before.
	var guard_on := _apply_build_org(true, malicious)
	_assert_equal(int((guard_on["org"] as Dictionary).get("faction_rank", 0)), 99, "allow_test_org on -> build.org applied (test affordance preserved)")
	_assert_equal(int(guard_on["seed_influence"]), 1000, "allow_test_org on -> influence seeded")
	_assert_true(bool(_claim_outcome(org_model, territory, guard_on["org"], "spoof_node", "lawless", int(guard_on["seed_influence"]))["ok"]), "test-mode org can claim (affordance preserved)")
	# An empty build.org is a no-op regardless of the flag.
	_assert_true((_apply_build_org(true, {})["org"] as Dictionary).is_empty(), "empty build.org -> no org even in test mode")

	if _failures.is_empty():
		print("claim_flow_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
