extends SceneTree
## HARDENING smoke for the pure quest model (scripts/rules/quest_model.gd). Adversarial edge-case
## coverage beyond quest_model_smoke.gd: non-mutation of every input, unknown-id handling on every
## entry point, multi-quest fan-out from a single event, malformed/partial event + reward data, and
## defs_from_data resilience to bad rows. Deterministic, NO RNG.

const Quest = preload("res://scripts/rules/quest_model.gd")

var _failures: Array[String] = []

# Synthetic, self-contained defs (isolated from the real data file so this test never drifts with content).
func _defs() -> Dictionary:
	return {
		"q_disable_any": {"id": "q_disable_any", "objective": {"kind": "disable", "count": 2},
			"reward": {"credits": 50, "cp": 1}},
		"q_disable_target": {"id": "q_disable_target", "objective": {"kind": "disable", "count": 1, "target_key": "womp_rat"},
			"reward": {"credits": 30}},   # reward.cp deliberately omitted
		"q_zone": {"id": "q_zone", "objective": {"kind": "reach_zone", "zone_id": "z.dune"},
			"reward": {"cp": 2}},         # reward.credits deliberately omitted
		"q_credits": {"id": "q_credits", "objective": {"kind": "earn_credits", "count": 100},
			"reward": {"credits": 10}},
	}

func _init() -> void:
	_test_accept_idempotent_preserves_progress()
	_test_record_event_non_mutating()
	_test_claim_non_mutating()
	_test_unknown_quest_ids()
	_test_negative_credit_event_clamped()
	_test_malformed_events_ignored()
	_test_single_event_fans_out_to_multiple_quests()
	_test_partial_reward_defaults_to_zero()
	_test_defs_from_data_skips_bad_rows()
	_finish()

func _test_accept_idempotent_preserves_progress() -> void:
	var defs := _defs()
	var q := Quest.accept(Quest.initial_quests(), "q_disable_any")
	q = Quest.record_event(q, defs, {"type": "disable"})
	_assert_equal(int((q["q_disable_any"] as Dictionary)["progress"]), 1, "one disable advances progress to 1")
	# re-accepting an in-progress quest must NOT reset progress.
	var q2 := Quest.accept(q, "q_disable_any")
	_assert_equal(int((q2["q_disable_any"] as Dictionary)["progress"]), 1, "re-accept is idempotent; progress preserved")
	_assert_equal(bool((q2["q_disable_any"] as Dictionary)["complete"]), false, "re-accept does not fabricate completion")

func _test_record_event_non_mutating() -> void:
	var defs := _defs()
	var q := Quest.accept(Quest.initial_quests(), "q_disable_any")
	var snapshot := q.duplicate(true)
	var _q2 := Quest.record_event(q, defs, {"type": "disable"})
	_assert_equal(q, snapshot, "record_event does not mutate its `quests` input")

func _test_claim_non_mutating() -> void:
	var defs := _defs()
	var q := Quest.accept(Quest.initial_quests(), "q_credits")
	q = Quest.record_event(q, defs, {"type": "credits", "amount": 500})
	var snapshot := q.duplicate(true)
	var _c := Quest.claim(q, defs, "q_credits")
	_assert_equal(q, snapshot, "claim does not mutate its `quests` input")

func _test_unknown_quest_ids() -> void:
	var defs := _defs()
	var empty := Quest.initial_quests()
	_assert_equal(Quest.is_complete(empty, "no_such_quest"), false, "is_complete on an unknown id is false")
	_assert_equal(Quest.can_claim(empty, "no_such_quest"), false, "can_claim on an unknown id is false")
	var c := Quest.claim(empty, defs, "no_such_quest")
	_assert_equal(bool(c["ok"]), false, "claiming an unknown quest fails")
	_assert_equal(int((c["reward"] as Dictionary)["credits"]), 0, "unknown-quest claim reward is zero (credits)")
	_assert_equal(int((c["reward"] as Dictionary)["cp"]), 0, "unknown-quest claim reward is zero (cp)")
	_assert_equal(c["quests"], empty, "a failed claim returns the SAME quests block unchanged")

