extends RefCounted

const DEFAULT_STATIONS := ["pilot", "copilot", "sensors", "commander", "gunner", "engineer", "navigator", "communications"]

static func station_rows(ship: Dictionary, state: Dictionary, stations: Array = DEFAULT_STATIONS) -> Array:
	var rows := []
	var crew_by_station := _crew_by_station(ship)
	var wounds_by_station := _wounds_by_station(ship)
	var assists_by_station := _assists_by_station(state)
	for station in stations:
		var station_key := _station_key(String(station))
		var crew: Dictionary = crew_by_station.get(station_key, {})
		var wound: Dictionary = wounds_by_station.get(station_key, {})
		var assists: Array = assists_by_station.get(station_key, [])
		rows.append({
			"station": station_key,
			"label": _station_label(station_key),
			"crew_name": String(crew.get("name", "Unassigned")),
			"wound_text": _wound_summary(wound),
			"has_wound": not wound.is_empty(),
			"assist_text": _assist_summary(assists),
			"has_assist": not assists.is_empty(),
		})
	return rows

static func station_line(row: Dictionary) -> String:
	var base := "%s: %s" % [String(row.get("label", "Station")), String(row.get("crew_name", "Unassigned"))]
	var wound_text := String(row.get("wound_text", ""))
	if wound_text != "":
		base = "%s [%s]" % [base, wound_text]
	var assist_text := String(row.get("assist_text", ""))
	if assist_text == "":
		return "%s | ready" % base
	return "%s | %s" % [base, assist_text]

static func _crew_by_station(ship: Dictionary) -> Dictionary:
	var crew_by_station := {}
	var crew_list: Array = ship.get("crew", [])
	for member in crew_list:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var station_key := _station_key(String(member.get("station", member.get("role", ""))))
		if station_key != "" and not crew_by_station.has(station_key):
			crew_by_station[station_key] = member
	return crew_by_station

static func _wounds_by_station(ship: Dictionary) -> Dictionary:
	var wounds_by_station := {}
	var crew_by_id := {}
	var crew_list: Array = ship.get("crew", [])
	for member in crew_list:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var member_id := String(member.get("id", ""))
		if member_id != "":
			crew_by_id[member_id] = member
	var condition: Dictionary = ship.get("condition", {})
	var crew_wounds: Dictionary = condition.get("crew_wounds", {})
	for crew_id in crew_wounds.keys():
		var wound_packet: Dictionary = crew_wounds.get(crew_id, {})
		var wound: Dictionary = wound_packet.get("wound", {})
		var severity := int(wound.get("severity", wound_packet.get("severity", 0)))
		if severity <= 0:
			continue
		var station_key := _station_key(String(wound_packet.get("station", "")))
		if station_key == "" and crew_by_id.has(crew_id):
			var crew: Dictionary = crew_by_id.get(crew_id, {})
			station_key = _station_key(String(crew.get("station", crew.get("role", ""))))
		if station_key == "":
			continue
		var existing: Dictionary = wounds_by_station.get(station_key, {})
		if severity >= int(existing.get("severity", -1)):
			var next := wound_packet.duplicate(true)
			next["severity"] = severity
			wounds_by_station[station_key] = next
	return wounds_by_station

static func _assists_by_station(state: Dictionary) -> Dictionary:
	var assists_by_station := {}
	var station_assists: Dictionary = state.get("station_assists", {})
	for target_action in station_assists.keys():
		var assist: Dictionary = station_assists.get(target_action, {})
		var station_key := _station_key(String(assist.get("station", "")))
		if station_key == "":
			continue
		if not assists_by_station.has(station_key):
			assists_by_station[station_key] = []
		var assists: Array = assists_by_station[station_key]
		assists.append(assist)
		assists_by_station[station_key] = assists
	return assists_by_station

static func _assist_summary(assists: Array) -> String:
	if assists.is_empty():
		return ""
	var parts := []
	for assist in assists:
		if typeof(assist) != TYPE_DICTIONARY:
			continue
		var name := String(assist.get("name", "Assist"))
		var pool := String(assist.get("pool", assist.get("pool_text", "")))
		var target := _target_text(assist)
		var pool_suffix := " %s" % pool if pool != "" else ""
		parts.append("%s%s -> %s%s" % [name, pool_suffix, target, _banked_round_text(assist)])
	return ", ".join(parts)

static func _banked_round_text(assist: Dictionary) -> String:
	var banked_round := int(assist.get("banked_round", 0))
	if banked_round <= 0:
		return ""
	return " since station %d" % banked_round

static func _wound_summary(wound_packet: Dictionary) -> String:
	if wound_packet.is_empty():
		return ""
	var wound: Dictionary = wound_packet.get("wound", {})
	var name := String(wound.get("name", wound_packet.get("name", "")))
	if name != "":
		return name
	var severity := int(wound.get("severity", wound_packet.get("severity", 0)))
	match severity:
		1:
			return "Stunned"
		2:
			return "Wounded"
		3:
			return "Incapacitated"
		4:
			return "Mortally Wounded"
		5:
			return "Killed"
		_:
			return ""

static func _target_text(assist: Dictionary) -> String:
	var target := String(assist.get("target_action", ""))
	if target == "":
		target = String(assist.get("requested_target_action", ""))
	var target_text := target.strip_edges().to_lower().replace("_", " ")
	var requested_text := String(assist.get("requested_target_action", "")).strip_edges().to_lower().replace("_", " ")
	if target_text == "":
		return requested_text if requested_text != "" else "next action"
	if requested_text != "" and requested_text != target_text:
		return "%s (%s)" % [target_text, requested_text]
	return target_text

static func _station_key(station: String) -> String:
	var key := station.strip_edges().to_lower().replace(" ", "_")
	if key == "comms":
		return "communications"
	return key

static func _station_label(station: String) -> String:
	match _station_key(station):
		"copilot":
			return "Copilot"
		"sensors":
			return "Sensors"
		"commander":
			return "Commander"
		"gunner":
			return "Gunner"
		"engineer":
			return "Engineer"
		"navigator":
			return "Navigator"
		"communications":
			return "Comms"
		"pilot":
			return "Pilot"
		_:
			return station.capitalize()
