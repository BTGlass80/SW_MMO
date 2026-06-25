extends SceneTree

const RangeStatusModel = preload("res://scripts/rules/range_status_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var state := {
		"player_cover_level": 1,
		"player_defense": "full_dodge",
		"pending_attack_cp": 2,
		"pending_soak_cp": 1,
		"force_point_active": false,
		"player_force_points": 1,
		"player_wound_severity": 2,
	}
	var audit_summary := {
		"count": 2,
		"latest_kind": "ground_range_incoming",
		"latest_seed": 5150,
		"latest_event_count": 3,
		"latest_valid": true,
		"latest_pressure_present": true,
		"latest_pressure_ready": 2,
		"latest_pressure_next_ready": 1,
		"latest_pressure_suppressed": 1,
		"latest_pressure_pinned": 1,
		"latest_pressure_covered": 1,
		"latest_pressure_fallback": 1,
		"latest_pressure_coordinating": 1,
		"latest_pressure_flanking": 1,
		"latest_pressure_reloading": 1,
		"latest_pressure_hesitating": 1,
		"latest_pressure_covering": 1,
		"latest_armor_present": true,
		"latest_armor_text": "you torso armor +0->-1",
	}
	var active_line := RangeStatusModel.telemetry_line(state, true, 1.5, 6.0, 3, 4, 2, audit_summary, 1, 1, 1, 1, 1, 1, 1, 1, 1)
	_assert_equal(active_line.contains("pressure running 4.5s"), true, "active pressure countdown")
	_assert_equal(active_line.contains("armed 4 / next 2 / suppressed 1 / pinned 1 / covered 1 / fallback 1 / coordinating 1 / flanking 1 / reloading 1 / hesitating 1 / covering 1"), true, "armed, next scheduled, suppressed, pinned, covered, fallback, coordinating, flanking, reloading, hesitating, and covering source counts included")
	_assert_equal(active_line.contains("cover half"), true, "cover state included")
	_assert_equal(active_line.contains("defense full dodge queued"), true, "defense state included")
	_assert_equal(active_line.contains("CP atk 2 / soak 1"), true, "cp queues included")
	_assert_equal(active_line.contains("FP 1 ready"), true, "force point ready included")
	_assert_equal(active_line.contains("wound Wounded"), true, "wound state included")
	_assert_equal(active_line.contains("audit incoming seed 5150 e3 ok p2->1 s1 i1 c1 f1 g1 k1 r1 h1 v1 hit you torso armor +0->-1"), true, "audit summary with pressure and armor included")

	var paused_line := RangeStatusModel.telemetry_line({"force_point_active": true}, false, 0.0, 6.0, 0, 0)
	_assert_equal(paused_line.contains("pressure paused"), true, "paused pressure text")
	_assert_equal(paused_line.contains("armed 0"), true, "empty armed source count")
	_assert_equal(paused_line.contains("FP active"), true, "active force point text")
	var unknown_line := RangeStatusModel.telemetry_line({}, true, 0.0, 6.0, 0)
	_assert_equal(unknown_line.contains("armed ?"), true, "unknown armed source count")
	_assert_equal(unknown_line.contains("audit"), false, "empty audit summary hidden")
	_assert_equal(unknown_line.contains("suppressed"), false, "zero suppressed count hidden")
	_assert_equal(unknown_line.contains("pinned"), false, "zero pinned count hidden")
	_assert_equal(unknown_line.contains("covered"), false, "zero covered count hidden")
	_assert_equal(unknown_line.contains("fallback"), false, "zero fallback count hidden")
	_assert_equal(unknown_line.contains("coordinating"), false, "zero coordinating count hidden")
	_assert_equal(unknown_line.contains("flanking"), false, "zero flanking count hidden")
	_assert_equal(unknown_line.contains("reloading"), false, "zero reloading count hidden")
	_assert_equal(unknown_line.contains("hesitating"), false, "zero hesitating count hidden")
	_assert_equal(unknown_line.contains("covering"), false, "zero covering count hidden")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("range_status_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
