extends RefCounted

const WOUND_NAMES := ["OK", "Stunned", "Wounded", "Incapacitated", "Mortally Wounded", "Killed"]

static func target_feedback(exchange: Dictionary) -> Dictionary:
	if bool(exchange.get("already_disabled", false)):
		return {
			"visible": true,
			"text": "DISABLED",
			"location": "torso",
			"tone": "disabled",
		}
	if bool(exchange.get("player_attack_skipped", false)):
		return {"visible": false}
	var attack: Dictionary = exchange.get("attack", {})
	var margin := int(attack.get("margin", 0))
	if bool(attack.get("blocked", false)):
		return {
			"visible": true,
			"text": "BLOCKED",
			"location": "torso",
			"tone": "blocked",
		}
	if not bool(attack.get("success", false)):
		return {
			"visible": true,
			"text": "MISS %s" % _signed_number(margin),
			"location": "torso",
			"tone": "miss",
		}

	var target_state: Dictionary = exchange.get("target_state", {})
	var location := String(target_state.get("hit_location", "torso"))
	var armor_applied := bool(target_state.get("armor_applied", false))
	var wound: Dictionary = exchange.get("target_wound", {})
	var wound_name := String(wound.get("name", _wound_name(int(target_state.get("wound_severity", 0)))))
	var armor_text := "armor" if armor_applied else "unarmored"
	var degraded := int(target_state.get("armor_degraded_pips", 0))
	if degraded > 0:
		armor_text += " %+d->%+d" % [
			int(target_state.get("armor_quality_pips_before", 0)),
			int(target_state.get("armor_quality_pips_after", target_state.get("armor_quality_pips", 0))),
		]
	return {
		"visible": true,
		"text": "HIT %s | %s | %s" % [_location_text(location), armor_text, wound_name],
		"location": location,
		"tone": "hit_armor" if armor_applied else "hit_unarmored",
	}

static func location_offset(location: String) -> Vector3:
	match _normalized_location(location):
		"head":
			return Vector3(0.0, 0.82, -0.34)
		"left_arm":
			return Vector3(-0.54, -0.05, -0.34)
		"right_arm":
			return Vector3(0.54, -0.05, -0.34)
		"left_leg":
			return Vector3(-0.28, -0.92, -0.34)
		"right_leg":
			return Vector3(0.28, -0.92, -0.34)
		_:
			return Vector3(0.0, -0.08, -0.34)

static func tone_color(tone: String) -> Color:
	match tone:
		"hit_armor":
			return Color(0.38, 0.82, 1.0)
		"hit_unarmored":
			return Color(1.0, 0.72, 0.24)
		"miss":
			return Color(0.72, 0.74, 0.76)
		"blocked":
			return Color(0.58, 0.66, 0.96)
		"disabled":
			return Color(1.0, 0.24, 0.18)
		_:
			return Color(1.0, 0.9, 0.5)

static func damage_part_names(location: String) -> PackedStringArray:
	match _normalized_location(location):
		"head":
			return PackedStringArray(["DamagePart_head"])
		"left_arm":
			return PackedStringArray(["DamagePart_left_arm", "DamagePart_arms", "DamagePart_torso"])
		"right_arm":
			return PackedStringArray(["DamagePart_right_arm", "DamagePart_arms", "DamagePart_torso"])
		"left_leg":
			return PackedStringArray(["DamagePart_left_leg", "DamagePart_legs", "DamagePart_torso"])
		"right_leg":
			return PackedStringArray(["DamagePart_right_leg", "DamagePart_legs", "DamagePart_torso"])
		_:
			return PackedStringArray(["DamagePart_torso", "DamagePart_full"])

static func persistent_damage_color(armor_applied: bool, wound_severity: int) -> Color:
	if wound_severity >= 3:
		return Color(0.22, 0.04, 0.035)
	if armor_applied:
		return Color(0.22, 0.52, 0.68)
	if wound_severity >= 2:
		return Color(0.72, 0.25, 0.12)
	return Color(0.78, 0.5, 0.18)

static func persistent_damage_marker(location: String, armor_applied: bool, wound_severity: int) -> Dictionary:
	var clamped_severity := mini(maxi(wound_severity, 0), 4)
	var radius := 0.075 + float(clamped_severity) * 0.035
	if armor_applied:
		radius += 0.025
	return {
		"visible": true,
		"location": _normalized_location(location),
		"offset": location_offset(location),
		"color": persistent_damage_color(armor_applied, wound_severity),
		"radius": radius,
		"emission": 0.26 if armor_applied else 0.18,
	}

static func _location_text(location: String) -> String:
	return _normalized_location(location).replace("_", " ")

static func _normalized_location(location: String) -> String:
	var cleaned := location.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if cleaned == "":
		return "torso"
	return cleaned

static func _signed_number(value: int) -> String:
	return "+%d" % value if value >= 0 else "%d" % value

static func _wound_name(severity: int) -> String:
	if severity >= 0 and severity < WOUND_NAMES.size():
		return WOUND_NAMES[severity]
	return WOUND_NAMES[WOUND_NAMES.size() - 1]
