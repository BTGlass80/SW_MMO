extends Node

const COMBATANT_DATA_PATH = "res://data/prototype_combatants.json"
const CHARACTER_DATA_PATH = "res://data/prototype_characters.json"
const SKILL_CATALOG_PATH = "res://data/prototype_skill_catalog.json"
const GroundCombatModel = preload("res://scripts/rules/ground_combat_model.gd")
const CharacterSheetModel = preload("res://scripts/rules/character_sheet_model.gd")
const ReticleAimModel = preload("res://scripts/rules/reticle_aim_model.gd")
const LiveClockModel = preload("res://scripts/rules/live_clock_model.gd")
const RangeStatusModel = preload("res://scripts/rules/range_status_model.gd")
const RangeTargetModel = preload("res://scripts/rules/range_target_model.gd")
const RangeActionWindowModel = preload("res://scripts/rules/range_action_window_model.gd")
const RangeHitFeedbackModel = preload("res://scripts/rules/range_hit_feedback_model.gd")
const RangeStateBadgeModel = preload("res://scripts/rules/range_state_badge_model.gd")
const CombatEventEnvelopeModel = preload("res://scripts/rules/combat_event_envelope_model.gd")
const CombatEventLogModel = preload("res://scripts/rules/combat_event_log_model.gd")
const ModalOverlayModel = preload("res://scripts/rules/modal_overlay_model.gd")

var result_label: Label
var status_label: Label
var telemetry_label: Label
var combat_model := GroundCombatModel.new()
var character_model := CharacterSheetModel.new()
var combat_state := combat_model.initial_state()
var attacker_pool := {"dice": 4, "pips": 1}
var player_dodge_pool := {"dice": 4, "pips": 0}
var damage_pool := {"dice": 4, "pips": 0}
var player_soak_pool := {"dice": 3, "pips": 0}
var target_attack_pool := {"dice": 3, "pips": 0}
var target_soak_pool := {"dice": 2, "pips": 0}
var player_armor: Dictionary = {}
var target_armor: Dictionary = {}
var target_profiles: Dictionary = {}
var max_ray_distance := 90.0
var exchange_rng := RandomNumberGenerator.new()
var starting_character_points := 5
var starting_force_points := 1
var live_pressure_enabled := true
var live_pressure_tick_seconds := 6.0
var live_pressure_accumulator := 0.0
var live_pressure_tick_count := 0
var live_pressure_clock_count := 0
var combat_event_log: Array = []
var hit_feedback_seconds := 2.8

func _ready() -> void:
	exchange_rng.randomize()
	_load_range_stats()
	_update_range_state_badges()
	_refresh_telemetry()

func _process(delta: float) -> void:
	_update_hit_feedback(delta)
	_update_range_state_badges()
	if _modal_overlay_active():
		_refresh_telemetry()
		return
	if not live_pressure_enabled:
		_refresh_telemetry()
		return
	var tick_result := LiveClockModel.ticks_for_delta(delta, live_pressure_accumulator, live_pressure_tick_seconds)
	live_pressure_accumulator = float(tick_result["accumulator"])
	for i in range(int(tick_result["ticks"])):
		live_pressure_clock_count += 1
		if _resolve_incoming_fire_drill(true, live_pressure_clock_count):
			live_pressure_tick_count += 1
	_refresh_telemetry()

func _input(event: InputEvent) -> void:
	if _modal_overlay_active():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return
		var hit := _raycast_from_camera(camera)
		if hit.is_empty():
			return
		var collider: Object = hit.get("collider")
		if collider is Node and collider.has_meta("combat_target"):
			_resolve_target_shot(camera.global_position, collider)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_add_aim()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_C:
		_toggle_cover()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		_declare_defense("dodge")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_declare_defense("full_dodge")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_P:
		_queue_attack_cp()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_O:
		_queue_soak_cp()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		_activate_force_point()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_V:
		_resolve_incoming_fire_drill()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_drill()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_Z:
		_toggle_live_pressure()

