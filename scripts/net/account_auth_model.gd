extends RefCounted
## Pure account-auth + RPC rate-limit helpers (E26). Headlessly testable; the live
## NetworkManager calls these with a real clock (Time.get_ticks_msec). Closes the
## identity-spoofing gap via an account_secret bound to the persisted record, and a
## token bucket so a peer can't flood reliable RPCs.

const DEFAULT_RPC_RATE := 25.0   # reliable RPCs/sec sustained
const DEFAULT_RPC_BURST := 50.0  # bucket capacity (burst allowance)

## Ownership guard. `stored` is the account's bound secret ("" = unsecured / unclaimed);
## `provided` is what the connecting client sent. Returns {ok, reason, secret}: on ok the
## caller writes `secret` onto the record. An unsecured account is CLAIMED by the provided
## secret (which may be "", leaving it open — backward compatible with pre-E26 saves); a
## secured account requires an EXACT match.
static func check_secret(stored: String, provided: String) -> Dictionary:
	if stored == "":
		return {"ok": true, "reason": "", "secret": provided}
	if stored == provided:
		return {"ok": true, "reason": "", "secret": stored}
	return {"ok": false, "reason": "bad_secret", "secret": ""}

## Token-bucket refill + consume. `budget` = {"tokens": float, "last_ms": int} ({} -> a
## full bucket). Returns {allowed: bool, budget: <new budget>}. Pure: the caller supplies
## `now_ms`, so it is deterministic and testable without a real clock.
static func consume_token(budget: Dictionary, now_ms: int, rate: float = DEFAULT_RPC_RATE, burst: float = DEFAULT_RPC_BURST) -> Dictionary:
	var tokens := float(budget.get("tokens", burst))
	var last_ms := int(budget.get("last_ms", now_ms))
	var elapsed := float(maxi(now_ms - last_ms, 0)) / 1000.0
	tokens = minf(tokens + elapsed * rate, burst)
	var allowed := tokens >= 1.0
	if allowed:
		tokens -= 1.0
	return {"allowed": allowed, "budget": {"tokens": tokens, "last_ms": now_ms}}
