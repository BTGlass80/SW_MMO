extends RefCounted
## Pure account-auth + RPC rate-limit helpers (E26; salted-hash-at-rest as of G8).
## Headlessly testable; the live NetworkManager calls these with a real clock
## (Time.get_ticks_msec) and the server-owned Crypto CSPRNG for salt. Closes the
## identity-spoofing gap via an account secret bound to the persisted record, and a
## token bucket so a peer can't flood reliable RPCs.
##
## G8 (crypto-at-rest): the account secret is NO LONGER stored in plaintext. On the
## first claim the server draws a random salt and stores SHA-256(salt+secret); on
## re-auth it recomputes the digest and compares. A legacy record still holding a
## plaintext `account_secret` verifies ONCE against the plaintext, then is upgraded
## in place to the salted hash — no new plaintext is ever written. Salt/hash live on
## the record as `secret_salt`/`secret_hash`; the legacy `account_secret` is read for
## migration only and erased on the first successful upgrade. Note: the ENet transport
## itself is still unencrypted (see the DEV-TRANSPORT banner in network_manager) — this
## slice hardens data at REST, not in flight; DTLS is a separate future slice.

const DEFAULT_RPC_RATE := 25.0   # reliable RPCs/sec sustained
const DEFAULT_RPC_BURST := 50.0  # bucket capacity (burst allowance)
const SALT_BYTES := 16           # 128-bit random salt per account

## Server-owned CSPRNG salt as a lowercase hex string. Uses Godot's Crypto (not a
## seedable RNG) — the salt is opaque and per-account; callers never assert its value.
static func generate_salt(num_bytes: int = SALT_BYTES) -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(num_bytes).hex_encode()

## Deterministic digest of SHA-256(salt + secret) as a lowercase hex string. Pure: given
## the same salt+secret it always returns the same value (so smokes can pin it with a
## fixed salt without any RNG).
static func hash_secret(salt: String, secret: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((salt + secret).to_utf8_buffer())
	return ctx.finish().hex_encode()

## Build the canonical salted-hash auth fields for a non-empty secret. The server owns the
## salt draw. Returns {secret_salt, secret_hash} — NEVER any plaintext.
static func make_auth_fields(secret: String) -> Dictionary:
	var salt := generate_salt()
	return {"secret_salt": salt, "secret_hash": hash_secret(salt, secret)}

## Ownership guard. `stored` is the record's auth state (any dict; the auth-relevant keys are
## `secret_salt`+`secret_hash` for a hashed account, or the legacy plaintext `account_secret`);
## `provided` is what the connecting client sent. Returns
##   {ok: bool, reason: String, changed: bool, fields: Dictionary}
## where on ok the caller persists via apply_auth(record, fields) IFF `changed` is true. `fields`
## is {} for an account that stays OPEN (first-claimer-wins), else {secret_salt, secret_hash}.
##
## Precedence:
##   1. Hashed record (secret_salt+secret_hash present): recompute + compare digests. No rewrite.
##   2. Legacy plaintext record (account_secret set, pre-G8): compare plaintext ONCE, and on match
##      upgrade in place to a salted hash (changed=true). A mismatch is rejected without upgrade.
##   3. Unsecured/unclaimed: claimed by the provided secret. A non-empty secret is stored as a
##      salted hash (changed=true); an empty secret leaves the account open (changed=false),
##      backward compatible with pre-E26 saves.
## A wrong secret against a secured (hashed or legacy) account is rejected `bad_secret` without
## touching the record. NO plaintext is ever returned or written.
static func verify(stored: Dictionary, provided: String) -> Dictionary:
	var salt := String(stored.get("secret_salt", ""))
	var digest := String(stored.get("secret_hash", ""))
	var legacy := String(stored.get("account_secret", ""))
	# 1. Already-hashed (secured) record.
	if salt != "" and digest != "":
		if hash_secret(salt, provided) == digest:
			return {"ok": true, "reason": "", "changed": false, "fields": {"secret_salt": salt, "secret_hash": digest}}
		return {"ok": false, "reason": "bad_secret", "changed": false, "fields": {}}
	# 2. Legacy plaintext record (pre-G8): compare once, then migrate to a salted hash.
	if legacy != "":
		if legacy == provided:
			return {"ok": true, "reason": "", "changed": true, "fields": make_auth_fields(provided)}
		return {"ok": false, "reason": "bad_secret", "changed": false, "fields": {}}
	# 3. Unsecured/unclaimed: first-claimer-wins.
	if provided == "":
		return {"ok": true, "reason": "", "changed": false, "fields": {}}  # stays open; nothing to persist
	return {"ok": true, "reason": "", "changed": true, "fields": make_auth_fields(provided)}

## Write the canonical auth state onto a record: strip the legacy plaintext field (it never
## survives a write) and set/clear the salted-hash fields. `fields` = {} clears all auth (an
## open, first-claimer account); else {secret_salt, secret_hash}. Mutates and returns `record`.
static func apply_auth(record: Dictionary, fields: Dictionary) -> Dictionary:
	record.erase("account_secret")  # legacy plaintext never survives a write (G8 migration)
	if fields.is_empty():
		record.erase("secret_salt")
		record.erase("secret_hash")
	else:
		record["secret_salt"] = String(fields.get("secret_salt", ""))
		record["secret_hash"] = String(fields.get("secret_hash", ""))
	return record

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
