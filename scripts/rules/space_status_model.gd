extends RefCounted

const HULL_NAMES := {
	0: "Operational",
	1: "Shield/Controls Hit",
	2: "Lightly Damaged",
	3: "Heavily Damaged",
	4: "Severely Damaged",
	5: "Destroyed",
}

const REPAIR_DIFFICULTY_NAMES := {
	10: "Easy",
	15: "Moderate",
	20: "Difficult",
	25: "Very Difficult",
}

const REPAIR_DIFFICULTIES := {
	"easy": 10,
	"moderate": 15,
	"difficult": 20,
	"very_difficult": 25,
}

const REPAIR_DIFFICULTY_OVERRIDE_MISSING := -99999

static func telemetry_line(state: Dictionary, contacts: Array, player_ship: Dictionary, live_enabled: bool, accumulator: float, tick_seconds: float, tick_count: int) -> String:
	var next_tick := maxf(tick_seconds - accumulator, 0.0)
	var live_text := "running %.1fs" % next_tick if live_enabled else "paused"
	var revealed: Array = state.get("revealed_contacts", [])
	var hidden_count := _hidden_contact_count(contacts, revealed)
	var known_count := _known_contact_count(contacts, revealed)
	return "Space state | traffic %s | contacts %d known %d hidden %d | locks %s | hostile %s | assists %s | ship %s | updates %d" % [
		live_text,
		contacts.size(),
		known_count,
		hidden_count,
		_lock_text(state, contacts),
		_automatic_hostile_fire_summary(state),
		_assist_text(state),
		_condition_text(player_ship),
		maxi(tick_count, 0),
	]

static func repair_change_text(event: Dictionary) -> String:
	var before_summary: Dictionary = event.get("before_condition_summary", {})
	var after_summary: Dictionary = event.get("after_condition_summary", {})
	var before_text := String(before_summary.get("text", ""))
	var after_text := String(after_summary.get("text", ""))
	if before_text == "" or after_text == "" or before_text == after_text:
		return ""
	return "%s -> %s" % [before_text, after_text]

static func damage_control_text(event: Dictionary, repaired_ship: Dictionary = {}, seed: int = 0) -> String:
	var status := "repaired" if bool(event.get("success", false)) else "not repaired"
	var quote: Dictionary = event.get("repair_quote", {})
	var change_text := repair_change_text(event)
	var change_suffix := "" if change_text == "" else " %s." % change_text
	return "Damage control seed %d: %s %d vs %s on %s %s, %s.%s%s %s.%s %s" % [
		int(event.get("repair_seed", seed)),
		String(event.get("repair_pool", "0D")),
		int(event.get("roll", {}).get("total", 0)),
		_damage_control_difficulty_text(event, quote),
		String(event.get("ship_name", repaired_ship.get("name", "Ship"))),
		String(event.get("system", "")).replace("_", " "),
		status,
		station_assist_suffix(event),
		station_wound_suffix(event),
		_damage_control_repair_quote_text(quote),
		change_suffix,
		ship_condition_text(repaired_ship),
	]

static func _damage_control_difficulty_text(event: Dictionary, quote: Dictionary) -> String:
	var difficulty := int(event.get("difficulty", 0))
	var name := String(quote.get("difficulty_name", "")).strip_edges()
	if name == "":
		return str(difficulty)
	return "%d %s" % [difficulty, name]

static func _damage_control_repair_quote_text(quote: Dictionary) -> String:
	var yard_cost := int(quote.get("yard_cost_credits", 0))
	if quote.has("can_field_repair") and not bool(quote.get("can_field_repair", true)):
		return "Field unavailable; yard %d cr" % yard_cost
	return "Field %d rounds/free; yard %d cr" % [
		int(quote.get("field_time_rounds", 0)),
		yard_cost,
	]

static func station_assist_applied_text(event: Dictionary) -> String:
	var assist: Dictionary = event.get("station_assist", {})
	if not bool(assist.get("applies", false)):
		return ""
	var name := String(assist.get("name", "Station Assist"))
	var requested := String(assist.get("requested_target_action", "")).strip_edges()
	var target_action := String(assist.get("target_action", "")).strip_edges()
	var target_text := ""
	if requested != "" and target_action != "" and requested.replace("-", "_").to_lower() != target_action.to_lower():
		target_text = " for %s" % station_target_action_text(assist)
	var pool_text := String(assist.get("pool_text", assist.get("pool", "")))
	if pool_text == "":
		return "%s%s" % [name, target_text]
	var round_text := _banked_round_text(assist)
	return "%s +%s%s%s" % [name, pool_text, target_text, round_text]

static func station_assist_suffix(event: Dictionary) -> String:
	var assist_text := station_assist_applied_text(event)
	if assist_text == "":
		return ""
	return " Assist %s." % assist_text

static func station_wound_text(event: Dictionary, key: String = "station_wound") -> String:
	var wound: Dictionary = event.get(key, {})
	if not bool(wound.get("applies", false)):
		return ""
	var name := String(wound.get("crew_name", "Crew"))
	if name == "":
		name = "Crew"
	var wound_name := String(wound.get("wound_name", "Wounded"))
	var penalty := int(wound.get("penalty_dice", 0))
	if penalty <= 0:
		return ""
	if bool(wound.get("action_blocked", false)):
		return "%s %s station disabled" % [name, wound_name]
	return "%s %s -%dD" % [name, wound_name, penalty]

static func station_wound_suffix(event: Dictionary) -> String:
	var wound_text := station_wound_text(event)
	if wound_text == "":
		return ""
	return " Wound %s." % wound_text

static func gunnery_station_wound_suffix(event: Dictionary) -> String:
	var parts := PackedStringArray()
	var attacker_text := station_wound_text(event, "attacker_station_wound")
	if attacker_text != "":
		parts.append("attacker %s" % attacker_text)
	var target_text := station_wound_text(event, "target_station_wound")
	if target_text != "":
		parts.append("target %s" % target_text)
	if parts.is_empty():
		return ""
	return " Wound %s." % "; ".join(parts)

static func station_replacement_text(event: Dictionary) -> String:
	if not bool(event.get("replaced_existing", false)):
		return ""
	var replaced: Dictionary = event.get("replaced_assist", {})
	var name := String(replaced.get("name", "previous assist"))
	var pool := String(replaced.get("pool", ""))
	var replaced_target_event := replaced.duplicate(true)
	if not replaced_target_event.has("target_action"):
		replaced_target_event["target_action"] = event.get("target_action", "")
	var target := station_target_action_text(replaced_target_event)
	if pool == "":
		return " Replaced %s for %s." % [name, target]
	return " Replaced %s %s for %s." % [name, pool, target]

static func station_target_action_text(event: Dictionary) -> String:
	var target_action := String(event.get("target_action", "")).replace("_", " ")
	var requested := String(event.get("requested_target_action", "")).strip_edges()
	var requested_label := requested.replace("_", " ").replace("-", " ")
	if requested_label == "" or requested_label.to_lower() == target_action.to_lower():
		return target_action
	return "%s (%s)" % [target_action, requested_label]

static func shield_reroute_text(event: Dictionary, seed: int = 0) -> String:
	var arc_names := PackedStringArray()
	for arc in event.get("requested_arcs", []):
		arc_names.append(String(arc))
	var success_text := "online" if bool(event.get("success", false)) else "failed"
	return "Shields %d seed %d: %s %d vs %d, %s %s.%s%s" % [
		int(event.get("shield_round", 0)),
		int(event.get("reroute_seed", seed)),
		String(event.get("shield_pool", "0D")),
		int(event.get("roll", {}).get("total", 0)),
		int(event.get("difficulty", 0)),
		", ".join(arc_names),
		success_text,
		station_assist_suffix(event),
		station_wound_suffix(event),
	]

static func station_assist_action_text(event: Dictionary, seed: int = 0) -> String:
	var status := "banked" if bool(event.get("success", false)) else "failed"
	return "Station %d seed %d: %s %d vs %d, %s %s %s for next %s (+%s).%s%s" % [
		int(event.get("station_round", 0)),
		int(event.get("assist_seed", seed)),
		String(event.get("assist_pool", "0D")),
		int(event.get("roll", {}).get("total", 0)),
		int(event.get("difficulty", 0)),
		String(event.get("station", "station")).capitalize(),
		status,
		String(event.get("assist_name", "station assist")),
		station_target_action_text(event),
		String(event.get("bonus_pool", "0D")),
		station_replacement_text(event),
		station_wound_suffix(event),
	]

