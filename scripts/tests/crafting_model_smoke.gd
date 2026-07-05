extends SceneTree

var _failures = []

func _init() -> void:
	var rules_script := load("res://scripts/rules/d6_rules.gd")
	var rules = rules_script.new()
	var craft_model_script := load("res://scripts/rules/crafting_model.gd")
	var craft_model = craft_model_script.new()
	
	# Verify JSON resources catalog loads correctly
	var resources = craft_model.get_resources("res://data/resources_clone_wars.json")
	_assert_equal(resources.size() > 0, true, "Resources catalog size > 0")
	
	var schematics = craft_model.get_schematics("res://data/schematics_clone_wars.json")
	_assert_equal(schematics.size() > 0, true, "Schematics catalog size > 0")

	# Test mock character sheet
	var sheet = {
		"name": "Test Crafter",
		"technical": "4D", # high technical skill for crafting checks
		"first_aid": "2D",
		"credits": 1000,
		"resources": {},
		"inventory": [
			{
				"template_id": "resource_stack",
				"stats": {"resource_type": "organic_tissue"},
				"stack_count": 10,
				"quality": 85.0
			},
			{
				"template_id": "resource_stack",
				"stats": {"resource_type": "medical_biogel"},
				"stack_count": 5,
				"quality": 75.0
			}
		]
	}

	# Test 1: Unknown schematic key fails
	var bad_craft = craft_model.craft_item(sheet, "hyperdrive_hyper_core", rules, 12345, "crafter_1")
	_assert_equal(bool(bad_craft.get("ok", false)), false, "Crafting unknown schematic key fails")
	_assert_equal(bad_craft.get("reason", ""), "unknown_schematic", "Fails with unknown_schematic reason")

	# Test 2: Insufficient resources fails
	var no_res_craft = craft_model.craft_item(sheet, "ship_patch_kit", rules, 12345, "crafter_1")
	_assert_equal(bool(no_res_craft.get("ok", false)), false, "Crafting with insufficient ingredients fails")
	print("DEBUG REASON: ", no_res_craft.get("reason", ""))
	_assert_equal(no_res_craft.get("reason", "").begins_with("insufficient_"), true, "Fails with insufficient resource reason")

	# Test 3: Successful basic medpac craft (requires 2 organic_tissue, 1 medical_biogel)
	var seed_val := 42 # deterministic seed for successful test
	var craft_success = craft_model.craft_item(sheet, "basic_medpac", rules, seed_val, "crafter_1")
	
	# If roll fails, we'll try another seed until we hit success or force technical attribute to a high value
	if not bool(craft_success.get("ok", false)):
		# Try with an extremely high technical pool to ensure success
		var high_sheet = sheet.duplicate(true)
		high_sheet["first_aid"] = "10D"
		craft_success = craft_model.craft_item(high_sheet, "basic_medpac", rules, seed_val, "crafter_1")
		
	_assert_equal(bool(craft_success.get("ok", false)), true, "Crafting medpac succeeds with high rolls")
	
	var out_sheet: Dictionary = craft_success.get("sheet", {})
	# Verify resources consumed: 10 organic_tissue - 2 = 8, 5 medical_biogel - 1 = 4
	var ah_qty = 0
	var ss_qty = 0
	var new_items = 0
	var crafted_item_id = ""
	for i_item in out_sheet.get("inventory", []):
		if i_item.get("template_id", "") == "resource_stack":
			if i_item.get("stats", {}).get("resource_type", "") == "organic_tissue":
				ah_qty += int(i_item.get("stack_count", 0))
			elif i_item.get("stats", {}).get("resource_type", "") == "medical_biogel":
				ss_qty += int(i_item.get("stack_count", 0))
		else:
			new_items += 1
			crafted_item_id = i_item.get("instance_id", "")
			
	_assert_equal(ah_qty, 8, "Organic tissue consumed")
	_assert_equal(ss_qty, 4, "Medical biogel consumed")
	
	# Verify item instance properties
	var item: Dictionary = craft_success.get("item", {})
	_assert_equal(item.get("template_id", ""), "medpac", "Item template id is medpac")
	_assert_equal(item.get("kind", ""), "medical", "Item kind is medical")
	_assert_equal(int(item.get("max_condition", 0)) > 0, true, "Medpac max condition is > 0")
	_assert_equal(item.get("created_by", ""), "crafter_1", "Crafter ID is stamped")
	_assert_equal(int(item.get("quality", 0)) > 0, true, "Item has a non-zero quality percentage")
	
	# Verify it was added to inventory array
	_assert_equal(new_items, 1, "One crafted item added to inventory")
	_assert_equal(crafted_item_id, item.get("instance_id", ""), "Inventory item ID matches created item ID")

	rules.free()
	if _failures.is_empty():
		print("crafting_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
