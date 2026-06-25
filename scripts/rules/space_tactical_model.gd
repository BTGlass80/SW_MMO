extends RefCounted

const SENSOR_DIFFICULTIES = {
	"Point Blank": 5,
	"Short": 10,
	"Medium": 15,
	"Long": 20,
	"Extreme": 30,
}

const SHIELD_ARC_DIFFICULTIES = {
	1: 5,
	2: 10,
	3: 15,
	4: 20,
}

const REPAIR_DIFFICULTIES = {
	"easy": 10,
	"moderate": 15,
	"difficult": 20,
	"very_difficult": 25,
}

const HULL_SEVERITY_NAMES = {
	0: "Operational",
	1: "Shield/Controls Hit",
	2: "Lightly Damaged",
	3: "Heavily Damaged",
	4: "Severely Damaged",
	5: "Destroyed",
}

const REPAIR_DIFFICULTY_NAMES = {
	10: "Easy",
	15: "Moderate",
	20: "Difficult",
	25: "Very Difficult",
}

const REPAIR_DIFFICULTY_OVERRIDE_MISSING = -99999

const REPAIR_TIME_BY_DIFFICULTY = {
	10: {"combat_rounds": 1, "bay_hours": 1},
	15: {"combat_rounds": 2, "bay_hours": 4},
	20: {"combat_rounds": 5, "bay_hours": 12},
	25: {"combat_rounds": 10, "bay_hours": 24},
}

const REPAIRABLE_SYSTEM_ORDER = [
	"shields",
	"maneuverability",
	"move",
	"weapons",
	"drives",
	"hyperdrive",
	"generator",
	"structural",
]

const GG6_DAMAGE_REPAIR_COSTS = {
	2: 1000,
	3: 2000,
	4: 3000,
	5: 3000,
}

const SENSOR_TARGETING_DIFFICULTY_MODIFIERS = {
	"unresolved": 10,
	"missed": 10,
	"faint": 6,
	"partial": 3,
	"solid": 1,
	"clear": 0,
}

const YARD_DAMAGED_SYSTEM_PCT = 0.01
const YARD_DESTROYED_SYSTEM_PCT = 0.06
const YARD_MIN_FEE = 50

const COLLISION_DAMAGE_BY_SPEED = {
	"cautious": {"dice": 2, "pips": 0},
	"cruise": {"dice": 4, "pips": 0},
	"cruising": {"dice": 4, "pips": 0},
	"high_speed": {"dice": 6, "pips": 0},
	"all_out": {"dice": 10, "pips": 0},
}

func initial_state() -> Dictionary:
	return {
		"scan_round": 1,
		"identification_round": 1,
		"comms_round": 1,
		"gunnery_round": 1,
		"shield_round": 1,
		"astrogation_round": 1,
		"maneuver_round": 1,
		"station_round": 1,
		"movement_round": 1,
		"sensor_pool": {"dice": 4, "pips": 0},
		"revealed_contacts": [],
		"sensor_contact_confidence": {},
		"identified_contacts": {},
		"contact_dispositions": {},
		"station_assists": {},
	}

func range_name_for_distance(distance: float) -> String:
	if distance <= 32.0:
		return "Point Blank"
	if distance <= 80.0:
		return "Short"
	if distance <= 150.0:
		return "Medium"
	if distance <= 240.0:
		return "Long"
	return "Extreme"

func incoming_arc_for_attack(attacker: Dictionary, target: Dictionary) -> String:
	var attacker_position := _position_from(attacker)
	var target_position := _position_from(target)
	var to_attacker := attacker_position - target_position
	if to_attacker.length() <= 0.001:
		return String(target.get("incoming_arc", attacker.get("target_arc", "front"))).strip_edges().to_lower()

	var heading_degrees := float(target.get("heading_degrees", 0.0))
	var heading_radians := deg_to_rad(heading_degrees)
	var forward := Vector2(cos(heading_radians), sin(heading_radians)).normalized()
	var direction := to_attacker.normalized()
	var dot := clampf(forward.dot(direction), -1.0, 1.0)
	var angle := rad_to_deg(acos(dot))
	if angle <= 45.0:
		return "front"
	if angle >= 135.0:
		return "rear"
	var cross := forward.x * direction.y - forward.y * direction.x
	if cross >= 0.0:
		return "right"
	return "left"

func incoming_arc_for_gunnery(attacker: Dictionary, target: Dictionary) -> String:
	if target.has("incoming_arc"):
		return String(target.get("incoming_arc", "front")).strip_edges().to_lower()
	if attacker.has("target_arc"):
		return String(attacker.get("target_arc", "front")).strip_edges().to_lower()
	return incoming_arc_for_attack(attacker, target)

func shield_difficulty_for_arc_count(arc_count: int) -> int:
	return int(SHIELD_ARC_DIFFICULTIES.get(clampi(arc_count, 1, 4), 20))

func sensor_confidence_for_margin(margin: int) -> Dictionary:
	if margin < 0:
		return {"key": "missed", "name": "Missed", "detail": "No reliable contact fix"}
	if margin <= 3:
		return {"key": "faint", "name": "Faint", "detail": "Weak contact, identity uncertain"}
	if margin <= 8:
		return {"key": "partial", "name": "Partial", "detail": "Contact resolved with rough track"}
	if margin <= 12:
		return {"key": "solid", "name": "Solid", "detail": "Contact resolved with useful track"}
	return {"key": "clear", "name": "Clear", "detail": "Clean contact and firing-quality track"}

func sensor_confidence_rank(confidence_key: String) -> int:
	match confidence_key:
		"faint":
			return 1
		"partial":
			return 2
		"solid":
			return 3
		"clear":
			return 4
		_:
			return 0

func sensor_confidence_for_contact(state: Dictionary, contact_id: String) -> Dictionary:
	var confidence_by_contact: Dictionary = state.get("sensor_contact_confidence", {})
	if contact_id == "" or not confidence_by_contact.has(contact_id):
		return {"key": "unresolved", "name": "Unresolved", "detail": "No successful sensor track"}
	var confidence: Dictionary = confidence_by_contact.get(contact_id, {})
	if confidence.is_empty():
		return {"key": "unresolved", "name": "Unresolved", "detail": "No successful sensor track"}
	return confidence.duplicate(true)

func sensor_targeting_difficulty_modifier(confidence_key: String) -> int:
	return int(SENSOR_TARGETING_DIFFICULTY_MODIFIERS.get(confidence_key, SENSOR_TARGETING_DIFFICULTY_MODIFIERS["unresolved"]))

func gunnery_sensor_targeting_modifier_for_contact(state: Dictionary, contact: Dictionary) -> int:
	if not _contact_requires_sensor_targeting(contact):
		return 0
	var confidence := sensor_confidence_for_contact(state, String(contact.get("id", "")))
	return sensor_targeting_difficulty_modifier(String(confidence.get("key", "unresolved")))

func targeting_context_for_contact(state: Dictionary, contact: Dictionary) -> Dictionary:
	var contact_id := String(contact.get("id", ""))
	var confidence := sensor_confidence_for_contact(state, contact_id)
	var confidence_key := String(confidence.get("key", "unresolved"))
	var confidence_rank := sensor_confidence_rank(confidence_key)
	var sensor_targeting_required := _contact_requires_sensor_targeting(contact)
	var gunnery_modifier := gunnery_sensor_targeting_modifier_for_contact(state, contact)
	var hint := "No resolved sensor track; visual or known target can still be engaged"
	if sensor_targeting_required:
		hint = "No resolved sensor track for this sensor-dependent target"
	match confidence_key:
		"faint":
			hint = "Weak sensor track; identity and vector are uncertain"
		"partial":
			hint = "Rough sensor track; firing data should be treated cautiously"
		"solid":
			hint = "Useful sensor track for targeting context"
		"clear":
			hint = "Clean firing-quality sensor track"
	return {
		"contact_id": contact_id,
		"confidence": confidence,
		"confidence_key": confidence_key,
		"confidence_name": String(confidence.get("name", "Unresolved")),
		"confidence_rank": confidence_rank,
		"has_sensor_track": confidence_rank > 0,
		"targeting_hint": hint,
		"sensor_targeting_required": sensor_targeting_required,
		"gunnery_difficulty_modifier": gunnery_modifier,
		"informational_only": not sensor_targeting_required,
	}

func crew_wound_penalty_for_station(ship: Dictionary, station: String) -> Dictionary:
	return _crew_wound_penalty_for_candidates(ship, [_crew_station_key(station)])

func crew_wound_penalty_for_action(ship: Dictionary, target_action: String) -> Dictionary:
	return _crew_wound_penalty_for_candidates(ship, _station_candidates_for_action(target_action))

func identification_context_for_contact(state: Dictionary, contact: Dictionary) -> Dictionary:
	var contact_id := String(contact.get("id", ""))
	var confidence := sensor_confidence_for_contact(state, contact_id)
	var confidence_key := String(confidence.get("key", "unresolved"))
	var confidence_rank := sensor_confidence_rank(confidence_key)
	var revealed: Array = state.get("revealed_contacts", [])
	var identified_by_contact: Dictionary = state.get("identified_contacts", {})
	return {
		"contact_id": contact_id,
		"confidence": confidence,
		"confidence_key": confidence_key,
		"confidence_name": String(confidence.get("name", "Unresolved")),
		"confidence_rank": confidence_rank,
		"has_sensor_track": confidence_rank > 0,
		"revealed": revealed.has(contact_id),
		"identified": identified_by_contact.has(contact_id),
		"identity": identified_by_contact.get(contact_id, {}),
		"informational_only": true,
	}

func weapon_solution_context_for_contact(state: Dictionary, contact: Dictionary) -> Dictionary:
	var contact_id := String(contact.get("id", ""))
	var movement: Dictionary = contact.get("movement", {})
	var required_rounds := maxi(int(movement.get("fire_ready_rounds", movement.get("lock_rounds_to_fire", 2))), 1)
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	var rounds := int(counts.get(contact_id, 0)) if contact_id != "" else 0
	var armed := bool(contact.get("counterfire", false)) and not _ship_weapons_disabled(contact)
	var ready := armed and rounds >= required_rounds
	var key := "none"
	var name := "No Lock"
	if armed and rounds > 0:
		key = "ready" if ready else "building"
		name = "Ready" if ready else "Acquiring"
	return {
		"contact_id": contact_id,
		"armed": armed,
		"rounds": rounds,
		"required_rounds": required_rounds,
		"ready": ready,
		"requires_solution": bool(contact.get("counterfire_requires_solution", false)),
		"key": key,
		"name": name,
	}

func engagement_context_for_contact(state: Dictionary, contact: Dictionary) -> Dictionary:
	var targeting_context := targeting_context_for_contact(state, contact)
	var weapon_context := weapon_solution_context_for_contact(state, contact)
	var summary := "Track %s, lock %s" % [
		String(targeting_context.get("confidence_name", "Unresolved")),
		String(weapon_context.get("name", "No Lock")),
	]
	if int(weapon_context.get("rounds", 0)) > 0:
		summary += " %d/%d" % [
			int(weapon_context.get("rounds", 0)),
			int(weapon_context.get("required_rounds", 1)),
		]
	return {
		"contact_id": String(contact.get("id", "")),
		"targeting": targeting_context,
		"weapon_solution": weapon_context,
		"summary": summary,
		"informational_only": true,
	}

func movement_failure_for_margin(failure_margin: int) -> Dictionary:
	if failure_margin <= 0:
		return {"key": "none", "name": "None", "move_fraction": 1.0, "pilot_penalty_dice": 0, "next_round_penalty_dice": 0, "control_locked_rounds": 0}
	if failure_margin <= 3:
		return {"key": "slight_slip", "name": "Slight Slip", "move_fraction": 1.0, "pilot_penalty_dice": 1, "next_round_penalty_dice": 0, "control_locked_rounds": 0}
	if failure_margin <= 6:
		return {"key": "slip", "name": "Slip", "move_fraction": 0.5, "pilot_penalty_dice": 3, "next_round_penalty_dice": 1, "control_locked_rounds": 0}
	if failure_margin <= 10:
		return {"key": "spin", "name": "Spin", "move_fraction": 0.25, "pilot_penalty_dice": 99, "next_round_penalty_dice": 99, "control_locked_rounds": 1}
	if failure_margin <= 15:
		return {"key": "minor_collision_or_wild_spin", "name": "Minor Collision / Wild Spin", "move_fraction": 0.0, "pilot_penalty_dice": 99, "next_round_penalty_dice": 99, "control_locked_rounds": 1}
	if failure_margin <= 20:
		return {"key": "collision_or_wild_spin", "name": "Collision / Wild Spin", "move_fraction": 0.0, "pilot_penalty_dice": 99, "next_round_penalty_dice": 99, "control_locked_rounds": 1}
	return {"key": "major_collision_or_spinout", "name": "Major Collision / Spinout", "move_fraction": 0.0, "pilot_penalty_dice": 99, "next_round_penalty_dice": 99, "control_locked_rounds": 1}

func collision_damage_pool_for_speed(speed: String) -> Dictionary:
	var speed_key := speed.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	return COLLISION_DAMAGE_BY_SPEED.get(speed_key, COLLISION_DAMAGE_BY_SPEED["cruise"])

func collision_modifier_dice_for_failure(failure_key: String) -> int:
	match failure_key:
		"minor_collision_or_wild_spin":
			return -3
		"collision_or_wild_spin":
			return 0
		"major_collision_or_spinout":
			return 4
		_:
			return 0

func collision_damage_pool_for_failure(rules: Object, speed: String, failure_key: String) -> Dictionary:
	var base_pool: Dictionary = collision_damage_pool_for_speed(speed)
	return rules.add_pips(base_pool, collision_modifier_dice_for_failure(failure_key) * 3)

func maneuver_hazard_context(start_position: Vector2, end_position: Vector2, hazards: Array) -> Dictionary:
	var crossed: Array = []
	var total_modifier := 0
	var collision_possible := false
	for hazard_value in hazards:
		if typeof(hazard_value) != TYPE_DICTIONARY:
			continue
		var hazard: Dictionary = hazard_value
		var center := _hazard_position(hazard)
		var radius := float(hazard.get("radius", 0.0))
		if radius <= 0.0:
			continue
		if _segment_intersects_circle(start_position, end_position, center, radius):
			var difficulty_modifier := int(hazard.get("difficulty_modifier", hazard.get("modifier", 0)))
			total_modifier += difficulty_modifier
			if bool(hazard.get("collision_possible", hazard.get("obstacle_present", true))):
				collision_possible = true
			crossed.append({
				"id": String(hazard.get("id", "")),
				"name": String(hazard.get("name", "Hazard")),
				"difficulty_modifier": difficulty_modifier,
				"collision_possible": bool(hazard.get("collision_possible", hazard.get("obstacle_present", true))),
				"radius": radius,
			})
	return {
		"crossed": crossed,
		"difficulty_modifier": total_modifier,
		"collision_possible": collision_possible,
	}