static func astrogation_plot_text(event: Dictionary, ship: Dictionary = {}, seed: int = 0) -> String:
	var status := "plotted" if bool(event.get("success", false)) else "failed"
	var reason := ""
	if not bool(event.get("can_plot", true)):
		reason = ", hyperdrive unavailable"
	var penalty := int(event.get("calculation_penalty", 0)) + int(event.get("astrogation_penalty", 0))
	var penalty_text := " +%d nav penalty" % penalty if penalty > 0 else ""
	return "Astrogation %d seed %d: %s %d vs %d%s, %s%s.%s%s %s -> %s" % [
		int(event.get("astrogation_round", 0)),
		int(event.get("plot_seed", seed)),
		String(event.get("action_pool", "0D")),
		int(event.get("roll", {}).get("total", 0)),
		int(event.get("difficulty", 0)),
		penalty_text,
		String(event.get("plot_name", "plot")),
		" %s" % status,
		station_assist_suffix(event),
		station_wound_suffix(event),
		String(event.get("before_condition_summary", {}).get("text", "Operational")),
		String(event.get("after_condition_summary", {}).get("text", _condition_summary_text(ship.get("condition", {})))),
	]

static func contact_identification_text(event: Dictionary, seed: int = 0) -> String:
	var status := "identified" if bool(event.get("success", false)) else "unresolved"
	var reason := ""
	if not bool(event.get("can_identify", true)):
		reason = ", no sensor track"
	var penalty := int(event.get("track_penalty", 0))
	var penalty_text := " +%d track penalty" % penalty if penalty > 0 else ""
	var identity_text := "none"
	if bool(event.get("success", false)):
		var identity: Dictionary = event.get("identity", {})
		identity_text = "%s [%s, %s]" % [
			String(identity.get("declared_name", event.get("contact_name", "Contact"))),
			String(identity.get("affiliation", "unknown")),
			String(identity.get("threat", "unknown")),
		]
	var sensor_context: Dictionary = event.get("sensor_context", {})
	return "Identify %d seed %d: %s %d vs %d%s, %s %s%s. Track %s. ID: %s.%s%s" % [
		int(event.get("identification_round", 0)),
		int(event.get("identify_seed", seed)),
		String(event.get("sensor_pool", "0D")),
		int(event.get("roll", {}).get("total", 0)),
		int(event.get("difficulty", 0)),
		penalty_text,
		String(event.get("contact_name", "Contact")),
		status,
		reason,
		String(sensor_context.get("confidence_name", "Unresolved")),
		identity_text,
		station_assist_suffix(event),
		station_wound_suffix(event),
	]

static func comms_hail_text(event: Dictionary, seed: int = 0) -> String:
	var status := "open" if bool(event.get("success", false)) else "no reply"
	var reason := ""
	if not bool(event.get("can_hail", true)):
		reason = ", no selected contact"
	var modifier := int(event.get("identity_penalty", 0)) + int(event.get("threat_modifier", 0))
	var modifier_text := " +%d comms pressure" % modifier if modifier > 0 else ""
	var identified_text := "identified" if bool(event.get("identified", false)) else "unidentified"
	return "Comms %d seed %d: %s %d vs %d%s, %s %s%s (%s). %s%s%s%s%s" % [
		int(event.get("comms_round", 0)),
		int(event.get("hail_seed", seed)),
		String(event.get("communications_pool", "0D")),
		int(event.get("roll", {}).get("total", 0)),
		int(event.get("difficulty", 0)),
		modifier_text,
		String(event.get("contact_name", "Contact")),
		status,
		reason,
		identified_text,
		String(event.get("response", "")),
		comms_weapon_solution_delay_text(event),
		comms_weapon_solution_pressure_text(event),
		station_assist_suffix(event),
		station_wound_suffix(event),
	]

static func comms_weapon_solution_delay_text(event: Dictionary) -> String:
	var delay: Dictionary = event.get("weapon_solution_delay", {})
	if not bool(delay.get("applies", false)):
		return ""
	return " Delayed lock: %s %d->%d." % [
		String(delay.get("contact_name", event.get("contact_name", "Contact"))),
		int(delay.get("prior_rounds", 0)),
		int(delay.get("remaining_rounds", 0)),
	]

static func comms_weapon_solution_pressure_text(event: Dictionary) -> String:
	var pressure: Dictionary = event.get("weapon_solution_pressure", {})
	if not bool(pressure.get("applies", false)):
		return ""
	var ready_suffix := " (ready)" if bool(pressure.get("fire_ready", false)) else ""
	return " Escalated lock: %s %d->%d%s." % [
		String(pressure.get("contact_name", event.get("contact_name", "Contact"))),
		int(pressure.get("prior_rounds", 0)),
		int(pressure.get("current_rounds", 0)),
		ready_suffix,
	]

static func maneuver_action_text(event: Dictionary, ship: Dictionary = {}, seed: int = 0) -> String:
	var status := "clean" if bool(event.get("success", false)) else String(event.get("failure", {}).get("name", "failed"))
	return "Maneuver %d seed %d: %s %d vs %d, heading %d, move %.1f (%s).%s%s%s%s%s %s" % [
		int(event.get("maneuver_round", 0)),
		int(event.get("maneuver_seed", seed)),
		String(event.get("action_pool", "0D")),
		int(event.get("roll", {}).get("total", 0)),
		int(event.get("difficulty", 0)),
		int(event.get("heading_degrees", 0)),
		float(event.get("actual_move", 0.0)),
		status,
		maneuver_hazard_text(event.get("hazard_context", {})),
		maneuver_collision_text(event.get("collision", {})),
		weapon_solution_break_text(event),
		station_assist_suffix(event),
		station_wound_suffix(event),
		ship_condition_text(ship),
	]

static func gunnery_damage_text(event: Dictionary) -> String:
	if not bool(event.get("hit", false)):
		return "no damage roll"
	var damage: Dictionary = event.get("damage", {})
	var shield_text := "hull %s + shields %s" % [
		String(event.get("target_hull_pool", "0D")),
		String(event.get("target_shield_pool", "0D")),
	]
	var system_text := ""
	if String(event.get("system_effect", {}).get("key", "none")) != "none":
		system_text = " [%s]" % String(event.get("system_effect", {}).get("name", "System Hit"))
	var passenger_text := ""
	var passenger_damage: Dictionary = event.get("passenger_damage", {})
	if bool(passenger_damage.get("applies", false)):
		passenger_text = " %s take %s." % [
			String(passenger_damage.get("affected_group", "Passengers")).capitalize(),
			String(passenger_damage.get("damage_pool", "0D")),
		]
		passenger_text += crew_wound_text(passenger_damage)
	return "%s vs soak %s (%s) => %s%s.%s" % [
		String(damage.get("damage_roll", {}).get("pool", "0D")),
		String(damage.get("soak_roll", {}).get("pool", "0D")),
		shield_text,
		String(event.get("starship_damage", {}).get("name", "No Damage")),
		system_text,
		passenger_text,
	]

static func gunnery_action_text(event: Dictionary, target_ship: Dictionary = {}, lock_disruption: Dictionary = {}, counterfire: Dictionary = {}, seed: int = 0) -> String:
	var hit_text := "hit" if bool(event.get("hit", false)) else "miss"
	return "Gunnery %d seed %d: %s %d vs %s %d (%s). %s%s%s %s %s%s%s" % [
		int(event.get("gunnery_round", 0)),
		int(event.get("exchange_seed", seed)),
		String(event.get("scaled_attack_pool", "0D")),
		int(event.get("attack_roll", {}).get("total", 0)),
		String(event.get("scaled_defense_pool", "0D")),
		int(event.get("difficulty", 0)),
		hit_text,
		gunnery_damage_text(event),
		station_assist_suffix(event),
		gunnery_station_wound_suffix(event),
		targeting_context_text(event.get("target_sensor_context", {})),
		ship_condition_text(target_ship),
		lock_disruption_text(lock_disruption),
		counterfire_text(counterfire),
	]

static func targeting_context_text(context: Dictionary) -> String:
	if context.is_empty():
		return "Track: Unresolved."
	var name := String(context.get("confidence_name", "Unresolved"))
	var hint := String(context.get("targeting_hint", "No resolved sensor track."))
	if hint.ends_with("."):
		hint = hint.substr(0, hint.length() - 1)
	var modifier := int(context.get("gunnery_difficulty_modifier", 0))
	var modifier_text := " (+%d difficulty)" % modifier if modifier > 0 else ""
	return "Track: %s - %s%s." % [name, hint, modifier_text]

static func lock_disruption_text(lock_disruption: Dictionary) -> String:
	if not bool(lock_disruption.get("applies", false)):
		return ""
	return " Disrupted lock: %d round(s)." % int(lock_disruption.get("prior_rounds", 0))

