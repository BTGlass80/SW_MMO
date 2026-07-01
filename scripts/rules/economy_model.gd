extends RefCounted
## Pure WEG-anchored credit economy (Wave F / DIV-0018). Owner decision 2026-07-01:
## "modest sink, WEG-anchored prices". Each catalog `cost` IS the WEG R&E list price and the
## BUY anchor (BUY_MARKUP=1.0); the churn sink is the 40% sell/buy-back spread. Buy price layers
## the Director event multiplier + Bargain (via a PASSED vendor_model instance) + a small rep
## discount, clamped so stacked discounts never drop below 0.35 of list. Loot credits drop from a
## disabled HOSTILE creature only (the training dummy stays CP-only). All-static, NO RNG of its
## own — the loot roller takes an explicit server-owned seed. All SPEND numbers are tunable consts.

# --- tunable economy constants ---
const STARTING_CREDITS := 1000       # chargen wallet (~2 sidearms or 1 heavy + vest of headroom)
const BUY_MARKUP := 1.0              # WEG list = street price; the sink is the sell spread, not markup
const SELL_RATE := 0.40             # vendor buy-back pays 40% of list (the 60% spread is the churn sink)
const MAX_TOTAL_DISCOUNT := 0.65    # stacked bargain+rep+event never take price below 0.35 of list
const REP_DISCOUNT := {"friendly": 0.05, "allied": 0.10}  # by reputation_model.standing_tier; else 0.0
# loot on a disabled hostile creature (credits/salvage only in v1; item drops are owner-gated follow-up)
const LOOT_CREATURE := [15, 45]     # per-head credit band for scale "creature"
const LOOT_CHARACTER := [40, 90]    # per-head credit band for scale "character"
const SALVAGE_CHANCE := 0.25        # chance a disabled hostile also yields a salvage bundle
const SALVAGE_BUNDLE := [20, 60]    # salvage-credit band

# Rep-tier -> buy discount (0.0 for hostile/neutral). Keyed on reputation_model.standing_tier().
static func discount_for_tier(tier: String) -> float:
	return float(REP_DISCOUNT.get(tier, 0.0))

# Final buy price. Delegates the Director multiplier + Bargain to the passed vendor INSTANCE
# (vendor_model.quote), then applies BUY_MARKUP + the rep discount, clamped to MAX_TOTAL_DISCOUNT
# of list, floored at 1 credit.
static func buy_price(list_cost: int, director_multiplier: float, bargain_dice: int, bargain_pips: int, rep_tier: String, vendor: Object) -> int:
	if list_cost <= 0:
		return 0  # contraband / faction-issued (cost 0) is not vendor-priced
	var quoted := int(vendor.quote(list_cost, director_multiplier, bargain_dice, bargain_pips))
	var price := int(round(float(quoted) * BUY_MARKUP * (1.0 - discount_for_tier(rep_tier))))
	var floor_price := int(ceil(float(list_cost) * (1.0 - MAX_TOTAL_DISCOUNT)))
	return maxi(maxi(price, floor_price), 1)

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

# Loot from a disabled creature spawn (creature_spawn_model.roll_spawn shape). Hostile-only;
# scale-tiered credits x pack_size + a chance-gated salvage bundle. Seed is server-owned.
static func roll_loot(spawn: Dictionary, seed: int) -> Dictionary:
	if not bool(spawn.get("hostile", false)):
		return {"credits": 0, "salvage_credits": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var band: Array = LOOT_CHARACTER if String(spawn.get("scale", "creature")) == "character" else LOOT_CREATURE
	var pack := maxi(int(spawn.get("pack_size", 1)), 1)
	var credits := rng.randi_range(int(band[0]), int(band[1])) * pack
	var salvage := 0
	if rng.randf() < SALVAGE_CHANCE:
		salvage = rng.randi_range(int(SALVAGE_BUNDLE[0]), int(SALVAGE_BUNDLE[1]))
	return {"credits": credits, "salvage_credits": salvage}
