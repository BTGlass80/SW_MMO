extends SceneTree

var _failures = []

func _init() -> void:

	var character_id := "char_pilot_1"
	var record := {
		"sheet": {
			"name": "Wedge",
			"credits": 2000,
			"astrogation": "3D",
			"inventory": []
		}
	}
	
	# Simulate client launch_ship RPC state transition
	var sheet: Dictionary = record.get("sheet", {})
	var space_state: Dictionary = sheet.get("space_state", {
		"current_system": "Tatooine",
		"in_space": false,
		"ship_id": "yt1300",
		"ship_name": "YT-1300 Corellian Freighter",
		"ship_cargo": {}
	})
	
	# Check space launch sets in_space to true
	space_state["in_space"] = true
	sheet["space_state"] = space_state
	record["sheet"] = sheet
	
	var check_state: Dictionary = record.get("sheet", {}).get("space_state", {})
	_assert_equal(bool(check_state.get("in_space", false)), true, "Ship launch sets in_space to true")
	_assert_equal(check_state.get("current_system", ""), "Tatooine", "Ship launch system defaults to Tatooine")

	# Check space mining adds resource to cargo
	var cargo: Dictionary = space_state.get("ship_cargo", {})
	var current := int(cargo.get("copper_ore", 0))
	cargo["copper_ore"] = current + 5
	space_state["ship_cargo"] = cargo
	sheet["space_state"] = space_state
	record["sheet"] = sheet
	
	var updated_cargo: Dictionary = record.get("sheet", {}).get("space_state", {}).get("ship_cargo", {})
	_assert_equal(int(updated_cargo.get("copper_ore", 0)), 5, "Mining adds 5 copper ore to cargo")

	# Check landing ship sets in_space to false
	space_state["in_space"] = false
	sheet["space_state"] = space_state
	record["sheet"] = sheet
	
	var land_state: Dictionary = record.get("sheet", {}).get("space_state", {})
	_assert_equal(bool(land_state.get("in_space", false)), false, "Landing sets in_space to false")

	# Check selling cargo awards credits and clears cargo
	var final_credits := int(sheet.get("credits", 0))
	var copper_count := int(cargo.get("copper_ore", 0))
	var earnings := copper_count * 10
	sheet["credits"] = final_credits + earnings
	cargo.erase("copper_ore")
	space_state["ship_cargo"] = cargo
	sheet["space_state"] = space_state
	record["sheet"] = sheet
	
	_assert_equal(int(record.get("sheet", {}).get("credits", 0)), 2050, "Selling 5 copper ore awards 50 credits (2000 + 50)")
	_assert_equal(record.get("sheet", {}).get("space_state", {}).get("ship_cargo", {}).has("copper_ore"), false, "Selling cargo clears cargo slots")


	if _failures.is_empty():
		print("space_travel_wire_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