static func counterfire_text(counterfire: Dictionary) -> String:
	if counterfire.is_empty():
		return ""
	if not bool(counterfire.get("applies", false)):
		var reason := String(counterfire.get("reason", ""))
		if reason == "not_configured":
			return ""
		return " Counterfire: %s." % reason.replace("_", " ")
	var event: Dictionary = counterfire.get("event", {})
	var hit_text := "hit" if bool(event.get("hit", false)) else "miss"
	var damage_text := "no damage"
	if bool(event.get("hit", false)):
		damage_text = String(event.get("starship_damage", {}).get("name", "No Damage"))
	var consumed_text := ""
	var consumed: Dictionary = counterfire.get("consumed_weapon_solution", {})
	if bool(consumed.get("applies", false)):
		consumed_text = " Spent lock: %d round(s)." % int(consumed.get("prior_rounds", 0))
	return " Counterfire: %s %d vs %d (%s), %s.%s %s" % [
		String(event.get("scaled_attack_pool", "0D")),
		int(event.get("attack_roll", {}).get("total", 0)),
		int(event.get("difficulty", 0)),
		hit_text,
		damage_text,
		consumed_text,
		ship_condition_text({"condition": counterfire.get("attacker_condition", {})}),
	]

static func ship_condition_text(ship: Dictionary) -> String:
	if ship.is_empty() or not ship.has("condition"):
		return "Condition: Operational."
	return "Condition: %s." % _condition_summary_text(ship.get("condition", {}))

static func maneuver_hazard_text(hazard_context: Dictionary) -> String:
	var crossed: Array = hazard_context.get("crossed", [])
	if crossed.is_empty():
		return ""
	var modifier := int(hazard_context.get("difficulty_modifier", 0))
	var extra := " +%d" % modifier if modifier != 0 else ""
	return " Hazard: %s%s." % [_hazard_crossing_names(crossed), extra]

static func _hazard_crossing_names(crossed: Array) -> String:
	var names := PackedStringArray()
	for crossed_value in crossed:
		if typeof(crossed_value) != TYPE_DICTIONARY:
			continue
		var hazard: Dictionary = crossed_value
		names.append(String(hazard.get("name", "Hazard")))
		if names.size() >= 2:
			break
	if names.is_empty():
		names.append("Hazard")
	var remaining := crossed.size() - names.size()
	if remaining > 0:
		return "%s +%d more" % [", ".join(names), remaining]
	return ", ".join(names)

static func hazard_detail_text(hazard: Dictionary, route_preview: Dictionary = {}) -> String:
	if hazard.is_empty():
		return "No approach hazard selected."
	var modifier := int(hazard.get("difficulty_modifier", hazard.get("modifier", 0)))
	var modifier_text := " +%d piloting difficulty" % modifier if modifier != 0 else " no piloting modifier"
	var radius := float(hazard.get("radius", 0.0))
	var collision_text := "collision risk" if bool(hazard.get("collision_possible", hazard.get("obstacle_present", true))) else "no collision risk"
	return "Hazard: %s%s, radius %.1f, %s.%s" % [
		String(hazard.get("name", "Approach Hazard")),
		modifier_text,
		radius,
		collision_text,
		_hazard_route_preview_text(hazard, route_preview),
	]

static func _hazard_route_preview_text(hazard: Dictionary, route_preview: Dictionary) -> String:
	if route_preview.is_empty():
		return ""
	var hazard_id := String(hazard.get("id", ""))
	var hazard_name := String(hazard.get("name", ""))
	var crosses := false
	var hazard_context: Dictionary = route_preview.get("hazard_context", {})
	for crossed_value in hazard_context.get("crossed", []):
		if typeof(crossed_value) != TYPE_DICTIONARY:
			continue
		var crossed: Dictionary = crossed_value
		if hazard_id != "" and String(crossed.get("id", "")) == hazard_id:
			crosses = true
			break
		if hazard_id == "" and hazard_name != "" and String(crossed.get("name", "")) == hazard_name:
			crosses = true
			break
	var route_text := "crosses" if crosses else "avoids"
	return " Current maneuver %s this hazard; total difficulty %d." % [
		route_text,
		int(route_preview.get("difficulty", 0)),
	]

static func crew_wound_text(passenger_damage: Dictionary) -> String:
	var member_wounds: Array = passenger_damage.get("member_wounds", [])
	if member_wounds.is_empty():
		return ""
	var first: Dictionary = member_wounds[0]
	return " %s: %s." % [
		String(first.get("name", "Crew")),
		String(first.get("wound", {}).get("name", "No Damage")),
	]

static func maneuver_collision_text(collision: Dictionary) -> String:
	if bool(collision.get("applies", false)):
		return " Collision %s vs hull %s => %s.%s" % [
			String(collision.get("damage_pool", "0D")),
			String(collision.get("hull_soak_pool", "0D")),
			String(collision.get("starship_damage", {}).get("name", "No Damage")),
			crew_wound_text(collision.get("passenger_damage", {})),
		]
	if String(collision.get("reason", "")) == "wild_spin_no_obstacle":
		return " No obstacle: wild spin."
	return ""

static func weapon_solution_break_text(event: Dictionary) -> String:
	var broken_count := int(event.get("weapon_solutions_broken", 0))
	if broken_count <= 0:
		return ""
	return " Broke %d weapon solution(s)." % broken_count

static func sensor_sweep_text(result: Dictionary, contacts: Array, seed: int) -> String:
	var names := PackedStringArray()
	var confidence_names := PackedStringArray()
	for event in result.get("events", []):
		if typeof(event) == TYPE_DICTIONARY and bool(event.get("success", false)):
			names.append(String(event.get("contact_name", "Contact")))
			confidence_names.append("%s %s" % [
				String(event.get("contact_name", "Contact")),
				String(event.get("confidence_name", "Contact")),
			])
	var revealed_text := "none" if names.is_empty() else ", ".join(names)
	var confidence_text := "" if confidence_names.is_empty() else " Track: %s." % ", ".join(confidence_names)
	var new_text := newly_revealed_text(result.get("newly_revealed_contacts", []), contacts)
	var count_text := contact_count_text(result.get("state", {}), contacts)
	return "Sensor sweep %d seed %d: %s %d => %s.%s%s %s%s%s" % [
		int(result.get("scan_round", 0)),
		seed,
		String(result.get("roll", {}).get("pool", "0D")),
		int(result.get("roll", {}).get("total", 0)),
		revealed_text,
		confidence_text,
		new_text,
		count_text,
		station_assist_suffix(result),
		station_wound_suffix(result),
	]

static func traffic_tick_text(result: Dictionary, auto_tick: bool = false) -> String:
	var moved_names := PackedStringArray()
	var holding_names := PackedStringArray()
	var lock_names := PackedStringArray()
	var blocked_names := PackedStringArray()
	for event in result.get("events", []):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if not bool(event.get("can_move", false)):
			var blocked_reason := String(event.get("movement_blocked_reason", ""))
			if blocked_reason != "" and blocked_reason != "no_movement_profile":
				blocked_names.append("%s %s" % [
					String(event.get("contact_name", "Contact")),
					blocked_reason.replace("_", " "),
				])
			continue
		if bool(event.get("holds_range", false)):
			holding_names.append(String(event.get("contact_name", "Contact")))
		else:
			moved_names.append(String(event.get("contact_name", "Contact")))
		if bool(event.get("weapon_solution", false)):
			var ready_text := "ready" if bool(event.get("fire_ready", false)) else "%d/%d" % [
				int(event.get("weapon_solution_rounds", 0)),
				int(event.get("fire_ready_rounds", 1)),
			]
			var engagement_context: Dictionary = event.get("engagement_context", {})
			var track_context: Dictionary = engagement_context.get("targeting", event.get("targeting_context", {}))
			lock_names.append("%s %s %s track %s" % [
				String(event.get("contact_name", "Contact")),
				String(event.get("range_name", "Unknown")),
				ready_text,
				String(track_context.get("confidence_name", "Unresolved")),
			])
	var moved_text := "none" if moved_names.is_empty() else ", ".join(moved_names)
	var holding_text := "" if holding_names.is_empty() else " Holding range: %s." % ", ".join(holding_names)
	var lock_text := "" if lock_names.is_empty() else " Weapon solution: %s." % ", ".join(lock_names)
	var blocked_text := "" if blocked_names.is_empty() else " Blocked: %s." % ", ".join(blocked_names)
	var ready_fire_text := ready_hostile_fire_text(result.get("ready_hostile_fire_events", []))
	var automatic_fire_text := automatic_hostile_fire_text(result.get("automatic_hostile_fire_events", []))
	var traffic_prefix := "Live traffic" if auto_tick else "Traffic"
	return "%s %d: moved %s.%s%s%s%s%s%s" % [
		traffic_prefix,
		int(result.get("movement_round", 0)),
		moved_text,
		holding_text,
		lock_text,
		blocked_text,
		ready_fire_text,
		automatic_fire_text,
		_condition_tick_summary(result.get("condition_events", [])),
	]

