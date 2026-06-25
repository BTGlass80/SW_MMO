extends SceneTree

const SpaceStatusModel = preload("res://scripts/rules/space_status_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var state := {
		"revealed_contacts": ["visible_patrol"],
		"weapon_solution_counts": {"sensor_shadow": 2},
		"station_assists": {
			"gunnery": {"name": "Gunner bracketing", "target_action": "gunnery", "pool": "1D", "banked_round": 3},
			"astrogation": {"name": "Jump calculation", "target_action": "astrogation", "requested_target_action": "jump_calculation", "pool": "1D", "banked_round": 4},
		},
	}
	var contacts := [
		{"id": "visible_patrol", "name": "Visible Patrol", "counterfire": false},
		{
			"id": "sensor_shadow",
			"name": "Sensor Shadow",
			"counterfire": true,
			"hidden_until_revealed": true,
			"movement": {"lock_rounds_to_fire": 2},
		},
	]
	var ship := {
		"condition": {
			"hull_severity": 2,
			"shield_loss_dice": 1,
			"controls_ionized": 1,
			"repairable_systems": ["shields"],
			"crew_wounds": {
				"pilot": {
					"name": "Pilot",
					"wound": {"name": "Wounded", "severity": 2},
					"severity": 2,
				},
				"copilot": {
					"name": "Copilot",
					"wound": {"name": "Stunned", "severity": 0},
					"severity": 0,
				},
			},
		},
	}
	var line := SpaceStatusModel.telemetry_line(state, contacts, ship, true, 1.0, 5.0, 4)
	_assert_equal(line.contains("traffic running 4.0s"), true, "live countdown")
	_assert_equal(line.contains("contacts 2 known 1 hidden 1"), true, "contact known and hidden counts")
	_assert_equal(line.contains("locks Sensor Shadow ready"), true, "ready hostile lock")
	_assert_equal(line.contains("assists Gunner bracketing 1D for gunnery since station 3"), true, "banked assist telemetry includes target action and station round")
	_assert_equal(line.contains("Jump calculation 1D for astrogation (jump calculation) since station 4"), true, "banked assist telemetry preserves requested target alias")
	_assert_equal(line.contains("ship Lightly Damaged/shields -1D/controls ionized 1/repair 1/1 crew wounded"), true, "ship condition summary")
	_assert_equal(line.contains("updates 4"), true, "live update count")
	_assert_equal(SpaceStatusModel.contact_count_text(state, contacts), "Known 1/2, hidden 1.", "contact count summary")
	var all_known_state := state.duplicate(true)
	all_known_state["revealed_contacts"] = ["visible_patrol", "sensor_shadow"]
	_assert_equal(SpaceStatusModel.contact_count_text(all_known_state, contacts), "Known 2/2, hidden 0.", "all contacts known summary")
	_assert_equal(SpaceStatusModel.contact_confidence_label(state, "sensor_shadow"), "", "missing contact confidence label stays quiet")
	var contact_label_state := all_known_state.duplicate(true)
	contact_label_state["sensor_contact_confidence"] = {"sensor_shadow": {"name": "Solid"}}
	_assert_equal(
		SpaceStatusModel.contact_confidence_label(contact_label_state, "sensor_shadow"),
		" | Track: Solid",
		"contact confidence label"
	)
	var identified_label_state := contact_label_state.duplicate(true)
	identified_label_state["identified_contacts"] = {
		"sensor_shadow": {
			"declared_name": "Masked Snub Contact",
			"affiliation": "unknown",
			"threat": "hostile",
		},
	}
	identified_label_state["contact_dispositions"] = {
		"sensor_shadow": {
			"status": "responsive",
			"weapon_solution_delay": {
				"applies": true,
				"prior_rounds": 2,
				"remaining_rounds": 1,
			},
		},
	}
	_assert_equal(
		SpaceStatusModel.contact_identification_label(identified_label_state, "sensor_shadow"),
		" | ID: Masked Snub Contact/unknown/hostile",
		"contact identification label"
	)
	_assert_equal(
		SpaceStatusModel.contact_disposition_label(identified_label_state, "sensor_shadow"),
		" | Comms: Responsive (lock 2->1)",
		"contact comms disposition label"
	)
	var pressure_label_state := contact_label_state.duplicate(true)
	pressure_label_state["contact_dispositions"] = {
		"sensor_shadow": {
			"status": "unresponsive",
			"weapon_solution_pressure": {
				"applies": true,
				"prior_rounds": 1,
				"current_rounds": 2,
				"fire_ready": true,
			},
		},
	}
	_assert_equal(
		SpaceStatusModel.contact_disposition_label(pressure_label_state, "sensor_shadow"),
		" | Comms: Unresponsive (lock 1->2 ready)",
		"contact comms pressure label shows ready lock"
	)
	_assert_equal(
		SpaceStatusModel.contact_visual_label_text(
			{"id": "sensor_shadow", "name": "Sensor Shadow", "status": "unknown", "hidden_until_revealed": true},
			state,
			"sensor_shadow"
		),
		"Unresolved return - unknown",
		"hidden contact visual label"
	)
	_assert_equal(
		SpaceStatusModel.contact_visual_label_text(
			{"id": "sensor_shadow", "name": "Sensor Shadow", "status": "closing", "hidden_until_revealed": true},
			identified_label_state,
			"sensor_shadow"
		),
		"Sensor Shadow - closing | Track: Solid | ID: Masked Snub Contact/unknown/hostile | Comms: Responsive (lock 2->1)",
		"revealed contact visual label with confidence identity and comms"
	)
	_assert_equal(
		SpaceStatusModel.contact_visual_label_text({"id": "visible_patrol", "name": "Visible Patrol", "status": "patrol"}, state),
		"Visible Patrol - patrol",
		"visible contact visual label without confidence"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_text(
			{"id": "sensor_shadow", "name": "Sensor Shadow", "status": "faint"},
			contact_label_state,
			"sensor_shadow"
		),
		"Target: Sensor Shadow - faint | Track: Solid",
		"selected contact text uses visual contact label"
	)
	_assert_equal(SpaceStatusModel.selected_contact_text({}, state), "Target: none selected", "empty selected contact text")
	_assert_equal(
		SpaceStatusModel.selected_contact_action_text(
			{"id": "sensor_shadow", "name": "Sensor Shadow", "status": "unknown", "hidden_until_revealed": true},
			state,
			"sensor_shadow"
		),
		"Selected target: Unresolved return - unknown.",
		"hidden selected contact action text"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_action_text(
			{"id": "sensor_shadow", "name": "Sensor Shadow", "status": "closing", "hidden_until_revealed": true},
			identified_label_state,
			"sensor_shadow"
		),
		"Selected target: Sensor Shadow - closing | Track: Solid | ID: Masked Snub Contact/unknown/hostile | Comms: Responsive (lock 2->1).",
		"revealed selected contact action text"
	)
	_assert_equal(SpaceStatusModel.selected_contact_action_text({}, state), "Selected target: none.", "empty selected contact action text")
	_assert_equal(
		SpaceStatusModel.selected_contact_bridge_cue_label(
			{"id": "sensor_shadow", "hidden_until_revealed": true},
			state,
			"sensor_shadow"
		),
		"Cue: sweep sensors [N]",
		"bridge cue asks for sensors on unresolved hidden return"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_bridge_cue_label(
			{"id": "sensor_shadow", "hidden_until_revealed": true},
			contact_label_state,
			"sensor_shadow"
		),
		"Cue: identify contact [I]",
		"bridge cue asks for identification after sensor track"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_bridge_cue_label(
			{"id": "sensor_shadow", "hidden_until_revealed": true, "comms": {}},
			{"revealed_contacts": ["sensor_shadow"], "identified_contacts": {"sensor_shadow": {"declared_name": "Masked Snub Contact"}}},
			"sensor_shadow"
		),
		"Cue: hail contact [X]",
		"bridge cue asks for hail after identification"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_bridge_cue_label(
			{"id": "sensor_shadow", "counterfire": true, "movement": {"lock_rounds_to_fire": 2}},
			{"weapon_solution_counts": {"sensor_shadow": 2}},
			"sensor_shadow"
		),
		"Cue: evade or return fire [L/B]",
		"bridge cue prioritizes ready hostile lock"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_bridge_cue_label(
			{"id": "sensor_shadow", "counterfire": true, "movement": {"lock_rounds_to_fire": 2}},
			{"weapon_solution_counts": {"sensor_shadow": 1}},
			"sensor_shadow"
		),
		"Cue: disrupt weapon solution [B/L]",
		"bridge cue reports partial hostile lock"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_bridge_cue_label(
			{"id": "sensor_shadow"},
			{},
			"sensor_shadow",
			{"sensor_targeting_required": true, "gunnery_difficulty_modifier": 6}
		),
		"Cue: improve sensor track [N]",
		"bridge cue asks for stronger track on hard sensor targeting"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_bridge_cue_label({"condition": {"shield_loss_dice": 1}}, {}, ""),
		"Cue: damage control [K]",
		"bridge cue asks for damage control on repairable contact"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_bridge_cue_label({"condition": {"destroyed": true}}, {}, ""),
		"Cue: target neutralized",
		"bridge cue reports destroyed contact"
	)
	_assert_equal(
		SpaceStatusModel.local_ship_bridge_cue_label({"condition": {"shield_loss_dice": 1}}),
		"Cue: local damage control [K]",
		"local bridge cue asks for damage control on damaged player ship"
	)
	_assert_equal(
		SpaceStatusModel.local_ship_bridge_cue_label({"condition": {"repairable_systems": ["backup relay"], "repair_difficulties": {"backup relay": "yard only"}}}),
		"",
		"local bridge cue ignores yard-only damage"
	)
	_assert_equal(
		SpaceStatusModel.local_ship_bridge_cue_label({"condition": {"destroyed": true, "shield_loss_dice": 1}}),
		"Cue: abandon ship",
		"local bridge cue reports destroyed player ship"
	)
	_assert_equal(
		SpaceStatusModel.bridge_cue_label(
			{"id": "sensor_shadow", "counterfire": true, "movement": {"lock_rounds_to_fire": 2}},
			{"weapon_solution_counts": {"sensor_shadow": 2}},
			{"condition": {"shield_loss_dice": 1}},
			"sensor_shadow"
		),
		"Cue: evade or return fire [L/B]",
		"combined bridge cue prioritizes selected contact threat over local repair"
	)
	_assert_equal(
		SpaceStatusModel.bridge_cue_label(
			{"id": "visible_patrol"},
			{},
			{"condition": {"shield_loss_dice": 1}},
			"visible_patrol"
		),
		"Cue: local damage control [K]",
		"combined bridge cue falls back to local repair"
	)
	_assert_equal(
		SpaceStatusModel.bridge_cue_label(
			{"id": "sensor_shadow", "counterfire": true, "movement": {"lock_rounds_to_fire": 2}},
			{"weapon_solution_counts": {"sensor_shadow": 2}},
			{"condition": {"destroyed": true}},
			"sensor_shadow"
		),
		"Cue: abandon ship",
		"combined bridge cue prioritizes destroyed player ship"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_lock_label(
			state,
			{"id": "sensor_shadow", "movement": {"lock_rounds_to_fire": 2}},
			"sensor_shadow"
		),
		"Lock: ready",
		"selected contact lock label"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_lock_label(
			state,
			{"id": "sensor_shadow", "range_name": "Short", "movement": {"lock_rounds_to_fire": 2}},
			"sensor_shadow"
		),
		"Lock: ready Short",
		"selected contact lock label includes direct range"
	)
	var movement_range_state := state.duplicate(true)
	movement_range_state["last_contact_movement_events"] = [{"contact_id": "sensor_shadow", "range_name": "Medium"}]
	_assert_equal(
		SpaceStatusModel.selected_contact_lock_label(
			movement_range_state,
			{"id": "sensor_shadow", "movement": {"lock_rounds_to_fire": 2}},
			"sensor_shadow"
		),
		"Lock: ready Medium",
		"selected contact lock label uses latest movement range"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_detail_text(
			{"id": "sensor_shadow", "name": "Sensor Shadow", "status": "unknown", "hidden_until_revealed": true, "movement": {"lock_rounds_to_fire": 2}},
			movement_range_state,
			"sensor_shadow"
		),
		"Target: Unresolved return | Status: unknown | Cue: sweep sensors [N] | Lock: ready Medium",
		"hidden selected contact detail avoids identity leak while showing lock range"
	)
	var holding_movement_state := state.duplicate(true)
	holding_movement_state["last_movement_events"] = [
		{
			"contact_id": "sensor_shadow",
			"can_move": true,
			"tracks_focus": true,
			"holds_range": true,
			"range_name": "Short",
			"move_units": 0.0,
		},
	]
	_assert_equal(
		SpaceStatusModel.selected_contact_movement_label(
			holding_movement_state,
			{"id": "sensor_shadow", "movement": {"track_target": "player", "hold_range": 80}},
			"sensor_shadow"
		),
		"Movement: holding Short while tracking player",
		"selected contact movement label reports holding track"
	)
	var closing_movement_state := state.duplicate(true)
	closing_movement_state["last_contact_movement_events"] = [
		{
			"contact_id": "sensor_shadow",
			"can_move": true,
			"tracks_focus": true,
			"holds_range": false,
			"range_name": "Medium",
			"move_units": 12.0,
		},
	]
	_assert_equal(
		SpaceStatusModel.selected_contact_movement_label(
			closing_movement_state,
			{"id": "sensor_shadow", "movement": {"track_target": "player", "hold_range": 80}},
			"sensor_shadow"
		),
		"Movement: tracking player, closing Medium at 12 units",
		"selected contact movement label reports closing track"
	)
	var blocked_movement_state := state.duplicate(true)
	blocked_movement_state["last_movement_events"] = [
		{"contact_id": "sensor_shadow", "can_move": false, "movement_blocked_reason": "drives_disabled"},
	]
	_assert_equal(
		SpaceStatusModel.selected_contact_movement_label(blocked_movement_state, {"id": "sensor_shadow"}, "sensor_shadow"),
		"Movement: blocked - drives disabled",
		"selected contact movement label reports blocked movement"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_movement_label({}, {"id": "visible_patrol", "movement": {"move_units": 10}}, "visible_patrol"),
		"Movement: patrol course, moving 10 units",
		"selected contact movement label falls back to patrol profile"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_scale_label({"scale": "starfighter"}),
		"Scale: Starfighter",
		"selected contact scale label reports scale"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_scale_label({"scale": "capital_ship"}),
		"Scale: Capital Ship",
		"selected contact scale label formats underscored scale"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_scale_label({}),
		"",
		"selected contact scale label stays quiet without scale"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_defense_label({"defense_pool": "4D+1"}),
		"Defense: 4D+1",
		"selected contact defense label reports base defensive maneuver"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_defense_label({"defense_pool": "4D+1", "condition": {"controls_ionized": 1, "maneuverability_loss_dice": 2}}),
		"Defense: 4D+1 (-1D controls, -2D maneuver)",
		"selected contact defense label reports condition penalties"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_defense_label({"defense_pool": "3D", "condition": {"drives_disabled": true}}),
		"Defense: no defensive maneuver (drives offline)",
		"selected contact defense label reports disabled drives"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_defense_label({"defense_pool": "3D", "condition": {"controls_ionized": 99}}),
		"Defense: no defensive maneuver (controls dead)",
		"selected contact defense label reports dead controls"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_defense_label({"condition": {"destroyed": true}}),
		"Defense: destroyed",
		"selected contact defense label reports destroyed contact"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_defense_label({}),
		"",
		"selected contact defense label stays quiet without defense data"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_soak_label({"hull": "2D+2", "shields": "0D"}),
		"Soak: hull 2D+2, shields 0D",
		"selected contact soak label reports hull and shields"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_soak_label({"hull": "4D", "shield_arcs": {"front": "1D", "rear": "0D", "left": "0D", "right": "0D"}}),
		"Soak: hull 4D, shields front 1D, rear 0D, left 0D, right 0D",
		"selected contact soak label reports shield arcs"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_soak_label({"hull": "4D", "shields": "2D", "condition": {"shield_loss_dice": 1, "controls_ionized": 1}}),
		"Soak: hull 4D, shields 2D (-1D shields, -1D controls)",
		"selected contact soak label reports shield penalties"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_soak_label({"condition": {"destroyed": true}, "hull": "4D"}),
		"Soak: destroyed",
		"selected contact soak label reports destroyed contact"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_soak_label({}),
		"",
		"selected contact soak label stays quiet without soak data"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_weapon_label({"gunnery_pool": "3D+1", "fire_control": "1D", "weapon_damage": "3D+2"}),
		"Weapons: gunnery 3D+1, fire control 1D, damage 3D+2",
		"selected contact weapon label reports offensive pools"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_weapon_label({"gunnery_pool": "3D+1", "fire_control": "1D", "weapon_damage": "3D+2", "condition": {"controls_ionized": 1}}),
		"Weapons: gunnery 3D+1, fire control 1D, damage 3D+2 (-1D controls)",
		"selected contact weapon label reports controls penalty"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_weapon_label({"gunnery_pool": "3D", "condition": {"controls_ionized": 99}}),
		"Weapons: controls dead",
		"selected contact weapon label reports dead controls"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_weapon_label({"condition": {"weapons_disabled": true}}),
		"Weapons: offline",
		"selected contact weapon label reports disabled weapons"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_weapon_label({"condition": {"destroyed": true}}),
		"Weapons: destroyed",
		"selected contact weapon label reports destroyed contact"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_weapon_label({"counterfire": true}),
		"Weapons: armed",
		"selected contact weapon label reports armed contact without pool data"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_weapon_label({}),
		"",
		"selected contact weapon label stays quiet without weapon data"
	)
	var crew_status_contact := {
		"id": "sensor_shadow",
		"name": "Sensor Shadow",
		"crew": [
			{"id": "shadow_pilot", "name": "Shadow Pilot", "station": "pilot"},
			{"id": "shadow_gunner", "name": "Shadow Gunner", "station": "gunner"},
		],
		"condition": {
			"crew_wounds": {
				"shadow_pilot": {"wound": {"name": "Wounded", "severity": 2}},
				"shadow_gunner": {"wound": {"name": "Stunned", "severity": 0}},
				"shadow_spare": {"name": "Spare", "station": "passenger", "wound": {"name": "No Damage", "severity": -1}},
			},
		},
	}
	_assert_equal(
		SpaceStatusModel.selected_contact_crew_label(crew_status_contact),
		"Crew: Shadow Gunner Stunned (gunner), Shadow Pilot Wounded (pilot)",
		"selected contact crew label reports meaningful crew wounds"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_crew_label({}),
		"",
		"selected contact crew label stays quiet without crew wounds"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_systems_label({
			"condition": {
				"move_loss": 2,
				"hyperdrive_disabled": true,
				"hyperdrive_calculation_penalty": 1,
				"astrogation_difficulty_penalty": 3,
				"generator_overloading": true,
				"structural_damage": true,
			},
		}),
		"Systems: Move -2, hyperdrive offline, hyperdrive calculations slowed, astrogation +3, generator overloading, structural damage",
		"selected contact systems label reports non-weapon ship systems"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_systems_label({"condition": {"destroyed": true}}),
		"Systems: destroyed",
		"selected contact systems label reports destroyed contact"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_systems_label({"condition": {"weapons_disabled": true, "drives_disabled": true, "maneuverability_loss_dice": 1}}),
		"",
		"selected contact systems label avoids duplicating weapon and defense posture"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_systems_label({}),
		"",
		"selected contact systems label stays quiet without system data"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_detail_text(crew_status_contact, {}, "sensor_shadow"),
		"Target: Sensor Shadow | Crew: Shadow Gunner Stunned (gunner), Shadow Pilot Wounded (pilot) | Condition: Operational, 1 crew wounded",
		"selected contact detail includes crew wound posture"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_detail_text(
			{"id": "sensor_shadow", "name": "Sensor Shadow", "status": "closing", "hidden_until_revealed": true, "scale": "starfighter", "defense_pool": "4D+1", "hull": "2D+2", "shields": "0D", "gunnery_pool": "3D+1", "fire_control": "1D", "weapon_damage": "3D+2", "movement": {"lock_rounds_to_fire": 2}},
			holding_movement_state,
			"sensor_shadow"
		),
		"Target: Unresolved return | Status: closing | Scale: Starfighter | Defense: 4D+1 | Soak: hull 2D+2, shields 0D | Weapons: gunnery 3D+1, fire control 1D, damage 3D+2 | Cue: sweep sensors [N] | Lock: ready | Movement: holding Short while tracking player",
		"selected contact detail includes scale, defense, soak, weapon, bridge cue, and movement posture"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_detail_text(
			{
				"id": "sensor_shadow",
				"name": "Sensor Shadow",
				"status": "closing",
				"hidden_until_revealed": true,
				"movement": {"lock_rounds_to_fire": 3},
				"counterfire": true,
				"counterfire_requires_solution": true,
				"condition": {"worst_hull_severity": 2, "shield_loss_dice": 1, "weapons_disabled": true, "hyperdrive_disabled": true, "astrogation_difficulty_penalty": 3},
			},
			identified_label_state,
			"sensor_shadow"
		),
		"Target: Sensor Shadow | Status: closing | Track: Solid | Weapons: offline | Systems: hyperdrive offline, astrogation +3 | ID: Masked Snub Contact/unknown/hostile | Comms: Responsive (lock 2->1) | Cue: damage control [K] | Lock: 2/3 | Fire posture: weapons offline | Counterfire: weapons offline | Repair: shields, weapons, hyperdrive | Condition: Lightly Damaged, Shields -1D, Weapons Disabled, Hyperdrive Disabled, Astrogation +3",
		"revealed selected contact detail summarizes tactical state, systems posture, bridge cue, counterfire posture, and repair options"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_detail_text(
			{"id": "sensor_shadow", "name": "Sensor Shadow", "status": "closing", "hidden_until_revealed": true},
			identified_label_state,
			"sensor_shadow",
			{"sensor_targeting_required": true, "gunnery_difficulty_modifier": 3}
		),
		"Target: Sensor Shadow | Status: closing | Track: Solid | ID: Masked Snub Contact/unknown/hostile | Comms: Responsive (lock 2->1) | Cue: improve sensor track [N] | Lock: ready | Targeting: +3 difficulty",
		"selected contact detail reports sensor targeting penalty"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_fire_posture_label(
			{},
			{"id": "sensor_shadow", "counterfire": true, "counterfire_requires_solution": true, "movement": {"lock_rounds_to_fire": 2}},
			"sensor_shadow"
		),
		"Fire posture: acquiring solution",
		"selected contact fire posture reports acquiring gated solution"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_fire_posture_label(
			{"weapon_solution_counts": {"sensor_shadow": 1}},
			{"id": "sensor_shadow", "counterfire": true, "counterfire_requires_solution": true, "movement": {"lock_rounds_to_fire": 2}},
			"sensor_shadow"
		),
		"Fire posture: solution 1/2",
		"selected contact fire posture reports partial gated solution"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_fire_posture_label(
			state,
			{"id": "sensor_shadow", "counterfire": true, "counterfire_requires_solution": true, "movement": {"lock_rounds_to_fire": 2}},
			"sensor_shadow"
		),
		"Fire posture: ready to fire",
		"selected contact fire posture reports ready gated solution"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_fire_posture_label(
			{},
			{"id": "sensor_shadow", "counterfire": true},
			"sensor_shadow"
		),
		"Fire posture: armed",
		"selected contact fire posture reports ungated armed contact"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_fire_posture_label(
			state,
			{"id": "sensor_shadow", "counterfire": true, "condition": {"weapons_disabled": true}},
			"sensor_shadow"
		),
		"Fire posture: weapons offline",
		"selected contact fire posture reports disabled weapons"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_fire_posture_label({}, {"counterfire": false}, "visible_patrol"),
		"",
		"selected contact fire posture stays quiet for passive contacts"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_counterfire_label({"counterfire": true}),
		"Counterfire: armed",
		"selected contact counterfire label reports armed posture"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_counterfire_label({"counterfire": true, "counterfire_requires_solution": true}),
		"Counterfire: lock-gated",
		"selected contact counterfire label reports gated posture"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_counterfire_label({"counterfire": true, "condition": {"weapons_disabled": true}}),
		"Counterfire: weapons offline",
		"selected contact counterfire label reports disabled weapons"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_counterfire_label({"counterfire": false}),
		"",
		"selected contact counterfire label stays quiet for passive contact"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_repair_label({"condition": {"shield_loss_dice": 1, "weapons_disabled": true, "weapons_destroyed": true, "drives_disabled": true}}),
		"Repair: shields, drives",
		"selected contact repair label excludes destroyed weapons"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_repair_label({"condition": {"repairable_systems": ["sensor mast", "cargo_lift"], "shield_loss_dice": 1}}),
		"Repair: shields, sensor_mast, cargo_lift",
		"selected contact repair label preserves custom repairable systems"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_repair_label({
			"repair_difficulties": {"cargo_lift": 25},
			"condition": {
				"repairable_systems": ["sensor mast", "cargo_lift", "backup relay"],
				"repair_difficulties": {"sensor mast": "difficult", "backup_relay": "yard only"},
			},
		}),
		"Repair: sensor_mast (Difficult), cargo_lift (Very Difficult), backup_relay (Yard Only)",
		"selected contact repair label shows data-driven repair difficulty overrides"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_repair_label({"condition": {"destroyed": true, "shield_loss_dice": 1}}),
		"",
		"selected contact repair label stays quiet for destroyed contacts"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_targeting_label({"sensor_targeting_required": true, "gunnery_difficulty_modifier": 0}),
		"Targeting: clean track",
		"selected contact detail reports clean sensor targeting"
	)
	_assert_equal(
		SpaceStatusModel.selected_contact_targeting_label({"sensor_targeting_required": false, "gunnery_difficulty_modifier": 6}),
		"",
		"visible target hides irrelevant sensor targeting penalty"
	)
	_assert_equal(SpaceStatusModel.selected_contact_detail_text({}, state), "Target: none selected", "empty selected contact detail")

	var tracked_lock_state := state.duplicate(true)
	tracked_lock_state["sensor_contact_confidence"] = {
		"sensor_shadow": {"name": "Solid"},
	}
	var tracked_lock_line := SpaceStatusModel.telemetry_line(tracked_lock_state, contacts, ship, true, 1.0, 5.0, 4)
	_assert_equal(tracked_lock_line.contains("locks Sensor Shadow ready track Solid"), true, "fallback lock telemetry includes persisted track confidence")

	var event_state := state.duplicate(true)
	event_state["last_movement_events"] = [
		{
			"contact_id": "sensor_shadow",
			"contact_name": "Sensor Shadow",
			"weapon_solution": true,
			"weapon_solution_rounds": 1,
			"fire_ready_rounds": 2,
			"fire_ready": false,
			"engagement_context": {
				"targeting": {"confidence_name": "Partial"},
				"weapon_solution": {"rounds": 1, "required_rounds": 2, "ready": false},
			},
		},
	]
	var event_line := SpaceStatusModel.telemetry_line(event_state, contacts, ship, true, 2.0, 5.0, 5)
	_assert_equal(event_line.contains("locks Sensor Shadow 1/2 track Partial"), true, "movement event lock text includes track confidence")
	var consumed_lock_state := event_state.duplicate(true)
	consumed_lock_state["weapon_solution_counts"] = {}
	var consumed_lock_line := SpaceStatusModel.telemetry_line(consumed_lock_state, contacts, ship, true, 2.0, 5.0, 5)
	_assert_equal(consumed_lock_line.contains("locks none"), true, "consumed lock hides stale movement-event telemetry")
	var hostile_fire_state := state.duplicate(true)
	hostile_fire_state["last_automatic_hostile_fire_events"] = [
		{
			"applies": true,
			"contact_name": "Sensor Shadow",
			"event": {
				"hit": true,
				"starship_damage": {"name": "Lightly Damaged"},
			},
			"consumed_weapon_solution": {"applies": true, "prior_rounds": 2},
			"player_condition": {"worst_hull_severity": 2, "shield_loss_dice": 1},
		},
		{"applies": false, "contact_name": "Broken Droid", "reason": "weapons_disabled", "consumed_weapon_solution": {"applies": true, "prior_rounds": 3}},
		{"applies": false, "contact_name": "Wreck Shooter", "reason": "player_destroyed", "consumed_weapon_solution": {"applies": true, "prior_rounds": 2}},
		{"applies": false, "contact_name": "Late Shooter", "reason": "player_destroyed_by_prior_fire", "consumed_weapon_solution": {"applies": true, "prior_rounds": 2}},
	]
	var hostile_fire_line := SpaceStatusModel.telemetry_line(hostile_fire_state, contacts, ship, true, 1.0, 5.0, 6)
	_assert_equal(hostile_fire_line.contains("hostile Sensor Shadow hit Lightly Damaged spent 2 ship Lightly Damaged/shields -1D"), true, "automatic hostile fire telemetry summarizes applied shot")
	_assert_equal(hostile_fire_line.contains("Broken Droid blocked weapons disabled cleared 3"), true, "automatic hostile fire telemetry summarizes blocked shot and cleared lock")
	_assert_equal(hostile_fire_line.contains("Wreck Shooter blocked player destroyed cleared 2"), true, "automatic hostile fire telemetry summarizes destroyed-player blocked shot")
	_assert_equal(hostile_fire_line.contains("Late Shooter blocked player destroyed by prior fire cleared 2"), true, "automatic hostile fire telemetry summarizes prior-fire blocked shot")

	var paused := SpaceStatusModel.telemetry_line({}, [], {}, false, 0.0, 5.0, 0)
	_assert_equal(paused.contains("traffic paused"), true, "paused text")
	_assert_equal(paused.contains("locks none"), true, "empty lock text")
	_assert_equal(paused.contains("hostile none"), true, "empty hostile fire text")
	_assert_equal(paused.contains("assists none"), true, "empty assist text")
	_assert_equal(paused.contains("ship Operational"), true, "default ship condition")

	var persistent_damage_line := SpaceStatusModel.telemetry_line(
		{},
		[],
		{"condition": {"worst_hull_severity": 3}},
		true,
		0.0,
		5.0,
		0
	)
	_assert_equal(persistent_damage_line.contains("ship Heavily Damaged"), true, "persistent hull severity telemetry")
	var destroyed_line := SpaceStatusModel.telemetry_line(
		{},
		[],
		{"condition": {"worst_hull_severity": 2, "destroyed": true}},
		true,
		0.0,
		5.0,
		0
	)
	_assert_equal(destroyed_line.contains("ship Destroyed"), true, "destroyed flag wins telemetry")
	var system_damage_line := SpaceStatusModel.telemetry_line(
		{},
		[],
		{
			"condition": {
				"maneuverability_loss_dice": 1,
				"move_loss": 2,
				"weapons_disabled": true,
				"drives_disabled": true,
				"hyperdrive_disabled": true,
				"generator_overloading": true,
				"structural_damage": true,
			},
		},
		true,
		0.0,
		5.0,
		0
	)
	_assert_equal(system_damage_line.contains("maneuver -1D"), true, "system telemetry includes maneuverability loss")
	_assert_equal(system_damage_line.contains("Move -2"), true, "system telemetry includes move loss")
	_assert_equal(system_damage_line.contains("weapons offline"), true, "system telemetry includes disabled weapons")
	_assert_equal(system_damage_line.contains("drives offline"), true, "system telemetry includes disabled drives")
	_assert_equal(system_damage_line.contains("hyperdrive offline"), true, "system telemetry includes disabled hyperdrive")
	_assert_equal(system_damage_line.contains("generator overloading"), true, "system telemetry includes generator overloading")
	_assert_equal(system_damage_line.contains("structural"), true, "system telemetry includes structural damage")
	_assert_equal(system_damage_line.contains("repair 7"), true, "repair count derives from persistent system fields")
	var custom_repair_line := SpaceStatusModel.telemetry_line(
		{},
		[],
		{"condition": {"repairable_systems": ["sensor mast", "cargo_lift"], "shield_loss_dice": 1}},
		true,
		0.0,
		5.0,
		0
	)
	_assert_equal(custom_repair_line.contains("repair 3"), true, "repair count preserves custom repairable systems")
	var yard_only_custom_repair_line := SpaceStatusModel.telemetry_line(
		{},
		[],
		{
			"repair_difficulties": {"backup relay": "yard only"},
			"condition": {
				"repairable_systems": ["sensor mast", "cargo_lift", "backup relay"],
				"repair_difficulties": {"sensor mast": "difficult", "cargo_lift": "very difficult"},
			},
		},
		true,
		0.0,
		5.0,
		0
	)
	_assert_equal(yard_only_custom_repair_line.contains("repair 2"), true, "repair count excludes yard-only custom systems")
	_assert_equal(yard_only_custom_repair_line.contains("repair 3"), false, "repair count does not imply yard-only systems are field-repairable")
	var destroyed_weapon_line := SpaceStatusModel.telemetry_line(
		{},
		[],
		{"condition": {"weapons_disabled": true, "weapons_destroyed": true}},
		true,
		0.0,
		5.0,
		0
	)
	_assert_equal(destroyed_weapon_line.contains("weapons offline"), true, "destroyed weapon still reports offline")
	_assert_equal(destroyed_weapon_line.contains("repair "), false, "destroyed weapon is not field-repairable telemetry")

	var repair_change := SpaceStatusModel.repair_change_text({
		"before_condition_summary": {"text": "Lightly Damaged, Shields -2D"},
		"after_condition_summary": {"text": "Lightly Damaged"},
	})
	_assert_equal(repair_change, "Lightly Damaged, Shields -2D -> Lightly Damaged", "repair change summary")
	var unchanged_repair := SpaceStatusModel.repair_change_text({
		"before_condition_summary": {"text": "Operational"},
		"after_condition_summary": {"text": "Operational"},
	})
	_assert_equal(unchanged_repair, "", "unchanged repair summary stays quiet")
	var missing_repair := SpaceStatusModel.repair_change_text({})
	_assert_equal(missing_repair, "", "missing repair summaries stay quiet")
	_assert_equal(
		SpaceStatusModel.damage_control_text({
			"repair_seed": 5151,
			"ship_name": "Local Freighter",
			"system": "shield_loss_dice",
			"repair_pool": "5D",
			"roll": {"total": 19},
			"difficulty": 15,
			"success": true,
			"repair_quote": {"difficulty_name": "Moderate", "field_time_rounds": 2, "yard_cost_credits": 980},
			"before_condition_summary": {"text": "Lightly Damaged, Shields -2D"},
			"after_condition_summary": {"text": "Lightly Damaged"},
			"station_assist": {
				"applies": true,
				"name": "Engineer prep",
				"pool_text": "1D",
				"banked_round": 4,
			},
		}, {"condition": {"worst_hull_severity": 2}}, 0),
		"Damage control seed 5151: 5D 19 vs 15 Moderate on Local Freighter shield loss dice, repaired. Assist Engineer prep +1D since station 4. Field 2 rounds/free; yard 980 cr. Lightly Damaged, Shields -2D -> Lightly Damaged. Condition: Lightly Damaged.",
		"damage-control success action text"
	)
	_assert_equal(
		SpaceStatusModel.damage_control_text({
			"ship_name": "Drill Target",
			"system": "weapons_disabled",
			"repair_pool": "4D",
			"roll": {"total": 8},
			"difficulty": 20,
			"success": false,
			"repair_quote": {"difficulty_name": "Very Difficult", "field_time_rounds": 4, "yard_cost_credits": 1200},
		}, {"condition": {"weapons_disabled": true}}, 77),
		"Damage control seed 77: 4D 8 vs 20 Very Difficult on Drill Target weapons disabled, not repaired. Field 4 rounds/free; yard 1200 cr. Condition: Operational | Weapons Disabled.",
		"damage-control failed action text with fallback seed"
	)
	_assert_equal(
		SpaceStatusModel.damage_control_text({
			"repair_seed": 88,
			"ship_name": "Hutt Courier",
			"system": "backup_relay",
			"repair_pool": "6D",
			"roll": {"total": 24},
			"difficulty": -1,
			"success": false,
			"repair_quote": {"can_field_repair": false, "difficulty_name": "Yard Only", "field_time_rounds": 0, "yard_cost_credits": 3900},
		}, {"condition": {"repairable_systems": ["backup_relay"]}}, 0),
		"Damage control seed 88: 6D 24 vs -1 Yard Only on Hutt Courier backup relay, not repaired. Field unavailable; yard 3900 cr. Condition: Operational.",
		"damage-control yard-only action text"
	)

	var assist_text := SpaceStatusModel.station_assist_applied_text({
		"station_assist": {
			"applies": true,
			"name": "Damage-control prep",
			"pool_text": "1D",
			"banked_round": 4,
		},
	})
	_assert_equal(assist_text, "Damage-control prep +1D since station 4", "applied station assist summary")
	var alias_assist_text := SpaceStatusModel.station_assist_applied_text({
		"station_assist": {
			"applies": true,
			"name": "Jump calculation",
			"pool_text": "1D",
			"target_action": "astrogation",
			"requested_target_action": "jump_calculation",
			"banked_round": 6,
		},
	})
	_assert_equal(alias_assist_text, "Jump calculation +1D for astrogation (jump calculation) since station 6", "applied station assist preserves requested alias")
	var unnamed_assist := SpaceStatusModel.station_assist_applied_text({
		"station_assist": {
			"applies": true,
			"name": "Sensor focus",
		},
	})
	_assert_equal(unnamed_assist, "Sensor focus", "applied station assist without pool")
	var no_assist := SpaceStatusModel.station_assist_applied_text({"station_assist": {"applies": false}})
	_assert_equal(no_assist, "", "missing station assist stays quiet")
	_assert_equal(
		SpaceStatusModel.station_assist_suffix({
			"station_assist": {
				"applies": true,
				"name": "Gunner bracketing",
				"pool_text": "1D",
				"banked_round": 3,
			},
		}),
		" Assist Gunner bracketing +1D since station 3.",
		"station assist suffix"
	)
	_assert_equal(SpaceStatusModel.station_assist_suffix({"station_assist": {"applies": false}}), "", "inactive station assist suffix stays quiet")
	_assert_equal(
		SpaceStatusModel.station_wound_text({
			"station_wound": {
				"applies": true,
				"crew_name": "Local Pilot",
				"wound_name": "Wounded",
				"penalty_dice": 1,
			},
		}),
		"Local Pilot Wounded -1D",
		"station wound text"
	)
	_assert_equal(
		SpaceStatusModel.station_wound_text({
			"station_wound": {
				"applies": true,
				"crew_name": "Local Gunner",
				"wound_name": "Incapacitated",
				"penalty_dice": 99,
				"action_blocked": true,
			},
		}),
		"Local Gunner Incapacitated station disabled",
		"station wound blocked text"
	)
	_assert_equal(
		SpaceStatusModel.station_wound_suffix({
			"station_wound": {
				"applies": true,
				"crew_name": "Engineer",
				"wound_name": "Wounded",
				"penalty_dice": 1,
			},
		}),
		" Wound Engineer Wounded -1D.",
		"station wound suffix"
	)
	_assert_equal(SpaceStatusModel.station_wound_suffix({"station_wound": {"applies": false}}), "", "inactive station wound stays quiet")
	_assert_equal(
		SpaceStatusModel.gunnery_station_wound_suffix({
			"attacker_station_wound": {
				"applies": true,
				"crew_name": "Gunner",
				"wound_name": "Wounded",
				"penalty_dice": 1,
			},
			"target_station_wound": {
				"applies": true,
				"crew_name": "Pilot",
				"wound_name": "Incapacitated",
				"penalty_dice": 99,
				"action_blocked": true,
			},
		}),
		" Wound attacker Gunner Wounded -1D; target Pilot Incapacitated station disabled.",
		"gunnery station wound suffix"
	)
	_assert_equal(SpaceStatusModel.station_replacement_text({"replaced_existing": false}), "", "station replacement stays quiet")
	_assert_equal(
		SpaceStatusModel.station_replacement_text({
			"replaced_existing": true,
			"replaced_assist": {"name": "Copilot vectors", "pool": "1D", "target_action": "maneuver"},
			"target_action": "maneuver",
		}),
		" Replaced Copilot vectors 1D for maneuver.",
		"station replacement with pool"
	)
	_assert_equal(
		SpaceStatusModel.station_replacement_text({
			"replaced_existing": true,
			"replaced_assist": {"name": "Sensor focus", "target_action": "sensors"},
		}),
		" Replaced Sensor focus for sensors.",
		"station replacement without pool"
	)
	_assert_equal(
		SpaceStatusModel.station_replacement_text({
			"replaced_existing": true,
			"target_action": "astrogation",
			"replaced_assist": {"name": "Jump calculation", "pool": "1D", "target_action": "astrogation", "requested_target_action": "jump_calculation"},
		}),
		" Replaced Jump calculation 1D for astrogation (jump calculation).",
		"station replacement preserves requested alias"
	)
	_assert_equal(
		SpaceStatusModel.shield_reroute_text({
			"shield_round": 2,
			"reroute_seed": 4242,
			"shield_pool": "5D",
			"roll": {"total": 17},
			"difficulty": 10,
			"requested_arcs": ["front", "rear"],
			"success": true,
		}),
		"Shields 2 seed 4242: 5D 17 vs 10, front, rear online.",
		"shield reroute action text"
	)
	_assert_equal(
		SpaceStatusModel.shield_reroute_text({
			"shield_round": 3,
			"shield_pool": "4D",
			"roll": {"total": 7},
			"difficulty": 15,
			"requested_arcs": ["left", "right", "rear"],
			"success": false,
			"station_assist": {
				"applies": true,
				"name": "Shield timing",
				"pool_text": "1D",
				"banked_round": 2,
			},
		}, 99),
		"Shields 3 seed 99: 4D 7 vs 15, left, right, rear failed. Assist Shield timing +1D since station 2.",
		"shield reroute fallback seed and assist text"
	)
	_assert_equal(
		SpaceStatusModel.station_assist_action_text({
			"station_round": 4,
			"assist_seed": 6161,
			"assist_pool": "4D",
			"roll": {"total": 18},
			"difficulty": 10,
			"station": "copilot",
			"success": true,
			"assist_name": "Copilot vectors",
			"target_action": "maneuver",
			"bonus_pool": "1D",
		}),
		"Station 4 seed 6161: 4D 18 vs 10, Copilot banked Copilot vectors for next maneuver (+1D).",
		"station assist action text"
	)
	_assert_equal(
		SpaceStatusModel.station_assist_action_text({
			"station_round": 6,
			"assist_seed": 6169,
			"assist_pool": "4D",
			"roll": {"total": 16},
			"difficulty": 10,
			"station": "navigator",
			"success": true,
			"assist_name": "Jump calculation",
			"requested_target_action": "jump_calculation",
			"target_action": "astrogation",
			"bonus_pool": "1D",
		}),
		"Station 6 seed 6169: 4D 16 vs 10, Navigator banked Jump calculation for next astrogation (jump calculation) (+1D).",
		"station assist action text preserves requested alias"
	)
	_assert_equal(
		SpaceStatusModel.station_assist_action_text({
			"station_round": 5,
			"assist_pool": "3D",
			"roll": {"total": 8},
			"difficulty": 12,
			"station": "navigator",
			"success": false,
			"assist_name": "Navigator timing",
			"target_action": "shield_reroute",
			"bonus_pool": "2D",
			"replaced_existing": true,
			"replaced_assist": {"name": "Old timing", "pool": "1D", "target_action": "shield_reroute"},
		}, 77),
		"Station 5 seed 77: 3D 8 vs 12, Navigator failed Navigator timing for next shield reroute (+2D). Replaced Old timing 1D for shield reroute.",
		"station assist fallback seed and replacement text"
	)
	_assert_equal(
		SpaceStatusModel.station_assist_action_text({
			"station_round": 7,
			"assist_seed": 6170,
			"assist_pool": "4D",
			"roll": {"total": 17},
			"difficulty": 10,
			"station": "navigator",
			"success": true,
			"assist_name": "Local jump prep",
			"requested_target_action": "local_jump",
			"target_action": "astrogation",
			"bonus_pool": "1D",
			"replaced_existing": true,
			"replaced_assist": {"name": "Jump calculation", "pool": "1D", "target_action": "astrogation", "requested_target_action": "jump_calculation"},
		}),
		"Station 7 seed 6170: 4D 17 vs 10, Navigator banked Local jump prep for next astrogation (local jump) (+1D). Replaced Jump calculation 1D for astrogation (jump calculation).",
		"station assist replacement text preserves old and new requested aliases"
	)
	_assert_equal(
		SpaceStatusModel.astrogation_plot_text({
			"astrogation_round": 2,
			"plot_seed": 9090,
			"action_pool": "5D",
			"roll": {"total": 22},
			"difficulty": 20,
			"calculation_penalty": 2,
			"astrogation_penalty": 3,
			"plot_name": "Plot local jump corridor",
			"success": true,
			"can_plot": true,
			"station_assist": {
				"applies": true,
				"name": "Navicomputer sync",
				"pool_text": "1D",
				"banked_round": 4,
			},
			"before_condition_summary": {"text": "Operational | Hyperdrive Calculations Slowed, Astrogation +3"},
			"after_condition_summary": {"text": "Operational"},
		}),
		"Astrogation 2 seed 9090: 5D 22 vs 20 +5 nav penalty, Plot local jump corridor plotted. Assist Navicomputer sync +1D since station 4. Operational | Hyperdrive Calculations Slowed, Astrogation +3 -> Operational",
		"astrogation plot action text"
	)
	_assert_equal(
		SpaceStatusModel.contact_identification_text({
			"identification_round": 3,
			"identify_seed": 4242,
			"sensor_pool": "5D",
			"roll": {"total": 19},
			"difficulty": 20,
			"track_penalty": 5,
			"contact_name": "Sensor Shadow",
			"success": false,
			"can_identify": true,
			"sensor_context": {"confidence_name": "Faint"},
		}),
		"Identify 3 seed 4242: 5D 19 vs 20 +5 track penalty, Sensor Shadow unresolved. Track Faint. ID: none.",
		"failed identification action text"
	)
	_assert_equal(
		SpaceStatusModel.contact_identification_text({
			"identification_round": 3,
			"identify_seed": 4242,
			"sensor_pool": "4D",
			"roll": {"total": 14},
			"difficulty": 20,
			"track_penalty": 5,
			"contact_name": "Sensor Shadow",
			"success": false,
			"can_identify": true,
			"sensor_context": {"confidence_name": "Faint"},
			"station_wound": {
				"applies": true,
				"crew_name": "Sensor Operator",
				"wound_name": "Wounded",
				"penalty_dice": 1,
			},
		}),
		"Identify 3 seed 4242: 4D 14 vs 20 +5 track penalty, Sensor Shadow unresolved. Track Faint. ID: none. Wound Sensor Operator Wounded -1D.",
		"identification action text reports station wound"
	)
	_assert_equal(
		SpaceStatusModel.contact_identification_text({
			"identification_round": 4,
			"identify_seed": 4243,
			"sensor_pool": "6D",
			"roll": {"total": 24},
			"difficulty": 15,
			"track_penalty": 0,
			"contact_name": "Sensor Shadow",
			"success": true,
			"can_identify": true,
			"sensor_context": {"confidence_name": "Solid"},
			"identity": {
				"declared_name": "Masked Snub Contact",
				"affiliation": "unknown",
				"threat": "hostile",
			},
			"station_assist": {
				"applies": true,
				"name": "Sensor focus",
				"pool_text": "1D",
				"banked_round": 6,
			},
		}),
		"Identify 4 seed 4243: 6D 24 vs 15, Sensor Shadow identified. Track Solid. ID: Masked Snub Contact [unknown, hostile]. Assist Sensor focus +1D since station 6.",
		"successful identification action text"
	)
	_assert_equal(
		SpaceStatusModel.comms_hail_text({
			"comms_round": 2,
			"hail_seed": 5252,
			"communications_pool": "5D",
			"roll": {"total": 17},
			"difficulty": 25,
			"identity_penalty": 5,
			"threat_modifier": 10,
			"contact_name": "Sensor Shadow",
			"success": false,
			"can_hail": true,
			"identified": false,
			"response": "Masked contact stays dark and keeps weapons posture.",
			"weapon_solution_pressure": {
				"applies": true,
				"contact_name": "Sensor Shadow",
				"prior_rounds": 0,
				"current_rounds": 1,
			},
		}),
		"Comms 2 seed 5252: 5D 17 vs 25 +15 comms pressure, Sensor Shadow no reply (unidentified). Masked contact stays dark and keeps weapons posture. Escalated lock: Sensor Shadow 0->1.",
		"failed comms hail text"
	)
	_assert_equal(
		SpaceStatusModel.comms_hail_text({
			"comms_round": 2,
			"hail_seed": 5252,
			"communications_pool": "5D",
			"roll": {"total": 17},
			"difficulty": 25,
			"identity_penalty": 5,
			"threat_modifier": 10,
			"contact_name": "Sensor Shadow",
			"success": false,
			"can_hail": true,
			"identified": false,
			"response": "Masked contact stays dark and keeps weapons posture.",
			"weapon_solution_pressure": {
				"applies": true,
				"contact_name": "Sensor Shadow",
				"prior_rounds": 1,
				"current_rounds": 2,
				"fire_ready": true,
			},
		}),
		"Comms 2 seed 5252: 5D 17 vs 25 +15 comms pressure, Sensor Shadow no reply (unidentified). Masked contact stays dark and keeps weapons posture. Escalated lock: Sensor Shadow 1->2 (ready).",
		"failed comms hail text shows ready lock"
	)
	_assert_equal(
		SpaceStatusModel.comms_hail_text({
			"comms_round": 3,
			"hail_seed": 5253,
			"communications_pool": "6D",
			"roll": {"total": 24},
			"difficulty": 20,
			"identity_penalty": 0,
			"threat_modifier": 10,
			"contact_name": "Sensor Shadow",
			"success": true,
			"can_hail": true,
			"identified": true,
			"response": "Masked contact clicks open for a breath, then cuts transmission.",
			"weapon_solution_delay": {
				"applies": true,
				"contact_name": "Sensor Shadow",
				"prior_rounds": 2,
				"remaining_rounds": 1,
			},
		}),
		"Comms 3 seed 5253: 6D 24 vs 20 +10 comms pressure, Sensor Shadow open (identified). Masked contact clicks open for a breath, then cuts transmission. Delayed lock: Sensor Shadow 2->1.",
		"successful comms hail reports weapon-solution delay"
	)
	_assert_equal(
		SpaceStatusModel.comms_hail_text({
			"comms_round": 3,
			"hail_seed": 5253,
			"communications_pool": "6D",
			"roll": {"total": 26},
			"difficulty": 20,
			"identity_penalty": 0,
			"threat_modifier": 10,
			"contact_name": "Sensor Shadow",
			"success": true,
			"can_hail": true,
			"identified": true,
			"response": "Masked contact clicks open for a breath, then cuts transmission.",
			"station_assist": {
				"applies": true,
				"name": "Traffic phrasebook",
				"pool_text": "1D",
				"banked_round": 7,
			},
		}),
		"Comms 3 seed 5253: 6D 26 vs 20 +10 comms pressure, Sensor Shadow open (identified). Masked contact clicks open for a breath, then cuts transmission. Assist Traffic phrasebook +1D since station 7.",
		"successful comms hail text"
	)
	_assert_equal(SpaceStatusModel.targeting_context_text({}), "Track: Unresolved.", "empty targeting context")
	_assert_equal(
		SpaceStatusModel.targeting_context_text({
			"confidence_name": "Solid",
			"targeting_hint": "Useful sensor track for targeting context",
		}),
		"Track: Solid - Useful sensor track for targeting context.",
		"tracked targeting context"
	)
	_assert_equal(
		SpaceStatusModel.targeting_context_text({
			"confidence_name": "Partial",
			"targeting_hint": "Rough sensor track; firing data should be treated cautiously",
			"gunnery_difficulty_modifier": 3,
		}),
		"Track: Partial - Rough sensor track; firing data should be treated cautiously (+3 difficulty).",
		"targeting context reports gunnery difficulty modifier"
	)
	_assert_equal(
		SpaceStatusModel.targeting_context_text({"confidence_name": "Partial"}),
		"Track: Partial - No resolved sensor track.",
		"targeting context fallback hint"
	)
	_assert_equal(
		SpaceStatusModel.gunnery_damage_text({
			"hit": false,
		}),
		"no damage roll",
		"missed gunnery damage text"
	)
	_assert_equal(
		SpaceStatusModel.gunnery_damage_text({
			"hit": true,
			"damage": {
				"damage_roll": {"pool": "6D"},
				"soak_roll": {"pool": "4D"},
			},
			"target_hull_pool": "3D",
			"target_shield_pool": "1D",
			"starship_damage": {"name": "Lightly Damaged"},
			"system_effect": {"key": "maneuverability_minus_1d", "name": "Maneuverability -1D"},
			"passenger_damage": {
				"applies": true,
				"affected_group": "passengers",
				"damage_pool": "1D",
				"member_wounds": [
					{"name": "Pilot", "wound": {"name": "Wounded"}},
				],
			},
		}),
		"6D vs soak 4D (hull 3D + shields 1D) => Lightly Damaged [Maneuverability -1D]. Passengers take 1D. Pilot: Wounded.",
		"hit gunnery damage text"
	)
	_assert_equal(
		SpaceStatusModel.gunnery_action_text({
			"gunnery_round": 3,
			"exchange_seed": 5150,
			"scaled_attack_pool": "5D",
			"attack_roll": {"total": 10},
			"scaled_defense_pool": "3D",
			"difficulty": 12,
			"hit": false,
		}, {}, {}, {}, 0),
		"Gunnery 3 seed 5150: 5D 10 vs 3D 12 (miss). no damage roll Track: Unresolved. Condition: Operational.",
		"missed gunnery action text"
	)
	_assert_equal(
		SpaceStatusModel.gunnery_action_text({
			"gunnery_round": 3,
			"exchange_seed": 5150,
			"scaled_attack_pool": "4D",
			"attack_roll": {"total": 10},
			"scaled_defense_pool": "2D",
			"difficulty": 12,
			"hit": false,
			"attacker_station_wound": {
				"applies": true,
				"crew_name": "Gunner",
				"wound_name": "Wounded",
				"penalty_dice": 1,
			},
			"target_station_wound": {
				"applies": true,
				"crew_name": "Pilot",
				"wound_name": "Wounded",
				"penalty_dice": 1,
			},
		}, {}, {}, {}, 0),
		"Gunnery 3 seed 5150: 4D 10 vs 2D 12 (miss). no damage roll Wound attacker Gunner Wounded -1D; target Pilot Wounded -1D. Track: Unresolved. Condition: Operational.",
		"gunnery action text reports station wounds"
	)
	_assert_equal(
		SpaceStatusModel.gunnery_action_text({
			"gunnery_round": 4,
			"scaled_attack_pool": "6D",
			"attack_roll": {"total": 21},
			"scaled_defense_pool": "3D",
			"difficulty": 15,
			"hit": true,
			"damage": {
				"damage_roll": {"pool": "6D"},
				"soak_roll": {"pool": "4D"},
			},
			"target_hull_pool": "3D",
			"target_shield_pool": "1D",
			"starship_damage": {"name": "Lightly Damaged"},
			"system_effect": {"key": "maneuverability_minus_1d", "name": "Maneuverability -1D"},
			"passenger_damage": {
				"applies": true,
				"affected_group": "passengers",
				"damage_pool": "1D",
				"member_wounds": [
					{"name": "Pilot", "wound": {"name": "Wounded"}},
				],
			},
			"station_assist": {
				"applies": true,
				"name": "Gunner bracketing",
				"pool_text": "1D",
				"banked_round": 3,
			},
			"target_sensor_context": {
				"confidence_name": "Solid",
				"targeting_hint": "Useful",
			},
		}, {"condition": {"worst_hull_severity": 2, "shield_loss_dice": 1}}, {"applies": true, "prior_rounds": 2}, {"applies": false, "reason": "requires_weapon_solution"}, 6161),
		"Gunnery 4 seed 6161: 6D 21 vs 3D 15 (hit). 6D vs soak 4D (hull 3D + shields 1D) => Lightly Damaged [Maneuverability -1D]. Passengers take 1D. Pilot: Wounded. Assist Gunner bracketing +1D since station 3. Track: Solid - Useful. Condition: Lightly Damaged | Shields -1D. Disrupted lock: 2 round(s). Counterfire: requires weapon solution.",
		"hit gunnery action text"
	)
	_assert_equal(SpaceStatusModel.lock_disruption_text({"applies": false}), "", "inactive lock disruption stays quiet")
	_assert_equal(
		SpaceStatusModel.lock_disruption_text({"applies": true, "prior_rounds": 2}),
		" Disrupted lock: 2 round(s).",
		"active lock disruption summary"
	)
	_assert_equal(SpaceStatusModel.counterfire_text({}), "", "empty counterfire stays quiet")
	_assert_equal(SpaceStatusModel.counterfire_text({"applies": false, "reason": "not_configured"}), "", "unconfigured counterfire stays quiet")
	_assert_equal(
		SpaceStatusModel.counterfire_text({"applies": false, "reason": "requires_weapon_solution"}),
		" Counterfire: requires weapon solution.",
		"blocked counterfire reason"
	)
	_assert_equal(
		SpaceStatusModel.counterfire_text({
			"applies": true,
			"event": {
				"scaled_attack_pool": "4D",
				"attack_roll": {"total": 18},
				"difficulty": 12,
				"hit": true,
				"starship_damage": {"name": "Lightly Damaged"},
			},
			"consumed_weapon_solution": {"applies": true, "prior_rounds": 2},
			"attacker_condition": {
				"worst_hull_severity": 2,
				"shield_loss_dice": 1,
				"controls_ionized": 1,
			},
		}),
		" Counterfire: 4D 18 vs 12 (hit), Lightly Damaged. Spent lock: 2 round(s). Condition: Lightly Damaged | Shields -1D, 1 Controls Ionized.",
		"applied counterfire summary"
	)
	_assert_equal(SpaceStatusModel.ship_condition_text({}), "Condition: Operational.", "empty ship condition text")
	_assert_equal(
		SpaceStatusModel.ship_condition_text({
			"condition": {
				"worst_hull_severity": 3,
				"shield_loss_dice": 2,
				"controls_ionized": 99,
				"hyperdrive_calculation_penalty": 1,
				"astrogation_difficulty_penalty": 5,
				"crew_wounds": {
					"pilot": {"name": "Pilot", "wound": {"name": "Wounded", "severity": 2}},
					"gunner": {"name": "Gunner", "wound": {"name": "Stunned", "severity": 0}},
				},
			},
		}),
		"Condition: Heavily Damaged | Shields -2D, Controls Dead, Hyperdrive Calculations Slowed, Astrogation +5 | 1 crew wounded.",
		"rich ship condition text"
	)
	_assert_equal(SpaceStatusModel.maneuver_hazard_text({}), "", "empty hazard text stays quiet")
	_assert_equal(
		SpaceStatusModel.maneuver_hazard_text({
			"crossed": [{"name": "Debris Lane"}],
			"difficulty_modifier": 5,
		}),
		" Hazard: Debris Lane +5.",
		"hazard text with modifier"
	)
	_assert_equal(
		SpaceStatusModel.maneuver_hazard_text({
			"crossed": [{"name": "Traffic Slot"}],
			"difficulty_modifier": 0,
		}),
		" Hazard: Traffic Slot.",
		"hazard text without modifier"
	)
	_assert_equal(
		SpaceStatusModel.maneuver_hazard_text({
			"crossed": [{"name": "Approach Debris"}, {"name": "Traffic Slot"}],
			"difficulty_modifier": 10,
		}),
		" Hazard: Approach Debris, Traffic Slot +10.",
		"multi-hazard text names first two hazards"
	)
	_assert_equal(
		SpaceStatusModel.maneuver_hazard_text({
			"crossed": [{"name": "Approach Debris"}, {"name": "Traffic Slot"}, {"name": "Dust Wake"}],
			"difficulty_modifier": 15,
		}),
		" Hazard: Approach Debris, Traffic Slot +1 more +15.",
		"multi-hazard text summarizes extra hazards"
	)
	_assert_equal(
		SpaceStatusModel.hazard_detail_text({
			"name": "Approach Debris",
			"radius": 8,
			"difficulty_modifier": 5,
			"collision_possible": true,
		}),
		"Hazard: Approach Debris +5 piloting difficulty, radius 8.0, collision risk.",
		"clickable hazard detail with collision risk"
	)
	_assert_equal(
		SpaceStatusModel.hazard_detail_text({
			"name": "Traffic Slot",
			"radius": 12,
			"difficulty_modifier": 0,
			"collision_possible": false,
		}),
		"Hazard: Traffic Slot no piloting modifier, radius 12.0, no collision risk.",
		"clickable hazard detail without collision risk"
	)
	_assert_equal(
		SpaceStatusModel.hazard_detail_text({
			"id": "approach_debris",
			"name": "Approach Debris",
			"radius": 8,
			"difficulty_modifier": 5,
			"collision_possible": true,
		}, {
			"difficulty": 20,
			"hazard_context": {
				"crossed": [{"id": "approach_debris", "name": "Approach Debris"}],
			},
		}),
		"Hazard: Approach Debris +5 piloting difficulty, radius 8.0, collision risk. Current maneuver crosses this hazard; total difficulty 20.",
		"clickable hazard detail with route crossing preview"
	)
	_assert_equal(
		SpaceStatusModel.hazard_detail_text({
			"id": "traffic_slot",
			"name": "Traffic Slot",
			"radius": 12,
			"difficulty_modifier": 0,
			"collision_possible": false,
		}, {
			"difficulty": 15,
			"hazard_context": {
				"crossed": [{"id": "approach_debris", "name": "Approach Debris"}],
			},
		}),
		"Hazard: Traffic Slot no piloting modifier, radius 12.0, no collision risk. Current maneuver avoids this hazard; total difficulty 15.",
		"clickable hazard detail with route avoidance preview"
	)
	_assert_equal(SpaceStatusModel.crew_wound_text({}), "", "empty crew wound text stays quiet")
	_assert_equal(
		SpaceStatusModel.crew_wound_text({
			"member_wounds": [
				{"name": "Pilot", "wound": {"name": "Wounded"}},
			],
		}),
		" Pilot: Wounded.",
		"crew wound text"
	)
	_assert_equal(SpaceStatusModel.maneuver_collision_text({}), "", "empty collision text stays quiet")
	_assert_equal(
		SpaceStatusModel.maneuver_collision_text({"reason": "wild_spin_no_obstacle"}),
		" No obstacle: wild spin.",
		"wild spin collision text"
	)
	_assert_equal(
		SpaceStatusModel.maneuver_collision_text({
			"applies": true,
			"damage_pool": "4D",
			"hull_soak_pool": "3D",
			"starship_damage": {"name": "Lightly Damaged"},
			"passenger_damage": {
				"member_wounds": [
					{"name": "Engineer", "wound": {"name": "Stunned"}},
				],
			},
		}),
		" Collision 4D vs hull 3D => Lightly Damaged. Engineer: Stunned.",
		"collision text with crew wound"
	)
	_assert_equal(SpaceStatusModel.weapon_solution_break_text({"weapon_solutions_broken": 0}), "", "empty break-lock text stays quiet")
	_assert_equal(
		SpaceStatusModel.weapon_solution_break_text({"weapon_solutions_broken": 2}),
		" Broke 2 weapon solution(s).",
		"break-lock text"
	)
	_assert_equal(
		SpaceStatusModel.maneuver_action_text({
			"maneuver_round": 6,
			"maneuver_seed": 7070,
			"action_pool": "6D",
			"roll": {"total": 24},
			"difficulty": 15,
			"heading_degrees": 90,
			"actual_move": 24.0,
			"success": true,
			"station_assist": {
				"applies": true,
				"name": "Copilot vectors",
				"pool_text": "1D",
				"banked_round": 5,
			},
		}, {"condition": {"worst_hull_severity": 1}}, 0),
		"Maneuver 6 seed 7070: 6D 24 vs 15, heading 90, move 24.0 (clean). Assist Copilot vectors +1D since station 5. Condition: Shield/Controls Hit.",
		"clean maneuver action text"
	)
	_assert_equal(
		SpaceStatusModel.maneuver_action_text({
			"maneuver_round": 7,
			"action_pool": "3D",
			"roll": {"total": 5},
			"difficulty": 25,
			"heading_degrees": 135,
			"actual_move": 0.0,
			"success": false,
			"failure": {"name": "Major Collision / Spinout"},
			"hazard_context": {
				"crossed": [{"name": "Debris Cloud"}],
				"difficulty_modifier": 5,
			},
			"collision": {
				"applies": true,
				"damage_pool": "10D",
				"hull_soak_pool": "4D",
				"starship_damage": {"name": "Heavily Damaged"},
				"passenger_damage": {
					"member_wounds": [
						{"name": "Pilot", "wound": {"name": "Wounded"}},
					],
				},
			},
			"weapon_solutions_broken": 1,
		}, {"condition": {"worst_hull_severity": 3, "crew_wounds": {"pilot": {"wound": {"severity": 2}}}}}, 8080),
		"Maneuver 7 seed 8080: 3D 5 vs 25, heading 135, move 0.0 (Major Collision / Spinout). Hazard: Debris Cloud +5. Collision 10D vs hull 4D => Heavily Damaged. Pilot: Wounded. Broke 1 weapon solution(s). Condition: Heavily Damaged | 1 crew wounded.",
		"failed maneuver action text with hazard collision and broken lock"
	)

	var new_reveal_text := SpaceStatusModel.newly_revealed_text(
		["sensor_shadow", "unknown_trace"],
		contacts
	)
	_assert_equal(new_reveal_text, " New: Sensor Shadow, unknown_trace.", "new reveal text uses contact names and id fallback")
	var no_new_reveal_text := SpaceStatusModel.newly_revealed_text([], contacts)
	_assert_equal(no_new_reveal_text, "", "empty new reveal text stays quiet")
	var sweep_text := SpaceStatusModel.sensor_sweep_text(
		{
			"scan_round": 3,
			"roll": {"pool": "5D", "total": 17},
			"events": [
				{"success": true, "contact_name": "Visible Patrol", "confidence_name": "Solid"},
				{"success": false, "contact_name": "Sensor Shadow", "confidence_name": "Missed"},
			],
			"newly_revealed_contacts": ["sensor_shadow"],
			"state": all_known_state,
			"station_assist": {
				"applies": true,
				"name": "Sensor focus",
				"pool_text": "1D",
				"banked_round": 4,
			},
		},
		contacts,
		99
	)
	_assert_equal(sweep_text, "Sensor sweep 3 seed 99: 5D 17 => Visible Patrol. Track: Visible Patrol Solid. New: Sensor Shadow. Known 2/2, hidden 0. Assist Sensor focus +1D since station 4.", "sensor sweep summary")
	var empty_sweep_text := SpaceStatusModel.sensor_sweep_text(
		{
			"scan_round": 4,
			"roll": {"pool": "4D", "total": 6},
			"events": [{"success": false, "contact_name": "Sensor Shadow"}],
			"state": state,
		},
		contacts,
		100
	)
	_assert_equal(empty_sweep_text, "Sensor sweep 4 seed 100: 4D 6 => none. Known 1/2, hidden 1.", "empty sensor sweep summary")
	var wounded_sweep_text := SpaceStatusModel.sensor_sweep_text(
		{
			"scan_round": 5,
			"roll": {"pool": "3D", "total": 11},
			"events": [{"success": false, "contact_name": "Sensor Shadow", "confidence_name": "Missed"}],
			"state": state,
			"station_wound": {
				"applies": true,
				"crew_name": "Sensor Operator",
				"wound_name": "Wounded",
				"penalty_dice": 1,
			},
		},
		contacts,
		101
	)
	_assert_equal(wounded_sweep_text, "Sensor sweep 5 seed 101: 3D 11 => none. Known 1/2, hidden 1. Wound Sensor Operator Wounded -1D.", "sensor sweep summary reports station wound")
	var traffic_text := SpaceStatusModel.traffic_tick_text(
		{
			"movement_round": 7,
			"events": [
				{"can_move": true, "contact_name": "Patrol Skiff"},
				{
					"can_move": true,
					"contact_name": "Sensor Shadow",
					"holds_range": true,
					"weapon_solution": true,
					"weapon_solution_rounds": 1,
					"fire_ready_rounds": 2,
					"fire_ready": false,
					"range_name": "Short",
					"engagement_context": {"targeting": {"confidence_name": "Partial"}},
				},
				{"can_move": false, "contact_name": "Disabled Freighter", "movement_blocked_reason": "drives_disabled"},
				{"can_move": false, "contact_name": "Spinning Courier", "movement_blocked_reason": "control_locked"},
			],
			"condition_events": [
				{
					"changed": true,
					"ship_name": "Local Freighter",
					"after_summary": "Lightly Damaged, Controls Ionized",
				},
			],
		},
		true
	)
	_assert_equal(traffic_text, "Live traffic 7: moved Patrol Skiff. Holding range: Sensor Shadow. Weapon solution: Sensor Shadow Short 1/2 track Partial. Blocked: Disabled Freighter drives disabled, Spinning Courier control locked. Conditions ticked: Local Freighter -> Lightly Damaged, Controls Ionized.", "live traffic summary")
	_assert_equal(
		SpaceStatusModel.ready_hostile_fire_text([
			{
				"contact_name": "Sensor Shadow",
				"range_name": "Short",
				"weapon_solution_rounds": 2,
				"fire_ready_rounds": 2,
				"targeting_context": {"confidence_name": "Partial"},
			},
		]),
		" Ready hostile fire: Sensor Shadow Short 2/2 track Partial.",
		"ready hostile fire text"
	)
	_assert_equal(
		SpaceStatusModel.automatic_hostile_fire_text([
			{
				"applies": true,
				"contact_name": "Sensor Shadow",
				"event": {
					"hit": true,
					"attack_roll": {"total": 18},
					"difficulty": 11,
					"starship_damage": {"name": "Lightly Damaged"},
				},
				"consumed_weapon_solution": {"applies": true, "prior_rounds": 2},
				"player_condition": {"worst_hull_severity": 1},
			},
			{"applies": false, "contact_name": "Broken Droid", "reason": "weapons_disabled", "consumed_weapon_solution": {"applies": true, "prior_rounds": 3}},
			{"applies": false, "contact_name": "Wreck Shooter", "reason": "player_destroyed", "consumed_weapon_solution": {"applies": true, "prior_rounds": 2}},
			{"applies": false, "contact_name": "Late Shooter", "reason": "player_destroyed_by_prior_fire", "consumed_weapon_solution": {"applies": true, "prior_rounds": 2}},
		]),
		" Hostile fire: Sensor Shadow 18 vs 11 hit, Lightly Damaged, spent 2, Condition: Shield/Controls Hit, Broken Droid blocked: weapons disabled, cleared 3, Wreck Shooter blocked: player destroyed, cleared 2, Late Shooter blocked: player destroyed by prior fire, cleared 2.",
		"automatic hostile fire text"
	)
	var ready_traffic_text := SpaceStatusModel.traffic_tick_text(
		{
			"movement_round": 8,
			"events": [
				{
					"can_move": true,
					"contact_name": "Sensor Shadow",
					"holds_range": true,
					"weapon_solution": true,
					"weapon_solution_rounds": 2,
					"fire_ready_rounds": 2,
					"fire_ready": true,
					"range_name": "Short",
					"engagement_context": {"targeting": {"confidence_name": "Partial"}},
				},
			],
			"ready_hostile_fire_events": [
				{
					"contact_name": "Sensor Shadow",
					"range_name": "Short",
					"weapon_solution_rounds": 2,
					"fire_ready_rounds": 2,
					"targeting_context": {"confidence_name": "Partial"},
				},
			],
			"automatic_hostile_fire_events": [
				{
					"applies": true,
					"contact_name": "Sensor Shadow",
					"event": {
						"hit": false,
						"attack_roll": {"total": 9},
						"difficulty": 11,
					},
					"consumed_weapon_solution": {"applies": true, "prior_rounds": 2},
					"player_condition": {"shield_loss_dice": 1},
				},
			],
		},
		true
	)
	_assert_equal(ready_traffic_text, "Live traffic 8: moved none. Holding range: Sensor Shadow. Weapon solution: Sensor Shadow Short ready track Partial. Ready hostile fire: Sensor Shadow Short 2/2 track Partial. Hostile fire: Sensor Shadow 9 vs 11 miss, no damage, spent 2, Condition: Operational | Shields -1D.", "ready hostile fire traffic summary")
	var manual_traffic_text := SpaceStatusModel.traffic_tick_text(
		{
			"movement_round": 9,
			"events": [{"can_move": true, "contact_name": "Patrol Skiff"}],
		},
		false
	)
	_assert_equal(manual_traffic_text, "Traffic 9: moved Patrol Skiff.", "manual traffic step summary")
	var quiet_traffic_text := SpaceStatusModel.traffic_tick_text(
		{
			"movement_round": 8,
			"events": [{"can_move": false, "contact_name": "Docked Transport"}],
			"condition_events": [{"changed": false, "ship_name": "Local Freighter"}],
		}
	)
	_assert_equal(quiet_traffic_text, "Traffic 8: moved none.", "quiet traffic summary")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("space_status_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
