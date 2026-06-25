extends SceneTree

const SpaceOverlayModeModel = preload("res://scripts/rules/space_overlay_mode_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var live_actions := SpaceOverlayModeModel.action_definitions(true)
	_assert_equal(live_actions.size(), 11, "all bridge actions are present")
	_assert_equal(live_actions[0]["button_text"], "Sensors [N]", "sensor button includes key glyph")
	_assert_equal(live_actions[9]["button_text"], "Pause [T]", "live traffic shows pause action")
	_assert_equal(live_actions[10]["key"], KEY_SEMICOLON, "manual traffic step keeps semicolon key")

	var paused_actions := SpaceOverlayModeModel.action_definitions(false)
	_assert_equal(paused_actions[9]["button_text"], "Resume [T]", "paused traffic shows resume action")

	var clear_route_actions := SpaceOverlayModeModel.action_definitions(true, {
		"difficulty": 15,
		"hazard_context": {"crossed": []},
	})
	_assert_equal(clear_route_actions[7]["button_text"], "Mnv 15 [L]", "maneuver button shows clear route difficulty")
	_assert_equal(clear_route_actions[7]["tooltip_text"], "Maneuver difficulty 15 clear", "maneuver button tooltip shows clear route")

	var hazard_route_actions := SpaceOverlayModeModel.action_definitions(true, {
		"difficulty": 20,
		"hazard_context": {"crossed": [{"id": "approach_debris", "name": "Approach Debris"}]},
	})
	_assert_equal(hazard_route_actions[7]["button_text"], "Mnv 20! [L]", "maneuver button marks hazardous difficulty")
	_assert_equal(hazard_route_actions[7]["tooltip_text"], "Maneuver difficulty 20 crosses Approach Debris", "maneuver button tooltip names hazard")

	var multi_hazard_route_actions := SpaceOverlayModeModel.action_definitions(true, {
		"difficulty": 25,
		"hazard_context": {"crossed": [
			{"id": "approach_debris", "name": "Approach Debris"},
			{"id": "traffic_slot", "name": "Traffic Slot"},
		]},
	})
	_assert_equal(multi_hazard_route_actions[7]["button_text"], "Mnv 25x2 [L]", "maneuver button shows multi-hazard count")
	_assert_equal(multi_hazard_route_actions[7]["tooltip_text"], "Maneuver difficulty 25 crosses 2 hazards incl Approach Debris", "maneuver button tooltip summarizes multiple hazards")

	var sensor_cue_actions := SpaceOverlayModeModel.action_definitions(true, {}, "Cue: sweep sensors [N]")
	_assert_equal(sensor_cue_actions[0]["button_text"], "> Sensors [N]", "sensor bridge cue highlights sensors action")
	_assert_equal(sensor_cue_actions[0]["cue_highlight"], true, "sensor bridge cue marks action metadata")
	_assert_equal(sensor_cue_actions[0]["cue_text"], "Cue: sweep sensors [N]", "sensor bridge cue stores structured cue text")
	_assert_equal(sensor_cue_actions[0]["cue_status_level"], "guidance", "sensor bridge cue stores guidance status")
	_assert_equal(sensor_cue_actions[0]["tooltip_text"], "Next cue: sweep sensors [N]", "sensor bridge cue becomes guidance button tooltip")
	_assert_equal(sensor_cue_actions[1]["button_text"], "ID [I]", "non-cue action remains unhighlighted")
	_assert_equal(sensor_cue_actions[1]["cue_highlight"], false, "non-cue action metadata remains unhighlighted")
	_assert_equal(sensor_cue_actions[1]["cue_status_level"], "none", "non-cue action keeps neutral cue status")

	var counterfire_cue_actions := SpaceOverlayModeModel.action_definitions(true, {
		"difficulty": 20,
		"hazard_context": {"crossed": [{"id": "approach_debris", "name": "Approach Debris"}]},
	}, "Cue: evade or return fire [L/B]")
	_assert_equal(counterfire_cue_actions[3]["button_text"], "> Gunnery [B]", "counterfire bridge cue highlights gunnery action")
	_assert_equal(counterfire_cue_actions[3]["cue_highlight"], true, "counterfire bridge cue marks gunnery metadata")
	_assert_equal(counterfire_cue_actions[3]["cue_status_level"], "threat", "counterfire bridge cue stores threat status on gunnery")
	_assert_equal(counterfire_cue_actions[7]["button_text"], "> Mnv 20! [L]", "counterfire bridge cue highlights maneuver action with route preview")
	_assert_equal(counterfire_cue_actions[7]["cue_highlight"], true, "counterfire bridge cue marks maneuver metadata")
	_assert_equal(counterfire_cue_actions[7]["cue_status_level"], "threat", "counterfire bridge cue stores threat status on maneuver")
	_assert_equal(counterfire_cue_actions[7]["tooltip_text"], "Maneuver difficulty 20 crosses Approach Debris | Threat cue: evade or return fire [L/B]", "counterfire bridge cue extends route tooltip with threat wording")
	var repair_cue_actions := SpaceOverlayModeModel.action_definitions(true, {}, "Cue: local damage control [K]")
	_assert_equal(repair_cue_actions[5]["button_text"], "> Repair [K]", "repair bridge cue highlights repair action")
	_assert_equal(repair_cue_actions[5]["cue_status_level"], "repair", "repair bridge cue stores repair status")
	_assert_equal(repair_cue_actions[5]["tooltip_text"], "Repair cue: local damage control [K]", "repair bridge cue becomes repair tooltip")
	_assert_equal(SpaceOverlayModeModel.cue_status_level(""), "none", "empty bridge cue has no urgency")
	_assert_equal(SpaceOverlayModeModel.cue_status_level("Cue: abandon ship"), "critical", "destroyed player bridge cue is critical")
	_assert_equal(SpaceOverlayModeModel.cue_status_level("Cue: target destroyed"), "notice", "destroyed selected target bridge cue is informational")
	_assert_equal(SpaceOverlayModeModel.cue_status_level("Cue: evade or return fire [L/B]"), "threat", "hostile lock bridge cue is threat")
	_assert_equal(SpaceOverlayModeModel.cue_status_level("Cue: local damage control [K]"), "repair", "local repair bridge cue is repair")
	_assert_equal(SpaceOverlayModeModel.cue_status_level("Cue: sweep sensors [N]"), "guidance", "routine bridge cue is guidance")

	var status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "sensor_shadow", "name": "Sensor Shadow"},
		{"revealed_contacts": ["visible_patrol", "sensor_shadow"], "scan_round": 4},
		true,
		3
	)
	_assert_equal(status, "Krayt Runner | Bridge mode | Traffic LIVE | Target Sensor Shadow | Tracks 2 | Scan 4 | Ticks 3", "bridge mode status text")

	var maneuver_status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "sensor_shadow", "name": "Sensor Shadow"},
		{"revealed_contacts": ["visible_patrol"], "scan_round": 5},
		true,
		4,
		{
			"difficulty": 20,
			"hazard_context": {"crossed": [{"id": "approach_debris", "name": "Approach Debris"}]},
		}
	)
	_assert_equal(maneuver_status, "Krayt Runner | Bridge mode | Traffic LIVE | Target Sensor Shadow | Tracks 1 | Scan 5 | Ticks 4 | Maneuver diff 20 crosses Approach Debris", "bridge mode status includes named route hazard preview")

	var cue_status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "sensor_shadow", "name": "Sensor Shadow"},
		{"revealed_contacts": ["sensor_shadow"], "scan_round": 5},
		true,
		4,
		{
			"difficulty": 20,
			"hazard_context": {"crossed": [{"id": "approach_debris", "name": "Approach Debris"}]},
		},
		"Cue: evade or return fire [L/B]"
	)
	_assert_equal(cue_status, "Krayt Runner | Bridge mode | Traffic LIVE | Target Sensor Shadow | Tracks 1 | Scan 5 | Ticks 4 | Maneuver diff 20 crosses Approach Debris | Threat evade or return fire [L/B]", "bridge mode status includes selected contact threat cue")

	var plain_cue_status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "hidden_return", "name": "Hidden Return"},
		{"revealed_contacts": [], "scan_round": 2},
		false,
		1,
		{},
		"Sweep sensors [N]"
	)
	_assert_equal(plain_cue_status, "Krayt Runner | Bridge mode | Traffic PAUSED | Target Hidden Return | Tracks 0 | Scan 2 | Ticks 1 | Next Sweep sensors [N]", "bridge mode status keeps plain cue text")

	var repair_cue_status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "visible_patrol", "name": "Visible Patrol"},
		{"revealed_contacts": ["visible_patrol"], "scan_round": 3},
		false,
		2,
		{},
		"Cue: local damage control [K]"
	)
	_assert_equal(repair_cue_status, "Krayt Runner | Bridge mode | Traffic PAUSED | Target Visible Patrol | Tracks 1 | Scan 3 | Ticks 2 | Repair local damage control [K]", "repair bridge cue uses repair language")

	var critical_cue_status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "sensor_shadow", "name": "Sensor Shadow"},
		{"revealed_contacts": ["sensor_shadow"], "scan_round": 6},
		true,
		7,
		{},
		"Cue: abandon ship"
	)
	_assert_equal(critical_cue_status, "Krayt Runner | Bridge mode | Traffic LIVE | Target Sensor Shadow | Tracks 1 | Scan 6 | Ticks 7 | Alert abandon ship", "critical bridge cue uses alert language")

	var notice_cue_status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "sensor_shadow", "name": "Sensor Shadow"},
		{"revealed_contacts": ["sensor_shadow"], "scan_round": 6},
		true,
		7,
		{},
		"Cue: target destroyed"
	)
	_assert_equal(notice_cue_status, "Krayt Runner | Bridge mode | Traffic LIVE | Target Sensor Shadow | Tracks 1 | Scan 6 | Ticks 7 | Status target destroyed", "destroyed selected target bridge cue uses status language")

	var multi_hazard_status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "sensor_shadow", "name": "Sensor Shadow"},
		{"revealed_contacts": ["visible_patrol"], "scan_round": 5},
		true,
		4,
		{
			"difficulty": 25,
			"hazard_context": {"crossed": [
				{"id": "approach_debris", "name": "Approach Debris"},
				{"id": "traffic_slot", "name": "Traffic Slot"},
			]},
		}
	)
	_assert_equal(multi_hazard_status, "Krayt Runner | Bridge mode | Traffic LIVE | Target Sensor Shadow | Tracks 1 | Scan 5 | Ticks 4 | Maneuver diff 25 crosses 2 hazards incl Approach Debris", "bridge mode status includes multi-hazard preview")

	var clear_maneuver_status := SpaceOverlayModeModel.mode_status_text(
		{"name": "Krayt Runner"},
		{"id": "visible_patrol", "name": "Visible Patrol"},
		{"revealed_contacts": [], "scan_round": 1},
		false,
		0,
		{
			"difficulty": 15,
			"hazard_context": {"crossed": []},
		}
	)
	_assert_equal(clear_maneuver_status, "Krayt Runner | Bridge mode | Traffic PAUSED | Target Visible Patrol | Tracks 0 | Scan 1 | Ticks 0 | Maneuver diff 15 clear", "bridge mode status includes clear route preview")

	var empty_status := SpaceOverlayModeModel.mode_status_text({}, {}, {}, false, 0)
	_assert_equal(empty_status, "Local ship | Bridge mode | Traffic PAUSED | Target No target | Tracks 0 | Scan 1 | Ticks 0", "bridge mode empty fallback")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("space_overlay_mode_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