static func ready_hostile_fire_text(ready_events: Array) -> String:
	var parts := PackedStringArray()
	for event_value in ready_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		var targeting: Dictionary = event.get("targeting_context", {})
		parts.append("%s %s %d/%d track %s" % [
			String(event.get("contact_name", "Contact")),
			String(event.get("range_name", "Unknown")),
			int(event.get("weapon_solution_rounds", 0)),
			int(event.get("fire_ready_rounds", 1)),
			String(targeting.get("confidence_name", "Unresolved")),
		])
	if parts.is_empty():
		return ""
	return " Ready hostile fire: %s." % ", ".join(parts)

static func automatic_hostile_fire_text(fire_events: Array) -> String:
	var parts := PackedStringArray()
	for event_value in fire_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var fire_event: Dictionary = event_value
		var contact_name := String(fire_event.get("contact_name", "Contact"))
		if not bool(fire_event.get("applies", false)):
			var reason := String(fire_event.get("reason", "blocked")).replace("_", " ")
			var blocked_consumed_text := ""
			var blocked_consumed: Dictionary = fire_event.get("consumed_weapon_solution", {})
			if bool(blocked_consumed.get("applies", false)):
				blocked_consumed_text = ", cleared %d" % int(blocked_consumed.get("prior_rounds", 0))
			parts.append("%s blocked: %s%s" % [contact_name, reason, blocked_consumed_text])
			continue
		var event: Dictionary = fire_event.get("event", {})
		var hit_text := "hit" if bool(event.get("hit", false)) else "miss"
		var damage_text := "no damage"
		if bool(event.get("hit", false)):
			damage_text = String(event.get("starship_damage", {}).get("name", "No Damage"))
		var consumed_text := ""
		var consumed: Dictionary = fire_event.get("consumed_weapon_solution", {})
		if bool(consumed.get("applies", false)):
			consumed_text = ", spent %d" % int(consumed.get("prior_rounds", 0))
		var condition_text := ship_condition_text({"condition": fire_event.get("player_condition", {})})
		if condition_text.ends_with("."):
			condition_text = condition_text.substr(0, condition_text.length() - 1)
		parts.append("%s %d vs %d %s, %s%s, %s" % [
			contact_name,
			int(event.get("attack_roll", {}).get("total", 0)),
			int(event.get("difficulty", 0)),
			hit_text,
			damage_text,
			consumed_text,
			condition_text,
		])
	if parts.is_empty():
		return ""
	return " Hostile fire: %s." % ", ".join(parts)

static func newly_revealed_text(newly_revealed_ids: Array, contacts: Array) -> String:
	if newly_revealed_ids.is_empty():
		return ""
	var names := PackedStringArray()
	for contact_id_value in newly_revealed_ids:
		var contact_id := String(contact_id_value)
		names.append(_contact_name_for_id(contact_id, contacts))
	if names.is_empty():
		return ""
	return " New: %s." % ", ".join(names)

static func contact_count_text(state: Dictionary, contacts: Array) -> String:
	var revealed: Array = state.get("revealed_contacts", [])
	var known_count := _known_contact_count(contacts, revealed)
	var hidden_count := _hidden_contact_count(contacts, revealed)
	return "Known %d/%d, hidden %d." % [known_count, contacts.size(), hidden_count]

static func contact_confidence_label(state: Dictionary, contact_id: String) -> String:
	var confidence_by_contact: Dictionary = state.get("sensor_contact_confidence", {})
	var confidence: Dictionary = confidence_by_contact.get(contact_id, {})
	if confidence.is_empty():
		return ""
	return " | Track: %s" % String(confidence.get("name", "Contact"))

static func contact_identification_label(state: Dictionary, contact_id: String) -> String:
	var identified_by_contact: Dictionary = state.get("identified_contacts", {})
	var identity: Dictionary = identified_by_contact.get(contact_id, {})
	if identity.is_empty():
		return ""
	var name := String(identity.get("declared_name", "Contact"))
	var affiliation := String(identity.get("affiliation", "unknown"))
	var threat := String(identity.get("threat", "unknown"))
	return " | ID: %s/%s/%s" % [name, affiliation, threat]

static func contact_disposition_label(state: Dictionary, contact_id: String) -> String:
	var dispositions: Dictionary = state.get("contact_dispositions", {})
	var disposition: Dictionary = dispositions.get(contact_id, {})
	if disposition.is_empty():
		return ""
	var delay: Dictionary = disposition.get("weapon_solution_delay", {})
	var pressure: Dictionary = disposition.get("weapon_solution_pressure", {})
	var delay_text := ""
	if bool(delay.get("applies", false)):
		delay_text = " (lock %d->%d)" % [
			int(delay.get("prior_rounds", 0)),
			int(delay.get("remaining_rounds", 0)),
		]
	elif bool(pressure.get("applies", false)):
		var ready_suffix := " ready" if bool(pressure.get("fire_ready", false)) else ""
		delay_text = " (lock %d->%d%s)" % [
			int(pressure.get("prior_rounds", 0)),
			int(pressure.get("current_rounds", 0)),
			ready_suffix,
		]
	return " | Comms: %s%s" % [String(disposition.get("status", "unknown")).capitalize(), delay_text]

static func contact_visual_label_text(contact: Dictionary, state: Dictionary, contact_id: String = "") -> String:
	var resolved_contact_id := contact_id
	if resolved_contact_id == "":
		resolved_contact_id = String(contact.get("id", ""))
	var revealed: Array = state.get("revealed_contacts", [])
	var hidden := bool(contact.get("hidden_until_revealed", false)) and not revealed.has(resolved_contact_id)
	if hidden:
		return "Unresolved return - %s" % String(contact.get("status", "unknown"))
	return "%s - %s%s" % [
		String(contact.get("name", "Contact")),
		String(contact.get("status", "")),
		contact_confidence_label(state, resolved_contact_id) + contact_identification_label(state, resolved_contact_id) + contact_disposition_label(state, resolved_contact_id),
	]

static func selected_contact_text(contact: Dictionary, state: Dictionary, contact_id: String = "") -> String:
	if contact.is_empty():
		return "Target: none selected"
	return "Target: %s" % contact_visual_label_text(contact, state, contact_id)

static func selected_contact_action_text(contact: Dictionary, state: Dictionary, contact_id: String = "") -> String:
	if contact.is_empty():
		return "Selected target: none."
	return "Selected target: %s." % contact_visual_label_text(contact, state, contact_id)

static func selected_contact_lock_label(state: Dictionary, contact: Dictionary, contact_id: String = "") -> String:
	if contact.is_empty():
		return ""
	var resolved_contact_id := contact_id
	if resolved_contact_id == "":
		resolved_contact_id = String(contact.get("id", ""))
	if resolved_contact_id == "":
		return ""
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	var count := int(counts.get(resolved_contact_id, 0))
	if count <= 0:
		return ""
	var movement: Dictionary = contact.get("movement", {})
	var required := maxi(int(movement.get("fire_ready_rounds", movement.get("lock_rounds_to_fire", 2))), 1)
	var ready_text := "ready" if count >= required else "%d/%d" % [count, required]
	var range_text := _selected_contact_lock_range_text(state, contact, resolved_contact_id)
	if range_text != "":
		return "Lock: %s %s" % [ready_text, range_text]
	return "Lock: %s" % ready_text