func _raycast_from_camera(camera: Camera3D) -> Dictionary:
	var viewport_size := get_viewport().get_visible_rect().size
	var mouse_pos := ReticleAimModel.aim_point_for_mouse_mode(Input.mouse_mode, viewport_size, get_viewport().get_mouse_position())
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_ray_distance)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _resolve_target_shot(origin: Vector3, target: Node) -> void:
	if not target is Node3D:
		return
	var target_node := target as Node3D
	var target_position := target_node.global_position
	var distance := origin.distance_to(target_position)
	var cover_level := int(target.get_meta("cover_level", 0))
	var target_name := String(target.get_meta("target_name", target.name))
	var target_profile := String(target.get_meta("target_profile", "b1_training_silhouette"))
	var target_state := {
		"wound_severity": int(target.get_meta("wound_severity", 0)),
		"armor_quality_pips": int(target.get_meta("armor_quality_pips", 0)),
	}
	var previous_target_severity := int(target_state["wound_severity"])
	var pools := _combat_pools(target_profile)
	var exchange_seed := int(exchange_rng.randi() & 0x7fffffff)
	var declaration := RangeActionWindowModel.player_declaration_for_state(combat_state, String(target.get_meta("target_id", target.name)))
	var action_window := RangeActionWindowModel.assemble_resolution_window(combat_state, [], String(target.get_meta("target_id", target.name)))
	var exchange: Dictionary = combat_model.resolve_exchange_with_action_window(D6Rules, combat_state, target_state, pools, distance, cover_level, action_window, exchange_seed)
	if bool(exchange["already_disabled"]):
		_record_result_envelope(exchange, "ground_range_shot")
		_show_target_feedback(target_node, exchange)
		_show("%s: %s is already disabled. Press R to reset the range drill." % [_window_text(), target_name])
		return

	combat_state = exchange["state"]
	var next_target_state: Dictionary = exchange["target_state"]
	target.set_meta("wound_severity", int(next_target_state["wound_severity"]))
	target.set_meta("armor_quality_pips", int(next_target_state.get("armor_quality_pips", 0)))

	if bool(exchange.get("player_attack_skipped", false)):
		_tint_target(target_node, int(next_target_state["wound_severity"]))
		var dodge_line := "%s seed %d [%s]: Full dodge vs %s. No blaster shot this action window." % [
			"Action window %d" % int(exchange["round"]),
			int(exchange["exchange_seed"]),
			RangeActionWindowModel.declaration_summary(declaration, 1),
			target_name,
		]
		dodge_line += _format_return_fire(exchange["return_fire"])
		_record_result_envelope(exchange, "ground_range_shot")
		_show_target_feedback(target_node, exchange)
		_show(dodge_line)
		_refresh_telemetry()
		return

	var result: Dictionary = exchange["attack"]
	var outcome := "HIT" if bool(result["success"]) else "MISS"
	if bool(result["blocked"]):
		outcome = "BLOCKED"

	var margin := int(result["margin"])
	var margin_text := "+%d" % margin if margin >= 0 else "%d" % margin
	var cover: Dictionary = result["cover"]
	var cover_text := "Cover %s" % cover["name"]
	if int(cover["bonus"]) > 0 and int(cover["bonus"]) < 999:
		cover_text += " +%d" % int(cover["bonus"])

	var attack: Dictionary = result["attack"]
	var attack_total := int(attack["total"]) + int(result.get("attack_cp", {}).get("total", 0))
	var damage_text := ""
	if bool(result["success"]):
		var damage: Dictionary = exchange["target_damage"]
		var wound: Dictionary = exchange["target_wound"]
		damage_text = " | Damage %d vs Soak %d => %s" % [
			int(damage["damage_roll"]["total"]),
			int(damage["soak_roll"]["total"]),
			wound["name"],
		]
		var degraded := int(next_target_state.get("armor_degraded_pips", 0))
		if degraded > 0:
			damage_text += " | Target armor %+d->%+d" % [
				int(next_target_state.get("armor_quality_pips_before", 0)),
				int(next_target_state.get("armor_quality_pips_after", next_target_state.get("armor_quality_pips", 0))),
			]
		_tint_target(target_node, int(next_target_state["wound_severity"]))
		if not bool(exchange["target_disabled"]):
			var suppressed_until_tick := _apply_remote_suppression(target_node)
			if suppressed_until_tick > live_pressure_clock_count:
				damage_text += " | Suppressed until tick %d" % suppressed_until_tick
			var fallback_until_tick := _apply_remote_fallback(target_node, previous_target_severity, int(next_target_state["wound_severity"]))
			if fallback_until_tick > live_pressure_clock_count:
				damage_text += " | Fallback until tick %d" % fallback_until_tick
	else:
		_tint_target(target_node, int(next_target_state["wound_severity"]))
		if not bool(result["blocked"]) and not bool(exchange["target_disabled"]):
			var pinned_until_tick := _apply_remote_pinning(target_node, margin)
			if pinned_until_tick > live_pressure_clock_count:
				damage_text += " | Pinned until tick %d" % pinned_until_tick

	var line := "%s seed %d [%s]: %s: %s | %s | %s %.1fm diff %d + %s => %d vs %d (%s)%s" % [
		"Action window %d" % int(exchange["round"]),
		int(exchange["exchange_seed"]),
		RangeActionWindowModel.declaration_summary(declaration, 1),
		target_name,
		outcome,
		_aim_text(int(exchange["aim_bonus_dice"])),
		result["range_name"],
		float(result["distance"]),
		int(result["range_difficulty"]),
		cover_text,
		attack_total,
		int(result["difficulty"]),
		margin_text,
		damage_text,
	]
	if int(exchange.get("attack_cp_spent", 0)) > 0:
		line += " | Attack CP %d => +%d" % [
			int(exchange["attack_cp_spent"]),
			int(result.get("attack_cp", {}).get("total", 0)),
		]
	if bool(exchange.get("force_point_spent", false)):
		line += " | Force Point active"

	if not bool(exchange["target_disabled"]):
		line += _format_return_fire(exchange["return_fire"])
	else:
		line += " | Remote disabled."

	_record_result_envelope(exchange, "ground_range_shot")
	_show_target_feedback(target_node, exchange)
	_show(line)
	_refresh_telemetry()

func _add_aim() -> void:
	combat_state = combat_model.add_aim(combat_state)
	_show_status("%s: Aiming. +%dD on next blaster shot." % [_window_text(), int(combat_state["aim_bonus_dice"])])
	_refresh_telemetry()

func _toggle_cover() -> void:
	combat_state = combat_model.toggle_cover(combat_state)
	var cover_text := "no cover" if int(combat_state["player_cover_level"]) == 0 else "half cover"
	_show_status("%s: You take %s at the Bay 94 firing barricade." % [_window_text(), cover_text])
	_refresh_telemetry()

