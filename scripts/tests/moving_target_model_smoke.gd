extends SceneTree

const MovingTargetModel = preload("res://scripts/rules/moving_target_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	_assert_equal(MovingTargetModel.local_offset(0.0, "x", 4.0, 1.0), Vector3.ZERO, "moving target starts at origin")
	var quarter := MovingTargetModel.local_offset(PI / 2.0, "x", 4.0, 1.0)
	_assert_close(quarter.x, 4.0, "x axis reaches positive distance")
	_assert_close(quarter.z, 0.0, "x axis has no z offset")
	var z_offset := MovingTargetModel.local_offset(PI / 2.0, "z", 3.0, 1.0)
	_assert_close(z_offset.z, -3.0, "z axis uses Godot forward")
	var stopped := MovingTargetModel.local_offset(10.0, "x", 4.0, 0.0)
	_assert_equal(stopped, Vector3.ZERO, "zero speed target is stationary")
	var walker_scale_motion := MovingTargetModel.local_offset(PI / 2.0 / 0.75, "x", 2.5, 0.75)
	_assert_close(walker_scale_motion.x, 2.5, "slow walker-scale target reaches configured lateral distance")
	var patrol_positive := MovingTargetModel.local_offset(1.0, "x", 4.0, 1.0, "patrol")
	_assert_close(patrol_positive.x, 4.0, "patrol target reaches positive endpoint")
	var patrol_center := MovingTargetModel.local_offset(2.0, "x", 4.0, 1.0, "patrol")
	_assert_close(patrol_center.x, 0.0, "patrol target returns through center")
	var patrol_negative := MovingTargetModel.local_offset(3.0, "x", 4.0, 1.0, "patrol")
	_assert_close(patrol_negative.x, -4.0, "patrol target reaches negative endpoint")
	var patrol_alias := MovingTargetModel.local_offset(3.0, "z", 2.0, 1.0, "triangle")
	_assert_close(patrol_alias.z, 2.0, "triangle alias uses Godot forward axis")
	_assert_equal(MovingTargetModel.should_move(2), true, "wounded target can still move")
	_assert_equal(MovingTargetModel.should_move(3), false, "incapacitated target stops moving")
	_assert_equal(MovingTargetModel.should_move(0, true), false, "explicitly paused target stops moving")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("moving_target_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