static func selected_contact_detail_text(contact: Dictionary, state: Dictionary, contact_id: String = "", targeting_context: Dictionary = {}) -> String:
	if contact.is_empty():
		return "Target: none selected"
	var resolved_contact_id := contact_id
	if resolved_contact_id == "":
		resolved_contact_id = String(contact.get("id", ""))
	var revealed: Array = state.get("revealed_contacts", [])
	var hidden := bool(contact.get("hidden_until_revealed", false)) and not revealed.has(resolved_contact_id)
	var parts := PackedStringArray()
	parts.append("Unresolved return" if hidden else String(contact.get("name", "Contact")))
	var status := String(contact.get("status", ""))
	if status != "":
		parts.append("Status: %s" % status)
	var scale_label := selected_contact_scale_label(contact)
	if scale_label != "":
		parts.append(scale_label)
	var confidence_label := _trimmed_contact_label(contact_confidence_label(state, resolved_contact_id))
	if confidence_label != "":
		parts.append(confidence_label)
	var defense_label := selected_contact_defense_label(contact)
	if defense_label != "":
		parts.append(defense_label)
	var soak_label := selected_contact_soak_label(contact)
	if soak_label != "":
		parts.append(soak_label)
	var weapon_label := selected_contact_weapon_label(contact)
	if weapon_label != "":
		parts.append(weapon_label)
	var crew_label := selected_contact_crew_label(contact)
	if crew_label != "":
		parts.append(crew_label)
	var systems_label := selected_contact_systems_label(contact)
	if systems_label != "":
		parts.append(systems_label)
	if not hidden:
		var id_label := _trimmed_contact_label(contact_identification_label(state, resolved_contact_id))
		if id_label != "":
			parts.append(id_label)
		var comms_label := _trimmed_contact_label(contact_disposition_label(state, resolved_contact_id))
		if comms_label != "":
			parts.append(comms_label)
	var cue_label := selected_contact_bridge_cue_label(contact, state, resolved_contact_id, targeting_context)
	if cue_label != "":
		parts.append(cue_label)
	var lock_label := selected_contact_lock_label(state, contact, resolved_contact_id)
	if lock_label != "":
		parts.append(lock_label)
	var movement_label := selected_contact_movement_label(state, contact, resolved_contact_id)
	if movement_label != "":
		parts.append(movement_label)
	var fire_posture_label := selected_contact_fire_posture_label(state, contact, resolved_contact_id)
	if fire_posture_label != "":
		parts.append(fire_posture_label)
	var counterfire_label := selected_contact_counterfire_label(contact)
	if counterfire_label != "":
		parts.append(counterfire_label)
	var targeting_label := selected_contact_targeting_label(targeting_context)
	if targeting_label != "":
		parts.append(targeting_label)
	var repair_label := selected_contact_repair_label(contact)
	if repair_label != "":
		parts.append(repair_label)
	if contact.has("condition"):
		parts.append("Condition: %s" % _condition_summary_text(contact.get("condition", {})).replace(" | ", ", "))
	return "Target: %s" % " | ".join(parts)

static func selected_contact_movement_label(state: Dictionary, contact: Dictionary, contact_id: String = "") -> String:
	if contact.is_empty():
		return ""
	var resolved_contact_id := contact_id
	if resolved_contact_id == "":
		resolved_contact_id = String(contact.get("id", ""))
	if resolved_contact_id == "":
		return ""
	var event := _latest_movement_event_for_contact(state, resolved_contact_id)
	if event.is_empty():
		return _movement_profile_label(contact)
	if event.has("can_move") and not bool(event.get("can_move", false)):
		var blocked_reason := String(event.get("movement_blocked_reason", "")).strip_edges()
		if blocked_reason == "" or blocked_reason == "no_movement_profile":
			return _movement_profile_label(contact)
		return "Movement: blocked - %s" % blocked_reason.replace("_", " ")
	if not event.has("can_move"):
		return ""
	var range_name := String(event.get("range_name", "")).strip_edges()
	var range_text := "" if range_name == "" or range_name == "Unknown" else " %s" % range_name
	if bool(event.get("holds_range", false)):
		if bool(event.get("tracks_focus", false)):
			return "Movement: holding%s while tracking player" % range_text
		return "Movement: holding%s" % range_text
	var move_units := float(event.get("move_units", 0.0))
	if bool(event.get("tracks_focus", false)):
		return "Movement: tracking player, closing%s at %s units" % [range_text, _compact_float(move_units)]
	if move_units > 0.0:
		return "Movement: course %d deg, moving %s units" % [
			int(round(float(event.get("heading_degrees", contact.get("heading_degrees", 0.0))))),
			_compact_float(move_units),
		]
	return _movement_profile_label(contact)

static func selected_contact_targeting_label(targeting_context: Dictionary) -> String:
	if targeting_context.is_empty() or not bool(targeting_context.get("sensor_targeting_required", false)):
		return ""
	var modifier := int(targeting_context.get("gunnery_difficulty_modifier", 0))
	if modifier > 0:
		return "Targeting: +%d difficulty" % modifier
	return "Targeting: clean track"

static func selected_contact_bridge_cue_label(contact: Dictionary, state: Dictionary, contact_id: String = "", targeting_context: Dictionary = {}) -> String:
	if contact.is_empty():
		return ""
	var resolved_contact_id := contact_id
	if resolved_contact_id == "":
		resolved_contact_id = String(contact.get("id", ""))
	var condition: Dictionary = contact.get("condition", {})
	if bool(condition.get("destroyed", false)):
		return "Cue: target neutralized"
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	var lock_count := int(counts.get(resolved_contact_id, 0))
	var weapons_offline := bool(condition.get("weapons_disabled", false)) or int(condition.get("controls_ionized", 0)) >= 99
	if bool(contact.get("counterfire", false)) and lock_count > 0 and not weapons_offline:
		var movement: Dictionary = contact.get("movement", {})
		var required := maxi(int(movement.get("fire_ready_rounds", movement.get("lock_rounds_to_fire", 2))), 1)
		if lock_count >= required:
			return "Cue: evade or return fire [L/B]"
		return "Cue: disrupt weapon solution [B/L]"
	var revealed: Array = state.get("revealed_contacts", [])
	var hidden := bool(contact.get("hidden_until_revealed", false)) and not revealed.has(resolved_contact_id)
	var confidence_by_contact: Dictionary = state.get("sensor_contact_confidence", {})
	var has_track := confidence_by_contact.has(resolved_contact_id)
	if hidden and not has_track:
		return "Cue: sweep sensors [N]"
	var targeting_modifier := int(targeting_context.get("gunnery_difficulty_modifier", 0))
	if bool(targeting_context.get("sensor_targeting_required", false)) and targeting_modifier >= 6:
		return "Cue: improve sensor track [N]"
	var identified_by_contact: Dictionary = state.get("identified_contacts", {})
	if not identified_by_contact.has(resolved_contact_id) and (has_track or bool(contact.get("hidden_until_revealed", false)) or contact.has("transponder")):
		return "Cue: identify contact [I]"
	var dispositions: Dictionary = state.get("contact_dispositions", {})
	if identified_by_contact.has(resolved_contact_id) and not dispositions.has(resolved_contact_id) and contact.has("comms"):
		return "Cue: hail contact [X]"
	if selected_contact_repair_label(contact) != "":
		return "Cue: damage control [K]"
	if bool(targeting_context.get("sensor_targeting_required", false)) and targeting_modifier > 0:
		return "Cue: improve sensor track [N]"
	return ""

static func local_ship_bridge_cue_label(ship: Dictionary) -> String:
	if ship.is_empty():
		return ""
	var condition: Dictionary = ship.get("condition", {})
	if bool(condition.get("destroyed", false)):
		return "Cue: abandon ship"
	if _field_repairable_system_count(ship) > 0:
		return "Cue: local damage control [K]"
	return ""

static func bridge_cue_label(contact: Dictionary, state: Dictionary, player_ship: Dictionary = {}, contact_id: String = "", targeting_context: Dictionary = {}) -> String:
	var local_cue := local_ship_bridge_cue_label(player_ship)
	if local_cue == "Cue: abandon ship":
		return local_cue
	if not contact.is_empty():
		var contact_cue := selected_contact_bridge_cue_label(contact, state, contact_id, targeting_context)
		if contact_cue != "":
			return contact_cue
	return local_cue

static func selected_contact_scale_label(contact: Dictionary) -> String:
	var scale := String(contact.get("scale", "")).strip_edges()
	if scale == "":
		return ""
	return "Scale: %s" % scale.replace("_", " ").capitalize()

static func selected_contact_defense_label(contact: Dictionary) -> String:
	if contact.is_empty():
		return ""
	var condition: Dictionary = contact.get("condition", {})
	if bool(condition.get("destroyed", false)):
		return "Defense: destroyed"
	if bool(condition.get("drives_disabled", false)):
		return "Defense: no defensive maneuver (drives offline)"
	if int(condition.get("controls_ionized", 0)) >= 99:
		return "Defense: no defensive maneuver (controls dead)"
	var defense_pool := String(contact.get("defense_pool", contact.get("maneuverability", ""))).strip_edges()
	if defense_pool == "":
		return ""
	var penalties := PackedStringArray()
	var controls := int(condition.get("controls_ionized", 0))
	if controls > 0:
		penalties.append("-%dD controls" % controls)
	var maneuver_loss := int(condition.get("maneuverability_loss_dice", 0))
	if maneuver_loss > 0:
		penalties.append("-%dD maneuver" % maneuver_loss)
	if penalties.is_empty():
		return "Defense: %s" % defense_pool
	return "Defense: %s (%s)" % [defense_pool, ", ".join(penalties)]

