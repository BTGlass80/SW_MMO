extends SceneTree

const SpaceStationStripModel = preload("res://scripts/rules/space_station_strip_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var ship := {
		"crew": [
			{"id": "local_pilot", "name": "Local Pilot", "station": "pilot"},
			{"id": "local_copilot", "name": "Local Copilot", "station": "copilot"},
			{"id": "local_gunner", "name": "Local Gunner", "station": "gunner"},
			{"id": "local_engineer", "name": "Local Engineer", "station": "engineer"},
			{"id": "local_navigator", "name": "Local Navigator", "station": "navigator"},
			{"id": "local_commander", "name": "Local Commander", "station": "commander"},
			{"id": "local_comms", "name": "Local Comms", "station": "communications"},
		],
		"condition": {
			"crew_wounds": {
				"local_pilot": {"wound": {"name": "Wounded", "severity": 2}, "severity": 2},
				"local_gunner": {"station": "gunner", "wound": {"severity": 3}, "severity": 3},
				"local_engineer": {"wound": {"name": "Stunned", "severity": 0}, "severity": 0},
			}
		}
	}
	var state := {
		"station_assists": {
			"sensors": {"name": "Tactical coordination", "station": "commander", "target_action": "sensors", "requested_target_action": "targeting_solution", "pool": "1D", "banked_round": 3},
			"gunnery": {"name": "Gunner bracketing", "station": "gunner", "target_action": "gunnery", "pool": "1D", "banked_round": 4},
			"communications": {"name": "Traffic phrasebook", "station": "comms", "target_action": "communications", "pool": "1D"},
		}
	}
	var rows := SpaceStationStripModel.station_rows(ship, state)
	_assert_equal(rows.size(), 8, "default bridge station count")
	_assert_equal(rows[0]["crew_name"], "Local Pilot", "pilot crew name")
	_assert_equal(rows[0]["wound_text"], "Wounded", "pilot crew-id wound fallback")
	_assert_equal(rows[2]["label"], "Sensors", "sensor station label")
	_assert_equal(rows[2]["crew_name"], "Unassigned", "missing sensor crew is explicit")
	_assert_equal(rows[3]["label"], "Commander", "commander station label")
	_assert_equal(rows[3]["crew_name"], "Local Commander", "commander crew name")
	_assert_equal(rows[3]["assist_text"], "Tactical coordination 1D -> sensors (targeting solution) since station 3", "commander banked assist preserves requested alias and station round")
	_assert_equal(rows[4]["assist_text"], "Gunner bracketing 1D -> gunnery since station 4", "gunner banked assist includes station round")
	_assert_equal(rows[4]["wound_text"], "Incapacitated", "gunner station wound severity fallback")
	_assert_equal(rows[5]["wound_text"], "", "stun-only crew wound stays quiet")
	_assert_equal(rows[7]["assist_text"], "Traffic phrasebook 1D -> communications", "comms alias banked assist")
	_assert_equal(SpaceStationStripModel.station_line(rows[0]), "Pilot: Local Pilot [Wounded] | ready", "wounded station line")
	_assert_equal(SpaceStationStripModel.station_line(rows[3]), "Commander: Local Commander | Tactical coordination 1D -> sensors (targeting solution) since station 3", "commander assisted station line")
	_assert_equal(SpaceStationStripModel.station_line(rows[4]), "Gunner: Local Gunner [Incapacitated] | Gunner bracketing 1D -> gunnery since station 4", "assisted wounded station line")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("space_station_strip_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
