extends SceneTree
## Flow guard for the LIVE armor-repair wiring (DIV-0026, Seam 4b). network_manager is a Node autoload
## not headlessly instantiable, so — like corpse_loot_wire_smoke / harvest_wire_smoke mirror the server
## composition around the pure models — this mirrors submit_repair_armor's record-side decision + effects
## around ArmorRepairModel (repair_cost/restore) + the _award_credits debit + the pip write-back:
##   * an AFFORDABLE repair of a BROKEN (floor) armor debits exactly repair_cost(current, PRISTINE, list)
##     and restores the quality pips to PRISTINE (0) — the real ceiling, NOT the +6 clamp bound;
##   * an UNAFFORDABLE repair is rejected with credits + pips untouched;
##   * an already-PRISTINE armor is a no-op (cost 0, no debit);
##   * repair NEVER over-restores above pristine (no +2D super-armor) and NEVER charges for undamaged gear;
##   * unpriced (list 0) / unknown / not-equipped requests reject cleanly (mirror buy/sell).
## armor_repair_model_smoke pins the pure cost/restore math; this locks the RPC's affordability gate +
## credit debit + pip restore composition to that model. (verify: repair-economy — repair anchors at
## NEW_QUALITY_PIPS (0), the pristine baseline combat degrades DOWN from, not MAX_QUALITY_PIPS (+6).)

const Repair := preload("res://scripts/rules/armor_repair_model.gd")
const EconomyModel := preload("res://scripts/rules/economy_model.gd")

var _failures: Array[String] = []

# The buy catalog shape network_manager builds (item_key -> {cost, ...}); one priced armor + one unpriced.
const CATALOG := {
	"blast_vest": {"cost": 1200, "vendor_stocked": true, "name": "Blast Vest", "kind": "armor"},
	"faction_cuirass": {"cost": 0, "vendor_stocked": false, "name": "Issued Cuirass", "kind": "armor"},
}

# Mirror of submit_repair_armor: decide + apply the record/pip side effects (no arena/RPC/net). Returns
# {ok, reason, cost, credits, quality_pips}. `current_pips` is the LIVE equipped-armor pip (arena state
# in production). Faithfully reproduces the branch order + the _award_credits floor(>=0) debit, INCLUDING
# the v1 repair target = PRISTINE (NEW_QUALITY_PIPS = 0), matching network_manager.submit_repair_armor.
func _repair(item_key: String, current_pips: int, credits: int, equipped_armor: String) -> Dictionary:
	var key := item_key.strip_edges()
	if not CATALOG.has(key):
		return {"ok": false, "reason": "unknown_item", "credits": credits, "quality_pips": current_pips}
	if key == "" or key != equipped_armor:
		return {"ok": false, "reason": "not_equipped", "credits": credits, "quality_pips": current_pips}
	var list_cost := int((CATALOG[key] as Dictionary).get("cost", 0))
	if list_cost <= 0:
		return {"ok": false, "reason": "unpriced", "credits": credits, "quality_pips": current_pips}
	var target := int(Repair.NEW_QUALITY_PIPS)   # v1 = full rebuild to PRISTINE (0), NOT the +6 clamp bound
	var cost := Repair.repair_cost(current_pips, target, list_cost)
	if cost <= 0:
		return {"ok": true, "reason": "no_op", "cost": 0, "credits": credits, "quality_pips": current_pips}
	if credits < cost:
		return {"ok": false, "reason": "cannot_afford", "cost": cost, "credits": credits, "quality_pips": current_pips}
	var restored := Repair.restore(current_pips, target)
	var new_credits := maxi(credits - cost, 0)   # mirrors _award_credits(-cost) floored at 0
	return {"ok": true, "reason": "repaired", "cost": cost, "credits": new_credits, "quality_pips": restored}

