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

	# -------------------------------------------------------------------------
	# E20: trim keeps NEWEST entries — strong ordering asserts
	# -------------------------------------------------------------------------
	# Build a fresh log with cap=3, push 5 envelopes (seeds 10..14).
	# _trim calls pop_front() until size <= limit, so it discards the oldest.
	# After all appends the log must contain exactly seeds [12, 13, 14] in that
	# chronological order (index 0 = oldest-of-kept, index 2 = newest).
	var trim_log: Array = []
	trim_log = CombatEventLogModel.append_envelope(trim_log, _envelope(10, "ground_range_shot", 1), 3)
	trim_log = CombatEventLogModel.append_envelope(trim_log, _envelope(11, "ground_range_shot", 2), 3)
	trim_log = CombatEventLogModel.append_envelope(trim_log, _envelope(12, "ground_range_shot", 3), 3)
	trim_log = CombatEventLogModel.append_envelope(trim_log, _envelope(13, "ground_range_shot", 4), 3)
	trim_log = CombatEventLogModel.append_envelope(trim_log, _envelope(14, "ground_range_shot", 5), 3)

	_assert_equal(trim_log.size(), 3, "E20 trim: log size equals cap")

	# Oldest-kept must be seed 12 (seeds 10 and 11 were popped from front)
	var trim_entry_0: Dictionary = trim_log[0]
	_assert_equal(int(trim_entry_0.get("exchange_seed", -1)), 12, "E20 trim: index 0 is seed 12 (oldest-kept)")

	var trim_entry_1: Dictionary = trim_log[1]
	_assert_equal(int(trim_entry_1.get("exchange_seed", -1)), 13, "E20 trim: index 1 is seed 13")

	var trim_entry_2: Dictionary = trim_log[2]
	_assert_equal(int(trim_entry_2.get("exchange_seed", -1)), 14, "E20 trim: index 2 is seed 14 (newest)")

	# latest() reads log[size-1] — must be the newest seed
	var trim_latest: Dictionary = CombatEventLogModel.latest(trim_log)
	_assert_equal(int(trim_latest.get("exchange_seed", -1)), 14, "E20 trim: latest() returns newest seed")

	# -------------------------------------------------------------------------
	# E20: kind-filtered view is in stable CHRONOLOGICAL order
	# -------------------------------------------------------------------------
	# Build a log with interleaved kinds, cap=10 (no trim).
	# envelopes_for_kind iterates log forward so matches come out in insertion
	# order (ascending seed).  Reversing trim or shuffling the filter loop
	# would produce a different order and break these asserts.
	var kind_log: Array = []
	kind_log = CombatEventLogModel.append_envelope(kind_log, _envelope(20, "ground_range_shot",     1), 10)
	kind_log = CombatEventLogModel.append_envelope(kind_log, _envelope(21, "ground_range_incoming", 2), 10)
	kind_log = CombatEventLogModel.append_envelope(kind_log, _envelope(22, "ground_range_shot",     3), 10)
	kind_log = CombatEventLogModel.append_envelope(kind_log, _envelope(23, "ground_range_incoming", 4), 10)
	kind_log = CombatEventLogModel.append_envelope(kind_log, _envelope(24, "ground_range_shot",     5), 10)

	var shots: Array = CombatEventLogModel.envelopes_for_kind(kind_log, "ground_range_shot")
	_assert_equal(shots.size(), 3, "E20 kind filter: shot count")

	var shot_0: Dictionary = shots[0]
	_assert_equal(int(shot_0.get("exchange_seed", -1)), 20, "E20 kind filter: shots[0] seed=20 (chronological first)")

	var shot_1: Dictionary = shots[1]
	_assert_equal(int(shot_1.get("exchange_seed", -1)), 22, "E20 kind filter: shots[1] seed=22 (chronological second)")

	var shot_2: Dictionary = shots[2]
	_assert_equal(int(shot_2.get("exchange_seed", -1)), 24, "E20 kind filter: shots[2] seed=24 (chronological third)")

	var incomings: Array = CombatEventLogModel.envelopes_for_kind(kind_log, "ground_range_incoming")
	_assert_equal(incomings.size(), 2, "E20 kind filter: incoming count")

	var inc_0: Dictionary = incomings[0]
	_assert_equal(int(inc_0.get("exchange_seed", -1)), 21, "E20 kind filter: incomings[0] seed=21 (chronological first)")

	var inc_1: Dictionary = incomings[1]
	_assert_equal(int(inc_1.get("exchange_seed", -1)), 23, "E20 kind filter: incomings[1] seed=23 (chronological second)")

	# A kind with no entries must return an empty array, not a crash
	var none_found: Array = CombatEventLogModel.envelopes_for_kind(kind_log, "melee_strike")
	_assert_equal(none_found.size(), 0, "E20 kind filter: unknown kind returns empty")

	# -------------------------------------------------------------------------
	# E20: trim + kind-filter interaction — newest N kept, filter still ordered
	# -------------------------------------------------------------------------
	# Push 5 mixed-kind envelopes with cap=3; oldest 2 are dropped.
	# Remaining are seeds 22..24.  kind-filter on "ground_range_shot" must
	# return [22, 24] in order — not [24, 22] (reverse) and not [20, 22, 24].
	var combo_log: Array = []
	combo_log = CombatEventLogModel.append_envelope(combo_log, _envelope(20, "ground_range_shot",     1), 3)
	combo_log = CombatEventLogModel.append_envelope(combo_log, _envelope(21, "ground_range_incoming", 2), 3)
	combo_log = CombatEventLogModel.append_envelope(combo_log, _envelope(22, "ground_range_shot",     3), 3)
	combo_log = CombatEventLogModel.append_envelope(combo_log, _envelope(23, "ground_range_incoming", 4), 3)
	combo_log = CombatEventLogModel.append_envelope(combo_log, _envelope(24, "ground_range_shot",     5), 3)

	_assert_equal(combo_log.size(), 3, "E20 combo: log trimmed to cap=3")

	var combo_shots: Array = CombatEventLogModel.envelopes_for_kind(combo_log, "ground_range_shot")
	# seeds 20 and 21 were trimmed; only seeds 22, 23, 24 survive.
	# Of those, "ground_range_shot" matches seeds 22 and 24.
	_assert_equal(combo_shots.size(), 2, "E20 combo: 2 shots survive trim+filter")

	var cshot_0: Dictionary = combo_shots[0]
	_assert_equal(int(cshot_0.get("exchange_seed", -1)), 22, "E20 combo: combo_shots[0] is seed 22 (oldest surviving shot)")

	var cshot_1: Dictionary = combo_shots[1]
	_assert_equal(int(cshot_1.get("exchange_seed", -1)), 24, "E20 combo: combo_shots[1] is seed 24 (newest)")

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
