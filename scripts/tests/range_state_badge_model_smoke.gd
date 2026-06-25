extends SceneTree

const RangeStateBadgeModel = preload("res://scripts/rules/range_state_badge_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var ready := RangeStateBadgeModel.badge_for_state("ready")
	_assert_equal(ready["visible"], true, "ready visible")
	_assert_equal(ready["text"], "READY", "ready text")
	_assert_equal(ready["color"], Color(1.0, 0.24, 0.16), "ready color")

	var covered := RangeStateBadgeModel.badge_for_state("covered")
	_assert_equal(covered["text"], "TUCKED", "covered text")
	_assert_equal(covered["color"], Color(0.34, 0.70, 1.0), "covered color")

	var covering := RangeStateBadgeModel.badge_for_state("covering")
	_assert_equal(covering["text"], "COVER", "covering text")
	_assert_equal(RangeStateBadgeModel.explanation_for_state("covering"), "applying covering pressure", "covering explanation")

	var fallback := RangeStateBadgeModel.badge_for_state("fallback")
	_assert_equal(fallback["text"], "FALLBACK", "fallback text")
	_assert_equal(RangeStateBadgeModel.explanation_for_state("pinned"), "pinned by near miss", "pinned explanation")

	var disabled := RangeStateBadgeModel.badge_for_state("disabled")
	_assert_equal(disabled["text"], "DOWN", "disabled text")

	var unknown := RangeStateBadgeModel.badge_for_state("custom_state")
	_assert_equal(unknown["text"], "CUSTOM_STATE", "unknown uppercase text")

	_assert_equal(RangeStateBadgeModel.badge_height_for_profile("b1_training_silhouette"), 1.45, "b1 badge height")
	_assert_equal(RangeStateBadgeModel.badge_height_for_profile("walker_armor_plate"), 2.05, "walker badge height")
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("range_state_badge_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
