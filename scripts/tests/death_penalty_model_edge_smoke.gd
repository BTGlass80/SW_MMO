extends SceneTree
## HARDENING smoke for the pure death-penalty model (scripts/rules/death_penalty_model.gd).
## Adversarial edge-case coverage beyond death_penalty_model_smoke.gd: the floor(n*0.5) drop-count
## boundary at n=0 and n=1 (both must drop NOTHING), "contested" penalized exactly like "lawless"
## (only "secured" is a safety net), the full insurance-charge depletion cycle (N covered deaths then
## an uninsured one), stacked insurance purchases accumulating rather than resetting, and default
## durability for a never-tracked slot. Deterministic, no RNG.

const DeathPenalty = preload("res://scripts/rules/death_penalty_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	_test_drop_count_floor_boundaries()
	_test_contested_penalized_like_lawless()
	_test_insurance_charge_depletion_cycle()
	_test_stacked_insurance_purchases_accumulate()
	_test_default_durability_and_empty_equipment()
	_test_buy_insurance_non_mutating()
	_finish()

func _test_drop_count_floor_boundaries() -> void:
	# 1 droppable unequipped item: floor(1 * 0.5) = 0 -> NOTHING drops (a lone spare is safe).
	var one_item := {"credits": 100, "equipment": {}, "inventory": ["knife"]}
	var r1: Dictionary = DeathPenalty.apply_death(one_item, "lawless")
	_assert_equal((r1["dropped"] as Array).size(), 0, "floor(1*0.5)=0: a single droppable item never drops")
	_assert_equal(((r1["sheet"] as Dictionary)["inventory"] as Array).size(), 1, "the lone item survives in inventory")

	# 0 items at all: no crash, nothing drops.
	var empty_inv := {"credits": 100, "equipment": {}, "inventory": []}
	var r0: Dictionary = DeathPenalty.apply_death(empty_inv, "lawless")
	_assert_equal((r0["dropped"] as Array).size(), 0, "an empty inventory drops nothing and does not crash")
	_assert_equal((r0["corpse_manifest"] as Dictionary)["items"], [], "corpse manifest is empty for an empty inventory")

	# 2 droppable items: floor(2*0.5)=1 -> exactly one drops.
	var two_items := {"credits": 100, "equipment": {}, "inventory": ["blast_helmet", "knife"]}
	var r2: Dictionary = DeathPenalty.apply_death(two_items, "lawless")
	_assert_equal((r2["dropped"] as Array).size(), 1, "floor(2*0.5)=1: exactly one of two droppable items drops")

	# No "equipment" key at all (degenerate sheet) does not crash apply_death.
	var no_equipment := {"credits": 50, "inventory": ["knife"]}
	var rne: Dictionary = DeathPenalty.apply_death(no_equipment, "lawless")
	_assert_equal(bool(rne["insured"]), false, "a sheet with no equipment key still resolves a normal uninsured death")

func _test_contested_penalized_like_lawless() -> void:
	var sheet := {"credits": 500, "equipment": {"weapon": "blaster_pistol"},
		"inventory": ["blaster_pistol", "blast_helmet", "knife"]}
	var res: Dictionary = DeathPenalty.apply_death(sheet, "contested")
	_assert_equal(int(res["durability_delta"]), DeathPenalty.DURABILITY_LOSS_ON_DEATH, "contested applies the same durability loss as lawless")
	# droppable = [blast_helmet, knife] sorted; floor(2*0.5)=1 -> [blast_helmet] drops.
	_assert_equal((res["dropped"] as Array).size(), 1, "contested drops the same fraction as lawless (only secured is penalty-free)")
	_assert_equal(int(res["durability_delta"]), 10, "contested equipped-item durability loss is 10% (uninsured)")

func _test_insurance_charge_depletion_cycle() -> void:
	var sheet: Dictionary = DeathPenalty.buy_insurance({"credits": 100, "equipment": {"weapon": "x"}, "inventory": ["x", "spare1", "spare2"]}, true)["sheet"]
	_assert_equal(int((sheet["insurance"] as Dictionary)["charges"]), DeathPenalty.INSURANCE_CHARGES, "one policy grants exactly INSURANCE_CHARGES charges")

	# Die INSURANCE_CHARGES times: every one of them must be covered, and no drop each time.
	var cur := sheet
	for i in range(DeathPenalty.INSURANCE_CHARGES):
		var res: Dictionary = DeathPenalty.apply_death(cur, "lawless")
		_assert_true(bool(res["insured"]), "death #%d is covered by the policy" % (i + 1))
		_assert_equal((res["dropped"] as Array).size(), 0, "death #%d drops nothing while covered" % (i + 1))
		cur = res["sheet"]
	_assert_equal(int((cur["insurance"] as Dictionary)["charges"]), 0, "all charges consumed after INSURANCE_CHARGES covered deaths")

	# The NEXT death (charges now 0) is fully uninsured.
	var uninsured_res: Dictionary = DeathPenalty.apply_death(cur, "lawless")
	_assert_equal(bool(uninsured_res["insured"]), false, "the death AFTER the last charge is depleted is uninsured")
	_assert_equal(int(uninsured_res["durability_delta"]), DeathPenalty.DURABILITY_LOSS_ON_DEATH, "the depleted-charge death takes the full (uninsured) durability loss")
	# charges never go negative.
	_assert_equal(int(((uninsured_res["sheet"] as Dictionary)["insurance"] as Dictionary)["charges"]), 0, "insurance charges floor at 0, never negative")

func _test_stacked_insurance_purchases_accumulate() -> void:
	var sheet := {"credits": 2000, "equipment": {}, "inventory": []}
	var once: Dictionary = DeathPenalty.buy_insurance(sheet, true)["sheet"]
	var twice: Dictionary = DeathPenalty.buy_insurance(once, true)["sheet"]
	_assert_equal(int((twice["insurance"] as Dictionary)["charges"]), DeathPenalty.INSURANCE_CHARGES * 2, "a second policy purchase ADDS to the remaining charges, not resets them")

func _test_default_durability_and_empty_equipment() -> void:
	var bare := {}
	_assert_equal(DeathPenalty.item_durability(bare, "weapon"), DeathPenalty.DEFAULT_DURABILITY, "an untracked slot on a bare sheet defaults to pristine durability")
	_assert_equal(DeathPenalty.is_covered(bare), false, "a bare sheet with no insurance block is uncovered")
	# apply_durability_loss on a sheet with equipment but no item_durability block at all: initializes cleanly.
	var fresh_equipped := {"equipment": {"weapon": "blaster_pistol"}}
	var after: Dictionary = DeathPenalty.apply_durability_loss(fresh_equipped, 15)
	_assert_equal(DeathPenalty.item_durability(after, "weapon"), 85, "durability loss from an untracked (pristine-default) slot subtracts correctly")

func _test_buy_insurance_non_mutating() -> void:
	var sheet := {"credits": 500, "equipment": {}, "inventory": []}
	var snapshot := sheet.duplicate(true)
	var _r := DeathPenalty.buy_insurance(sheet, true)
	_assert_equal(sheet, snapshot, "buy_insurance does not mutate its input sheet")
	var _r2 := DeathPenalty.apply_death(sheet, "lawless")
	_assert_equal(sheet, snapshot, "apply_death does not mutate its input sheet (second check, insurance-free sheet)")

func _finish() -> void:
	if _failures.is_empty():
		print("death_penalty_model_edge_smoke: OK")
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
