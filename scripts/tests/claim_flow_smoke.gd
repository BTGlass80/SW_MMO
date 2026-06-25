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
