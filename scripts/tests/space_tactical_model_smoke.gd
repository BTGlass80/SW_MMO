extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	var rules_script: GDScript = load("res://scripts/rules/d6_rules.gd")
	var rules: Node = rules_script.new()
	var model_script: GDScript = load("res://scripts/rules/space_tactical_model.gd")
	var model: RefCounted = model_script.new()

	var state: Dictionary = model.initial_state()
	_assert_equal(state["scan_round"], 1, "initial scan round")
	_assert_equal(state["identification_round"], 1, "initial identification round")
	_assert_equal(state["comms_round"], 1, "initial comms round")
	_assert_equal(state["gunnery_round"], 1, "initial gunnery round")
	_assert_equal(state["shield_round"], 1, "initial shield round")
	_assert_equal(state["astrogation_round"], 1, "initial astrogation round")
	_assert_equal(state["maneuver_round"], 1, "initial maneuver round")
	_assert_equal(state["station_round"], 1, "initial station round")
	_assert_equal(state["movement_round"], 1, "initial movement round")
	_assert_equal(rules.pool_to_string(state["sensor_pool"]), "4D", "initial sensor pool")
	_assert_equal(state["sensor_contact_confidence"], {}, "initial sensor confidence store")
	_assert_equal(state["identified_contacts"], {}, "initial identified contact store")
	_assert_equal(state["contact_dispositions"], {}, "initial contact disposition store")

	_assert_equal(model.range_name_for_distance(10.0), "Point Blank", "point blank range")
	_assert_equal(model.range_name_for_distance(60.0), "Short", "short range")
	_assert_equal(model.range_name_for_distance(120.0), "Medium", "medium range")
	_assert_equal(model.range_name_for_distance(220.0), "Long", "long range")
	_assert_equal(model.range_name_for_distance(260.0), "Extreme", "extreme range")
	var arc_target := {"position": {"x": 0, "y": 0}, "heading_degrees": 0}
	_assert_equal(model.incoming_arc_for_attack({"position": {"x": 10, "y": 0}}, arc_target), "front", "incoming front arc")
	_assert_equal(model.incoming_arc_for_attack({"position": {"x": -10, "y": 0}}, arc_target), "rear", "incoming rear arc")
	_assert_equal(model.incoming_arc_for_attack({"position": {"x": 0, "y": 10}}, arc_target), "right", "incoming right arc")
	_assert_equal(model.incoming_arc_for_attack({"position": {"x": 0, "y": -10}}, arc_target), "left", "incoming left arc")
	_assert_equal(model.incoming_arc_for_gunnery({"position": {"x": 0, "y": -10}}, arc_target), "left", "gunnery arc uses maneuver-derived arc")
	_assert_equal(model.incoming_arc_for_gunnery({"target_arc": "rear", "position": {"x": 0, "y": -10}}, arc_target), "rear", "attacker target arc overrides derived arc")
	_assert_equal(model.shield_difficulty_for_arc_count(1), 5, "one shield arc difficulty")
	_assert_equal(model.shield_difficulty_for_arc_count(4), 20, "four shield arc difficulty")
	_assert_equal(model.sensor_confidence_for_margin(-1)["key"], "missed", "negative sensor margin missed")
	_assert_equal(model.sensor_confidence_for_margin(0)["key"], "faint", "zero sensor margin faint")
	_assert_equal(model.sensor_confidence_for_margin(4)["key"], "partial", "partial sensor margin")
	_assert_equal(model.sensor_confidence_for_margin(9)["key"], "solid", "solid sensor margin")
	_assert_equal(model.sensor_confidence_for_margin(13)["key"], "clear", "clear sensor margin")
	_assert_equal(model.sensor_confidence_rank("missed"), 0, "missed confidence rank")
	_assert_equal(model.sensor_confidence_rank("solid") > model.sensor_confidence_rank("partial"), true, "solid ranks above partial")
	_assert_equal(model.sensor_confidence_for_contact(state, "unknown")["key"], "unresolved", "unknown contact has unresolved track")
	_assert_equal(model.sensor_targeting_difficulty_modifier("unresolved"), 10, "unresolved targeting penalty")
	_assert_equal(model.sensor_targeting_difficulty_modifier("faint"), 6, "faint targeting penalty")
	_assert_equal(model.sensor_targeting_difficulty_modifier("partial"), 3, "partial targeting penalty")
	_assert_equal(model.sensor_targeting_difficulty_modifier("solid"), 1, "solid targeting penalty")
	_assert_equal(model.sensor_targeting_difficulty_modifier("clear"), 0, "clear targeting penalty")
	_assert_equal(model.movement_failure_for_margin(2)["key"], "slight_slip", "slight movement failure")
	_assert_equal(model.movement_failure_for_margin(5)["move_fraction"], 0.5, "slip completes half move")
	_assert_equal(model.movement_failure_for_margin(9)["key"], "spin", "spin movement failure")
	_assert_equal(rules.pool_to_string(model.collision_damage_pool_for_speed("cautious")), "2D", "cautious collision damage")
	_assert_equal(rules.pool_to_string(model.collision_damage_pool_for_speed("cruise")), "4D", "cruise collision damage")
	_assert_equal(rules.pool_to_string(model.collision_damage_pool_for_speed("high speed")), "6D", "high-speed collision damage")
	_assert_equal(rules.pool_to_string(model.collision_damage_pool_for_speed("all-out")), "10D", "all-out collision damage")
	_assert_equal(model.collision_modifier_dice_for_failure("minor_collision_or_wild_spin"), -3, "minor collision subtracts damage dice")
	_assert_equal(model.collision_modifier_dice_for_failure("major_collision_or_spinout"), 4, "major collision adds damage dice")
	_assert_equal(rules.pool_to_string(model.collision_damage_pool_for_failure(rules, "cruise", "minor_collision_or_wild_spin")), "1D", "minor cruise collision pool")
	_assert_equal(rules.pool_to_string(model.collision_damage_pool_for_failure(rules, "all-out", "major_collision_or_spinout")), "14D", "major all-out collision pool")
	var hazard_context: Dictionary = model.maneuver_hazard_context(Vector2(0, 0), Vector2(20, 20), [
		{"id": "debris", "name": "Debris", "position": {"x": 12, "y": 12}, "radius": 4, "difficulty_modifier": 5, "collision_possible": true},
	])
	_assert_equal(hazard_context["crossed"].size(), 1, "maneuver path crosses hazard")
	_assert_equal(hazard_context["difficulty_modifier"], 5, "crossed hazard modifies difficulty")
	_assert_equal(hazard_context["collision_possible"], true, "crossed hazard can become collision")
	var route_preview: Dictionary = model.maneuver_route_preview(
		{"position": {"x": 0, "y": 0}, "heading_degrees": 0},
		{"difficulty": 10, "modifier": 5, "turn_degrees": 45, "move_units": 28, "hazards": [
			{"id": "debris", "name": "Debris", "position": {"x": 12, "y": 12}, "radius": 8, "difficulty_modifier": 5, "collision_possible": true},
		]}
	)
	_assert_equal(route_preview["hazard_context"]["crossed"].size(), 1, "route preview records crossed hazard")
	_assert_equal(route_preview["difficulty"], 20, "route preview includes base, maneuver, and hazard difficulty")
	_assert_equal(model.starship_damage_for_margin(-1)["key"], "no_damage", "negative starship margin")
	_assert_equal(model.starship_damage_for_margin(0)["key"], "shields_blown_or_controls_ionized", "zero starship margin")
	_assert_equal(model.starship_damage_for_margin(8)["key"], "lightly_damaged", "light starship damage")
	_assert_equal(model.starship_damage_for_margin(12)["key"], "heavily_damaged", "heavy starship damage")
	_assert_equal(model.starship_damage_for_margin(15)["key"], "severely_damaged", "severe starship damage")
	_assert_equal(model.starship_damage_for_margin(16)["key"], "destroyed", "destroyed starship damage")
	_assert_equal(model.starship_damage_for_margin(8, "ion")["key"], "two_controls_ionized", "ion starship damage")
	_assert_equal(model.starship_damage_for_margin(16, "ion")["key"], "controls_dead", "dead ion controls")
	_assert_equal(model.starship_system_effect_for_damage("lightly_damaged", 1)["key"], "maneuverability_minus_1d", "light system roll 1")
	_assert_equal(model.starship_system_effect_for_damage("heavily_damaged", 5)["key"], "shields_minus_2d_or_two_controls_ionized", "heavy system roll 5")
	_assert_equal(model.starship_system_effect_for_damage("severely_damaged", 6)["key"], "destroyed", "severe system roll 6")
	_assert_equal(rules.pool_to_string(model.passenger_damage_pool_for_starship_damage("lightly_damaged")), "1D", "light passenger damage")
	_assert_equal(rules.pool_to_string(model.passenger_damage_pool_for_starship_damage("heavily_damaged")), "3D", "heavy passenger damage")
	_assert_equal(rules.pool_to_string(model.passenger_damage_pool_for_starship_damage("severely_damaged")), "6D", "severe passenger damage")
	_assert_equal(rules.pool_to_string(model.passenger_damage_pool_for_starship_damage("destroyed")), "12D", "destroyed passenger damage")
	_assert_equal(model.passenger_damage_group_for_system_effect({"key": "weapon_emplacement_destroyed"}), "gunners", "weapon hit affects gunners")
	_assert_equal(model.passenger_damage_group_for_system_effect({"key": "dead_in_space"}), "passengers", "non-weapon hit affects passengers")
	var condition_ship := {"shields": "1D"}
	var shield_loss: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, {}, model.starship_damage_for_margin(0))
	_assert_equal(shield_loss["shield_loss_dice"], 1, "shield blown removes one shield die")
	var shield_empty: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, shield_loss, model.starship_damage_for_margin(0))
	_assert_equal(shield_empty["controls_ionized"], 1, "shield blown with no remaining shields ionizes controls")
	var ion_condition: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, {}, model.starship_damage_for_margin(8, "ion"))
	_assert_equal(ion_condition["controls_ionized"], 2, "ion damage persists controls ionized count")
	var heavy_condition: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, {}, model.starship_damage_for_margin(12))
	var severe_from_repeat: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, heavy_condition, model.starship_damage_for_margin(12), model.starship_system_effect_for_damage("heavily_damaged", 2))
	_assert_equal(severe_from_repeat["worst_hull_severity"], 4, "repeated heavy damage escalates to severe")
	_assert_equal(severe_from_repeat["system_effects"][0]["key"], "fire_arc_weapons_inoperative", "condition logs system effect")
	var maneuver_condition_ship := {"defense_pool": "2D", "shields": "1D"}
	var maneuver_loss: Dictionary = model.apply_starship_damage_to_condition(rules, maneuver_condition_ship, {}, model.starship_damage_for_margin(8), model.starship_system_effect_for_damage("lightly_damaged", 1))
	_assert_equal(maneuver_loss["maneuverability_loss_dice"], 1, "maneuverability system hit persists die loss")
	var shield_system_loss: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, {}, model.starship_damage_for_margin(12), model.starship_system_effect_for_damage("heavily_damaged", 5))
	_assert_equal(shield_system_loss["shield_loss_dice"], 1, "heavy shield system hit removes remaining shield")
	_assert_equal(shield_system_loss["controls_ionized"], 1, "heavy shield system hit ionizes if shields run out")
	var move_loss: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, {}, model.starship_damage_for_margin(8), model.starship_system_effect_for_damage("lightly_damaged", 6))
	_assert_equal(move_loss["move_loss"], 1, "move system hit persists lost Move")
	var disabled_weapons: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, {}, model.starship_damage_for_margin(12), model.starship_system_effect_for_damage("heavily_damaged", 2))
	_assert_equal(disabled_weapons["weapons_disabled"], true, "weapon system hit disables later fire")
	var dead_in_space: Dictionary = model.apply_starship_damage_to_condition(rules, condition_ship, {}, model.starship_damage_for_margin(15), model.starship_system_effect_for_damage("severely_damaged", 1))
	_assert_equal(dead_in_space["drives_disabled"], true, "dead in space disables drives")
	_assert_equal(dead_in_space["move_loss"], 4, "dead in space records move loss floor")
	var condition_summary: Dictionary = model.ship_condition_summary({
		"condition": {
			"worst_hull_severity": 3,
			"shield_loss_dice": 1,
			"maneuverability_loss_dice": 1,
			"weapons_disabled": true,
			"crew_wounds": {
				"pilot": {
					"id": "pilot",
					"name": "Pilot",
					"station": "pilot",
					"wound": {"name": "Wounded", "severity": 2},
					"severity": 2,
				},
			},
		},
	})
	_assert_equal(condition_summary["status"], "Heavily Damaged", "condition summary names hull status")
	_assert_equal(condition_summary["repairable_systems"].has("shields"), true, "condition summary lists shield repair")
	_assert_equal(condition_summary["repairable_systems"].has("weapons"), true, "condition summary lists weapon repair")
	_assert_equal(condition_summary["crew_wounds"].size(), 1, "condition summary counts wounded crew")
	_assert_equal(String(condition_summary["text"]).contains("crew wounded"), true, "condition summary text mentions crew wounds")
	var overlapping_repair_summary: Dictionary = model.ship_condition_summary({
		"condition": {
			"hyperdrive_disabled": true,
			"hyperdrive_calculation_penalty": 2,
			"astrogation_difficulty_penalty": 5,
			"repairable_systems": ["sensor mast", "sensor_mast"],
		},
	})
	_assert_equal(overlapping_repair_summary["repairable_systems"].count("hyperdrive"), 1, "condition summary deduplicates hyperdrive repair symptoms")
	_assert_equal(overlapping_repair_summary["repairable_systems"].count("sensor_mast"), 1, "condition summary deduplicates custom repair aliases")
	var wounded_station_ship := {
		"crew": [{"id": "local_pilot", "name": "Local Pilot", "station": "pilot"}],
		"condition": {
			"crew_wounds": {
				"local_pilot": {"name": "Local Pilot", "wound": {"name": "Wounded", "severity": 2}, "severity": 2},
			},
		},
	}
	var pilot_wound_penalty: Dictionary = model.crew_wound_penalty_for_action(wounded_station_ship, "maneuver")
	_assert_equal(pilot_wound_penalty["applies"], true, "pilot wound penalty applies to maneuver actions")
	_assert_equal(pilot_wound_penalty["penalty_dice"], 1, "wounded station loses one action die")
	var incapacitated_station_ship := {
		"condition": {
			"crew_wounds": {
				"gunner": {"station": "gunner", "wound": {"name": "Incapacitated", "severity": 3}, "severity": 3},
			},
		},
	}
	var incapacitated_penalty: Dictionary = model.crew_wound_penalty_for_action(incapacitated_station_ship, "gunnery")
	_assert_equal(incapacitated_penalty["action_blocked"], true, "incapacitated station cannot act")
	_assert_equal(incapacitated_penalty["penalty_dice"], 99, "incapacitated station zeros action pool")
	var ionized_round_ship := {"condition": {"controls_ionized": 2, "controls_ionized_rounds": 2}}
	var after_one_round: Dictionary = model.advance_ship_condition_round(ionized_round_ship)
	_assert_equal(after_one_round["condition"]["controls_ionized"], 2, "ionized controls persist after one countdown")
	_assert_equal(after_one_round["condition"]["controls_ionized_rounds"], 1, "ionized controls countdown decreases")
	var after_two_rounds: Dictionary = model.advance_ship_condition_round(after_one_round)
	_assert_equal(after_two_rounds["condition"]["controls_ionized"], 0, "ionized controls clear when countdown expires")

	var moving_contacts := [
		{"id": "mover", "name": "Mover", "position": {"x": 0, "y": 0}, "heading_degrees": 0, "movement": {"move_units": 10, "turn_degrees": 90}},
		{"id": "dead", "name": "Dead", "position": {"x": 5, "y": 5}, "heading_degrees": 0, "movement": {"move_units": 10}, "condition": {"drives_disabled": true}},
		{"id": "locked", "name": "Locked", "position": {"x": 3, "y": 4}, "heading_degrees": 0, "movement": {"move_units": 10}, "condition": {"control_locked_rounds": 1}},
	]
	var movement_result: Dictionary = model.advance_contacts(state, moving_contacts)
	_assert_equal(movement_result["state"]["movement_round"], 2, "contact movement advances movement round")
	_assert_equal(int(movement_result["contacts"][0]["heading_degrees"]), 90, "moving contact turns")
	_assert_equal(round(float(movement_result["contacts"][0]["position"]["y"])), 10.0, "moving contact advances along heading")
	_assert_equal(movement_result["events"][0]["can_move"], true, "moving contact event records movement")
	_assert_equal(movement_result["events"][1]["can_move"], false, "disabled contact cannot move")
	_assert_equal(movement_result["events"][1]["movement_blocked_reason"], "drives_disabled", "disabled contact reports movement block reason")
	_assert_equal(movement_result["contacts"][1]["position"], {"x": 5, "y": 5}, "disabled contact stays put")
	_assert_equal(movement_result["events"][2]["can_move"], false, "control-locked contact cannot move")
	_assert_equal(movement_result["events"][2]["movement_blocked_reason"], "control_locked", "control-locked contact reports movement block reason")
	_assert_equal(movement_result["contacts"][2]["position"], {"x": 3, "y": 4}, "control-locked contact stays put")
	var tactical_player := {
		"id": "player_ship",
		"name": "Player Ship",
		"position": {"x": 20, "y": 0},
		"scale": "starfighter",
		"hull": "1D",
		"defense_pool": "0D",
		"dodge_active": false,
		"condition": {"controls_ionized": 1, "controls_ionized_rounds": 1},
	}
	var tactical_contacts := [
		{
			"id": "round_mover",
			"name": "Round Mover",
			"position": {"x": 0, "y": 0},
			"heading_degrees": 0,
			"movement": {"move_units": 10, "turn_degrees": 0},
			"condition": {"pilot_action_penalty_dice": 1, "pilot_action_penalty_rounds": 1},
		},
		{
			"id": "tracker",
			"name": "Tracker",
			"position": {"x": -20, "y": 0},
			"heading_degrees": 90,
			"movement": {"move_units": 10, "track_target": "player", "turn_rate_degrees": 45},
		},
		{
			"id": "holder",
			"name": "Holder",
			"position": {"x": 5, "y": 0},
			"heading_degrees": 90,
			"scale": "starfighter",
			"gunnery_pool": "12D",
			"fire_control": "0D",
			"weapon_damage": "12D",
			"counterfire": true,
			"movement": {"move_units": 10, "track_target": "player", "turn_rate_degrees": 45, "hold_range": 20, "lock_rounds_to_fire": 2},
		},
		{
			"id": "passive_holder",
			"name": "Passive Holder",
			"position": {"x": 5, "y": 0},
			"heading_degrees": 90,
			"movement": {"move_units": 10, "track_target": "player", "turn_rate_degrees": 45, "hold_range": 20},
		},
	]
	var tactical_state := state.duplicate(true)
	tactical_state["sensor_contact_confidence"] = {"holder": model.sensor_confidence_for_margin(4)}
	tactical_state["station_assists"] = {
		"gunnery": {"station": "sensors", "name": "Sensor lock", "target_action": "gunnery", "pool": "1D", "banked_round": 1}
	}
	var pre_lock_context: Dictionary = model.weapon_solution_context_for_contact(tactical_state, tactical_contacts[2])
	_assert_equal(pre_lock_context["key"], "none", "unbuilt weapon solution context starts clear")
	var tactical_round: Dictionary = model.advance_tactical_round(tactical_state, tactical_player, tactical_contacts)
	_assert_equal(tactical_round["state"]["movement_round"], 2, "tactical round advances movement round")
	_assert_equal(tactical_round["ship"]["condition"]["controls_ionized"], 0, "tactical round clears expired player ionization")
	_assert_equal(tactical_round["contacts"][0]["condition"]["pilot_action_penalty_dice"], 0, "tactical round clears expired contact pilot penalty")
	_assert_equal(round(float(tactical_round["contacts"][0]["position"]["x"])), 10.0, "tactical round still moves contacts")
	_assert_equal(int(tactical_round["contacts"][1]["heading_degrees"]), 45, "tracking contact turns toward player")
	_assert_equal(tactical_round["events"][1]["tracks_focus"], true, "tracking contact records focused movement")
	_assert_equal(int(tactical_round["contacts"][2]["heading_degrees"]), 45, "holding contact still turns toward player")
	_assert_equal(round(float(tactical_round["contacts"][2]["position"]["x"])), 5.0, "holding contact does not close inside engagement range")
	_assert_equal(tactical_round["events"][2]["holds_range"], true, "holding contact records engagement hold")
	_assert_equal(tactical_round["events"][2]["weapon_solution"], true, "armed holding contact records weapon solution")
	_assert_equal(tactical_round["events"][2]["weapon_solution_rounds"], 1, "first held solution records one lock round")
	_assert_equal(tactical_round["events"][2]["fire_ready"], false, "first held solution is not ready")
	_assert_equal(tactical_round["events"][2]["range_name"], "Point Blank", "weapon solution records WEG range band")
	_assert_equal(tactical_round["events"][2]["targeting_context"]["confidence_key"], "partial", "movement event carries contact track confidence")
	_assert_equal(tactical_round["events"][2]["weapon_solution_context"]["key"], "building", "movement event carries building lock context")
	_assert_equal(tactical_round["events"][2]["weapon_solution_context"]["rounds"], 1, "lock context carries current lock rounds")
	_assert_equal(String(tactical_round["events"][2]["engagement_context"]["summary"]).contains("Track Partial"), true, "engagement context summarizes track quality")
	_assert_equal(tactical_round["events"][2]["engagement_context"]["informational_only"], true, "engagement context is informational")
	_assert_equal(tactical_round["events"][3]["weapon_solution"], false, "passive holding contact has no weapon solution")
	_assert_equal(tactical_round["condition_events"].size(), 5, "tactical round records player and contact condition ticks")
	_assert_equal(tactical_round["condition_events"][0]["changed"], true, "player condition tick records change")
	var second_tactical_round: Dictionary = model.advance_tactical_round(tactical_round["state"], tactical_round["ship"], tactical_round["contacts"])
	_assert_equal(second_tactical_round["events"][2]["weapon_solution_rounds"], 2, "second held solution increments lock clock")
	_assert_equal(second_tactical_round["events"][2]["fire_ready"], true, "second held solution is ready")
	_assert_equal(second_tactical_round["events"][2]["weapon_solution_context"]["key"], "ready", "ready lock context is reported")
	_assert_equal(second_tactical_round["ready_hostile_fire_events"].size(), 1, "ready lock emits hostile fire opportunity")
	_assert_equal(second_tactical_round["ready_hostile_fire_events"][0]["contact_id"], "holder", "ready fire event names contact")
	_assert_equal(second_tactical_round["ready_hostile_fire_events"][0]["informational_only"], true, "ready fire event is informational before automatic damage")
	_assert_equal(second_tactical_round["state"]["last_ready_hostile_fire_events"].size(), 1, "ready fire events persist in tactical state")
	var automatic_hostile_fire: Dictionary = model.resolve_ready_hostile_fire(
		rules,
		second_tactical_round["state"],
		second_tactical_round["ship"],
		second_tactical_round["contacts"],
		second_tactical_round["ready_hostile_fire_events"],
		8080
	)
	_assert_equal(automatic_hostile_fire["events"].size(), 1, "ready hostile fire resolves one automatic shot")
	_assert_equal(automatic_hostile_fire["events"][0]["applies"], true, "automatic hostile fire applies")
	_assert_equal(automatic_hostile_fire["events"][0]["event"]["attacker_id"], "holder", "automatic hostile fire uses ready contact as attacker")
	_assert_equal(automatic_hostile_fire["events"][0]["consumed_weapon_solution"]["prior_rounds"], 2, "automatic hostile fire consumes ready lock rounds")
	_assert_equal(automatic_hostile_fire["state"]["weapon_solution_counts"].has("holder"), false, "automatic hostile fire clears consumed lock")
	_assert_equal(automatic_hostile_fire["state"]["station_assists"].has("gunnery"), true, "automatic hostile fire does not consume player gunnery assist")
	_assert_equal(automatic_hostile_fire["state"]["last_automatic_hostile_fire_events"].size(), 1, "automatic hostile fire persists latest events")
	var disabled_lock_state := state.duplicate(true)
	disabled_lock_state["weapon_solution_counts"] = {"disabled_holder": 3}
	var disabled_hostile_fire: Dictionary = model.resolve_ready_hostile_fire(
		rules,
		disabled_lock_state,
		tactical_player,
		[
			{
				"id": "disabled_holder",
				"name": "Disabled Holder",
				"counterfire": true,
				"condition": {"weapons_disabled": true},
				"movement": {"lock_rounds_to_fire": 2},
			},
		],
		[
			{
				"contact_id": "disabled_holder",
				"contact_name": "Disabled Holder",
				"weapon_solution_rounds": 3,
				"fire_ready_rounds": 2,
			},
		],
		8181
	)
	_assert_equal(disabled_hostile_fire["events"][0]["applies"], false, "disabled automatic hostile fire is blocked")
	_assert_equal(disabled_hostile_fire["events"][0]["reason"], "weapons_disabled", "disabled automatic hostile fire reports reason")
	_assert_equal(disabled_hostile_fire["events"][0]["consumed_weapon_solution"]["prior_rounds"], 3, "disabled automatic hostile fire reports cleared lock rounds")
	_assert_equal(disabled_hostile_fire["state"]["weapon_solution_counts"].has("disabled_holder"), false, "disabled automatic hostile fire clears stale lock")
	var destroyed_player_lock_state := state.duplicate(true)
	destroyed_player_lock_state["weapon_solution_counts"] = {"wreck_shooter": 2}
	var destroyed_player_fire: Dictionary = model.resolve_ready_hostile_fire(
		rules,
		destroyed_player_lock_state,
		tactical_player.merged({"condition": {"destroyed": true}}, true),
		[
			{
				"id": "wreck_shooter",
				"name": "Wreck Shooter",
				"counterfire": true,
				"gunnery_pool": "12D",
				"weapon_damage": "12D",
				"movement": {"lock_rounds_to_fire": 2},
			},
		],
		[
			{
				"contact_id": "wreck_shooter",
				"contact_name": "Wreck Shooter",
				"weapon_solution_rounds": 2,
				"fire_ready_rounds": 2,
			},
		],
		8282
	)
	_assert_equal(destroyed_player_fire["events"][0]["applies"], false, "destroyed player blocks automatic hostile fire")
	_assert_equal(destroyed_player_fire["events"][0]["reason"], "player_destroyed", "destroyed player automatic hostile fire reports reason")
	_assert_equal(destroyed_player_fire["events"][0]["consumed_weapon_solution"]["prior_rounds"], 2, "destroyed player automatic hostile fire reports cleared lock rounds")
	_assert_equal(destroyed_player_fire["state"]["weapon_solution_counts"].has("wreck_shooter"), false, "destroyed player automatic hostile fire clears ready lock")
	var same_tick_destroy_state := state.duplicate(true)
	same_tick_destroy_state["weapon_solution_counts"] = {"first_shooter": 2, "second_shooter": 2}
	var same_tick_destroy_fire: Dictionary = model.resolve_ready_hostile_fire(
		rules,
		same_tick_destroy_state,
		tactical_player.merged({"condition": {}}, true),
		[
			{
				"id": "first_shooter",
				"name": "First Shooter",
				"counterfire": true,
				"scale": "starfighter",
				"position": {"x": 5, "y": 0},
				"gunnery_pool": "12D",
				"weapon_damage": "20D",
				"movement": {"lock_rounds_to_fire": 2},
			},
			{
				"id": "second_shooter",
				"name": "Second Shooter",
				"counterfire": true,
				"scale": "starfighter",
				"position": {"x": 6, "y": 0},
				"gunnery_pool": "12D",
				"weapon_damage": "12D",
				"movement": {"lock_rounds_to_fire": 2},
			},
		],
		[
			{"contact_id": "first_shooter", "contact_name": "First Shooter", "weapon_solution_rounds": 2, "fire_ready_rounds": 2},
			{"contact_id": "second_shooter", "contact_name": "Second Shooter", "weapon_solution_rounds": 2, "fire_ready_rounds": 2},
		],
		8383
	)
	_assert_equal(same_tick_destroy_fire["events"].size(), 2, "same tick hostile fire records both ready contacts")
	_assert_equal(same_tick_destroy_fire["events"][0]["applies"], true, "first same-tick hostile fire resolves")
	_assert_equal(same_tick_destroy_fire["ship"]["condition"]["destroyed"], true, "first same-tick hostile fire destroys player")
	_assert_equal(same_tick_destroy_fire["events"][1]["applies"], false, "second same-tick hostile fire is blocked after destruction")
	_assert_equal(same_tick_destroy_fire["events"][1]["reason"], "player_destroyed_by_prior_fire", "second same-tick hostile fire reports prior destruction")
	_assert_equal(same_tick_destroy_fire["events"][1]["consumed_weapon_solution"]["prior_rounds"], 2, "second same-tick hostile fire clears its lock")
	_assert_equal(same_tick_destroy_fire["state"]["weapon_solution_counts"].is_empty(), true, "same tick hostile fire clears all consumed and blocked locks")

	_assert_equal(model.repair_difficulty_for_system({"condition": {"shield_loss_dice": 2}}, "shields"), 15, "two lost shield dice are moderate repair")
	_assert_equal(model.repair_difficulty_for_system({"condition": {"maneuverability_loss_dice": 3}}, "maneuverability"), 20, "three maneuverability dice are difficult repair")
	_assert_equal(model.repair_difficulty_for_system({"condition": {"move_loss": 4}}, "move"), 25, "four lost moves are very difficult repair")
	var custom_difficulty_ship := {
		"repair_difficulties": {
			"sensor mast": "difficult",
			"cargo_lift": 25,
			"backup relay": "yard only",
		},
		"condition": {
			"repairable_systems": ["sensor mast", "cargo_lift", "backup_relay"],
			"repair_difficulties": {"sensor_mast": "very difficult"},
		},
	}
	_assert_equal(model.repair_difficulty_for_system(custom_difficulty_ship, "sensor mast"), 25, "condition repair difficulty overrides ship default")
	_assert_equal(model.repair_difficulty_for_system(custom_difficulty_ship, "cargo lift"), 25, "numeric custom repair difficulty is accepted")
	_assert_equal(model.repair_difficulty_for_system(custom_difficulty_ship, "backup relay"), -1, "yard-only custom repair difficulty is accepted")
	_assert_equal(model.repair_difficulty_for_system({"repair_difficulties": {"weapons": 10}, "condition": {"weapons_disabled": true, "weapons_destroyed": true}}, "weapons"), -1, "destroyed weapons ignore repair difficulty override")
	var repair_quote: Dictionary = model.repair_quote_for_system({"base_cost_credits": 98000, "condition": {"shield_loss_dice": 2}}, "shields", true)
	_assert_equal(repair_quote["difficulty_name"], "Moderate", "repair quote carries difficulty name")
	_assert_equal(repair_quote["field_cost_credits"], 0, "field damage control stays free")
	_assert_equal(repair_quote["field_time_rounds"], 2, "moderate combat repair takes two rounds")
	_assert_equal(repair_quote["repair_bay_time_hours"], 4, "moderate bay repair takes four hours")
	_assert_equal(repair_quote["yard_cost_credits"], 980, "yard damaged-system repair scales from ship value")
	var custom_repair_quote: Dictionary = model.repair_quote_for_system(custom_difficulty_ship, "sensor mast", true)
	_assert_equal(custom_repair_quote["difficulty_name"], "Very Difficult", "custom repair quote names overridden difficulty")
	_assert_equal(custom_repair_quote["field_time_rounds"], 10, "custom very difficult repair uses longer field time")
	var fallback_quote: Dictionary = model.repair_quote_for_system({"condition": {"worst_hull_severity": 4, "structural_damage": true}}, "structural", false)
	_assert_equal(fallback_quote["yard_cost_credits"], 3000, "GG6 severe fallback repair cost")
	_assert_equal(model.first_repairable_system({"shield_loss_dice": 1, "weapons_disabled": true}), "shields", "first repairable system prioritizes shields")
	_assert_equal(model.first_repairable_system({"weapons_disabled": true}), "weapons", "first repairable system finds disabled weapons")
	_assert_equal(model.first_repairable_system({"weapons_disabled": true, "weapons_destroyed": true, "drives_disabled": true}), "drives", "first repairable system skips destroyed weapons")
	_assert_equal(model.first_repairable_system({"weapons_disabled": true, "weapons_destroyed": true}), "", "destroyed weapons are not field repairable")
	_assert_equal(model.first_repairable_system({"repairable_systems": ["sensor mast", "cargo_lift"]}), "sensor_mast", "first repairable system preserves custom systems")
	_assert_equal(model.first_repairable_system({"shield_loss_dice": 1, "repairable_systems": ["sensor mast"]}), "shields", "canonical repairs stay ahead of custom systems")
	_assert_equal(model.first_field_repairable_system({"condition": {"repairable_systems": ["backup relay"], "repair_difficulties": {"backup relay": "yard only"}}}), "", "field repair target skips yard-only custom systems")
	_assert_equal(model.first_field_repairable_system({"condition": {"repairable_systems": ["backup relay", "cargo_lift"], "repair_difficulties": {"backup relay": "yard only", "cargo_lift": "difficult"}}}), "cargo_lift", "field repair target chooses first field-repairable custom system")
	var custom_condition_summary: Dictionary = model.ship_condition_summary({"condition": {"repairable_systems": ["sensor mast", "cargo_lift"]}})
	_assert_equal(custom_condition_summary["repairable_systems"].has("sensor_mast"), true, "condition summary lists custom sensor repair")
	_assert_equal(custom_condition_summary["repairable_systems"].has("cargo_lift"), true, "condition summary lists custom cargo repair")
	var player_repair_target: Dictionary = model.damage_control_target(
		{"id": "player", "condition": {"shield_loss_dice": 1}},
		{"id": "target", "condition": {"weapons_disabled": true}}
	)
	_assert_equal(player_repair_target["role"], "player", "damage control prioritizes player ship")
	_assert_equal(player_repair_target["system"], "shields", "player damage-control target reports player system")
	var fallback_repair_target: Dictionary = model.damage_control_target(
		{"id": "player", "condition": {}},
		{"id": "target", "condition": {"weapons_disabled": true}}
	)
	_assert_equal(fallback_repair_target["role"], "fallback", "damage control falls back to target ship")
	_assert_equal(fallback_repair_target["system"], "weapons", "fallback damage-control target reports target system")
	var destroyed_weapon_fallback: Dictionary = model.damage_control_target(
		{"id": "player", "condition": {}},
		{"id": "target", "condition": {"weapons_disabled": true, "weapons_destroyed": true, "drives_disabled": true}}
	)
	_assert_equal(destroyed_weapon_fallback["role"], "fallback", "damage control can still fall back after destroyed weapons")
	_assert_equal(destroyed_weapon_fallback["system"], "drives", "damage control skips destroyed weapons in fallback target")
	var custom_fallback_repair_target: Dictionary = model.damage_control_target(
		{"id": "player", "condition": {}},
		{"id": "target", "condition": {"repairable_systems": ["sensor mast"]}}
	)
	_assert_equal(custom_fallback_repair_target["role"], "fallback", "damage control can fall back to custom systems")
	_assert_equal(custom_fallback_repair_target["system"], "sensor_mast", "fallback damage-control target reports custom system")
	var yard_only_player_repair_target: Dictionary = model.damage_control_target(
		{"id": "player", "condition": {"repairable_systems": ["backup relay", "cargo_lift"], "repair_difficulties": {"backup relay": "yard only", "cargo_lift": "difficult"}}},
		{"id": "target", "condition": {"shield_loss_dice": 1}}
	)
	_assert_equal(yard_only_player_repair_target["role"], "player", "damage control keeps player priority after skipping yard-only custom system")
	_assert_equal(yard_only_player_repair_target["system"], "cargo_lift", "damage control chooses first field-repairable custom system")
	var yard_only_player_fallback_target: Dictionary = model.damage_control_target(
		{"id": "player", "condition": {"repairable_systems": ["backup relay"], "repair_difficulties": {"backup relay": "yard only"}}},
		{"id": "target", "condition": {"shield_loss_dice": 1}}
	)
	_assert_equal(yard_only_player_fallback_target["role"], "fallback", "damage control falls back when player only has yard-only repairs")
	_assert_equal(yard_only_player_fallback_target["system"], "shields", "damage control fallback remains field-repairable")
	var idle_repair_target: Dictionary = model.damage_control_target({"id": "player", "condition": {}}, {"id": "target", "condition": {}})
	_assert_equal(idle_repair_target["role"], "none", "damage control idles with no repairable systems")

	var repair_ship := {
		"id": "repair_test",
		"name": "Repair Test",
		"base_cost_credits": 98000,
		"condition": {
			"shield_loss_dice": 2,
			"maneuverability_loss_dice": 1,
			"weapons_disabled": true,
		},
	}
	var shield_repair: Dictionary = model.resolve_damage_control(rules, state, repair_ship, "shields", "20D", 6060, false)
	_assert_equal(shield_repair["event"]["success"], true, "high repair pool restores shields")
	_assert_equal(shield_repair["event"]["base_difficulty"], 15, "repair event records base difficulty")
	_assert_equal(shield_repair["event"]["repair_quote"]["yard_cost_credits"], 980, "repair event carries yard quote")
	_assert_equal(shield_repair["ship"]["condition"]["shield_loss_dice"], 0, "shield repair clears shield loss")
	_assert_equal(shield_repair["ship"]["condition"]["repair_log"].size(), 1, "successful repair logs field repair")
	_assert_equal(String(shield_repair["event"]["before_condition_summary"]["text"]).contains("Shields -2D"), true, "repair event carries before condition summary")
	_assert_equal(String(shield_repair["event"]["after_condition_summary"]["text"]).contains("Shields -2D"), false, "repair event carries repaired after summary")
	var maneuver_repair: Dictionary = model.resolve_damage_control(rules, state, repair_ship, "maneuverability", "20D", 6060, true)
	_assert_equal(maneuver_repair["event"]["difficulty"], 15, "in-combat repair adds five to easy difficulty")
	_assert_equal(maneuver_repair["ship"]["condition"]["maneuverability_loss_dice"], 0, "maneuverability repair clears maneuverability loss")
	var destroyed_weapon_repair: Dictionary = model.resolve_damage_control(rules, state, {"condition": {"weapons_disabled": true, "weapons_destroyed": true}}, "weapons", "20D", 6060, false)
	_assert_equal(destroyed_weapon_repair["event"]["can_repair"], false, "destroyed weapons cannot be repaired")
	_assert_equal(destroyed_weapon_repair["event"]["success"], false, "destroyed weapon repair cannot succeed")
	var custom_repair_ship := {
		"id": "custom_repair_test",
		"name": "Custom Repair Test",
		"condition": {"repairable_systems": ["sensor mast", "cargo_lift"], "repair_difficulties": {"sensor mast": "difficult"}},
	}
	var custom_repair: Dictionary = model.resolve_damage_control(rules, state, custom_repair_ship, "sensor mast", "20D", 6060, false)
	_assert_equal(custom_repair["event"]["success"], true, "custom repairable system can be repaired")
	_assert_equal(custom_repair["event"]["base_difficulty"], 20, "custom repairable systems can carry data-driven difficulty")
	_assert_equal(custom_repair["ship"]["condition"]["repairable_systems"].has("sensor_mast"), false, "custom repair clears repaired system")
	_assert_equal(custom_repair["ship"]["condition"]["repairable_systems"].has("cargo_lift"), true, "custom repair preserves other custom systems")
	var field_repair_alias_assist: Dictionary = model.resolve_crew_station_assist(rules, state, {"engineering_pool": "20D"}, {"name": "Field repair prep", "station": "engineering", "target_action": "field_repair", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6165)
	_assert_equal(field_repair_alias_assist["event"]["success"], true, "field repair alias station assist succeeds")
	_assert_equal(field_repair_alias_assist["state"]["station_assists"].has("repair"), true, "field repair alias banks repair assist")
	var alias_repair_state := state.duplicate(true)
	alias_repair_state["station_assists"] = field_repair_alias_assist["state"]["station_assists"]
	var alias_assisted_repair: Dictionary = model.resolve_damage_control(rules, alias_repair_state, repair_ship, "shields", "20D", 6060, false)
	_assert_equal(alias_assisted_repair["event"]["station_assist"]["applies"], true, "field repair alias assist is consumed by damage control")
	_assert_equal(alias_assisted_repair["event"]["station_assist"]["target_action"], "repair", "field repair alias resolves to repair target action")
	_assert_equal(alias_assisted_repair["event"]["repair_pool"], "21D", "field repair alias assist adds to repair pool")
	_assert_equal(alias_assisted_repair["state"]["station_assists"].has("repair"), false, "field repair alias assist is one-shot")
	var incapacitated_repair_ship := repair_ship.duplicate(true)
	incapacitated_repair_ship["condition"] = repair_ship["condition"].duplicate(true)
	incapacitated_repair_ship["condition"]["crew_wounds"] = {"engineer": {"station": "engineering", "wound": {"name": "Incapacitated", "severity": 3}, "severity": 3}}
	var incapacitated_repair: Dictionary = model.resolve_damage_control(rules, state, incapacitated_repair_ship, "shields", "5D", 6060, false)
	_assert_equal(incapacitated_repair["event"]["station_wound"]["action_blocked"], true, "incapacitated engineer blocks repair station")
	_assert_equal(incapacitated_repair["event"]["repair_pool"], "0D", "incapacitated engineer has zero repair pool")

	var astrogation_ship := {
		"id": "nav_test",
		"name": "Nav Test",
		"astrogation_pool": "20D",
		"condition": {
			"hyperdrive_calculation_penalty": 2,
			"astrogation_difficulty_penalty": 5,
		},
	}
	var astrogation_success: Dictionary = model.resolve_astrogation_plot(rules, state, astrogation_ship, {"name": "Plot exit", "difficulty": 10}, 9090)
	_assert_equal(astrogation_success["event"]["success"], true, "astrogation plot succeeds with high pool")
	_assert_equal(astrogation_success["event"]["difficulty"], 17, "astrogation plot includes nav penalties")
	_assert_equal(astrogation_success["ship"]["condition"]["hyperdrive_calculation_penalty"], 0, "astrogation clears calculation penalty")
	_assert_equal(astrogation_success["ship"]["condition"]["astrogation_difficulty_penalty"], 0, "astrogation clears astrogation penalty")
	_assert_equal(astrogation_success["ship"]["condition"]["navigation_log"].size(), 1, "astrogation success logs plotted route")
	var astrogation_assist_state := state.duplicate(true)
	astrogation_assist_state["station_assists"] = {"astrogation": {"station": "navigator", "name": "Navicomputer sync", "target_action": "astrogation", "pool": "1D", "banked_round": 2}}
	var assisted_astrogation: Dictionary = model.resolve_astrogation_plot(rules, astrogation_assist_state, astrogation_ship, {"name": "Plot exit", "difficulty": 10}, 9090)
	_assert_equal(assisted_astrogation["event"]["station_assist"]["applies"], true, "astrogation consumes navigator assist")
	_assert_equal(assisted_astrogation["event"]["action_pool"], "21D", "astrogation assist adds to pool")
	_assert_equal(assisted_astrogation["state"]["station_assists"].has("astrogation"), false, "astrogation assist is one-shot")
	var wounded_astrogation_ship := astrogation_ship.duplicate(true)
	wounded_astrogation_ship["condition"] = astrogation_ship["condition"].duplicate(true)
	wounded_astrogation_ship["condition"]["crew_wounds"] = {"navigator": {"station": "navigator", "wound": {"name": "Wounded", "severity": 2}, "severity": 2}}
	var wounded_astrogation: Dictionary = model.resolve_astrogation_plot(rules, state, wounded_astrogation_ship, {"name": "Plot exit", "difficulty": 10}, 9090)
	_assert_equal(wounded_astrogation["event"]["station_wound_penalty_dice"], 1, "astrogation records navigator wound penalty")
	_assert_equal(wounded_astrogation["event"]["action_pool"], "19D", "wounded navigator loses one astrogation die")
	var nav_alias_assist: Dictionary = model.resolve_crew_station_assist(rules, state, {"navicomputer_pool": "20D"}, {"name": "Jump calculation", "station": "navigator", "target_action": "jump_calculation", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6169)
	_assert_equal(nav_alias_assist["event"]["success"], true, "navigation alias station assist succeeds")
	_assert_equal(nav_alias_assist["event"]["requested_target_action"], "jump_calculation", "navigation alias event preserves requested target")
	_assert_equal(nav_alias_assist["state"]["station_assists"]["astrogation"]["requested_target_action"], "jump_calculation", "navigation alias bank preserves requested target")
	_assert_equal(nav_alias_assist["state"]["station_assists"].has("astrogation"), true, "navigation alias banks astrogation assist")
	var alias_assisted_astrogation: Dictionary = model.resolve_astrogation_plot(rules, nav_alias_assist["state"], astrogation_ship, {"name": "Plot exit", "difficulty": 10}, 9090)
	_assert_equal(alias_assisted_astrogation["event"]["station_assist"]["applies"], true, "navigation alias assist is consumed by astrogation")
	_assert_equal(alias_assisted_astrogation["event"]["station_assist"]["target_action"], "astrogation", "navigation alias resolves to astrogation target action")
	_assert_equal(alias_assisted_astrogation["event"]["station_assist"]["requested_target_action"], "jump_calculation", "navigation alias consumed assist preserves requested target")
	_assert_equal(alias_assisted_astrogation["state"]["station_assists"].has("astrogation"), false, "navigation alias assist is one-shot")
	var disabled_hyperdrive_plot: Dictionary = model.resolve_astrogation_plot(rules, state, {"astrogation_pool": "20D", "condition": {"hyperdrive_disabled": true}}, {"name": "Plot exit", "difficulty": 10}, 9090)
	_assert_equal(disabled_hyperdrive_plot["event"]["can_plot"], false, "disabled hyperdrive blocks astrogation plot")
	_assert_equal(disabled_hyperdrive_plot["event"]["success"], false, "disabled hyperdrive plot cannot succeed")

	var maneuver_ship := {
		"id": "maneuver_test",
		"name": "Maneuver Test",
		"position": {"x": 0, "y": 0},
		"heading_degrees": 0,
		"piloting_pool": "20D",
		"maneuverability": "1D",
	}
	var maneuver_action := {"name": "Bank right", "difficulty": 10, "modifier": 0, "turn_degrees": 90, "move_units": 20}
	var maneuver_success: Dictionary = model.resolve_maneuver_action(rules, state, maneuver_ship, maneuver_action, 7070)
	_assert_equal(maneuver_success["event"]["success"], true, "high pilot maneuver succeeds")
	_assert_equal(maneuver_success["state"]["maneuver_round"], 2, "maneuver advances maneuver round")
	_assert_equal(int(maneuver_success["ship"]["heading_degrees"]), 90, "successful maneuver turns heading")
	_assert_equal(round(float(maneuver_success["ship"]["position"]["y"])), 20.0, "successful maneuver moves along new heading")
	var locked_state := state.duplicate(true)
	locked_state["weapon_solution_counts"] = {"hostile": 2}
	var evasive_success: Dictionary = model.resolve_maneuver_action(rules, locked_state, maneuver_ship, maneuver_action.merged({"break_weapon_solutions": true}), 7070)
	_assert_equal(evasive_success["event"]["success"], true, "successful evasive maneuver succeeds")
	_assert_equal(evasive_success["event"]["weapon_solutions_broken"], 1, "successful evasive maneuver clears lock count")
	_assert_equal(evasive_success["state"]["weapon_solution_counts"].is_empty(), true, "successful evasive maneuver clears lock state")
	var assist_result: Dictionary = model.resolve_crew_station_assist(rules, state, maneuver_ship, {"name": "Copilot vectors", "station": "copilot", "target_action": "maneuver", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6161)
	_assert_equal(assist_result["event"]["success"], true, "crew station assist succeeds")
	_assert_equal(assist_result["state"]["station_round"], 2, "station assist advances station round")
	_assert_equal(assist_result["state"]["station_assists"].has("maneuver"), true, "station assist banks maneuver bonus")
	_assert_equal(assist_result["state"]["station_assists"]["maneuver"]["banked_round"], 1, "station assist records banked round")
	var wounded_assist_ship := {
		"crew": [{"id": "local_copilot", "name": "Local Copilot", "station": "copilot"}],
		"condition": {
			"crew_wounds": {
				"local_copilot": {"name": "Local Copilot", "wound": {"name": "Wounded", "severity": 2}, "severity": 2},
			},
		},
	}
	var wounded_assist: Dictionary = model.resolve_crew_station_assist(rules, state, wounded_assist_ship, {"name": "Wounded copilot vectors", "station": "copilot", "target_action": "maneuver", "pool": "5D", "bonus_pool": "1D", "difficulty": 1}, 6161)
	_assert_equal(wounded_assist["event"]["station_wound_penalty_dice"], 1, "wounded station assist records wound penalty")
	_assert_equal(wounded_assist["event"]["assist_pool"], "4D", "wounded station assist loses one die")
	var replacement_result: Dictionary = model.resolve_crew_station_assist(rules, assist_result["state"], maneuver_ship, {"name": "Navigator timing", "station": "navigator", "target_action": "maneuver", "pool": "20D", "bonus_pool": "2D", "difficulty": 10}, 6162)
	_assert_equal(replacement_result["event"]["replaced_existing"], true, "station assist reports replacement")
	_assert_equal(replacement_result["event"]["replaced_assist"]["name"], "Copilot vectors", "station assist records replaced name")
	_assert_equal(replacement_result["state"]["station_assists"]["maneuver"]["name"], "Navigator timing", "station assist replacement is banked")
	_assert_equal(replacement_result["state"]["station_assists"]["maneuver"]["banked_round"], 2, "station assist replacement records new banked round")
	var assisted_maneuver: Dictionary = model.resolve_maneuver_action(rules, assist_result["state"], maneuver_ship, maneuver_action, 7070)
	_assert_equal(assisted_maneuver["event"]["station_assist"]["applies"], true, "maneuver consumes station assist")
	_assert_equal(assisted_maneuver["event"]["station_assist"]["pool_text"], "1D", "station assist records bonus pool")
	_assert_equal(assisted_maneuver["event"]["station_assist"]["banked_round"], 1, "consumed station assist reports banked round")
	_assert_equal(assisted_maneuver["event"]["action_pool"], "22D", "station assist adds to maneuver action pool")
	_assert_equal(assisted_maneuver["state"]["station_assists"].has("maneuver"), false, "station assist is one-shot")
	var wounded_maneuver_ship := maneuver_ship.duplicate(true)
	wounded_maneuver_ship["crew"] = [{"id": "local_pilot", "name": "Local Pilot", "station": "pilot"}]
	wounded_maneuver_ship["condition"] = {"crew_wounds": {"local_pilot": {"wound": {"name": "Wounded", "severity": 2}, "severity": 2}}}
	var wounded_maneuver: Dictionary = model.resolve_maneuver_action(rules, state, wounded_maneuver_ship, maneuver_action, 7070)
	_assert_equal(wounded_maneuver["event"]["station_wound_penalty_dice"], 1, "maneuver records pilot wound penalty")
	_assert_equal(wounded_maneuver["event"]["action_pool"], "20D", "wounded pilot loses one maneuver die")
	var incapacitated_maneuver_ship := maneuver_ship.duplicate(true)
	incapacitated_maneuver_ship["condition"] = {"crew_wounds": {"pilot": {"station": "pilot", "wound": {"name": "Incapacitated", "severity": 3}, "severity": 3}}}
	var incapacitated_maneuver: Dictionary = model.resolve_maneuver_action(rules, state, incapacitated_maneuver_ship, maneuver_action, 7070)
	_assert_equal(incapacitated_maneuver["event"]["station_wound"]["action_blocked"], true, "incapacitated pilot blocks maneuver station")
	_assert_equal(incapacitated_maneuver["event"]["action_pool"], "0D", "incapacitated pilot has zero maneuver pool")
	var helm_alias_assist: Dictionary = model.resolve_crew_station_assist(rules, state, {"helm_pool": "20D"}, {"name": "Break-lock vector", "station": "helm", "target_action": "break_lock", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6166)
	_assert_equal(helm_alias_assist["event"]["success"], true, "helm alias station assist succeeds")
	_assert_equal(helm_alias_assist["state"]["station_assists"].has("maneuver"), true, "helm alias banks maneuver assist")
	var alias_maneuver: Dictionary = model.resolve_maneuver_action(rules, helm_alias_assist["state"], maneuver_ship, maneuver_action, 7070)
	_assert_equal(alias_maneuver["event"]["station_assist"]["applies"], true, "helm alias assist is consumed by maneuver")
	_assert_equal(alias_maneuver["event"]["station_assist"]["target_action"], "maneuver", "helm alias resolves to maneuver target action")
	_assert_equal(alias_maneuver["state"]["station_assists"].has("maneuver"), false, "helm alias assist is one-shot")
	var hazard_maneuver := {"name": "Thread hazard", "difficulty": 10, "modifier": 0, "turn_degrees": 45, "move_units": 28, "hazards": [{"id": "debris", "name": "Debris Cloud", "position": {"x": 12, "y": 12}, "radius": 8, "difficulty_modifier": 5, "collision_possible": true}]}
	var hazard_success: Dictionary = model.resolve_maneuver_action(rules, state, maneuver_ship, hazard_maneuver, 7070)
	_assert_equal(hazard_success["event"]["hazard_context"]["crossed"].size(), 1, "maneuver event records crossed hazard")
	_assert_equal(hazard_success["event"]["difficulty"], 15, "hazard raises maneuver difficulty")

	var maneuver_failure_ship := maneuver_ship.duplicate(true)
	maneuver_failure_ship["piloting_pool"] = "0D"
	maneuver_failure_ship["maneuverability"] = "0D"
	var maneuver_failure: Dictionary = model.resolve_maneuver_action(rules, state, maneuver_failure_ship, maneuver_action, 7070)
	_assert_equal(maneuver_failure["event"]["success"], false, "low pilot maneuver fails")
	_assert_equal(maneuver_failure["event"]["failure"].has("key"), true, "failed maneuver records WEG failure")
	_assert_equal(float(maneuver_failure["event"]["actual_move"]) <= 20.0, true, "failed maneuver limits movement")
	var evasive_failure: Dictionary = model.resolve_maneuver_action(rules, locked_state, maneuver_failure_ship, maneuver_action.merged({"break_weapon_solutions": true}), 7070)
	_assert_equal(evasive_failure["event"]["weapon_solutions_broken"], 0, "failed evasive maneuver does not clear lock count")
	_assert_equal(evasive_failure["state"]["weapon_solution_counts"].has("hostile"), true, "failed evasive maneuver keeps lock state")
	var hazard_collision_maneuver := hazard_maneuver.duplicate(true)
	hazard_collision_maneuver["difficulty"] = 30
	hazard_collision_maneuver["speed"] = "cruise"
	var hazard_collision_ship := maneuver_failure_ship.duplicate(true)
	hazard_collision_ship["hull"] = "0D"
	var hazard_collision: Dictionary = model.resolve_maneuver_action(rules, state, hazard_collision_ship, hazard_collision_maneuver, 8080)
	_assert_equal(hazard_collision["event"]["hazard_context"]["collision_possible"], true, "hazard failure marks collision possible")
	_assert_equal(hazard_collision["event"]["collision"]["applies"], true, "hazard failure resolves collision")

	var collision_maneuver := {
		"name": "Thread debris",
		"difficulty": 30,
		"modifier": 0,
		"turn_degrees": 0,
		"move_units": 20,
		"speed": "all-out",
		"collision_possible": true,
	}
	var collision_ship := maneuver_failure_ship.duplicate(true)
	collision_ship["hull"] = "0D"
	var collision_failure: Dictionary = model.resolve_maneuver_action(rules, state, collision_ship, collision_maneuver, 8080)
	_assert_equal(collision_failure["event"]["failure"]["key"], "major_collision_or_spinout", "large maneuver failure reaches major collision band")
	_assert_equal(collision_failure["event"]["collision"]["applies"], true, "obstacle-present failure resolves collision damage")
	_assert_equal(collision_failure["event"]["collision"]["damage_pool"], "14D", "major all-out collision damage applies")
	_assert_equal(collision_failure["event"]["collision"]["hull_soak_pool"], "0D", "collision soaks against hull")
	_assert_equal(collision_failure["ship"]["condition"]["damage_log"].size() > 0, true, "collision damage persists ship condition")
	var wild_spin_maneuver := collision_maneuver.duplicate(true)
	wild_spin_maneuver["collision_possible"] = false
	var wild_spin_failure: Dictionary = model.resolve_maneuver_action(rules, state, collision_ship, wild_spin_maneuver, 8080)
	_assert_equal(wild_spin_failure["event"]["collision"]["applies"], false, "no obstacle converts collision band to wild spin")
	_assert_equal(wild_spin_failure["event"]["collision"]["reason"], "wild_spin_no_obstacle", "wild spin records no-obstacle reason")

	var disabled_drive_maneuver: Dictionary = model.resolve_maneuver_action(rules, state, {"condition": {"drives_disabled": true}, "piloting_pool": "20D", "maneuverability": "2D"}, maneuver_action, 7070)
	_assert_equal(disabled_drive_maneuver["event"]["can_maneuver"], false, "disabled drives cannot maneuver")
	_assert_equal(disabled_drive_maneuver["event"]["actual_move"], 0.0, "disabled drives do not move")

	var contacts := [
		{"id": "near", "name": "Near Contact", "position": {"x": 8, "y": 0}},
		{"id": "medium", "name": "Medium Contact", "position": {"x": 110, "y": 0}},
		{"id": "far", "name": "Far Contact", "position": {"x": 300, "y": 0}},
	]
	var sweep_a: Dictionary = model.resolve_sensor_sweep(rules, state, contacts, 31337)
	var sweep_b: Dictionary = model.resolve_sensor_sweep(rules, state, contacts, 31337)
	_assert_equal(sweep_a["events"], sweep_b["events"], "same sensor seed replays identical events")
	_assert_equal(sweep_a["state"]["scan_round"], 2, "sensor sweep advances scan round")
	_assert_equal(sweep_a["events"].size(), 3, "one event per contact")
	_assert_equal(sweep_a["events"][0]["contact_id"], "near", "event records contact id")
	_assert_equal(sweep_a["events"][0]["difficulty"], 5, "near contact difficulty")
	_assert_equal(sweep_a["events"][0]["margin"], int(sweep_a["roll"]["total"]) - int(sweep_a["events"][0]["difficulty"]), "sensor event records roll margin")
	_assert_equal(String(sweep_a["events"][0]["confidence_key"]) != "", true, "sensor event records confidence key")
	_assert_equal(sweep_a["events"][0]["confidence"]["key"], sweep_a["events"][0]["confidence_key"], "sensor event carries confidence details")
	if bool(sweep_a["events"][0]["success"]):
		_assert_equal(sweep_a["state"]["sensor_contact_confidence"].has("near"), true, "successful sweep stores contact confidence")
		_assert_equal(sweep_a["state"]["sensor_contact_confidence"]["near"]["key"], sweep_a["events"][0]["confidence_key"], "stored confidence matches event")
		_assert_equal(sweep_a["newly_revealed_contacts"].has("near"), true, "successful sweep reports newly revealed contact")
	var stored_confidence_state := state.duplicate(true)
	stored_confidence_state["sensor_pool"] = rules.parse_pool("0D")
	stored_confidence_state["sensor_contact_confidence"] = {"near": model.sensor_confidence_for_margin(13)}
	var weak_resweep: Dictionary = model.resolve_sensor_sweep(rules, stored_confidence_state, [{"id": "near", "name": "Near Contact", "position": {"x": 8, "y": 0}}], 31337)
	_assert_equal(weak_resweep["state"]["sensor_contact_confidence"]["near"]["key"], "clear", "weaker sweep preserves stronger prior confidence")
	var prior_reveal_state := state.duplicate(true)
	prior_reveal_state["sensor_pool"] = rules.parse_pool("0D")
	prior_reveal_state["revealed_contacts"] = ["near"]
	var failed_reveal_sweep: Dictionary = model.resolve_sensor_sweep(rules, prior_reveal_state, [{"id": "far", "name": "Far Contact", "position": {"x": 300, "y": 0}}], 31337)
	_assert_equal(failed_reveal_sweep["state"]["revealed_contacts"].has("near"), true, "failed sweep preserves prior revealed contact")
	_assert_equal(failed_reveal_sweep["newly_revealed_contacts"].is_empty(), true, "failed sweep reports no new reveals")
	var sensor_assist_state := state.duplicate(true)
	sensor_assist_state["station_assists"] = {"sensors": {"station": "sensors", "name": "Sensor focus", "target_action": "sensors", "pool": "1D"}}
	var assisted_sweep: Dictionary = model.resolve_sensor_sweep(rules, sensor_assist_state, contacts, 31337)
	_assert_equal(assisted_sweep["station_assist"]["applies"], true, "sensor sweep consumes station assist")
	_assert_equal(rules.pool_to_string(assisted_sweep["sensor_pool"]), "5D", "sensor assist adds to sensor pool")
	_assert_equal(assisted_sweep["state"]["station_assists"].has("sensors"), false, "sensor assist is one-shot")
	var wounded_sensor_ship := {
		"condition": {
			"crew_wounds": {
				"sensors": {"station": "sensors", "wound": {"name": "Wounded", "severity": 2}, "severity": 2},
			},
		},
	}
	var wounded_sweep: Dictionary = model.resolve_sensor_sweep(rules, state, contacts, 31337, wounded_sensor_ship)
	_assert_equal(wounded_sweep["station_wound_penalty_dice"], 1, "sensor sweep records sensor-operator wound penalty")
	_assert_equal(rules.pool_to_string(wounded_sweep["sensor_pool"]), "3D", "wounded sensor operator loses one sensor die")
	var incapacitated_sensor_ship := {
		"condition": {
			"crew_wounds": {
				"sensors": {"station": "sensors", "wound": {"name": "Incapacitated", "severity": 3}, "severity": 3},
			},
		},
	}
	var incapacitated_sweep: Dictionary = model.resolve_sensor_sweep(rules, state, contacts, 31337, incapacitated_sensor_ship)
	_assert_equal(incapacitated_sweep["station_wound"]["action_blocked"], true, "incapacitated sensor operator blocks sensor station")
	_assert_equal(rules.pool_to_string(incapacitated_sweep["sensor_pool"]), "0D", "incapacitated sensor operator has zero sensor pool")
	var id_contact := {
		"id": "near",
		"name": "Near Contact",
		"position": {"x": 8, "y": 0},
		"transponder": {
			"declared_name": "Near Freighter",
			"registry": "NF-1138",
			"affiliation": "local traffic",
			"threat": "neutral",
			"profile": "Clean freighter return",
		},
	}
	var identification_state := state.duplicate(true)
	identification_state["sensor_pool"] = rules.parse_pool("20D")
	identification_state["revealed_contacts"] = ["near"]
	identification_state["sensor_contact_confidence"] = {"near": model.sensor_confidence_for_margin(4)}
	var identification: Dictionary = model.resolve_contact_identification(rules, identification_state, id_contact, {"name": "Identify contact", "difficulty": 10}, 4242)
	_assert_equal(identification["event"]["success"], true, "high sensors identify contact")
	_assert_equal(identification["state"]["identification_round"], 2, "identification advances round")
	_assert_equal(identification["state"]["identified_contacts"].has("near"), true, "successful identification persists profile")
	_assert_equal(identification["state"]["identified_contacts"]["near"]["registry"], "NF-1138", "identification stores transponder registry")
	_assert_equal(identification["event"]["sensor_context"]["confidence_key"], "partial", "identification records sensor confidence context")
	var unresolved_identification: Dictionary = model.resolve_contact_identification(rules, state, id_contact, {"name": "Identify contact", "difficulty": 10}, 4242)
	_assert_equal(unresolved_identification["event"]["can_identify"], false, "untracked contact cannot be identified")
	_assert_equal(unresolved_identification["event"]["success"], false, "untracked identification cannot succeed")
	var identification_assist_state := identification_state.duplicate(true)
	identification_assist_state["station_assists"] = {"sensors": {"station": "sensors", "name": "Sensor focus", "target_action": "sensors", "pool": "1D"}}
	var assisted_identification: Dictionary = model.resolve_contact_identification(rules, identification_assist_state, id_contact, {"name": "Identify contact", "difficulty": 10}, 4242)
	_assert_equal(assisted_identification["event"]["station_assist"]["applies"], true, "identification consumes sensor assist")
	_assert_equal(assisted_identification["event"]["sensor_pool"], "21D", "identification assist adds to sensor pool")
	_assert_equal(assisted_identification["state"]["station_assists"].has("sensors"), false, "identification assist is one-shot")
	var wounded_identification: Dictionary = model.resolve_contact_identification(rules, identification_state, id_contact, {"name": "Identify contact", "difficulty": 10}, 4242, wounded_sensor_ship)
	_assert_equal(wounded_identification["event"]["station_wound_penalty_dice"], 1, "identification records sensor-operator wound penalty")
	_assert_equal(wounded_identification["event"]["sensor_pool"], "19D", "wounded sensor operator loses one identification die")
	var identification_alias_assist: Dictionary = model.resolve_crew_station_assist(rules, state, {"sensors_pool": "20D"}, {"name": "Targeting solution", "station": "sensors", "target_action": "identification", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6163)
	_assert_equal(identification_alias_assist["event"]["success"], true, "identification alias station assist succeeds")
	_assert_equal(identification_alias_assist["state"]["station_assists"].has("sensors"), true, "identification alias banks sensors assist")
	var commander_targeting_assist: Dictionary = model.resolve_crew_station_assist(rules, state, {"crew": [{"id": "local_commander", "name": "Local Commander", "station": "commander"}]}, {"name": "Tactical coordination", "station": "commander", "target_action": "targeting_solution", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6164)
	_assert_equal(commander_targeting_assist["event"]["success"], true, "commander targeting assist succeeds")
	_assert_equal(commander_targeting_assist["event"]["target_action"], "sensors", "commander targeting assist normalizes to sensors")
	_assert_equal(commander_targeting_assist["event"]["requested_target_action"], "targeting_solution", "commander targeting assist preserves requested target")
	_assert_equal(commander_targeting_assist["state"]["station_assists"].has("sensors"), true, "commander targeting assist banks sensors assist")
	var commander_identification_state := identification_state.duplicate(true)
	commander_identification_state["station_assists"] = commander_targeting_assist["state"]["station_assists"]
	var commander_assisted_identification: Dictionary = model.resolve_contact_identification(rules, commander_identification_state, id_contact, {"name": "Identify contact", "difficulty": 10}, 4242)
	_assert_equal(commander_assisted_identification["event"]["station_assist"]["applies"], true, "commander targeting assist is consumed by contact identification")
	_assert_equal(commander_assisted_identification["event"]["station_assist"]["requested_target_action"], "targeting_solution", "commander targeting assist preserves alias on consumption")
	var alias_identification_state := identification_state.duplicate(true)
	alias_identification_state["station_assists"] = identification_alias_assist["state"]["station_assists"]
	var alias_assisted_identification: Dictionary = model.resolve_contact_identification(rules, alias_identification_state, id_contact, {"name": "Identify contact", "difficulty": 10}, 4242)
	_assert_equal(alias_assisted_identification["event"]["station_assist"]["applies"], true, "identification alias assist is consumed by contact identification")
	_assert_equal(alias_assisted_identification["event"]["station_assist"]["target_action"], "sensors", "identification alias resolves to sensors target action")
	_assert_equal(alias_assisted_identification["state"]["station_assists"].has("sensors"), false, "identification alias assist is one-shot")
	var comms_ship := {
		"id": "comms_test",
		"name": "Comms Test",
		"communications_pool": "20D",
	}
	var comms_contact := id_contact.duplicate(true)
	comms_contact["transponder"]["threat"] = "hostile"
	comms_contact["comms"] = {
		"success_response": "Contact opens a narrow channel.",
		"failure_response": "Contact stays dark.",
	}
	var comms_state: Dictionary = identification["state"].duplicate(true)
	var hail: Dictionary = model.resolve_comms_hail(rules, comms_state, comms_ship, comms_contact, {"name": "Hail contact", "difficulty": 10}, 5252)
	_assert_equal(hail["event"]["success"], true, "high communications pool opens hail")
	_assert_equal(hail["state"]["comms_round"], 2, "hail advances comms round")
	_assert_equal(hail["event"]["identified"], true, "hail event records identified contact")
	_assert_equal(hail["event"]["threat_modifier"], 10, "hostile hail records threat modifier")
	_assert_equal(hail["state"]["contact_dispositions"]["near"]["status"], "responsive", "successful hail persists responsive disposition")
	var delayed_hail_state := comms_state.duplicate(true)
	delayed_hail_state["weapon_solution_counts"] = {"near": 2}
	var delayed_hail: Dictionary = model.resolve_comms_hail(rules, delayed_hail_state, comms_ship, comms_contact, {"name": "Hail contact", "difficulty": 10, "delay_weapon_solution_on_success": true, "weapon_solution_delay_rounds": 1}, 5252)
	_assert_equal(delayed_hail["event"]["weapon_solution_delay"]["applies"], true, "successful hail can delay weapon solution")
	_assert_equal(delayed_hail["event"]["weapon_solution_delay"]["prior_rounds"], 2, "hail delay records prior lock rounds")
	_assert_equal(delayed_hail["event"]["weapon_solution_delay"]["remaining_rounds"], 1, "hail delay records remaining lock rounds")
	_assert_equal(delayed_hail["state"]["weapon_solution_counts"]["near"], 1, "hail delay reduces lock count")
	_assert_equal(delayed_hail["state"]["contact_dispositions"]["near"]["weapon_solution_delay"]["applies"], true, "hail delay persists in contact disposition")
	var pressure_hail_contact := comms_contact.duplicate(true)
	pressure_hail_contact["counterfire"] = true
	pressure_hail_contact["movement"] = {"lock_rounds_to_fire": 2}
	var pressure_hail: Dictionary = model.resolve_comms_hail(rules, state, {"communications_pool": "0D"}, pressure_hail_contact, {"name": "Hail contact", "difficulty": 30, "advance_weapon_solution_on_failure": true, "weapon_solution_pressure_rounds": 1}, 5252)
	_assert_equal(pressure_hail["event"]["success"], false, "low communications pool fails pressure hail")
	_assert_equal(pressure_hail["event"]["weapon_solution_pressure"]["applies"], true, "failed hail can advance weapon solution")
	_assert_equal(pressure_hail["event"]["weapon_solution_pressure"]["prior_rounds"], 0, "failed hail pressure records prior lock rounds")
	_assert_equal(pressure_hail["event"]["weapon_solution_pressure"]["current_rounds"], 1, "failed hail pressure records current lock rounds")
	_assert_equal(pressure_hail["state"]["weapon_solution_counts"]["near"], 1, "failed hail pressure advances lock count")
	_assert_equal(pressure_hail["state"]["contact_dispositions"]["near"]["weapon_solution_pressure"]["applies"], true, "failed hail pressure persists in contact disposition")
	var ready_pressure_hail_state := state.duplicate(true)
	ready_pressure_hail_state["weapon_solution_counts"] = {"near": 1}
	var ready_pressure_hail: Dictionary = model.resolve_comms_hail(rules, ready_pressure_hail_state, {"communications_pool": "0D"}, pressure_hail_contact, {"name": "Hail contact", "difficulty": 30, "advance_weapon_solution_on_failure": true, "weapon_solution_pressure_rounds": 1}, 5252)
	_assert_equal(ready_pressure_hail["event"]["weapon_solution_pressure"]["current_rounds"], 2, "failed hail pressure can complete lock count")
	_assert_equal(ready_pressure_hail["event"]["weapon_solution_pressure"]["fire_ready"], true, "failed hail pressure records ready lock")
	var failed_hail: Dictionary = model.resolve_comms_hail(rules, state, {"communications_pool": "0D"}, comms_contact, {"name": "Hail contact", "difficulty": 30}, 5252)
	_assert_equal(failed_hail["event"]["success"], false, "low communications pool fails hail")
	_assert_equal(failed_hail["state"]["contact_dispositions"]["near"]["status"], "unresponsive", "failed hail persists unresponsive disposition")
	var comms_assist_state: Dictionary = comms_state.duplicate(true)
	comms_assist_state["station_assists"] = {"communications": {"station": "communications", "name": "Traffic phrasebook", "target_action": "communications", "pool": "1D"}}
	var assisted_hail: Dictionary = model.resolve_comms_hail(rules, comms_assist_state, comms_ship, comms_contact, {"name": "Hail contact", "difficulty": 10}, 5252)
	_assert_equal(assisted_hail["event"]["station_assist"]["applies"], true, "hail consumes communications assist")
	_assert_equal(assisted_hail["event"]["communications_pool"], "21D", "communications assist adds to hail pool")
	_assert_equal(assisted_hail["state"]["station_assists"].has("communications"), false, "communications assist is one-shot")
	var wounded_comms_ship := comms_ship.duplicate(true)
	wounded_comms_ship["condition"] = {"crew_wounds": {"comms": {"station": "communications", "wound": {"name": "Wounded", "severity": 2}, "severity": 2}}}
	var wounded_hail: Dictionary = model.resolve_comms_hail(rules, comms_state, wounded_comms_ship, comms_contact, {"name": "Hail contact", "difficulty": 10}, 5252)
	_assert_equal(wounded_hail["event"]["station_wound_penalty_dice"], 1, "comms records communications wound penalty")
	_assert_equal(wounded_hail["event"]["communications_pool"], "19D", "wounded comms crew loses one die")
	var hail_alias_assist: Dictionary = model.resolve_crew_station_assist(rules, state, {"communications_pool": "20D"}, {"name": "Transponder ping", "station": "communications", "target_action": "hail_contact", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6164)
	_assert_equal(hail_alias_assist["event"]["success"], true, "hail alias station assist succeeds")
	_assert_equal(hail_alias_assist["state"]["station_assists"].has("communications"), true, "hail alias banks communications assist")
	var alias_hail_state := comms_state.duplicate(true)
	alias_hail_state["station_assists"] = hail_alias_assist["state"]["station_assists"]
	var alias_assisted_hail: Dictionary = model.resolve_comms_hail(rules, alias_hail_state, comms_ship, comms_contact, {"name": "Hail contact", "difficulty": 10}, 5252)
	_assert_equal(alias_assisted_hail["event"]["station_assist"]["applies"], true, "hail alias assist is consumed by comms hail")
	_assert_equal(alias_assisted_hail["event"]["station_assist"]["target_action"], "communications", "hail alias resolves to communications target action")
	_assert_equal(alias_assisted_hail["state"]["station_assists"].has("communications"), false, "hail alias assist is one-shot")

	var attacker := {
		"id": "trainer",
		"name": "Trainer",
		"position": {"x": 0, "y": 0},
		"scale": "starfighter",
		"gunnery_pool": "4D",
		"fire_control": "1D",
		"weapon_damage": "4D+1",
	}
	var target := {
		"id": "drone",
		"name": "Drone",
		"position": {"x": 90, "y": 0},
		"scale": "starfighter",
		"defense_pool": "3D",
		"hull": "2D+2",
	}
	var unresolved_context: Dictionary = model.targeting_context_for_contact(state, target)
	_assert_equal(unresolved_context["confidence_key"], "unresolved", "untracked target context is unresolved")
	_assert_equal(unresolved_context["has_sensor_track"], false, "untracked target has no sensor track")
	_assert_equal(unresolved_context["gunnery_difficulty_modifier"], 0, "visible target has no sensor targeting penalty")
	_assert_equal(unresolved_context["informational_only"], true, "targeting context is informational")
	var hidden_target := target.duplicate(true)
	hidden_target["hidden_until_revealed"] = true
	hidden_target["dodge_active"] = false
	var hidden_context: Dictionary = model.targeting_context_for_contact(state, hidden_target)
	_assert_equal(hidden_context["sensor_targeting_required"], true, "hidden target requires sensor targeting")
	_assert_equal(hidden_context["gunnery_difficulty_modifier"], 10, "hidden unresolved target gets sensor targeting penalty")
	_assert_equal(hidden_context["informational_only"], false, "hidden target context affects gunnery")
	var tracked_target_state := state.duplicate(true)
	tracked_target_state["sensor_contact_confidence"] = {"drone": model.sensor_confidence_for_margin(9)}
	var tracked_context: Dictionary = model.targeting_context_for_contact(tracked_target_state, target)
	_assert_equal(tracked_context["confidence_key"], "solid", "tracked target context uses persisted confidence")
	_assert_equal(tracked_context["confidence_rank"], 3, "tracked target context carries confidence rank")
	_assert_equal(tracked_context["has_sensor_track"], true, "tracked target has sensor track")
	_assert_equal(tracked_context["gunnery_difficulty_modifier"], 0, "visible tracked target still has no sensor targeting penalty")
	var hidden_tracked_context: Dictionary = model.targeting_context_for_contact(tracked_target_state, hidden_target)
	_assert_equal(hidden_tracked_context["gunnery_difficulty_modifier"], 1, "hidden solid track has small targeting penalty")
	var tracked_shot: Dictionary = model.resolve_gunnery_exchange(rules, tracked_target_state, attacker, target, 5150)
	_assert_equal(tracked_shot["event"]["target_sensor_confidence_key"], "solid", "gunnery event carries target confidence key")
	_assert_equal(tracked_shot["event"]["target_sensor_confidence_rank"], 3, "gunnery event carries target confidence rank")
	_assert_equal(tracked_shot["event"]["target_has_sensor_track"], true, "gunnery event notes tracked target")
	_assert_equal(tracked_shot["event"]["target_sensor_context"]["informational_only"], true, "gunnery confidence is informational")
	var hidden_tracked_shot: Dictionary = model.resolve_gunnery_exchange(rules, tracked_target_state, attacker, hidden_target, 5150)
	_assert_equal(hidden_tracked_shot["event"]["sensor_targeting_required"], true, "hidden tracked shot records sensor targeting requirement")
	_assert_equal(hidden_tracked_shot["event"]["sensor_targeting_applies"], true, "player hidden target shot applies sensor modifier")
	_assert_equal(hidden_tracked_shot["event"]["sensor_targeting_difficulty_modifier"], 1, "solid hidden target adds one difficulty")
	_assert_equal(hidden_tracked_shot["event"]["pre_sensor_difficulty"], 15, "hidden tracked shot records pre-sensor difficulty")
	_assert_equal(hidden_tracked_shot["event"]["difficulty"], 16, "hidden tracked shot difficulty includes sensor modifier")
	var hidden_untracked_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, attacker, hidden_target, 5150)
	_assert_equal(hidden_untracked_shot["event"]["sensor_targeting_difficulty_modifier"], 10, "untracked hidden target adds unresolved sensor modifier")
	_assert_equal(hidden_untracked_shot["event"]["difficulty"], 25, "untracked hidden target difficulty includes unresolved modifier")
	var shot_a: Dictionary = model.resolve_gunnery_exchange(rules, state, attacker, target, 5150)
	var shot_b: Dictionary = model.resolve_gunnery_exchange(rules, state, attacker, target, 5150)
	_assert_equal(shot_a["event"], shot_b["event"], "same gunnery seed replays identical event")
	_assert_equal(shot_a["state"]["gunnery_round"], 2, "gunnery exchange advances round")
	_assert_equal(shot_a["event"]["range_name"], "Medium", "gunnery records range")
	_assert_equal(shot_a["event"]["target_sensor_confidence_key"], "unresolved", "untracked gunnery target is annotated unresolved")
	_assert_equal(shot_a["event"]["base_attack_pool"], "5D", "gunnery plus fire control")
	_assert_equal(shot_a["event"]["scaled_attack_pool"], "5D", "same-scale attack unchanged")
	_assert_equal(shot_a["event"]["scaled_defense_pool"], "3D", "same-scale dodge unchanged")
	var gunnery_assist_state := state.duplicate(true)
	gunnery_assist_state["station_assists"] = {"gunnery": {"station": "gunner", "name": "Gunner bracketing", "target_action": "gunnery", "pool": "1D"}}
	var assisted_shot: Dictionary = model.resolve_gunnery_exchange(rules, gunnery_assist_state, attacker, target, 5150)
	_assert_equal(assisted_shot["event"]["station_assist"]["applies"], true, "gunnery consumes station assist")
	_assert_equal(assisted_shot["event"]["base_attack_pool"], "6D", "gunnery assist adds to attack pool")
	_assert_equal(assisted_shot["state"]["station_assists"].has("gunnery"), false, "gunnery assist is one-shot")
	var wounded_attacker := attacker.duplicate(true)
	wounded_attacker["condition"] = {"crew_wounds": {"gunner": {"station": "gunner", "wound": {"name": "Wounded", "severity": 2}, "severity": 2}}}
	var wounded_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, wounded_attacker, target, 5150)
	_assert_equal(wounded_shot["event"]["attacker_station_wound_penalty_dice"], 1, "gunnery records gunner wound penalty")
	_assert_equal(wounded_shot["event"]["base_attack_pool"], "4D", "wounded gunner loses one attack die")
	var wounded_defender := target.duplicate(true)
	wounded_defender["condition"] = {"crew_wounds": {"pilot": {"station": "pilot", "wound": {"name": "Wounded", "severity": 2}, "severity": 2}}}
	var wounded_defense_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, attacker, wounded_defender, 5150)
	_assert_equal(wounded_defense_shot["event"]["target_station_wound_penalty_dice"], 1, "gunnery records defender pilot wound penalty")
	_assert_equal(wounded_defense_shot["event"]["scaled_defense_pool"], "2D", "wounded defender pilot loses one dodge die")
	var fire_control_alias_assist: Dictionary = model.resolve_crew_station_assist(rules, state, {"fire_control_pool": "20D"}, {"name": "Fire-control lock", "station": "gunner", "target_action": "weapon_solution", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6167)
	_assert_equal(fire_control_alias_assist["event"]["success"], true, "fire-control alias station assist succeeds")
	_assert_equal(fire_control_alias_assist["state"]["station_assists"].has("gunnery"), true, "fire-control alias banks gunnery assist")
	var alias_assisted_shot: Dictionary = model.resolve_gunnery_exchange(rules, fire_control_alias_assist["state"], attacker, target, 5150)
	_assert_equal(alias_assisted_shot["event"]["station_assist"]["applies"], true, "fire-control alias assist is consumed by gunnery")
	_assert_equal(alias_assisted_shot["event"]["station_assist"]["target_action"], "gunnery", "fire-control alias resolves to gunnery target action")
	_assert_equal(alias_assisted_shot["state"]["station_assists"].has("gunnery"), false, "fire-control alias assist is one-shot")

	var shield_target := {
		"id": "shielded_drone",
		"name": "Shielded Drone",
		"position": {"x": 10, "y": 0},
		"scale": "starfighter",
		"defense_pool": "0D",
		"dodge_active": false,
		"hull": "2D+2",
		"shields": "1D",
		"incoming_arc": "front",
		"shield_arcs": {"front": "1D", "rear": "0D", "left": "0D", "right": "0D"},
	}
	var shield_attacker := attacker.duplicate(true)
	shield_attacker["gunnery_pool"] = "20D"
	shield_attacker["fire_control"] = "0D"
	var shield_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, shield_attacker, shield_target, 9090)
	_assert_equal(shield_shot["event"]["hit"], true, "high gunnery shield shot hits")
	_assert_equal(shield_shot["event"]["target_hull_pool"], "2D+2", "shield shot records target hull")
	_assert_equal(shield_shot["event"]["target_shield_pool"], "1D", "shield shot records target shields")
	_assert_equal(shield_shot["event"]["target_base_soak_pool"], "3D+2", "shields add to hull soak")
	_assert_equal(shield_shot["event"]["scaled_soak_pool"], "3D+2", "same-scale shield soak is unchanged")
	_assert_equal(shield_shot["event"]["shield_arc"], "front", "shield shot records covered arc")
	_assert_equal(shield_shot["event"]["damage"]["soak_roll"]["pool"], "3D+2", "damage resolution rolls hull plus shields")
	_assert_equal(shield_shot["event"]["starship_damage"].has("key"), true, "gunnery event carries starship damage result")
	_assert_equal(shield_shot["event"]["system_effect"].has("key"), true, "gunnery event carries system effect result")
	_assert_equal(shield_shot["event"]["passenger_damage"].has("applies"), true, "gunnery event carries passenger damage result")
	_assert_equal(shield_shot["target"].has("condition"), true, "gunnery returns updated target condition")

	var passenger_test_attacker := shield_attacker.duplicate(true)
	passenger_test_attacker["weapon_damage"] = "20D"
	var passenger_test_target := shield_target.duplicate(true)
	passenger_test_target["hull"] = "0D"
	passenger_test_target["shields"] = "0D"
	passenger_test_target["shield_arcs"] = {"front": "0D"}
	passenger_test_target["crew"] = [
		{"id": "pilot", "name": "Pilot", "station": "pilot", "soak": "3D"},
		{"id": "gunner", "name": "Gunner", "station": "gunner", "damage_group": "gunners", "soak": "3D"},
	]
	var passenger_test_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, passenger_test_attacker, passenger_test_target, 9090)
	_assert_equal(passenger_test_shot["event"]["passenger_damage"]["applies"], true, "damaged ship rolls passenger damage")
	_assert_equal(passenger_test_shot["event"]["passenger_damage"]["damage_pool"] != "0D", true, "passenger damage uses nonzero chart pool")
	_assert_equal(passenger_test_shot["event"]["passenger_damage"]["member_wounds"].size() > 0, true, "passenger damage resolves crew member wounds")
	_assert_equal(passenger_test_shot["event"]["passenger_damage"]["member_wounds"][0].has("wound"), true, "crew wound carries WEG wound result")
	_assert_equal(passenger_test_shot["target"]["condition"]["passenger_damage_log"].size() > 0, true, "target condition logs passenger damage")
	_assert_equal(passenger_test_shot["target"]["condition"]["crew_wounds"].has("pilot"), true, "target condition persists crew wound")

	var rear_target := shield_target.duplicate(true)
	rear_target["incoming_arc"] = "rear"
	var rear_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, shield_attacker, rear_target, 9090)
	_assert_equal(rear_shot["event"]["target_shield_pool"], "0D", "unshielded rear arc adds no shields")
	_assert_equal(rear_shot["event"]["shield_arc"], "rear", "rear shot records uncovered arc")
	_assert_equal(rear_shot["event"]["damage"]["soak_roll"]["pool"], "2D+2", "uncovered arc rolls hull soak only")

	var derived_arc_target := shield_target.duplicate(true)
	derived_arc_target.erase("incoming_arc")
	derived_arc_target["heading_degrees"] = 0
	var left_arc_attacker := shield_attacker.duplicate(true)
	left_arc_attacker["position"] = {"x": 10, "y": -10}
	var derived_left_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, left_arc_attacker, derived_arc_target, 9090)
	_assert_equal(derived_left_shot["event"]["shield_arc"], "left", "gunnery derives incoming left arc")
	_assert_equal(derived_left_shot["event"]["target_shield_pool"], "0D", "derived unshielded left arc adds no shields")

	var depleted_shield_target := shield_target.duplicate(true)
	depleted_shield_target["condition"] = {"shield_loss_dice": 1}
	var depleted_shield_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, shield_attacker, depleted_shield_target, 9090)
	_assert_equal(depleted_shield_shot["event"]["target_shield_pool"], "0D", "shield loss reduces later shield soak")

	var ion_attacker := shield_attacker.duplicate(true)
	ion_attacker["weapon_type"] = "ion"
	var ion_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, ion_attacker, shield_target, 9090)
	_assert_equal(ion_shot["event"]["hit"], true, "high gunnery ion shot hits")
	_assert_equal(ion_shot["event"]["target_shield_pool"], "0D", "ion cannon bypasses shields")
	_assert_equal(ion_shot["event"]["damage"]["soak_roll"]["pool"], "2D+2", "ion damage rolls hull soak only")
	_assert_equal(ion_shot["event"]["starship_damage"]["ion_controls"] >= 0, true, "ion gunnery records controls ionized")

	var ionized_attacker := shield_attacker.duplicate(true)
	ionized_attacker["fire_control"] = "1D"
	ionized_attacker["condition"] = {"controls_ionized": 1}
	var ionized_attacker_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, ionized_attacker, shield_target, 9090)
	_assert_equal(ionized_attacker_shot["event"]["attacker_controls_penalty"], 1, "attacker records controls ionized penalty")
	_assert_equal(ionized_attacker_shot["event"]["base_attack_pool"], "20D", "controls ionized reduces fire control")
	_assert_equal(ionized_attacker_shot["event"]["scaled_damage_pool"], "3D+1", "controls ionized reduces weapon damage")

	var ionized_target := shield_target.duplicate(true)
	ionized_target["condition"] = {"controls_ionized": 1}
	var ionized_target_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, shield_attacker, ionized_target, 9090)
	_assert_equal(ionized_target_shot["event"]["target_controls_penalty"], 1, "target records controls ionized penalty")
	_assert_equal(ionized_target_shot["event"]["target_shield_pool"], "0D", "controls ionized reduces target shields")

	var maneuver_damaged_target := target.duplicate(true)
	maneuver_damaged_target["condition"] = {"maneuverability_loss_dice": 1}
	var maneuver_damaged_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, attacker, maneuver_damaged_target, 5150)
	_assert_equal(maneuver_damaged_shot["event"]["target_maneuverability_penalty"], 1, "target records maneuverability loss")
	_assert_equal(maneuver_damaged_shot["event"]["scaled_defense_pool"], "2D", "maneuverability loss reduces defensive maneuver pool")

	var dead_target := target.duplicate(true)
	dead_target["condition"] = {"drives_disabled": true}
	var dead_target_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, attacker, dead_target, 5150)
	_assert_equal(dead_target_shot["event"]["target_drives_disabled"], true, "dead target records disabled drives")
	_assert_equal(dead_target_shot["event"]["scaled_defense_pool"], "0D", "dead-in-space target cannot maneuver defensively")

	var disabled_attacker := attacker.duplicate(true)
	disabled_attacker["condition"] = {"weapons_disabled": true}
	var disabled_attacker_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, disabled_attacker, target, 5150)
	_assert_equal(disabled_attacker_shot["event"]["attacker_weapons_disabled"], true, "disabled weapons flag reaches gunnery")
	_assert_equal(disabled_attacker_shot["event"]["base_attack_pool"], "0D", "disabled weapons prevent attack pool")

	var counterfire_attacker := {
		"id": "local_ship",
		"name": "Local Ship",
		"position": {"x": 0, "y": 0},
		"scale": "starfighter",
		"gunnery_pool": "1D",
		"fire_control": "0D",
		"weapon_damage": "0D",
		"defense_pool": "0D",
		"dodge_active": false,
		"hull": "0D",
		"shields": "0D",
	}
	var counterfire_target := {
		"id": "hostile_shadow",
		"name": "Hostile Shadow",
		"position": {"x": 10, "y": 0},
		"scale": "starfighter",
		"defense_pool": "0D",
		"hull": "20D",
		"shields": "0D",
		"counterfire": true,
		"gunnery_pool": "20D",
		"fire_control": "0D",
		"weapon_damage": "20D",
	}
	var counterfire_exchange: Dictionary = model.resolve_gunnery_exchange_with_counterfire(rules, state, counterfire_attacker, counterfire_target, 9191)
	_assert_equal(counterfire_exchange["counterfire"]["applies"], true, "counterfire target fires back")
	_assert_equal(counterfire_exchange["counterfire"]["event"]["hit"], true, "counterfire rolls a normal gunnery hit")
	_assert_equal(counterfire_exchange["attacker"].has("condition"), true, "counterfire updates original attacker condition")
	_assert_equal(int(counterfire_exchange["attacker"]["condition"]["worst_hull_severity"]) > 0 or bool(counterfire_exchange["attacker"]["condition"]["destroyed"]), true, "counterfire persists damage on original attacker")
	_assert_equal(counterfire_exchange["state"]["gunnery_round"], 3, "primary exchange plus counterfire advances gunnery rounds")
	var disabled_counterfire_target := counterfire_target.duplicate(true)
	disabled_counterfire_target["condition"] = {"weapons_disabled": true}
	var disabled_counterfire_exchange: Dictionary = model.resolve_gunnery_exchange_with_counterfire(rules, state, counterfire_attacker, disabled_counterfire_target, 9191)
	_assert_equal(disabled_counterfire_exchange["counterfire"]["applies"], false, "disabled hostile cannot counterfire")
	_assert_equal(disabled_counterfire_exchange["counterfire"]["reason"], "weapons_disabled", "disabled counterfire reports reason")
	var solution_required_target := counterfire_target.duplicate(true)
	solution_required_target["id"] = "solution_required"
	solution_required_target["counterfire_requires_solution"] = true
	solution_required_target["movement"] = {"lock_rounds_to_fire": 2}
	var no_solution_counterfire: Dictionary = model.resolve_gunnery_exchange_with_counterfire(rules, state, counterfire_attacker, solution_required_target, 9191)
	_assert_equal(no_solution_counterfire["counterfire"]["applies"], false, "solution-gated hostile cannot counterfire without ready lock")
	_assert_equal(no_solution_counterfire["counterfire"]["reason"], "weapon_solution_not_ready", "solution-gated counterfire reports not-ready reason")
	var ready_solution_state := state.duplicate(true)
	ready_solution_state["weapon_solution_counts"] = {"solution_required": 2}
	var weak_counterfire_attacker := counterfire_attacker.duplicate(true)
	weak_counterfire_attacker["gunnery_pool"] = "0D"
	weak_counterfire_attacker["fire_control"] = "0D"
	var evasive_solution_target := solution_required_target.duplicate(true)
	evasive_solution_target["position"] = {"x": 320, "y": 0}
	evasive_solution_target["dodge_active"] = false
	var ready_solution_counterfire: Dictionary = model.resolve_gunnery_exchange_with_counterfire(rules, ready_solution_state, weak_counterfire_attacker, evasive_solution_target, 9191)
	_assert_equal(ready_solution_counterfire["event"]["hit"], false, "missed player shot leaves ready solution intact")
	_assert_equal(ready_solution_counterfire["counterfire"]["applies"], true, "solution-gated hostile counterfires with ready lock")
	_assert_equal(ready_solution_counterfire["counterfire"]["consumed_weapon_solution"]["applies"], true, "solution-gated counterfire reports consumed lock")
	_assert_equal(ready_solution_counterfire["counterfire"]["consumed_weapon_solution"]["prior_rounds"], 2, "solution-gated counterfire reports consumed lock rounds")
	_assert_equal(ready_solution_counterfire["state"]["weapon_solution_counts"].has("solution_required"), false, "solution-gated counterfire consumes ready lock")
	var locked_gunnery_state := state.duplicate(true)
	locked_gunnery_state["weapon_solution_counts"] = {"locked_target": 2}
	var lock_break_attacker := shield_attacker.duplicate(true)
	lock_break_attacker["id"] = "lock_breaker"
	var locked_target := {
		"id": "locked_target",
		"name": "Locked Target",
		"position": {"x": 10, "y": 0},
		"scale": "starfighter",
		"defense_pool": "0D",
		"dodge_active": false,
		"hull": "20D",
		"shields": "0D",
	}
	var disrupted_lock_shot: Dictionary = model.resolve_gunnery_exchange_with_counterfire(rules, locked_gunnery_state, lock_break_attacker, locked_target, 9090)
	_assert_equal(disrupted_lock_shot["lock_disruption"]["applies"], true, "successful gunnery hit disrupts target lock")
	_assert_equal(disrupted_lock_shot["lock_disruption"]["prior_rounds"], 2, "lock disruption reports prior lock rounds")
	_assert_equal(disrupted_lock_shot["state"]["weapon_solution_counts"].has("locked_target"), false, "successful gunnery hit clears target lock state")
	var missed_lock_state := state.duplicate(true)
	missed_lock_state["weapon_solution_counts"] = {"missed_target": 2}
	var miss_attacker := lock_break_attacker.duplicate(true)
	miss_attacker["gunnery_pool"] = "0D"
	miss_attacker["fire_control"] = "0D"
	var missed_target := locked_target.duplicate(true)
	missed_target["id"] = "missed_target"
	missed_target["position"] = {"x": 320, "y": 0}
	var missed_lock_shot: Dictionary = model.resolve_gunnery_exchange_with_counterfire(rules, missed_lock_state, miss_attacker, missed_target, 9090)
	_assert_equal(missed_lock_shot["event"]["hit"], false, "low gunnery misses lock target")
	_assert_equal(missed_lock_shot["lock_disruption"]["applies"], false, "missed gunnery does not disrupt lock")
	_assert_equal(missed_lock_shot["state"]["weapon_solution_counts"].has("missed_target"), true, "missed gunnery keeps target lock state")

	var shield_ship := {
		"id": "operator_test",
		"name": "Operator Test",
		"shields": "1D",
		"starship_shields_pool": "20D",
	}
	var reroute: Dictionary = model.resolve_shield_reroute(rules, state, shield_ship, ["front", "rear", "front"], 4242)
	_assert_equal(reroute["event"]["success"], true, "high shield operator reroute succeeds")
	_assert_equal(reroute["event"]["requested_arcs"], ["front", "rear"], "reroute deduplicates requested arcs")
	_assert_equal(reroute["event"]["difficulty"], 10, "two shield arcs are moderate difficulty")
	_assert_equal(reroute["ship"]["shield_arcs"]["front"], "1D", "reroute covers front arc")
	_assert_equal(reroute["ship"]["shield_arcs"]["rear"], "1D", "reroute covers rear arc")
	_assert_equal(reroute["state"]["shield_round"], 2, "shield reroute advances shield round")
	var wounded_shield_ship := shield_ship.duplicate(true)
	wounded_shield_ship["condition"] = {"crew_wounds": {"shields": {"station": "shields", "wound": {"name": "Wounded", "severity": 2}, "severity": 2}}}
	var wounded_reroute: Dictionary = model.resolve_shield_reroute(rules, state, wounded_shield_ship, ["front"], 4242)
	_assert_equal(wounded_reroute["event"]["station_wound_penalty_dice"], 1, "shield reroute records shield-operator wound penalty")
	_assert_equal(wounded_reroute["event"]["shield_pool"], "19D", "wounded shield operator loses one die")
	var shield_alias_assist: Dictionary = model.resolve_crew_station_assist(rules, state, {"starship_shields_pool": "20D"}, {"name": "Angle deflectors", "station": "copilot", "target_action": "angle_shields", "pool": "20D", "bonus_pool": "1D", "difficulty": 10}, 6168)
	_assert_equal(shield_alias_assist["event"]["success"], true, "shield alias station assist succeeds")
	_assert_equal(shield_alias_assist["state"]["station_assists"].has("shields"), true, "shield alias banks shields assist")
	var alias_reroute: Dictionary = model.resolve_shield_reroute(rules, shield_alias_assist["state"], shield_ship, ["front"], 4242)
	_assert_equal(alias_reroute["event"]["station_assist"]["applies"], true, "shield alias assist is consumed by shield reroute")
	_assert_equal(alias_reroute["event"]["station_assist"]["target_action"], "shields", "shield alias resolves to shields target action")
	_assert_equal(alias_reroute["event"]["shield_pool"], "21D", "shield alias assist adds to shield pool")
	_assert_equal(alias_reroute["state"]["station_assists"].has("shields"), false, "shield alias assist is one-shot")

	var capital_attacker := attacker.duplicate(true)
	capital_attacker["scale"] = "capital"
	capital_attacker["weapon_damage"] = "5D"
	var fighter_target := target.duplicate(true)
	fighter_target["scale"] = "starfighter"
	var capital_shot: Dictionary = model.resolve_gunnery_exchange(rules, state, capital_attacker, fighter_target, 5150)
	_assert_equal(capital_shot["event"]["scale_difference"], -6, "capital to starfighter scale difference")
	_assert_equal(capital_shot["event"]["scaled_attack_pool"], "5D", "higher scale attack pool stays normal")
	_assert_equal(capital_shot["event"]["scaled_defense_pool"], "9D", "lower scale target adds scale to dodge")
	if bool(capital_shot["event"]["hit"]):
		_assert_equal(capital_shot["event"]["damage"]["damage_roll"]["pool"], "11D", "higher scale weapon adds scale to damage")

	rules.free()
	rules_script = null
	model_script = null

	if _failures.is_empty():
		print("space_tactical_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
