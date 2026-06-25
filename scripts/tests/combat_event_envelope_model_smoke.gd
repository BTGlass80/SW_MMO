extends SceneTree

const CombatEventEnvelopeModel = preload("res://scripts/rules/combat_event_envelope_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var result := {
		"round": 4,
		"exchange_seed": 12345,
		"action_window": {
			"ready": true,
			"phase": "resolution",
			"window": 4,
			"active_ids": ["trainee", "remote_a"],
			"declaration_count": 2,
			"errors": [],
		},
		"events": [
			{"type": "player_attack", "exchange_seed": 12345},
			{"type": "remote_return_fire", "exchange_seed": 12345},
		],
		"state": {
			"round": 5,
			"player_wound_severity": 1,
			"player_character_points": 4,
			"player_force_points": 1,
		},
		"target_state": {"wound_severity": 2},
		"encounter_state": {
			"kind": "range_pressure",
			"tick_index": 8,
			"live_enabled": true,
			"current": {"armed": 4, "ready": 2, "covered": 1},
			"next": {"armed": 4, "ready": 1, "covered": 2},
		},
		"target_disabled": false,
		"force_point_spent": false,
	}
	var envelope := CombatEventEnvelopeModel.envelope_for_result(result, "ground_range_shot", "test")
	_assert_equal(envelope["version"], 1, "envelope version")
	_assert_equal(envelope["message_type"], "combat.exchange.resolved", "message type")
	_assert_equal(envelope["channel"], "test", "channel")
	_assert_equal(envelope["exchange_kind"], "ground_range_shot", "exchange kind")
	_assert_equal(envelope["round"], 4, "round copied")
	_assert_equal(envelope["exchange_seed"], 12345, "seed copied")
	_assert_equal(envelope["valid"], true, "valid result")
	_assert_equal(envelope["action_window"]["ready"], true, "ready action window")
	_assert_equal(envelope["action_window"]["active_ids"], ["trainee", "remote_a"], "active ids copied")
	_assert_equal(envelope["event_count"], 2, "event count")
	_assert_equal(envelope["event_types"], ["player_attack", "remote_return_fire"], "event types")
	_assert_equal(envelope["state_delta"]["next_round"], 5, "next round")
	_assert_equal(envelope["state_delta"]["player_wound_severity"], 1, "player wound severity")
	_assert_equal(envelope["state_delta"]["target_wound_severity"], 2, "target wound severity")
	_assert_equal(envelope["encounter_state"]["present"], true, "encounter state present")
	_assert_equal(envelope["encounter_state"]["kind"], "range_pressure", "encounter state kind")
	_assert_equal(envelope["encounter_state"]["tick_index"], 8, "encounter tick copied")
	_assert_equal(envelope["encounter_state"]["current"]["ready"], 2, "current ready count copied")
	_assert_equal(envelope["encounter_state"]["next"]["covered"], 2, "next covered count copied")
	_assert_equal(envelope["flags"]["target_disabled"], false, "target disabled flag")

	var invalid := CombatEventEnvelopeModel.envelope_for_result({
		"exchange_seed": 77,
		"invalid_action_window": true,
		"action_window": {"ready": false, "phase": "declaration", "errors": ["bad declaration"]},
		"events": [{"type": "action_window_invalid"}],
		"state": {"round": 1},
	}, "ground_range_incoming")
	_assert_equal(invalid["valid"], false, "invalid result")
	_assert_equal(invalid["action_window"]["phase"], "declaration", "invalid phase retained")
	_assert_equal(invalid["action_window"]["errors"], ["bad declaration"], "invalid errors retained")
	_assert_equal(invalid["event_types"], ["action_window_invalid"], "invalid event type")
	_assert_equal(invalid["encounter_state"]["present"], false, "missing encounter state hidden")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("combat_event_envelope_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
