extends SceneTree

const SpaceOverlayLayoutModel = preload("res://scripts/rules/space_overlay_layout_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var default_layout := SpaceOverlayLayoutModel.layout_for_viewport(Vector2(1280, 720))
	_assert_vector_approx(default_layout["mode_status_position"], Vector2(34, 82), "default mode status position")
	_assert_vector_approx(default_layout["mode_status_size"], Vector2(794.4, 38), "default mode status size")
	_assert_vector_approx(default_layout["traffic_status_position"], Vector2(34, 122), "default traffic status position")
	_assert_vector_approx(default_layout["traffic_status_size"], Vector2(794.4, 28), "default traffic status size")
	_assert_vector_approx(default_layout["map_origin"], Vector2(32, 154), "default map origin")
	_assert_vector_approx(default_layout["map_size"], Vector2(794.4, 530), "default map size")
	_assert_float_approx(default_layout["panel_width"], 393.6, "default panel width")

	var wide_layout := SpaceOverlayLayoutModel.layout_for_viewport(Vector2(1920, 1080))
	_assert_vector_approx(wide_layout["mode_status_size"], Vector2(1344, 38), "wide viewport status follows map width")
	_assert_vector_approx(wide_layout["map_size"], Vector2(1344, 890), "wide viewport map expands")
	_assert_float_approx(wide_layout["panel_width"], 484, "wide viewport panel remains usable")
	_assert_float_approx(wide_layout["panel_x"], 1404, "wide viewport panel follows map")

	var tiny_layout := SpaceOverlayLayoutModel.layout_for_viewport(Vector2(320, 240))
	_assert_vector_approx(tiny_layout["viewport_size"], Vector2(640, 480), "tiny viewport clamps to safe size")
	_assert_vector_approx(tiny_layout["mode_status_size"], Vector2(440, 38), "tiny viewport status keeps map width")
	_assert_vector_approx(tiny_layout["map_size"], Vector2(440, 320), "tiny viewport keeps minimum map")
	_assert_float_approx(tiny_layout["panel_width"], 320, "tiny viewport keeps minimum panel")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("space_overlay_layout_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_float_approx(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_vector_approx(actual: Vector2, expected: Vector2, label: String) -> void:
	if not actual.is_equal_approx(expected):
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