static func selected_contact_soak_label(contact: Dictionary) -> String:
	if contact.is_empty():
		return ""
	var condition: Dictionary = contact.get("condition", {})
	if bool(condition.get("destroyed", false)):
		return "Soak: destroyed"
	var hull_pool := String(contact.get("hull", "")).strip_edges()
	var shield_text := _selected_contact_shield_text(contact)
	if hull_pool == "" and shield_text == "":
		return ""
	var parts := PackedStringArray()
	if hull_pool != "":
		parts.append("hull %s" % hull_pool)
	if shield_text != "":
		parts.append("shields %s%s" % [shield_text, _selected_contact_shield_penalty_text(condition)])
	return "Soak: %s" % ", ".join(parts)

static func selected_contact_weapon_label(contact: Dictionary) -> String:
	if contact.is_empty():
		return ""
	var condition: Dictionary = contact.get("condition", {})
	if bool(condition.get("destroyed", false)):
		return "Weapons: destroyed"
	if bool(condition.get("weapons_disabled", false)):
		return "Weapons: offline"
	if int(condition.get("controls_ionized", 0)) >= 99:
		return "Weapons: controls dead"
	var parts := PackedStringArray()
	var gunnery_pool := String(contact.get("gunnery_pool", "")).strip_edges()
	if gunnery_pool != "":
		parts.append("gunnery %s" % gunnery_pool)
	var fire_control := String(contact.get("fire_control", "")).strip_edges()
	if fire_control != "":
		parts.append("fire control %s" % fire_control)
	var weapon_damage := String(contact.get("weapon_damage", "")).strip_edges()
	if weapon_damage != "":
		parts.append("damage %s" % weapon_damage)
	if parts.is_empty():
		if bool(contact.get("counterfire", false)):
			return "Weapons: armed"
		return ""
	var controls := int(condition.get("controls_ionized", 0))
	var penalty_text := ""
	if controls > 0:
		penalty_text = " (-%dD controls)" % controls
	return "Weapons: %s%s" % [", ".join(parts), penalty_text]

static func selected_contact_crew_label(contact: Dictionary) -> String:
	if contact.is_empty():
		return ""
	var condition: Dictionary = contact.get("condition", {})
	var crew_wounds: Dictionary = condition.get("crew_wounds", {})
	if crew_wounds.is_empty():
		return ""
	var crew_ids: Array = crew_wounds.keys()
	crew_ids.sort()
	var entries := PackedStringArray()
	for crew_id_value in crew_ids:
		var crew_id := String(crew_id_value)
		var packet: Dictionary = crew_wounds.get(crew_id, {})
		var wound: Dictionary = packet.get("wound", {})
		var wound_name := String(wound.get("name", packet.get("wound_name", ""))).strip_edges()
		var severity := int(wound.get("severity", packet.get("severity", -1)))
		if wound_name == "" or wound_name.to_lower() == "no damage" or severity < 0:
			continue
		var name := String(packet.get("name", _crew_roster_name(contact, crew_id))).strip_edges()
		if name == "":
			name = crew_id
		var station := String(packet.get("station", _crew_roster_station(contact, crew_id))).strip_edges()
		if station != "":
			entries.append("%s %s (%s)" % [name, wound_name, station])
		else:
			entries.append("%s %s" % [name, wound_name])
	if entries.is_empty():
		return ""
	return "Crew: %s" % ", ".join(entries)

static func selected_contact_systems_label(contact: Dictionary) -> String:
	if contact.is_empty():
		return ""
	var condition: Dictionary = contact.get("condition", {})
	if condition.is_empty():
		return ""
	if bool(condition.get("destroyed", false)):
		return "Systems: destroyed"
	var parts := PackedStringArray()
	var move_loss := int(condition.get("move_loss", 0))
	if move_loss > 0:
		parts.append("Move -%d" % move_loss)
	if bool(condition.get("hyperdrive_disabled", false)):
		parts.append("hyperdrive offline")
	if int(condition.get("hyperdrive_calculation_penalty", 0)) > 0:
		parts.append("hyperdrive calculations slowed")
	if int(condition.get("astrogation_difficulty_penalty", 0)) > 0:
		parts.append("astrogation +%d" % int(condition.get("astrogation_difficulty_penalty", 0)))
	if bool(condition.get("generator_overloading", false)):
		parts.append("generator overloading")
	if bool(condition.get("structural_damage", false)):
		parts.append("structural damage")
	if parts.is_empty():
		return ""
	return "Systems: %s" % ", ".join(parts)

static func selected_contact_fire_posture_label(state: Dictionary, contact: Dictionary, contact_id: String = "") -> String:
	if contact.is_empty():
		return ""
	var resolved_contact_id := contact_id
	if resolved_contact_id == "":
		resolved_contact_id = String(contact.get("id", ""))
	if resolved_contact_id == "":
		return ""
	if not bool(contact.get("counterfire", false)):
		return ""
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	var count := int(counts.get(resolved_contact_id, 0))
	var condition: Dictionary = contact.get("condition", {})
	if bool(condition.get("destroyed", false)):
		return "Fire posture: destroyed"
	if bool(condition.get("weapons_disabled", false)):
		return "Fire posture: weapons offline"
	var movement: Dictionary = contact.get("movement", {})
	var required := maxi(int(movement.get("fire_ready_rounds", movement.get("lock_rounds_to_fire", 2))), 1)
	if bool(contact.get("counterfire_requires_solution", false)) or count > 0:
		if count <= 0:
			return "Fire posture: acquiring solution"
		if count < required:
			return "Fire posture: solution %d/%d" % [count, required]
		return "Fire posture: ready to fire"
	return "Fire posture: armed"

static func selected_contact_counterfire_label(contact: Dictionary) -> String:
	if contact.is_empty():
		return ""
	if not bool(contact.get("counterfire", false)):
		return ""
	var condition: Dictionary = contact.get("condition", {})
	if bool(condition.get("destroyed", false)):
		return "Counterfire: destroyed"
	if bool(condition.get("weapons_disabled", false)):
		return "Counterfire: weapons offline"
	if bool(contact.get("counterfire_requires_solution", false)):
		return "Counterfire: lock-gated"
	return "Counterfire: armed"

static func selected_contact_repair_label(contact: Dictionary) -> String:
	var condition: Dictionary = contact.get("condition", {})
	if condition.is_empty() or bool(condition.get("destroyed", false)):
		return ""
	var repairable := _repairable_system_names(condition)
	if repairable.is_empty():
		return ""
	var labeled := PackedStringArray()
	for system_name in repairable:
		labeled.append(_repairable_system_label(contact, condition, system_name))
	return "Repair: %s" % ", ".join(labeled)

static func _repairable_system_label(contact: Dictionary, condition: Dictionary, system_name: String) -> String:
	var system_key := _normalize_system_name(system_name)
	var override_difficulty := _repair_difficulty_override(contact, condition, system_key)
	if override_difficulty == REPAIR_DIFFICULTY_OVERRIDE_MISSING:
		return system_key
	var difficulty_name := "Yard Only" if override_difficulty < 0 else String(REPAIR_DIFFICULTY_NAMES.get(override_difficulty, "Difficulty %d" % override_difficulty))
	return "%s (%s)" % [system_key, difficulty_name]

static func _repair_difficulty_override(contact: Dictionary, condition: Dictionary, system_key: String) -> int:
	var tables := [
		condition.get("repair_difficulties", {}),
		condition.get("system_repair_difficulties", {}),
		contact.get("repair_difficulties", {}),
		contact.get("system_repair_difficulties", {}),
	]
	for table in tables:
		if typeof(table) != TYPE_DICTIONARY:
			continue
		var parsed := _repair_difficulty_from_table(table, system_key)
		if parsed != REPAIR_DIFFICULTY_OVERRIDE_MISSING:
			return parsed
	return REPAIR_DIFFICULTY_OVERRIDE_MISSING

static func _repair_difficulty_from_table(table: Dictionary, system_key: String) -> int:
	for raw_key in table.keys():
		if _normalize_system_name(String(raw_key)) != system_key:
			continue
		return _repair_difficulty_value(table.get(raw_key))
	return REPAIR_DIFFICULTY_OVERRIDE_MISSING

