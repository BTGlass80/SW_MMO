extends SceneTree
## Smoke for the pure WEG-anchored economy (Wave F / DIV-0018): buy_price layering
## (list anchor + director event + bargain + rep, clamped), sell buy-back, non-mutating
## buy/sell with the can_* reason ladder, and the seeded creature loot roller.

const EconomyModel = preload("res://scripts/rules/economy_model.gd")
const VendorModel = preload("res://scripts/rules/vendor_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var vendor = VendorModel.new()

	# --- buy_price: list is the anchor at neutral/no-event/no-bargain (BUY_MARKUP=1.0) ---
	_assert_equal(EconomyModel.buy_price(500, 1.0, 0, 0, "neutral", vendor), 500, "neutral list price == cost")
	# trade_boom (director 0.85) lowers it.
	_assert_equal(EconomyModel.buy_price(500, 0.85, 0, 0, "neutral", vendor), 425, "trade_boom multiplier lowers the price")
	# friendly rep = 5% off; allied = 10% off (stacked after bargain).
	_assert_equal(EconomyModel.buy_price(500, 1.0, 0, 0, "friendly", vendor), 475, "friendly rep -5%")
	_assert_equal(EconomyModel.buy_price(500, 1.0, 10, 0, "allied", vendor), 315, "bargain 10D (-30%) then allied -10%")
	# hostile/neutral get no rep discount.
	_assert_equal(EconomyModel.buy_price(500, 1.0, 0, 0, "hostile", vendor), 500, "hostile rep -> no discount")
	# Buy floor (G5): stacked deep discounts never drop below 0.45 of list — the floor was raised above
	# the 0.40 sell rate so buy-at-floor-then-sell can no longer print credits.
	_assert_equal(EconomyModel.buy_price(500, 0.5, 20, 0, "allied", vendor), 225, "stacked discounts clamp at the 0.45-of-list floor (> sell)")
	# contraband / faction-issued (cost 0) is not vendor-priced.
	_assert_equal(EconomyModel.buy_price(0, 1.0, 0, 0, "neutral", vendor), 0, "cost-0 item is unpriced")

	# --- sell_price: 40% buy-back ---
	_assert_equal(EconomyModel.sell_price(500), 200, "sell pays 40% of list")
	_assert_equal(EconomyModel.sell_price(250), 100, "sell 40% of 250")

	# --- catalog + a starting sheet ---
	var catalog := {
		"blaster_pistol": {"vendor_stocked": true, "cost": 500},
		"vibroblade": {"vendor_stocked": true, "cost": 250},
		"cis_field_armor": {"vendor_stocked": false, "cost": 0},  # faction-issued, not sold
	}
	var sheet := {"credits": 1000, "inventory": ["blaster_pistol"], "equipment": {"weapon": "blaster_pistol"}}

	# --- can_buy reason ladder ---
	_assert_equal(String(EconomyModel.can_buy(sheet, "nope", 100, catalog)["reason"]), "unknown_item", "unknown item rejected")
	_assert_equal(String(EconomyModel.can_buy(sheet, "cis_field_armor", 100, catalog)["reason"]), "not_stocked", "un-stocked item rejected")
	_assert_equal(String(EconomyModel.can_buy(sheet, "vibroblade", 2000, catalog)["reason"]), "cannot_afford", "over-budget rejected")
	_assert_true(bool(EconomyModel.can_buy(sheet, "vibroblade", 250, catalog)["ok"]), "affordable stocked item ok")

	# --- buy is NON-mutating: credits deducted + item appended on the NEW sheet only ---
	var bought: Dictionary = EconomyModel.buy(sheet, "vibroblade", 250, catalog)
	_assert_true(bool(bought["ok"]), "buy ok")
	_assert_equal(int((bought["sheet"] as Dictionary)["credits"]), 750, "buy deducts the price")
	_assert_true(((bought["sheet"] as Dictionary)["inventory"] as Array).has("vibroblade"), "bought item appended to inventory")
	_assert_equal(int(sheet["credits"]), 1000, "original sheet is NOT mutated by buy")
	_assert_equal((sheet["inventory"] as Array).size(), 1, "original inventory is NOT mutated by buy")

	# --- sell: blocks a currently-equipped item; pays out an unequipped one; non-mutating ---
	_assert_equal(String(EconomyModel.can_sell(sheet, "blaster_pistol")["reason"]), "equipped", "cannot sell the equipped weapon")
	_assert_equal(String(EconomyModel.can_sell(sheet, "ghost_item")["reason"]), "not_owned", "cannot sell an unowned item")
	var newsheet: Dictionary = bought["sheet"]  # has an unequipped vibroblade
	_assert_true(bool(EconomyModel.can_sell(newsheet, "vibroblade")["ok"]), "an unequipped owned item is sellable")
	var sold: Dictionary = EconomyModel.sell(newsheet, "vibroblade", EconomyModel.sell_price(250))
	_assert_true(bool(sold["ok"]), "sell ok")
	_assert_equal(int((sold["sheet"] as Dictionary)["credits"]), 850, "sell adds the buy-back (750 + 100)")
	_assert_true(not ((sold["sheet"] as Dictionary)["inventory"] as Array).has("vibroblade"), "sold item removed from inventory")
	_assert_equal(int((newsheet as Dictionary)["credits"]), 750, "original sheet is NOT mutated by sell")

	# --- roll_loot: hostile-only, deterministic, ONE scale-independent base band x pack, zero for dummy ---
	# G15 (DIV-0028): ONE loot axis — a single base band [15,45] for EVERY hostile head (scale no longer
	# feeds credits) x threat_tier multiplier. This spawn omits threat_tier -> DEFAULT_LOOT_TIER (2) = x1.0,
	# so the credit band is [15,45] x pack 2 x1.0 = [30,90].
	var hostile_spawn := {"hostile": true, "scale": "creature", "pack_size": 2}
	var loot_a: Dictionary = EconomyModel.roll_loot(hostile_spawn, 7)
	var loot_b: Dictionary = EconomyModel.roll_loot(hostile_spawn, 7)
	_assert_equal(int(loot_a["credits"]), int(loot_b["credits"]), "roll_loot is deterministic for a fixed seed")
	_assert_true(int(loot_a["credits"]) >= 30 and int(loot_a["credits"]) <= 90, "creature loot in [15,45] x pack 2 x tier-2 default (x1.0) = [30,90]")
	var non_hostile := {"hostile": false, "scale": "creature", "pack_size": 3}
	_assert_equal(int(EconomyModel.roll_loot(non_hostile, 7)["credits"]), 0, "non-hostile (sparring) disable drops zero credits")

	# --- scale no longer feeds loot credits (double-dip killed, G15) ---
	# character scale and creature scale with the same tier/pack/seed pay IDENTICAL credits now.
	var creature_t3 := {"hostile": true, "scale": "creature", "pack_size": 1, "threat_tier": 3}
	var character_t3 := {"hostile": true, "scale": "character", "pack_size": 1, "threat_tier": 3}
	for sc in [1, 7, 99, 4242]:
		_assert_equal(int(EconomyModel.roll_loot(creature_t3, sc)["credits"]), int(EconomyModel.roll_loot(character_t3, sc)["credits"]), "creature vs character scale pay the SAME credits at equal tier (no scale double-dip, seed %d)" % sc)

	# --- roll_loot threat-tier weighting (Wave G / G15): risk is the ONE reward axis ---
	# Same scale/pack/seed, only threat_tier differs: credits must be MONOTONE NON-DECREASING in tier,
	# and a tier-4 apex must pay STRICTLY more than a tier-2 common (x7 vs x1 on a >=15 base). Note t1==t2
	# (both x1) by design — there is no hostile tier-1 creature in the catalog, so t1 is the never-used floor.
	var t1 := {"hostile": true, "scale": "creature", "pack_size": 1, "threat_tier": 1}
	var t2 := {"hostile": true, "scale": "creature", "pack_size": 1, "threat_tier": 2}
	var t3 := {"hostile": true, "scale": "creature", "pack_size": 1, "threat_tier": 3}
	var t4 := {"hostile": true, "scale": "creature", "pack_size": 1, "threat_tier": 4}
	var t5 := {"hostile": true, "scale": "creature", "pack_size": 1, "threat_tier": 5}
	for s in [1, 7, 99, 4242, 123456]:
		var c1 := int(EconomyModel.roll_loot(t1, s)["credits"])
		var c2 := int(EconomyModel.roll_loot(t2, s)["credits"])
		var c3 := int(EconomyModel.roll_loot(t3, s)["credits"])
		var c4 := int(EconomyModel.roll_loot(t4, s)["credits"])
		var c5 := int(EconomyModel.roll_loot(t5, s)["credits"])
		_assert_true(c1 <= c2 and c2 <= c3 and c3 <= c4 and c4 <= c5, "loot credits monotone non-decreasing in threat_tier (seed %d): %d<=%d<=%d<=%d<=%d" % [s, c1, c2, c3, c4, c5])
		_assert_true(c4 > c2, "a tier-4 apex pays strictly MORE than a tier-2 common for the same seed %d (%d > %d)" % [s, c4, c2])

	# tier-1 IS the un-weighted band (x1): its credit == the raw base for the same seed.
	_assert_true(int(EconomyModel.roll_loot(t1, 7)["credits"]) >= 15 and int(EconomyModel.roll_loot(t1, 7)["credits"]) <= 45, "tier-1 (x1) loot is the raw [15,45] band for pack 1")

	# default-tier fallback: a spawn with NO threat_tier == an explicit tier-2 spawn, roll for roll.
	var no_tier := {"hostile": true, "scale": "creature", "pack_size": 1}
	for s2 in [1, 7, 99, 4242]:
		_assert_equal(int(EconomyModel.roll_loot(no_tier, s2)["credits"]), int(EconomyModel.roll_loot(t2, s2)["credits"]), "an omitted threat_tier defaults to tier 2 (seed %d)" % s2)

	# determinism holds for a tiered spawn too (same seed -> identical credits + salvage).
	var d1: Dictionary = EconomyModel.roll_loot(t4, 555)
	var d2: Dictionary = EconomyModel.roll_loot(t4, 555)
	_assert_equal(int(d1["credits"]), int(d2["credits"]), "tiered roll_loot credits are deterministic for a fixed seed")
	_assert_equal(int(d1["salvage_credits"]), int(d2["salvage_credits"]), "tiered roll_loot salvage is deterministic for a fixed seed")

	# the multiplier helper (G15): 1=x1 floor, 2=x1, 3=x3, 4=x8 apex, 5=x10 boss; out-of-range clamps in.
	_assert_equal(EconomyModel.loot_tier_multiplier(1), 1.0, "tier 1 -> x1 floor")
	_assert_equal(EconomyModel.loot_tier_multiplier(2), 1.0, "tier 2 -> x1 (== t1, the common entry)")
	_assert_equal(EconomyModel.loot_tier_multiplier(3), 3.0, "tier 3 -> x3")
	_assert_equal(EconomyModel.loot_tier_multiplier(4), 8.0, "tier 4 apex -> x8")
	_assert_equal(EconomyModel.loot_tier_multiplier(5), 10.0, "tier 5 boss -> x10")
	_assert_equal(EconomyModel.loot_tier_multiplier(0), 1.0, "a below-range tier clamps to the x1 floor")
	_assert_equal(EconomyModel.loot_tier_multiplier(9), 10.0, "an above-range tier clamps to the x10 boss cap")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("economy_model_smoke: OK")
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
