extends SceneTree

var _failures = []

func _init() -> void:

	var SpaceTravelModel = load("res://scripts/rules/space_travel_model.gd")
	var character_id := "char_pilot_1"
	var record := {
		"sheet": {
			"name": "Wedge",
			"credits": 2000,
			"astrogation": "3D",
			"inventory": [],
			"ships": ["yt1300"],
			"space_state": {
				"current_system": "Tatooine",
				"in_space": false,
				"ship_id": "yt1300",
				"ship_name": "YT-1300 Corellian Freighter",
				"ship_cargo": []
			}
		}
	}
	
	# Simulate client launch_ship RPC state transition
	var launch_res = SpaceTravelModel.launch_ship(record["sheet"], "yt1300")
	record["sheet"] = launch_res["sheet"]
	
	var check_state: Dictionary = record.get("sheet", {}).get("space_state", {})
	_assert_equal(bool(check_state.get("in_space", false)), true, "Ship launch sets in_space to true")
	_assert_equal(check_state.get("current_system", ""), "Tatooine", "Ship launch system defaults to Tatooine")

	# Check space mining adds resource to cargo
	var harvest_res = SpaceTravelModel.harvest_cargo(record["sheet"], "copper_ore", 123)
	record["sheet"] = harvest_res["sheet"]
	
	var updated_cargo: Array = record.get("sheet", {}).get("space_state", {}).get("ship_cargo", [])
	_assert_equal(updated_cargo.size(), 1, "Mining adds 1 copper ore to cargo")
	_assert_equal(String(updated_cargo[0]["template_id"]), "copper_ore", "Mining adds copper_ore")

	# Check landing ship sets in_space to false and moves cargo to inventory
	var land_res = SpaceTravelModel.land_ship(record["sheet"])
	record["sheet"] = land_res["sheet"]
	
	var land_state: Dictionary = record.get("sheet", {}).get("space_state", {})
	_assert_equal(bool(land_state.get("in_space", false)), false, "Landing sets in_space to false")

	# Check selling cargo - Note this just checks that they have it in inventory to sell.
	# The actual economy sell is handled by EconomyModel, so we just verify the cargo got into the inventory.
	var final_inventory = record.get("sheet", {}).get("inventory", [])
	_assert_equal(final_inventory.size(), 1, "Landing moved cargo to inventory")
	_assert_equal(record.get("sheet", {}).get("space_state", {}).get("ship_cargo", []).size(), 0, "Landing cleared ship cargo")


	if _failures.is_empty():
		print("space_travel_wire_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual, expected, label: String) -> void:
	if str(actual) != str(expected):
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
