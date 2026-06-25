extends SceneTree

const RangeTargetModel = preload("res://scripts/rules/range_target_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var armed_remote := {
		"attack_pool": {"dice": 3, "pips": 0},
		"damage_pool": {"dice": 3, "pips": 2},
	}
	var inert_plate := {
		"attack_pool": {"dice": 0, "pips": 0},
		"damage_pool": {"dice": 0, "pips": 0},
	}
	_assert_equal(RangeTargetModel.can_return_fire(armed_remote, 0), true, "armed active remote can return fire")
	_assert_equal(RangeTargetModel.can_return_fire(armed_remote, 3), false, "disabled remote cannot return fire")
	_assert_equal(RangeTargetModel.can_return_fire(inert_plate, 0), false, "inert armor plate cannot return fire")
	var staggered_remote := armed_remote.duplicate()
	staggered_remote["fire_cadence_ticks"] = 3
	staggered_remote["fire_phase_ticks"] = 1
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(staggered_remote, 0, 1), true, "staggered remote fires on configured phase")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(staggered_remote, 0, 2), false, "staggered remote waits between firing ticks")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(staggered_remote, 0, 4), true, "staggered remote repeats after cadence")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(staggered_remote, 3, 4), false, "disabled staggered remote cannot fire")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(inert_plate, 0, 1), false, "inert plate cannot fire on cadence")
	var suppressed_remote := armed_remote.duplicate()
	suppressed_remote["suppressed_until_tick"] = 5
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(suppressed_remote, 0, 4), false, "suppressed remote cannot fire before resume tick")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(suppressed_remote, 0, 5), true, "suppressed remote can fire on resume tick")
	_assert_equal(RangeTargetModel.live_tick_state(suppressed_remote, 0, 4), "suppressed", "suppressed state reported")
	var pinned_remote := armed_remote.duplicate()
	pinned_remote["pinned_until_tick"] = 5
	_assert_equal(RangeTargetModel.is_pinned_on_live_tick(pinned_remote, 4), true, "pinned remote active before resume")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(pinned_remote, 0, 4), false, "pinned remote cannot fire before resume tick")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(pinned_remote, 0, 5), true, "pinned remote can fire on resume tick")
	_assert_equal(RangeTargetModel.live_tick_state(pinned_remote, 0, 4), "pinned", "pinned state reported")
	var pinning_rule := {"pinning_ticks": 2, "pinning_miss_margin": 3}
	_assert_equal(RangeTargetModel.pinning_resume_tick(pinning_rule, 10, -3), 13, "close miss at threshold pins remote")
	_assert_equal(RangeTargetModel.pinning_resume_tick(pinning_rule, 10, -1), 13, "narrow miss pins remote")
	_assert_equal(RangeTargetModel.pinning_resume_tick(pinning_rule, 10, -4), 10, "wide miss does not pin remote")
	_assert_equal(RangeTargetModel.pinning_resume_tick(pinning_rule, 10, 0), 10, "hit margin does not use miss pinning")
	_assert_equal(RangeTargetModel.pinning_resume_tick({"pinning_ticks": 0, "pinning_miss_margin": 3}, 10, -1), 10, "unconfigured pinning stays quiet")
	var peeking_remote := armed_remote.duplicate()
	peeking_remote["fire_cadence_ticks"] = 1
	peeking_remote["peek_exposed_ticks"] = 1
	peeking_remote["peek_covered_ticks"] = 2
	peeking_remote["peek_phase_ticks"] = 0
	_assert_equal(RangeTargetModel.is_peek_covered_on_live_tick(peeking_remote, 0), false, "peek remote starts exposed")
	_assert_equal(RangeTargetModel.is_peek_covered_on_live_tick(peeking_remote, 1), true, "peek remote tucks after exposed tick")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(peeking_remote, 0, 1), false, "covered peeking remote cannot fire")
	_assert_equal(RangeTargetModel.live_tick_state(peeking_remote, 0, 1), "covered", "covered state reported")
	_assert_equal(RangeTargetModel.live_tick_state(peeking_remote, 0, 3), "ready", "peeking remote becomes ready again")
	var fallback_remote := armed_remote.duplicate()
	fallback_remote["fallback_until_tick"] = 4
	_assert_equal(RangeTargetModel.is_falling_back_on_live_tick(fallback_remote, 3), true, "fallback remote active before resume")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(fallback_remote, 0, 3), false, "fallback remote cannot fire before resume tick")
	_assert_equal(RangeTargetModel.live_tick_state(fallback_remote, 0, 3), "fallback", "fallback state reported")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(fallback_remote, 0, 4), true, "fallback remote can fire on resume tick")
	var hesitating_remote := armed_remote.duplicate()
	hesitating_remote["fire_cadence_ticks"] = 1
	hesitating_remote["morale_hold_ticks"] = 1
	hesitating_remote["morale_cadence_ticks"] = 3
	hesitating_remote["morale_phase_ticks"] = 2
	hesitating_remote["morale_min_wound_severity"] = 1
	_assert_equal(RangeTargetModel.is_hesitating_on_live_tick(hesitating_remote, 0, 2), false, "fresh remote ignores morale hesitation")
	_assert_equal(RangeTargetModel.is_hesitating_on_live_tick(hesitating_remote, 1, 2), true, "wounded remote hesitates on morale phase")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(hesitating_remote, 1, 2), false, "hesitating remote cannot fire")
	_assert_equal(RangeTargetModel.live_tick_state(hesitating_remote, 1, 2), "hesitating", "hesitating state reported")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(hesitating_remote, 1, 3), true, "hesitating remote can fire after hold")
	var flanking_remote := armed_remote.duplicate()
	flanking_remote["fire_cadence_ticks"] = 1
	flanking_remote["flank_move_ticks"] = 1
	flanking_remote["flank_cadence_ticks"] = 4
	flanking_remote["flank_phase_ticks"] = 2
	_assert_equal(RangeTargetModel.is_flanking_on_live_tick(flanking_remote, 2), true, "flanking remote is repositioning on phase tick")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(flanking_remote, 0, 2), false, "flanking remote cannot fire while moving")
	_assert_equal(RangeTargetModel.live_tick_state(flanking_remote, 0, 2), "flanking", "flanking state reported")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(flanking_remote, 0, 3), true, "flanking remote can fire after repositioning")
	var reloading_remote := armed_remote.duplicate()
	reloading_remote["fire_cadence_ticks"] = 2
	reloading_remote["fire_phase_ticks"] = 1
	reloading_remote["reload_ticks"] = 1
	reloading_remote["reload_cadence_ticks"] = 4
	reloading_remote["reload_phase_ticks"] = 3
	_assert_equal(RangeTargetModel.is_reloading_on_live_tick(reloading_remote, 3), true, "reloading remote is cycling on reload phase")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(reloading_remote, 0, 3), false, "reloading remote cannot fire on a reload tick")
	_assert_equal(RangeTargetModel.live_tick_state(reloading_remote, 0, 3), "reloading", "reloading state reported")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(reloading_remote, 0, 5), true, "reloading remote can fire after weapon cycle")
	var covering_remote := armed_remote.duplicate()
	covering_remote["fire_cadence_ticks"] = 1
	covering_remote["covering_fire_ticks"] = 1
	covering_remote["covering_fire_cadence_ticks"] = 4
	covering_remote["covering_fire_phase_ticks"] = 2
	_assert_equal(RangeTargetModel.is_covering_on_live_tick(covering_remote, 2), true, "covering remote creates pressure on phase tick")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(covering_remote, 0, 2), false, "covering remote does not resolve damage fire")
	_assert_equal(RangeTargetModel.live_tick_state(covering_remote, 0, 2), "covering", "covering state reported")
	_assert_equal(RangeTargetModel.can_fire_on_live_tick(covering_remote, 0, 3), true, "covering remote can fire after covering hold")
	var summary_reloading_remote := reloading_remote.duplicate()
	summary_reloading_remote["reload_phase_ticks"] = 2
	_assert_equal(RangeTargetModel.live_tick_state(inert_plate, 0, 1), "inert", "inert state reported")
	_assert_equal(RangeTargetModel.live_tick_state(armed_remote, 3, 1), "disabled", "disabled state reported before inert")
	var fireteam_lead := armed_remote.duplicate()
	fireteam_lead["coordination_group"] = "bay_pair"
	fireteam_lead["coordination_priority"] = 0
	var fireteam_wing := armed_remote.duplicate()
	fireteam_wing["coordination_group"] = "bay_pair"
	fireteam_wing["coordination_priority"] = 1
	var coordinated_states := RangeTargetModel.live_tick_states([
		{"profile": fireteam_wing, "wound_severity": 0},
		{"profile": fireteam_lead, "wound_severity": 0},
	], 0)
	_assert_equal(coordinated_states[0], "coordinating", "lower-priority fireteam remote holds fire")
	_assert_equal(coordinated_states[1], "ready", "higher-priority fireteam remote remains ready")
	var coordinated_summary := RangeTargetModel.live_tick_summary([
		{"profile": fireteam_wing, "wound_severity": 0},
		{"profile": fireteam_lead, "wound_severity": 0},
	], 0)
	_assert_equal(coordinated_summary["armed"], 2, "coordinated summary keeps both sources armed")
	_assert_equal(coordinated_summary["ready"], 1, "coordinated summary counts selected shooter")
	_assert_equal(coordinated_summary["coordinating"], 1, "coordinated summary counts held wingmate")
	var summary := RangeTargetModel.live_tick_summary([
		{"profile": armed_remote, "wound_severity": 0},
		{"profile": staggered_remote, "wound_severity": 0},
		{"profile": suppressed_remote, "wound_severity": 0},
		{"profile": pinned_remote, "wound_severity": 0},
		{"profile": peeking_remote, "wound_severity": 0},
		{"profile": fallback_remote, "wound_severity": 0},
		{"profile": hesitating_remote, "wound_severity": 1},
		{"profile": flanking_remote, "wound_severity": 0},
		{"profile": summary_reloading_remote, "wound_severity": 0},
		{"profile": covering_remote, "wound_severity": 0},
		{"profile": inert_plate, "wound_severity": 0},
		{"profile": armed_remote, "wound_severity": 3},
	], 2)
	_assert_equal(summary["armed"], 10, "summary counts armed return-fire sources")
	_assert_equal(summary["ready"], 1, "summary counts ready source")
	_assert_equal(summary["waiting"], 1, "summary counts cadence-waiting source")
	_assert_equal(summary["suppressed"], 1, "summary counts suppressed source")
	_assert_equal(summary["pinned"], 1, "summary counts pinned source")
	_assert_equal(summary["covered"], 1, "summary counts tucked covered source")
	_assert_equal(summary["fallback"], 1, "summary counts fallback source")
	_assert_equal(summary["hesitating"], 1, "summary counts hesitating source")
	_assert_equal(summary["flanking"], 1, "summary counts flanking source")
	_assert_equal(summary["reloading"], 1, "summary counts reloading source")
	_assert_equal(summary["covering"], 1, "summary counts covering source")
	_assert_equal(summary["coordinating"], 0, "summary omits coordinating sources when no group holds")
	_assert_equal(summary["inert"], 1, "summary counts inert source")
	_assert_equal(summary["disabled"], 1, "summary counts disabled source")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("range_target_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