func maneuver_route_preview(ship: Dictionary, maneuver: Dictionary) -> Dictionary:
	var current_heading := float(ship.get("heading_degrees", 0.0))
	var requested_move := float(maneuver.get("move_units", 0.0))
	var intended_heading := fposmod(current_heading + float(maneuver.get("turn_degrees", 0.0)), 360.0)
	var intended_heading_radians := deg_to_rad(intended_heading)
	var current_position := _position_from(ship)
	var intended_position := current_position + Vector2(cos(intended_heading_radians), sin(intended_heading_radians)) * requested_move
	var hazard_context := maneuver_hazard_context(current_position, intended_position, maneuver.get("hazards", []))
	var base_difficulty := int(maneuver.get("difficulty", 10))
	var maneuver_modifier := int(maneuver.get("modifier", 0))
	return {
		"start_position": {"x": current_position.x, "y": current_position.y},
		"intended_position": {"x": intended_position.x, "y": intended_position.y},
		"heading_degrees": intended_heading,
		"requested_move": requested_move,
		"base_difficulty": base_difficulty,
		"maneuver_modifier": maneuver_modifier,
		"hazard_context": hazard_context,
		"difficulty": base_difficulty + maneuver_modifier + int(hazard_context.get("difficulty_modifier", 0)),
	}

func starship_damage_for_margin(margin: int, weapon_type: String = "") -> Dictionary:
	var normalized_weapon_type := weapon_type.strip_edges().to_lower()
	if margin < 0:
		return {"key": "no_damage", "name": "No Damage", "severity": 0, "ion_controls": 0}

	if normalized_weapon_type == "ion":
		if margin <= 3:
			return {"key": "one_control_ionized", "name": "1 Control Ionized", "severity": 1, "ion_controls": 1}
		if margin <= 8:
			return {"key": "two_controls_ionized", "name": "2 Controls Ionized", "severity": 2, "ion_controls": 2}
		if margin <= 12:
			return {"key": "three_controls_ionized", "name": "3 Controls Ionized", "severity": 3, "ion_controls": 3}
		if margin <= 15:
			return {"key": "four_controls_ionized", "name": "4 Controls Ionized", "severity": 4, "ion_controls": 4}
		return {"key": "controls_dead", "name": "Controls Dead", "severity": 5, "ion_controls": 99}

	if margin <= 3:
		return {"key": "shields_blown_or_controls_ionized", "name": "Shields Blown / Controls Ionized", "severity": 1, "ion_controls": 0}
	if margin <= 8:
		return {"key": "lightly_damaged", "name": "Lightly Damaged", "severity": 2, "ion_controls": 0}
	if margin <= 12:
		return {"key": "heavily_damaged", "name": "Heavily Damaged", "severity": 3, "ion_controls": 0}
	if margin <= 15:
		return {"key": "severely_damaged", "name": "Severely Damaged", "severity": 4, "ion_controls": 0}
	return {"key": "destroyed", "name": "Destroyed", "severity": 5, "ion_controls": 0}

func starship_system_effect_for_damage(damage_key: String, system_roll: int) -> Dictionary:
	var roll := clampi(system_roll, 1, 6)
	if damage_key == "lightly_damaged":
		match roll:
			1:
				return {"key": "maneuverability_minus_1d", "name": "Maneuverability -1D", "roll": roll}
			2:
				return {"key": "weapon_emplacement_destroyed", "name": "Weapon Emplacement Destroyed", "roll": roll}
			3:
				return {"key": "weapon_emplacement_inoperative", "name": "Weapon Emplacement Inoperative", "roll": roll}
			4:
				return {"key": "hyperdrive_calculation_time_doubled", "name": "Hyperdrive Calculation Time Doubled", "roll": roll}
			5:
				return {"key": "shields_minus_1d_or_controls_ionized", "name": "Shields -1D / Controls Ionized", "roll": roll}
			_:
				return {"key": "move_minus_1", "name": "Move -1", "roll": roll}
	if damage_key == "heavily_damaged":
		match roll:
			1:
				return {"key": "maneuverability_minus_2d", "name": "Maneuverability -2D", "roll": roll}
			2:
				return {"key": "fire_arc_weapons_inoperative", "name": "Fire-Arc Weapons Inoperative", "roll": roll}
			3:
				return {"key": "fire_arc_weapons_destroyed", "name": "Fire-Arc Weapons Destroyed", "roll": roll}
			4:
				return {"key": "hyperdrive_astrogation_plus_10", "name": "Hyperdrive Astrogation +10", "roll": roll}
			5:
				return {"key": "shields_minus_2d_or_two_controls_ionized", "name": "Shields -2D / 2 Controls Ionized", "roll": roll}
			_:
				return {"key": "move_minus_2", "name": "Move -2", "roll": roll}
	if damage_key == "severely_damaged":
		match roll:
			1:
				return {"key": "dead_in_space", "name": "Dead in Space", "roll": roll}
			2:
				return {"key": "overloaded_generator", "name": "Overloaded Generator", "roll": roll}
			3:
				return {"key": "disabled_hyperdrives", "name": "Disabled Hyperdrives", "roll": roll}
			4:
				return {"key": "disabled_weapons", "name": "Disabled Weapons", "roll": roll}
			5:
				return {"key": "structural_damage", "name": "Structural Damage", "roll": roll}
			_:
				return {"key": "destroyed", "name": "Destroyed", "roll": roll}
	return {"key": "none", "name": "None", "roll": 0}

func passenger_damage_pool_for_starship_damage(damage_key: String) -> Dictionary:
	match damage_key:
		"lightly_damaged":
			return {"dice": 1, "pips": 0}
		"heavily_damaged":
			return {"dice": 3, "pips": 0}
		"severely_damaged":
			return {"dice": 6, "pips": 0}
		"destroyed":
			return {"dice": 12, "pips": 0}
		_:
			return {"dice": 0, "pips": 0}

func passenger_damage_group_for_system_effect(system_effect: Dictionary) -> String:
	var effect_key := String(system_effect.get("key", "none"))
	if effect_key == "weapon_emplacement_destroyed" or effect_key == "fire_arc_weapons_destroyed":
		return "gunners"
	if effect_key == "weapon_emplacement_inoperative" or effect_key == "fire_arc_weapons_inoperative":
		return "gunners"
	return "passengers"

func ship_condition_summary(ship_or_condition: Dictionary) -> Dictionary:
	var condition: Dictionary = ship_or_condition.get("condition", ship_or_condition)
	var severity := int(condition.get("worst_hull_severity", 0))
	if bool(condition.get("destroyed", false)):
		severity = 5
	var status := String(HULL_SEVERITY_NAMES.get(clampi(severity, 0, 5), "Operational"))
	var flags: PackedStringArray = PackedStringArray()
	var repairable_systems: Array = []

	var shield_loss := int(condition.get("shield_loss_dice", 0))
	if shield_loss > 0:
		flags.append("Shields -%dD" % shield_loss)
		_append_repairable_system(repairable_systems, "shields")

	var controls_ionized := int(condition.get("controls_ionized", 0))
	if controls_ionized > 0:
		flags.append("Controls Dead" if controls_ionized >= 99 else "%d Controls Ionized" % controls_ionized)

	var maneuverability_loss := int(condition.get("maneuverability_loss_dice", 0))
	if maneuverability_loss > 0:
		flags.append("Maneuverability -%dD" % maneuverability_loss)
		_append_repairable_system(repairable_systems, "maneuverability")

	var move_loss := int(condition.get("move_loss", 0))
	if move_loss > 0:
		flags.append("Move -%d" % move_loss)
		_append_repairable_system(repairable_systems, "move")

	if bool(condition.get("weapons_disabled", false)):
		flags.append("Weapons Disabled")
		_append_repairable_system(repairable_systems, "weapons")
	if bool(condition.get("drives_disabled", false)):
		flags.append("Drives Disabled")
		_append_repairable_system(repairable_systems, "drives")
	if bool(condition.get("hyperdrive_disabled", false)):
		flags.append("Hyperdrive Disabled")
		_append_repairable_system(repairable_systems, "hyperdrive")
	if int(condition.get("hyperdrive_calculation_penalty", 0)) > 0:
		flags.append("Hyperdrive Calculations Slowed")
		_append_repairable_system(repairable_systems, "hyperdrive")
	if int(condition.get("astrogation_difficulty_penalty", 0)) > 0:
		flags.append("Astrogation +%d" % int(condition.get("astrogation_difficulty_penalty", 0)))
		_append_repairable_system(repairable_systems, "hyperdrive")
	if bool(condition.get("generator_overloading", false)):
		flags.append("Generator Overloading")
		_append_repairable_system(repairable_systems, "generator")
	if bool(condition.get("structural_damage", false)):
		flags.append("Structural Damage")
		_append_repairable_system(repairable_systems, "structural")
	for system_name in _custom_repairable_system_names(condition):
		flags.append("%s Repair" % String(system_name).replace("_", " "))
		_append_repairable_system(repairable_systems, system_name)

	var crew_summaries: Array = []
	var crew_wounds: Dictionary = condition.get("crew_wounds", {})
	var crew_ids: Array = crew_wounds.keys()
	crew_ids.sort()
	for crew_id in crew_ids:
		var crew_wound: Dictionary = crew_wounds.get(crew_id, {})
		var wound: Dictionary = crew_wound.get("wound", {})
		if int(wound.get("severity", crew_wound.get("severity", 0))) <= 0:
			continue
		crew_summaries.append({
			"id": String(crew_id),
			"name": String(crew_wound.get("name", crew_id)),
			"station": String(crew_wound.get("station", "")),
			"wound": String(wound.get("name", "Wounded")),
			"severity": int(wound.get("severity", crew_wound.get("severity", 0))),
		})

	var text_parts: PackedStringArray = PackedStringArray()
	text_parts.append(status)
	if flags.size() > 0:
		text_parts.append(", ".join(flags))
	if crew_summaries.size() > 0:
		text_parts.append("%d crew wounded" % crew_summaries.size())

	return {
		"status": status,
		"severity": severity,
		"flags": flags,
		"repairable_systems": repairable_systems,
		"crew_wounds": crew_summaries,
		"text": " | ".join(text_parts),
	}

func _append_repairable_system(repairable_systems: Array, system_name: String) -> void:
	var system_key := _normalize_system_key(system_name)
	if system_key != "" and not repairable_systems.has(system_key):
		repairable_systems.append(system_key)

func empty_ship_condition() -> Dictionary:
	return {
		"shield_loss_dice": 0,
		"controls_ionized": 0,
		"controls_ionized_rounds": 0,
		"pilot_action_penalty_dice": 0,
		"pilot_action_penalty_rounds": 0,
		"control_locked_rounds": 0,
		"maneuverability_loss_dice": 0,
		"move_loss": 0,
		"light_damage_count": 0,
		"heavy_damage_count": 0,
		"severe_damage_count": 0,
		"worst_hull_severity": 0,
		"destroyed": false,
		"weapons_disabled": false,
		"drives_disabled": false,
		"hyperdrive_disabled": false,
		"generator_overloading": false,
		"structural_damage": false,
		"hyperdrive_calculation_penalty": 0,
		"astrogation_difficulty_penalty": 0,
		"system_effects": [],
		"passenger_damage_log": [],
		"crew_wounds": {},
		"repair_log": [],
		"damage_log": [],
	}

func advance_ship_condition_round(ship: Dictionary) -> Dictionary:
	var updated_ship := ship.duplicate(true)
	var condition: Dictionary = ship.get("condition", empty_ship_condition())
	var next_condition := empty_ship_condition()
	for key in condition.keys():
		next_condition[key] = condition[key]

	var ion_rounds := int(next_condition.get("controls_ionized_rounds", 0))
	if ion_rounds > 0:
		ion_rounds -= 1
		next_condition["controls_ionized_rounds"] = ion_rounds
		if ion_rounds <= 0:
			next_condition["controls_ionized"] = 0

	var pilot_penalty_rounds := int(next_condition.get("pilot_action_penalty_rounds", 0))
	if pilot_penalty_rounds > 0:
		pilot_penalty_rounds -= 1
		next_condition["pilot_action_penalty_rounds"] = pilot_penalty_rounds
		if pilot_penalty_rounds <= 0:
			next_condition["pilot_action_penalty_dice"] = 0

	var control_locked_rounds := int(next_condition.get("control_locked_rounds", 0))
	if control_locked_rounds > 0:
		control_locked_rounds -= 1
		next_condition["control_locked_rounds"] = control_locked_rounds

	updated_ship["condition"] = next_condition
	return updated_ship

func advance_contacts(state: Dictionary, contacts: Array, focus: Dictionary = {}) -> Dictionary:
	var next_state := state.duplicate(true)
	var movement_round := int(next_state.get("movement_round", 1))
	var updated_contacts: Array = []
	var events: Array = []
	var focus_position := _position_from(focus)
	var has_focus := not focus.is_empty()
	var weapon_solution_counts: Dictionary = next_state.get("weapon_solution_counts", {}).duplicate(true)

	for contact_value in contacts:
		if typeof(contact_value) != TYPE_DICTIONARY:
			updated_contacts.append(contact_value)
			continue
		var contact: Dictionary = contact_value
		var updated_contact := contact.duplicate(true)
		var movement: Dictionary = contact.get("movement", {})
		var movement_blocked_reason := _movement_blocked_reason(contact, movement)
		var can_move := movement_blocked_reason == ""
		var start_position := _position_from(contact)
		var start_heading := float(contact.get("heading_degrees", 0.0))
		var move_units := 0.0
		var turn_degrees := 0.0
		var next_heading := start_heading
		var next_position := start_position
		var tracks_focus := false
		var holds_range := false
		var distance_to_focus := start_position.distance_to(focus_position) if has_focus else 0.0
		var range_name := range_name_for_distance(distance_to_focus) if has_focus else "Unknown"
		var weapon_solution := false
		var weapon_solution_rounds := 0
		var fire_ready := false
		var fire_ready_rounds := int(movement.get("fire_ready_rounds", movement.get("lock_rounds_to_fire", 2)))
		if can_move:
			move_units = float(movement.get("move_units", movement.get("speed_units", 0.0)))
			turn_degrees = float(movement.get("turn_degrees", 0.0))
			tracks_focus = has_focus and String(movement.get("track_target", "")).strip_edges().to_lower() == "player"
			if tracks_focus:
				var desired_heading := _heading_degrees_between(start_position, focus_position)
				var max_turn := absf(float(movement.get("turn_rate_degrees", movement.get("max_turn_degrees", turn_degrees))))
				if max_turn <= 0.0:
					max_turn = 360.0
				next_heading = _turn_toward_degrees(start_heading, desired_heading, max_turn)
				turn_degrees = _shortest_signed_angle_degrees(start_heading, next_heading)
				var hold_range := float(movement.get("hold_range", movement.get("engagement_range", -1.0)))
				holds_range = hold_range >= 0.0 and distance_to_focus <= hold_range
				if holds_range:
					move_units = 0.0
					weapon_solution = bool(contact.get("counterfire", false)) and not _ship_weapons_disabled(contact)
			else:
				next_heading = fposmod(start_heading + turn_degrees, 360.0)
			var heading_radians := deg_to_rad(next_heading)
			next_position = start_position + Vector2(cos(heading_radians), sin(heading_radians)) * move_units
			updated_contact["heading_degrees"] = next_heading
			updated_contact["position"] = {"x": next_position.x, "y": next_position.y}

		var contact_id := String(contact.get("id", ""))
		if weapon_solution and contact_id != "":
			weapon_solution_rounds = int(weapon_solution_counts.get(contact_id, 0)) + 1
			weapon_solution_counts[contact_id] = weapon_solution_rounds
			fire_ready = weapon_solution_rounds >= maxi(fire_ready_rounds, 1)
		elif contact_id != "":
			weapon_solution_counts.erase(contact_id)

		var engagement_state := next_state.duplicate(true)
		engagement_state["weapon_solution_counts"] = weapon_solution_counts
		var engagement_context := engagement_context_for_contact(engagement_state, updated_contact)
		updated_contacts.append(updated_contact)
		events.append({
			"type": "space_contact_movement",
			"movement_round": movement_round,
			"contact_id": contact_id,
			"contact_name": String(contact.get("name", "Contact")),
			"can_move": can_move,
			"movement_blocked_reason": movement_blocked_reason,
			"tracks_focus": tracks_focus,
			"holds_range": holds_range,
			"weapon_solution": weapon_solution,
			"weapon_solution_rounds": weapon_solution_rounds,
			"fire_ready": fire_ready,
			"fire_ready_rounds": maxi(fire_ready_rounds, 1),
			"targeting_context": engagement_context.get("targeting", {}),
			"weapon_solution_context": engagement_context.get("weapon_solution", {}),
			"engagement_context": engagement_context,
			"distance_to_focus": distance_to_focus,
			"range_name": range_name,
			"move_units": move_units,
			"turn_degrees": turn_degrees,
			"start_heading": start_heading,
			"heading_degrees": next_heading,
			"start_position": {"x": start_position.x, "y": start_position.y},
			"position": {"x": next_position.x, "y": next_position.y},
		})

	next_state["movement_round"] = movement_round + 1
	next_state["weapon_solution_counts"] = weapon_solution_counts
	next_state["last_movement_events"] = events
	return {
		"movement_round": movement_round,
		"contacts": updated_contacts,
		"events": events,
		"state": next_state,
	}