func _declare_defense(defense_type: String) -> void:
	combat_state = combat_model.declare_defense(combat_state, defense_type)
	var label := "normal dodge" if defense_type == "dodge" else "full dodge"
	var suffix := "against the next remote shot."
	if defense_type == "full_dodge":
		suffix = "as your whole next action window. The next remote volley will resolve it."
	_show_status("%s: Declared %s %s" % [_window_text(), label, suffix])
	_refresh_telemetry()

func _queue_attack_cp() -> void:
	combat_state = combat_model.queue_attack_cp(combat_state)
	_show_status("%s: Queued %d attack CP. CP remaining: %d." % [
		_window_text(),
		int(combat_state["pending_attack_cp"]),
		int(combat_state["player_character_points"]),
	])
	_refresh_telemetry()

func _queue_soak_cp() -> void:
	combat_state = combat_model.queue_soak_cp(combat_state)
	_show_status("%s: Queued %d soak CP if remote fire hits. CP remaining: %d." % [
		_window_text(),
		int(combat_state["pending_soak_cp"]),
		int(combat_state["player_character_points"]),
	])
	_refresh_telemetry()

func _activate_force_point() -> void:
	var before := bool(combat_state.get("force_point_active", false))
	combat_state = combat_model.activate_force_point(combat_state)
	if bool(combat_state.get("force_point_active", false)) and not before:
		_show_status("%s: Force Point queued for the next action window. FP remaining after use: %d." % [
			_window_text(),
			maxi(int(combat_state["player_force_points"]) - 1, 0),
		])
	else:
		_show_status("%s: Force Point not queued. Clear CP queues or reset if needed." % _window_text())
	_refresh_telemetry()

func _resolve_incoming_fire_drill(auto_tick: bool = false, live_tick_index: int = -1) -> bool:
	var camera := get_viewport().get_camera_3d()
	var incoming := []
	var live_states_by_instance := _live_return_fire_states_by_instance(live_tick_index) if auto_tick else {}
	for target in get_tree().get_nodes_in_group("range_targets"):
		if not target is Node3D:
			continue
		var profile := _target_profile(String(target.get_meta("target_profile", "b1_training_silhouette")))
		var source_state := {
			"wound_severity": int(target.get_meta("wound_severity", 0)),
		}
		var source_profile := _source_fire_profile(target, profile)
		if not RangeTargetModel.can_return_fire(source_profile, int(source_state["wound_severity"])):
			continue
		if auto_tick and String(live_states_by_instance.get(target.get_instance_id(), "waiting")) != "ready":
			continue
		var target_node := target as Node3D
		var distance := 12.0
		if camera != null:
			distance = camera.global_position.distance_to(target_node.global_position)
		incoming.append({
			"source_id": String(target.get_meta("target_id", target.name)),
			"source_name": String(target.get_meta("target_name", target.name)),
			"distance": distance,
			"cover_level": int(combat_state.get("player_cover_level", 0)),
			"wound_severity": int(source_state["wound_severity"]),
		})
		if not profile.is_empty():
			incoming[incoming.size() - 1]["attack_pool"] = source_profile["attack_pool"]
			incoming[incoming.size() - 1]["damage_pool"] = source_profile["damage_pool"]
			incoming[incoming.size() - 1]["armor"] = profile.get("armor", {})
			incoming[incoming.size() - 1]["scale"] = profile.get("scale", "character")

	if incoming.is_empty():
		if not auto_tick:
			_show_status("%s: No active remotes can fire." % _window_text())
		return false

	var exchange_seed := int(exchange_rng.randi() & 0x7fffffff)
	var player_declaration := RangeActionWindowModel.player_declaration_for_state(combat_state)
	var remote_declarations := RangeActionWindowModel.remote_declarations_for_incoming(incoming)
	var action_window := RangeActionWindowModel.assemble_resolution_window(combat_state, incoming)
	var result: Dictionary = combat_model.resolve_incoming_fire_window_with_action_window(
		D6Rules,
		combat_state,
		_combat_pools(),
		incoming,
		action_window,
		exchange_seed
	)
	result["player_declaration"] = player_declaration
	result["remote_declarations"] = remote_declarations
	_record_result_envelope(result, "ground_range_incoming")
	combat_state = result["state"]
	_show(_format_incoming_fire_window(result, auto_tick))
	_refresh_telemetry()
	return true

func _toggle_live_pressure() -> void:
	live_pressure_enabled = not live_pressure_enabled
	var state_text := "resumed" if live_pressure_enabled else "paused"
	_show_status("Live remote pressure %s after %d automatic volley(s)." % [
		state_text,
		live_pressure_tick_count,
	])
	_refresh_telemetry()

func _reset_drill() -> void:
	combat_state = combat_model.initial_state()
	combat_state["player_character_points"] = starting_character_points
	combat_state["player_force_points"] = starting_force_points
	live_pressure_accumulator = 0.0
	live_pressure_tick_count = 0
	live_pressure_clock_count = 0
	combat_event_log = []
	for target in get_tree().get_nodes_in_group("range_targets"):
		if target is Node3D:
			target.set_meta("damaged_locations", [])
			target.set_meta("wound_severity", 0)
			target.set_meta("armor_quality_pips", 0)
			target.remove_meta("suppressed_until_tick")
			target.remove_meta("pinned_until_tick")
			target.remove_meta("fallback_until_tick")
			_clear_persistent_damage_marks(target)
			_tint_target(target, 0)
	_update_range_state_badges()
	_show("Range drill reset. LMB fires, RMB aims, C toggles half cover, Q dodges, F full dodges, V forces a volley, Z pauses live pressure.")
	_show_status("Action window 1: no aim, no cover, trainee OK. Live remotes fire every %.0fs." % live_pressure_tick_seconds)
	_refresh_telemetry()

