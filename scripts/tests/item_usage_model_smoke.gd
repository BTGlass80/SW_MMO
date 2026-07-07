extends SceneTree

var _failures = []

func _init() -> void:
	var usage_model_script := load("res://scripts/rules/item_usage_model.gd")
	var usage_model = usage_model_script.new()
	var rules_script := load("res://scripts/rules/d6_rules.gd")
	var rules = rules_script.new()
	
	var sheet = {
		"first_aid": "10D",
		"technical": "4D",
		"starship_repair": "4D"
	}
	
	var medpac = {
		"template_key": "medpac",
		"quality": 80.0,
		"condition": 2,
		"max_condition": 5
	}
	
	var target = {
		"wounds": 2,
		"wound_state": "wounded_twice",
		"ammo": {"packs": 10},
		"hull": 50
	}
	
	# Test 1: Medpac heals wound on success
	var seed_val = 12345
	var medpac_result = usage_model.use_item(sheet, rules, target, medpac, seed_val)
	
	_assert_equal(bool(medpac_result.get("ok", false)), true, "Medpac heals target on success")
	_assert_equal(int(medpac_result.get("target_state", {}).get("wounds", 2)), 1, "Target wounds reduced from 2 to 1")
	_assert_equal(String(medpac_result.get("target_state", {}).get("wound_state", "")), "wounded", "Target wound_state reduced from wounded_twice to wounded")
	_assert_equal(int(medpac_result.get("item", {}).get("condition", 0)), 1, "Medpac condition reduced from 2 to 1")
	_assert_equal(bool(medpac_result.get("consumed", true)), false, "Medpac not consumed because condition > 0")
	
	# Test 2: Power pack adds ammo
	var power_pack = {
		"template_key": "power_pack",
		"quality": 100.0,
		"stats": {"shots": 20}
	}
	
	var power_pack_result = usage_model.use_item(sheet, rules, target, power_pack, seed_val)
	_assert_equal(bool(power_pack_result.get("ok", false)), true, "Power pack adds ammo")
	_assert_equal(int(power_pack_result.get("ammo_added", 0)), 30, "Power pack returns added shots (20 * 1.5)")
	_assert_equal(bool(power_pack_result.get("consumed", false)), true, "Power pack consumed")
	
	# Test 3: Ship repair patch repairs hull
	var repair_patch = {
		"template_key": "ship_repair_patch",
		"quality": 90.0,
		"stats": {"repairs_hull": 20}
	}
	var patch_result = usage_model.use_item(sheet, rules, target, repair_patch, seed_val)
	_assert_equal(bool(patch_result.get("ok", false)), true, "Repair patch succeeds")
	var new_hull = int(patch_result.get("target_state", {}).get("hull", 0))
	_assert_equal(new_hull > 50, true, "Ship hull repaired")
	_assert_equal(bool(patch_result.get("consumed", false)), true, "Repair patch consumed")

	rules.free()
	if _failures.is_empty():
		print("item_usage_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
