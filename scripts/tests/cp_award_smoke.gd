extends SceneTree
## Smoke test for the CP-award-on-disable economy hook (E19).
##
## Guards the pure Progression.award + raise_skill path that _award_cp in
## network_manager.gd exercises when a training target is disabled. We do NOT
## instantiate network_manager.gd (it is a Node autoload with sockets); instead
## we exercise the same Progression static methods it calls directly, using the
## same constant (COMBAT_CP_REWARD = 3) and the same track ("gameplay").
##
## Assertions:
##   1. new_wallet() starts at 0/0.
##   2. award("gameplay", 3) adds exactly 3 gameplay CP and leaves rp_cp at 0.
##   3. wallet_total after award equals 3.
##   4. can_raise returns true for a cheap skill (1D attribute + 0D bonus => cost 1).
##   5. raise_skill succeeds (ok=true), costs 1 CP, gameplay wallet drops by 1.
##   6. raise_skill on an empty wallet returns ok=false, reason="insufficient_cp".
##   7. award with amount=0 does not change the wallet.
##   8. award with a negative amount is clamped to zero (maxi guard).
##   9. rp_cp track: award("rp", 5) credits rp_cp only.
##  10. _spend drains gameplay first, then rp_cp (cross-track spend via raise_skill).
##  11. new_wallet clamps negative inputs to 0.

const COMBAT_CP_REWARD := 3  # mirror of network_manager.gd line 26

var _failures: Array[String] = []

func _init() -> void:
	var Progression = load("res://scripts/rules/progression_model.gd")
	var rules_script = load("res://scripts/rules/d6_rules.gd")
	var rules = rules_script.new()

	# 1. Fresh wallet starts empty.
	var w0 = Progression.new_wallet()
	_assert_equal(w0.get("gameplay_cp", -1), 0, "new_wallet gameplay_cp starts at 0")
	_assert_equal(w0.get("rp_cp", -1), 0, "new_wallet rp_cp starts at 0")

	# 2. award("gameplay", COMBAT_CP_REWARD) adds exactly 3 gameplay CP.
	var w1 = Progression.award(w0, "gameplay", COMBAT_CP_REWARD)
	_assert_equal(w1.get("gameplay_cp", -1), 3, "award 3 gameplay CP lands in gameplay_cp")
	_assert_equal(w1.get("rp_cp", -1), 0,     "award gameplay CP leaves rp_cp untouched")

	# 3. wallet_total reflects the award.
	_assert_equal(Progression.wallet_total(w1), 3, "wallet_total after award(gameplay,3) == 3")

	# 4. can_raise: a 1D attribute, 0D bonus — pip cost == 1 die == 1 CP — should be affordable.
	_assert_equal(Progression.can_raise(rules, w1, "1D", "0D"), true, "can_raise true when wallet >= cost")

	# 5. raise_skill succeeds, costs 1 CP (1D total => pip_cost=1), wallet drops by 1.
	var result = Progression.raise_skill(rules, w1, "1D", "0D")
	_assert_equal(result.get("ok"), true, "raise_skill ok=true when wallet is sufficient")
	_assert_equal(result.get("cost"), 1,  "raise_skill cost is 1 for 1D total pool")
	var w2 = result.get("wallet", {})
	_assert_equal(w2.get("gameplay_cp"), 2, "wallet after raise_skill has gameplay_cp 3-1=2")
	_assert_equal(w2.get("rp_cp"), 0,       "wallet after raise_skill rp_cp unchanged")

	# Confirm new_skill_bonus advanced by one pip from 0D: 0D+1
	_assert_equal(result.get("new_skill_bonus"), "0D+1", "raise_skill new_skill_bonus is 0D+1")

	# 6. raise_skill on an empty wallet fails.
	var w_empty = Progression.new_wallet()
	var failed = Progression.raise_skill(rules, w_empty, "1D", "0D")
	_assert_equal(failed.get("ok"),     false,              "raise_skill ok=false on empty wallet")
	_assert_equal(failed.get("reason"), "insufficient_cp",  "raise_skill reason=insufficient_cp")

	# 7. award with amount=0 does not change the wallet.
	var w3 = Progression.award(w1, "gameplay", 0)
	_assert_equal(w3.get("gameplay_cp"), 3, "award(0) leaves gameplay_cp unchanged")

	# 8. award with a negative amount is clamped (maxi(amount,0) in progression_model.gd line 54).
	var w4 = Progression.award(w1, "gameplay", -10)
	_assert_equal(w4.get("gameplay_cp"), 3, "award(-10) is clamped to zero, wallet unchanged")

	# 9. rp track: award("rp", 5) credits only rp_cp.
	var w5 = Progression.award(w0, "rp", 5)
	_assert_equal(w5.get("rp_cp", -1),      5, "award rp=5 lands in rp_cp")
	_assert_equal(w5.get("gameplay_cp", -1), 0, "award rp=5 leaves gameplay_cp untouched")

	# 10. Cross-track spend: gameplay drained first, remainder from rp_cp.
	#     Build a wallet with gameplay=1, rp=2, then raise a 2D total skill (cost=2).
	#     Expect gameplay_cp=0, rp_cp=1.
	var w_mixed = Progression.new_wallet(1, 2)
	_assert_equal(w_mixed.get("gameplay_cp"), 1, "new_wallet(1,2) gameplay_cp=1")
	_assert_equal(w_mixed.get("rp_cp"),       2, "new_wallet(1,2) rp_cp=2")
	var cross = Progression.raise_skill(rules, w_mixed, "2D", "0D")
	# 2D total => pip_cost = 2
	_assert_equal(cross.get("ok"),   true, "cross-track raise_skill ok=true")
	_assert_equal(cross.get("cost"), 2,    "cross-track cost is 2 for 2D total pool")
	var w_after = cross.get("wallet", {})
	_assert_equal(w_after.get("gameplay_cp"), 0, "cross-track spend drains gameplay_cp first")
	_assert_equal(w_after.get("rp_cp"),       1, "cross-track spend takes remainder from rp_cp")

	# 11. new_wallet clamps negative inputs to 0.
	var w_neg = Progression.new_wallet(-5, -99)
	_assert_equal(w_neg.get("gameplay_cp"), 0, "new_wallet(-5,0) clamps gameplay_cp to 0")
	_assert_equal(w_neg.get("rp_cp"),       0, "new_wallet(0,-99) clamps rp_cp to 0")

	rules.free()

	if _failures.is_empty():
		print("cp_award_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
