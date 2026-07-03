extends RefCounted
## Pure WEG-anchored credit economy (Wave F / DIV-0018). Owner decision 2026-07-01:
## "modest sink, WEG-anchored prices". Each catalog `cost` IS the WEG R&E list price and the
## BUY anchor (BUY_MARKUP=1.0); the churn sink is the 40% sell/buy-back spread. Buy price layers
## the Director event multiplier + Bargain (via a PASSED vendor_model instance) + a small rep
## discount, clamped by buy_floor() so a fully-discounted BUY always costs strictly MORE than the
## SELL buy-back returns (no buy->sell arbitrage, Wave G / G5). Loot credits drop from a
## disabled HOSTILE creature only (the training dummy stays CP-only). All-static, NO RNG of its
## own — the loot roller takes an explicit server-owned seed. All SPEND numbers are tunable consts.

# --- tunable economy constants ---
const STARTING_CREDITS := 1000       # chargen wallet (~2 sidearms or 1 heavy + vest of headroom)
const BUY_MARKUP := 1.0              # WEG list = street price; the sink is the sell spread, not markup
const SELL_RATE := 0.40             # vendor buy-back pays 40% of list (the 60% spread is the churn sink)
# Stacked bargain+rep+event can only take a BUY down to (1-MAX_TOTAL_DISCOUNT) of list = 0.45 here.
# ANTI-ARBITRAGE INVARIANT (Wave G / G5): (1.0 - MAX_TOTAL_DISCOUNT) MUST stay > SELL_RATE so the
# cheapest a buy can ever cost stays above what selling it straight back pays; otherwise a
# fully-discounted buy -> immediate sell would PRINT credits. buy_floor() is the single source of
# truth for that clamp and ALSO hard-floors at sell_price+1, so even re-widening THIS dial toward
# 0.65 again can never reopen the exploit.
const MAX_TOTAL_DISCOUNT := 0.55
const REP_DISCOUNT := {"friendly": 0.05, "allied": 0.10}  # by reputation_model.standing_tier; else 0.0
# loot on a disabled hostile creature (credits/salvage only in v1; item drops are owner-gated follow-up)
# ONE loot axis (Wave G / G15, DIV-0028): a SINGLE base credit band that applies to EVERY hostile head
# regardless of scale, then a pure threat_tier multiplier. character-scale (tuskens / thugs / enforcers)
# no longer gets a richer base band — that was the double-dip (higher base band AND, being t3, a fat
# multiplier) the G15 balance re-probe flagged as the best-income exploit in the game. Risk now rides on
# ONE dial: threat_tier. Salvage stays tier-independent (the raw carcass, not the kill's danger).
const LOOT_BASE := [15, 45]         # per-head base credit band for EVERY hostile creature (scale-independent)
const SALVAGE_CHANCE := 0.25        # chance a disabled hostile also yields a salvage bundle
const SALVAGE_BUNDLE := [20, 60]    # salvage-credit band (tier-independent — the raw carcass, not the kill's danger)

# --- threat-tier -> credit reward multiplier (Wave G / G15, DIV-0028: risk correlates with reward) ----
# The SINGLE loot axis. Base band x this multiplier is the whole credit reward, so a riskier (higher-tier)
# kill is worth more. The curve is tuned against tools/balance_probe.gd, NOT vibes: higher-tier creatures
# take proportionally MORE windows-per-kill (green anchors: hitcher_crab t2 ~2.5 wpk, tusken t3 ~5.3,
# acklay t4 ~12.5), AND the flat tier-independent salvage bundle inflates fast-kill low-tier cr/min, so the
# multiplier has to grow FASTER than the windows-per-kill curve to keep cr/min monotone non-decreasing
# across ambient tiers t1->t4. Measured per-DATA-tier MEAN cr/min at these mults (base band mean 30, green
# probe): t2 ~185, t3 ~252, t4 ~416 — monotone; the crab/tusken/acklay anchors are ~196 / ~225 / ~240,
# also monotone. There is no HOSTILE tier-1 creature in the catalog (every hostile probes >=0.5% out/window
# = t2+), so the t1 mult is the never-used floor and equals the t2 entry mult. tier 5 = BOSS/event content
# (merdeth / krayt_dragon / rancor): never ambient, so it is OUTSIDE the monotone-cr/min requirement (bosses
# are so tanky their cr/min is tiny); its credit mult is a premium but a boss's real reward is its harvest
# good (pearl/shell), not credit farming.
const DEFAULT_LOOT_TIER := 2        # tier when a spawn omits threat_tier (== creature_spawn_model.DEFAULT_THREAT_TIER)
const MIN_LOOT_TIER := 1
const MAX_LOOT_TIER := 5            # tier 5 = boss/event channel (mirrors creature_spawn_model.BOSS_THREAT_TIER)
const LOOT_TIER_MULT := {1: 1.0, 2: 1.0, 3: 3.0, 4: 8.0, 5: 10.0}

