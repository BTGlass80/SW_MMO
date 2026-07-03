extends SceneTree
## Anti-arbitrage smoke for the pure economy model (Wave G / G5). Proves the buy->sell exploit is
## closed and CANNOT recur: for EVERY vendor_stocked catalog item (weapons + armor) and for a range
## of raw list costs, the cheapest a BUY can ever cost (buy_floor) is STRICTLY greater than what an
## immediate SELL pays back (sell_price). If this ever regresses (e.g. someone re-widens
## MAX_TOTAL_DISCOUNT past 1 - SELL_RATE), this test goes red. Deterministic; RNG seeded by
## convention even though the pricing model is pure.

const EconomyModel = preload("res://scripts/rules/economy_model.gd")

const WEAPONS_DATA_PATH := "res://data/weapons_clone_wars.json"
const ARMOR_DATA_PATH := "res://data/armor_clone_wars.json"

var _failures: Array[String] = []

func _init() -> void:
	# Seed RNG per project convention (never randomize()); the pricing model itself is pure/static.
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	# --- direct unit asserts: buy_floor(list) > sell_price(list) across a range of list costs -----
	# Covers a tiny cost (integer-rounding edge), typical gear, and a big-ticket item.
	for list_cost in [1, 100, 500, 5000]:
		var floor_v: int = EconomyModel.buy_floor(list_cost)
		var sell_v: int = EconomyModel.sell_price(list_cost)
		_assert_true(floor_v > sell_v,
			"buy_floor(%d)=%d must be > sell_price(%d)=%d (no buy->sell arbitrage)" % [list_cost, floor_v, list_cost, sell_v])
		# The floor is also the true clamp used by buy_price: an extreme stacked discount can never
		# drive the paid price below buy_floor (proves buy_price and buy_floor cannot drift apart).
		var deep_discount: int = EconomyModel.buy_price(list_cost, 0.1, 20, 0, "allied", _NullVendor.new())
		_assert_true(deep_discount >= floor_v,
			"buy_price(%d, max discount) = %d must not fall below buy_floor = %d" % [list_cost, deep_discount, floor_v])
		_assert_true(deep_discount > sell_v,
			"buy_price(%d, max discount) = %d must stay > sell_price = %d" % [list_cost, deep_discount, sell_v])

	# --- catalog-wide: every vendor_stocked weapon + armor obeys buy_floor(list) > sell_price(list) -
	var weapons_data := _load_json(WEAPONS_DATA_PATH)
	var armor_data := _load_json(ARMOR_DATA_PATH)
	var checked := 0
	checked += _check_catalog_section(weapons_data.get("weapons", {}), "weapon")
	checked += _check_catalog_section(armor_data.get("armor", {}), "armor")
	# Guard against silently checking nothing (bad path / empty data would make the test vacuous).
	_assert_true(checked > 0, "at least one vendor_stocked catalog item was checked (data loaded)")

	_finish()

# Iterate a top-level catalog map ({key: {cost, vendor_stocked, ...}}) the way the vendor/economy
# code does; assert the invariant on each priced, vendor-stocked entry. Returns how many were checked.
func _check_catalog_section(section: Dictionary, kind: String) -> int:
	var count := 0
	for key in section.keys():
		var entry: Dictionary = section.get(key, {})
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not bool(entry.get("vendor_stocked", false)):
			continue
		var list_cost := int(entry.get("cost", 0))
		if list_cost <= 0:
			continue  # cost-0 items are unpriced (both floor and sell return 0) -- not an arbitrage
		var floor_v: int = EconomyModel.buy_floor(list_cost)
		var sell_v: int = EconomyModel.sell_price(list_cost)
		_assert_true(floor_v > sell_v,
			"%s '%s' (list %d): buy_floor=%d must be > sell_price=%d" % [kind, String(key), list_cost, floor_v, sell_v])
		count += 1
	return count

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % path)
		return {}
	return parsed

func _finish() -> void:
	if _failures.is_empty():
		print("economy_floor_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

# Minimal vendor stub matching vendor_model.quote()'s signature, so buy_price can be exercised
# without loading the full droid/vendor data. Applies the same maxed bargain math (>=0.5 cap) as
# vendor_model so the "deep discount" path genuinely tries to punch through the floor.
class _NullVendor:
	func quote(base_cost: int, director_multiplier: float, bargain_dice: int, bargain_pips: int) -> int:
		var effective_dice := float(bargain_dice) + float(bargain_pips) / 3.0
		var discount := clampf(effective_dice * 0.03, 0.0, 0.5)
		return int(round(float(base_cost) * director_multiplier * (1.0 - discount)))
