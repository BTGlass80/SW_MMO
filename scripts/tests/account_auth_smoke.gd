extends SceneTree
## Headless smoke for the pure account-auth + rate-limit helpers (E26). Verifies the
## ownership-secret guard (claim/match/mismatch/backward-compat) and the token-bucket
## refill+consume with an explicit clock.

const Auth := preload("res://scripts/net/account_auth_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- check_secret ---
	var claim: Dictionary = Auth.check_secret("", "tok123")
	_assert_true(bool(claim["ok"]) and String(claim["secret"]) == "tok123", "unsecured account is claimed by the provided secret")
	var match_ok: Dictionary = Auth.check_secret("tok123", "tok123")
	_assert_true(bool(match_ok["ok"]) and String(match_ok["secret"]) == "tok123", "matching secret accepted, secret preserved")
	var mismatch: Dictionary = Auth.check_secret("tok123", "wrong")
	_assert_true(not bool(mismatch["ok"]) and String(mismatch["reason"]) == "bad_secret", "wrong secret rejected (bad_secret)")
	var open_acct: Dictionary = Auth.check_secret("", "")
	_assert_true(bool(open_acct["ok"]) and String(open_acct["secret"]) == "", "unsecured + no secret stays open (backward compatible)")
	var secured_no_secret: Dictionary = Auth.check_secret("tok123", "")
	_assert_true(not bool(secured_no_secret["ok"]), "a secured account rejects an empty secret")

	# --- consume_token (token bucket) ---
	var fresh: Dictionary = Auth.consume_token({}, 0, 25.0, 50.0)
	_assert_true(bool(fresh["allowed"]), "a fresh (full) bucket allows an RPC")
	_assert_true(is_equal_approx(float((fresh["budget"] as Dictionary)["tokens"]), 49.0), "full bucket 50 -> 49 after one consume")

	var drained: Dictionary = Auth.consume_token({"tokens": 0.0, "last_ms": 0}, 0, 25.0, 50.0)
	_assert_true(not bool(drained["allowed"]), "an empty bucket with no time elapsed denies")

	var refilled: Dictionary = Auth.consume_token({"tokens": 0.0, "last_ms": 0}, 1000, 25.0, 50.0)
	_assert_true(bool(refilled["allowed"]), "1s of refill at rate 25 re-allows")
	_assert_true(float((refilled["budget"] as Dictionary)["tokens"]) >= 23.0, "~25 tokens refilled (minus the one consumed)")

	# Sustained over-rate is throttled: from a full bucket, draining faster than the
	# refill rate eventually denies.
	var budget: Dictionary = {}
	var denied_count := 0
	for i in range(120):
		var r: Dictionary = Auth.consume_token(budget, 0, 25.0, 50.0)  # all at the same instant -> no refill
		budget = r["budget"]
		if not bool(r["allowed"]):
			denied_count += 1
	_assert_true(denied_count > 0, "draining a bucket without refill eventually throttles")

	# Burst cap: a long idle never exceeds `burst`.
	var capped: Dictionary = Auth.consume_token({"tokens": 0.0, "last_ms": 0}, 100000, 25.0, 50.0)
	_assert_true(float((capped["budget"] as Dictionary)["tokens"]) <= 50.0, "tokens are capped at the burst ceiling")

	if _failures.is_empty():
		print("account_auth_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)