# --- OPTIONAL per-creature wpk-variance correction dial (Wave G / G16, DIV-0028) ------------------
# The threat_tier multiplier is FLAT across a tier, but within one tier kill-speed (windows-per-kill)
# can vary ~8x: a glass-cannon (deadly enough to earn its tier, but dies in ~3-4 windows) farms many
# more kills/minute than a bruiser of the SAME tier that soaks ~12-28 windows, so at a flat tier mult
# the fast one's cr/min blows out (svaper measured ~824 cr/min vs its t4 mate voroos ~105 — a ~8x
# within-tier spread the G15 re-probe flagged as the new farming meta). `loot_mult` is a per-creature
# scalar (default 1.0) that corrects ONLY for that wpk variance: <1 trims a fast-killer's per-kill
# credits back toward the tier norm, >1 lifts a genuine bruiser whose slow kill starves its cr/min.
# It is NOT a new axis (no scale, no zone, no rarity) — it rides INSIDE the single tier axis as a pure
# post-multiply, so risk still rides on threat_tier; this dial only flattens the kill-speed accident.
# Applied to at-shipping only the handful of t4 creatures whose measured wpk deviates far from the tier
# reference (~12.5 wpk): svaper/raen_sovra/arqet/stalker_lizard (fast, <1) and voroos (bruiser, >1).
const DEFAULT_LOOT_MULT := 1.0
const MIN_LOOT_MULT := 0.1          # sane clamp so a data typo can never zero out or invert a reward
const MAX_LOOT_MULT := 10.0

# Rep-tier -> buy discount (0.0 for hostile/neutral). Keyed on reputation_model.standing_tier().
static func discount_for_tier(tier: String) -> float:
	return float(REP_DISCOUNT.get(tier, 0.0))

# Final buy price. Delegates the Director multiplier + Bargain to the passed vendor INSTANCE
# (vendor_model.quote), then applies BUY_MARKUP + the rep discount, clamped UP to buy_floor()
# (the single source of truth for the minimum a buy can ever cost).
static func buy_price(list_cost: int, director_multiplier: float, bargain_dice: int, bargain_pips: int, rep_tier: String, vendor: Object) -> int:
	if list_cost <= 0:
		return 0  # contraband / faction-issued (cost 0) is not vendor-priced
	var quoted := int(vendor.quote(list_cost, director_multiplier, bargain_dice, bargain_pips))
	var price := int(round(float(quoted) * BUY_MARKUP * (1.0 - discount_for_tier(rep_tier))))
	return maxi(price, buy_floor(list_cost))

# buy_floor(list_cost) -> the minimum credits a BUY can EVER cost (the clamped floor). This is the
# SINGLE SOURCE OF TRUTH used by buy_price's clamp so the floor and the price path can't drift.
# It is the LARGER of:
#   * the stacked-discount floor  ceil((1 - MAX_TOTAL_DISCOUNT) * list) = 0.45 of list, and
#   * sell_price(list) + 1        -- the HARD anti-arbitrage guarantee.
# The +1 clamp makes buy_floor(list) > sell_price(list) for EVERY list >= 1 (including tiny costs
# where integer rounding would otherwise let the two tie), so a fully-discounted buy followed by an
# immediate sell can never net a profit. The guarantee holds even if MAX_TOTAL_DISCOUNT is later
# re-widened (Wave G / G5); economy_floor_smoke.gd pins it across the whole vendor catalog.
static func buy_floor(list_cost: int) -> int:
	if list_cost <= 0:
		return 0  # unpriced (contraband / faction-issued, cost 0); mirrors buy_price/sell_price
	var pct_floor := int(ceil(float(list_cost) * (1.0 - MAX_TOTAL_DISCOUNT)))
	return maxi(pct_floor, sell_price(list_cost) + 1)

# Vendor buy-back: pays SELL_RATE of the item's list cost, floored at 1.
static func sell_price(list_cost: int) -> int:
	if list_cost <= 0:
		return 0
	return maxi(int(round(float(list_cost) * SELL_RATE)), 1)

# --- the owned-item set (inventory when present, else the currently-equipped items) ---
static func _owned_list(sheet: Dictionary) -> Array:
	var inv: Variant = sheet.get("inventory", null)
	if inv is Array:
		return (inv as Array).duplicate()
	var out: Array = []
	for v in (sheet.get("equipment", {}) as Dictionary).values():
		if String(v) != "":
			out.append(String(v))
	return out

static func _is_equipped(sheet: Dictionary, item_key: String) -> bool:
	for v in (sheet.get("equipment", {}) as Dictionary).values():
		if String(v) == item_key:
			return true
	return false

# {ok, reason} — reasons: unknown_item / not_stocked / cannot_afford
static func can_buy(sheet: Dictionary, item_key: String, price: int, catalog: Dictionary) -> Dictionary:
	if not catalog.has(item_key):
		return {"ok": false, "reason": "unknown_item"}
	if not bool((catalog[item_key] as Dictionary).get("vendor_stocked", false)):
		return {"ok": false, "reason": "not_stocked"}
	if int(sheet.get("credits", 0)) < price:
		return {"ok": false, "reason": "cannot_afford"}
	return {"ok": true, "reason": ""}

