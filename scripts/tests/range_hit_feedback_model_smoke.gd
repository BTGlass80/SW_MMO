extends SceneTree

const RangeHitFeedbackModel = preload("res://scripts/rules/range_hit_feedback_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var armored_hit := RangeHitFeedbackModel.target_feedback({
		"attack": {"success": true, "blocked": false, "margin": 8},
		"target_state": {
			"hit_location": "torso",
			"armor_applied": true,
			"armor_degraded_pips": 1,
			"armor_quality_pips_before": 0,
			"armor_quality_pips_after": -1,
			"wound_severity": 2,
		},
		"target_wound": {"name": "Wounded"},
	})
	_assert_equal(armored_hit["visible"], true, "armored hit visible")
	_assert_equal(armored_hit["text"], "HIT torso | armor +0->-1 | Wounded", "armored hit text")
	_assert_equal(armored_hit["location"], "torso", "armored hit location")
	_assert_equal(armored_hit["tone"], "hit_armor", "armored hit tone")

	var unarmored_hit := RangeHitFeedbackModel.target_feedback({
		"attack": {"success": true, "blocked": false, "margin": 3},
		"target_state": {
			"hit_location": "left_arm",
			"armor_applied": false,
			"wound_severity": 1,
		},
		"target_wound": {"name": "Stunned"},
	})
	_assert_equal(unarmored_hit["text"], "HIT left arm | unarmored | Stunned", "unarmored hit text")
	_assert_equal(unarmored_hit["tone"], "hit_unarmored", "unarmored hit tone")

	var miss := RangeHitFeedbackModel.target_feedback({"attack": {"success": false, "blocked": false, "margin": -2}})
	_assert_equal(miss["text"], "MISS -2", "miss text")
	_assert_equal(miss["tone"], "miss", "miss tone")

	var blocked := RangeHitFeedbackModel.target_feedback({"attack": {"success": false, "blocked": true, "margin": -99}})
	_assert_equal(blocked["text"], "BLOCKED", "blocked text")
	_assert_equal(blocked["tone"], "blocked", "blocked tone")

	var skipped := RangeHitFeedbackModel.target_feedback({"player_attack_skipped": true})
	_assert_equal(skipped["visible"], false, "full dodge has no target marker")

	_assert_equal(RangeHitFeedbackModel.location_offset("left_arm"), Vector3(-0.54, -0.05, -0.34), "left arm offset")
	_assert_equal(RangeHitFeedbackModel.tone_color("hit_armor"), Color(0.38, 0.82, 1.0), "armor color")
	_assert_equal(Array(RangeHitFeedbackModel.damage_part_names("right_leg")), ["DamagePart_right_leg", "DamagePart_legs", "DamagePart_torso"], "right leg part fallback")
	_assert_equal(RangeHitFeedbackModel.persistent_damage_color(true, 1), Color(0.22, 0.52, 0.68), "persistent armor scuff color")
	_assert_equal(RangeHitFeedbackModel.persistent_damage_color(false, 3), Color(0.22, 0.04, 0.035), "persistent disabled damage color")
	var armor_marker := RangeHitFeedbackModel.persistent_damage_marker("torso", true, 2)
	_assert_equal(armor_marker["visible"], true, "persistent marker visible")
	_assert_equal(armor_marker["location"], "torso", "persistent marker location")
	_assert_equal(armor_marker["offset"], Vector3(0.0, -0.08, -0.34), "persistent marker torso offset")
	_assert_equal(armor_marker["color"], Color(0.22, 0.52, 0.68), "persistent armor marker color")
	_assert_approx(float(armor_marker["radius"]), 0.17, "persistent armor marker radius")
	_assert_equal(armor_marker["emission"], 0.26, "persistent armor marker emission")
	var disabled_marker := RangeHitFeedbackModel.persistent_damage_marker("left leg", false, 4)
	_assert_equal(disabled_marker["location"], "left_leg", "persistent marker normalizes location")
	_assert_approx(float(disabled_marker["radius"]), 0.215, "persistent disabled marker radius")
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("range_hit_feedback_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_approx(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.0001:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
