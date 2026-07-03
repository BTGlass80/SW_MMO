extends SceneTree
## HARDENING smoke for the pure economy model (scripts/rules/economy_model.gd). Adversarial edge-case
## coverage beyond economy_model_smoke.gd: exact-credit boundaries, the free-item (cost 0) can_buy
## path, the MAX_TOTAL_DISCOUNT floor at its exact boundary, ownership materialization when a sheet
## has NO inventory key at all, the (intentional, now-locked-in) "equipped blocks ALL copies" sell
## rule even when a spare is owned, stacked-item sell-down-to-zero, and roll_loot's scale band +
## salvage-chance behavior across distinct seeds. All deterministic.

const EconomyModel = preload("res://scripts/rules/economy_model.gd")
const VendorModel = preload("res://scripts/rules/vendor_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var vendor = VendorModel.new()

	# --- exact-credit boundary: affordable at EXACTLY the price; short by 1 fails ---
	var exact_sheet := {"credits": 250, "inventory": [], "equipment": {}}
	var catalog := {"vibroblade": {"vendor_stocked": true, "cost": 250}}
	_assert_true(bool(EconomyModel.can_buy(exact_sheet, "vibroblade", 250, catalog)["ok"]), "affording the EXACT price is allowed")
	var bought := EconomyModel.buy(exact_sheet, "vibroblade", 250, catalog)
	_assert_equal(int((bought["sheet"] as Dictionary)["credits"]), 0, "spending the exact balance leaves 0 credits")
	var short_sheet := {"credits": 249, "inventory": [], "equipment": {}}
	_assert_equal(String(EconomyModel.can_buy(short_sheet, "vibroblade", 250, catalog)["reason"]), "cannot_afford", "1 credit short is rejected")

	# --- can_buy on a free (cost-0 / faction-issued) but VENDOR-STOCKED item never blocks on price ---
	var free_catalog := {"issued_kit": {"vendor_stocked": true, "cost": 0}}
	var broke_sheet := {"credits": 0, "inventory": [], "equipment": {}}
	_assert_true(bool(EconomyModel.can_buy(broke_sheet, "issued_kit", 0, free_catalog)["ok"]), "a 0-price stocked item is buyable even at 0 credits")

	# --- buy_price: MAX_TOTAL_DISCOUNT floor at its EXACT boundary (0.35 of list, list=1000) ---
	# An extreme director discount + max bargain + allied rep would drive the raw price far below the
	# floor; buy_price must clamp to exactly ceil(1000*0.35)=350, never lower.
	var floored := EconomyModel.buy_price(1000, 0.1, 20, 0, "allied", vendor)
	_assert_equal(floored, 350, "stacked extreme discounts clamp to exactly the 0.35-of-list floor")
	# A price already ABOVE the floor before clamping passes through unclamped (sanity: the floor is a
	# MINIMUM, not a universal re-price).
	var unclamped := EconomyModel.buy_price(1000, 1.0, 0, 0, "neutral", vendor)
	_assert_equal(unclamped, 1000, "an undiscounted price is not touched by the floor clamp")

	# --- ownership materialization: a sheet with NO "inventory" key at all still owns its equipped gear ---
	var equipped_only := {"credits": 500, "equipment": {"weapon": "blaster_pistol"}}  # no "inventory" key
	var mat_catalog := {"vibroblade": {"vendor_stocked": true, "cost": 100}}
	var mat_bought := EconomyModel.buy(equipped_only, "vibroblade", 100, mat_catalog)
	_assert_true(bool(mat_bought["ok"]), "buy succeeds on a sheet with no prior inventory key")
	var mat_inv: Array = (mat_bought["sheet"] as Dictionary)["inventory"]
	_assert_true(mat_inv.has("blaster_pistol"), "the previously-equipped-only item is materialized into inventory")
	_assert_true(mat_inv.has("vibroblade"), "the newly bought item is present too")
	_assert_equal(mat_inv.size(), 2, "exactly the equipped item + the new purchase, nothing extra")

	# --- (locked-in, intentional) can_sell blocks ALL copies of an equipped item type, even a spare ---
	var spare_sheet := {"credits": 0, "equipment": {"weapon": "blaster_pistol"},
		"inventory": ["blaster_pistol", "blaster_pistol"]}  # one worn + one spare
	_assert_equal(String(EconomyModel.can_sell(spare_sheet, "blaster_pistol")["reason"]), "equipped",
		"can_sell blocks the whole item TYPE while equipped, even though a spare copy is owned (economy_model is not per-instance; death_penalty_model IS -- this is a documented divergence between the two models, not a bug in either)")

	# --- stacked sell-down-to-zero: selling twice removes the item entirely, third sell fails not_owned ---
	var stack_sheet := {"credits": 0, "equipment": {}, "inventory": ["knife", "knife"]}
	var s1 := EconomyModel.sell(stack_sheet, "knife", 5)
	_assert_true(bool(s1["ok"]), "first sell of a stacked item succeeds")
	_assert_equal(((s1["sheet"] as Dictionary)["inventory"] as Array).size(), 1, "one instance remains after the first sell")
	var s2 := EconomyModel.sell(s1["sheet"], "knife", 5)
	_assert_true(bool(s2["ok"]), "second sell succeeds")
	_assert_equal(((s2["sheet"] as Dictionary)["inventory"] as Array).size(), 0, "no instances remain after selling both")
	_assert_equal(String(EconomyModel.can_sell(s2["sheet"], "knife")["reason"]), "not_owned", "a third sell attempt correctly reports not_owned")

	# --- roll_loot: "character" scale band + a distinct seed changes the roll (seed actually matters) ---
	var char_spawn := {"hostile": true, "scale": "character", "pack_size": 1}
	var loot_char: Dictionary = EconomyModel.roll_loot(char_spawn, 42)
	_assert_true(int(loot_char["credits"]) >= 40 and int(loot_char["credits"]) <= 90, "character-scale loot lands in [40,90] for pack 1")
	var loot_other_seed: Dictionary = EconomyModel.roll_loot(char_spawn, 4242)
	# not asserting inequality of a single field (small band could coincide) -- assert the pair of
	# (credits, salvage_credits) tuples differ across enough distinct seeds to prove determinism-by-seed.
	var distinct_found := false
	for seed in [1, 2, 3, 4, 5, 6, 7, 8]:
		var a: Dictionary = EconomyModel.roll_loot(char_spawn, seed)
		var b: Dictionary = EconomyModel.roll_loot(char_spawn, seed + 1000)
		if int(a["credits"]) != int(b["credits"]) or int(a["salvage_credits"]) != int(b["salvage_credits"]):
			distinct_found = true
			break
	_assert_true(distinct_found, "different seeds produce different loot rolls (seed actually drives the RNG)")

	# --- roll_loot: missing pack_size defaults to (and floors at) 1, no crash on scale 0 / negative ---
	var no_pack := {"hostile": true, "scale": "creature"}
	var loot_no_pack: Dictionary = EconomyModel.roll_loot(no_pack, 9)
	_assert_true(int(loot_no_pack["credits"]) >= 15 and int(loot_no_pack["credits"]) <= 45, "a missing pack_size defaults to pack 1 (band unmultiplied)")
	var neg_pack := {"hostile": true, "scale": "creature", "pack_size": -3}
	var loot_neg_pack: Dictionary = EconomyModel.roll_loot(neg_pack, 9)
	_assert_true(int(loot_neg_pack["credits"]) >= 15 and int(loot_neg_pack["credits"]) <= 45, "a negative pack_size floors at 1, does not invert/crash")

	# --- discount_for_tier: unknown tier defaults to no discount ---
	_assert_equal(EconomyModel.discount_for_tier("nonexistent_tier"), 0.0, "an unrecognized rep tier gets no discount")
	_assert_equal(EconomyModel.discount_for_tier(""), 0.0, "an empty tier string gets no discount")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("economy_model_edge_smoke: OK")
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
