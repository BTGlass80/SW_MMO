extends RefCounted
## Pure PvP-CONSENT model (Wave F / DIV-0022). The ADDITIVE opt-in consent layer that sits ON TOP of
## the shipped zone-based open-PvP gate (`pvp_rules_model.can_fire`, DIV-0019). It answers the single
## deterministic question "may attacker A fire on target B right now, and is the hit lethal?" as
## `{allowed, reason, lethal}` by composing three layers with a fixed precedence (design
## docs/PVP_CONSENT_DESIGN.md §1.2):
##   1. zone-based OPEN PvP  — DELEGATED to `pvp_rules_model.can_fire` (lawless-only); NEVER re-implemented
##      here, so consent can only ADD permission in protected zones, never REMOVE the zone protection.
##   2. opt-in DUELS         — a challenge->accept handshake makes exactly two players mutually
##      attackable in ANY zone (even secured), default NON-lethal.
##   3. bounty-as-CONSENT    — a credit-funded bounty makes a target lawfully attackable by an eligible
##      hunter in contested+lawless (not secured), lethal, collected on death.
## Plus a symmetric one-way NEWBIE-protection guard. This file also owns the in-memory consent STATE
## (pending/active duels + active bounties) and its accept/decline/expire/yield/abort/collect transitions,
## and the pre-resolvers (`duel_active`, `bounty_eligible`) that turn that state into the ctx booleans
## `resolve()` reads. PURE + DETERMINISTIC: NO nodes, sockets, or RNG (PvP eligibility is a function of
## already-resolved state, exactly like security_gate.gd). Transitions are NON-MUTATING (return a new
## state), matching the quest_model / territory_model style. The HOT netcode wiring (RPCs, arena clamp,
## wallet escrow, death collection hook) is a later slice; this is the headlessly-testable truth.

const ZoneGate := preload("res://scripts/rules/pvp_rules_model.gd")   # DIV-0019 zone gate — composed, not edited

# --- Duel tunables (docs §4) ---
const OFFER_TTL := 60.0            # an unaccepted challenge auto-declines after this many seconds
const DUEL_MAX_DURATION := 600.0  # optional hard cap on an active duel (10 min); 0 arg = uncapped
const DUEL_YIELD_SEVERITY := 3     # KO ceiling: first to 'incapacitated' loses (distinct from DIV-0016 cap of 2)

# --- Bounty tunables (docs §5) ---
const MIN_BOUNTY := 250            # real-stake floor
const POSTING_FEE_PCT := 0.10      # non-refundable sink skimmed on placement
const POSTING_FEE_MIN := 25
const BOUNTY_TTL := 604800.0       # 7 days from the last placement
const BOUNTY_MAX := 25000          # pot cap so one kill can't pay an economy-breaking sum
const PAYOFF_MULTIPLIER := 1.5     # target buys out their own bounty at pot x this (a sink)
const BOUNTY_PLACE_COOLDOWN := 300.0
const DEFAULT_BOUNTY_TIERS := ["contested", "lawless"]   # NOT secured — the civic/newbie core stays sanctuary

# =====================================================================================================
# SECTION A — the pure arbiter: resolve(attacker, target, ctx) -> {allowed, reason, lethal}
# =====================================================================================================

