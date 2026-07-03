extends SceneTree
## HARDENING smoke for the pure PvP-consent model (scripts/rules/pvp_consent_model.gd). Adversarial
## coverage beyond pvp_consent_model_smoke.gd, targeting the transition/accounting edges: the
## one-active-duel-per-player invariant across MULTIPLE pending offers (regression for a confirmed
## bug — see below), pair_key symmetry across numeric-string orderings, bounty pot-cap + fee
## accounting, pay_off / expire_bounties refund math, and non-mutation of every transition's input
## state. Deterministic; no RNG is drawn (model is RNG-free).

const Consent := preload("res://scripts/rules/pvp_consent_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	_test_double_accept_invariant_bug_fix()
	_test_abort_ends_all_of_a_players_live_duels()
	_test_pair_key_symmetry()
	_test_challenge_and_accept_non_mutating()
	_test_conclude_ko_and_yield()
	_test_expire_offer_vs_active_duration()
	_test_bounty_pot_cap_and_accounting()
	_test_pay_off_bounty_refunds()
	_test_expire_bounties_sweep()
	_test_place_bounty_non_mutating()
	_finish()

# ---------------------------------------------------------------------------------------------
# CONFIRMED BUG (fixed in this pass): accept() only checked the specific pair's own offer state,
# never that the acceptor/challenger wasn't ALREADY active elsewhere. Two different challengers can
# both have a live OFFERED record against the same target (challenge() only blocks a NEW offer while
# the challenger/target is already ACTIVE, not while merely offered-elsewhere). Before the fix, both
# offers could be independently accepted, leaving the shared player active in two duels at once —
# breaking the "one active duel per player" invariant `may_fire`/`build_ctx` implicitly assume
# (duel_active is looked up per-PAIR, so two simultaneously active pairs would both grant consent).
# ---------------------------------------------------------------------------------------------
func _test_double_accept_invariant_bug_fix() -> void:
	var st := Consent.new_state()
	# Two different challengers (11, 22) both offer a duel to the SAME target (99).
	var ch1 := Consent.challenge(st, 11, 99, "z", 0.0)
	_assert_true(bool(ch1["ok"]), "first challenger's offer to 99 is created")
	st = ch1["state"]
	var ch2 := Consent.challenge(st, 22, 99, "z", 0.0)
	_assert_true(bool(ch2["ok"]), "a second, different challenger may also offer 99 a duel (neither side is ACTIVE yet)")
	st = ch2["state"]

	# 99 accepts the first challenge -> active.
	var acc1 := Consent.accept(st, 11, 99, 1.0)
	_assert_true(bool(acc1["ok"]), "99 accepts the first offer")
	st = acc1["state"]
	_assert_true(Consent.duel_active(st, 11, 99), "11<->99 is active")

	# 99 (or the second challenger) tries to accept the SECOND offer while already active with 11.
	var acc2 := Consent.accept(st, 22, 99, 2.0)
	_assert_equal(bool(acc2["ok"]), false, "accepting a second offer while already in an active duel is REJECTED")
	_assert_equal(String(acc2["reason"]), "already_dueling", "rejection reason is already_dueling")
	# state must be UNCHANGED on rejection (accept is non-mutating on failure too).
	_assert_equal(acc2["state"], st, "a rejected accept() returns the state unchanged")
	_assert_true(not Consent.duel_active(st, 22, 99), "22<->99 never became active")
	_assert_true(Consent.duel_active(st, 11, 99), "11<->99 remains the sole active duel for 99")

# ---------------------------------------------------------------------------------------------
# CONFIRMED BUG (fixed in this pass): abort(who) returned after ending only the FIRST live duel it
# found in dict-insertion order. A player can legitimately hold a pending OFFERED challenge AND an
# ACTIVE duel at the same time (accept() does not clean up a player's other standing offers, and
# challenge() only blocks a NEW offer while a side is already ACTIVE — not while merely offered). If
# the OFFERED record was inserted BEFORE the ACTIVE one, abort() ended the harmless offer and LEFT
# THE ACTIVE DUEL LIVE — so a player who disconnects / leaves the zone stayed mutually attackable
# (may_fire still returns duel-consent for the still-active pair). abort() must end EVERY live duel
# involving `who`, not just the first one encountered.
# ---------------------------------------------------------------------------------------------
func _test_abort_ends_all_of_a_players_live_duels() -> void:
	var st := Consent.new_state()
	# Insert an OFFERED duel 11<->99 FIRST (the record abort used to wrongly stop on)...
	st = Consent.challenge(st, 11, 99, "z", 0.0)["state"]
	# ...then a SECOND offer 22<->99, which 99 accepts -> 22<->99 becomes ACTIVE (inserted later).
	st = Consent.challenge(st, 22, 99, "z", 0.0)["state"]
	st = Consent.accept(st, 22, 99, 1.0)["state"]
	_assert_true(Consent.duel_active(st, 22, 99), "setup: 22<->99 is the active duel; 11<->99 is a lingering offer")

	# 99 disconnects / leaves -> abort must terminate BOTH the active duel and the lingering offer.
	var ab := Consent.abort(st, 99)
	_assert_true(bool(ab["ok"]), "abort(99) reports it ended at least one duel")
	var st_ab: Dictionary = ab["state"]
	_assert_true(not Consent.duel_active(st_ab, 22, 99),
		"abort(99) MUST end 99's ACTIVE duel, not just the earlier-inserted offer (else the disconnecting player stays attackable)")
	# The lingering offer is also cleared (99 can no longer be dueled by it).
	var offer_rec: Dictionary = (st_ab["duels"] as Dictionary)[Consent.pair_key(11, 99)]
	_assert_equal(String(offer_rec.get("state", "")), "ended", "abort(99) also ends 99's lingering OFFERED challenge")
	# And nobody is left able to open PvP against the disconnected player via a stale consent record.
	var A99 := {"id": 99, "is_player": true, "node_id": "z", "newbie_protected": false}
	var A22 := {"id": 22, "is_player": true, "node_id": "z", "newbie_protected": false}
	_assert_equal(bool(Consent.may_fire(st_ab, A22, A99, "secured").get("allowed")), false,
		"after abort, the ex-opponent can no longer fire the disconnected player in a protected zone")

func _test_pair_key_symmetry() -> void:
	# String-int ids where the LEXICOGRAPHIC compare disagrees with numeric compare ("10" < "2")
	# must still produce a stable, order-independent key.
	_assert_equal(Consent.pair_key(2, 10), Consent.pair_key(10, 2), "pair_key is symmetric across numeric ids")
	_assert_equal(Consent.pair_key("alice", "bob"), Consent.pair_key("bob", "alice"), "pair_key is symmetric across string ids")
	_assert_equal(Consent.pair_key(5, 5), "5|5", "pair_key of a value with itself is well-formed")

func _test_challenge_and_accept_non_mutating() -> void:
	var st := Consent.new_state()
	var snapshot := st.duplicate(true)
	var _ch := Consent.challenge(st, 1, 2, "z", 0.0)
	_assert_equal(st, snapshot, "challenge() does not mutate its input state")

	st = Consent.challenge(st, 1, 2, "z", 0.0)["state"]
	var snapshot2 := st.duplicate(true)
	var _acc := Consent.accept(st, 1, 2, 5.0)
	_assert_equal(st, snapshot2, "accept() does not mutate its input state")

func _test_conclude_ko_and_yield() -> void:
	var st := Consent.new_state()
	st = Consent.challenge(st, 1, 2, "z", 0.0)["state"]
	st = Consent.accept(st, 1, 2, 1.0)["state"]
	# KO: the LOSER is recorded; the standing party wins.
	var ko := Consent.conclude_ko(st, 1)
	_assert_true(bool(ko["ok"]), "conclude_ko ends the active duel for the loser")
	var rec: Dictionary = (ko["state"]["duels"] as Dictionary)[Consent.pair_key(1, 2)]
	_assert_equal(String((rec["result"] as Dictionary)["outcome"]), "ko", "outcome recorded as ko")
	_assert_equal((rec["result"] as Dictionary)["winner"], 2, "the non-loser (2) is recorded as winner")
	_assert_true(not Consent.duel_active(ko["state"], 1, 2), "the duel is no longer active after KO")

	# yield: the YIELDING party is who is passed; the opponent wins.
	var st2 := Consent.new_state()
	st2 = Consent.challenge(st2, 3, 4, "z", 0.0)["state"]
	st2 = Consent.accept(st2, 3, 4, 1.0)["state"]
	var yr := Consent.yield_duel(st2, 4)
	_assert_true(bool(yr["ok"]), "yield_duel ends the active duel for the yielder")
	var rec2: Dictionary = (yr["state"]["duels"] as Dictionary)[Consent.pair_key(3, 4)]
	_assert_equal((rec2["result"] as Dictionary)["winner"], 3, "the non-yielder (3) is recorded as winner")

	# a KO/yield on someone with NO active duel is a clean no-op failure.
	_assert_equal(bool(Consent.conclude_ko(Consent.new_state(), 99)["ok"]), false, "conclude_ko with no active duel fails cleanly")
	_assert_equal(bool(Consent.yield_duel(Consent.new_state(), 99)["ok"]), false, "yield_duel with no active duel fails cleanly")

func _test_expire_offer_vs_active_duration() -> void:
	# An ACTIVE duel with a finite max_duration expires to a TIMED DRAW when now reaches it.
	var st := Consent.new_state()
	st = Consent.challenge(st, 1, 2, "z", 0.0)["state"]
	st = Consent.accept(st, 1, 2, 0.0, 100.0)["state"]  # max_duration = 100
	var not_yet := Consent.expire(st, 99.0)
	_assert_equal(bool(not_yet["ok"]), false, "no expiry fires before max_duration elapses")
	_assert_true(Consent.duel_active(not_yet["state"], 1, 2), "duel still active just before its cap")
	var timed_out := Consent.expire(st, 100.0)
	_assert_true(bool(timed_out["ok"]), "duel expires exactly at max_duration")
	var rec: Dictionary = (timed_out["state"]["duels"] as Dictionary)[Consent.pair_key(1, 2)]
	_assert_equal((rec["result"] as Dictionary)["winner"], null, "a timed-out duel has no winner (draw)")
	_assert_equal(String((rec["result"] as Dictionary)["outcome"]), "expire", "timed-out outcome is 'expire'")

	# An UNCAPPED duel (max_duration = 0) never auto-expires from the duration branch.
	var st2 := Consent.new_state()
	st2 = Consent.challenge(st2, 5, 6, "z", 0.0)["state"]
	st2 = Consent.accept(st2, 5, 6, 0.0, 0.0)["state"]  # uncapped
	var never := Consent.expire(st2, 1_000_000.0)
	_assert_equal(bool(never["ok"]), false, "an uncapped active duel never expires from duration")
	_assert_true(Consent.duel_active(never["state"], 5, 6), "the uncapped duel is still active")

func _test_bounty_pot_cap_and_accounting() -> void:
	var st := Consent.new_state()
	# Two placements that together would exceed BOUNTY_MAX must clamp the SECOND contribution.
	var p1 := Consent.place_bounty(st, 1, 100, Consent.BOUNTY_MAX - 1000, 0.0)
	_assert_true(bool(p1["ok"]), "first large placement accepted")
	st = p1["state"]
	_assert_equal(Consent.bounty_pot(st, 100), Consent.BOUNTY_MAX - 1000, "pot after placement #1")
	var p2 := Consent.place_bounty(st, 2, 100, 5000, 0.0)  # would push pot 4000 over the cap
	_assert_true(bool(p2["ok"]), "second placement still succeeds (clamped, not rejected)")
	st = p2["state"]
	_assert_equal(Consent.bounty_pot(st, 100), Consent.BOUNTY_MAX, "pot clamps exactly at BOUNTY_MAX, never over")

	# Contributor accounting always sums EXACTLY to the pot (net_add, not the raw attempted amount).
	var rec: Dictionary = (st["bounties"] as Dictionary)["100"]
	var total := 0
	for c in rec["contributors"]:
		total += int((c as Dictionary)["amount"])
	_assert_equal(total, Consent.bounty_pot(st, 100), "sum of contributor escrow amounts equals the pot exactly")
	# the clamped contributor's recorded amount is the CLIPPED net_add (1000), not the raw 5000 attempt.
	_assert_equal(int((rec["contributors"] as Array)[1]["amount"]), 1000, "an overflowing contribution is recorded at its clamped (net) amount")

	# a bounty below MIN_BOUNTY on the SECOND placement (topping-up an existing pot) still requires the
	# per-call floor -- place_bounty enforces MIN_BOUNTY on every individual call, not just the first.
	var st2 := Consent.new_state()
	st2 = Consent.place_bounty(st2, 1, 200, Consent.MIN_BOUNTY, 0.0)["state"]
	_assert_equal(bool(Consent.place_bounty(st2, 2, 200, 10, 0.0)["ok"]), false, "a top-up placement is still held to MIN_BOUNTY")

func _test_pay_off_bounty_refunds() -> void:
	var st := Consent.new_state()
	st = Consent.place_bounty(st, 1, 50, 1000, 0.0)["state"]
	st = Consent.place_bounty(st, 2, 50, 500, 0.0)["state"]
	_assert_equal(Consent.bounty_pot(st, 50), 1500, "pot accumulates both placements")
	var payoff := Consent.pay_off_bounty(st, 50)
	_assert_true(bool(payoff["ok"]), "pay_off succeeds on an active bounty")
	_assert_equal(int(payoff["cost"]), int(ceil(1500.0 * Consent.PAYOFF_MULTIPLIER)), "payoff cost = pot x multiplier (rounded up)")
	var refunds: Dictionary = payoff["refunds"]
	_assert_equal(int(refunds[1]), 1000, "contributor 1 refunded their exact escrow")
	_assert_equal(int(refunds[2]), 500, "contributor 2 refunded their exact escrow")
	_assert_true(not Consent.has_bounty(payoff["state"], 50), "the bounty record is removed after payoff")

	# pay_off on a non-existent bounty fails cleanly.
	var none := Consent.pay_off_bounty(Consent.new_state(), 999)
	_assert_equal(bool(none["ok"]), false, "pay_off on a missing bounty fails")
	_assert_equal((none["refunds"] as Dictionary).size(), 0, "no refunds on a missing bounty")

func _test_expire_bounties_sweep() -> void:
	var st := Consent.new_state()
	st = Consent.place_bounty(st, 1, 77, 1000, 0.0)["state"]     # expires at 0 + BOUNTY_TTL
	st = Consent.place_bounty(st, 2, 88, 2000, 500.0)["state"]   # expires at 500 + BOUNTY_TTL (still fresh)
	# sweep at a time past #77's TTL but before #88's.
	var swept := Consent.expire_bounties(st, Consent.BOUNTY_TTL + 1.0)
	_assert_true(bool(swept["ok"]), "sweep reports a change when at least one bounty expires")
	_assert_true(not Consent.has_bounty(swept["state"], 77), "the expired bounty (77) is removed")
	_assert_true(Consent.has_bounty(swept["state"], 88), "the still-fresh bounty (88) survives the sweep")
	var refunds: Dictionary = swept["refunds"]
	_assert_equal(int(refunds[1]), 1000, "the expired bounty's contributor is refunded in the sweep result")
	_assert_true(not refunds.has(2), "an un-expired bounty's contributor is not refunded")

	# a sweep that expires nothing reports ok=false and an empty refund map.
	var nothing := Consent.expire_bounties(Consent.new_state(), 0.0)
	_assert_equal(bool(nothing["ok"]), false, "sweeping an empty state reports no change")
	_assert_equal((nothing["refunds"] as Dictionary).size(), 0, "no refunds when nothing expired")

func _test_place_bounty_non_mutating() -> void:
	var st := Consent.new_state()
	st = Consent.place_bounty(st, 1, 50, 1000, 0.0)["state"]
	var snapshot := st.duplicate(true)
	var _p2 := Consent.place_bounty(st, 2, 50, 500, 0.0)
	_assert_equal(st, snapshot, "place_bounty does not mutate its input state")
	var _col := Consent.collect_bounty(st, 50, 3)
	_assert_equal(st, snapshot, "collect_bounty does not mutate its input state")

func _finish() -> void:
	if _failures.is_empty():
		print("pvp_consent_model_edge_smoke: OK")
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