func get_range_state() -> Dictionary:
	return {
		"round": int(combat_state["round"]),
		"action_window_seconds": float(combat_state["action_window_seconds"]),
		"aim_bonus_dice": int(combat_state["aim_bonus_dice"]),
		"player_cover_level": int(combat_state["player_cover_level"]),
		"player_wound_severity": int(combat_state["player_wound_severity"]),
		"player_defense": String(combat_state["player_defense"]),
		"player_character_points": int(combat_state["player_character_points"]),
		"player_force_points": int(combat_state["player_force_points"]),
		"player_armor_quality_pips": int(combat_state.get("player_armor_quality_pips", 0)),
		"force_point_active": bool(combat_state["force_point_active"]),
		"pending_attack_cp": int(combat_state["pending_attack_cp"]),
		"pending_soak_cp": int(combat_state["pending_soak_cp"]),
		"live_pressure_enabled": live_pressure_enabled,
		"live_pressure_tick_seconds": live_pressure_tick_seconds,
		"live_pressure_tick_count": live_pressure_tick_count,
		"live_pressure_clock_count": live_pressure_clock_count,
		"attacker_pool": attacker_pool,
		"player_dodge_pool": player_dodge_pool,
		"damage_pool": damage_pool,
		"player_soak_pool": player_soak_pool,
		"target_attack_pool": target_attack_pool,
		"target_soak_pool": target_soak_pool,
		"player_armor": player_armor,
		"target_armor": target_armor,
		"target_profiles": target_profiles,
		"combat_event_log_summary": CombatEventLogModel.summary(combat_event_log),
	}

func target_live_state_context(instance_id: int) -> Dictionary:
	var current_states := _live_return_fire_states_by_instance(live_pressure_clock_count)
	var next_states := _live_return_fire_states_by_instance(live_pressure_clock_count + 1)
	return {
		"live_enabled": live_pressure_enabled,
		"tick_index": live_pressure_clock_count,
		"current_state": String(current_states.get(instance_id, "inert")),
		"next_state": String(next_states.get(instance_id, "inert")),
	}

func _record_result_envelope(result: Dictionary, exchange_kind: String) -> void:
	result["encounter_state"] = _range_encounter_state()
	result["event_envelope"] = CombatEventEnvelopeModel.envelope_for_result(result, exchange_kind, "local")
	combat_event_log = CombatEventLogModel.append_envelope(combat_event_log, result["event_envelope"])

func _range_encounter_state() -> Dictionary:
	return {
		"kind": "range_pressure",
		"tick_index": live_pressure_clock_count,
		"live_enabled": live_pressure_enabled,
		"current": _live_return_fire_summary(live_pressure_clock_count),
		"next": _live_return_fire_summary(live_pressure_clock_count + 1),
	}

func _apply_remote_suppression(target: Node3D) -> int:
	var suppression_ticks := maxi(int(target.get_meta("suppression_ticks", 0)), 0)
	if suppression_ticks <= 0:
		return live_pressure_clock_count
	var resume_tick := live_pressure_clock_count + suppression_ticks + 1
	target.set_meta("suppressed_until_tick", resume_tick)
	return resume_tick

func _apply_remote_pinning(target: Node3D, attack_margin: int) -> int:
	var pinning_profile := {
		"pinning_ticks": int(target.get_meta("pinning_ticks", 0)),
		"pinning_miss_margin": int(target.get_meta("pinning_miss_margin", 0)),
	}
	var resume_tick := RangeTargetModel.pinning_resume_tick(pinning_profile, live_pressure_clock_count, attack_margin)
	if resume_tick <= live_pressure_clock_count:
		return live_pressure_clock_count
	target.set_meta("pinned_until_tick", max(resume_tick, int(target.get_meta("pinned_until_tick", -1))))
	return int(target.get_meta("pinned_until_tick", resume_tick))

func _apply_remote_fallback(target: Node3D, previous_severity: int, next_severity: int) -> int:
	var fallback_ticks := maxi(int(target.get_meta("fallback_ticks", 0)), 0)
	if fallback_ticks <= 0:
		return live_pressure_clock_count
	var threshold := maxi(int(target.get_meta("fallback_on_wound_severity", 2)), 1)
	if previous_severity >= threshold or next_severity < threshold:
		return live_pressure_clock_count
	var resume_tick := live_pressure_clock_count + fallback_ticks + 1
	target.set_meta("fallback_until_tick", max(resume_tick, int(target.get_meta("fallback_until_tick", -1))))
	return int(target.get_meta("fallback_until_tick", resume_tick))