# Result shape is EXACTLY {allowed:bool, reason:String, lethal:bool} (owner spec, docs §1.1).
# reason enum:
#   "pve_target" | "self" | "not_colocated"  -> hard denies / wrong caller
#   "siege"                                   -> allow via siege no-consent scope (off-by-default hook)
#   "duel"                                    -> allow via active mutual duel (lethal = the duel's opt-in)
#   "newbie_protected"                        -> deny, a party is under protection
#   "bounty"                                  -> allow via bounty-as-consent (lethal)
#   "lawless_open"                            -> allow via zone open-PvP (lethal)
#   "protected_zone"                          -> deny, secured/contested, no consent path
#
# ctx (server pre-resolves every key; all optional with safe defaults):
#   { zone_tier:String, duel_active:bool, duel_lethal:bool, bounty_eligible:bool, siege_forced:bool }
# attacker/target: { id, is_player, node_id, newbie_protected }
static func resolve(attacker: Dictionary, target: Dictionary, ctx: Dictionary) -> Dictionary:
	# 1. wrong caller: a non-player target belongs to the PvE lethal gate (DIV-0017), not here.
	if not bool(target.get("is_player", true)):
		return _deny("pve_target")
	# 2. no self-fire.
	if attacker.get("id") == target.get("id"):
		return _deny("self")
	# 3. must share the same node/zone (empty node == no shared node).
	var a_node := String(attacker.get("node_id", ""))
	var b_node := String(target.get("node_id", ""))
	if a_node == "" or b_node == "" or a_node != b_node:
		return _deny("not_colocated")
	# 4. siege forces a war window that outranks everything (owner-gated hook; off by default here).
	if bool(ctx.get("siege_forced", false)):
		return _allow("siege", true)
	# 5. an ACTIVE mutual duel overrides BOTH the zone default AND the newbie guard (two-sided consent).
	if bool(ctx.get("duel_active", false)):
		return _allow("duel", bool(ctx.get("duel_lethal", false)))
	# 6. newbie protection blocks ALL non-consensual paths below (symmetric: neither attack nor be attacked).
	if bool(attacker.get("newbie_protected", false)) or bool(target.get("newbie_protected", false)):
		return _deny("newbie_protected")
	# 7. bounty-as-consent: tagged BEFORE generic lawless-open so a hunter's kill credits the contract.
	if bool(ctx.get("bounty_eligible", false)):
		return _allow("bounty", true)
	# 8. zone open PvP — DELEGATE to the shipped DIV-0019 gate (lawless-only). Same tier both sides because
	#    co-location is already guaranteed; this keeps the "where is open PvP" truth in ONE place.
	var tier := String(ctx.get("zone_tier", ""))
	if _zone_open(a_node, b_node, tier):
		return _allow("lawless_open", true)
	# 9. secured/contested with no consent path.
	return _deny("protected_zone")

# Convenience: assemble ctx from the live consent STATE + zone info, then resolve. This is the single
# entry the HOT layer / smoke calls; SECTION A stays a pure arbiter over pre-resolved flags.
static func may_fire(state: Dictionary, attacker: Dictionary, target: Dictionary,
		zone_tier: String, siege_forced: bool = false) -> Dictionary:
	return resolve(attacker, target, build_ctx(state, attacker, target, zone_tier, siege_forced))

# Turn the consent state into the ctx booleans resolve() reads.
static func build_ctx(state: Dictionary, attacker: Dictionary, target: Dictionary,
		zone_tier: String, siege_forced: bool = false) -> Dictionary:
	var a_id: Variant = attacker.get("id")
	var b_id: Variant = target.get("id")
	return {
		"zone_tier": zone_tier,
		"duel_active": duel_active(state, a_id, b_id),
		"duel_lethal": duel_lethal(state, a_id, b_id),
		"bounty_eligible": bounty_eligible(state, a_id, b_id, zone_tier),
		"siege_forced": siege_forced,
	}

# Whether the delegated zone gate (DIV-0019) opens PvP for this pair/tier. `open_tiers` is passable for a
# server that ever re-tunes OPEN_PVP_TIERS (default = pvp_rules_model.OPEN_PVP_TIERS).
static func _zone_open(a_node: String, b_node: String, tier: String,
		open_tiers: Array = ZoneGate.OPEN_PVP_TIERS) -> bool:
	return bool(ZoneGate.can_fire(a_node, b_node, tier, tier, open_tiers).get("allowed", false))

static func _allow(reason: String, lethal: bool) -> Dictionary:
	return {"allowed": true, "reason": reason, "lethal": lethal}

static func _deny(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason, "lethal": false}

# =====================================================================================================
# SECTION B — consent STATE container
# =====================================================================================================

static func new_state() -> Dictionary:
	return {"duels": {}, "bounties": {}}

# Canonical unordered key for a pair (type-agnostic: peer ints or character strings).
static func pair_key(a: Variant, b: Variant) -> String:
	var sa := str(a)
	var sb := str(b)
	if sa <= sb:
		return sa + "|" + sb
	return sb + "|" + sa

# =====================================================================================================
# SECTION C — Layer 2: opt-in duels (offer -> accept -> active -> ended). In-memory, non-persisted.
# =====================================================================================================

