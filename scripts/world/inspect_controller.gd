extends Node

const ModalOverlayModel = preload("res://scripts/rules/modal_overlay_model.gd")
const RangeInspectionModel = preload("res://scripts/rules/range_inspection_model.gd")

var result_label: Label
var max_ray_distance := 35.0

func _input(event: InputEvent) -> void:
	if _modal_overlay_active():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return

		var hit := _raycast_from_camera(camera)
		if hit.is_empty():
			_show("Nothing obvious catches your attention.")
			return

		var collider: Object = hit.get("collider")
		if collider is Node and collider.has_meta("combat_target"):
			_show(_range_target_text(collider))
			return
		if collider is Node and collider.has_meta("inspectable"):
			var title := String(collider.get_meta("title", "Location"))
			var description := String(collider.get_meta("description", ""))
			_show("%s: %s" % [title, description])

func _raycast_from_camera(camera: Camera3D) -> Dictionary:
	var mouse_pos := get_viewport().get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_pos = get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_ray_distance)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _show(text: String) -> void:
	if result_label != null:
		result_label.text = text

func _range_target_text(target: Node) -> String:
	var target_profile_key := String(target.get_meta("target_profile", ""))
	var range_state := _live_range_state()
	var range_controller := _live_range_controller()
	var target_profiles: Dictionary = range_state.get("target_profiles", {})
	var profile: Dictionary = target_profiles.get(target_profile_key, {})
	var behavior_context := {}
	if range_controller != null and range_controller.has_method("target_live_state_context"):
		behavior_context = range_controller.target_live_state_context(target.get_instance_id())
	return RangeInspectionModel.target_text(
		String(target.get_meta("target_name", target.name)),
		target_profile_key,
		int(target.get_meta("cover_level", 0)),
		int(target.get_meta("wound_severity", 0)),
		int(target.get_meta("armor_quality_pips", 0)),
		profile,
		behavior_context
	)

func _live_range_state() -> Dictionary:
	var range_controller := _live_range_controller()
	if range_controller == null or not range_controller.has_method("get_range_state"):
		return {}
	return range_controller.get_range_state()

func _live_range_controller() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var range_controller := tree.root.find_child("BlasterRangeController", true, false)
	if range_controller == null:
		return null
	return range_controller

func _modal_overlay_active() -> bool:
	return ModalOverlayModel.is_modal_overlay_active(get_tree())