func _format_return_fire(return_fire: Dictionary) -> String:
	var result: Dictionary = return_fire["attack"]
	var cover: Dictionary = result["cover"]
	var cover_text := "Cover %s" % cover["name"]
	if int(cover["bonus"]) > 0 and int(cover["bonus"]) < 999:
		cover_text += " +%d" % int(cover["bonus"])
	var defense: Dictionary = result["defense"]
	var defense_text := ""
	if String(defense["type"]) != "none":
		defense_text = ", %s" % String(defense["text"])

	var attack: Dictionary = result["attack"]
	if not bool(return_fire["hit"]):
		return " | Remote fire misses: %d vs %d (%s%s)." % [
			int(attack["total"]),
			int(result["difficulty"]),
			cover_text,
			defense_text,
		]

	var damage: Dictionary = return_fire["damage"]
	var wound: Dictionary = return_fire["wound"]
	var soak_cp_text := ""
	if int(return_fire.get("soak_cp_spent", 0)) > 0:
		soak_cp_text = " + CP %d" % int(damage.get("soak_cp", {}).get("total", 0))
	var armor_text := ""
	if int(return_fire.get("player_armor_degraded_pips", 0)) > 0:
		armor_text = " Armor %+d->%+d." % [
			int(return_fire.get("player_armor_quality_pips_before", 0)),
			int(return_fire.get("player_armor_quality_pips_after", 0)),
		]
	return " | Remote fire hits: %d vs %d (%s%s). Stun damage %d vs Soak %d%s => %s.%s You: %s." % [
		int(attack["total"]),
		int(result["difficulty"]),
		cover_text,
		defense_text,
		int(damage["damage_roll"]["total"]),
		int(damage["soak_roll"]["total"]),
		soak_cp_text,
		wound["name"],
		armor_text,
		combat_model.wound_name_for_severity(int(combat_state["player_wound_severity"])),
	]

func _format_incoming_fire_window(result: Dictionary, auto_tick: bool = false) -> String:
	var defense: Dictionary = result.get("defense", {})
	var defense_text := "no declared defense"
	if not defense.is_empty():
		defense_text = "%s %d" % [
			String(defense.get("type", "defense")),
			int(defense.get("value", 0)),
		]
	var parts := PackedStringArray()
	for incoming in result["incoming"]:
		var attack: Dictionary = incoming["attack"]
		var attack_roll: Dictionary = attack["attack"]
		var label := "%s %s %d/%d" % [
			String(incoming.get("source_name", "Remote")),
			"hits" if bool(incoming["hit"]) else "misses",
			int(attack_roll["total"]),
			int(attack["difficulty"]),
		]
		if bool(incoming["hit"]):
			var damage: Dictionary = incoming["damage"]
			label += " %s" % String(damage["wound"]["name"])
			if int(incoming.get("soak_cp_spent", 0)) > 0:
				label += " CP%d" % int(incoming["soak_cp_spent"])
		parts.append(label)
	var prefix := "Live remote volley" if auto_tick else "Incoming-fire window"
	var declaration: Dictionary = result.get("player_declaration", {})
	return "%s %d seed %d [%s]: vs %d remotes, %s. %s. You: %s." % [
		prefix,
		int(result["round"]),
		int(result["exchange_seed"]),
		RangeActionWindowModel.declaration_summary(declaration, int(result["incoming"].size())),
		result["incoming"].size(),
		defense_text,
		"; ".join(parts),
		combat_model.wound_name_for_severity(int(combat_state["player_wound_severity"])),
	]

func _show(text: String) -> void:
	if result_label != null:
		result_label.text = text

func _show_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	else:
		_show(text)

func _show_target_feedback(target: Node3D, exchange: Dictionary) -> void:
	var feedback := RangeHitFeedbackModel.target_feedback(exchange)
	_record_persistent_damage_visual(target, exchange)
	_refresh_persistent_damage_visuals(target)
	if not bool(feedback.get("visible", false)):
		return
	var existing := target.get_node_or_null("RangeHitFeedback")
	if existing != null:
		existing.queue_free()

	var container := Node3D.new()
	container.name = "RangeHitFeedback"
	container.position = RangeHitFeedbackModel.location_offset(String(feedback.get("location", "torso")))
	container.set_meta("ttl", hit_feedback_seconds)
	container.add_to_group("range_hit_feedback")
	target.add_child(container)

	var color := RangeHitFeedbackModel.tone_color(String(feedback.get("tone", "")))
	var marker := MeshInstance3D.new()
	marker.name = "HitLocationMarker"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	marker.mesh = sphere
	marker.position = Vector3.ZERO
	marker.material_override = _feedback_material(color)
	container.add_child(marker)

	var label := Label3D.new()
	label.name = "HitFeedbackLabel"
	label.text = String(feedback.get("text", ""))
	label.position = Vector3(0.0, 0.38, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.02, 0.018, 0.014, 0.92)
	container.add_child(label)