# challenge(A -> B): requires co-location (caller checks zone) + A!=B + neither already in an ACTIVE duel
# and no live (offered/active) record for this pair. Creates OFFERED. Returns {ok, state, reason}.
static func challenge(state: Dictionary, a: Variant, b: Variant, zone_id: String, now: float,
		lethal: bool = false, offer_ttl: float = OFFER_TTL) -> Dictionary:
	if a == b:
		return {"ok": false, "state": state, "reason": "self"}
	var duels: Dictionary = state.get("duels", {})
	var key := pair_key(a, b)
	var existing: Dictionary = duels.get(key, {})
	if not existing.is_empty() and String(existing.get("state", "ended")) != "ended":
		return {"ok": false, "state": state, "reason": "duplicate"}
	if _in_active_duel(state, a) != "" or _in_active_duel(state, b) != "":
		return {"ok": false, "state": state, "reason": "already_dueling"}
	var next := state.duplicate(true)
	(next["duels"] as Dictionary)[key] = {
		"a": a, "b": b, "state": "offered", "lethal": lethal, "zone_id": zone_id,
		"offered_at": now, "offer_ttl": now + offer_ttl,
		"started_at": 0.0, "max_duration": 0.0, "result": null,
	}
	return {"ok": true, "state": next, "reason": ""}

# accept(B): OFFERED -> ACTIVE; both flagged mutually attackable. Returns {ok, state, reason}.
# Guards the SAME one-active-duel-per-player invariant challenge() enforces at offer time: a player
# may hold several simultaneous OFFERED challenges (e.g. two different challengers), but accepting a
# second one while already in an ACTIVE duel is rejected (bug found in hardening review — without this
# guard two different challengers could each have their offer to the same player accepted, leaving that
# player "active" in two duels at once).
static func accept(state: Dictionary, a: Variant, b: Variant, now: float,
		max_duration: float = DUEL_MAX_DURATION) -> Dictionary:
	var key := pair_key(a, b)
	var rec: Dictionary = (state.get("duels", {}) as Dictionary).get(key, {})
	if rec.is_empty() or String(rec.get("state", "")) != "offered":
		return {"ok": false, "state": state, "reason": "no_offer"}
	if _in_active_duel(state, a) != "" or _in_active_duel(state, b) != "":
		return {"ok": false, "state": state, "reason": "already_dueling"}
	var next := state.duplicate(true)
	var r: Dictionary = (next["duels"] as Dictionary)[key]
	r["state"] = "active"
	r["started_at"] = now
	r["max_duration"] = (now + max_duration) if max_duration > 0.0 else 0.0
	return {"ok": true, "state": next, "reason": ""}

# decline(B): OFFERED -> ENDED(decline). No flags set.
static func decline(state: Dictionary, a: Variant, b: Variant) -> Dictionary:
	return _end_pair(state, pair_key(a, b), null, "decline", ["offered"])

# yield_duel(who): the yielding party's ACTIVE duel ends; the opponent is recorded winner.
static func yield_duel(state: Dictionary, who: Variant) -> Dictionary:
	var key := _in_active_duel(state, who)
	if key == "":
		return {"ok": false, "state": state, "reason": "no_active_duel"}
	var rec: Dictionary = (state["duels"] as Dictionary)[key]
	var winner: Variant = rec["b"] if rec["a"] == who else rec["a"]
	return _end_pair(state, key, winner, "yield", ["active"])

# conclude_ko(loser): loser reached DUEL_YIELD_SEVERITY -> ACTIVE ends, standing party wins.
static func conclude_ko(state: Dictionary, loser: Variant) -> Dictionary:
	var key := _in_active_duel(state, loser)
	if key == "":
		return {"ok": false, "state": state, "reason": "no_active_duel"}
	var rec: Dictionary = (state["duels"] as Dictionary)[key]
	var winner: Variant = rec["b"] if rec["a"] == loser else rec["a"]
	return _end_pair(state, key, winner, "ko", ["active"])

# abort(who): a participant leaves the zone / disconnects -> their OFFERED-or-ACTIVE duel ends, no winner.
static func abort(state: Dictionary, who: Variant) -> Dictionary:
	var duels: Dictionary = state.get("duels", {})
	for key in duels:
		var rec: Dictionary = duels[key]
		var st := String(rec.get("state", "ended"))
		if (st == "active" or st == "offered") and (rec.get("a") == who or rec.get("b") == who):
			return _end_pair(state, key, null, "abort", ["active", "offered"])
	return {"ok": false, "state": state, "reason": "no_duel"}

# expire(now): sweep (slow tick) — OFFERED past its TTL and ACTIVE past its max_duration both -> ENDED(expire).
static func expire(state: Dictionary, now: float) -> Dictionary:
	var next := state.duplicate(true)
	var changed := false
	var duels: Dictionary = next["duels"]
	for key in duels:
		var rec: Dictionary = duels[key]
		var st := String(rec.get("state", "ended"))
		if st == "offered" and now >= float(rec.get("offer_ttl", 0.0)):
			rec["state"] = "ended"
			rec["result"] = {"winner": null, "outcome": "expire"}
			changed = true
		elif st == "active" and float(rec.get("max_duration", 0.0)) > 0.0 and now >= float(rec["max_duration"]):
			rec["state"] = "ended"
			rec["result"] = {"winner": null, "outcome": "expire"}  # timed draw
			changed = true
	return {"ok": changed, "state": next, "reason": ""}

