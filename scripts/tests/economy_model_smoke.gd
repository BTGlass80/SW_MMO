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

	# --- roll_loot: hostile-only, deterministic, scale-tiered x pack, zero for the dummy ---
	var hostile_spawn := {"hostile": true, "scale": "creature", "pack_size": 2}
	var loot_a: Dictionary = EconomyModel.roll_loot(hostile_spawn, 7)
	var loot_b: Dictionary = EconomyModel.roll_loot(hostile_spawn, 7)
	_assert_equal(int(loot_a["credits"]), int(loot_b["credits"]), "roll_loot is deterministic for a fixed seed")
	_assert_true(int(loot_a["credits"]) >= 30 and int(loot_a["credits"]) <= 90, "creature loot in [15,45] x pack 2")
	var non_hostile := {"hostile": false, "scale": "creature", "pack_size": 3}
	_assert_equal(int(EconomyModel.roll_loot(non_hostile, 7)["credits"]), 0, "non-hostile (sparring) disable drops zero credits")

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