func _update_hit_feedback(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for feedback in tree.get_nodes_in_group("range_hit_feedback"):
		if not feedback is Node3D:
			continue
		var node := feedback as Node3D
		var ttl := float(node.get_meta("ttl", 0.0)) - delta
		node.set_meta("ttl", ttl)
		var alpha := clampf(ttl / hit_feedback_seconds, 0.0, 1.0)
		for child in node.get_children():
			if child is Label3D:
				var label := child as Label3D
				var next_color: Color = label.modulate
				next_color.a = alpha
				label.modulate = next_color
			elif child is MeshInstance3D:
				var mesh := child as MeshInstance3D
				if mesh.material_override is StandardMaterial3D:
					var material: StandardMaterial3D = (mesh.material_override as StandardMaterial3D).duplicate()
					var material_color: Color = material.albedo_color
					material_color.a = alpha
					material.albedo_color = material_color
					mesh.material_override = material
		if ttl <= 0.0:
			node.queue_free()

func _feedback_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.55
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _record_persistent_damage_visual(target: Node3D, exchange: Dictionary) -> void:
	var attack: Dictionary = exchange.get("attack", {})
	if not bool(attack.get("success", false)) or bool(attack.get("blocked", false)):
		return
	var target_state: Dictionary = exchange.get("target_state", {})
	var location := String(target_state.get("hit_location", ""))
	if location == "":
		return
	var damaged_locations: Array = target.get_meta("damaged_locations", [])
	var next_locations := []
	var updated := false
	for item in damaged_locations:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		if String(entry.get("location", "")) == location:
			entry = _damage_visual_entry(location, target_state)
			updated = true
		next_locations.append(entry)
	if not updated:
		next_locations.append(_damage_visual_entry(location, target_state))
	target.set_meta("damaged_locations", next_locations)

func _refresh_persistent_damage_visuals(target: Node3D) -> void:
	var damaged_locations: Array = target.get_meta("damaged_locations", [])
	for item in damaged_locations:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var color: Color = entry.get("color", Color(0.72, 0.25, 0.12))
		for part_name in RangeHitFeedbackModel.damage_part_names(String(entry.get("location", ""))):
			var part := target.get_node_or_null(String(part_name))
			if part is MeshInstance3D:
				(part as MeshInstance3D).material_override = _persistent_damage_material(color)
				break
	_refresh_persistent_damage_marks(target, damaged_locations)

func _refresh_persistent_damage_marks(target: Node3D, damaged_locations: Array) -> void:
	var container := target.get_node_or_null("RangePersistentDamageMarks")
	if container == null:
		container = Node3D.new()
		container.name = "RangePersistentDamageMarks"
		target.add_child(container)
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for item in damaged_locations:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var marker: Dictionary = entry.get("marker", {})
		if marker.is_empty() or not bool(marker.get("visible", false)):
			continue
		var scorch := MeshInstance3D.new()
		scorch.name = "Scorch_%s" % String(marker.get("location", "torso"))
		var sphere := SphereMesh.new()
		var radius := float(marker.get("radius", 0.09))
		sphere.radius = radius
		sphere.height = radius * 0.28
		scorch.mesh = sphere
		scorch.position = marker.get("offset", Vector3.ZERO)
		scorch.scale = Vector3(1.0, 0.22, 0.22)
		scorch.material_override = _persistent_damage_mark_material(
			marker.get("color", Color(0.72, 0.25, 0.12)),
			float(marker.get("emission", 0.18))
		)
		container.add_child(scorch)

func _clear_persistent_damage_marks(target: Node3D) -> void:
	var container := target.get_node_or_null("RangePersistentDamageMarks")
	if container != null:
		container.queue_free()

func _damage_visual_entry(location: String, target_state: Dictionary) -> Dictionary:
	var armor_applied := bool(target_state.get("armor_applied", false))
	var wound_severity := int(target_state.get("wound_severity", 0))
	return {
		"location": location,
		"armor_applied": armor_applied,
		"wound_severity": wound_severity,
		"color": RangeHitFeedbackModel.persistent_damage_color(
			armor_applied,
			wound_severity
		),
		"marker": RangeHitFeedbackModel.persistent_damage_marker(location, armor_applied, wound_severity),
	}

func _persistent_damage_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	material.emission_enabled = true
	material.emission = color.darkened(0.35)
	material.emission_energy_multiplier = 0.18
	return material

func _persistent_damage_mark_material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.12)
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	return material

func _refresh_telemetry() -> void:
	if telemetry_label != null:
		var current_summary := _live_return_fire_summary(live_pressure_clock_count)
		var next_summary := _live_return_fire_summary(live_pressure_clock_count + 1)
		telemetry_label.text = RangeStatusModel.telemetry_line(
			combat_state,
			live_pressure_enabled,
			live_pressure_accumulator,
			live_pressure_tick_seconds,
			live_pressure_tick_count,
			int(current_summary.get("armed", 0)),
			int(next_summary.get("ready", 0)),
			CombatEventLogModel.summary(combat_event_log),
			int(current_summary.get("suppressed", 0)),
			int(current_summary.get("pinned", 0)),
			int(current_summary.get("covered", 0)),
			int(current_summary.get("fallback", 0)),
			int(current_summary.get("coordinating", 0)),
			int(current_summary.get("flanking", 0)),
			int(current_summary.get("reloading", 0)),
			int(current_summary.get("hesitating", 0)),
			int(current_summary.get("covering", 0))
		)

func _update_range_state_badges() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var states_by_instance := _live_return_fire_states_by_instance(live_pressure_clock_count)
	for target in tree.get_nodes_in_group("range_targets"):
		if not target is Node3D:
			continue
		var target_node := target as Node3D
		var state := String(states_by_instance.get(target_node.get_instance_id(), "inert"))
		_show_range_state_badge(target_node, state)

func _show_range_state_badge(target: Node3D, state: String) -> void:
	var badge := RangeStateBadgeModel.badge_for_state(state)
	var label := target.get_node_or_null("RangeStateBadge")
	if label == null:
		label = Label3D.new()
		label.name = "RangeStateBadge"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 22
		label.outline_size = 7
		label.outline_modulate = Color(0.02, 0.018, 0.014, 0.94)
		target.add_child(label)
	if not label is Label3D:
		return
	var state_label := label as Label3D
	state_label.visible = bool(badge.get("visible", true))
	state_label.text = String(badge.get("text", "UNKNOWN"))
	state_label.modulate = badge.get("color", Color(0.82, 0.82, 0.82))
	var profile_key := String(target.get_meta("target_profile", ""))
	state_label.position = Vector3(0.0, RangeStateBadgeModel.badge_height_for_profile(profile_key), 0.0)