# --- duel predicates (read-only, O(1)/O(n) — cheap enough per fire-intent) ---
static func duel_active(state: Dictionary, a: Variant, b: Variant) -> bool:
	var rec: Dictionary = (state.get("duels", {}) as Dictionary).get(pair_key(a, b), {})
	return String(rec.get("state", "")) == "active"

static func duel_lethal(state: Dictionary, a: Variant, b: Variant) -> bool:
	var rec: Dictionary = (state.get("duels", {}) as Dictionary).get(pair_key(a, b), {})
	return String(rec.get("state", "")) == "active" and bool(rec.get("lethal", false))

# Returns the pair_key of an ACTIVE duel involving `who`, or "" if none.
static func _in_active_duel(state: Dictionary, who: Variant) -> String:
	var duels: Dictionary = state.get("duels", {})
	for key in duels:
		var rec: Dictionary = duels[key]
		if String(rec.get("state", "")) == "active" and (rec.get("a") == who or rec.get("b") == who):
			return key
	return ""

# Mark a duel record ENDED with an outcome/winner, but only from one of `from_states`.
static func _end_pair(state: Dictionary, key: String, winner: Variant, outcome: String,
		from_states: Array) -> Dictionary:
	var rec: Dictionary = (state.get("duels", {}) as Dictionary).get(key, {})
	if rec.is_empty() or not from_states.has(String(rec.get("state", ""))):
		return {"ok": false, "state": state, "reason": "no_such_duel"}
	var next := state.duplicate(true)
	var r: Dictionary = (next["duels"] as Dictionary)[key]
	r["state"] = "ended"
	r["result"] = {"winner": winner, "outcome": outcome}
	return {"ok": true, "state": next, "reason": ""}

# =====================================================================================================
# SECTION D — Layer 3: bounty-as-consent (persisted world contract). One accumulating record per target.
# =====================================================================================================

static func posting_fee_for(amount: int) -> int:
	return maxi(POSTING_FEE_MIN, int(round(float(amount) * POSTING_FEE_PCT)))

# place_bounty: no self-bounty, amount >= MIN_BOUNTY; escrow ACCUMULATES into the per-target pot (capped),
# TTL extends to now+BOUNTY_TTL. The actual wallet debit is the HOT layer's job (economy_model / DIV-0018);
# this pure model only tracks pot/contributors/fee. Returns {ok, state, reason, posting_fee, pot}.
static func place_bounty(state: Dictionary, placer_id: Variant, target_id: Variant, amount: int,
		now: float, min_tiers: Array = DEFAULT_BOUNTY_TIERS, hunters_guild_only: bool = false) -> Dictionary:
	if placer_id == target_id:
		return {"ok": false, "state": state, "reason": "self_bounty", "posting_fee": 0, "pot": 0}
	if amount < MIN_BOUNTY:
		return {"ok": false, "state": state, "reason": "below_minimum", "posting_fee": 0, "pot": 0}
	var next := state.duplicate(true)
	var bounties: Dictionary = next["bounties"]
	var key := str(target_id)
	var fee := posting_fee_for(amount)
	var rec: Dictionary = bounties.get(key, {})
	if rec.is_empty():
		rec = {
			"target_id": target_id, "pot_credits": 0, "contributors": [],
			"min_tiers": min_tiers.duplicate(), "hunters_guild_only": hunters_guild_only,
			"expires_at": now + BOUNTY_TTL, "posting_fee_paid": 0,
		}
	var net_add := mini(amount, BOUNTY_MAX - int(rec.get("pot_credits", 0)))   # respect the pot cap
	net_add = maxi(net_add, 0)
	rec["pot_credits"] = int(rec.get("pot_credits", 0)) + net_add
	(rec["contributors"] as Array).append({"placer_id": placer_id, "amount": net_add, "placed_at": now})
	rec["expires_at"] = now + BOUNTY_TTL   # a fresh placement extends the hunt
	rec["posting_fee_paid"] = int(rec.get("posting_fee_paid", 0)) + fee
	bounties[key] = rec
	return {"ok": true, "state": next, "reason": "", "posting_fee": fee, "pot": int(rec["pot_credits"])}

