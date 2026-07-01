extends RefCounted
## Pure death / respawn penalty (Wave F / DIV-0006, owner numbers 2026-07-01: "partial loss +
## insurance, credits kept"). All-static, NO RNG (the drop selection is DETERMINISTIC: sorted
## unequipped items, floor(n/2) dropped). The SERVER calls apply_death on the 'dead' transition,
## persists the returned sheet, writes the corpse manifest, and relocates the character to respawn.
## Lethality itself is gated upstream (DIV-0017: real damage only in lawless zones); this model is
## the consequence. Credits are NEVER lost. All numbers are tunable consts.

const DURABILITY_LOSS_ON_DEATH := 10   # equipped items lose 10% durability per uninsured death
const DURABILITY_LOSS_INSURED := 3     # ...reduced to 3% when a policy covers the death
const DROP_FRACTION_UNEQUIPPED := 0.5  # fraction of UNEQUIPPED inventory that drops (equipped never drops)
const INSURANCE_PREMIUM := 500         # cost of a policy (the vendor debits this; buy_insurance just grants)
const INSURANCE_CHARGES := 3           # covered deaths granted per policy purchase
const RESPAWN_WOUND_STATE := "wounded" # wound tier on respawn (sev 2) — not healthy, not still-dead
const DEFAULT_DURABILITY := 100        # an item with no tracked durability is assumed pristine

# insurance.charges > 0 -> the next death is covered (no drop, reduced durability loss)
static func is_covered(sheet: Dictionary) -> bool:
	return int((sheet.get("insurance", {}) as Dictionary).get("charges", 0)) > 0

# Current durability of the item in an equipment slot (default pristine).
static func item_durability(sheet: Dictionary, slot: String) -> int:
	return int((sheet.get("item_durability", {}) as Dictionary).get(slot, DEFAULT_DURABILITY))

# NON-mutating: subtract `amount` durability from every EQUIPPED slot (floored at 0). Returns a new sheet.
static func apply_durability_loss(sheet: Dictionary, amount: int) -> Dictionary:
	var next := sheet.duplicate(true)
	var dur: Dictionary = next.get("item_durability", {})
	for slot in (next.get("equipment", {}) as Dictionary):
		if String((next["equipment"] as Dictionary)[slot]) == "":
			continue
		var cur := int(dur.get(slot, DEFAULT_DURABILITY))
		dur[slot] = maxi(cur - amount, 0)
	next["item_durability"] = dur
	return next

# NON-mutating: grant INSURANCE_CHARGES covered deaths (the caller/vendor debits INSURANCE_PREMIUM
# and passes premium_paid=true). Returns {ok, reason, sheet}.
static func buy_insurance(sheet: Dictionary, premium_paid: bool) -> Dictionary:
	if not premium_paid:
		return {"ok": false, "reason": "unpaid", "sheet": sheet}
	var next := sheet.duplicate(true)
	var ins: Dictionary = next.get("insurance", {})
	ins["charges"] = int(ins.get("charges", 0)) + INSURANCE_CHARGES
	next["insurance"] = ins
	return {"ok": true, "reason": "", "sheet": next}

# The inventory items that may drop = one instance of each currently-equipped item is protected
# (so a spare of an equipped item CAN drop), everything else is droppable.
static func _droppable_unequipped(sheet: Dictionary) -> Array:
	var inv: Array = (sheet.get("inventory", []) as Array).duplicate()
	var protected: Dictionary = {}  # equipped item_key -> remaining protected instances
	for v in (sheet.get("equipment", {}) as Dictionary).values():
		var k := String(v)
		if k != "":
			protected[k] = int(protected.get(k, 0)) + 1
	var droppable: Array = []
	for item in inv:
		var k := String(item)
		if int(protected.get(k, 0)) > 0:
			protected[k] = int(protected[k]) - 1  # protect this equipped instance
		else:
			droppable.append(k)
	droppable.sort()
	return droppable

# The death consequence. Returns:
#   {sheet, corpse_manifest:{items:[...]}, insured:bool, durability_delta:int, dropped:Array}
# credits UNCHANGED; wound_state -> RESPAWN_WOUND_STATE. In a "secured" zone the death is penalty-free
# (instant restore: no drop, no durability loss). An insured death consumes a charge, drops nothing,
# and takes reduced durability loss.
static func apply_death(sheet: Dictionary, security_tier: String) -> Dictionary:
	var next := sheet.duplicate(true)
	next["wound_state"] = RESPAWN_WOUND_STATE  # credits deliberately untouched

	# Secured zones: penalty-free respawn (safety net; hostile PvE can't even reach here — DIV-0017).
	if security_tier == "secured":
		return {"sheet": next, "corpse_manifest": {"items": []}, "insured": false, "durability_delta": 0, "dropped": []}

	var covered := is_covered(next)
	var loss := DURABILITY_LOSS_INSURED if covered else DURABILITY_LOSS_ON_DEATH
	next = apply_durability_loss(next, loss)

	var dropped: Array = []
	if covered:
		# consume one insurance charge; no inventory drop.
		var ins: Dictionary = next.get("insurance", {})
		ins["charges"] = maxi(int(ins.get("charges", 0)) - 1, 0)
		next["insurance"] = ins
	else:
		var droppable := _droppable_unequipped(next)
		var drop_count := int(floor(float(droppable.size()) * DROP_FRACTION_UNEQUIPPED))
		for i in range(drop_count):
			dropped.append(droppable[i])
		# remove the dropped items (first matching occurrences) from inventory
		var inv: Array = (next.get("inventory", []) as Array).duplicate()
		for item in dropped:
			var idx := inv.find(item)
			if idx >= 0:
				inv.remove_at(idx)
		next["inventory"] = inv

	return {"sheet": next, "corpse_manifest": {"items": dropped}, "insured": covered, "durability_delta": loss, "dropped": dropped}