func advance_tactical_round(state: Dictionary, player_ship: Dictionary, contacts: Array) -> Dictionary:
	var updated_player := advance_ship_condition_round(player_ship) if not player_ship.is_empty() else {}
	var conditioned_contacts: Array = []
	var condition_events: Array = []

	if not player_ship.is_empty():
		condition_events.append(_condition_tick_event(player_ship, updated_player, "player"))

	for contact_value in contacts:
		if typeof(contact_value) != TYPE_DICTIONARY:
			conditioned_contacts.append(contact_value)
			continue
		var contact: Dictionary = contact_value
		var updated_contact := advance_ship_condition_round(contact)
		conditioned_contacts.append(updated_contact)
		condition_events.append(_condition_tick_event(contact, updated_contact, "contact"))

	var movement_result: Dictionary = advance_contacts(state, conditioned_contacts, updated_player)
	var next_state: Dictionary = movement_result.get("state", state)
	var ready_fire_events := _ready_hostile_fire_events(movement_result.get("events", []))
	next_state["last_condition_tick_events"] = condition_events
	next_state["last_ready_hostile_fire_events"] = ready_fire_events
	return {
		"movement_round": movement_result.get("movement_round", int(state.get("movement_round", 1))),
		"ship": updated_player,
		"contacts": movement_result.get("contacts", conditioned_contacts),
		"events": movement_result.get("events", []),
		"condition_events": condition_events,
		"ready_hostile_fire_events": ready_fire_events,
		"state": next_state,
	}

func resolve_ready_hostile_fire(rules: Object, state: Dictionary, player_ship: Dictionary, contacts: Array, ready_events: Array, base_seed: int = -1) -> Dictionary:
	var next_state := state.duplicate(true)
	var updated_player := player_ship.duplicate(true)
	var updated_contacts := contacts.duplicate(true)
	var fire_events: Array = []
	for i in range(ready_events.size()):
		if typeof(ready_events[i]) != TYPE_DICTIONARY:
			continue
		var ready_event: Dictionary = ready_events[i]
		var contact_id := String(ready_event.get("contact_id", ""))
		var contact_index := _contact_index_by_id(updated_contacts, contact_id)
		var fire_event := {
			"type": "space_automatic_hostile_fire",
			"applies": false,
			"reason": "contact_not_found",
			"contact_id": contact_id,
			"contact_name": String(ready_event.get("contact_name", "Contact")),
			"ready_event": ready_event,
			"event": {},
			"consumed_weapon_solution": {"applies": false, "contact_id": contact_id, "prior_rounds": 0},
			"player_condition": updated_player.get("condition", empty_ship_condition()),
		}
		if contact_index < 0:
			fire_events.append(fire_event)
			continue
		var contact: Dictionary = updated_contacts[contact_index]
		var contact_condition: Dictionary = contact.get("condition", empty_ship_condition())
		if bool(contact_condition.get("destroyed", false)):
			fire_event["reason"] = "target_destroyed"
			fire_event["consumed_weapon_solution"] = _consume_weapon_solution_for_contact(next_state, contact)
			fire_events.append(fire_event)
			continue
		if _ship_weapons_disabled(contact):
			fire_event["reason"] = "weapons_disabled"
			fire_event["consumed_weapon_solution"] = _consume_weapon_solution_for_contact(next_state, contact)
			fire_events.append(fire_event)
			continue
		if bool(updated_player.get("condition", {}).get("destroyed", false)):
			fire_event["reason"] = "player_destroyed_by_prior_fire" if _automatic_fire_destroyed_player(fire_events) else "player_destroyed"
			fire_event["consumed_weapon_solution"] = _consume_weapon_solution_for_contact(next_state, contact)
			fire_event["player_condition"] = updated_player.get("condition", empty_ship_condition())
			fire_events.append(fire_event)
			continue
		if not _weapon_solution_ready_for_contact(next_state, contact):
			fire_event["reason"] = "weapon_solution_not_ready"
			fire_events.append(fire_event)
			continue
		var fire_seed := -1
		if base_seed >= 0:
			fire_seed = base_seed + (i * 101)
		var shot: Dictionary = resolve_gunnery_exchange(rules, next_state, contact, updated_player, fire_seed, false)
		next_state = shot.get("state", next_state)
		updated_player = shot.get("target", updated_player)
		var consumed_solution := _consume_weapon_solution_for_contact(next_state, contact)
		fire_event["applies"] = true
		fire_event["reason"] = "resolved"
		fire_event["exchange_seed"] = fire_seed
		fire_event["event"] = shot.get("event", {})
		fire_event["consumed_weapon_solution"] = consumed_solution
		fire_event["player_condition"] = updated_player.get("condition", empty_ship_condition())
		fire_events.append(fire_event)
	next_state["last_automatic_hostile_fire_events"] = fire_events
	return {
		"events": fire_events,
		"ship": updated_player,
		"contacts": updated_contacts,
		"state": next_state,
	}

func _automatic_fire_destroyed_player(fire_events: Array) -> bool:
	for event_value in fire_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if bool(event.get("applies", false)) and bool(event.get("player_condition", {}).get("destroyed", false)):
			return true
	return false

func _ready_hostile_fire_events(movement_events: Array) -> Array:
	var ready_events: Array = []
	for event_value in movement_events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if not bool(event.get("weapon_solution", false)) or not bool(event.get("fire_ready", false)):
			continue
		ready_events.append({
			"type": "space_ready_hostile_fire",
			"movement_round": int(event.get("movement_round", 0)),
			"contact_id": String(event.get("contact_id", "")),
			"contact_name": String(event.get("contact_name", "Contact")),
			"range_name": String(event.get("range_name", "Unknown")),
			"weapon_solution_rounds": int(event.get("weapon_solution_rounds", 0)),
			"fire_ready_rounds": int(event.get("fire_ready_rounds", 1)),
			"targeting_context": event.get("targeting_context", {}),
			"weapon_solution_context": event.get("weapon_solution_context", {}),
			"engagement_context": event.get("engagement_context", {}),
			"informational_only": true,
		})
	return ready_events

func _contact_index_by_id(contacts: Array, contact_id: String) -> int:
	for i in range(contacts.size()):
		if typeof(contacts[i]) == TYPE_DICTIONARY and String(contacts[i].get("id", "")) == contact_id:
			return i
	return -1

