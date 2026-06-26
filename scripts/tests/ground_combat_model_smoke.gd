extends SceneTree

const RangeActionWindowModel = preload("res://scripts/rules/range_action_window_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var rules_script: GDScript = load("res://scripts/rules/d6_rules.gd")
	var rules: Node = rules_script.new()
	var model_script: GDScript = load("res://scripts/rules/ground_combat_model.gd")
	var model: RefCounted = model_script.new()

	var state: Dictionary = model.initial_state()
	_assert_equal(state["round"], 1, "initial round")
	_assert_equal(state["action_window_seconds"], 5.0, "initial action window")
	_assert_equal(state["aim_bonus_dice"], 0, "initial aim")
	_assert_equal(state["player_cover_level"], 0, "initial cover")
	_assert_equal(state["player_defense"], "none", "initial defense")
	_assert_equal(state["player_character_points"], 5, "initial character points")
	_assert_equal(state["player_force_points"], 1, "initial force points")
	_assert_equal(state["force_point_active"], false, "initial force point inactive")
	_assert_equal(state["pending_attack_cp"], 0, "initial pending attack cp")
	_assert_equal(state["pending_soak_cp"], 0, "initial pending soak cp")

	state = model.add_aim(state)
	state = model.add_aim(state)
	state = model.add_aim(state)
	state = model.add_aim(state)
	_assert_equal(state["aim_bonus_dice"], 3, "aim caps at 3D")

	state = model.toggle_cover(state)
	_assert_equal(state["player_cover_level"], 2, "cover toggles to half")
	state = model.toggle_cover(state)
	_assert_equal(state["player_cover_level"], 0, "cover toggles off")

	state = model.declare_defense(state, "dodge")
	_assert_equal(state["player_defense"], "dodge", "normal dodge declaration")
	state = model.declare_defense(state, "full_dodge")
	_assert_equal(state["player_defense"], "full_dodge", "full dodge declaration")
	state = model.declare_defense(state, "bogus")
	_assert_equal(state["player_defense"], "none", "unknown defense clears declaration")

	state = model.queue_attack_cp(model.initial_state(), 6)
	_assert_equal(state["pending_attack_cp"], 5, "attack cp queue caps at available cp and max spend")
	state = model.queue_soak_cp(model.initial_state(), 2)
	_assert_equal(state["pending_soak_cp"], 2, "soak cp queues")
	state = model.activate_force_point(model.initial_state())
	_assert_equal(state["force_point_active"], true, "force point activates")
	state = model.queue_attack_cp(state, 1)
	_assert_equal(state["pending_attack_cp"], 0, "cannot queue attack cp during force point window")
	state = model.queue_attack_cp(model.initial_state(), 1)
	state = model.activate_force_point(state)
	_assert_equal(state["force_point_active"], false, "cannot activate force point with queued cp")

	var disabled: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 3}, _pools(), 12.0, 0, 123)
	_assert_equal(disabled["already_disabled"], true, "disabled target is not resolved again")
	_assert_equal(disabled["state"]["round"], 1, "disabled target does not advance round")
	_assert_equal(disabled["events"][0]["type"], "target_already_disabled", "disabled target event")
	_assert_equal(disabled["exchange_seed"], 123, "disabled target preserves exchange seed")

	state = model.add_aim(model.initial_state())
	var blocked: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 456)
	_assert_equal(blocked["already_disabled"], false, "full cover exchange resolves")
	_assert_equal(blocked["exchange_seed"], 456, "resolved exchange preserves seed")
	_assert_equal(blocked["attack"]["blocked"], true, "full cover blocks player shot")
	_assert_equal(blocked["state"]["round"], 2, "resolved exchange advances round")
	_assert_equal(blocked["state"]["aim_bonus_dice"], 0, "resolved exchange consumes aim")
	_assert_equal(blocked["player_action_count"], 1, "single attack action count")
	_assert_equal(rules.pool_to_string(blocked["shot_pool"]), "5D+1", "aim adds after action penalty")
	_assert_equal(blocked["events"][0]["type"], "player_attack", "exchange starts with player attack event")
	_assert_equal(blocked["events"][0]["exchange_seed"], 456, "player attack event includes seed")
	_assert_equal(blocked["events"][0]["blocked"], true, "player attack event records blocked shot")
	_assert_equal(blocked["events"][0]["shot_pool"], "5D+1", "player attack event records shot pool")
	_assert_equal(blocked["events"][blocked["events"].size() - 1]["type"], "exchange_completed", "exchange completion event")

	state = model.toggle_cover(model.initial_state())
	var from_cover: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 789)
	_assert_equal(from_cover["state"]["player_cover_level"], 1, "attacking from half cover degrades to quarter")

	state = model.declare_defense(model.initial_state(), "dodge")
	var dodging: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 901)
	_assert_equal(dodging["state"]["player_defense"], "none", "normal dodge is consumed by return fire")
	_assert_equal(dodging["player_action_count"], 2, "normal dodge creates two-action window")
	_assert_equal(rules.pool_to_string(dodging["shot_pool"]), "3D+1", "normal dodge penalizes player shot")
	_assert_equal(dodging["events"][0]["action_count"], 2, "normal dodge attack event records two actions")
	_assert_equal(dodging["events"][0]["shot_pool"], "3D+1", "normal dodge attack event records penalized shot pool")
	_assert_equal(dodging["return_fire"]["attack"]["defense"]["type"], "dodge", "return fire sees normal dodge")
	_assert_equal(dodging["return_fire"]["attack"]["defense"]["replaces"], true, "normal dodge replaces return-fire range difficulty")
	_assert_equal(dodging["return_fire"]["attack"]["defense"]["roll"]["pool"], "3D", "normal dodge return fire applies multi-action penalty")
	_assert_equal(_has_event(dodging["events"], "remote_return_fire"), true, "normal dodge exchange emits return-fire event")

	state = model.declare_defense(model.initial_state(), "full_dodge")
	var full_dodging: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 902)
	_assert_equal(full_dodging["state"]["player_defense"], "none", "full dodge is consumed by return fire")
	_assert_equal(full_dodging["player_attack_skipped"], true, "full dodge skips player attack")
	_assert_equal(full_dodging["skip_reason"], "full_dodge", "full dodge skip reason")
	_assert_equal(full_dodging["player_action_count"], 1, "full dodge is a single defense-only action")
	_assert_equal(rules.pool_to_string(full_dodging["shot_pool"]), "0D", "full dodge has no shot pool")
	_assert_equal(full_dodging["attack"].is_empty(), true, "full dodge has no attack payload")
	_assert_equal(full_dodging["events"][0]["type"], "player_full_dodge", "full dodge emits defense-only event")
	_assert_equal(full_dodging["return_fire"]["attack"]["defense"]["type"], "full_dodge", "return fire sees full dodge")
	_assert_equal(full_dodging["return_fire"]["attack"]["defense"]["replaces"], false, "full dodge adds to return-fire range difficulty")
	_assert_equal(full_dodging["return_fire"]["attack"]["defense"]["roll"]["pool"], "4D", "full dodge return fire keeps full pool")
	_assert_equal(_event_by_type(full_dodging["events"], "remote_return_fire").get("defense_type", ""), "full_dodge", "return-fire event records full dodge")

	state = model.declare_defense(model.initial_state(), "dodge")
	var incoming_window_pools := _pools()
	incoming_window_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	var incoming_window: Dictionary = model.resolve_incoming_fire_window(
		rules,
		state,
		incoming_window_pools,
		[
			{"source_id": "remote_a", "source_name": "Remote A", "distance": 12.0, "cover_level": 0},
			{"source_id": "remote_b", "source_name": "Remote B", "distance": 18.0, "cover_level": 0},
		],
		920
	)
	_assert_equal(incoming_window["incoming"].size(), 2, "incoming fire window resolves two attacks")
	_assert_equal(incoming_window["state"]["round"], 2, "incoming fire window advances round")
	_assert_equal(incoming_window["state"]["player_defense"], "none", "incoming fire window consumes defense")
	_assert_equal(incoming_window["defense"].has("cached_roll"), true, "incoming fire window caches defense roll")
	_assert_equal(incoming_window["incoming"][0]["attack"]["defense"]["value"], incoming_window["defense"]["value"], "first incoming attack uses cached defense")
	_assert_equal(incoming_window["incoming"][1]["attack"]["defense"]["value"], incoming_window["defense"]["value"], "second incoming attack uses cached defense")
	_assert_equal(_event_by_type(incoming_window["events"], "incoming_fire_window_completed").get("incoming_count", 0), 2, "incoming window completion event records count")

	state = model.declare_defense(model.initial_state(), "dodge")
	var packet_window := RangeActionWindowModel.assemble_resolution_window(
		state,
		[
			{"source_id": "remote_a", "source_name": "Remote A", "distance": 12.0, "cover_level": 0},
			{"source_id": "remote_b", "source_name": "Remote B", "distance": 18.0, "cover_level": 0},
		]
	)
	var packet_incoming: Dictionary = model.resolve_incoming_fire_window_with_action_window(
		rules,
		state,
		incoming_window_pools,
		[
			{"source_id": "remote_a", "source_name": "Remote A", "distance": 12.0, "cover_level": 0},
			{"source_id": "remote_b", "source_name": "Remote B", "distance": 18.0, "cover_level": 0},
		],
		packet_window,
		922
	)
	_assert_equal(packet_incoming.get("invalid_action_window", false), false, "ready packet resolves incoming fire")
	_assert_equal(packet_incoming["action_window"]["ready"], true, "resolved incoming fire keeps action-window packet")
	_assert_equal(packet_incoming["action_window"]["active_ids"], ["trainee", "remote_a", "remote_b"], "incoming packet records active participants")

	state = model.declare_defense(model.initial_state(), "dodge")
	var packet_exchange_window := RangeActionWindowModel.assemble_resolution_window(state, [], "remote_a")
	var packet_exchange: Dictionary = model.resolve_exchange_with_action_window(
		rules,
		state,
		{"wound_severity": 0},
		_pools(),
		12.0,
		4,
		packet_exchange_window,
		923
	)
	_assert_equal(packet_exchange.get("invalid_action_window", false), false, "ready packet resolves player exchange")
	_assert_equal(packet_exchange["action_window"]["state"]["declarations"].has("trainee"), true, "player exchange keeps declaration state")

	var invalid_state: Dictionary = model.queue_attack_cp(model.initial_state(), 1)
	invalid_state["force_point_active"] = true
	var invalid_packet := RangeActionWindowModel.assemble_resolution_window(invalid_state, [], "remote_a")
	var invalid_exchange: Dictionary = model.resolve_exchange_with_action_window(
		rules,
		invalid_state,
		{"wound_severity": 0},
		_pools(),
		12.0,
		4,
		invalid_packet,
		924
	)
	_assert_equal(invalid_exchange["invalid_action_window"], true, "invalid packet blocks exchange resolution")
	_assert_equal(invalid_exchange["state"]["round"], 1, "invalid packet does not advance round")
	_assert_equal(invalid_exchange["events"][0]["type"], "action_window_invalid", "invalid packet emits event")

	state = model.queue_soak_cp(model.initial_state(), 2)
	var incoming_soak_cp: Dictionary = model.resolve_incoming_fire_window(
		rules,
		state,
		incoming_window_pools,
		[
			{"source_id": "remote_a", "distance": 12.0, "cover_level": 0},
			{"source_id": "remote_b", "distance": 12.0, "cover_level": 0},
		],
		921
	)
	_assert_equal(incoming_soak_cp["incoming"][0]["hit"], true, "first high-pool incoming attack hits")
	_assert_equal(incoming_soak_cp["incoming"][1]["hit"], true, "second high-pool incoming attack hits")
	_assert_equal(incoming_soak_cp["incoming"][0]["soak_cp_spent"], 2, "queued soak cp spends on first hit")
	_assert_equal(incoming_soak_cp["incoming"][1]["soak_cp_spent"], 0, "queued soak cp is not spent twice")
	_assert_equal(incoming_soak_cp["state"]["player_character_points"], 3, "incoming window soak cp reduces character points once")

	var incoming_weapon_pools := _pools()
	incoming_weapon_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	var incoming_target_weapon: Dictionary = model.resolve_incoming_fire_window(
		rules,
		model.initial_state(),
		incoming_weapon_pools,
		[
			{"source_id": "remote_custom", "distance": 12.0, "cover_level": 0, "damage_pool": {"dice": 1, "pips": 1}},
		],
		922
	)
	_assert_equal(incoming_target_weapon["incoming"][0]["damage"]["damage_roll"]["pool"], "1D+1", "incoming fire can override source damage pool")

	var incoming_partial_armor_pools := _pools()
	incoming_partial_armor_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	incoming_partial_armor_pools["player_armor"] = _torso_vest()
	var incoming_partial_armor: Dictionary = model.resolve_incoming_fire_window(
		rules,
		model.initial_state(),
		incoming_partial_armor_pools,
		[
			{"source_id": "remote_called_shot", "distance": 12.0, "cover_level": 0, "hit_location": "left_arm"},
		],
		923
	)
	_assert_equal(incoming_partial_armor["incoming"][0]["damage"]["soak_roll"]["pool"], "3D", "incoming fire hit-location override can bypass partial armor")
	_assert_equal(_event_by_type(incoming_partial_armor["events"], "incoming_fire").get("player_hit_location", ""), "left_arm", "incoming-fire event records hit-location override")
	_assert_equal(_event_by_type(incoming_partial_armor["events"], "incoming_fire").get("player_armor_applied", true), false, "incoming-fire event records uncovered armor")

	state = model.initial_state()
	state["player_wound_severity"] = 1
	var stunned_attack: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 903)
	_assert_equal(stunned_attack["player_wound_penalty_dice"], 1, "stunned trainee has one penalty die")
	_assert_equal(rules.pool_to_string(stunned_attack["shot_pool"]), "3D+1", "stun penalty reduces player shot")
	_assert_equal(stunned_attack["events"][0]["wound_penalty_dice"], 1, "attack event records wound penalty")

	state = model.declare_defense(model.initial_state(), "dodge")
	state["player_wound_severity"] = 1
	var stunned_dodge: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 904)
	_assert_equal(rules.pool_to_string(stunned_dodge["shot_pool"]), "2D+1", "stun plus normal dodge penalties stack on shot")
	_assert_equal(stunned_dodge["return_fire"]["attack"]["defense"]["roll"]["pool"], "2D", "stun plus normal dodge penalties stack on dodge")

	state = model.initial_state()
	state["player_wound_severity"] = 1
	var high_accuracy_pools := _pools()
	high_accuracy_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	var stunned_soak: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, high_accuracy_pools, 12.0, 4, 905)
	_assert_equal(stunned_soak["return_fire"]["hit"], true, "high accuracy remote hits stunned trainee")
	_assert_equal(stunned_soak["return_fire"]["player_wound_penalty_dice"], 1, "return fire records player wound penalty")
	_assert_equal(stunned_soak["return_fire"]["damage"]["soak_roll"]["pool"], "2D", "stun penalty reduces player soak")

	var wounded_target_pools := _pools()
	wounded_target_pools["attacker_pool"] = {"dice": 20, "pips": 0}
	var wounded_target_soak: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 2}, wounded_target_pools, 12.0, 0, 906)
	_assert_equal(wounded_target_soak["target_damage"]["soak_roll"]["pool"], "1D", "wounded target has reduced soak")
	_assert_equal(_event_by_type(wounded_target_soak["events"], "target_damage").get("wound_penalty_dice", 0), 1, "target damage event records wound penalty")

	var wounded_target_fire: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 2}, _pools(), 12.0, 4, 907)
	_assert_equal(wounded_target_fire["return_fire"]["attack"]["attack"]["pool"], "2D", "wounded target has reduced return-fire pool")
	_assert_equal(wounded_target_fire["return_fire"]["target_wound_penalty_dice"], 1, "return fire records target wound penalty")
	_assert_equal(_event_by_type(wounded_target_fire["events"], "remote_return_fire").get("target_wound_penalty_dice", 0), 1, "return-fire event records target wound penalty")

	var target_weapon_pools := _pools()
	target_weapon_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	target_weapon_pools["target_damage_pool"] = {"dice": 2, "pips": 2}
	var target_weapon_fire: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, target_weapon_pools, 12.0, 4, 929)
	_assert_equal(target_weapon_fire["return_fire"]["hit"], true, "target-specific weapon high-pool remote hits")
	_assert_equal(target_weapon_fire["return_fire"]["damage"]["damage_roll"]["pool"], "2D+2", "return fire uses target-specific damage pool")

	var walker_target_pools := _pools()
	walker_target_pools["attacker_pool"] = {"dice": 20, "pips": 1}
	walker_target_pools["attacker_scale"] = "character"
	walker_target_pools["target_scale"] = "walker"
	var walker_target: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, walker_target_pools, 12.0, 0, 930)
	_assert_equal(rules.pool_to_string(walker_target["shot_pool"]), "24D+1", "character attacker adds scale dice to hit walker-scale target")
	_assert_equal(walker_target["target_damage"]["soak_roll"]["pool"], "6D", "walker-scale target adds scale dice to soak")
	_assert_equal(walker_target["target_damage"]["damage_roll"]["pool"], "4D", "character-scale weapon damage is unchanged against walker target")

	var walker_fire_pools := _pools()
	walker_fire_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	walker_fire_pools["attacker_scale"] = "character"
	walker_fire_pools["target_scale"] = "walker"
	state = model.declare_defense(model.initial_state(), "dodge")
	var walker_fire: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, walker_fire_pools, 12.0, 4, 931)
	_assert_equal(walker_fire["return_fire"]["attack"]["defense"]["roll"]["pool"], "7D", "character target adds walker scale dice to normal dodge after action penalty")
	if bool(walker_fire["return_fire"]["hit"]):
		_assert_equal(walker_fire["return_fire"]["damage"]["damage_roll"]["pool"], "8D", "walker-scale weapon adds scale dice to damage")

	var armored_player_pools := _pools()
	armored_player_pools["player_armor"] = _blast_vest()
	var armored_player_attack: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, armored_player_pools, 12.0, 4, 913)
	_assert_equal(rules.pool_to_string(armored_player_attack["shot_pool"]), "3D+1", "armor dex penalty reduces player attack")

	state = model.declare_defense(model.initial_state(), "dodge")
	var armored_player_dodge: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, armored_player_pools, 12.0, 4, 914)
	_assert_equal(rules.pool_to_string(armored_player_dodge["shot_pool"]), "2D+1", "armor plus normal dodge penalties stack on shot")
	_assert_equal(armored_player_dodge["return_fire"]["attack"]["defense"]["roll"]["pool"], "2D", "armor plus normal dodge penalties stack on dodge")

	var armored_remote_pools := _pools()
	armored_remote_pools["target_armor"] = _blast_vest()
	var armored_remote_fire: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, armored_remote_pools, 12.0, 4, 915)
	_assert_equal(armored_remote_fire["return_fire"]["attack"]["attack"]["pool"], "2D", "target armor dex penalty reduces return-fire pool")

	var armored_target_pools := _pools()
	armored_target_pools["attacker_pool"] = {"dice": 20, "pips": 0}
	armored_target_pools["target_armor"] = _blast_vest()
	var armored_target_soak: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, armored_target_pools, 12.0, 0, 916)
	_assert_equal(armored_target_soak["target_damage"]["soak_roll"]["pool"], "2D+1", "target armor energy protection adds to soak")

	# F64: a bare-"+2" armor (WEG's natural pip-only form) applies its +2 soak END-TO-END through
	# resolve_exchange. The armor smokes only ever used the parser-safe "0D+1" form, so the half-fix
	# (armor_condition_model._pool_text_has_pips rejecting no-"D" tokens -> armor dropped from
	# covered_locations -> armor_for_location {} -> 0 soak) shipped green. Target soak 2D + a "+2"
	# energy armor -> 2D+2, NOT 2D (armor silently dropped).
	var pip_armor_target_pools := _pools()
	pip_armor_target_pools["attacker_pool"] = {"dice": 20, "pips": 0}  # reliably hit -> target soak rolled
	pip_armor_target_pools["target_armor"] = {"protection_energy": "+2", "protection_physical": "+2"}
	var pip_armor_target: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, pip_armor_target_pools, 12.0, 0, 9164)
	_assert_equal(pip_armor_target["target_damage"]["soak_roll"]["pool"], "2D+2", "F64: a bare-'+2' armor applies its +2 soak end-to-end (not 2D with the armor dropped)")

	var covered_target_pools := _pools()
	covered_target_pools["attacker_pool"] = {"dice": 20, "pips": 0}
	covered_target_pools["target_armor"] = _torso_vest()
	covered_target_pools["target_hit_location_override"] = "torso"
	var covered_target: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, covered_target_pools, 12.0, 0, 9163)
	_assert_equal(covered_target["target_damage"]["soak_roll"]["pool"], "2D+1", "covered target location receives armor soak")
	_assert_equal(_event_by_type(covered_target["events"], "target_damage").get("hit_location", ""), "torso", "target damage event records covered hit location")
	_assert_equal(_event_by_type(covered_target["events"], "target_damage").get("armor_applied", false), true, "target damage event records covered armor")

	var uncovered_target_pools := _pools()
	uncovered_target_pools["attacker_pool"] = {"dice": 20, "pips": 0}
	uncovered_target_pools["target_armor"] = _torso_vest()
	uncovered_target_pools["target_hit_location_override"] = "left_arm"
	var uncovered_target: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, uncovered_target_pools, 12.0, 0, 9164)
	_assert_equal(uncovered_target["target_damage"]["soak_roll"]["pool"], "2D", "uncovered target location skips armor soak")
	_assert_equal(_event_by_type(uncovered_target["events"], "target_damage").get("hit_location", ""), "left_arm", "target damage event records uncovered hit location")
	_assert_equal(_event_by_type(uncovered_target["events"], "target_damage").get("armor_applied", true), false, "target damage event records uncovered armor")

	var degraded_target_pools := _pools()
	degraded_target_pools["attacker_pool"] = {"dice": 20, "pips": 0}
	degraded_target_pools["damage_pool"] = {"dice": 20, "pips": 0}
	degraded_target_pools["target_armor"] = _blast_vest()
	var degraded_target: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, degraded_target_pools, 12.0, 0, 9161)
	_assert_equal(degraded_target["target_state"]["armor_quality_pips"], -2, "severe target damage degrades armor by two pips")
	_assert_equal(_event_by_type(degraded_target["events"], "target_damage").get("armor_degraded_pips", 0), 2, "target damage event records armor degradation")
	var already_degraded_target: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0, "armor_quality_pips": -1}, armored_target_pools, 12.0, 0, 9162)
	_assert_equal(already_degraded_target["target_damage"]["soak_roll"]["pool"], "2D", "damaged target armor loses one pip of soak")

	var armored_player_soak_pools := _pools()
	armored_player_soak_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	armored_player_soak_pools["player_armor"] = _blast_vest()
	var armored_player_soak: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, armored_player_soak_pools, 12.0, 4, 917)
	_assert_equal(armored_player_soak["return_fire"]["damage"]["soak_roll"]["pool"], "3D+1", "player armor energy protection adds to soak")

	var covered_player_pools := _pools()
	covered_player_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	covered_player_pools["player_armor"] = _torso_vest()
	covered_player_pools["player_hit_location_override"] = "torso"
	var covered_player: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, covered_player_pools, 12.0, 4, 9173)
	_assert_equal(covered_player["return_fire"]["damage"]["soak_roll"]["pool"], "3D+1", "covered player location receives armor soak")
	_assert_equal(_event_by_type(covered_player["events"], "remote_return_fire").get("player_hit_location", ""), "torso", "return-fire event records covered hit location")
	_assert_equal(_event_by_type(covered_player["events"], "remote_return_fire").get("player_armor_applied", false), true, "return-fire event records covered armor")

	var uncovered_player_pools := _pools()
	uncovered_player_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	uncovered_player_pools["player_armor"] = _torso_vest()
	uncovered_player_pools["player_hit_location_override"] = "left_arm"
	var uncovered_player: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, uncovered_player_pools, 12.0, 4, 9174)
	_assert_equal(uncovered_player["return_fire"]["damage"]["soak_roll"]["pool"], "3D", "uncovered player location skips armor soak")
	_assert_equal(_event_by_type(uncovered_player["events"], "remote_return_fire").get("player_hit_location", ""), "left_arm", "return-fire event records uncovered hit location")
	_assert_equal(_event_by_type(uncovered_player["events"], "remote_return_fire").get("player_armor_applied", true), false, "return-fire event records uncovered armor")

	var degraded_player_armor_pools := _pools()
	degraded_player_armor_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	degraded_player_armor_pools["target_damage_pool"] = {"dice": 20, "pips": 0}
	degraded_player_armor_pools["player_armor"] = _blast_vest()
	var degraded_player_armor: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, degraded_player_armor_pools, 12.0, 4, 9172)
	_assert_equal(degraded_player_armor["return_fire"]["player_armor_degraded_pips"], 1, "stun damage degrades player armor by one pip")
	_assert_equal(degraded_player_armor["state"]["player_armor_quality_pips"], -1, "player armor quality persists after return fire")
	_assert_equal(_event_by_type(degraded_player_armor["events"], "remote_return_fire").get("player_armor_degraded_pips", 0), 1, "return-fire event records player armor degradation")
	var player_damaged_armor_state: Dictionary = model.initial_state()
	player_damaged_armor_state["player_armor_quality_pips"] = -1
	var damaged_player_armor_soak: Dictionary = model.resolve_exchange(rules, player_damaged_armor_state, {"wound_severity": 0}, armored_player_soak_pools, 12.0, 4, 9171)
	_assert_equal(damaged_player_armor_soak["return_fire"]["damage"]["soak_roll"]["pool"], "3D", "damaged player armor loses one pip of soak")

	state = model.queue_attack_cp(model.initial_state(), 2)
	var attack_cp_exchange: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 908)
	_assert_equal(attack_cp_exchange["attack_cp_spent"], 2, "attack cp is spent on player attack")
	_assert_equal(attack_cp_exchange["state"]["player_character_points"], 3, "attack cp reduces character points")
	_assert_equal(attack_cp_exchange["state"]["pending_attack_cp"], 0, "attack cp queue clears after attack")
	_assert_equal(attack_cp_exchange["attack"]["attack_cp"]["count"], 2, "attack result records cp dice count")
	_assert_equal(_event_by_type(attack_cp_exchange["events"], "player_attack").get("attack_cp_spent", 0), 2, "attack event records cp spend")

	state = model.queue_soak_cp(model.initial_state(), 2)
	var soak_cp_pools := _pools()
	soak_cp_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	var soak_cp_exchange: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, soak_cp_pools, 12.0, 4, 909)
	_assert_equal(soak_cp_exchange["soak_cp_spent"], 2, "soak cp is spent when remote fire hits")
	_assert_equal(soak_cp_exchange["state"]["player_character_points"], 3, "soak cp reduces character points")
	_assert_equal(soak_cp_exchange["state"]["pending_soak_cp"], 0, "soak cp queue clears after hit")
	_assert_equal(soak_cp_exchange["return_fire"]["damage"]["soak_cp"]["count"], 2, "return fire damage records soak cp dice")
	_assert_equal(_event_by_type(soak_cp_exchange["events"], "remote_return_fire").get("soak_cp_spent", 0), 2, "return fire event records soak cp spend")

	state = model.activate_force_point(model.initial_state())
	var fp_attack: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 910)
	_assert_equal(fp_attack["force_point_spent"], true, "force point is spent on exchange")
	_assert_equal(fp_attack["state"]["player_force_points"], 0, "force point resource decreases")
	_assert_equal(fp_attack["state"]["force_point_active"], false, "force point clears after exchange")
	_assert_equal(rules.pool_to_string(fp_attack["shot_pool"]), "8D+2", "force point doubles attack pool")
	_assert_equal(_event_by_type(fp_attack["events"], "player_attack").get("force_point_spent", false), true, "attack event records force point")

	state = model.activate_force_point(model.declare_defense(model.initial_state(), "dodge"))
	var fp_dodge: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 12.0, 4, 911)
	_assert_equal(rules.pool_to_string(fp_dodge["shot_pool"]), "7D+2", "force point and normal dodge penalty both affect attack")
	_assert_equal(fp_dodge["return_fire"]["attack"]["defense"]["roll"]["pool"], "7D", "force point and normal dodge penalty both affect dodge")

	state = model.activate_force_point(model.initial_state())
	var fp_soak_pools := _pools()
	fp_soak_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	var fp_soak: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, fp_soak_pools, 12.0, 4, 912)
	_assert_equal(fp_soak["return_fire"]["force_point_active"], true, "return fire sees force point active")
	_assert_equal(fp_soak["return_fire"]["damage"]["soak_roll"]["pool"], "6D", "force point doubles soak pool")

	state = model.activate_force_point(model.initial_state())
	var fp_armor_soak_pools := _pools()
	fp_armor_soak_pools["target_attack_pool"] = {"dice": 20, "pips": 0}
	fp_armor_soak_pools["player_armor"] = _blast_vest()
	var fp_armor_soak: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, fp_armor_soak_pools, 12.0, 4, 918)
	_assert_equal(fp_armor_soak["return_fire"]["damage"]["soak_roll"]["pool"], "6D+1", "force point doubles Strength but not armor soak")

	# F55: a Force Point doubles the player's DAMAGE pool too (the one FP-affected roll that
	# previously did NOT double — attack/dodge/soak all did). Point-blank (dist 5, cover 0) so the
	# FP-boosted attack reliably connects and damage is rolled; a miss yields "MISS" (clear fail).
	# RANGED: 4D -> 8D.
	state = model.activate_force_point(model.initial_state())
	var fp_dmg: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, _pools(), 5.0, 0, 4242)
	_assert_equal(_damage_pool_text(fp_dmg), "8D", "force point doubles the player's RANGED damage pool (4D -> 8D)")
	# MELEE nuance (Guide_01): FP doubles STR but NOT the weapon bonus. The arena supplies
	# damage_pool_fp = 2*STR + bonus; a 5D melee pool (STR 2D + 3D bonus) becomes 7D, not 10D.
	state = model.activate_force_point(model.initial_state())
	var melee_pools := _pools()
	melee_pools["damage_pool"] = {"dice": 5, "pips": 0}
	melee_pools["damage_pool_fp"] = {"dice": 7, "pips": 0}
	var fp_melee: Dictionary = model.resolve_exchange(rules, state, {"wound_severity": 0}, melee_pools, 5.0, 0, 4243)
	_assert_equal(_damage_pool_text(fp_melee), "7D", "force point doubles melee STR but not the weapon bonus (5D -> 7D, not 10D)")
	# Regression: WITHOUT a force point the damage pool is unchanged (4D).
	var no_fp_dmg: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, _pools(), 5.0, 0, 4242)
	_assert_equal(_damage_pool_text(no_fp_dmg), "4D", "no force point: ranged damage pool stays 4D")

	var replay_a: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, _pools(), 24.0, 2, 424242)
	var replay_b: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, _pools(), 24.0, 2, 424242)
	_assert_equal(replay_a["events"], replay_b["events"], "same exchange seed replays identical event payloads")
	_assert_equal(replay_a["attack"], replay_b["attack"], "same exchange seed replays identical attack rolls")

	var replay_c: Dictionary = model.resolve_exchange(rules, model.initial_state(), {"wound_severity": 0}, _pools(), 24.0, 2, 424243)
	_assert_equal(replay_a["exchange_seed"] == replay_c["exchange_seed"], false, "different exchange seeds are tracked distinctly")

	_assert_equal(model.wound_name_for_severity(0), "OK", "severity 0 name")
	_assert_equal(model.wound_name_for_severity(3), "Incapacitated", "severity 3 name")

	rules.free()
	rules_script = null
	model_script = null

	if _failures.is_empty():
		print("ground_combat_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _pools() -> Dictionary:
	return {
		"attacker_pool": {"dice": 4, "pips": 1},
		"damage_pool": {"dice": 4, "pips": 0},
		"player_dodge_pool": {"dice": 4, "pips": 0},
		"player_soak_pool": {"dice": 3, "pips": 0},
		"target_attack_pool": {"dice": 3, "pips": 0},
		"target_soak_pool": {"dice": 2, "pips": 0},
	}

func _blast_vest() -> Dictionary:
	return {
		"protection_physical": "1D",
		"protection_energy": "0D+1",
		"dexterity_penalty": "-1D",
	}

func _torso_vest() -> Dictionary:
	var vest := _blast_vest()
	vest["coverage"] = ["torso"]
	return vest

func _has_event(events: Array, event_type: String) -> bool:
	return not _event_by_type(events, event_type).is_empty()

func _event_by_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and String(event.get("type", "")) == event_type:
			return event
	return {}

# F55: the player's outgoing damage pool string from an exchange result ("MISS" if the attack
# missed, so a stray miss is a clear assertion failure rather than a crash on an empty dict).
func _damage_pool_text(result: Dictionary) -> String:
	return String(((result.get("target_damage", {}) as Dictionary).get("damage_roll", {}) as Dictionary).get("pool", "MISS"))

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
