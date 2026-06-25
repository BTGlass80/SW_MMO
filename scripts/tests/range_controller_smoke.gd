extends SceneTree

const ReticleAimModel = preload("res://scripts/rules/reticle_aim_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var viewport_size := Vector2(1280, 720)
	var drifted_mouse := Vector2(32, 44)

	_assert_equal(
		ReticleAimModel.aim_point_for_mouse_mode(Input.MOUSE_MODE_CAPTURED, viewport_size, drifted_mouse),
		Vector2(640, 360),
		"captured mouse aims from reticle center"
	)
	_assert_equal(
		ReticleAimModel.aim_point_for_mouse_mode(Input.MOUSE_MODE_VISIBLE, viewport_size, drifted_mouse),
		drifted_mouse,
		"visible mouse aims from cursor position"
	)

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("range_controller_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
