extends RefCounted

const ACTIONS := [
	{"label": "Sensors", "key_name": "N", "key": KEY_N},
	{"label": "ID", "key_name": "I", "key": KEY_I},
	{"label": "Hail", "key_name": "X", "key": KEY_X},
	{"label": "Gunnery", "key_name": "B", "key": KEY_B},
	{"label": "Shields", "key_name": "J", "key": KEY_J},
	{"label": "Repair", "key_name": "K", "key": KEY_K},
	{"label": "Astro", "key_name": "Y", "key": KEY_Y},
	{"label": "Maneuver", "key_name": "L", "key": KEY_L},
	{"label": "Assist", "key_name": "U", "key": KEY_U},
	{"label": "Pause", "key_name": "T", "key": KEY_T, "resume_label": "Resume"},
	{"label": "Step", "key_name": ";", "key": KEY_SEMICOLON},
]

static func action_definitions(live_traffic_enabled: bool = true, route_preview: Dictionary = {}, bridge_cue: String = "") -> Array:
	var actions := []
	var cue_keys := _cue_action_keys(bridge_cue)
	var cue_level := cue_status_level(bridge_cue)
	for action in ACTIONS:
		var next: Dictionary = action.duplicate(true)
		if int(next.get("key", 0)) == KEY_T and not live_traffic_enabled:
			next["label"] = String(next.get("resume_label", "Resume"))
		if int(next.get("key", 0)) == KEY_L and not route_preview.is_empty():
			next["button_text"] = _route_button_text(route_preview, String(next.get("key_name", "")))
			next["tooltip_text"] = _route_tooltip_text(route_preview)
		else:
			next["button_text"] = "%s [%s]" % [String(next.get("label", "")), String(next.get("key_name", ""))]
		next["cue_highlight"] = false
		next["cue_status_level"] = "none"
		if _cue_matches_action(next, cue_keys):
			next["cue_highlight"] = true
			next["cue_text"] = bridge_cue
			next["cue_status_level"] = cue_level
			next["button_text"] = "> %s" % String(next["button_text"])
			var cue_tooltip := _bridge_cue_tooltip_text(bridge_cue)
			if next.has("tooltip_text") and String(next["tooltip_text"]) != "":
				next["tooltip_text"] = "%s | %s" % [String(next["tooltip_text"]), cue_tooltip]
			else:
				next["tooltip_text"] = cue_tooltip
		actions.append(next)
	return actions

static func mode_status_text(ship: Dictionary, selected_contact: Dictionary, state: Dictionary, live_traffic_enabled: bool, tick_count: int, route_preview: Dictionary = {}, bridge_cue: String = "") -> String:
	var ship_name := String(ship.get("name", "Local ship"))
	var selected_name := String(selected_contact.get("name", selected_contact.get("id", "No target")))
	var traffic := "LIVE" if live_traffic_enabled else "PAUSED"
	var revealed_count := 0
	if state.has("revealed_contacts") and typeof(state["revealed_contacts"]) == TYPE_ARRAY:
		revealed_count = state["revealed_contacts"].size()
	var scan_round := int(state.get("scan_round", 1))
	return "%s | Bridge mode | Traffic %s | Target %s | Tracks %d | Scan %d | Ticks %d%s%s" % [
		ship_name,
		traffic,
		selected_name,
		revealed_count,
		scan_round,
		tick_count,
		_route_preview_text(route_preview),
		_bridge_cue_status_text(bridge_cue),
	]

static func cue_status_level(bridge_cue: String) -> String:
	if bridge_cue == "":
		return "none"
	var cue := bridge_cue.to_lower()
	if cue.find("abandon ship") >= 0:
		return "critical"
	if cue.find("target destroyed") >= 0 or cue.find("destroyed contact") >= 0:
		return "notice"
	if cue.find("evade") >= 0 or cue.find("return fire") >= 0 or cue.find("weapon solution") >= 0 or cue.find("ready hostile fire") >= 0:
		return "threat"
	if cue.find("damage control") >= 0 or cue.find("repair") >= 0:
		return "repair"
	return "guidance"

static func _route_preview_text(route_preview: Dictionary) -> String:
	if route_preview.is_empty():
		return ""
	return " | %s" % _route_tooltip_text(route_preview).replace("Maneuver difficulty", "Maneuver diff")

static func _bridge_cue_status_text(bridge_cue: String) -> String:
	if bridge_cue == "":
		return ""
	var cue := bridge_cue
	if cue.begins_with("Cue: "):
		cue = cue.substr(5)
	match cue_status_level(bridge_cue):
		"critical":
			return " | Alert %s" % cue
		"threat":
			return " | Threat %s" % cue
		"repair":
			return " | Repair %s" % cue
		"notice":
			return " | Status %s" % cue
	return " | Next %s" % cue

static func _bridge_cue_tooltip_text(bridge_cue: String) -> String:
	if bridge_cue == "":
		return ""
	var cue := bridge_cue
	if cue.begins_with("Cue: "):
		cue = cue.substr(5)
	match cue_status_level(bridge_cue):
		"critical":
			return "Alert cue: %s" % cue
		"threat":
			return "Threat cue: %s" % cue
		"repair":
			return "Repair cue: %s" % cue
		"notice":
			return "Status cue: %s" % cue
	return "Next cue: %s" % cue

static func _route_button_text(route_preview: Dictionary, key_name: String) -> String:
	var crossed := _route_crossed_hazards(route_preview)
	var hazard_marker := ""
	if crossed.size() == 1:
		hazard_marker = "!"
	elif crossed.size() > 1:
		hazard_marker = "x%d" % crossed.size()
	return "Mnv %d%s [%s]" % [
		int(route_preview.get("difficulty", 0)),
		hazard_marker,
		key_name,
	]

static func _route_tooltip_text(route_preview: Dictionary) -> String:
	var crossed := _route_crossed_hazards(route_preview)
	return "Maneuver difficulty %d %s" % [
		int(route_preview.get("difficulty", 0)),
		_route_hazard_summary(crossed),
	]

static func _route_crossed_hazards(route_preview: Dictionary) -> Array:
	var hazard_context: Dictionary = route_preview.get("hazard_context", {})
	return hazard_context.get("crossed", [])

static func _route_hazard_summary(crossed: Array) -> String:
	if crossed.size() == 1 and typeof(crossed[0]) == TYPE_DICTIONARY:
		return "crosses %s" % String(crossed[0].get("name", "1 hazard"))
	elif crossed.size() > 1:
		var first_name := "hazard"
		if typeof(crossed[0]) == TYPE_DICTIONARY:
			first_name = String(crossed[0].get("name", "hazard"))
		return "crosses %d hazards incl %s" % [crossed.size(), first_name]
	return "clear"

static func _cue_action_keys(bridge_cue: String) -> Array:
	var keys := []
	if bridge_cue == "":
		return keys
	for action in ACTIONS:
		var key_name := String(action.get("key_name", ""))
		if key_name == "":
			continue
		if bridge_cue.find("[%s]" % key_name) >= 0:
			keys.append(key_name)
		elif bridge_cue.find("[%s/" % key_name) >= 0:
			keys.append(key_name)
		elif bridge_cue.find("/%s]" % key_name) >= 0:
			keys.append(key_name)
		elif bridge_cue.find("/%s/" % key_name) >= 0:
			keys.append(key_name)
	return keys

static func _cue_matches_action(action: Dictionary, cue_keys: Array) -> bool:
	return cue_keys.has(String(action.get("key_name", "")))