# {ok, reason, sheet} — NON-mutating; on ok returns a new sheet with credits-=price and item_key
# appended to inventory (dupes allowed = stackable ownership).
static func buy(sheet: Dictionary, item_key: String, price: int, catalog: Dictionary) -> Dictionary:
	var check := can_buy(sheet, item_key, price, catalog)
	if not bool(check["ok"]):
		return {"ok": false, "reason": String(check["reason"]), "sheet": sheet}
	var next := sheet.duplicate(true)
	next["credits"] = int(next.get("credits", 0)) - price
	var inv := _owned_list(next)  # materializes from equipped if there was no inventory (keeps ownership)
	inv.append(item_key)
	next["inventory"] = inv
	return {"ok": true, "reason": "", "sheet": next}

# {ok, reason} — reasons: not_owned / equipped (cannot sell a currently-equipped item)
static func can_sell(sheet: Dictionary, item_key: String) -> Dictionary:
	if not _owned_list(sheet).has(item_key):
		return {"ok": false, "reason": "not_owned"}
	if _is_equipped(sheet, item_key):
		return {"ok": false, "reason": "equipped"}
	return {"ok": true, "reason": ""}

# {ok, reason, sheet} — NON-mutating; on ok credits+=price and the FIRST matching inventory entry removed.
static func sell(sheet: Dictionary, item_key: String, price: int) -> Dictionary:
	var check := can_sell(sheet, item_key)
	if not bool(check["ok"]):
		return {"ok": false, "reason": String(check["reason"]), "sheet": sheet}
	var next := sheet.duplicate(true)
	next["credits"] = int(next.get("credits", 0)) + price
	var inv := _owned_list(next)
	var idx := inv.find(item_key)
	if idx >= 0:
		inv.remove_at(idx)
	next["inventory"] = inv
	return {"ok": true, "reason": "", "sheet": next}

# Grant owned items into the sheet's inventory (materializing from equipped if there was none), dupes
# allowed = stackable ownership — the same append shape as buy(). NON-mutating: returns a new sheet.
# Used by the DIV-0025 corpse-loot transfer (a third party receives a lawless corpse's dropped set) and
# any future item grant. Credits are handled separately (DIV-0006: credits are NEVER on a corpse).
static func grant_items(sheet: Dictionary, items: Array) -> Dictionary:
	if items.is_empty():
		return sheet
	var next := sheet.duplicate(true)
	var inv := _owned_list(next)
	for it in items:
		inv.append(String(it))
	next["inventory"] = inv
	return next

# threat_tier (1..5) -> credit-reward multiplier. Out-of-range clamps to [MIN,MAX]_LOOT_TIER; an
# unknown key falls back to ×1. Static/pure so tests and the balance probe can read it directly.
static func loot_tier_multiplier(threat_tier: int) -> float:
	var t := clampi(threat_tier, MIN_LOOT_TIER, MAX_LOOT_TIER)
	return float(LOOT_TIER_MULT.get(t, 1.0))

# Per-creature wpk-variance correction scalar (DIV-0028). Defaults to 1.0 when absent and is clamped
# to [MIN,MAX]_LOOT_MULT so a data typo can never zero out or invert a reward. Static/pure.
static func loot_mult_of(spawn: Dictionary) -> float:
	return clampf(float(spawn.get("loot_mult", DEFAULT_LOOT_MULT)), MIN_LOOT_MULT, MAX_LOOT_MULT)

# Loot from a disabled creature spawn (creature_spawn_model.roll_spawn shape). Hostile-only; the SINGLE
# scale-independent base band x pack_size is then weighted by the creature's threat_tier (Wave G / G15,
# DIV-0028) so a riskier kill pays more, then by the OPTIONAL per-creature loot_mult (Wave G / G16) that
# corrects for within-tier kill-speed variance; a chance-gated (tier-independent) salvage bundle rides
# along. Seed is server-owned. threat_tier defaults to DEFAULT_LOOT_TIER (2) and loot_mult to 1.0 when
# absent, so legacy / partial spawns never break. The RNG draw ORDER is unchanged (band roll, then salvage
# chance, then salvage bundle) — both tier and loot_mult are pure post-multiplies on the credit figure, so
# a given seed's salvage result is identical regardless of scale/tier/mult; only the credit total scales.
static func roll_loot(spawn: Dictionary, seed: int) -> Dictionary:
	if not bool(spawn.get("hostile", false)):
		return {"credits": 0, "salvage_credits": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pack := maxi(int(spawn.get("pack_size", 1)), 1)
	var base := rng.randi_range(int(LOOT_BASE[0]), int(LOOT_BASE[1])) * pack
	var tier := int(spawn.get("threat_tier", DEFAULT_LOOT_TIER))
	var credits := int(round(float(base) * loot_tier_multiplier(tier) * loot_mult_of(spawn)))
	var salvage := 0
	if rng.randf() < SALVAGE_CHANCE:
		salvage = rng.randi_range(int(SALVAGE_BUNDLE[0]), int(SALVAGE_BUNDLE[1]))
	return {"credits": credits, "salvage_credits": salvage}
