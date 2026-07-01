extends SceneTree
## Smoke for the pure death penalty (Wave F / DIV-0006): credits kept, durability loss, the
## 50% unequipped drop (equipped protected), the insurance path (no-drop + reduced loss + charge
## decrement), penalty-free secured death, and non-mutation.

const DeathPenalty = preload("res://scripts/rules/death_penalty_model.gd")

var _failures: Array[String] = []

func _base_sheet() -> Dictionary:
	return {
		"credits": 1000,
		"wound_state": "dead",
		"equipment": {"weapon": "blaster_pistol", "armor": "blast_vest"},
		# inventory includes the two equipped items (protected) + 3 unequipped
		"inventory": ["blaster_pistol", "blast_vest", "hold_out_blaster", "blast_helmet", "knife"],
	}

func _init() -> void:
	# --- UNINSURED death in a lawless zone: credits kept, 10% durability, 50% unequipped drop ---
	var sheet := _base_sheet()
	var res: Dictionary = DeathPenalty.apply_death(sheet, "lawless")
	var out: Dictionary = res["sheet"]
	_assert_equal(int(out["credits"]), 1000, "credits are KEPT on death")
	_assert_equal(String(out["wound_state"]), "wounded", "respawn wound_state is 'wounded'")
	_assert_equal(DeathPenalty.item_durability(out, "weapon"), 90, "equipped weapon loses 10% durability")
	_assert_equal(DeathPenalty.item_durability(out, "armor"), 90, "equipped armor loses 10% durability")
	_assert_equal(int(res["durability_delta"]), 10, "uninsured durability delta is 10")
	_assert_equal(bool(res["insured"]), false, "uninsured death")
	# droppable unequipped sorted = [blast_helmet, hold_out_blaster, knife]; floor(3*0.5)=1 -> [blast_helmet]
	var dropped: Array = res["dropped"]
	_assert_equal(dropped.size(), 1, "50% of 3 unequipped -> 1 dropped")
	_assert_equal(String(dropped[0]), "blast_helmet", "the sorted-first droppable item drops")
	_assert_true(not (out["inventory"] as Array).has("blast_helmet"), "dropped item left the inventory")
	_assert_true((out["inventory"] as Array).has("blaster_pistol"), "equipped weapon is kept in inventory")
	_assert_true((out["inventory"] as Array).has("blast_vest"), "equipped armor is kept in inventory")
	_assert_equal((res["corpse_manifest"] as Dictionary)["items"], dropped, "corpse manifest = dropped items")

	# --- original sheet is NOT mutated ---
	_assert_equal((sheet["inventory"] as Array).size(), 5, "original inventory not mutated")
	_assert_equal(String(sheet["wound_state"]), "dead", "original wound_state not mutated")

	# --- INSURED death: no drop, 3% durability, one charge consumed ---
	var insured_sheet: Dictionary = DeathPenalty.buy_insurance(_base_sheet(), true)["sheet"]
	_assert_equal(int((insured_sheet["insurance"] as Dictionary)["charges"]), 3, "policy grants 3 charges")
	_assert_true(DeathPenalty.is_covered(insured_sheet), "an insured sheet is covered")
	var ires: Dictionary = DeathPenalty.apply_death(insured_sheet, "lawless")
	var iout: Dictionary = ires["sheet"]
	_assert_equal(bool(ires["insured"]), true, "insured death is covered")
	_assert_equal(int(ires["durability_delta"]), 3, "insured durability delta is 3")
	_assert_equal(DeathPenalty.item_durability(iout, "weapon"), 97, "insured weapon loses only 3%")
	_assert_equal((ires["dropped"] as Array).size(), 0, "insured death drops nothing")
	_assert_equal((iout["inventory"] as Array).size(), 5, "insured inventory intact")
	_assert_equal(int((iout["insurance"] as Dictionary)["charges"]), 2, "insured death consumes one charge")
	_assert_equal(int(iout["credits"]), 1000, "insured death keeps credits")

	# --- SECURED death: penalty-free (instant restore) ---
	var sres: Dictionary = DeathPenalty.apply_death(_base_sheet(), "secured")
	var sout: Dictionary = sres["sheet"]
	_assert_equal(String(sout["wound_state"]), "wounded", "secured death still respawns wounded")
	_assert_equal(DeathPenalty.item_durability(sout, "weapon"), 100, "secured death: no durability loss")
	_assert_equal((sres["dropped"] as Array).size(), 0, "secured death drops nothing")
	_assert_equal((sout["inventory"] as Array).size(), 5, "secured inventory intact")

	# --- a SPARE of an equipped item CAN drop (only one equipped instance is protected) ---
	var spare_sheet := {"credits": 100, "equipment": {"weapon": "blaster_pistol"},
		"inventory": ["blaster_pistol", "blaster_pistol", "knife", "vibroblade"]}
	var spres: Dictionary = DeathPenalty.apply_death(spare_sheet, "lawless")
	# droppable = [blaster_pistol(spare), knife, vibroblade] sorted -> [blaster_pistol, knife, vibroblade]; floor(3*0.5)=1
	_assert_equal((spres["dropped"] as Array).size(), 1, "1 of 3 droppable (incl. the spare) drops")
	_assert_equal(String((spres["dropped"] as Array)[0]), "blaster_pistol", "the spare (sorted-first) drops, not the equipped one")
	_assert_true(((spres["sheet"] as Dictionary)["inventory"] as Array).has("blaster_pistol"), "the EQUIPPED instance is still owned")

	# --- buy_insurance requires payment; apply_durability_loss floors at 0 ---
	_assert_equal(bool(DeathPenalty.buy_insurance(_base_sheet(), false)["ok"]), false, "unpaid insurance rejected")
	var worn := {"equipment": {"weapon": "x"}, "item_durability": {"weapon": 5}}
	var worn_after: Dictionary = DeathPenalty.apply_durability_loss(worn, 10)
	_assert_equal(DeathPenalty.item_durability(worn_after, "weapon"), 0, "durability floors at 0")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("death_penalty_model_smoke: OK")
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