static func _repair_difficulty_value(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return int(round(float(value)))
		TYPE_STRING:
			var text := String(value).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
			if text.is_valid_int():
				return int(text)
			match text:
				"easy":
					return REPAIR_DIFFICULTIES["easy"]
				"moderate":
					return REPAIR_DIFFICULTIES["moderate"]
				"difficult":
					return REPAIR_DIFFICULTIES["difficult"]
				"very_difficult":
					return REPAIR_DIFFICULTIES["very_difficult"]
				"yard_only", "yard", "unrepairable", "destroyed":
					return -1
	return REPAIR_DIFFICULTY_OVERRIDE_MISSING

static func _normalize_system_name(system_name: String) -> String:
	return system_name.strip_edges().to_lower().replace(" ", "_")

static func _trimmed_contact_label(label: String) -> String:
	if label == "":
		return ""
	return label.substr(3) if label.begins_with(" | ") else label

static func _selected_contact_lock_range_text(state: Dictionary, contact: Dictionary, contact_id: String) -> String:
	var direct_range := String(contact.get("range_name", contact.get("engagement_range_name", ""))).strip_edges()
	if direct_range != "":
		return direct_range
	var movement: Dictionary = contact.get("movement", {})
	var movement_range := String(movement.get("range_name", movement.get("engagement_range_name", ""))).strip_edges()
	if movement_range != "":
		return movement_range
	for event_value in state.get("last_contact_movement_events", []):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if String(event.get("contact_id", "")) != contact_id:
			continue
		var event_range := String(event.get("range_name", "")).strip_edges()
		if event_range != "":
			return event_range
	return ""

static func _latest_movement_event_for_contact(state: Dictionary, contact_id: String) -> Dictionary:
	var event_sources := [
		state.get("last_contact_movement_events", []),
		state.get("last_movement_events", []),
	]
	for events in event_sources:
		if typeof(events) != TYPE_ARRAY:
			continue
		for i in range(events.size() - 1, -1, -1):
			var event_value: Variant = events[i]
			if typeof(event_value) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_value
			if String(event.get("contact_id", "")) == contact_id:
				return event
	return {}

static func _movement_profile_label(contact: Dictionary) -> String:
	var movement: Dictionary = contact.get("movement", {})
	if movement.is_empty():
		return ""
	var track_target := String(movement.get("track_target", "")).strip_edges().to_lower()
	var move_units := float(movement.get("move_units", movement.get("speed_units", 0.0)))
	if track_target == "player":
		if float(movement.get("hold_range", movement.get("engagement_range", -1.0))) >= 0.0:
			return "Movement: tracking player, hold range armed"
		return "Movement: tracking player"
	if move_units > 0.0:
		return "Movement: patrol course, moving %s units" % _compact_float(move_units)
	return ""

static func _selected_contact_shield_text(contact: Dictionary) -> String:
	var shield_arcs: Dictionary = contact.get("shield_arcs", {})
	if not shield_arcs.is_empty():
		var arc_parts := PackedStringArray()
		for arc_name in ["front", "rear", "left", "right", "all"]:
			if not shield_arcs.has(arc_name):
				continue
			var pool := String(shield_arcs.get(arc_name, "")).strip_edges()
			if pool != "":
				arc_parts.append("%s %s" % [arc_name, pool])
		if not arc_parts.is_empty():
			return ", ".join(arc_parts)
	return String(contact.get("shields", "")).strip_edges()

static func _selected_contact_shield_penalty_text(condition: Dictionary) -> String:
	var penalties := PackedStringArray()
	var shield_loss := int(condition.get("shield_loss_dice", 0))
	if shield_loss > 0:
		penalties.append("-%dD shields" % shield_loss)
	var controls := int(condition.get("controls_ionized", 0))
	if controls > 0 and controls < 99:
		penalties.append("-%dD controls" % controls)
	if penalties.is_empty():
		return ""
	return " (%s)" % ", ".join(penalties)

static func _crew_roster_name(contact: Dictionary, crew_id: String) -> String:
	var member := _crew_roster_member(contact, crew_id)
	return String(member.get("name", ""))

static func _crew_roster_station(contact: Dictionary, crew_id: String) -> String:
	var member := _crew_roster_member(contact, crew_id)
	return String(member.get("station", member.get("role", "")))

static func _crew_roster_member(contact: Dictionary, crew_id: String) -> Dictionary:
	var crew: Array = contact.get("crew", contact.get("crew_roster", contact.get("occupants", [])))
	for member_value in crew:
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_value
		if String(member.get("id", member.get("name", ""))) == crew_id:
			return member
	return {}

static func _compact_float(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))
	return "%.1f" % value

static func _contact_name_for_id(contact_id: String, contacts: Array) -> String:
	for contact in contacts:
		if typeof(contact) == TYPE_DICTIONARY and String(contact.get("id", "")) == contact_id:
			return String(contact.get("name", contact_id))
	return contact_id

static func _known_contact_count(contacts: Array, revealed: Array) -> int:
	var known_count := 0
	for contact in contacts:
		if typeof(contact) != TYPE_DICTIONARY:
			continue
		var contact_id := String(contact.get("id", ""))
		if not bool(contact.get("hidden_until_revealed", false)) or revealed.has(contact_id):
			known_count += 1
	return known_count

static func _hidden_contact_count(contacts: Array, revealed: Array) -> int:
	var hidden_count := 0
	for contact in contacts:
		if typeof(contact) != TYPE_DICTIONARY:
			continue
		var contact_id := String(contact.get("id", ""))
		if bool(contact.get("hidden_until_revealed", false)) and not revealed.has(contact_id):
			hidden_count += 1
	return hidden_count

static func _lock_text(state: Dictionary, contacts: Array) -> String:
	var movement_event_text := _movement_event_lock_text(state)
	if movement_event_text != "":
		return movement_event_text
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	var confidence_by_contact: Dictionary = state.get("sensor_contact_confidence", {})
	var parts := PackedStringArray()
	for contact in contacts:
		if typeof(contact) != TYPE_DICTIONARY or not bool(contact.get("counterfire", false)):
			continue
		var contact_id := String(contact.get("id", ""))
		if contact_id == "":
			continue
		var count := int(counts.get(contact_id, 0))
		if count <= 0:
			continue
		var movement: Dictionary = contact.get("movement", {})
		var required := maxi(int(movement.get("fire_ready_rounds", movement.get("lock_rounds_to_fire", 2))), 1)
		var ready_text := "ready" if count >= required else "%d/%d" % [count, required]
		parts.append("%s %s%s" % [
			String(contact.get("name", contact_id)),
			ready_text,
			_fallback_track_text(confidence_by_contact.get(contact_id, {})),
		])
	if parts.is_empty():
		return "none"
	return ", ".join(parts)

static func _fallback_track_text(confidence: Dictionary) -> String:
	if confidence.is_empty():
		return ""
	return " track %s" % String(confidence.get("name", "Unresolved"))

static func _movement_event_lock_text(state: Dictionary) -> String:
	var parts := PackedStringArray()
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	for event in state.get("last_movement_events", []):
		if typeof(event) != TYPE_DICTIONARY or not bool(event.get("weapon_solution", false)):
			continue
		var contact_id := String(event.get("contact_id", ""))
		if contact_id == "" or int(counts.get(contact_id, 0)) <= 0:
			continue
		var context: Dictionary = event.get("engagement_context", {})
		var targeting: Dictionary = context.get("targeting", event.get("targeting_context", {}))
		var solution: Dictionary = context.get("weapon_solution", event.get("weapon_solution_context", {}))
		var rounds := int(solution.get("rounds", event.get("weapon_solution_rounds", 0)))
		var required := maxi(int(solution.get("required_rounds", event.get("fire_ready_rounds", 1))), 1)
		var ready := bool(solution.get("ready", event.get("fire_ready", false)))
		var ready_text := "ready" if ready else "%d/%d" % [rounds, required]
		var track_name := String(targeting.get("confidence_name", "Unresolved"))
		parts.append("%s %s track %s" % [
			String(event.get("contact_name", event.get("contact_id", "Contact"))),
			ready_text,
			track_name,
		])
	if parts.is_empty():
		return ""
	return ", ".join(parts)

static func _automatic_hostile_fire_summary(state: Dictionary) -> String:
	var parts := PackedStringArray()
	for event_value in state.get("last_automatic_hostile_fire_events", []):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var fire_event: Dictionary = event_value
		var contact_name := String(fire_event.get("contact_name", "Contact"))
		if not bool(fire_event.get("applies", false)):
			var reason := String(fire_event.get("reason", "blocked")).replace("_", " ")
			var blocked_consumed_text := ""
			var blocked_consumed: Dictionary = fire_event.get("consumed_weapon_solution", {})
			if bool(blocked_consumed.get("applies", false)):
				blocked_consumed_text = " cleared %d" % int(blocked_consumed.get("prior_rounds", 0))
			parts.append("%s blocked %s%s" % [contact_name, reason, blocked_consumed_text])
			continue
		var event: Dictionary = fire_event.get("event", {})
		var hit_text := "hit" if bool(event.get("hit", false)) else "miss"
		var damage_text := "no damage"
		if bool(event.get("hit", false)):
			damage_text = String(event.get("starship_damage", {}).get("name", "No Damage"))
		var consumed_text := ""
		var consumed: Dictionary = fire_event.get("consumed_weapon_solution", {})
		if bool(consumed.get("applies", false)):
			consumed_text = " spent %d" % int(consumed.get("prior_rounds", 0))
		parts.append("%s %s %s%s ship %s" % [
			contact_name,
			hit_text,
			damage_text,
			consumed_text,
			_condition_text({"condition": fire_event.get("player_condition", {})}),
		])
	if parts.is_empty():
		return "none"
	return ", ".join(parts)