func resolve_crew_station_assist(rules: Object, state: Dictionary, ship: Dictionary, assist: Dictionary, assist_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if assist_seed >= 0:
		rng.seed = assist_seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var station_round := int(next_state.get("station_round", 1))
	var station := String(assist.get("station", "copilot")).strip_edges().to_lower()
	var requested_target_action := String(assist.get("target_action", "maneuver")).strip_edges()
	var target_action := _station_target_key(requested_target_action)
	var pool: Dictionary = rules.parse_pool(String(assist.get("pool", _station_assist_pool_text(ship, station))))
	var station_wound := crew_wound_penalty_for_station(ship, station)
	pool = _apply_crew_wound_penalty(rules, pool, station_wound)
	var difficulty := int(assist.get("difficulty", 10))
	var roll: Dictionary = rules.roll_pool(pool, rng)
	var success := int(roll.get("total", 0)) >= difficulty
	var bonus_pool: Dictionary = rules.parse_pool(String(assist.get("bonus_pool", "1D")))
	var station_assists: Dictionary = next_state.get("station_assists", {})
	var replaced_assist := {}
	if success and target_action != "":
		if station_assists.has(target_action):
			replaced_assist = station_assists.get(target_action, {}).duplicate(true)
		station_assists[target_action] = {
			"station": station,
			"name": String(assist.get("name", "%s assist" % station.capitalize())),
			"requested_target_action": requested_target_action,
			"target_action": target_action,
			"pool": rules.pool_to_string(bonus_pool),
			"banked_round": station_round,
		}
	next_state["station_assists"] = station_assists

	var event := {
		"type": "space_crew_station_assist",
		"station_round": station_round,
		"assist_seed": assist_seed,
		"ship_id": String(ship.get("id", "")),
		"ship_name": String(ship.get("name", "Ship")),
		"station": station,
		"assist_name": String(assist.get("name", "%s assist" % station.capitalize())),
		"requested_target_action": requested_target_action,
		"target_action": target_action,
		"assist_pool": rules.pool_to_string(pool),
		"station_wound": station_wound,
		"station_wound_penalty_dice": int(station_wound.get("penalty_dice", 0)),
		"bonus_pool": rules.pool_to_string(bonus_pool),
		"difficulty": difficulty,
		"roll": roll,
		"success": success,
		"replaced_existing": not replaced_assist.is_empty(),
		"replaced_assist": replaced_assist,
	}
	next_state["station_round"] = station_round + 1
	next_state["last_station_event"] = event
	return {
		"station_round": station_round,
		"assist_seed": assist_seed,
		"event": event,
		"ship": ship.duplicate(true),
		"state": next_state,
	}

func resolve_maneuver_action(rules: Object, state: Dictionary, ship: Dictionary, maneuver: Dictionary, maneuver_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if maneuver_seed >= 0:
		rng.seed = maneuver_seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var maneuver_round := int(next_state.get("maneuver_round", 1))
	var updated_ship := ship.duplicate(true)
	var condition: Dictionary = ship.get("condition", empty_ship_condition())
	var controls_penalty := _controls_ionized_penalty(ship)
	var maneuverability_penalty := _maneuverability_penalty(ship)
	var drives_disabled := _ship_drives_disabled(ship)
	var control_locked := int(condition.get("control_locked_rounds", 0)) > 0

	var piloting_pool: Dictionary = rules.parse_pool(String(ship.get("piloting_pool", ship.get("pilot_pool", "0D"))))
	var maneuverability_pool: Dictionary = rules.parse_pool(String(ship.get("maneuverability", ship.get("defense_pool", "0D"))))
	maneuverability_pool = _subtract_condition_dice(rules, maneuverability_pool, controls_penalty + maneuverability_penalty)
	var action_pool: Dictionary = rules.add_pools(piloting_pool, maneuverability_pool)
	action_pool = _subtract_condition_dice(rules, action_pool, int(condition.get("pilot_action_penalty_dice", 0)))
	var station_wound := crew_wound_penalty_for_action(ship, "maneuver")
	action_pool = _apply_crew_wound_penalty(rules, action_pool, station_wound)
	var station_assist: Dictionary = _consume_station_assist(rules, next_state, "maneuver")
	if bool(station_assist.get("applies", false)):
		action_pool = rules.add_pools(action_pool, station_assist.get("pool", rules.parse_pool("0D")))
	if drives_disabled or control_locked:
		action_pool = rules.parse_pool("0D")

	var current_heading := float(ship.get("heading_degrees", 0.0))
	var requested_move := float(maneuver.get("move_units", 0.0))
	var intended_heading := fposmod(current_heading + float(maneuver.get("turn_degrees", 0.0)), 360.0)
	var intended_heading_radians := deg_to_rad(intended_heading)
	var current_position := _position_from(ship)
	var intended_position := current_position + Vector2(cos(intended_heading_radians), sin(intended_heading_radians)) * requested_move
	var hazard_context := maneuver_hazard_context(current_position, intended_position, maneuver.get("hazards", []))

	var base_difficulty := int(maneuver.get("difficulty", 10))
	var modifier := int(maneuver.get("modifier", 0)) + int(hazard_context.get("difficulty_modifier", 0))
	var difficulty := base_difficulty + modifier
	var roll: Dictionary = rules.roll_pool(action_pool, rng)
	var can_maneuver := not drives_disabled and not control_locked
	var success := can_maneuver and int(roll.get("total", 0)) >= difficulty
	var failure_margin := maxi(difficulty - int(roll.get("total", 0)), 0)
	var failure := movement_failure_for_margin(failure_margin)
	var move_fraction := 1.0 if success else float(failure.get("move_fraction", 0.0))
	if not can_maneuver:
		move_fraction = 0.0

	var turn_degrees := float(maneuver.get("turn_degrees", 0.0)) if success else 0.0
	var next_heading := fposmod(current_heading + turn_degrees, 360.0)
	var actual_move := requested_move * move_fraction
	var heading_radians := deg_to_rad(next_heading)
	var next_position := current_position + Vector2(cos(heading_radians), sin(heading_radians)) * actual_move
	updated_ship["heading_degrees"] = next_heading
	updated_ship["position"] = {"x": next_position.x, "y": next_position.y}

	var next_condition := empty_ship_condition()
	for key in condition.keys():
		next_condition[key] = condition[key]
	if not success and can_maneuver:
		next_condition["pilot_action_penalty_dice"] = int(failure.get("next_round_penalty_dice", 0))
		next_condition["pilot_action_penalty_rounds"] = 1 if int(failure.get("next_round_penalty_dice", 0)) > 0 else 0
		next_condition["control_locked_rounds"] = int(failure.get("control_locked_rounds", 0))
		next_condition["last_movement_failure"] = failure
	var collision_maneuver := maneuver.duplicate(true)
	if bool(hazard_context.get("collision_possible", false)):
		collision_maneuver["collision_possible"] = true
	var collision_event := _resolve_maneuver_collision(rules, ship, next_condition, failure, collision_maneuver, rng) if not success and can_maneuver else {
		"applies": false,
		"reason": "not_failed_maneuver",
	}
	next_condition = collision_event.get("ship_condition", next_condition)
	updated_ship["condition"] = next_condition
	var break_weapon_solutions := bool(maneuver.get("break_weapon_solutions", maneuver.get("evasive", false)))
	var broken_weapon_solution_count := 0
	if success and break_weapon_solutions:
		var weapon_solution_counts: Dictionary = next_state.get("weapon_solution_counts", {})
		broken_weapon_solution_count = weapon_solution_counts.size()
		next_state["weapon_solution_counts"] = {}

	var event := {
		"type": "space_maneuver_action",
		"maneuver_round": maneuver_round,
		"maneuver_seed": maneuver_seed,
		"ship_id": String(ship.get("id", "")),
		"ship_name": String(ship.get("name", "Ship")),
		"maneuver_name": String(maneuver.get("name", "Maneuver")),
		"piloting_pool": rules.pool_to_string(piloting_pool),
		"maneuverability_pool": rules.pool_to_string(maneuverability_pool),
		"action_pool": rules.pool_to_string(action_pool),
		"station_wound": station_wound,
		"station_wound_penalty_dice": int(station_wound.get("penalty_dice", 0)),
		"station_assist": station_assist,
		"hazard_context": hazard_context,
		"difficulty": difficulty,
		"base_difficulty": base_difficulty,
		"modifier": modifier,
		"roll": roll,
		"success": success,
		"failure": failure,
		"can_maneuver": can_maneuver,
		"drives_disabled": drives_disabled,
		"control_locked": control_locked,
		"start_heading": current_heading,
		"heading_degrees": next_heading,
		"requested_move": requested_move,
		"actual_move": actual_move,
		"position": updated_ship["position"],
		"collision": collision_event,
		"break_weapon_solutions": break_weapon_solutions,
		"weapon_solutions_broken": broken_weapon_solution_count,
	}
	next_state["maneuver_round"] = maneuver_round + 1
	next_state["last_maneuver_event"] = event
	return {
		"maneuver_round": maneuver_round,
		"maneuver_seed": maneuver_seed,
		"event": event,
		"ship": updated_ship,
		"state": next_state,
	}

func repair_difficulty_for_system(ship: Dictionary, system_name: String) -> int:
	var condition: Dictionary = ship.get("condition", {})
	var system_key := _normalize_system_key(system_name)
	if (system_key == "weapons" or system_key == "weapon") and bool(condition.get("weapons_destroyed", false)):
		return -1
	var override_difficulty := _repair_difficulty_override(ship, condition, system_key)
	if override_difficulty != REPAIR_DIFFICULTY_OVERRIDE_MISSING:
		return override_difficulty
	match system_key:
		"shields":
			return _repair_difficulty_by_count(int(condition.get("shield_loss_dice", 0)), [1, 2, 3], true)
		"maneuverability":
			var maneuver_loss := int(condition.get("maneuverability_loss_dice", 0))
			if maneuver_loss <= 1:
				return REPAIR_DIFFICULTIES["easy"]
			if maneuver_loss == 2:
				return REPAIR_DIFFICULTIES["moderate"]
			return REPAIR_DIFFICULTIES["difficult"]
		"move", "space":
			var move_loss := int(condition.get("move_loss", 0))
			if move_loss >= 4:
				return REPAIR_DIFFICULTIES["very_difficult"]
			return _repair_difficulty_by_count(move_loss, [1, 2, 3], true)
		"drives", "drive":
			return REPAIR_DIFFICULTIES["difficult"]
		"hyperdrive", "hyperdrives":
			return REPAIR_DIFFICULTIES["moderate"]
		"weapons", "weapon":
			if bool(condition.get("weapons_destroyed", false)):
				return -1
			return REPAIR_DIFFICULTIES["very_difficult"]
		"generator":
			return REPAIR_DIFFICULTIES["difficult"]
		"structural":
			return REPAIR_DIFFICULTIES["very_difficult"]
		_:
			return REPAIR_DIFFICULTIES["moderate"]

func _repair_difficulty_override(ship: Dictionary, condition: Dictionary, system_key: String) -> int:
	var tables := [
		condition.get("repair_difficulties", {}),
		condition.get("system_repair_difficulties", {}),
		ship.get("repair_difficulties", {}),
		ship.get("system_repair_difficulties", {}),
	]
	for table in tables:
		if typeof(table) != TYPE_DICTIONARY:
			continue
		var parsed := _repair_difficulty_from_table(table, system_key)
		if parsed != REPAIR_DIFFICULTY_OVERRIDE_MISSING:
			return parsed
	return REPAIR_DIFFICULTY_OVERRIDE_MISSING

func _repair_difficulty_from_table(table: Dictionary, system_key: String) -> int:
	for raw_key in table.keys():
		if _normalize_system_key(String(raw_key)) != system_key:
			continue
		return _repair_difficulty_value(table.get(raw_key))
	return REPAIR_DIFFICULTY_OVERRIDE_MISSING

func _repair_difficulty_value(value: Variant) -> int:
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

func repair_quote_for_system(ship: Dictionary, system_name: String, in_combat: bool = true) -> Dictionary:
	var system_key := _normalize_system_key(system_name)
	var difficulty := repair_difficulty_for_system(ship, system_key)
	var time_estimate: Dictionary = REPAIR_TIME_BY_DIFFICULTY.get(difficulty, {"combat_rounds": 0, "bay_hours": 0})
	var yard_cost := int(_yard_repair_cost_for_system(ship, system_key, difficulty))
	return {
		"system": system_key,
		"can_field_repair": difficulty >= 0,
		"difficulty": difficulty,
		"difficulty_name": REPAIR_DIFFICULTY_NAMES.get(difficulty, "Yard Only" if difficulty < 0 else "Moderate"),
		"field_cost_credits": 0,
		"field_time_rounds": int(time_estimate.get("combat_rounds", 0)) if in_combat else 0,
		"repair_bay_time_hours": int(time_estimate.get("bay_hours", 0)),
		"yard_cost_credits": yard_cost,
		"yard_min_fee_credits": YARD_MIN_FEE,
		"source_note": "Field damage control stays free; dockyard quotes use SW_MUSH yard percentages with GG6 flat damage-cost fallback.",
	}

func first_repairable_system(condition: Dictionary) -> String:
	var systems := repairable_system_candidates(condition)
	if systems.size() > 0:
		return systems[0]
	return ""

func first_field_repairable_system(ship: Dictionary) -> String:
	var condition: Dictionary = ship.get("condition", {})
	for system_name in repairable_system_candidates(condition):
		if repair_difficulty_for_system(ship, system_name) >= 0:
			return system_name
	return ""

func repairable_system_candidates(condition: Dictionary) -> Array:
	var systems: Array = []
	if int(condition.get("shield_loss_dice", 0)) > 0:
		systems.append("shields")
	if int(condition.get("maneuverability_loss_dice", 0)) > 0:
		systems.append("maneuverability")
	if bool(condition.get("weapons_disabled", false)) and not bool(condition.get("weapons_destroyed", false)):
		systems.append("weapons")
	if bool(condition.get("drives_disabled", false)):
		systems.append("drives")
	if int(condition.get("move_loss", 0)) > 0:
		systems.append("move")
	if bool(condition.get("hyperdrive_disabled", false)) or int(condition.get("hyperdrive_calculation_penalty", 0)) > 0 or int(condition.get("astrogation_difficulty_penalty", 0)) > 0:
		systems.append("hyperdrive")
	if bool(condition.get("generator_overloading", false)):
		systems.append("generator")
	if bool(condition.get("structural_damage", false)):
		systems.append("structural")
	for custom_system in _custom_repairable_system_names(condition):
		systems.append(custom_system)
	return systems

func _normalize_system_key(system_name: String) -> String:
	return system_name.strip_edges().to_lower().replace(" ", "_")

func _custom_repairable_system_names(condition: Dictionary) -> Array:
	var custom_systems: Array = []
	for system in condition.get("repairable_systems", []):
		var system_key := _normalize_system_key(String(system))
		if system_key == "":
			continue
		if REPAIRABLE_SYSTEM_ORDER.has(system_key):
			continue
		if custom_systems.has(system_key):
			continue
		custom_systems.append(system_key)
	return custom_systems

func damage_control_target(player_ship: Dictionary, fallback_ship: Dictionary) -> Dictionary:
	var player_system := first_field_repairable_system(player_ship)
	if player_system != "":
		return {
			"role": "player",
			"ship": player_ship,
			"system": player_system,
		}

	var fallback_system := first_field_repairable_system(fallback_ship)
	if fallback_system != "":
		return {
			"role": "fallback",
			"ship": fallback_ship,
			"system": fallback_system,
		}

	return {
		"role": "none",
		"ship": {},
		"system": "",
	}

func resolve_damage_control(rules: Object, state: Dictionary, ship: Dictionary, system_name: String, repair_pool: Variant, repair_seed: int = -1, in_combat: bool = true, num_actions: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if repair_seed >= 0:
		rng.seed = repair_seed
	else:
		rng.randomize()

	var system_key := _normalize_system_key(system_name)
	var pool: Dictionary = {}
	if typeof(repair_pool) == TYPE_STRING:
		pool = rules.parse_pool(String(repair_pool))
	elif typeof(repair_pool) == TYPE_DICTIONARY:
		pool = repair_pool
	else:
		pool = rules.parse_pool("0D")
	if num_actions > 1:
		pool = rules.apply_multi_action_penalty(pool, num_actions)
	var station_wound := crew_wound_penalty_for_action(ship, "repair")
	pool = _apply_crew_wound_penalty(rules, pool, station_wound)

	var difficulty := repair_difficulty_for_system(ship, system_key)
	var can_repair := difficulty >= 0 and not bool(ship.get("condition", {}).get("destroyed", false))
	var total_difficulty := difficulty + (5 if in_combat and can_repair else 0)
	var repair_quote := repair_quote_for_system(ship, system_key, in_combat)
	var next_state := state.duplicate(true)
	var station_assist: Dictionary = _consume_station_assist(rules, next_state, "repair")
	if bool(station_assist.get("applies", false)):
		pool = rules.add_pools(pool, station_assist.get("pool", rules.parse_pool("0D")))
	var roll: Dictionary = rules.roll_pool(pool, rng)
	var success := can_repair and int(roll.get("total", 0)) >= total_difficulty
	var updated_ship := ship.duplicate(true)
	if success:
		var repaired_condition := _repair_condition_for_system(ship.get("condition", empty_ship_condition()), system_key)
		var repair_log: Array = repaired_condition.get("repair_log", [])
		repair_log.append({
			"system": system_key,
			"field_cost_credits": int(repair_quote.get("field_cost_credits", 0)),
			"field_time_rounds": int(repair_quote.get("field_time_rounds", 0)),
			"repair_bay_time_hours": int(repair_quote.get("repair_bay_time_hours", 0)),
		})
		repaired_condition["repair_log"] = repair_log
		updated_ship["condition"] = repaired_condition

	var before_summary := ship_condition_summary(ship)
	var after_summary := ship_condition_summary(updated_ship)
	next_state["last_repair_event"] = {
		"type": "space_damage_control",
		"repair_seed": repair_seed,
		"ship_id": String(ship.get("id", "")),
		"ship_name": String(ship.get("name", "Ship")),
		"system": system_key,
		"repair_pool": rules.pool_to_string(pool),
		"station_wound": station_wound,
		"station_wound_penalty_dice": int(station_wound.get("penalty_dice", 0)),
		"station_assist": station_assist,
		"difficulty": total_difficulty,
		"base_difficulty": difficulty,
		"in_combat": in_combat,
		"can_repair": can_repair,
		"repair_quote": repair_quote,
		"roll": roll,
		"success": success,
		"before_condition_summary": before_summary,
		"after_condition_summary": after_summary,
	}
	return {
		"repair_seed": repair_seed,
		"event": next_state["last_repair_event"],
		"ship": updated_ship,
		"state": next_state,
	}

func resolve_astrogation_plot(rules: Object, state: Dictionary, ship: Dictionary, action: Dictionary, plot_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if plot_seed >= 0:
		rng.seed = plot_seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var astrogation_round := int(next_state.get("astrogation_round", 1))
	var condition: Dictionary = ship.get("condition", empty_ship_condition())
	var base_difficulty := int(action.get("difficulty", 15))
	var calculation_penalty := int(condition.get("hyperdrive_calculation_penalty", 0))
	var astrogation_penalty := int(condition.get("astrogation_difficulty_penalty", 0))
	var total_difficulty := base_difficulty + calculation_penalty + astrogation_penalty
	var pool_text := String(action.get("pool", ship.get("astrogation_pool", ship.get("navigator_pool", "0D"))))
	var action_pool: Dictionary = rules.parse_pool(pool_text)
	var station_wound := crew_wound_penalty_for_action(ship, "astrogation")
	action_pool = _apply_crew_wound_penalty(rules, action_pool, station_wound)
	var station_assist: Dictionary = _consume_station_assist(rules, next_state, "astrogation")
	if bool(station_assist.get("applies", false)):
		action_pool = rules.add_pools(action_pool, station_assist.get("pool", rules.parse_pool("0D")))
	var can_plot := not bool(condition.get("destroyed", false)) and not bool(condition.get("hyperdrive_disabled", false))
	var roll: Dictionary = rules.roll_pool(action_pool, rng)
	var success := can_plot and int(roll.get("total", 0)) >= total_difficulty
	var updated_ship := ship.duplicate(true)
	var before_summary := ship_condition_summary(ship)
	var next_condition := empty_ship_condition()
	for key in condition.keys():
		next_condition[key] = condition[key]
	if success:
		next_condition["hyperdrive_calculation_penalty"] = 0
		next_condition["astrogation_difficulty_penalty"] = 0
		var nav_log: Array = next_condition.get("navigation_log", [])
		nav_log.append({
			"name": String(action.get("name", "Astrogation plot")),
			"round": astrogation_round,
			"margin": int(roll.get("total", 0)) - total_difficulty,
		})
		next_condition["navigation_log"] = nav_log
		updated_ship["condition"] = next_condition
	var after_summary := ship_condition_summary(updated_ship)
	var event := {
		"type": "space_astrogation_plot",
		"astrogation_round": astrogation_round,
		"plot_seed": plot_seed,
		"ship_id": String(ship.get("id", "")),
		"ship_name": String(ship.get("name", "Ship")),
		"plot_name": String(action.get("name", "Astrogation plot")),
		"action_pool": rules.pool_to_string(action_pool),
		"station_wound": station_wound,
		"station_wound_penalty_dice": int(station_wound.get("penalty_dice", 0)),
		"station_assist": station_assist,
		"base_difficulty": base_difficulty,
		"calculation_penalty": calculation_penalty,
		"astrogation_penalty": astrogation_penalty,
		"difficulty": total_difficulty,
		"can_plot": can_plot,
		"roll": roll,
		"success": success,
		"before_condition_summary": before_summary,
		"after_condition_summary": after_summary,
	}
	next_state["astrogation_round"] = astrogation_round + 1
	next_state["last_astrogation_event"] = event
	return {
		"astrogation_round": astrogation_round,
		"plot_seed": plot_seed,
		"event": event,
		"ship": updated_ship,
		"state": next_state,
	}

func apply_starship_damage_to_condition(rules: Object, ship: Dictionary, condition: Dictionary, starship_damage: Dictionary, system_effect: Dictionary = {}) -> Dictionary:
	var next_condition := empty_ship_condition()
	for key in condition.keys():
		next_condition[key] = condition[key]

	var damage_key := String(starship_damage.get("key", "no_damage"))
	if damage_key == "no_damage" or damage_key == "not_rolled":
		return next_condition

	if damage_key == "shields_blown_or_controls_ionized":
		_apply_shield_loss_or_controls_ionized(rules, ship, next_condition)
	elif damage_key.ends_with("controls_ionized") or damage_key == "controls_dead":
		var ion_controls := int(starship_damage.get("ion_controls", 1))
		if damage_key == "controls_dead":
			next_condition["controls_ionized"] = 99
		else:
			next_condition["controls_ionized"] = int(next_condition.get("controls_ionized", 0)) + maxi(ion_controls, 1)
		next_condition["controls_ionized_rounds"] = 2
	elif damage_key == "lightly_damaged":
		next_condition["light_damage_count"] = int(next_condition.get("light_damage_count", 0)) + 1
		next_condition["worst_hull_severity"] = maxi(int(next_condition.get("worst_hull_severity", 0)), 2)
	elif damage_key == "heavily_damaged":
		if int(next_condition.get("worst_hull_severity", 0)) >= 3:
			next_condition["severe_damage_count"] = int(next_condition.get("severe_damage_count", 0)) + 1
			next_condition["worst_hull_severity"] = maxi(int(next_condition.get("worst_hull_severity", 0)), 4)
		else:
			next_condition["heavy_damage_count"] = int(next_condition.get("heavy_damage_count", 0)) + 1
			next_condition["worst_hull_severity"] = maxi(int(next_condition.get("worst_hull_severity", 0)), 3)
	elif damage_key == "severely_damaged":
		if int(next_condition.get("worst_hull_severity", 0)) >= 4:
			next_condition["destroyed"] = true
			next_condition["worst_hull_severity"] = 5
		else:
			next_condition["severe_damage_count"] = int(next_condition.get("severe_damage_count", 0)) + 1
			next_condition["worst_hull_severity"] = maxi(int(next_condition.get("worst_hull_severity", 0)), 4)
	elif damage_key == "destroyed":
		next_condition["destroyed"] = true
		next_condition["worst_hull_severity"] = 5

	_apply_system_effect_to_condition(rules, ship, next_condition, system_effect)

	var damage_log: Array = next_condition.get("damage_log", [])
	damage_log.append(damage_key)
	next_condition["damage_log"] = damage_log
	if not system_effect.is_empty() and String(system_effect.get("key", "none")) != "none":
		var system_effects: Array = next_condition.get("system_effects", [])
		system_effects.append(system_effect)
		next_condition["system_effects"] = system_effects
	return next_condition

func resolve_shield_reroute(rules: Object, state: Dictionary, ship: Dictionary, requested_arcs: Array, reroute_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if reroute_seed >= 0:
		rng.seed = reroute_seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var shield_round := int(next_state.get("shield_round", 1))
	var unique_arcs := _unique_shield_arcs(requested_arcs)
	var difficulty := shield_difficulty_for_arc_count(unique_arcs.size())
	var shield_pool: Dictionary = rules.parse_pool(String(ship.get("starship_shields_pool", ship.get("shields_pool", "0D"))))
	var station_wound := crew_wound_penalty_for_action(ship, "shields")
	shield_pool = _apply_crew_wound_penalty(rules, shield_pool, station_wound)
	var station_assist: Dictionary = _consume_station_assist(rules, next_state, "shields")
	if bool(station_assist.get("applies", false)):
		shield_pool = rules.add_pools(shield_pool, station_assist.get("pool", rules.parse_pool("0D")))
	var roll: Dictionary = rules.roll_pool(shield_pool, rng)
	var success := int(roll["total"]) >= difficulty and unique_arcs.size() > 0
	var shield_value := String(ship.get("shields", "0D"))
	var shield_arcs := {}
	if success:
		for arc in unique_arcs:
			shield_arcs[arc] = shield_value

	var updated_ship := ship.duplicate(true)
	if success:
		updated_ship["shield_arcs"] = shield_arcs
		updated_ship.erase("incoming_arc")

	var event := {
		"type": "space_shield_reroute",
		"shield_round": shield_round,
		"reroute_seed": reroute_seed,
		"ship_id": String(ship.get("id", "")),
		"ship_name": String(ship.get("name", "Ship")),
		"requested_arcs": unique_arcs,
		"difficulty": difficulty,
		"shield_pool": rules.pool_to_string(shield_pool),
		"station_wound": station_wound,
		"station_wound_penalty_dice": int(station_wound.get("penalty_dice", 0)),
		"station_assist": station_assist,
		"roll": roll,
		"success": success,
		"shield_arcs": shield_arcs,
	}

	next_state["shield_round"] = shield_round + 1
	next_state["last_shield_event"] = event
	return {
		"shield_round": shield_round,
		"reroute_seed": reroute_seed,
		"event": event,
		"ship": updated_ship,
		"state": next_state,
	}

func resolve_sensor_sweep(rules: Object, state: Dictionary, contacts: Array, sweep_seed: int = -1, ship: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if sweep_seed >= 0:
		rng.seed = sweep_seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var scan_round := int(next_state.get("scan_round", 1))
	var sensor_pool: Dictionary = next_state.get("sensor_pool", {"dice": 4, "pips": 0})
	var station_wound := crew_wound_penalty_for_action(ship, "sensors") if not ship.is_empty() else _empty_crew_wound_penalty(["sensors"])
	sensor_pool = _apply_crew_wound_penalty(rules, sensor_pool, station_wound)
	var station_assist: Dictionary = _consume_station_assist(rules, next_state, "sensors")
	if bool(station_assist.get("applies", false)):
		sensor_pool = rules.add_pools(sensor_pool, station_assist.get("pool", rules.parse_pool("0D")))
	var sweep_roll: Dictionary = rules.roll_pool(sensor_pool, rng)
	var revealed: Array = next_state.get("revealed_contacts", []).duplicate(true)
	var newly_revealed: Array = []
	var events: Array = []
	var confidence_by_contact: Dictionary = next_state.get("sensor_contact_confidence", {}).duplicate(true)

	for contact in contacts:
		if typeof(contact) != TYPE_DICTIONARY:
			continue
		var pos: Dictionary = contact.get("position", {})
		var distance := Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0))).length()
		var range_name := range_name_for_distance(distance)
		var difficulty := int(SENSOR_DIFFICULTIES.get(range_name, 30))
		var margin := int(sweep_roll["total"]) - difficulty
		var success := margin >= 0
		var confidence := sensor_confidence_for_margin(margin)
		var event := {
			"type": "sensor_contact_check",
			"scan_round": scan_round,
			"sweep_seed": sweep_seed,
			"contact_id": String(contact.get("id", "")),
			"contact_name": String(contact.get("name", "Contact")),
			"range_name": range_name,
			"difficulty": difficulty,
			"roll_total": int(sweep_roll["total"]),
			"margin": margin,
			"success": success,
			"confidence": confidence,
			"confidence_key": String(confidence.get("key", "")),
			"confidence_name": String(confidence.get("name", "")),
		}
		events.append(event)
		if success:
			var contact_id := String(contact.get("id", ""))
			if not revealed.has(contact_id):
				revealed.append(contact_id)
				newly_revealed.append(contact_id)
			var existing: Dictionary = confidence_by_contact.get(contact_id, {})
			if sensor_confidence_rank(String(confidence.get("key", ""))) >= sensor_confidence_rank(String(existing.get("key", ""))):
				confidence_by_contact[contact_id] = confidence

	next_state["scan_round"] = scan_round + 1
	next_state["revealed_contacts"] = revealed
	next_state["sensor_contact_confidence"] = confidence_by_contact
	return {
		"scan_round": scan_round,
		"sweep_seed": sweep_seed,
		"sensor_pool": sensor_pool,
		"station_wound": station_wound,
		"station_wound_penalty_dice": int(station_wound.get("penalty_dice", 0)),
		"station_assist": station_assist,
		"roll": sweep_roll,
		"revealed_contacts": revealed,
		"newly_revealed_contacts": newly_revealed,
		"events": events,
		"state": next_state,
	}

func resolve_contact_identification(rules: Object, state: Dictionary, contact: Dictionary, action: Dictionary = {}, identify_seed: int = -1, ship: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if identify_seed >= 0:
		rng.seed = identify_seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var identification_round := int(next_state.get("identification_round", 1))
	var contact_id := String(contact.get("id", ""))
	var context := identification_context_for_contact(next_state, contact)
	var confidence_rank := int(context.get("confidence_rank", 0))
	var can_identify := contact_id != "" and (bool(context.get("revealed", false)) or confidence_rank > 0)
	var base_difficulty := int(action.get("difficulty", 15))
	var track_penalty := int(action.get("unresolved_penalty", 10)) if confidence_rank <= 0 else maxi(3 - confidence_rank, 0) * int(action.get("track_penalty_step", 5))
	var difficulty := base_difficulty + track_penalty
	var sensor_pool: Dictionary = rules.parse_pool(String(action.get("pool", rules.pool_to_string(next_state.get("sensor_pool", {"dice": 4, "pips": 0})))))
	var station_wound := crew_wound_penalty_for_action(ship, "sensors") if not ship.is_empty() else _empty_crew_wound_penalty(["sensors"])
	sensor_pool = _apply_crew_wound_penalty(rules, sensor_pool, station_wound)
	var station_assist: Dictionary = _consume_station_assist(rules, next_state, "sensors")
	if bool(station_assist.get("applies", false)):
		sensor_pool = rules.add_pools(sensor_pool, station_assist.get("pool", rules.parse_pool("0D")))
	var roll: Dictionary = rules.roll_pool(sensor_pool, rng)
	var success := can_identify and int(roll.get("total", 0)) >= difficulty
	var identity_profile := _identity_profile_for_contact(contact)
	var identified_by_contact: Dictionary = next_state.get("identified_contacts", {}).duplicate(true)
	if success:
		identified_by_contact[contact_id] = identity_profile
	next_state["identified_contacts"] = identified_by_contact

	var event := {
		"type": "space_contact_identification",
		"identification_round": identification_round,
		"identify_seed": identify_seed,
		"contact_id": contact_id,
		"contact_name": String(contact.get("name", "Contact")),
		"scan_name": String(action.get("name", "Identify contact")),
		"sensor_pool": rules.pool_to_string(sensor_pool),
		"station_wound": station_wound,
		"station_wound_penalty_dice": int(station_wound.get("penalty_dice", 0)),
		"station_assist": station_assist,
		"difficulty": difficulty,
		"base_difficulty": base_difficulty,
		"track_penalty": track_penalty,
		"roll": roll,
		"success": success,
		"can_identify": can_identify,
		"sensor_context": context,
		"identity": identity_profile if success else {},
		"informational_only": true,
	}
	next_state["identification_round"] = identification_round + 1
	next_state["last_identification_event"] = event
	return {
		"identification_round": identification_round,
		"identify_seed": identify_seed,
		"event": event,
		"state": next_state,
	}

func resolve_comms_hail(rules: Object, state: Dictionary, ship: Dictionary, contact: Dictionary, action: Dictionary = {}, hail_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if hail_seed >= 0:
		rng.seed = hail_seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var comms_round := int(next_state.get("comms_round", 1))
	var contact_id := String(contact.get("id", ""))
	var identity_context := identification_context_for_contact(next_state, contact)
	var identified := bool(identity_context.get("identified", false))
	var can_hail := contact_id != ""
	var base_difficulty := int(action.get("difficulty", 10))
	var identity_penalty := int(action.get("unidentified_penalty", 5)) if not identified else 0
	var threat_modifier := _comms_threat_modifier(contact, action)
	var difficulty := base_difficulty + identity_penalty + threat_modifier
	var pool: Dictionary = rules.parse_pool(String(action.get("pool", ship.get("communications_pool", ship.get("comms_pool", ship.get("sensors_pool", "0D"))))))
	var station_wound := crew_wound_penalty_for_action(ship, "communications")
	pool = _apply_crew_wound_penalty(rules, pool, station_wound)
	var station_assist: Dictionary = _consume_station_assist(rules, next_state, "communications")
	if bool(station_assist.get("applies", false)):
		pool = rules.add_pools(pool, station_assist.get("pool", rules.parse_pool("0D")))
	var roll: Dictionary = rules.roll_pool(pool, rng)
	var success := can_hail and int(roll.get("total", 0)) >= difficulty
	var response := _comms_response_for_contact(contact, success)
	var weapon_solution_delay := {"applies": false, "reason": "not_configured", "contact_id": contact_id, "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "remaining_rounds": 0, "reduced_by": 0}
	if success and bool(action.get("delay_weapon_solution_on_success", action.get("delay_lock_on_success", false))):
		weapon_solution_delay = _delay_weapon_solution_for_contact(
			next_state,
			contact,
			int(action.get("weapon_solution_delay_rounds", action.get("delay_rounds", 1)))
		)
	var weapon_solution_pressure := {"applies": false, "reason": "not_configured", "contact_id": contact_id, "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "current_rounds": 0, "advanced_by": 0, "fire_ready": false}
	if (not success) and can_hail and bool(action.get("advance_weapon_solution_on_failure", action.get("pressure_lock_on_failure", false))):
		weapon_solution_pressure = _advance_weapon_solution_for_contact(
			next_state,
			contact,
			int(action.get("weapon_solution_pressure_rounds", action.get("pressure_rounds", 1)))
		)
	var contact_dispositions: Dictionary = next_state.get("contact_dispositions", {}).duplicate(true)
	contact_dispositions[contact_id] = {
		"contact_id": contact_id,
		"contact_name": String(contact.get("name", "Contact")),
		"status": "responsive" if success else "unresponsive",
		"response": response,
		"round": comms_round,
		"identified": identified,
		"weapon_solution_delay": weapon_solution_delay,
		"weapon_solution_pressure": weapon_solution_pressure,
	}
	next_state["contact_dispositions"] = contact_dispositions
	var event := {
		"type": "space_comms_hail",
		"comms_round": comms_round,
		"hail_seed": hail_seed,
		"ship_id": String(ship.get("id", "")),
		"ship_name": String(ship.get("name", "Ship")),
		"contact_id": contact_id,
		"contact_name": String(contact.get("name", "Contact")),
		"hail_name": String(action.get("name", "Hail contact")),
		"communications_pool": rules.pool_to_string(pool),
		"station_wound": station_wound,
		"station_wound_penalty_dice": int(station_wound.get("penalty_dice", 0)),
		"station_assist": station_assist,
		"difficulty": difficulty,
		"base_difficulty": base_difficulty,
		"identity_penalty": identity_penalty,
		"threat_modifier": threat_modifier,
		"roll": roll,
		"success": success,
		"can_hail": can_hail,
		"identified": identified,
		"identity_context": identity_context,
		"response": response,
		"disposition": contact_dispositions.get(contact_id, {}),
		"weapon_solution_delay": weapon_solution_delay,
		"weapon_solution_pressure": weapon_solution_pressure,
		"informational_only": true,
	}
	next_state["comms_round"] = comms_round + 1
	next_state["last_comms_event"] = event
	return {
		"comms_round": comms_round,
		"hail_seed": hail_seed,
		"event": event,
		"state": next_state,
	}

func resolve_gunnery_exchange(rules: Object, state: Dictionary, attacker: Dictionary, target: Dictionary, exchange_seed: int = -1, allow_station_assist: bool = true) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if exchange_seed >= 0:
		rng.seed = exchange_seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var gunnery_round := int(next_state.get("gunnery_round", 1))
	var attacker_position := _position_from(attacker)
	var target_position := _position_from(target)
	var distance := attacker_position.distance_to(target_position)
	var range_name := range_name_for_distance(distance)
	var range_difficulty := int(SENSOR_DIFFICULTIES.get(range_name, 30))
	var attacker_scale := String(attacker.get("scale", "starfighter"))
	var target_scale := String(target.get("scale", "starfighter"))
	var attacker_controls_penalty := _controls_ionized_penalty(attacker)
	var target_controls_penalty := _controls_ionized_penalty(target)
	var attacker_weapons_disabled := _ship_weapons_disabled(attacker)
	var target_maneuverability_penalty := _maneuverability_penalty(target)
	var target_drives_disabled := _ship_drives_disabled(target)
	var target_sensor_context := targeting_context_for_contact(next_state, target)
	var sensor_targeting_applies := allow_station_assist and bool(target_sensor_context.get("sensor_targeting_required", false))
	var sensor_targeting_modifier := int(target_sensor_context.get("gunnery_difficulty_modifier", 0)) if sensor_targeting_applies else 0

	var gunnery_pool: Dictionary = rules.parse_pool(String(attacker.get("gunnery_pool", "0D")))
	var fire_control: Dictionary = rules.parse_pool(String(attacker.get("fire_control", "0D")))
	var penalized_fire_control: Dictionary = _subtract_condition_dice(rules, fire_control, attacker_controls_penalty)
	var base_attack_pool: Dictionary = rules.add_pools(gunnery_pool, penalized_fire_control)
	var attacker_station_wound := crew_wound_penalty_for_action(attacker, "gunnery")
	base_attack_pool = _apply_crew_wound_penalty(rules, base_attack_pool, attacker_station_wound)
	var station_assist := {"applies": false, "reason": "not_available"}
	if allow_station_assist:
		station_assist = _consume_station_assist(rules, next_state, "gunnery")
		if bool(station_assist.get("applies", false)):
			base_attack_pool = rules.add_pools(base_attack_pool, station_assist.get("pool", rules.parse_pool("0D")))
	if attacker_weapons_disabled:
		base_attack_pool = rules.parse_pool("0D")
	var scaled_attack_pool: Dictionary = rules.apply_scale_to_attack_pool(base_attack_pool, attacker_scale, target_scale)

	var target_defense_pool: Dictionary = rules.parse_pool(String(target.get("defense_pool", "0D")))
	target_defense_pool = _subtract_condition_dice(rules, target_defense_pool, target_controls_penalty)
	target_defense_pool = _subtract_condition_dice(rules, target_defense_pool, target_maneuverability_penalty)
	var target_station_wound := crew_wound_penalty_for_action(target, "maneuver")
	target_defense_pool = _apply_crew_wound_penalty(rules, target_defense_pool, target_station_wound)
	if target_drives_disabled:
		target_defense_pool = rules.parse_pool("0D")
	var scaled_defense_pool: Dictionary = rules.apply_scale_to_dodge_pool(target_defense_pool, attacker_scale, target_scale)
	var defense_roll: Dictionary = rules.roll_pool(scaled_defense_pool, rng)
	var attack_roll: Dictionary = rules.roll_pool(scaled_attack_pool, rng)
	var difficulty := int(defense_roll["total"])
	var defense_replaces_range := true
	if not bool(target.get("dodge_active", true)):
		difficulty = range_difficulty
		defense_replaces_range = false
	var pre_sensor_difficulty := difficulty
	difficulty += sensor_targeting_modifier

	var margin := int(attack_roll["total"]) - difficulty
	var hit := margin >= 0
	var damage_result := {}
	var target_hull := {"dice": 0, "pips": 0}
	var shield_context := {"pool": {"dice": 0, "pips": 0}, "arc": "none", "bypassed": false}
	var target_shields := {"dice": 0, "pips": 0}
	var target_base_soak := {"dice": 0, "pips": 0}
	var scaled_soak_pool := {"dice": 0, "pips": 0}
	var scaled_damage_pool := {"dice": 0, "pips": 0}
	var weapon_type := String(attacker.get("weapon_type", attacker.get("damage_type", ""))).strip_edges().to_lower()
	var starship_damage := {"key": "not_rolled", "name": "Not Rolled", "severity": 0, "ion_controls": 0}
	var system_effect := {"key": "none", "name": "None", "roll": 0}
	var passenger_damage := {"applies": false, "affected_group": "none", "damage_pool": "0D", "damage_roll": {}}
	var updated_target := target.duplicate(true)
	var target_condition: Dictionary = target.get("condition", empty_ship_condition())
	if hit:
		var damage_pool: Dictionary = rules.parse_pool(String(attacker.get("weapon_damage", "0D")))
		damage_pool = _subtract_condition_dice(rules, damage_pool, attacker_controls_penalty)
		if attacker_weapons_disabled:
			damage_pool = rules.parse_pool("0D")
		target_hull = rules.parse_pool(String(target.get("hull", "0D")))
		shield_context = _shield_context_for_attack(rules, attacker, target)
		target_shields = shield_context.get("pool", {"dice": 0, "pips": 0})
		target_base_soak = rules.add_pools(target_hull, target_shields)
		scaled_damage_pool = rules.apply_scale_to_damage_pool(damage_pool, attacker_scale, target_scale)
		scaled_soak_pool = rules.apply_scale_to_soak_pool(target_base_soak, attacker_scale, target_scale)
		damage_result = rules.resolve_damage(scaled_damage_pool, scaled_soak_pool, rng)
		starship_damage = starship_damage_for_margin(int(damage_result.get("margin", 0)), weapon_type)
		system_effect = starship_system_effect_for_damage(String(starship_damage.get("key", "")), rng.randi_range(1, 6))
		passenger_damage = _resolve_passenger_damage(rules, target, starship_damage, system_effect, rng)
		target_condition = apply_starship_damage_to_condition(rules, target, target_condition, starship_damage, system_effect)
		target_condition = _append_passenger_damage_to_condition(target_condition, passenger_damage)
		updated_target["condition"] = target_condition

	var event := {
		"type": "space_gunnery_exchange",
		"gunnery_round": gunnery_round,
		"exchange_seed": exchange_seed,
		"attacker_id": String(attacker.get("id", "")),
		"attacker_name": String(attacker.get("name", "Attacker")),
		"target_id": String(target.get("id", "")),
		"target_name": String(target.get("name", "Target")),
		"target_sensor_context": target_sensor_context,
		"target_sensor_confidence": target_sensor_context.get("confidence", {}),
		"target_sensor_confidence_key": String(target_sensor_context.get("confidence_key", "unresolved")),
		"target_sensor_confidence_name": String(target_sensor_context.get("confidence_name", "Unresolved")),
		"target_sensor_confidence_rank": int(target_sensor_context.get("confidence_rank", 0)),
		"target_has_sensor_track": bool(target_sensor_context.get("has_sensor_track", false)),
		"range_name": range_name,
		"range_difficulty": range_difficulty,
		"pre_sensor_difficulty": pre_sensor_difficulty,
		"sensor_targeting_required": bool(target_sensor_context.get("sensor_targeting_required", false)),
		"sensor_targeting_applies": sensor_targeting_applies,
		"sensor_targeting_difficulty_modifier": sensor_targeting_modifier,
		"distance": distance,
		"scale_difference": rules.scale_difference(attacker_scale, target_scale),
		"attacker_controls_penalty": attacker_controls_penalty,
		"target_controls_penalty": target_controls_penalty,
		"target_maneuverability_penalty": target_maneuverability_penalty,
		"attacker_station_wound": attacker_station_wound,
		"attacker_station_wound_penalty_dice": int(attacker_station_wound.get("penalty_dice", 0)),
		"target_station_wound": target_station_wound,
		"target_station_wound_penalty_dice": int(target_station_wound.get("penalty_dice", 0)),
		"attacker_weapons_disabled": attacker_weapons_disabled,
		"target_drives_disabled": target_drives_disabled,
		"base_attack_pool": rules.pool_to_string(base_attack_pool),
		"station_assist": station_assist,
		"scaled_attack_pool": rules.pool_to_string(scaled_attack_pool),
		"scaled_defense_pool": rules.pool_to_string(scaled_defense_pool),
		"defense_replaces_range": defense_replaces_range,
		"defense_roll": defense_roll,
		"attack_roll": attack_roll,
		"difficulty": difficulty,
		"margin": margin,
		"hit": hit,
		"target_hull_pool": rules.pool_to_string(target_hull),
		"target_shield_pool": rules.pool_to_string(target_shields),
		"target_base_soak_pool": rules.pool_to_string(target_base_soak),
		"scaled_soak_pool": rules.pool_to_string(scaled_soak_pool),
		"scaled_damage_pool": rules.pool_to_string(scaled_damage_pool),
		"shield_arc": String(shield_context.get("arc", "none")),
		"shields_bypassed": bool(shield_context.get("bypassed", false)),
		"shields_applied": int(target_shields.get("dice", 0)) > 0 or int(target_shields.get("pips", 0)) > 0,
		"starship_damage": starship_damage,
		"system_effect": system_effect,
		"passenger_damage": passenger_damage,
		"target_condition": target_condition,
		"damage": damage_result,
	}

	next_state["gunnery_round"] = gunnery_round + 1
	next_state["last_gunnery_event"] = event
	return {
		"gunnery_round": gunnery_round,
		"exchange_seed": exchange_seed,
		"event": event,
		"target": updated_target,
		"state": next_state,
	}

func resolve_gunnery_exchange_with_counterfire(rules: Object, state: Dictionary, attacker: Dictionary, target: Dictionary, exchange_seed: int = -1) -> Dictionary:
	var primary: Dictionary = resolve_gunnery_exchange(rules, state, attacker, target, exchange_seed)
	var next_state: Dictionary = primary.get("state", state)
	var updated_target: Dictionary = primary.get("target", target)
	var updated_attacker := attacker.duplicate(true)
	var primary_event: Dictionary = primary.get("event", {})
	var target_condition: Dictionary = updated_target.get("condition", {})
	var lock_disruption := _disrupt_weapon_solution_for_target(next_state, target, bool(primary_event.get("hit", false)), target_condition)
	var counterfire := {
		"applies": false,
		"reason": "not_configured",
		"event": {},
		"attacker_condition": updated_attacker.get("condition", empty_ship_condition()),
	}

	if bool(updated_target.get("counterfire", false)):
		counterfire["reason"] = "ready"
		if bool(target_condition.get("destroyed", false)):
			counterfire["reason"] = "target_destroyed"
		elif _ship_weapons_disabled(updated_target):
			counterfire["reason"] = "weapons_disabled"
		elif bool(updated_target.get("counterfire_requires_solution", false)) and not _weapon_solution_ready_for_contact(next_state, updated_target):
			counterfire["reason"] = "weapon_solution_not_ready"
		else:
			var counterfire_seed := -1
			if exchange_seed >= 0:
				counterfire_seed = exchange_seed + 7919
			var counter: Dictionary = resolve_gunnery_exchange(rules, next_state, updated_target, attacker, counterfire_seed, false)
			next_state = counter.get("state", next_state)
			updated_attacker = counter.get("target", updated_attacker)
			var consumed_solution := _consume_weapon_solution_for_contact(next_state, updated_target)
			counterfire["applies"] = true
			counterfire["reason"] = "resolved"
			counterfire["consumed_weapon_solution"] = consumed_solution
			counterfire["event"] = counter.get("event", {})
			counterfire["attacker_condition"] = updated_attacker.get("condition", empty_ship_condition())

	var exchange_event := {
		"type": "space_gunnery_exchange_with_counterfire",
		"exchange_seed": exchange_seed,
		"primary": primary_event,
		"lock_disruption": lock_disruption,
		"counterfire": counterfire,
	}
	next_state["last_gunnery_event"] = primary_event
	next_state["last_gunnery_counterfire_event"] = exchange_event
	return {
		"gunnery_round": primary.get("gunnery_round", int(state.get("gunnery_round", 1))),
		"exchange_seed": exchange_seed,
		"event": primary_event,
		"lock_disruption": lock_disruption,
		"counterfire": counterfire,
		"target": updated_target,
		"attacker": updated_attacker,
		"state": next_state,
	}

func _resolve_maneuver_collision(rules: Object, ship: Dictionary, condition: Dictionary, failure: Dictionary, maneuver: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var failure_key := String(failure.get("key", "none"))
	var collision_failure := failure_key == "minor_collision_or_wild_spin" or failure_key == "collision_or_wild_spin" or failure_key == "major_collision_or_spinout"
	var obstacle_present := bool(maneuver.get("collision_possible", maneuver.get("obstacle_present", false)))
	var speed := String(maneuver.get("speed", "cruise"))
	var damage_pool: Dictionary = collision_damage_pool_for_failure(rules, speed, failure_key)
	var hull_pool: Dictionary = rules.parse_pool(String(ship.get("hull", "0D")))
	var base_event := {
		"applies": false,
		"reason": "failure_not_collision" if not collision_failure else "wild_spin_no_obstacle",
		"failure_key": failure_key,
		"speed": speed,
		"damage_pool": rules.pool_to_string(damage_pool),
		"hull_soak_pool": rules.pool_to_string(hull_pool),
		"damage": {},
		"starship_damage": {"key": "not_rolled", "name": "Not Rolled", "severity": 0, "ion_controls": 0},
		"system_effect": {"key": "none", "name": "None", "roll": 0},
		"passenger_damage": {"applies": false, "affected_group": "none", "damage_pool": "0D", "damage_roll": {}},
		"ship_condition": condition,
	}
	if not collision_failure or not obstacle_present:
		return base_event

	var damage_result: Dictionary = rules.resolve_damage(damage_pool, hull_pool, rng)
	var starship_damage := starship_damage_for_margin(int(damage_result.get("margin", 0)))
	var system_effect := starship_system_effect_for_damage(String(starship_damage.get("key", "")), rng.randi_range(1, 6))
	var passenger_damage := _resolve_passenger_damage(rules, ship, starship_damage, system_effect, rng)
	var next_condition := apply_starship_damage_to_condition(rules, ship, condition, starship_damage, system_effect)
	next_condition = _append_passenger_damage_to_condition(next_condition, passenger_damage)
	base_event["applies"] = true
	base_event["reason"] = "collision"
	base_event["damage"] = damage_result
	base_event["starship_damage"] = starship_damage
	base_event["system_effect"] = system_effect
	base_event["passenger_damage"] = passenger_damage
	base_event["ship_condition"] = next_condition
	return base_event

func _station_target_key(target_action: String) -> String:
	var key := target_action.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	match key:
		"pilot", "piloting", "maneuver", "maneuvering", "helm", "helm_control", "evasive", "evasion", "break_lock", "course_correction", "approach_vector", "vectoring":
			return "maneuver"
		"gunner", "gunnery", "weapons", "weapon", "attack", "fire", "fire_control", "target_lock", "weapon_lock", "weapon_solution", "bracketing", "turret", "cannon":
			return "gunnery"
		"sensor", "sensors", "scan", "scanning", "identify", "identification", "id", "targeting", "targeting_solution", "sensor_lock":
			return "sensors"
		"communications", "communication", "comms", "comm", "hail", "hailing", "hail_contact", "contact_hail", "traffic", "traffic_control", "transmit", "transmission", "broadcast", "transponder", "transponder_ping":
			return "communications"
		"shield", "shields", "reroute", "shield_reroute", "starship_shields", "deflector", "deflectors", "deflector_shields", "angle_shields", "shield_angle", "shield_timing":
			return "shields"
		"engineer", "engineering", "repair", "repairs", "damage_control", "damage_control_repair", "damcon", "field_repair", "field_repairs", "patch", "patching", "systems_repair":
			return "repair"
		"navigator", "navigation", "astrogation", "astrography", "navicomputer", "nav_computer", "nav_plot", "route_plot", "course_plot", "jump_plot", "jump_calculation", "hyperdrive_calculation", "hyperspace", "hyperspace_route", "local_jump":
			return "astrogation"
		_:
			return key

func _station_candidates_for_action(target_action: String) -> Array:
	var target_key := _station_target_key(target_action)
	match target_key:
		"maneuver":
			return ["maneuver", "pilot", "helm", "copilot"]
		"gunnery":
			return ["gunnery", "gunner", "weapons", "fire_control"]
		"sensors":
			return ["sensors", "sensor", "scanner"]
		"communications":
			return ["communications", "communication", "comms", "comm"]
		"shields":
			return ["shields", "shield", "deflectors", "copilot"]
		"repair":
			return ["repair", "repairs", "engineer", "engineering", "damage_control"]
		"astrogation":
			return ["astrogation", "navigator", "navigation", "navicomputer"]
		_:
			return [target_key]

func _crew_station_key(station: String) -> String:
	return station.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

func _crew_wound_penalty_for_candidates(ship: Dictionary, candidates: Array) -> Dictionary:
	var candidate_keys := []
	for candidate_value in candidates:
		var candidate := _crew_station_key(String(candidate_value))
		if candidate != "" and not candidate_keys.has(candidate):
			candidate_keys.append(candidate)

	var condition: Dictionary = ship.get("condition", {})
	var crew_wounds: Dictionary = condition.get("crew_wounds", {})
	if candidate_keys.is_empty() or crew_wounds.is_empty():
		return _empty_crew_wound_penalty(candidate_keys)

	var crew_stations := _crew_station_lookup_by_id(ship)
	var selected := {}
	for crew_id_value in crew_wounds.keys():
		var crew_id := String(crew_id_value)
		var packet: Dictionary = crew_wounds.get(crew_id, {})
		var wound: Dictionary = packet.get("wound", {})
		var severity := int(wound.get("severity", packet.get("severity", 0)))
		if severity <= 0:
			continue
		var station := _crew_station_key(String(packet.get("station", "")))
		if station == "":
			station = String(crew_stations.get(crew_id, ""))
		var station_target := _station_target_key(station)
		if not candidate_keys.has(station) and not candidate_keys.has(station_target):
			continue
		if selected.is_empty() or severity > int(selected.get("severity", 0)):
			selected = {
				"applies": true,
				"crew_id": crew_id,
				"crew_name": String(packet.get("name", crew_id)),
				"station": station,
				"wound_name": String(wound.get("name", "Wounded")),
				"severity": severity,
				"penalty_dice": _crew_wound_penalty_dice(severity),
				"action_blocked": severity >= 3,
				"candidate_stations": candidate_keys,
			}

	if selected.is_empty():
		return _empty_crew_wound_penalty(candidate_keys)
	return selected

func _empty_crew_wound_penalty(candidate_keys: Array) -> Dictionary:
	return {
		"applies": false,
		"crew_id": "",
		"crew_name": "",
		"station": "",
		"wound_name": "",
		"severity": 0,
		"penalty_dice": 0,
		"action_blocked": false,
		"candidate_stations": candidate_keys,
	}

func _crew_station_lookup_by_id(ship: Dictionary) -> Dictionary:
	var lookup := {}
	var raw_crew: Variant = ship.get("crew", ship.get("crew_roster", ship.get("occupants", [])))
	if typeof(raw_crew) != TYPE_ARRAY:
		return lookup
	for member_value in raw_crew:
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_value
		var crew_id := String(member.get("id", member.get("name", ""))).strip_edges()
		if crew_id == "":
			continue
		lookup[crew_id] = _crew_station_key(String(member.get("station", member.get("role", ""))))
	return lookup

func _crew_wound_penalty_dice(severity: int) -> int:
	if severity <= 0:
		return 0
	if severity <= 2:
		return 1
	return 99

func _apply_crew_wound_penalty(rules: Object, pool: Dictionary, wound_context: Dictionary) -> Dictionary:
	var penalty := int(wound_context.get("penalty_dice", 0))
	if penalty <= 0:
		return pool
	return rules.apply_wound_penalty(pool, penalty)

func _identity_profile_for_contact(contact: Dictionary) -> Dictionary:
	var transponder: Dictionary = contact.get("transponder", {})
	var registry := String(transponder.get("registry", contact.get("registry", "unregistered")))
	var affiliation := String(transponder.get("affiliation", contact.get("affiliation", "unknown")))
	var declared_name := String(transponder.get("declared_name", contact.get("name", "Contact")))
	var threat := String(transponder.get("threat", "unknown"))
	var profile := String(transponder.get("profile", contact.get("status", "")))
	var masked := bool(transponder.get("masked", false))
	return {
		"declared_name": declared_name,
		"registry": registry,
		"affiliation": affiliation,
		"threat": threat,
		"profile": profile,
		"masked": masked,
		"summary": "%s / %s / %s" % [declared_name, affiliation, threat],
	}

func _comms_threat_modifier(contact: Dictionary, action: Dictionary) -> int:
	var transponder: Dictionary = contact.get("transponder", {})
	var threat := String(transponder.get("threat", contact.get("threat", "unknown"))).strip_edges().to_lower()
	var modifiers: Dictionary = action.get("threat_modifiers", {})
	if modifiers.has(threat):
		return int(modifiers.get(threat, 0))
	match threat:
		"friendly", "neutral":
			return 0
		"authority", "uncertain":
			return 5
		"hostile":
			return 10
		_:
			return 5

func _comms_response_for_contact(contact: Dictionary, success: bool) -> String:
	var comms: Dictionary = contact.get("comms", {})
	if success:
		return String(comms.get("success_response", "Acknowledges hail and keeps channel open."))
	return String(comms.get("failure_response", "No useful response."))

func _station_assist_pool_text(ship: Dictionary, station: String) -> String:
	var station_key := station.strip_edges().to_lower().replace(" ", "_")
	if ship.has("%s_assist_pool" % station_key):
		return String(ship.get("%s_assist_pool" % station_key, "0D"))
	if ship.has("%s_pool" % station_key):
		return String(ship.get("%s_pool" % station_key, "0D"))
	var crew: Array = ship.get("crew", [])
	for member_value in crew:
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_value
		var member_station := String(member.get("station", member.get("role", ""))).strip_edges().to_lower()
		if member_station == station_key:
			return String(member.get("assist_pool", member.get("pool", "0D")))
	return "0D"

func _consume_station_assist(rules: Object, state: Dictionary, target_action: String) -> Dictionary:
	var target_key := _station_target_key(target_action)
	var station_assists: Dictionary = state.get("station_assists", {})
	if target_key == "" or not station_assists.has(target_key):
		return {"applies": false, "target_action": target_key, "pool": rules.parse_pool("0D"), "pool_text": "0D"}
	var assist: Dictionary = station_assists.get(target_key, {})
	station_assists.erase(target_key)
	state["station_assists"] = station_assists
	var pool: Dictionary = rules.parse_pool(String(assist.get("pool", "0D")))
	return {
		"applies": true,
		"station": String(assist.get("station", "")),
		"name": String(assist.get("name", "Station Assist")),
		"target_action": target_key,
		"requested_target_action": String(assist.get("requested_target_action", "")),
		"pool": pool,
		"pool_text": rules.pool_to_string(pool),
		"banked_round": int(assist.get("banked_round", 0)),
	}

func _position_from(entity: Dictionary) -> Vector2:
	var pos: Dictionary = entity.get("position", {})
	return Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))

func _heading_degrees_between(from_position: Vector2, to_position: Vector2) -> float:
	var delta := to_position - from_position
	if delta.length() <= 0.001:
		return 0.0
	return fposmod(rad_to_deg(atan2(delta.y, delta.x)), 360.0)

func _shortest_signed_angle_degrees(from_degrees: float, to_degrees: float) -> float:
	return fposmod(to_degrees - from_degrees + 180.0, 360.0) - 180.0

func _turn_toward_degrees(current_degrees: float, target_degrees: float, max_turn_degrees: float) -> float:
	var delta := _shortest_signed_angle_degrees(current_degrees, target_degrees)
	var limited_delta := clampf(delta, -absf(max_turn_degrees), absf(max_turn_degrees))
	return fposmod(current_degrees + limited_delta, 360.0)

func _hazard_position(hazard: Dictionary) -> Vector2:
	var pos: Dictionary = hazard.get("position", {})
	return Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))

func _segment_intersects_circle(start_position: Vector2, end_position: Vector2, center: Vector2, radius: float) -> bool:
	var segment := end_position - start_position
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start_position.distance_to(center) <= radius
	var t := clampf((center - start_position).dot(segment) / length_squared, 0.0, 1.0)
	var closest := start_position + segment * t
	return closest.distance_to(center) <= radius

func _shield_context_for_attack(rules: Object, attacker: Dictionary, target: Dictionary) -> Dictionary:
	var weapon_type := String(attacker.get("weapon_type", attacker.get("damage_type", ""))).strip_edges().to_lower()
	if weapon_type == "ion":
		return {"pool": rules.parse_pool("0D"), "arc": "bypassed", "bypassed": true}

	var shield_arcs: Variant = target.get("shield_arcs", {})
	if typeof(shield_arcs) == TYPE_DICTIONARY:
		var incoming_arc := incoming_arc_for_gunnery(attacker, target)
		return {
			"pool": _ship_shield_pool_after_condition(rules, target, rules.parse_pool(String(shield_arcs.get(incoming_arc, shield_arcs.get("all", "0D"))))),
			"arc": incoming_arc,
			"bypassed": false,
		}

	if target.has("shields"):
		return {
			"pool": _ship_shield_pool_after_condition(rules, target, rules.parse_pool(String(target.get("shields", "0D")))),
			"arc": "all",
			"bypassed": false,
		}

	return {"pool": rules.parse_pool("0D"), "arc": "none", "bypassed": false}

func _unique_shield_arcs(requested_arcs: Array) -> Array:
	var allowed := ["front", "rear", "left", "right"]
	var result: Array = []
	for arc_value in requested_arcs:
		var arc := String(arc_value).strip_edges().to_lower()
		if allowed.has(arc) and not result.has(arc):
			result.append(arc)
	return result

func _apply_shield_loss_or_controls_ionized(rules: Object, ship: Dictionary, condition: Dictionary) -> void:
	_apply_shield_loss_or_controls_ionized_count(rules, ship, condition, 1)

func _apply_shield_loss_or_controls_ionized_count(rules: Object, ship: Dictionary, condition: Dictionary, loss_dice: int) -> void:
	var shield_pool: Dictionary = rules.parse_pool(String(ship.get("shields", "0D")))
	var shield_dice := int(shield_pool.get("dice", 0))
	for i in range(maxi(loss_dice, 0)):
		var current_loss := int(condition.get("shield_loss_dice", 0))
		if shield_dice - current_loss > 0:
			condition["shield_loss_dice"] = current_loss + 1
		else:
			condition["controls_ionized"] = int(condition.get("controls_ionized", 0)) + 1
			condition["controls_ionized_rounds"] = 2

func _apply_system_effect_to_condition(rules: Object, ship: Dictionary, condition: Dictionary, system_effect: Dictionary) -> void:
	var effect_key := String(system_effect.get("key", "none"))
	match effect_key:
		"maneuverability_minus_1d":
			_apply_maneuverability_loss_or_move_loss(rules, ship, condition, 1, 1)
		"maneuverability_minus_2d":
			_apply_maneuverability_loss_or_move_loss(rules, ship, condition, 2, 2)
		"shields_minus_1d_or_controls_ionized":
			_apply_shield_loss_or_controls_ionized_count(rules, ship, condition, 1)
		"shields_minus_2d_or_two_controls_ionized":
			_apply_shield_loss_or_controls_ionized_count(rules, ship, condition, 2)
		"move_minus_1":
			_apply_move_loss(condition, 1)
		"move_minus_2":
			_apply_move_loss(condition, 2)
		"weapon_emplacement_destroyed", "weapon_emplacement_inoperative", "fire_arc_weapons_inoperative", "fire_arc_weapons_destroyed", "disabled_weapons":
			condition["weapons_disabled"] = true
			if effect_key == "weapon_emplacement_destroyed" or effect_key == "fire_arc_weapons_destroyed":
				condition["weapons_destroyed"] = true
		"dead_in_space":
			condition["drives_disabled"] = true
			condition["move_loss"] = maxi(int(condition.get("move_loss", 0)), 4)
		"disabled_hyperdrives":
			condition["hyperdrive_disabled"] = true
		"hyperdrive_calculation_time_doubled":
			condition["hyperdrive_calculation_penalty"] = maxi(int(condition.get("hyperdrive_calculation_penalty", 0)), 1)
		"hyperdrive_astrogation_plus_10":
			condition["astrogation_difficulty_penalty"] = maxi(int(condition.get("astrogation_difficulty_penalty", 0)), 10)
		"overloaded_generator":
			condition["generator_overloading"] = true
		"structural_damage":
			condition["structural_damage"] = true
		"destroyed":
			condition["destroyed"] = true
			condition["worst_hull_severity"] = 5

func _apply_maneuverability_loss_or_move_loss(rules: Object, ship: Dictionary, condition: Dictionary, loss_dice: int, move_loss_if_zero: int) -> void:
	var maneuverability_pool: Dictionary = rules.parse_pool(String(ship.get("maneuverability", ship.get("defense_pool", "0D"))))
	var available_dice := int(maneuverability_pool.get("dice", 0)) - int(condition.get("maneuverability_loss_dice", 0))
	if available_dice > 0:
		condition["maneuverability_loss_dice"] = int(condition.get("maneuverability_loss_dice", 0)) + loss_dice
	else:
		_apply_move_loss(condition, move_loss_if_zero)

func _apply_move_loss(condition: Dictionary, move_loss: int) -> void:
	condition["move_loss"] = int(condition.get("move_loss", 0)) + maxi(move_loss, 0)
	if int(condition.get("move_loss", 0)) >= 4:
		condition["drives_disabled"] = true
	if int(condition.get("move_loss", 0)) >= 5:
		condition["destroyed"] = true
		condition["worst_hull_severity"] = 5

func _controls_ionized_penalty(ship: Dictionary) -> int:
	var condition: Dictionary = ship.get("condition", {})
	var controls := int(condition.get("controls_ionized", 0))
	if controls >= 99:
		return 99
	return maxi(controls, 0)

func _ship_shield_pool_after_condition(rules: Object, ship: Dictionary, shield_pool: Dictionary) -> Dictionary:
	var condition: Dictionary = ship.get("condition", {})
	var penalty := int(condition.get("shield_loss_dice", 0)) + _controls_ionized_penalty(ship)
	return _subtract_condition_dice(rules, shield_pool, penalty)

func _maneuverability_penalty(ship: Dictionary) -> int:
	var condition: Dictionary = ship.get("condition", {})
	return maxi(int(condition.get("maneuverability_loss_dice", 0)), 0)

func _contact_requires_sensor_targeting(contact: Dictionary) -> bool:
	return bool(contact.get("sensor_targeting_required", contact.get("hidden_until_revealed", false)))

func _ship_weapons_disabled(ship: Dictionary) -> bool:
	var condition: Dictionary = ship.get("condition", {})
	return bool(condition.get("destroyed", false)) or bool(condition.get("weapons_disabled", false))

func _ship_drives_disabled(ship: Dictionary) -> bool:
	var condition: Dictionary = ship.get("condition", {})
	return bool(condition.get("destroyed", false)) or bool(condition.get("drives_disabled", false))

func _movement_blocked_reason(ship: Dictionary, movement: Dictionary) -> String:
	if movement.is_empty():
		return "no_movement_profile"
	var condition: Dictionary = ship.get("condition", {})
	if bool(condition.get("destroyed", false)):
		return "destroyed"
	if bool(condition.get("drives_disabled", false)):
		return "drives_disabled"
	if int(condition.get("control_locked_rounds", 0)) > 0:
		return "control_locked"
	return ""

func _subtract_condition_dice(rules: Object, pool: Dictionary, penalty_dice: int) -> Dictionary:
	if penalty_dice <= 0:
		return pool
	return rules.subtract_pools(pool, {"dice": penalty_dice, "pips": 0})

func _resolve_passenger_damage(rules: Object, ship: Dictionary, starship_damage: Dictionary, system_effect: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var damage_key := String(starship_damage.get("key", "no_damage"))
	var pool: Dictionary = passenger_damage_pool_for_starship_damage(damage_key)
	var applies := int(pool.get("dice", 0)) > 0 or int(pool.get("pips", 0)) > 0
	var roll := {}
	var affected_group := passenger_damage_group_for_system_effect(system_effect) if applies else "none"
	var member_wounds: Array = []
	if applies:
		roll = rules.roll_pool(pool, rng)
		member_wounds = _resolve_crew_member_wounds(rules, ship, affected_group, roll, rng)
	return {
		"applies": applies,
		"affected_group": affected_group,
		"damage_pool": rules.pool_to_string(pool),
		"damage_roll": roll,
		"member_wounds": member_wounds,
	}

func _append_passenger_damage_to_condition(condition: Dictionary, passenger_damage: Dictionary) -> Dictionary:
	if not bool(passenger_damage.get("applies", false)):
		return condition
	var next_condition := empty_ship_condition()
	for key in condition.keys():
		next_condition[key] = condition[key]
	var passenger_damage_log: Array = next_condition.get("passenger_damage_log", [])
	passenger_damage_log.append(passenger_damage)
	next_condition["passenger_damage_log"] = passenger_damage_log
	var crew_wounds: Dictionary = next_condition.get("crew_wounds", {})
	for member_wound in passenger_damage.get("member_wounds", []):
		if typeof(member_wound) != TYPE_DICTIONARY:
			continue
		var member_id := String(member_wound.get("id", ""))
		if member_id == "":
			continue
		var existing: Dictionary = crew_wounds.get(member_id, {})
		if int(member_wound.get("severity", 0)) >= int(existing.get("severity", -1)):
			crew_wounds[member_id] = member_wound
	next_condition["crew_wounds"] = crew_wounds
	return next_condition

func _resolve_crew_member_wounds(rules: Object, ship: Dictionary, affected_group: String, damage_roll: Dictionary, rng: RandomNumberGenerator) -> Array:
	var wounds: Array = []
	var members := _crew_members_for_damage_group(ship, affected_group)
	for member in members:
		var soak_pool: Dictionary = rules.parse_pool(String(member.get("soak", member.get("strength", "2D"))))
		var soak_roll: Dictionary = rules.roll_pool(soak_pool, rng)
		var margin := int(damage_roll.get("total", 0)) - int(soak_roll.get("total", 0))
		var wound: Dictionary = rules.wound_for_damage_margin(margin)
		wounds.append({
			"id": String(member.get("id", member.get("name", ""))).strip_edges(),
			"name": String(member.get("name", member.get("id", "Crew"))),
			"station": String(member.get("station", member.get("role", ""))),
			"affected_group": affected_group,
			"soak_pool": rules.pool_to_string(soak_pool),
			"soak_roll": soak_roll,
			"margin": margin,
			"wound": wound,
			"severity": int(wound.get("severity", 0)),
		})
	return wounds

func _crew_members_for_damage_group(ship: Dictionary, affected_group: String) -> Array:
	var crew: Array = []
	var raw_crew: Variant = ship.get("crew", ship.get("crew_roster", ship.get("occupants", [])))
	if typeof(raw_crew) != TYPE_ARRAY:
		return crew
	var group_key := affected_group.strip_edges().to_lower()
	for member_value in raw_crew:
		if typeof(member_value) != TYPE_DICTIONARY:
			continue
		var member: Dictionary = member_value
		var explicit_group := String(member.get("damage_group", member.get("group", ""))).strip_edges().to_lower()
		var station := String(member.get("station", member.get("role", ""))).strip_edges().to_lower()
		if group_key == "gunners":
			if explicit_group == "gunners" or explicit_group == "gunner" or station == "gunner":
				crew.append(member)
		elif group_key == "passengers":
			if explicit_group == "passengers" or explicit_group == "passenger" or (explicit_group == "" and station != "gunner"):
				crew.append(member)
	return crew

func _repair_difficulty_by_count(count: int, thresholds: Array, easy_for_first: bool) -> int:
	if count <= 0:
		return REPAIR_DIFFICULTIES["easy"] if easy_for_first else REPAIR_DIFFICULTIES["moderate"]
	if count <= int(thresholds[0]):
		return REPAIR_DIFFICULTIES["easy"]
	if thresholds.size() > 1 and count <= int(thresholds[1]):
		return REPAIR_DIFFICULTIES["moderate"]
	if thresholds.size() > 2 and count <= int(thresholds[2]):
		return REPAIR_DIFFICULTIES["difficult"]
	return REPAIR_DIFFICULTIES["very_difficult"]

func _yard_repair_cost_for_system(ship: Dictionary, system_key: String, difficulty: int) -> int:
	var condition: Dictionary = ship.get("condition", {})
	var base_cost := int(ship.get("base_cost_credits", ship.get("template_cost", ship.get("cost", 0))))
	var pct := YARD_DAMAGED_SYSTEM_PCT
	if difficulty < 0 or bool(condition.get("%s_destroyed" % system_key, false)):
		pct = YARD_DESTROYED_SYSTEM_PCT
	var percent_cost := int(round(maxi(base_cost, 0) * pct))
	var fallback_cost := _gg6_fallback_repair_cost(condition, difficulty)
	var raw_cost := percent_cost if percent_cost > 0 else fallback_cost
	if raw_cost <= 0:
		return 0
	return maxi(raw_cost, YARD_MIN_FEE)

func _gg6_fallback_repair_cost(condition: Dictionary, difficulty: int) -> int:
	var severity := int(condition.get("worst_hull_severity", 0))
	if severity >= 2:
		return int(GG6_DAMAGE_REPAIR_COSTS.get(clampi(severity, 2, 5), 3000))
	if difficulty == REPAIR_DIFFICULTIES["easy"]:
		return 1000
	if difficulty == REPAIR_DIFFICULTIES["moderate"]:
		return 2000
	if difficulty == REPAIR_DIFFICULTIES["difficult"] or difficulty == REPAIR_DIFFICULTIES["very_difficult"]:
		return 3000
	return 0

func _repair_condition_for_system(condition: Dictionary, system_key: String) -> Dictionary:
	var next_condition := empty_ship_condition()
	for key in condition.keys():
		next_condition[key] = condition[key]
	var retained_repairable_systems: Array = []
	for system in next_condition.get("repairable_systems", []):
		var retained_system_key := _normalize_system_key(String(system))
		if retained_system_key == "" or retained_system_key == system_key:
			continue
		if not retained_repairable_systems.has(retained_system_key):
			retained_repairable_systems.append(retained_system_key)
	next_condition["repairable_systems"] = retained_repairable_systems
	match system_key:
		"shields":
			next_condition["shield_loss_dice"] = 0
		"maneuverability":
			next_condition["maneuverability_loss_dice"] = 0
		"move", "space":
			next_condition["move_loss"] = 0
			next_condition["drives_disabled"] = false
		"drives", "drive":
			next_condition["drives_disabled"] = false
			next_condition["move_loss"] = 0
		"hyperdrive", "hyperdrives":
			next_condition["hyperdrive_disabled"] = false
			next_condition["hyperdrive_calculation_penalty"] = 0
			next_condition["astrogation_difficulty_penalty"] = 0
		"weapons", "weapon":
			if not bool(next_condition.get("weapons_destroyed", false)):
				next_condition["weapons_disabled"] = false
		"generator":
			next_condition["generator_overloading"] = false
		"structural":
			next_condition["structural_damage"] = false
	return next_condition

func _condition_tick_event(ship: Dictionary, updated_ship: Dictionary, role: String) -> Dictionary:
	var before_condition: Dictionary = ship.get("condition", empty_ship_condition())
	var after_condition: Dictionary = updated_ship.get("condition", empty_ship_condition())
	var before_summary: Dictionary = ship_condition_summary({"condition": before_condition})
	var after_summary: Dictionary = ship_condition_summary({"condition": after_condition})
	return {
		"type": "space_condition_tick",
		"role": role,
		"ship_id": String(ship.get("id", "")),
		"ship_name": String(ship.get("name", "Ship")),
		"changed": before_condition != after_condition,
		"before_condition": before_condition,
		"after_condition": after_condition,
		"before_summary": String(before_summary.get("text", "Operational")),
		"after_summary": String(after_summary.get("text", "Operational")),
	}

func _disrupt_weapon_solution_for_target(state: Dictionary, target: Dictionary, hit: bool, target_condition: Dictionary) -> Dictionary:
	var target_id := String(target.get("id", ""))
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	var prior_rounds := int(counts.get(target_id, 0)) if target_id != "" else 0
	var weapons_disabled := bool(target_condition.get("destroyed", false)) or bool(target_condition.get("weapons_disabled", false))
	var disrupted := target_id != "" and prior_rounds > 0 and (hit or weapons_disabled)
	if disrupted:
		counts = counts.duplicate(true)
		counts.erase(target_id)
		state["weapon_solution_counts"] = counts
	return {
		"applies": disrupted,
		"target_id": target_id,
		"prior_rounds": prior_rounds,
		"reason": "hit" if hit else "weapons_disabled" if weapons_disabled else "none",
	}

func _weapon_solution_ready_for_contact(state: Dictionary, contact: Dictionary) -> bool:
	var contact_id := String(contact.get("id", ""))
	if contact_id == "":
		return false
	var movement: Dictionary = contact.get("movement", {})
	var required_rounds := int(movement.get("fire_ready_rounds", movement.get("lock_rounds_to_fire", 2)))
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	return int(counts.get(contact_id, 0)) >= maxi(required_rounds, 1)

func _consume_weapon_solution_for_contact(state: Dictionary, contact: Dictionary) -> Dictionary:
	var contact_id := String(contact.get("id", ""))
	if contact_id == "":
		return {"applies": false, "contact_id": "", "prior_rounds": 0}
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	if not counts.has(contact_id):
		return {"applies": false, "contact_id": contact_id, "prior_rounds": 0}
	var prior_rounds := int(counts.get(contact_id, 0))
	counts = counts.duplicate(true)
	counts.erase(contact_id)
	state["weapon_solution_counts"] = counts
	return {"applies": true, "contact_id": contact_id, "prior_rounds": prior_rounds}

func _delay_weapon_solution_for_contact(state: Dictionary, contact: Dictionary, delay_rounds: int) -> Dictionary:
	var contact_id := String(contact.get("id", ""))
	if contact_id == "":
		return {"applies": false, "reason": "no_contact", "contact_id": "", "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "remaining_rounds": 0, "reduced_by": 0}
	if delay_rounds <= 0:
		return {"applies": false, "reason": "not_configured", "contact_id": contact_id, "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "remaining_rounds": 0, "reduced_by": 0}
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	var prior_rounds := int(counts.get(contact_id, 0))
	if prior_rounds <= 0:
		return {"applies": false, "reason": "no_weapon_solution", "contact_id": contact_id, "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "remaining_rounds": 0, "reduced_by": 0}
	var reduced_by := mini(delay_rounds, prior_rounds)
	var remaining_rounds := maxi(prior_rounds - reduced_by, 0)
	counts = counts.duplicate(true)
	if remaining_rounds > 0:
		counts[contact_id] = remaining_rounds
	else:
		counts.erase(contact_id)
	state["weapon_solution_counts"] = counts
	return {
		"applies": true,
		"reason": "comms_delay",
		"contact_id": contact_id,
		"contact_name": String(contact.get("name", "Contact")),
		"prior_rounds": prior_rounds,
		"remaining_rounds": remaining_rounds,
		"reduced_by": reduced_by,
	}

func _advance_weapon_solution_for_contact(state: Dictionary, contact: Dictionary, pressure_rounds: int) -> Dictionary:
	var contact_id := String(contact.get("id", ""))
	if contact_id == "":
		return {"applies": false, "reason": "no_contact", "contact_id": "", "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "current_rounds": 0, "advanced_by": 0, "fire_ready": false}
	if pressure_rounds <= 0:
		return {"applies": false, "reason": "not_configured", "contact_id": contact_id, "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "current_rounds": 0, "advanced_by": 0, "fire_ready": false}
	if not bool(contact.get("counterfire", false)):
		return {"applies": false, "reason": "not_armed", "contact_id": contact_id, "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "current_rounds": 0, "advanced_by": 0, "fire_ready": false}
	if _ship_weapons_disabled(contact):
		return {"applies": false, "reason": "weapons_disabled", "contact_id": contact_id, "contact_name": String(contact.get("name", "Contact")), "prior_rounds": 0, "current_rounds": 0, "advanced_by": 0, "fire_ready": false}
	var movement: Dictionary = contact.get("movement", {})
	var required_rounds := maxi(int(movement.get("fire_ready_rounds", movement.get("lock_rounds_to_fire", 2))), 1)
	var counts: Dictionary = state.get("weapon_solution_counts", {})
	var prior_rounds := int(counts.get(contact_id, 0))
	if prior_rounds >= required_rounds:
		return {"applies": false, "reason": "already_ready", "contact_id": contact_id, "contact_name": String(contact.get("name", "Contact")), "prior_rounds": prior_rounds, "current_rounds": prior_rounds, "advanced_by": 0, "fire_ready": true, "fire_ready_rounds": required_rounds}
	var advanced_by := mini(pressure_rounds, required_rounds - prior_rounds)
	var current_rounds := prior_rounds + advanced_by
	counts = counts.duplicate(true)
	counts[contact_id] = current_rounds
	state["weapon_solution_counts"] = counts
	return {
		"applies": true,
		"reason": "comms_pressure",
		"contact_id": contact_id,
		"contact_name": String(contact.get("name", "Contact")),
		"prior_rounds": prior_rounds,
		"current_rounds": current_rounds,
		"advanced_by": advanced_by,
		"fire_ready_rounds": required_rounds,
		"fire_ready": current_rounds >= required_rounds,
	}
