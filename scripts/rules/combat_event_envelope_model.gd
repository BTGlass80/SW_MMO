extends RefCounted

const ENVELOPE_VERSION := 1
const MESSAGE_TYPE := "combat.exchange.resolved"

static func envelope_for_result(result: Dictionary, exchange_kind: String = "ground_range", channel: String = "local") -> Dictionary:
	var events: Array = result.get("events", [])
	var action_window: Dictionary = result.get("action_window", {})
	return {
		"version": ENVELOPE_VERSION,
		"message_type": MESSAGE_TYPE,
		"channel": channel,
		"exchange_kind": exchange_kind,
		"round": int(result.get("round", result.get("action_window", {}).get("window", 0))),
		"exchange_seed": int(result.get("exchange_seed", -1)),
		"valid": not bool(result.get("invalid_action_window", false)),
		"invalid_action_window": bool(result.get("invalid_action_window", false)),
		"action_window": _action_window_summary(action_window),
		"events": events,
		"event_count": events.size(),
		"event_types": _event_types(events),
		"state_delta": _state_delta(result),
		"encounter_state": _encounter_state_summary(result.get("encounter_state", {})),
		"flags": _result_flags(result),
	}

static func _action_window_summary(action_window: Dictionary) -> Dictionary:
	if action_window.is_empty():
		return {
			"present": false,
			"ready": false,
			"phase": "",
			"active_ids": [],
			"declaration_count": 0,
			"errors": [],
		}
	return {
		"present": true,
		"ready": bool(action_window.get("ready", false)),
		"phase": String(action_window.get("phase", "")),
		"window": int(action_window.get("window", 0)),
		"active_ids": action_window.get("active_ids", []),
		"declaration_count": int(action_window.get("declaration_count", 0)),
		"errors": action_window.get("errors", []),
	}

static func _event_types(events: Array) -> Array:
	var types := []
	for event in events:
		if typeof(event) == TYPE_DICTIONARY:
			types.append(String(Dictionary(event).get("type", "")))
	return types

static func _state_delta(result: Dictionary) -> Dictionary:
	var state: Dictionary = result.get("state", {})
	var target_state: Dictionary = result.get("target_state", {})
	return {
		"next_round": int(state.get("round", 0)),
		"player_wound_severity": int(state.get("player_wound_severity", 0)),
		"target_wound_severity": int(target_state.get("wound_severity", -1)),
		"player_character_points": int(state.get("player_character_points", -1)),
		"player_force_points": int(state.get("player_force_points", -1)),
	}

static func _encounter_state_summary(encounter_state: Dictionary) -> Dictionary:
	if encounter_state.is_empty():
		return {"present": false}
	return {
		"present": true,
		"kind": String(encounter_state.get("kind", "")),
		"tick_index": int(encounter_state.get("tick_index", -1)),
		"live_enabled": bool(encounter_state.get("live_enabled", false)),
		"current": encounter_state.get("current", {}),
		"next": encounter_state.get("next", {}),
	}

static func _result_flags(result: Dictionary) -> Dictionary:
	return {
		"already_disabled": bool(result.get("already_disabled", false)),
		"target_disabled": bool(result.get("target_disabled", false)),
		"player_attack_skipped": bool(result.get("player_attack_skipped", false)),
		"force_point_spent": bool(result.get("force_point_spent", false)),
	}
