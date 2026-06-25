extends Node

const ModalOverlayModel = preload("res://scripts/rules/modal_overlay_model.gd")
const MovingTargetModel = preload("res://scripts/rules/moving_target_model.gd")

var elapsed_seconds := 0.0

func _process(delta: float) -> void:
	if ModalOverlayModel.is_modal_overlay_active(get_tree()):
		return
	elapsed_seconds += maxf(delta, 0.0)
	for target in get_tree().get_nodes_in_group("moving_range_targets"):
		if not target is Node3D:
			continue
		var target_node := target as Node3D
		if not MovingTargetModel.should_move(int(target_node.get_meta("wound_severity", 0)), bool(target_node.get_meta("motion_paused", false))):
			continue
		var origin: Vector3 = target_node.get_meta("motion_origin", target_node.global_position)
		var axis := String(target_node.get_meta("motion_axis", "x"))
		var distance := float(target_node.get_meta("motion_distance", 0.0))
		var speed := float(target_node.get_meta("motion_speed", 0.0))
		var pattern := String(target_node.get_meta("motion_pattern", "sine"))
		target_node.global_position = origin + MovingTargetModel.local_offset(elapsed_seconds, axis, distance, speed, pattern)
