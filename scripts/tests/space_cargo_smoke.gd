extends SceneTree
## Server-Owned Space Cargo Loop Proof (RWD Priority 6)
## Mirrors network_manager.gd JSON handling for submit_launch_ship, submit_space_harvest, and submit_land_ship.

var _failures: Array[String] = []

# Mirrors network_manager.gd submit_launch_ship
func _submit_launch_ship(record: Dictionary, ship_id: String) -> Dictionary:
	var sheet: Dictionary = record.get("sheet", {})
	var owned_ships: Array = sheet.get("ships", [])
	
	var selected_ship_id := ship_id
	if selected_ship_id == "" or not owned_ships.has(selected_ship_id):
		return {"ok": false, "reason": "does_not_own_ship"}
		
	var space_state: Dictionary = sheet.get("space_state", {})
	if space_state.is_empty():
		space_state = {
			"current_system": "Tatooine",
			"in_space": false,
			"ship_id": selected_ship_id,
			"ship_name": selected_ship_id.capitalize(),
			"ship_cargo": []
		}
	else:
		space_state["ship_id"] = selected_ship_id
		
	space_state["in_space"] = true
	sheet["space_state"] = space_state
	record["sheet"] = sheet
	
	return {"ok": true, "record": record, "space_state": space_state}

# Mirrors network_manager.gd submit_space_harvest
func _submit_space_harvest(record: Dictionary, target_key: String, rng_seed: int, telemetry_log: Array) -> Dictionary:
	var sheet: Dictionary = record.get("sheet", {})
	var space_state: Dictionary = sheet.get("space_state", {})
	if space_state.is_empty() or not bool(space_state.get("in_space", false)):
		return {"ok": false, "reason": "not_in_space"}
		
	var cargo: Array = space_state.get("ship_cargo", [])
	var harvest_key := target_key
	if harvest_key == "":
		harvest_key = "starship_salvage"
		
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var item_instance := {
		"instance_id": str(rng.randi()),
		"template_id": harvest_key,
		"quantity": 1
	}
	cargo.append(item_instance)
	space_state["ship_cargo"] = cargo
	sheet["space_state"] = space_state
	record["sheet"] = sheet
	
	telemetry_log.append({
		"event": "faucet_harvest", 
		"item_template": harvest_key,
		"context": "space_harvest"
	})
	
	return {"ok": true, "record": record, "harvested": item_instance}

# Mirrors network_manager.gd submit_land_ship
func _submit_land_ship(record: Dictionary, telemetry_log: Array) -> Dictionary:
	var sheet: Dictionary = record.get("sheet", {})
	var docking_fee := 50
	var credits := int(sheet.get("credits", 0))
	if credits < docking_fee:
		return {"ok": false, "reason": "insufficient_credits"}
		
	var space_state: Dictionary = sheet.get("space_state", {})
	if space_state.is_empty() or not bool(space_state.get("in_space", false)):
		return {"ok": false, "reason": "not_in_space"}
		
	space_state["in_space"] = false
	
	var inventory: Array = sheet.get("inventory", [])
	var cargo: Array = space_state.get("ship_cargo", [])
	for item in cargo:
		inventory.append(item)
	space_state["ship_cargo"] = []
	sheet["inventory"] = inventory
	sheet["credits"] = credits - docking_fee
	sheet["space_state"] = space_state
	record["sheet"] = sheet
	
	telemetry_log.append({
		"event": "sink_fee",
		"fee_type": "docking",
		"amount": docking_fee,
		"remaining_credits": sheet["credits"]
	})
	
	return {"ok": true, "record": record, "transferred_cargo_count": cargo.size()}

func _init() -> void:
	var telemetry_log = []
	
	var player_record = {
		"id": "pilot_1",
		"sheet": {
			"inventory": [],
			"credits": 1000,
			"ships": ["yt1300"],
			"space_state": {}
		}
	}
	
	# 1. LAUNCH
	var launch_res = _submit_launch_ship(player_record, "yt1300")
	if not _assert_equal(bool(launch_res.get("ok", false)), true, "Launch ship"): return
	player_record = launch_res["record"]
	
	var space_state = player_record["sheet"]["space_state"]
	if not _assert_equal(space_state["in_space"], true, "Player launched into space"): return
	if not _assert_equal(space_state["ship_id"], "yt1300", "Ship ID is correct"): return
	
	# 2. HARVEST (Salvage)
	var harvest_res = _submit_space_harvest(player_record, "starship_salvage", 12345, telemetry_log)
	if not _assert_equal(bool(harvest_res.get("ok", false)), true, "Harvest salvage"): return
	player_record = harvest_res["record"]
	
	var cargo: Array = player_record["sheet"]["space_state"].get("ship_cargo", [])
	if not _assert_equal(cargo.size(), 1, "Cargo has 1 item after harvest"): return
	if not _assert_equal(String(cargo[0].get("template_id", "")), "starship_salvage", "Harvested correct item template"): return
	
	# 3. LAND
	var land_res = _submit_land_ship(player_record, telemetry_log)
	if not _assert_equal(bool(land_res.get("ok", false)), true, "Land ship"): return
	player_record = land_res["record"]
	
	if not _assert_equal(player_record["sheet"]["space_state"]["in_space"], false, "Player landed safely"): return
	if not _assert_equal(player_record["sheet"]["space_state"]["ship_cargo"].size(), 0, "Cargo emptied after landing"): return
	
	var inventory: Array = player_record["sheet"].get("inventory", [])
	if not _assert_equal(inventory.size(), 1, "Cargo transferred to inventory"): return
	if not _assert_equal(String(inventory[0].get("template_id", "")), "starship_salvage", "Inventory has salvaged item"): return
	
	var credits: int = player_record["sheet"].get("credits", 0)
	if not _assert_equal(credits, 950, "Charged 50 credit docking fee (sink)"): return
	
	# Verify telemetry logged faucet and sink
	var events = []
	for evt in telemetry_log:
		events.append(evt["event"])
	if not _assert_true(events.has("faucet_harvest"), "telemetry logged faucet_harvest"): return
	if not _assert_true(events.has("sink_fee"), "telemetry logged sink_fee"): return
	
	if _failures.is_empty():
		print("space_cargo_smoke: OK")
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

func _assert_true(actual: bool, label: String) -> bool:
	if not actual:
		_failures.append("%s: expected true, got false" % label)
		for failure in _failures:
			printerr(failure)
		quit(1)
		return false
	return true