func _live_return_fire_summary(tick_index: int) -> Dictionary:
	return RangeTargetModel.live_tick_summary(_range_target_fire_entries(), tick_index)

func _live_return_fire_states_by_instance(tick_index: int) -> Dictionary:
	var entries := _range_target_fire_entries()
	var states := RangeTargetModel.live_tick_states(entries, tick_index)
	var states_by_instance := {}
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		states_by_instance[int(entry.get("instance_id", -1))] = String(states[index])
	return states_by_instance

func _range_target_fire_entries() -> Array:
	var entries := []
	var tree := get_tree()
	if tree == null:
		return entries
	for target in tree.get_nodes_in_group("range_targets"):
		if not target is Node:
			continue
		var profile := _target_profile(String(target.get_meta("target_profile", "b1_training_silhouette")))
		var source_profile := _source_fire_profile(target, profile)
		entries.append({
			"instance_id": target.get_instance_id(),
			"profile": source_profile,
			"wound_severity": int(target.get_meta("wound_severity", 0)),
		})
	return entries

func _tint_target(target: Node3D, severity: int) -> void:
	var color := Color(0.63, 0.53, 0.38)
	if severity == 1:
		color = Color(0.86, 0.72, 0.22)
	elif severity == 2:
		color = Color(0.88, 0.45, 0.18)
	elif severity == 3:
		color = Color(0.75, 0.18, 0.13)
	elif severity >= 4:
		color = Color(0.36, 0.04, 0.04)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	for child in target.get_children():
		if child is MeshInstance3D:
			child.material_override = material