func _test_negative_credit_event_clamped() -> void:
	var defs := _defs()
	var q := Quest.accept(Quest.initial_quests(), "q_credits")
	q = Quest.record_event(q, defs, {"type": "credits", "amount": 60})
	q = Quest.record_event(q, defs, {"type": "credits", "amount": -1000})  # must never REDUCE progress
	_assert_equal(int((q["q_credits"] as Dictionary)["progress"]), 60, "a negative credit event clamps to 0 delta, never reduces progress")
	_assert_equal(bool((q["q_credits"] as Dictionary)["complete"]), false, "still incomplete after the negative event")

func _test_malformed_events_ignored() -> void:
	var defs := _defs()
	# targeted disable with a MISSING creature_key on the event -> no match, no progress.
	var q := Quest.accept(Quest.initial_quests(), "q_disable_target")
	q = Quest.record_event(q, defs, {"type": "disable"})  # no creature_key at all
	_assert_equal(int((q["q_disable_target"] as Dictionary)["progress"]), 0, "a disable event with no creature_key does not satisfy a targeted objective")
	# reach_zone with a missing zone_id -> no match.
	var z := Quest.accept(Quest.initial_quests(), "q_zone")
	z = Quest.record_event(z, defs, {"type": "travel"})  # no zone_id
	_assert_equal(bool((z["q_zone"] as Dictionary)["complete"]), false, "a travel event with no zone_id does not complete reach_zone")
	# a totally unrelated event type does nothing to any objective kind.
	var d := Quest.accept(Quest.initial_quests(), "q_disable_any")
	d = Quest.record_event(d, defs, {"type": "chat", "text": "hi"})
	_assert_equal(int((d["q_disable_any"] as Dictionary)["progress"]), 0, "an unrelated event type advances nothing")

func _test_single_event_fans_out_to_multiple_quests() -> void:
	var defs := _defs()
	var q := Quest.accept(Quest.initial_quests(), "q_disable_any")
	q = Quest.accept(q, "q_disable_target")
	# one event that satisfies BOTH an untargeted and a matching targeted disable objective.
	q = Quest.record_event(q, defs, {"type": "disable", "creature_key": "womp_rat"})
	_assert_equal(int((q["q_disable_any"] as Dictionary)["progress"]), 1, "the untargeted quest also advances from the same event")
	_assert_equal(bool((q["q_disable_target"] as Dictionary)["complete"]), true, "the targeted quest completes from the same event")

func _test_partial_reward_defaults_to_zero() -> void:
	var defs := _defs()
	# q_disable_target's reward omits "cp"; q_zone's reward omits "credits". Both must default to 0, not crash.
	var q := Quest.accept(Quest.initial_quests(), "q_disable_target")
	q = Quest.record_event(q, defs, {"type": "disable", "creature_key": "womp_rat"})
	var c := Quest.claim(q, defs, "q_disable_target")
	_assert_equal(int((c["reward"] as Dictionary)["credits"]), 30, "present reward field honored")
	_assert_equal(int((c["reward"] as Dictionary)["cp"]), 0, "missing reward.cp defaults to 0, no crash")

	var z := Quest.accept(Quest.initial_quests(), "q_zone")
	z = Quest.record_event(z, defs, {"type": "travel", "zone_id": "z.dune"})
	var cz := Quest.claim(z, defs, "q_zone")
	_assert_equal(int((cz["reward"] as Dictionary)["cp"]), 2, "present reward field honored (cp)")
	_assert_equal(int((cz["reward"] as Dictionary)["credits"]), 0, "missing reward.credits defaults to 0, no crash")

func _test_defs_from_data_skips_bad_rows() -> void:
	var data := {"quests": [
		{"id": "q_ok", "objective": {"kind": "disable", "count": 1}, "reward": {}},
		{"objective": {"kind": "disable", "count": 1}},   # missing id -> skipped
		{"id": "", "objective": {}},                        # empty id -> skipped
		"not_a_dict",                                       # wrong type -> skipped
		42,                                                  # wrong type -> skipped
	]}
	var defs := Quest.defs_from_data(data)
	_assert_equal(defs.size(), 1, "only the single well-formed row survives defs_from_data")
	_assert_true(defs.has("q_ok"), "the well-formed quest id is present")

func _finish() -> void:
	if _failures.is_empty():
		print("quest_model_edge_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
