extends Node3D
## Solo (single-player) world entry. Builds the shared Mos Eisley settlement via
## WorldBuilder, then layers the single-player blaster range, controllers, HUD, and
## overlays on top. The networked world (scripts/net/net_world.gd) reuses the same
## WorldBuilder so geometry is authored once.

const PlayerController = preload("res://scripts/player/player_controller.gd")
const ModalOverlayModel = preload("res://scripts/rules/modal_overlay_model.gd")
const BlasterRange = preload("res://scripts/world/blaster_range.gd")
const InspectController = preload("res://scripts/world/inspect_controller.gd")
const SpaceMapOverlay = preload("res://scripts/world/space_map_overlay.gd")
const CharacterSheetOverlay = preload("res://scripts/world/character_sheet_overlay.gd")
const MovingTargetController = preload("res://scripts/world/moving_target_controller.gd")
const WorldBuilder = preload("res://scripts/world/world_builder.gd")

var _builder: WorldBuilder
var _hud_result_label: Label
var _hud_status_label: Label
var _hud_telemetry_label: Label
var _ground_layer_visible_before_modal := {}

func _ready() -> void:
	_builder = WorldBuilder.new()
	_builder.build_lighting(self)
	_builder.build_ground(self)
	_builder.build_settlement(self)
	_build_blaster_range()
	_build_player()
	_build_hud()
	_build_range_controller()
	_build_moving_target_controller()
	_build_inspection_controller()
	_build_space_map_overlay()
	_build_character_sheet_overlay()

func _process(_delta: float) -> void:
	_sync_ground_gameplay_layers()

func _build_player() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerController)
	player.position = Vector3(-20, 1.2, -6)

	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.55
	player.add_child(head)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 74
	camera.current = true
	head.add_child(camera)

	add_child(player)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.add_to_group("ground_gameplay_layer")
	add_child(layer)

	var label := Label.new()
	label.position = Vector2(18, 16)
	label.text = "Mos Eisley Spaceport Row, 20 BBY | Move: WASD / Mouse / Space | Ground: LMB fire / RMB aim / E inspect / H sheet / C cover / Q dodge / F full dodge / V force volley / Z pause remotes / P-O CP / G FP / R reset | Space: M map / N sensors / T pause traffic / B gunnery / U assist"
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = Color(0.09, 0.08, 0.06)
	layer.add_child(label)

	var roll := D6Rules.check(D6Rules.parse_pool("4D+2"), "moderate")
	var margin := int(roll["margin"])
	var margin_text := "+%d" % margin if margin >= 0 else "%d" % margin
	var dice_label := Label.new()
	dice_label.position = Vector2(18, 44)
	dice_label.text = "Sample D6 check: %s vs %s => %d (%s)" % [roll["pool"], roll["difficulty"], roll["total"], margin_text]
	dice_label.add_theme_font_size_override("font_size", 15)
	dice_label.modulate = Color(0.09, 0.08, 0.06)
	layer.add_child(dice_label)

	_hud_result_label = Label.new()
	_hud_result_label.position = Vector2(18, 98)
	_hud_result_label.size = Vector2(980, 80)
	_hud_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud_result_label.text = "Combat log: LMB fires at a B1 remote."
	_hud_result_label.add_theme_font_size_override("font_size", 15)
	_hud_result_label.modulate = Color(0.09, 0.08, 0.06)
	layer.add_child(_hud_result_label)

	_hud_telemetry_label = Label.new()
	_hud_telemetry_label.position = Vector2(18, 180)
	_hud_telemetry_label.size = Vector2(980, 24)
	_hud_telemetry_label.text = "Range state: loading."
	_hud_telemetry_label.add_theme_font_size_override("font_size", 14)
	_hud_telemetry_label.modulate = Color(0.09, 0.08, 0.06)
	layer.add_child(_hud_telemetry_label)

	_hud_status_label = Label.new()
	_hud_status_label.position = Vector2(18, 72)
	_hud_status_label.size = Vector2(980, 24)
	_hud_status_label.text = "Status: Live remotes fire every few seconds. RMB aims up to +3D. C cover. Q/F dodge. P/O queue CP. G queues FP. R resets."
	_hud_status_label.add_theme_font_size_override("font_size", 15)
	_hud_status_label.modulate = Color(0.09, 0.08, 0.06)
	layer.add_child(_hud_status_label)
	_add_crosshair(layer)
	_set_mouse_filter_recursive(layer)

