extends SceneTree
## Regression guard for the server's register_account COMPOSITION PRECEDENCE (E26 + the
## post-Wave-E hardening fixes). network_manager is a Node autoload that is not headlessly
## instantiable, so — like claim_flow_smoke / the E15-E20 guards — this replicates its
## register wiring with the REAL AccountAuthModel and locks the ordering + the two MEDIUM
## bugs adversarial review caught (which the stock once-per-session client never exercised,
## so the gate/two-process missed them):
##   rate-limit -> auth(secret) -> single-session lock -> bind -> org set/CLEAR.
##   BUG #1 (org never cleared): re-registering a peer from an org char to a no-org char
##          must ERASE _peer_orgs/_peer_axes, not leave a stale faction.
##   BUG #2 (no single-session lock): a second peer claiming a char another connected peer
##          already owns must be denied `already_logged_in` (but the SAME peer may re-bind).
## account_auth_smoke covers the pure check_secret/token-bucket; this covers the
## network_manager COMPOSITION around them.

const Auth := preload("res://scripts/net/account_auth_model.gd")

var _failures: Array[String] = []

# Faithful mirror of register_account's server-side precedence. Mutates `st` (the server
# state: peer_characters/peer_orgs/peer_axes/records/budgets) exactly as the RPC does and
# returns {ok, reason}. `now_ms` is supplied so the rate-limit stays deterministic.
func _register(st: Dictionary, sender: int, character_id: String, build: Dictionary, now_ms: int) -> Dictionary:
	# 1. rate-limit gates before anything else.
	var rl: Dictionary = Auth.consume_token(st["budgets"].get(sender, {}), now_ms)
	st["budgets"][sender] = rl["budget"]
	if not bool(rl["allowed"]):
		return {"ok": false, "reason": "rate_limited"}
	# 2. auth: present the matching secret BEFORE loading/overwriting/binding.
	var record: Dictionary = (st["records"].get(character_id, {}) as Dictionary).duplicate(true)
	var auth: Dictionary = Auth.check_secret(String(record.get("account_secret", "")), String(build.get("secret", "")))
	if not bool(auth["ok"]):
		return {"ok": false, "reason": String(auth["reason"])}
	# 3. single-session lock: another CONNECTED peer must not already own this character.
	for pid in st["peer_characters"].keys():
		if pid != sender and String(st["peer_characters"][pid]) == character_id:
			return {"ok": false, "reason": "already_logged_in"}
	# 4. bind + persist secret.
	st["peer_characters"][sender] = character_id
	record["account_secret"] = String(auth["secret"])
	# Optional org from the build (test affordance); else the record keeps whatever it loaded.
	var build_org: Dictionary = build.get("org", {})
	if not build_org.is_empty() and String(build_org.get("faction_id", "")) != "":
		record["org"] = {
			"faction_id": String(build_org.get("faction_id", "")),
			"faction_axis": String(build_org.get("faction_axis", "independent")),
			"faction_rank": int(build_org.get("faction_rank", 1)),
		}
	# 5. ALWAYS refresh _peer_orgs/_peer_axes from the record — set when present, CLEAR when not.
	if record.has("org") and typeof(record["org"]) == TYPE_DICTIONARY:
		st["peer_orgs"][sender] = String((record["org"] as Dictionary).get("faction_id", ""))
		st["peer_axes"][sender] = String((record["org"] as Dictionary).get("faction_axis", ""))
	else:
		st["peer_orgs"].erase(sender)
		st["peer_axes"].erase(sender)
	st["records"][character_id] = record
	return {"ok": true, "reason": ""}

func _fresh_state() -> Dictionary:
	return {"peer_characters": {}, "peer_orgs": {}, "peer_axes": {}, "records": {}, "budgets": {}}

