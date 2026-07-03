extends SceneTree
## Headless smoke for the G8 salted-hash-at-rest account auth (pure account_auth_model). Covers:
##   - hash_secret determinism (fixed salt -> fixed digest; no RNG, so it is pinned exactly),
##   - salt draw shape/uniqueness (Crypto CSPRNG; asserted structurally, never by value),
##   - verify: fresh claim stores salt+hash (never plaintext), match/mismatch on a hashed record,
##   - the LEGACY plaintext -> salted-hash MIGRATION (verify once against plaintext, apply_auth
##     erases the plaintext + writes salt/hash, and the upgraded record verifies via the hash path),
##   - open-account first-claimer-wins backward compatibility.
## No RandomNumberGenerator / randomize() — digest assertions use fixed salts; salt draws are only
## checked for shape and inequality.

const Auth := preload("res://scripts/net/account_auth_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- hash_secret determinism (fixed salt, no RNG) ---
	var salt := "00112233445566778899aabbccddeeff"
	var d1 := Auth.hash_secret(salt, "swordfish")
	var d2 := Auth.hash_secret(salt, "swordfish")
	_assert_equal(d1, d2, "same salt+secret -> identical digest (deterministic)")
	_assert_true(d1.length() == 64, "SHA-256 digest is 64 hex chars")
	_assert_true(d1 != "swordfish", "digest is not the plaintext secret")
	_assert_true(Auth.hash_secret(salt, "other") != d1, "a different secret -> a different digest")
	_assert_true(Auth.hash_secret("ffffffff", "swordfish") != d1, "a different salt -> a different digest")

	# --- salt draw: hex, right length, unique across draws (structural only) ---
	var s1 := Auth.generate_salt()
	var s2 := Auth.generate_salt()
	_assert_true(s1.length() == Auth.SALT_BYTES * 2, "salt is SALT_BYTES*2 hex chars")
	_assert_true(s1 != s2, "two salt draws differ (CSPRNG)")
	_assert_true(_is_hex(s1), "salt is lowercase hex")

	# --- verify: fresh claim (unsecured -> salted hash, never plaintext) ---
	var claim := Auth.verify({}, "swordfish")
	_assert_true(bool(claim["ok"]) and bool(claim["changed"]), "fresh non-empty claim is accepted and flagged changed")
	var fields: Dictionary = claim["fields"]
	_assert_true(String(fields.get("secret_salt", "")) != "" and String(fields.get("secret_hash", "")) != "", "claim yields salt + hash")
	_assert_equal(Auth.hash_secret(String(fields["secret_salt"]), "swordfish"), String(fields["secret_hash"]), "stored hash == SHA-256(salt+secret)")

	# --- verify: match / mismatch on a hashed record ---
	var hashed := {"secret_salt": String(fields["secret_salt"]), "secret_hash": String(fields["secret_hash"])}
	var good := Auth.verify(hashed, "swordfish")
	_assert_true(bool(good["ok"]) and not bool(good["changed"]), "right secret verifies without a rewrite")
	var wrong := Auth.verify(hashed, "guess")
	_assert_true(not bool(wrong["ok"]) and String(wrong["reason"]) == "bad_secret", "wrong secret -> bad_secret")
	var empty := Auth.verify(hashed, "")
	_assert_true(not bool(empty["ok"]), "a secured (hashed) account rejects an empty secret")

	# --- open account: first-claimer-wins backward compatibility ---
	var open_claim := Auth.verify({}, "")
	_assert_true(bool(open_claim["ok"]) and not bool(open_claim["changed"]) and (open_claim["fields"] as Dictionary).is_empty(), "empty secret on an unsecured account stays open (no write)")

	# --- LEGACY plaintext -> salted-hash MIGRATION ---
	var legacy := {"character_id": "vault", "account_secret": "key"}  # a pre-G8 record on disk
	# wrong plaintext is rejected without touching the record
	var legacy_bad := Auth.verify(legacy, "nope")
	_assert_true(not bool(legacy_bad["ok"]) and String(legacy_bad["reason"]) == "bad_secret", "legacy wrong plaintext -> bad_secret")
	_assert_true(legacy.has("account_secret"), "a rejected legacy verify does not mutate the record")
	# right plaintext verifies ONCE and instructs a migration
	var legacy_ok := Auth.verify(legacy, "key")
	_assert_true(bool(legacy_ok["ok"]) and bool(legacy_ok["changed"]), "legacy right plaintext verifies once and flags changed")
	# apply_auth performs the in-place upgrade: strip plaintext, write salt+hash
	Auth.apply_auth(legacy, legacy_ok["fields"])
	_assert_true(not legacy.has("account_secret"), "migration ERASES the plaintext account_secret")
	_assert_true(String(legacy.get("secret_salt", "")) != "" and String(legacy.get("secret_hash", "")) != "", "migration writes salt + hash")
	# the upgraded record now verifies via the HASH path (no plaintext left), and rejects a wrong secret
	var post := Auth.verify(legacy, "key")
	_assert_true(bool(post["ok"]) and not bool(post["changed"]), "upgraded record verifies via the hash path (no rewrite)")
	_assert_true(not bool(Auth.verify(legacy, "key2")["ok"]), "upgraded record rejects a wrong secret")

	# --- apply_auth({}) clears an account back to open (and strips any legacy plaintext) ---
	var cleared := {"account_secret": "old", "secret_salt": "aa", "secret_hash": "bb"}
	Auth.apply_auth(cleared, {})
	_assert_true(not cleared.has("account_secret") and not cleared.has("secret_salt") and not cleared.has("secret_hash"), "apply_auth({}) clears all auth fields (open account)")

	if _failures.is_empty():
		print("auth_hash_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _is_hex(s: String) -> bool:
	for i in s.length():
		var c := s[i]
		if not ((c >= "0" and c <= "9") or (c >= "a" and c <= "f")):
			return false
	return true

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