func _build_range_controller() -> void:
	var controller := Node.new()
	controller.name = "BlasterRangeController"
	controller.set_script(BlasterRange)
	controller.result_label = _hud_result_label
	controller.status_label = _hud_status_label
	controller.telemetry_label = _hud_telemetry_label
	add_child(controller)

func _build_inspection_controller() -> void:
	var controller := Node.new()
	controller.name = "InspectController"
	controller.set_script(InspectController)
	controller.result_label = _hud_status_label
	add_child(controller)

func _build_space_map_overlay() -> void:
	var overlay := SpaceMapOverlay.new()
	overlay.name = "SpaceMapOverlay"
	add_child(overlay)

func _build_character_sheet_overlay() -> void:
	var overlay := CharacterSheetOverlay.new()
	overlay.name = "CharacterSheetOverlay"
	add_child(overlay)

func _add_crosshair(layer: CanvasLayer) -> void:
	var horizontal := ColorRect.new()
	horizontal.position = Vector2(635, 359)
	horizontal.size = Vector2(10, 2)
	horizontal.color = Color(0.09, 0.08, 0.06, 0.75)
	layer.add_child(horizontal)

	var vertical := ColorRect.new()
	vertical.position = Vector2(639, 355)
	vertical.size = Vector2(2, 10)
	vertical.color = Color(0.09, 0.08, 0.06, 0.75)
	layer.add_child(vertical)

func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_recursive(child)

func _sync_ground_gameplay_layers() -> void:
	var modal_active := ModalOverlayModel.is_modal_overlay_active(get_tree())
	var should_show := ModalOverlayModel.should_show_ground_gameplay_layer(modal_active)
	for node in get_tree().get_nodes_in_group("ground_gameplay_layer"):
		if not node is CanvasLayer and not node is CanvasItem:
			continue
		var node_id := node.get_instance_id()
		if not should_show:
			if not _ground_layer_visible_before_modal.has(node_id):
				_ground_layer_visible_before_modal[node_id] = bool(node.visible)
			node.visible = false
		elif _ground_layer_visible_before_modal.has(node_id):
			node.visible = bool(_ground_layer_visible_before_modal[node_id])
			_ground_layer_visible_before_modal.erase(node_id)

func _build_blaster_range() -> void:
	_builder.add_box_to_world(self, Vector3(-20, 0.11, -18), Vector3(8, 0.08, 1.0), Color(0.34, 0.29, 0.22))
	_builder.add_box_to_world(self, Vector3(-20, 0.2, -11), Vector3(2.8, 0.18, 0.25), Color(0.83, 0.64, 0.18))
	_builder.add_box_to_world(self, Vector3(-20, 0.2, -23), Vector3(2.8, 0.18, 0.25), Color(0.83, 0.64, 0.18))
	_builder.add_box_to_world(self, Vector3(-20, 0.2, -39), Vector3(2.8, 0.18, 0.25), Color(0.83, 0.64, 0.18))

	_add_range_target(Vector3(-20, 1.1, -12), "B1 training silhouette - short", 0, "b1_training_silhouette", {}, {"fire_cadence_ticks": 1, "fire_phase_ticks": 0, "suppression_ticks": 1})
	_add_range_target(Vector3(-20, 1.1, -18), "B1 lateral remote - moving", 1, "b1_training_silhouette", {"axis": "x", "distance": 4.0, "speed": 1.6, "pattern": "sine"}, {"fire_cadence_ticks": 2, "fire_phase_ticks": 1, "suppression_ticks": 2, "pinning_ticks": 1, "pinning_miss_margin": 2, "fallback_ticks": 1, "fallback_on_wound_severity": 2, "reload_ticks": 1, "reload_cadence_ticks": 4, "reload_phase_ticks": 3, "morale_hold_ticks": 1, "morale_cadence_ticks": 3, "morale_phase_ticks": 2, "morale_min_wound_severity": 1, "covering_fire_ticks": 1, "covering_fire_cadence_ticks": 5, "covering_fire_phase_ticks": 4})
	_add_range_target(Vector3(-20, 1.1, -24), "B1 behind cargo - medium", 2, "b1_training_silhouette", {}, {"fire_cadence_ticks": 2, "fire_phase_ticks": 0, "suppression_ticks": 1, "pinning_ticks": 1, "pinning_miss_margin": 3, "peek_exposed_ticks": 1, "peek_covered_ticks": 1, "peek_phase_ticks": 0, "fallback_ticks": 2, "fallback_on_wound_severity": 2, "coordination_group": "bay_cover_pair", "coordination_priority": 1, "morale_hold_ticks": 1, "morale_cadence_ticks": 4, "morale_phase_ticks": 3, "morale_min_wound_severity": 1, "covering_fire_ticks": 1, "covering_fire_cadence_ticks": 4, "covering_fire_phase_ticks": 1})
	_add_range_target(Vector3(-20, 1.1, -40), "B1 behind bay wall - long", 3, "b1_training_silhouette", {}, {"fire_cadence_ticks": 3, "fire_phase_ticks": 2, "suppression_ticks": 1, "pinning_ticks": 1, "pinning_miss_margin": 3, "peek_exposed_ticks": 1, "peek_covered_ticks": 2, "peek_phase_ticks": 2, "fallback_ticks": 2, "fallback_on_wound_severity": 2, "coordination_group": "bay_cover_pair", "coordination_priority": 0, "flank_move_ticks": 1, "flank_cadence_ticks": 5, "flank_phase_ticks": 1, "reload_ticks": 1, "reload_cadence_ticks": 6, "reload_phase_ticks": 5, "covering_fire_ticks": 1, "covering_fire_cadence_ticks": 5, "covering_fire_phase_ticks": 4})
	_add_walker_armor_target(Vector3(-14, 1.55, -34), "Walker-scale moving armor plate", 0, {"axis": "x", "distance": 2.5, "speed": 0.75, "pattern": "patrol"})
	_builder.add_box_to_world(self, Vector3(-20.7, 0.65, -24), Vector3(1.2, 1.3, 1.2), Color(0.36, 0.25, 0.16))
	_builder.add_box_to_world(self, Vector3(-20.8, 0.95, -40), Vector3(1.3, 1.9, 0.8), Color(0.48, 0.43, 0.38))
	_builder.add_box_to_world(self, Vector3(-20, 0.7, -6), Vector3(4.5, 1.4, 0.6), Color(0.32, 0.29, 0.24))