func _init() -> void:
	var hutt := {"faction_id": "org_hutt_cartel", "faction_axis": "hutt", "faction_rank": 3}

	# --- Auth precedence ---
	var st: Dictionary = _fresh_state()
	# Fresh unsecured account is claimed by the provided secret, which is bound to the record.
	_assert_true(bool(_register(st, 10, "alice", {"secret": "swordfish"}, 0)["ok"]), "fresh unsecured claim -> ok")
	_assert_equal(String((st["records"]["alice"] as Dictionary).get("account_secret", "")), "swordfish", "secret bound on first claim")
	# A later session with the WRONG secret is denied bad_secret and does NOT bind the peer.
	var bad: Dictionary = _register(st, 11, "alice", {"secret": "guess"}, 0)
	_assert_equal(String(bad["reason"]), "bad_secret", "wrong secret -> bad_secret")
	_assert_true(not st["peer_characters"].has(11), "denied auth never binds the peer")

	# --- Auth BEFORE the single-session lock: a wrong secret reports bad_secret even when a
	#     session conflict also exists (auth is checked first). ---
	var st2: Dictionary = _fresh_state()
	(st2["records"] as Dictionary)["vault"] = {"account_secret": "key"}
	_assert_true(bool(_register(st2, 20, "vault", {"secret": "key"}, 0)["ok"]), "owner binds secured char")
	_assert_equal(String(_register(st2, 21, "vault", {"secret": "nope"}, 0)["reason"]), "bad_secret", "auth precedes lock (bad_secret, not already_logged_in)")

	# --- Single-session lock (BUG #2) ---
	var st3: Dictionary = _fresh_state()
	_assert_true(bool(_register(st3, 30, "han", {}, 0)["ok"]), "peer 30 binds han")
	_assert_equal(String(_register(st3, 31, "han", {}, 0)["reason"]), "already_logged_in", "second peer on same char -> already_logged_in")
	_assert_true(bool(_register(st3, 31, "chewie", {}, 0)["ok"]), "the second peer may bind a DIFFERENT char")
	# The SAME peer may re-bind its own character (pid == sender is skipped by the lock).
	_assert_true(bool(_register(st3, 30, "han", {}, 0)["ok"]), "same peer re-binds its own char")

	# --- Org set-then-CLEAR on re-register (BUG #1) ---
	var st4: Dictionary = _fresh_state()
	_assert_true(bool(_register(st4, 40, "boss", {"org": hutt}, 0)["ok"]), "peer 40 registers an org char")
	_assert_equal(String(st4["peer_orgs"].get(40, "")), "org_hutt_cartel", "org char -> _peer_orgs set")
	_assert_equal(String(st4["peer_axes"].get(40, "")), "hutt", "org char -> _peer_axes set")
	# Same peer re-registers a NO-ORG character: the stale org/axis MUST be cleared.
	_assert_true(bool(_register(st4, 40, "nobody", {}, 0)["ok"]), "peer 40 re-registers a no-org char")
	_assert_true(not st4["peer_orgs"].has(40), "no-org re-register CLEARS _peer_orgs (no stale faction)")
	_assert_true(not st4["peer_axes"].has(40), "no-org re-register CLEARS _peer_axes")
	# Re-registering back to an org char re-sets it.
	_assert_true(bool(_register(st4, 40, "boss", {}, 0)["ok"]), "peer 40 returns to the persisted org char")
	_assert_equal(String(st4["peer_orgs"].get(40, "")), "org_hutt_cartel", "persisted org re-sets _peer_orgs on return")

	# --- Rate-limit gates before auth/bind ---
	var st5: Dictionary = _fresh_state()
	(st5["budgets"] as Dictionary)[50] = {"tokens": 0.0, "last_ms": 0}  # drained bucket, no refill (now==last)
	var throttled: Dictionary = _register(st5, 50, "rey", {"secret": "x"}, 0)
	_assert_equal(String(throttled["reason"]), "rate_limited", "drained bucket -> rate_limited")
	_assert_true(not st5["peer_characters"].has(50), "rate-limited register never binds the peer")

	if _failures.is_empty():
		print("auth_flow_smoke: OK")
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
