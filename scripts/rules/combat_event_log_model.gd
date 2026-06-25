extends RefCounted

const DEFAULT_LIMIT := 25

static func append_envelope(log: Array, envelope: Dictionary, limit: int = DEFAULT_LIMIT) -> Array:
	var next_log := log.duplicate(true)
	if envelope.is_empty():
		return _trim(next_log, limit)
	next_log.append(envelope.duplicate(true))
	return _trim(next_log, limit)

static func latest(log: Array) -> Dictionary:
	if log.is_empty():
		return {}
	var envelope: Dictionary = log[log.size() - 1]
	return envelope.duplicate(true)

static func summary(log: Array) -> Dictionary:
	var latest_envelope := latest(log)
	if latest_envelope.is_empty():
		return {
			"count": 0,
			"latest_seed": -1,
			"latest_kind": "",
			"latest_round": 0,
			"latest_event_count": 0,
			"latest_valid": false,
			"latest_pressure_present": false,
			"latest_pressure_ready": 0,
			"latest_pressure_next_ready": 0,
			"latest_pressure_suppressed": 0,
			"latest_pressure_pinned": 0,
			"latest_pressure_covered": 0,
			"latest_pressure_fallback": 0,
			"latest_pressure_coordinating": 0,
			"latest_pressure_flanking": 0,
			"latest_pressure_reloading": 0,
			"latest_pressure_hesitating": 0,
			"latest_pressure_covering": 0,
			"latest_armor_present": false,
			"latest_armor_text": "",
		}
	var pressure := _pressure_summary(latest_envelope)
	var armor := _armor_summary(latest_envelope)
	return {
		"count": log.size(),
		"latest_seed": int(latest_envelope.get("exchange_seed", -1)),
		"latest_kind": String(latest_envelope.get("exchange_kind", "")),
		"latest_round": int(latest_envelope.get("round", 0)),
		"latest_event_count": int(latest_envelope.get("event_count", 0)),
		"latest_valid": bool(latest_envelope.get("valid", false)),
		"latest_pressure_present": bool(pressure.get("present", false)),
		"latest_pressure_ready": int(pressure.get("ready", 0)),
		"latest_pressure_next_ready": int(pressure.get("next_ready", 0)),
		"latest_pressure_suppressed": int(pressure.get("suppressed", 0)),
		"latest_pressure_pinned": int(pressure.get("pinned", 0)),
		"latest_pressure_covered": int(pressure.get("covered", 0)),
		"latest_pressure_fallback": int(pressure.get("fallback", 0)),
		"latest_pressure_coordinating": int(pressure.get("coordinating", 0)),
		"latest_pressure_flanking": int(pressure.get("flanking", 0)),
		"latest_pressure_reloading": int(pressure.get("reloading", 0)),
		"latest_pressure_hesitating": int(pressure.get("hesitating", 0)),
		"latest_pressure_covering": int(pressure.get("covering", 0)),
		"latest_armor_present": bool(armor.get("present", false)),
		"latest_armor_text": String(armor.get("text", "")),
	}

static func envelopes_for_kind(log: Array, exchange_kind: String) -> Array:
	var matches := []
	for envelope in log:
		if typeof(envelope) == TYPE_DICTIONARY and String(Dictionary(envelope).get("exchange_kind", "")) == exchange_kind:
			matches.append(Dictionary(envelope).duplicate(true))
	return matches

static func _trim(log: Array, limit: int) -> Array:
	var safe_limit := maxi(limit, 0)
	if safe_limit == 0:
		return []
	while log.size() > safe_limit:
		log.pop_front()
	return log

static func _pressure_summary(envelope: Dictionary) -> Dictionary:
	var encounter_state: Dictionary = envelope.get("encounter_state", {})
	if encounter_state.is_empty() or not bool(encounter_state.get("present", false)) or String(encounter_state.get("kind", "")) != "range_pressure":
		return {"present": false}
	var current: Dictionary = encounter_state.get("current", {})
	var next: Dictionary = encounter_state.get("next", {})
	return {
		"present": true,
		"ready": int(current.get("ready", 0)),
		"next_ready": int(next.get("ready", 0)),
		"suppressed": int(current.get("suppressed", 0)),
		"pinned": int(current.get("pinned", 0)),
		"covered": int(current.get("covered", 0)),
		"fallback": int(current.get("fallback", 0)),
		"coordinating": int(current.get("coordinating", 0)),
		"flanking": int(current.get("flanking", 0)),
		"reloading": int(current.get("reloading", 0)),
		"hesitating": int(current.get("hesitating", 0)),
		"covering": int(current.get("covering", 0)),
	}

static func _armor_summary(envelope: Dictionary) -> Dictionary:
	var events: Array = envelope.get("events", [])
	for i in range(events.size() - 1, -1, -1):
		if typeof(events[i]) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = events[i]
		var event_type := String(event.get("type", ""))
		if event_type == "target_damage":
			return _armor_event_summary(
				"target",
				String(event.get("hit_location", "")),
				bool(event.get("armor_applied", false)),
				int(event.get("armor_quality_pips_before", 0)),
				int(event.get("armor_quality_pips_after", 0)),
				int(event.get("armor_degraded_pips", 0))
			)
		if event_type == "remote_return_fire" or event_type == "incoming_fire":
			return _armor_event_summary(
				"you",
				String(event.get("player_hit_location", "")),
				bool(event.get("player_armor_applied", false)),
				int(event.get("player_armor_quality_pips_before", 0)),
				int(event.get("player_armor_quality_pips_after", 0)),
				int(event.get("player_armor_degraded_pips", 0))
			)
	return {"present": false, "text": ""}

static func _armor_event_summary(subject: String, hit_location: String, armor_applied: bool, before: int, after: int, degraded: int) -> Dictionary:
	var location_text := _location_text(hit_location)
	if location_text == "":
		return {"present": false, "text": ""}
	var armor_text := "armor" if armor_applied else "unarmored"
	var quality_text := ""
	if degraded > 0 and before != after:
		quality_text = " %+d->%+d" % [before, after]
	return {
		"present": true,
		"text": "%s %s %s%s" % [subject, location_text, armor_text, quality_text],
	}

static func _location_text(hit_location: String) -> String:
	return hit_location.strip_edges().to_lower().replace("_", " ")
