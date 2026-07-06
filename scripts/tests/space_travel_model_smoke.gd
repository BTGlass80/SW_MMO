extends SceneTree
## Verifies the pure SpaceTravelModel logic

var _failures: Array[String] = []

func _init() -> void:
	var SpaceTravelModel = load("res://scripts/rules/space_travel_model.gd")
	var telemetry_log = []
	
	var player_sheet = {
		"inventory": [],
		"credits": 1000,
		"ships": ["yt1300"],
		"space_state": {}
	}
	
	# 1. LAUNCH
	var launch_res = SpaceTravelModel.launch_ship(player_sheet, "yt1300")
	if not _assert_equal(bool(launch_res.get("ok", false)), true, "Launch ship"): return
	player_sheet = launch_res["sheet"]
	
	var space_state = player_sheet["space_state"]
	if not _assert_equal(space_state["in_space"], true, "Player launched into space"): return
	if not _assert_equal(space_state["ship_id"], "yt1300", "Ship ID is correct"): return
	
	# 2. HARVEST (Salvage)
	var harvest_res = SpaceTravelModel.harvest_cargo(player_sheet, "starship_salvage", 12345)
	if not _assert_equal(bool(harvest_res.get("ok", false)), true, "Harvest salvage"): return
	player_sheet = harvest_res["sheet"]
	
	var cargo: Array = player_sheet["space_state"].get("ship_cargo", [])
	if not _assert_equal(cargo.size(), 1, "Cargo has 1 item after harvest"): return
	if not _assert_equal(String(cargo[0].get("template_id", "")), "starship_salvage", "Harvested correct item template"): return
	
	# 3. LAND
	var land_res = SpaceTravelModel.land_ship(player_sheet)
	if not _assert_equal(bool(land_res.get("ok", false)), true, "Land ship"): return
	player_sheet = land_res["sheet"]
	
	if not _assert_equal(player_sheet["space_state"]["in_space"], false, "Player landed safely"): return
	if not _assert_equal(player_sheet["space_state"]["ship_cargo"].size(), 0, "Cargo emptied after landing"): return
	
	var inventory: Array = player_sheet.get("inventory", [])
	if not _assert_equal(inventory.size(), 1, "Cargo transferred to inventory"): return
	if not _assert_equal(String(inventory[0].get("template_id", "")), "starship_salvage", "Inventory has salvaged item"): return
	
	var credits: int = player_sheet.get("credits", 0)
	if not _assert_equal(credits, 950, "Charged 50 credit docking fee (sink)"): return
	
	if _failures.is_empty():
		print("space_travel_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> bool:
	if str(actual) != str(expected):
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
		for failure in _failures:
			printerr(failure)
		quit(1)
		return false
	return true
