extends SceneTree
## Headless smoke for the pure armor broken-state + repair-cost model (Wave G, DIV-0006 "at the
## floor = broken -> halved pools until repaired" tier + the repair credit-sink). Deterministic:
## NO RNG, NO clock. Pins the broken tier exactly at the condition floor (and NOT one pip above),
## the halved pool multiplier, the repair cost scaling with BOTH pips restored AND list cost (with
## the >= 1 floor and the at/above-target no-op), and restore() clamping at the PRISTINE ceiling.
##
## Repair ceiling = PRISTINE (NEW_QUALITY_PIPS = 0), NOT the MAX_QUALITY_PIPS (+6) clamp bound: live
## combat seeds armor_quality_pips at 0 and only degrades DOWN toward the -6 floor, so the degradable
## span is [-6, 0] = TOTAL_SPAN 6. Repairing toward +6 would mint +2D super-armor above undamaged AND
## charge for pristine gear, so the model clamps every repair target to [MIN, 0]. (verify: repair-economy)

const Repair := preload("res://scripts/rules/armor_repair_model.gd")
const ArmorCondition := preload("res://scripts/rules/armor_condition_model.gd")
const EconomyModel := preload("res://scripts/rules/economy_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var floor_pips := int(ArmorCondition.MIN_QUALITY_PIPS)   # -6 broken floor
	var clamp_bound := int(ArmorCondition.MAX_QUALITY_PIPS)  # +6 condition clamp bound (never reached in play)
	var pristine := int(Repair.NEW_QUALITY_PIPS)             #  0 pristine = the REPAIR ceiling

	# --- the range is reused verbatim from the condition model (no drift) ---
	_assert_equal(Repair.MIN_QUALITY_PIPS, floor_pips, "MIN reused from armor_condition_model (-6 floor)")
	_assert_equal(Repair.MAX_QUALITY_PIPS, clamp_bound, "MAX reused from armor_condition_model (+6 clamp bound)")
	_assert_equal(Repair.NEW_QUALITY_PIPS, 0, "PRISTINE repair ceiling is 0 (combat degrades DOWN from here)")
	_assert_equal(Repair.TOTAL_SPAN, pristine - floor_pips, "degradable span is floor..pristine = 6 pips")

	# --- broken tier: exactly AT the floor, and NOT one pip above ---
	_assert_equal(Repair.is_broken(floor_pips), true, "broken exactly at the condition floor (-6)")
	_assert_equal(Repair.is_broken(floor_pips + 1), false, "NOT broken one pip above the floor (-5)")
	_assert_equal(Repair.is_broken(0), false, "not broken at pristine quality (0)")
	# Defensive: at/below the floor is still broken (combat clamps, but guard anyway).
	_assert_equal(Repair.is_broken(floor_pips - 1), true, "below the floor still reads broken (defensive)")

	# --- pool multiplier: 1.0 normal, halved (0.5) when broken ---
	_assert_equal(Repair.pool_multiplier(0), 1.0, "pristine armor -> full pool (x1.0)")
	_assert_equal(Repair.pool_multiplier(floor_pips + 1), 1.0, "one pip above the floor is still full pool")
	_assert_equal(Repair.pool_multiplier(floor_pips), 0.5, "broken armor -> HALVED pool (x0.5)")
	_assert_equal(Repair.pool_multiplier(floor_pips), Repair.BROKEN_POOL_MULTIPLIER, "broken multiplier is the tunable const")

	# --- repair_cost scales with PIPS RESTORED (same list cost), all targeting the PRISTINE ceiling (0) ---
	var list := 1200  # a mid-tier item; sell_price(1200)=480 -> per-pip = 480/6 = 80
	var full := Repair.repair_cost(floor_pips, pristine, list)   # restore 6 pips (broken -> pristine)
	var half := Repair.repair_cost(-3, pristine, list)           # restore 3 pips
	var third := Repair.repair_cost(-2, pristine, list)          # restore 2 pips
	_assert_equal(full > half, true, "repairing more pips costs more (6 > 3 pips)")
	_assert_equal(half > third, true, "repairing more pips costs more (3 > 2 pips)")
	# A full floor->pristine repair is anchored on the economy buy-back (sell_price), reusing the dial.
	_assert_equal(full, EconomyModel.sell_price(list), "full rebuild = the item's economy buy-back value (reuses sell_price)")
	_assert_equal(half, int(round(float(EconomyModel.sell_price(list)) * 3.0 / 6.0)), "half-span repair is proportional to pips restored")

	# --- repair_cost scales with LIST COST (same pips restored) ---
	var cheap := Repair.repair_cost(floor_pips, pristine, 300)
	var dear := Repair.repair_cost(floor_pips, pristine, 1200)
	_assert_equal(dear > cheap, true, "a pricier item costs more to repair the same pips")

	# --- floors at >= 1 whenever any pips are restored (tiny list -> rounds to 0 -> floored to 1) ---
	_assert_equal(Repair.repair_cost(floor_pips, floor_pips + 1, 1), 1, "1 pip on a 1-credit item still costs >= 1")
	_assert_equal(Repair.repair_cost(floor_pips, pristine, 1) >= 1, true, "any real repair costs at least 1 credit")

	# --- no-op cases return 0 ---
	_assert_equal(Repair.repair_cost(pristine, pristine, list), 0, "already at target (pristine) -> 0")
	_assert_equal(Repair.repair_cost(-2, -4, list), 0, "target BELOW current -> no-op 0")
	_assert_equal(Repair.repair_cost(floor_pips, floor_pips, list), 0, "broken but target=floor -> 0")
	# Unpriced item (list_cost <= 0, e.g. faction-issued/contraband) -> no repair charge.
	_assert_equal(Repair.repair_cost(floor_pips, pristine, 0), 0, "unpriced item (list 0) -> no repair charge")

	# --- ANTI-SUPER-ARMOR: a target ABOVE pristine is clamped to 0; repairing pristine toward +6 is free ---
	_assert_equal(Repair.repair_cost(floor_pips, clamp_bound, list), full, "target above pristine (+6) is clamped -> same cost as repair to pristine (0)")
	_assert_equal(Repair.repair_cost(pristine, clamp_bound, list), 0, "repairing PRISTINE gear toward +6 costs 0 (undamaged is never charged)")

	# --- restore() clamps at PRISTINE (0) and never lowers the current level ---
	_assert_equal(Repair.restore(floor_pips, pristine), pristine, "repair from the floor to pristine -> 0")
	_assert_equal(Repair.restore(floor_pips, -3), -3, "partial repair lands at the requested (still-negative) target")
	_assert_equal(Repair.restore(floor_pips, clamp_bound), pristine, "over-repair toward +6 is CLAMPED at pristine (0) — no super-armor")
	_assert_equal(Repair.restore(pristine, clamp_bound), pristine, "already pristine + over-target -> stays 0")
	_assert_equal(Repair.restore(-2, -4), -2, "target BELOW current -> no-op (keeps current)")
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
