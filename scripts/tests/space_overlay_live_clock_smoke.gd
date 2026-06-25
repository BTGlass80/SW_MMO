extends SceneTree

const LiveClockModel = preload("res://scripts/rules/live_clock_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var partial: Dictionary = LiveClockModel.ticks_for_delta(2.0, 1.0, 5.0)
	_assert_equal(partial["ticks"], 0, "partial live traffic delta does not tick")
	_assert_equal(partial["accumulator"], 3.0, "partial live traffic delta accumulates")

	var single: Dictionary = LiveClockModel.ticks_for_delta(3.5, 2.0, 5.0)
	_assert_equal(single["ticks"], 1, "live traffic delta emits one tick")
	_assert_equal(single["accumulator"], 0.5, "live traffic delta carries remainder")

	var catch_up: Dictionary = LiveClockModel.ticks_for_delta(12.0, 0.0, 5.0)
	_assert_equal(catch_up["ticks"], 2, "live traffic can catch up multiple ticks")
	_assert_equal(catch_up["accumulator"], 2.0, "live traffic preserves catch-up remainder")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("space_overlay_live_clock_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
