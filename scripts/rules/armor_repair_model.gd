extends RefCounted
## Pure armor broken-state + repair-cost model (Wave G, DIV-0006 "at the floor = broken -> halved
## effectiveness until repaired" tier + the repair credit-sink). Live combat drives
## `armor_quality_pips` DOWN via armor_condition_model.apply_degradation (clamped at the condition
## floor). THIS model READS that pip level (it never mutates combat state) and answers the two
## things the ledger still needs modeled:
##   1. the BROKEN tier — armor sitting at the condition floor is "broken" and its soak pool is
##      HALVED until repaired. The live pool-halving is a later HOT slice mainline owns; this model
##      owns the boolean + the exact multiplier the slice will apply.
##   2. the REPAIR credit-sink — cost to restore pips back toward the ceiling, priced off the SAME
##      economy dial as the vendor buy-back (economy_model.sell_price), NOT a new pricing scheme.
## All-static, deterministic: NO RNG, NO clock. The pip range is reused verbatim from
## armor_condition_model so the floor/ceiling can never drift (MIN -6 = broken floor, MAX +6 =
## fully-repaired ceiling).

const ArmorCondition := preload("res://scripts/rules/armor_condition_model.gd")
const EconomyModel := preload("res://scripts/rules/economy_model.gd")

# Pip range reused verbatim from the condition model (single source of truth for floor/ceiling).
const MIN_QUALITY_PIPS := ArmorCondition.MIN_QUALITY_PIPS   # -6, the "broken" floor
const MAX_QUALITY_PIPS := ArmorCondition.MAX_QUALITY_PIPS   #  6, the fully-repaired ceiling
const TOTAL_SPAN := MAX_QUALITY_PIPS - MIN_QUALITY_PIPS     # 12 pips floor..ceiling = a full rebuild

# --- tunable dials ---
# DIV-0006: a broken item's pools are HALVED until repaired. The HOT slice multiplies the soak pool
# (dice + pips) by this factor; 0.5 = halved. Kept an explicit named const so the halving magnitude
# is a single edit rather than a scattered literal.
const BROKEN_POOL_MULTIPLIER := 0.5
# A full floor->ceiling repair costs this multiple of the item's economy buy-back (sell_price).
# =1.0 anchors a full rebuild at the item's own buy-back value, so repairing is never dominated by
# dump-and-rebuy (rebuy is clamped strictly ABOVE sell_price by economy_model.buy_floor). Tunable.
const REPAIR_FULL_SPAN_SINK := 1.0

# is_broken(pips) -> true once the item has degraded to (or, defensively, below) the condition
# floor. At the floor exactly it is broken; one pip above the floor it is NOT.
static func is_broken(quality_pips: int) -> bool:
	return quality_pips <= MIN_QUALITY_PIPS

# pool_multiplier(pips) -> the factor the HOT slice applies to the soak pool: 1.0 normally, the
# halved BROKEN_POOL_MULTIPLIER once broken.
static func pool_multiplier(quality_pips: int) -> float:
	return BROKEN_POOL_MULTIPLIER if is_broken(quality_pips) else 1.0

# repair_cost(current, target, list_cost) -> credits to restore pips toward the ceiling. Scales with
# BOTH the pips restored and the item's list cost (via economy_model.sell_price, so it reuses the
# shipped economy dial). Target is clamped at MAX (can't over-repair); cost is floored >= 1 whenever
# any pips are restored; returns 0 (no-op) when already at/above target, or when the item is
# unpriced (list_cost <= 0 — mirrors the economy buy/sell path for contraband / faction-issued gear).
static func repair_cost(current_pips: int, target_pips: int, list_cost: int) -> int:
	if list_cost <= 0:
		return 0
	var start := clampi(current_pips, MIN_QUALITY_PIPS, MAX_QUALITY_PIPS)
	var goal := clampi(target_pips, MIN_QUALITY_PIPS, MAX_QUALITY_PIPS)
	var restored := goal - start
	if restored <= 0:
		return 0
	var full_span_cost := float(EconomyModel.sell_price(list_cost)) * REPAIR_FULL_SPAN_SINK
	var cost := full_span_cost * float(restored) / float(TOTAL_SPAN)
	return maxi(int(round(cost)), 1)

# restore(current, target) -> the resulting pip level after paying for a repair. Never lowers the
# current level (a target at/below current is a no-op returning current) and never exceeds MAX (a
# target above the ceiling clamps to MAX).
static func restore(current_pips: int, target_pips: int) -> int:
	var goal := clampi(target_pips, MIN_QUALITY_PIPS, MAX_QUALITY_PIPS)
	return clampi(maxi(current_pips, goal), MIN_QUALITY_PIPS, MAX_QUALITY_PIPS)
