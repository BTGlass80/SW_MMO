extends SceneTree

const CombatEventLogModel = preload("res://scripts/rules/combat_event_log_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var log := []
	log = CombatEventLogModel.append_envelope(log, _envelope(100, "ground_range_shot", 1), 2)
	log = CombatEventLogModel.append_envelope(log, _envelope(101, "ground_range_incoming", 2), 2)
	var summary_a := CombatEventLogModel.summary(log)
	_assert_equal(summary_a["count"], 2, "summary count")
	_assert_equal(summary_a["latest_seed"], 101, "latest seed")
	_assert_equal(summary_a["latest_kind"], "ground_range_incoming", "latest kind")
	_assert_equal(summary_a["latest_round"], 2, "latest round")
	_assert_equal(summary_a["latest_event_count"], 1, "latest event count")
	_assert_equal(summary_a["latest_valid"], true, "latest valid")
	_assert_equal(summary_a["latest_pressure_present"], true, "latest pressure present")
	_assert_equal(summary_a["latest_pressure_ready"], 2, "latest pressure ready")
	_assert_equal(summary_a["latest_pressure_next_ready"], 1, "latest pressure next ready")
	_assert_equal(summary_a["latest_pressure_suppressed"], 1, "latest pressure suppressed")
	_assert_equal(summary_a["latest_pressure_pinned"], 1, "latest pressure pinned")
	_assert_equal(summary_a["latest_pressure_covered"], 1, "latest pressure covered")
	_assert_equal(summary_a["latest_pressure_fallback"], 1, "latest pressure fallback")
	_assert_equal(summary_a["latest_pressure_coordinating"], 1, "latest pressure coordinating")
	_assert_equal(summary_a["latest_pressure_flanking"], 1, "latest pressure flanking")
	_assert_equal(summary_a["latest_pressure_reloading"], 1, "latest pressure reloading")
	_assert_equal(summary_a["latest_pressure_hesitating"], 1, "latest pressure hesitating")
	_assert_equal(summary_a["latest_pressure_covering"], 1, "latest pressure covering")
	_assert_equal(summary_a["latest_armor_present"], true, "latest armor present")
	_assert_equal(summary_a["latest_armor_text"], "you torso armor +0->-1", "latest armor text")

	log = CombatEventLogModel.append_envelope(log, _envelope(102, "ground_range_shot", 3), 2)
	_assert_equal(log.size(), 2, "log trims to limit")
	_assert_equal(CombatEventLogModel.summary(log)["latest_seed"], 102, "latest survives trim")
	_assert_equal(CombatEventLogModel.summary(log)["latest_armor_text"], "target left arm unarmored", "target armor text survives summary")
	_assert_equal(CombatEventLogModel.envelopes_for_kind(log, "ground_range_shot").size(), 1, "kind filter")
	_assert_equal(CombatEventLogModel.envelopes_for_kind(log, "ground_range_incoming").size(), 1, "older matching kind remains")

	var latest := CombatEventLogModel.latest(log)
	latest["exchange_seed"] = 999
	_assert_equal(CombatEventLogModel.latest(log)["exchange_seed"], 102, "latest returns copy")

	var empty_summary := CombatEventLogModel.summary([])
	_assert_equal(empty_summary["count"], 0, "empty summary count")
	_assert_equal(empty_summary["latest_seed"], -1, "empty latest seed")
	_assert_equal(empty_summary["latest_pressure_present"], false, "empty pressure hidden")
	_assert_equal(empty_summary["latest_armor_present"], false, "empty armor hidden")
	_assert_equal(CombatEventLogModel.append_envelope(log, {}, 0).size(), 0, "zero limit clears log")

	_finish()

func _envelope(seed: int, kind: String, round_num: int) -> Dictionary:
	return {
		"exchange_seed": seed,
		"exchange_kind": kind,
		"round": round_num,
		"event_count": 1,
		"valid": true,
		"events": _events_for_kind(kind),
		"encounter_state": {
			"present": true,
			"kind": "range_pressure",
			"current": {"ready": 2, "suppressed": 1, "pinned": 1, "covered": 1, "fallback": 1, "coordinating": 1, "flanking": 1, "reloading": 1, "hesitating": 1, "covering": 1},
			"next": {"ready": 1},
		},
	}

func _events_for_kind(kind: String) -> Array:
	if kind == "ground_range_shot":
		return [{
			"type": "target_damage",
			"hit_location": "left_arm",
			"armor_applied": false,
			"armor_quality_pips_before": 0,
			"armor_quality_pips_after": 0,
			"armor_degraded_pips": 0,
		}]
	return [{
		"type": "incoming_fire",
		"player_hit_location": "torso",
		"player_armor_applied": true,
		"player_armor_quality_pips_before": 0,
		"player_armor_quality_pips_after": -1,
		"player_armor_degraded_pips": 1,
	}]

func _finish() -> void:
	if _failures.is_empty():
		print("combat_event_log_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
