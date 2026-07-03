extends SceneTree
## Bounty-as-consent flow guard (DIV-0022). Exercises the pure bounty lifecycle the HOT layer drives:
## place (escrow + posting-fee SINK), the §1.2 precedence (bounty grants LETHAL attackability to an
## eligible non-placer hunter in contested+lawless, NOT secured, NOT newbie-shielded), collect ONCE on
## the target's death (pot cleared), and the no-self / no-placer collection guards. Character-id keyed
## (the persisted book). Deterministic, no RNG/sockets.

const PvpConsent := preload("res://scripts/rules/pvp_consent_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var st := PvpConsent.new_state()

	# --- place: escrow into the pot + a non-refundable posting fee sink ---
	var res: Dictionary = PvpConsent.place_bounty(st, "char_placer", "char_target", 500, 1000.0)
	_assert_true(bool(res.get("ok", false)), "place_bounty on another player succeeds")
	st = res["state"]
	_assert_equal(int(res.get("pot", 0)), 500, "the pot equals the escrowed amount")
	_assert_equal(int(res.get("posting_fee", 0)), PvpConsent.posting_fee_for(500), "the posting fee is skimmed on placement")
	_assert_equal(PvpConsent.posting_fee_for(500), 50, "10% posting fee on 500 = 50 (the SINK)")
	# The HOT layer debits escrow + fee (550); a later collect returns 500 to the hunter -> NET sink = the fee.
	_assert_equal(500 + PvpConsent.posting_fee_for(500), 550, "placement debits escrow + fee (550); net economy sink is the 50 fee")
	_assert_true(PvpConsent.has_bounty(st, "char_target"), "the target now carries an active bounty")

	# --- no self-bounty ---
	var self_b: Dictionary = PvpConsent.place_bounty(st, "char_target", "char_target", 500, 1001.0)
	_assert_equal(String(self_b.get("reason", "")), "self_bounty", "a player cannot place a bounty on themselves")
	# --- below the minimum stake ---
	var low_b: Dictionary = PvpConsent.place_bounty(st, "char_placer", "char_other", 10, 1002.0)
	_assert_equal(String(low_b.get("reason", "")), "below_minimum", "a below-MIN_BOUNTY placement is rejected")

	# --- stacking: a second placement accumulates the pot ---
	var add: Dictionary = PvpConsent.place_bounty(st, "char_ric", "char_target", 300, 1100.0)
	st = add["state"]
	_assert_equal(int(add.get("pot", 0)), 800, "a second placement ACCUMULATES the pot (500 + 300)")

	# --- eligibility precedence (server pre-resolves bounty_eligible) ---
	_assert_true(PvpConsent.bounty_eligible(st, "char_hunter", "char_target", "lawless"), "a non-placer hunter is eligible in lawless")
	_assert_true(PvpConsent.bounty_eligible(st, "char_hunter", "char_target", "contested"), "a non-placer hunter is eligible in contested")
	_assert_true(not PvpConsent.bounty_eligible(st, "char_hunter", "char_target", "secured"), "NO one is bounty-eligible in secured (civic core stays sanctuary)")
	_assert_true(not PvpConsent.bounty_eligible(st, "char_placer", "char_target", "lawless"), "a CONTRIBUTOR/placer is NOT eligible (no self-collection funnel)")
	_assert_true(not PvpConsent.bounty_eligible(st, "char_target", "char_target", "lawless"), "the TARGET is not eligible on themselves")

	# --- resolve(): a bountied lawless target resolves as reason 'bounty', lethal, tagged for collection ---
	var A := {"id": "char_hunter", "is_player": true, "node_id": "z", "newbie_protected": false}
	var B := {"id": "char_target", "is_player": true, "node_id": "z", "newbie_protected": false}
	var r := PvpConsent.resolve(A, B, {"zone_tier": "lawless", "duel_active": false, "bounty_eligible": true})
	_assert_equal(String(r.get("reason", "")), "bounty", "an eligible bounty is tagged BEFORE lawless_open so the kill credits the contract")
	_assert_equal(bool(r.get("lethal", false)), true, "a bounty kill is lethal")
	# newbie protection (rule 6) still shields a protected target from the bounty path (rule 7).
	var Bn := {"id": "char_target", "is_player": true, "node_id": "z", "newbie_protected": true}
	var rn := PvpConsent.resolve(A, Bn, {"zone_tier": "lawless", "duel_active": false, "bounty_eligible": true})
	_assert_equal(String(rn.get("reason", "")), "newbie_protected", "a newbie-protected target is NOT bounty-huntable (rule 6 above rule 7)")

	# --- collection guards: no self / no placer ---
	var self_c: Dictionary = PvpConsent.collect_bounty(st, "char_target", "char_target")
	_assert_equal(String(self_c.get("reason", "")), "self_collect", "the target cannot collect their own bounty")
	var placer_c: Dictionary = PvpConsent.collect_bounty(st, "char_target", "char_placer")
	_assert_equal(String(placer_c.get("reason", "")), "placer_collect", "a placer/contributor cannot collect (self-funnel blocked)")

	# --- collect ONCE on death: payout to the hunter, pot cleared ---
	var col: Dictionary = PvpConsent.collect_bounty(st, "char_target", "char_hunter")
	_assert_true(bool(col.get("ok", false)), "an eligible hunter collects on the target's death")
	_assert_equal(int(col.get("payout", 0)), 800, "the payout is the full accumulated pot")
	st = col["state"]
	_assert_true(not PvpConsent.has_bounty(st, "char_target"), "the pot is CLEARED after collection (record removed)")
	var again: Dictionary = PvpConsent.collect_bounty(st, "char_target", "char_hunter")
	_assert_equal(String(again.get("reason", "")), "no_bounty", "a collected bounty cannot be collected a SECOND time (collect-once)")

	if _failures.is_empty():
		print("bounty_flow_smoke: OK")
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
