extends SceneTree

var _failures = []

func _init() -> void:
	var craft_model_script := load("res://scripts/rules/crafting_model.gd")
	var craft_model = craft_model_script.new()
	
	var rules_script := load("res://scripts/rules/d6_rules.gd")
	var rules = rules_script.new()
	
	var sheet = {
		"search": "6D",
		"inventory": []
	}
	var current_time = 1000000
	
	# Test 1: roll survey in Tatooine Mos Eisley approach
	var survey1 = craft_model.roll_survey(sheet, rules, "tatooine.mos_eisley.approach", 999, current_time)
	_assert_equal(bool(survey1.get("ok", false)), true, "Survey succeeds in approach zone")
	_assert_equal(survey1.has("type"), true, "Survey returns resource type key")
	_assert_equal(survey1.has("deposit_id"), true, "Survey returns temporary deposit id")
	_assert_equal(int(survey1.get("quality", 0)) >= 40, true, "Resource quality >= 40%")
	_assert_equal(int(survey1.get("density", 0)) >= 20, true, "Resource density >= 20%")
	
	# Test 2: Determinism check (same zone and seed must return exact same resource type and quality)
	var survey2 = craft_model.roll_survey(sheet, rules, "tatooine.mos_eisley.approach", 999, current_time)
	_assert_equal(survey1.get("type", ""), survey2.get("type", ""), "Deterministic resource type")
	_assert_equal(survey1.get("quality", 0), survey2.get("quality", 0), "Deterministic quality percentage")
	_assert_equal(survey1.get("density", 0), survey2.get("density", 0), "Deterministic density percentage")
	
	# Test 3: Harvest deposit checks
	var harvest_outcome = craft_model.harvest_resource(sheet, rules, survey1, 999, current_time)
	_assert_equal(bool(harvest_outcome.get("ok", false)), true, "Resource harvesting succeeds")
	_assert_equal(int(harvest_outcome.get("count", 0)) > 0, true, "Harvest returns > 0 units")
	
	var new_sheet: Dictionary = harvest_outcome.get("sheet", {})
	var r_type: String = survey1.get("type", "")
	var inventory: Array = new_sheet.get("inventory", [])
	
	var stored_res: Dictionary = {}
	for item in inventory:
		if item.get("template_id", "") == "resource_stack" and item.get("stats", {}).get("resource_type", "") == r_type:
			stored_res = item
			break
			
	_assert_equal(int(stored_res.get("stack_count", 0)) > 0, true, "Sheet inventory resource count > 0")
	_assert_equal(float(stored_res.get("quality", 0.0)), float(survey1.get("quality", 0.0)), "Resource quality stored in inventory matches survey quality")
	
	# Test 4: Expired deposit fails
	var expired_harvest = craft_model.harvest_resource(sheet, rules, survey1, 999, current_time + 400)
	_assert_equal(bool(expired_harvest.get("ok", false)), false, "Expired deposit harvest fails")
	_assert_equal(expired_harvest.get("reason", ""), "deposit_expired", "Reason is deposit_expired")
	
	rules.free()

	if _failures.is_empty():
		print("survey_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