# Server pre-resolver (docs §5.3): target has an active record AND zone_tier in its min_tiers AND the
# attacker is neither the target nor a contributor/placer. (Guild gate is enforced by the HOT layer, which
# knows org membership; the pure model exposes hunters_guild_only on the record for it.)
static func bounty_eligible(state: Dictionary, attacker_id: Variant, target_id: Variant, zone_tier: String) -> bool:
	if attacker_id == target_id:
		return false
	var rec: Dictionary = (state.get("bounties", {}) as Dictionary).get(str(target_id), {})
	if rec.is_empty():
		return false
	if not (rec.get("min_tiers", DEFAULT_BOUNTY_TIERS) as Array).has(zone_tier):
		return false
	for c in rec.get("contributors", []):
		if (c as Dictionary).get("placer_id") == attacker_id:
			return false   # no placer/contributor self-collection funnel
	return true

static func has_bounty(state: Dictionary, target_id: Variant) -> bool:
	return not (state.get("bounties", {}) as Dictionary).get(str(target_id), {}).is_empty()

static func bounty_pot(state: Dictionary, target_id: Variant) -> int:
	return int((state.get("bounties", {}) as Dictionary).get(str(target_id), {}).get("pot_credits", 0))

# Collect on the target's death via the `bounty` path. Guards: collector is not the target and not a
# contributor/placer. Removes the record; returns the pot to credit to the collector (HOT wallet layer).
static func collect_bounty(state: Dictionary, target_id: Variant, collector_id: Variant) -> Dictionary:
	var key := str(target_id)
	var rec: Dictionary = (state.get("bounties", {}) as Dictionary).get(key, {})
	if rec.is_empty():
		return {"ok": false, "state": state, "reason": "no_bounty", "payout": 0}
	if collector_id == target_id:
		return {"ok": false, "state": state, "reason": "self_collect", "payout": 0}
	for c in rec.get("contributors", []):
		if (c as Dictionary).get("placer_id") == collector_id:
			return {"ok": false, "state": state, "reason": "placer_collect", "payout": 0}
	var next := state.duplicate(true)
	(next["bounties"] as Dictionary).erase(key)
	return {"ok": true, "state": next, "reason": "", "payout": int(rec.get("pot_credits", 0))}

# pay_off: the target settles their own bounty at pot x PAYOFF_MULTIPLIER (a sink). Escrow refunds to
# contributors pro-rata; record removed. Returns {ok, state, cost, refunds:{placer_id -> amount}}.
static func pay_off_bounty(state: Dictionary, target_id: Variant) -> Dictionary:
	var key := str(target_id)
	var rec: Dictionary = (state.get("bounties", {}) as Dictionary).get(key, {})
	if rec.is_empty():
		return {"ok": false, "state": state, "reason": "no_bounty", "cost": 0, "refunds": {}}
	var next := state.duplicate(true)
	(next["bounties"] as Dictionary).erase(key)
	var cost := int(ceil(float(rec.get("pot_credits", 0)) * PAYOFF_MULTIPLIER))
	return {"ok": true, "state": next, "reason": "", "cost": cost, "refunds": _contributor_refunds(rec)}

# expire_bounties(now): slow-tick sweep — records past their TTL are removed and escrow refunded pro-rata
# (minus the non-refundable posting fee, already taken). Returns {ok, state, refunds:{placer_id -> amount}}.
static func expire_bounties(state: Dictionary, now: float) -> Dictionary:
	var next := state.duplicate(true)
	var bounties: Dictionary = next["bounties"]
	var all_refunds := {}
	var changed := false
	for key in bounties.keys():
		var rec: Dictionary = bounties[key]
		if now >= float(rec.get("expires_at", 0.0)):
			var refunds := _contributor_refunds(rec)
			for placer_id in refunds:
				all_refunds[placer_id] = int(all_refunds.get(placer_id, 0)) + int(refunds[placer_id])
			bounties.erase(key)
			changed = true
	return {"ok": changed, "state": next, "refunds": all_refunds}

# Sum each contributor's escrow (the pot IS the sum of contributions; posting fee was a separate sink).
static func _contributor_refunds(rec: Dictionary) -> Dictionary:
	var out := {}
	for c in rec.get("contributors", []):
		var pid: Variant = (c as Dictionary).get("placer_id")
		out[pid] = int(out.get(pid, 0)) + int((c as Dictionary).get("amount", 0))
	return out
