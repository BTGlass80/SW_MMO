extends SceneTree
## Headless smoke test for the org-territory model (M2.1).
## Verifies claim preconditions (claimable tiers, influence threshold, one-per-node),
## influence-tier + effective-security derivation, and passive income accrual
## (tier scaling, lawless > contested, deterministic over ticks).

const Territory := preload("res://scripts/net/territory_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- derivation ---
	_assert_equal(Territory.influence_tier(75), "control", "influence 75 -> control")
	_assert_equal(Territory.influence_tier(50), "dominant", "influence 50 -> dominant")
	_assert_equal(Territory.influence_tier(25), "foothold", "influence 25 -> foothold")
	_assert_equal(Territory.security_effective("lawless"), "contested", "claiming upgrades lawless -> contested for members")
	_assert_equal(Territory.security_effective("contested"), "contested", "contested stays contested")

	# --- claim preconditions ---
	var t: Territory = Territory.new()
	_assert_true(not t.can_claim("n1", "secured", 99), "secured zones cannot be claimed")
	_assert_true(not t.can_claim("n1", "contested", 10), "below the influence floor cannot claim")
	_assert_true(t.can_claim("n1", "contested", 25), "contested + enough influence can claim")

	# Reject a claim that fails its precondition.
	_assert_true(t.claim_node("c0", "n0", "z", "org_a", "secured", 99).is_empty(), "secured claim rejected")
	_assert_equal(t.claim_count(), 0, "no claim recorded on rejection")

	# A valid contested claim.
	var claim := t.claim_node("c1", "n1", "tatooine.jundland", "org_hutt", "contested", 50)
	_assert_true(not claim.is_empty(), "valid contested claim accepted")
	_assert_equal(String(claim["influence_tier_at_claim"]), "dominant", "influence 50 claim is dominant tier")
	_assert_equal(String(claim["security_effective"]), "contested", "contested claim effective security")
	_assert_equal(t.claim_for_node("n1"), "c1", "node maps to its claim")
	# One claim per node.
	_assert_true(t.claim_node("c1b", "n1", "tatooine.jundland", "org_cis", "contested", 90).is_empty(), "second claim on a node is rejected")

	# A lawless control claim (higher risk/reward).
	t.claim_node("c2", "n2", "tatooine.dune_sea", "org_hutt", "lawless", 80)
	_assert_equal(String(t.get_claim("c2")["influence_tier_at_claim"]), "control", "influence 80 claim is control tier")
	_assert_equal(String(t.get_claim("c2")["security_effective"]), "contested", "lawless claim upgrades to contested for members")

	# --- income accrual ---
	var contested_dominant := Territory.income_for("contested", "dominant")
	var lawless_control := Territory.income_for("lawless", "control")
	var lawless_dominant := Territory.income_for("lawless", "dominant")
	_assert_equal(int(contested_dominant["credits"]), 200, "contested dominant base yield")
	_assert_true(int(lawless_dominant["credits"]) > int(contested_dominant["credits"]), "lawless yields more than contested at the same tier")
	_assert_true(int(lawless_control["credits"]) > int(lawless_dominant["credits"]), "higher tier yields more")

	# Accrual credits the org treasuries; org_hutt owns both claims (c1 contested dominant + c2 lawless control).
	var expected_per_tick := int(contested_dominant["credits"]) + int(lawless_control["credits"])
	t.accrue_income()
	_assert_equal(t.get_org_credits("org_hutt"), expected_per_tick, "one tick credits the org for all its claims")
	t.accrue_income()
	_assert_equal(t.get_org_credits("org_hutt"), expected_per_tick * 2, "income accrues each tick (deterministic)")

	# Release frees the node for a future claim.
	t.release_claim("c1")
	_assert_true(not t.has_claim("c1"), "released claim is gone")
	_assert_equal(t.claim_for_node("n1"), "", "released node is free to claim again")

	# --- F59: org claims + treasuries survive a server restart (to_dict / apply_persisted) ---
	var live: Territory = Territory.new()
	live.claim_node("pc1", "pn1", "tatooine.jundland", "org_hutt", "contested", 50)  # dominant
	live.claim_node("pc2", "pn2", "tatooine.dune_sea", "org_cis", "lawless", 80)     # control
	live.accrue_income()
	var blob := live.to_dict()
	var booted: Territory = Territory.new()
	booted.apply_persisted(blob)
	_assert_equal(booted.to_dict(), blob, "F59: apply_persisted reproduces the exact saved claim state")
	_assert_equal(booted.claim_count(), 2, "F59: claims restored across restart")
	_assert_equal(booted.get_org_credits("org_hutt"), live.get_org_credits("org_hutt"), "F59: org treasury restored")
	_assert_equal(booted.claim_for_node("pn2"), "pc2", "F59: node->claim index rebuilt on restore")
	# The rebuilt index still enforces one-claim-per-node after a restart.
	_assert_true(booted.claim_node("pc2b", "pn2", "tatooine.dune_sea", "org_hutt", "lawless", 80).is_empty(), "F59: restored node index still rejects a double claim")
	# Income keeps accruing post-restore (proves the claims are fully live, not just inert data).
	booted.accrue_income()
	_assert_equal(booted.get_org_credits("org_cis"), live.get_org_credits("org_cis") * 2, "F59: restored claims keep yielding income")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("territory_smoke: OK")
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