func _build_moving_target_controller() -> void:
	var controller := Node.new()
	controller.name = "MovingTargetController"
	controller.set_script(MovingTargetController)
	add_child(controller)

func _add_range_target(pos: Vector3, target_name: String, cover_level: int, target_profile: String = "b1_training_silhouette", motion: Dictionary = {}, behavior: Dictionary = {}) -> void:
	var body := StaticBody3D.new()
	body.name = target_name
	body.position = pos
	body.set_meta("combat_target", true)
	body.set_meta("target_name", target_name)
	body.set_meta("target_profile", target_profile)
	body.set_meta("cover_level", cover_level)
	body.set_meta("wound_severity", 0)
	body.add_to_group("range_targets")
	_apply_motion_metadata(body, pos, motion)
	_apply_behavior_metadata(body, behavior)
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 2.2, 0.35)
	collision.shape = shape
	body.add_child(collision)

	_builder.add_box(body, Vector3(0, -0.15, 0), Vector3(0.72, 1.45, 0.22), Color(0.63, 0.53, 0.38), "torso")
	_builder.add_box(body, Vector3(0, 0.82, 0), Vector3(0.46, 0.42, 0.22), Color(0.72, 0.63, 0.46), "head")
	_builder.add_box(body, Vector3(-0.52, -0.05, 0), Vector3(0.2, 1.1, 0.18), Color(0.57, 0.48, 0.35), "left_arm")
	_builder.add_box(body, Vector3(0.52, -0.05, 0), Vector3(0.2, 1.1, 0.18), Color(0.57, 0.48, 0.35), "right_arm")
	_builder.add_box(body, Vector3(0, -1.05, 0), Vector3(0.95, 0.2, 0.18), Color(0.18, 0.18, 0.16), "legs")