static func _assist_text(state: Dictionary) -> String:
	var assists: Dictionary = state.get("station_assists", {})
	if assists.is_empty():
		return "none"
	var parts := PackedStringArray()
	for key in assists.keys():
		var assist: Dictionary = assists.get(key, {})
		var name := String(assist.get("name", String(key).capitalize()))
		var pool := String(assist.get("pool", "0D"))
		var target_event := assist.duplicate(true)
		if not target_event.has("target_action"):
			target_event["target_action"] = key
		var target := station_target_action_text(target_event)
		parts.append("%s %s for %s%s" % [name, pool, target, _banked_round_text(assist)])
	if parts.is_empty():
		return "none"
	return ", ".join(parts)

static func _banked_round_text(assist: Dictionary) -> String:
	var banked_round := int(assist.get("banked_round", 0))
	if banked_round <= 0:
		return ""
	return " since station %d" % banked_round

static func _condition_tick_summary(condition_events: Array) -> String:
	var changed_names := PackedStringArray()
	for event in condition_events:
		if typeof(event) != TYPE_DICTIONARY or not bool(event.get("changed", false)):
			continue
		var ship_name := String(event.get("ship_name", "Ship"))
		var after_summary := String(event.get("after_summary", ""))
		if after_summary == "":
			changed_names.append(ship_name)
		else:
			changed_names.append("%s -> %s" % [ship_name, after_summary])
	if changed_names.is_empty():
		return ""
	return " Conditions ticked: %s." % "; ".join(changed_names)

static func _condition_summary_text(condition: Dictionary) -> String:
	var severity := _hull_severity(condition)
	var status := String(HULL_NAMES.get(clampi(severity, 0, 5), "Operational"))
	var flags := PackedStringArray()
	var shield_loss := int(condition.get("shield_loss_dice", 0))
	if shield_loss > 0:
		flags.append("Shields -%dD" % shield_loss)
	var controls := int(condition.get("controls_ionized", 0))
	if controls > 0:
		flags.append("Controls Dead" if controls >= 99 else "%d Controls Ionized" % controls)
	var maneuver_loss := int(condition.get("maneuverability_loss_dice", 0))
	if maneuver_loss > 0:
		flags.append("Maneuverability -%dD" % maneuver_loss)
	var move_loss := int(condition.get("move_loss", 0))
	if move_loss > 0:
		flags.append("Move -%d" % move_loss)
	if bool(condition.get("weapons_disabled", false)):
		flags.append("Weapons Disabled")
	if bool(condition.get("drives_disabled", false)):
		flags.append("Drives Disabled")
	if bool(condition.get("hyperdrive_disabled", false)):
		flags.append("Hyperdrive Disabled")
	if int(condition.get("hyperdrive_calculation_penalty", 0)) > 0:
		flags.append("Hyperdrive Calculations Slowed")
	if int(condition.get("astrogation_difficulty_penalty", 0)) > 0:
		flags.append("Astrogation +%d" % int(condition.get("astrogation_difficulty_penalty", 0)))
	if bool(condition.get("generator_overloading", false)):
		flags.append("Generator Overloading")
	if bool(condition.get("structural_damage", false)):
		flags.append("Structural Damage")
	var crew_wound_count := _crew_wound_count(condition)
	var text_parts := PackedStringArray()
	text_parts.append(status)
	if not flags.is_empty():
		text_parts.append(", ".join(flags))
	if crew_wound_count > 0:
		text_parts.append("%d crew wounded" % crew_wound_count)
	return " | ".join(text_parts)

static func _condition_text(ship: Dictionary) -> String:
	var condition: Dictionary = ship.get("condition", {})
	var severity := _hull_severity(condition)
	var parts := PackedStringArray()
	parts.append(String(HULL_NAMES.get(clampi(severity, 0, 5), "Operational")))
	var shield_loss := int(condition.get("shield_loss_dice", 0))
	if shield_loss > 0:
		parts.append("shields -%dD" % shield_loss)
	var controls := int(condition.get("controls_ionized", 0))
	if controls > 0:
		parts.append("controls dead" if controls >= 99 else "controls ionized %d" % controls)
	var system_flags := _system_flags(condition)
	for flag in system_flags:
		parts.append(flag)
	var repairable_count := _field_repairable_system_count(ship)
	if repairable_count > 0:
		parts.append("repair %d" % repairable_count)
	var crew_wound_count := _crew_wound_count(condition)
	if crew_wound_count > 0:
		parts.append("%d crew wounded" % crew_wound_count)
	return "/".join(parts)

static func _hull_severity(condition: Dictionary) -> int:
	if bool(condition.get("destroyed", false)):
		return 5
	return maxi(
		int(condition.get("hull_severity", 0)),
		int(condition.get("worst_hull_severity", 0))
	)

static func _crew_wound_count(condition: Dictionary) -> int:
	var count := 0
	var crew_wounds: Dictionary = condition.get("crew_wounds", {})
	for crew_id in crew_wounds.keys():
		var crew_wound: Dictionary = crew_wounds.get(crew_id, {})
		var wound: Dictionary = crew_wound.get("wound", {})
		if int(wound.get("severity", crew_wound.get("severity", 0))) > 0:
			count += 1
	return count

static func _field_repairable_system_count(ship: Dictionary) -> int:
	var condition: Dictionary = ship.get("condition", {})
	var count := 0
	for system_name in _repairable_system_names(condition):
		var override_difficulty := _repair_difficulty_override(ship, condition, system_name)
		if override_difficulty != REPAIR_DIFFICULTY_OVERRIDE_MISSING and override_difficulty < 0:
			continue
		count += 1
	return count

static func _repairable_system_names(condition: Dictionary) -> PackedStringArray:
	var systems := {}
	var extra_systems := PackedStringArray()
	var canonical_order := ["shields", "maneuverability", "move", "weapons", "drives", "hyperdrive", "generator", "structural"]
	for system in condition.get("repairable_systems", []):
		var system_name := String(system).strip_edges().to_lower().replace(" ", "_")
		if system_name == "":
			continue
		systems[system_name] = true
		if not canonical_order.has(system_name) and not extra_systems.has(system_name):
			extra_systems.append(system_name)
	if int(condition.get("shield_loss_dice", 0)) > 0:
		systems["shields"] = true
	if int(condition.get("maneuverability_loss_dice", 0)) > 0:
		systems["maneuverability"] = true
	if int(condition.get("move_loss", 0)) > 0:
		systems["move"] = true
	if bool(condition.get("weapons_disabled", false)) and not bool(condition.get("weapons_destroyed", false)):
		systems["weapons"] = true
	if bool(condition.get("drives_disabled", false)):
		systems["drives"] = true
	if bool(condition.get("hyperdrive_disabled", false)) or int(condition.get("hyperdrive_calculation_penalty", 0)) > 0 or int(condition.get("astrogation_difficulty_penalty", 0)) > 0:
		systems["hyperdrive"] = true
	if bool(condition.get("generator_overloading", false)):
		systems["generator"] = true
	if bool(condition.get("structural_damage", false)):
		systems["structural"] = true
	var ordered := PackedStringArray()
	for system_name in canonical_order:
		if systems.has(system_name):
			ordered.append(system_name)
	for system_name in extra_systems:
		if systems.has(system_name):
			ordered.append(system_name)
	return ordered

static func _system_flags(condition: Dictionary) -> PackedStringArray:
	var flags := PackedStringArray()
	var maneuver_loss := int(condition.get("maneuverability_loss_dice", 0))
	if maneuver_loss > 0:
		flags.append("maneuver -%dD" % maneuver_loss)
	var move_loss := int(condition.get("move_loss", 0))
	if move_loss > 0:
		flags.append("Move -%d" % move_loss)
	if bool(condition.get("weapons_disabled", false)):
		flags.append("weapons offline")
	if bool(condition.get("drives_disabled", false)):
		flags.append("drives offline")
	if bool(condition.get("hyperdrive_disabled", false)):
		flags.append("hyperdrive offline")
	if bool(condition.get("generator_overloading", false)):
		flags.append("generator overloading")
	if bool(condition.get("structural_damage", false)):
		flags.append("structural")
	return flags
