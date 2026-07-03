extends SceneTree
## Headless smoke for the pure armor broken-state + repair-cost model (Wave G, DIV-0006 "at the
## floor = broken -> halved pools until repaired" tier + the repair credit-sink). Deterministic:
## NO RNG, NO clock. Pins the broken tier exactly at the condition floor (and NOT one pip above),
## the halved pool multiplier, the repair cost scaling with BOTH pips restored AND list cost (with
## the >= 1 floor and the at/above-target no-op), and restore() clamping at MAX. The pip range is
## reused from armor_condition_model (MIN -6 floor, MAX +6 ceiling) so it can never drift.

const Repair := preload("res://scripts/rules/armor_repair_model.gd")
const ArmorCondition := preload("res://scripts/rules/armor_condition_model.gd")
const EconomyModel := preload("res://scripts/rules/economy_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var floor_pips := int(ArmorCondition.MIN_QUALITY_PIPS)   # -6
	var ceil_pips := int(ArmorCondition.MAX_QUALITY_PIPS)    #  6

	# --- the range is reused verbatim from the condition model (no drift) ---
	_assert_equal(Repair.MIN_QUALITY_PIPS, floor_pips, "MIN reused from armor_condition_model (-6 floor)")
	_assert_equal(Repair.MAX_QUALITY_PIPS, ceil_pips, "MAX reused from armor_condition_model (+6 ceiling)")
	_assert_equal(Repair.TOTAL_SPAN, ceil_pips - floor_pips, "full span is floor..ceiling = 12 pips")

	# --- broken tier: exactly AT the floor, and NOT one pip above ---
	_assert_equal(Repair.is_broken(floor_pips), true, "broken exactly at the condition floor (-6)")
	_assert_equal(Repair.is_broken(floor_pips + 1), false, "NOT broken one pip above the floor (-5)")
	_assert_equal(Repair.is_broken(0), false, "not broken at neutral quality (0)")
	_assert_equal(Repair.is_broken(ceil_pips), false, "not broken at full quality (+6)")
	# Defensive: at/below the floor is still broken (combat clamps, but guard anyway).
	_assert_equal(Repair.is_broken(floor_pips - 1), true, "below the floor still reads broken (defensive)")

	# --- pool multiplier: 1.0 normal, halved (0.5) when broken ---
	_assert_equal(Repair.pool_multiplier(0), 1.0, "normal armor -> full pool (x1.0)")
	_assert_equal(Repair.pool_multiplier(ceil_pips), 1.0, "full-quality armor -> full pool (x1.0)")
	_assert_equal(Repair.pool_multiplier(floor_pips + 1), 1.0, "one pip above the floor is still full pool")
	_assert_equal(Repair.pool_multiplier(floor_pips), 0.5, "broken armor -> HALVED pool (x0.5)")
	_assert_equal(Repair.pool_multiplier(floor_pips), Repair.BROKEN_POOL_MULTIPLIER, "broken multiplier is the tunable const")

	# --- repair_cost scales with PIPS RESTORED (same list cost) ---
	var list := 1200  # a mid-tier item; sell_price(1200)=480 -> per-pip = 480/12 = 40
	var full := Repair.repair_cost(floor_pips, ceil_pips, list)   # restore 12 pips (broken -> full)
	var half := Repair.repair_cost(0, ceil_pips, list)            # restore 6 pips
	var quarter := Repair.repair_cost(3, ceil_pips, list)         # restore 3 pips
	_assert_equal(full > half, true, "repairing more pips costs more (12 > 6 pips)")
	_assert_equal(half > quarter, true, "repairing more pips costs more (6 > 3 pips)")
	# A full floor->ceiling repair is anchored on the economy buy-back (sell_price), reusing the dial.
	_assert_equal(full, EconomyModel.sell_price(list), "full rebuild = the item's economy buy-back value (reuses sell_price)")
	_assert_equal(half, int(round(float(EconomyModel.sell_price(list)) * 6.0 / 12.0)), "half-span repair is proportional to pips restored")

	# --- repair_cost scales with LIST COST (same pips restored) ---
	var cheap := Repair.repair_cost(floor_pips, ceil_pips, 300)
	var dear := Repair.repair_cost(floor_pips, ceil_pips, 1200)
	_assert_equal(dear > cheap, true, "a pricier item costs more to repair the same pips")

	# --- floors at >= 1 whenever any pips are restored (tiny list -> rounds to 0 -> floored to 1) ---
	_assert_equal(Repair.repair_cost(floor_pips, floor_pips + 1, 1), 1, "1 pip on a 1-credit item still costs >= 1")
	_assert_equal(Repair.repair_cost(floor_pips, ceil_pips, 1) >= 1, true, "any real repair costs at least 1 credit")

	# --- no-op cases return 0 ---
	_assert_equal(Repair.repair_cost(ceil_pips, ceil_pips, list), 0, "already at target (MAX) -> 0")
	_assert_equal(Repair.repair_cost(3, 3, list), 0, "already at target (mid) -> 0")
	_assert_equal(Repair.repair_cost(3, 0, list), 0, "target BELOW current -> no-op 0")
	_assert_equal(Repair.repair_cost(floor_pips, floor_pips, list), 0, "broken but target=floor -> 0")
	# Over-repair request is clamped at MAX, so cost matches a repair to exactly MAX (no extra charge).
	_assert_equal(Repair.repair_cost(floor_pips, ceil_pips + 10, list), full, "target above MAX is clamped -> same cost as repair to MAX")
	# Unpriced item (list_cost <= 0, e.g. faction-issued/contraband) -> no repair charge.
	_assert_equal(Repair.repair_cost(floor_pips, ceil_pips, 0), 0, "unpriced item (list 0) -> no repair charge")

	# --- restore() clamps at MAX and never lowers the current level ---
	_assert_equal(Repair.restore(floor_pips, ceil_pips), ceil_pips, "repair from the floor to full -> MAX")
	_assert_equal(Repair.restore(floor_pips, 0), 0, "partial repair lands at the requested target")
	_assert_equal(Repair.restore(0, ceil_pips + 99), ceil_pips, "over-repair target is CLAMPED at MAX")
	_assert_equal(Repair.restore(ceil_pips, ceil_pips + 5), ceil_pips, "already at MAX + over-target -> stays MAX")
	_assert_equal(Repair.restore(3, 0), 3, "target BELOW current -> no-op (keeps current)")
	_assert_equal(Repair.restore(floor_pips, floor_pips), floor_pips, "repair to the same (floor) level is a no-op")

	if _failures.is_empty():
		print("armor_repair_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