func _init() -> void:
	var floor_pips := int(Repair.MIN_QUALITY_PIPS)     # -6 broken floor
	var pristine_pips := int(Repair.NEW_QUALITY_PIPS)  #  0 pristine ceiling (the real repair target)
	# A full floor->pristine rebuild spans the WHOLE degradable range (TOTAL_SPAN = 6), so it is priced at
	# exactly one economy buy-back (sell_price * REPAIR_FULL_SPAN_SINK 1.0), same as before the ceiling fix.
	var full_cost := Repair.repair_cost(floor_pips, pristine_pips, 1200)   # = sell_price(1200) = 480
	_assert_equal(full_cost, EconomyModel.sell_price(1200), "full rebuild is priced off the economy buy-back dial (sell_price)")

	# --- ANTI-SUPER-ARMOR guards (the repair-economy fix): the model NEVER lets pips exceed pristine (0),
	#     and NEVER charges to 'repair' undamaged gear, even if a caller asks for the +6 clamp bound. ---
	_assert_equal(Repair.restore(floor_pips, int(Repair.MAX_QUALITY_PIPS)), pristine_pips,
		"asking to restore a broken armor all the way to MAX (+6) still clamps to pristine (0) — no super-armor")
	_assert_equal(Repair.restore(pristine_pips, int(Repair.MAX_QUALITY_PIPS)), pristine_pips,
		"a pristine armor asked to go to +6 stays at 0 — pips never rise above pristine")
	_assert_equal(Repair.repair_cost(pristine_pips, int(Repair.MAX_QUALITY_PIPS), 1200), 0,
		"repairing pristine gear toward +6 costs 0 — undamaged armor is never charged")

	# --- AFFORDABLE repair of a BROKEN armor: debit exactly repair_cost, restore pips to PRISTINE (0) ---
	var out := _repair("blast_vest", floor_pips, 1000, "blast_vest")
	_assert_equal(bool(out["ok"]), true, "an affordable repair of a broken armor succeeds")
	_assert_equal(int(out["cost"]), full_cost, "the repair debits exactly repair_cost(floor, PRISTINE, list)")
	_assert_equal(int(out["credits"]), 1000 - full_cost, "credits drop by exactly the repair cost")
	_assert_equal(int(out["quality_pips"]), pristine_pips, "the armor's quality pips are restored to pristine (0), NEVER above")

	# --- UNAFFORDABLE repair: rejected, credits + pips untouched ---
	var poor := _repair("blast_vest", floor_pips, full_cost - 1, "blast_vest")
	_assert_equal(bool(poor["ok"]), false, "a repair costing more than the wallet is rejected")
	_assert_equal(String(poor["reason"]), "cannot_afford", "the rejection reason is cannot_afford")
	_assert_equal(int(poor["credits"]), full_cost - 1, "a rejected repair does NOT debit credits")
	_assert_equal(int(poor["quality_pips"]), floor_pips, "a rejected repair leaves the armor still broken")

	# --- exactly-affordable boundary: credits == cost repairs and lands the wallet at 0 ---
	var exact := _repair("blast_vest", floor_pips, full_cost, "blast_vest")
	_assert_equal(bool(exact["ok"]), true, "credits == cost is affordable (the gate is credits < cost)")
	_assert_equal(int(exact["credits"]), 0, "an exact-cost repair empties the wallet to 0 (never negative)")
	_assert_equal(int(exact["quality_pips"]), pristine_pips, "the exact-cost repair still restores to pristine (0)")

	# --- NO-OP when already PRISTINE: cost 0, no debit (undamaged gear is free to 'repair') ---
	var noop := _repair("blast_vest", pristine_pips, 1000, "blast_vest")
	_assert_equal(bool(noop["ok"]), true, "repairing an already-pristine armor is a benign no-op")
	_assert_equal(String(noop["reason"]), "no_op", "the no-op reason is surfaced")
	_assert_equal(int(noop["cost"]), 0, "an already-pristine armor costs 0 to 'repair'")
	_assert_equal(int(noop["credits"]), 1000, "a no-op repair does NOT debit credits")

	# --- a PARTIALLY degraded (not-yet-broken) armor still repairs to PRISTINE for a proportional fee ---
	var partial := _repair("blast_vest", -3, 1000, "blast_vest")
	var partial_cost := Repair.repair_cost(-3, pristine_pips, 1200)
	_assert_equal(int(partial["cost"]), partial_cost, "a partial repair costs proportionally to the pips restored")
	_assert_equal(int(partial["cost"]) < full_cost, true, "restoring fewer pips costs less than a full rebuild")
	_assert_equal(int(partial["quality_pips"]), pristine_pips, "a partial repair still tops the armor up to pristine (0)")

	# --- reject paths mirror buy/sell ---
	_assert_equal(String(_repair("faction_cuirass", floor_pips, 9999, "faction_cuirass")["reason"]), "unpriced",
		"unpriced (contraband/faction-issued, list 0) gear cannot be repaired")
	_assert_equal(String(_repair("nonexistent", floor_pips, 9999, "nonexistent")["reason"]), "unknown_item",
		"an item not in the catalog is rejected")
	_assert_equal(String(_repair("blast_vest", floor_pips, 9999, "some_other_armor")["reason"]), "not_equipped",
		"repair targets the EQUIPPED armor — a non-equipped key is rejected")

	if _failures.is_empty():
		print("armor_repair_wire_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