func _load_range_stats() -> void:
	if not FileAccess.file_exists(COMBATANT_DATA_PATH):
		return

	var file := FileAccess.open(COMBATANT_DATA_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed
	var trainee: Dictionary = data.get("range_trainee", {})
	var weapons: Dictionary = data.get("weapons", {})
	var armors: Dictionary = data.get("armors", {})
	var targets: Dictionary = data.get("targets", {})
	var weapon_key := String(trainee.get("weapon", "training_blaster"))
	var weapon: Dictionary = weapons.get(weapon_key, {})
	var target: Dictionary = targets.get("b1_training_silhouette", {})
	var player_armor_key := String(trainee.get("armor", ""))
	var target_armor_key := String(target.get("armor", ""))

	var sheet_loaded := _load_trainee_character_sheet(data)
	if not sheet_loaded:
		attacker_pool = D6Rules.parse_pool(String(trainee.get("blaster", "4D+1")))
		player_dodge_pool = D6Rules.parse_pool(String(trainee.get("dodge", "4D")))
		player_soak_pool = D6Rules.parse_pool(String(trainee.get("soak", "3D")))
		player_armor = armors.get(player_armor_key, {})
		starting_character_points = int(trainee.get("character_points", 5))
		starting_force_points = int(trainee.get("force_points", 1))
	combat_state["player_character_points"] = starting_character_points
	combat_state["player_force_points"] = starting_force_points
	if not sheet_loaded:
		damage_pool = D6Rules.parse_pool(String(weapon.get("damage", "4D")))
	target_attack_pool = D6Rules.parse_pool(String(target.get("blaster", "3D")))
	target_soak_pool = D6Rules.parse_pool(String(target.get("soak", "2D")))
	target_armor = armors.get(target_armor_key, {})
	target_profiles.clear()
	for key in targets.keys():
		var profile_target: Dictionary = targets[key]
		var profile_armor_key := String(profile_target.get("armor", ""))
		var profile_weapon_key := String(profile_target.get("weapon", ""))
		var profile_weapon: Dictionary = weapons.get(profile_weapon_key, {})
		target_profiles[String(key)] = {
			"name": String(profile_target.get("name", key)),
			"attack_pool": D6Rules.parse_pool(String(profile_target.get("blaster", "0D"))),
			"damage_pool": D6Rules.parse_pool(String(profile_weapon.get("damage", "0D"))),
			"soak_pool": D6Rules.parse_pool(String(profile_target.get("soak", "0D"))),
			"armor": armors.get(profile_armor_key, {}),
			"scale": String(profile_target.get("scale", "character")),
			"weapon_name": String(profile_weapon.get("name", "Weapon")),
			"source_note": String(profile_target.get("source_note", "")),
		}

func _load_trainee_character_sheet(gear_data: Dictionary) -> bool:
	var character_data := _load_json_file(CHARACTER_DATA_PATH)
	var skill_catalog := _load_json_file(SKILL_CATALOG_PATH)
	if character_data.is_empty() or skill_catalog.is_empty():
		return false
	var characters: Dictionary = character_data.get("characters", {})
	var sheet: Dictionary = characters.get("range_trainee", {})
	if sheet.is_empty():
		return false
	var combat_pools: Dictionary = character_model.combat_pools_from_sheet(D6Rules, sheet, skill_catalog, gear_data)
	attacker_pool = combat_pools.get("attacker_pool", attacker_pool)
	player_dodge_pool = combat_pools.get("player_dodge_pool", player_dodge_pool)
	player_soak_pool = combat_pools.get("player_soak_pool", player_soak_pool)
	player_armor = combat_pools.get("player_armor", player_armor)
	damage_pool = combat_pools.get("damage_pool", damage_pool)
	starting_character_points = int(combat_pools.get("character_points", starting_character_points))
	starting_force_points = int(combat_pools.get("force_points", starting_force_points))
	combat_state["player_wound_severity"] = int(combat_pools.get("wound_severity", 0))
	return true

func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _combat_pools(target_profile: String = "b1_training_silhouette") -> Dictionary:
	var profile := _target_profile(target_profile)
	return {
		"attacker_pool": attacker_pool,
		"player_dodge_pool": player_dodge_pool,
		"damage_pool": damage_pool,
		"target_damage_pool": profile.get("damage_pool", damage_pool),
		"player_soak_pool": player_soak_pool,
		"target_attack_pool": profile.get("attack_pool", target_attack_pool),
		"target_soak_pool": profile.get("soak_pool", target_soak_pool),
		"player_armor": player_armor,
		"target_armor": profile.get("armor", target_armor),
		"attacker_scale": "character",
		"target_scale": String(profile.get("scale", "character")),
	}

func _target_profile(target_profile: String) -> Dictionary:
	return target_profiles.get(target_profile, {})

func _return_fire_profile(profile: Dictionary) -> Dictionary:
	if profile.is_empty():
		return {
			"attack_pool": target_attack_pool,
			"damage_pool": damage_pool,
		}
	return {
		"attack_pool": profile.get("attack_pool", target_attack_pool),
		"damage_pool": profile.get("damage_pool", damage_pool),
	}

func _source_fire_profile(target: Node, profile: Dictionary) -> Dictionary:
	var source_profile := _return_fire_profile(profile)
	source_profile["fire_cadence_ticks"] = int(target.get_meta("fire_cadence_ticks", profile.get("fire_cadence_ticks", 1)))
	source_profile["fire_phase_ticks"] = int(target.get_meta("fire_phase_ticks", profile.get("fire_phase_ticks", 0)))
	source_profile["suppressed_until_tick"] = int(target.get_meta("suppressed_until_tick", -1))
	source_profile["pinned_until_tick"] = int(target.get_meta("pinned_until_tick", -1))
	source_profile["peek_exposed_ticks"] = int(target.get_meta("peek_exposed_ticks", profile.get("peek_exposed_ticks", 0)))
	source_profile["peek_covered_ticks"] = int(target.get_meta("peek_covered_ticks", profile.get("peek_covered_ticks", 0)))
	source_profile["peek_phase_ticks"] = int(target.get_meta("peek_phase_ticks", profile.get("peek_phase_ticks", source_profile["fire_phase_ticks"])))
	source_profile["fallback_until_tick"] = int(target.get_meta("fallback_until_tick", -1))
	source_profile["coordination_group"] = String(target.get_meta("coordination_group", profile.get("coordination_group", "")))
	source_profile["coordination_priority"] = int(target.get_meta("coordination_priority", profile.get("coordination_priority", 0)))
	source_profile["flank_move_ticks"] = int(target.get_meta("flank_move_ticks", profile.get("flank_move_ticks", 0)))
	source_profile["flank_cadence_ticks"] = int(target.get_meta("flank_cadence_ticks", profile.get("flank_cadence_ticks", 0)))
	source_profile["flank_phase_ticks"] = int(target.get_meta("flank_phase_ticks", profile.get("flank_phase_ticks", source_profile["fire_phase_ticks"])))
	source_profile["reload_ticks"] = int(target.get_meta("reload_ticks", profile.get("reload_ticks", 0)))
	source_profile["reload_cadence_ticks"] = int(target.get_meta("reload_cadence_ticks", profile.get("reload_cadence_ticks", 0)))
	source_profile["reload_phase_ticks"] = int(target.get_meta("reload_phase_ticks", profile.get("reload_phase_ticks", source_profile["fire_phase_ticks"])))
	source_profile["morale_hold_ticks"] = int(target.get_meta("morale_hold_ticks", profile.get("morale_hold_ticks", 0)))
	source_profile["morale_cadence_ticks"] = int(target.get_meta("morale_cadence_ticks", profile.get("morale_cadence_ticks", 0)))
	source_profile["morale_phase_ticks"] = int(target.get_meta("morale_phase_ticks", profile.get("morale_phase_ticks", source_profile["fire_phase_ticks"])))
	source_profile["morale_min_wound_severity"] = int(target.get_meta("morale_min_wound_severity", profile.get("morale_min_wound_severity", 1)))
	source_profile["covering_fire_ticks"] = int(target.get_meta("covering_fire_ticks", profile.get("covering_fire_ticks", 0)))
	source_profile["covering_fire_cadence_ticks"] = int(target.get_meta("covering_fire_cadence_ticks", profile.get("covering_fire_cadence_ticks", 0)))
	source_profile["covering_fire_phase_ticks"] = int(target.get_meta("covering_fire_phase_ticks", profile.get("covering_fire_phase_ticks", source_profile["fire_phase_ticks"])))
	return source_profile

func _aim_text(aim_bonus: int) -> String:
	return "Aim +%dD" % aim_bonus if aim_bonus > 0 else "No aim"

func _window_text() -> String:
	return "Action window %d" % int(combat_state["round"])

func _modal_overlay_active() -> bool:
	return ModalOverlayModel.is_modal_overlay_active(get_tree())