func _add_walker_armor_target(pos: Vector3, target_name: String, cover_level: int, motion: Dictionary = {}) -> void:
	var body := StaticBody3D.new()
	body.name = target_name
	body.position = pos
	body.set_meta("combat_target", true)
	body.set_meta("target_name", target_name)
	body.set_meta("target_profile", "walker_armor_plate")
	body.set_meta("cover_level", cover_level)
	body.set_meta("wound_severity", 0)
	body.add_to_group("range_targets")
	_apply_motion_metadata(body, pos, motion)
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 3.1, 0.55)
	collision.shape = shape
	body.add_child(collision)

	_builder.add_box(body, Vector3(0, 0, 0), Vector3(2.8, 3.1, 0.45), Color(0.38, 0.43, 0.43), "torso")
	_builder.add_box(body, Vector3(0, 0.9, -0.28), Vector3(2.2, 0.22, 0.18), Color(0.72, 0.54, 0.18), "head")
	_builder.add_box(body, Vector3(-1.08, -0.45, -0.3), Vector3(0.22, 1.6, 0.18), Color(0.24, 0.28, 0.28), "left_arm")
	_builder.add_box(body, Vector3(1.08, -0.45, -0.3), Vector3(0.22, 1.6, 0.18), Color(0.24, 0.28, 0.28), "right_arm")
	_builder.add_label(self, pos + Vector3(0, 2.4, 0), "Moving walker scale")

func _apply_motion_metadata(body: Node3D, pos: Vector3, motion: Dictionary) -> void:
	if motion.is_empty():
		return
	body.add_to_group("moving_range_targets")
	body.set_meta("motion_origin", pos)
	body.set_meta("motion_axis", String(motion.get("axis", "x")))
	body.set_meta("motion_distance", float(motion.get("distance", 0.0)))
	body.set_meta("motion_speed", float(motion.get("speed", 0.0)))
	body.set_meta("motion_pattern", String(motion.get("pattern", "sine")))

func _apply_behavior_metadata(body: Node3D, behavior: Dictionary) -> void:
	if behavior.is_empty():
		return
	body.set_meta("fire_cadence_ticks", maxi(int(behavior.get("fire_cadence_ticks", 1)), 1))
	body.set_meta("fire_phase_ticks", int(behavior.get("fire_phase_ticks", 0)))
	body.set_meta("suppression_ticks", maxi(int(behavior.get("suppression_ticks", 0)), 0))
	body.set_meta("pinning_ticks", maxi(int(behavior.get("pinning_ticks", 0)), 0))
	body.set_meta("pinning_miss_margin", maxi(int(behavior.get("pinning_miss_margin", 0)), 0))
	body.set_meta("peek_exposed_ticks", maxi(int(behavior.get("peek_exposed_ticks", 0)), 0))
	body.set_meta("peek_covered_ticks", maxi(int(behavior.get("peek_covered_ticks", 0)), 0))
	body.set_meta("peek_phase_ticks", int(behavior.get("peek_phase_ticks", behavior.get("fire_phase_ticks", 0))))
	body.set_meta("fallback_ticks", maxi(int(behavior.get("fallback_ticks", 0)), 0))
	body.set_meta("fallback_on_wound_severity", maxi(int(behavior.get("fallback_on_wound_severity", 2)), 1))
	body.set_meta("coordination_group", String(behavior.get("coordination_group", "")))
	body.set_meta("coordination_priority", int(behavior.get("coordination_priority", 0)))
	body.set_meta("flank_move_ticks", maxi(int(behavior.get("flank_move_ticks", 0)), 0))
	body.set_meta("flank_cadence_ticks", maxi(int(behavior.get("flank_cadence_ticks", 0)), 0))
	body.set_meta("flank_phase_ticks", int(behavior.get("flank_phase_ticks", behavior.get("fire_phase_ticks", 0))))
	body.set_meta("reload_ticks", maxi(int(behavior.get("reload_ticks", 0)), 0))
	body.set_meta("reload_cadence_ticks", maxi(int(behavior.get("reload_cadence_ticks", 0)), 0))
	body.set_meta("reload_phase_ticks", int(behavior.get("reload_phase_ticks", behavior.get("fire_phase_ticks", 0))))
	body.set_meta("morale_hold_ticks", maxi(int(behavior.get("morale_hold_ticks", 0)), 0))
	body.set_meta("morale_cadence_ticks", maxi(int(behavior.get("morale_cadence_ticks", 0)), 0))
	body.set_meta("morale_phase_ticks", int(behavior.get("morale_phase_ticks", behavior.get("fire_phase_ticks", 0))))
	body.set_meta("morale_min_wound_severity", maxi(int(behavior.get("morale_min_wound_severity", 1)), 1))
	body.set_meta("covering_fire_ticks", maxi(int(behavior.get("covering_fire_ticks", 0)), 0))
	body.set_meta("covering_fire_cadence_ticks", maxi(int(behavior.get("covering_fire_cadence_ticks", 0)), 0))
	body.set_meta("covering_fire_phase_ticks", int(behavior.get("covering_fire_phase_ticks", behavior.get("fire_phase_ticks", 0))))
