extends RefCounted

const ArmorConditionModel = preload("res://scripts/rules/armor_condition_model.gd")
const RangeStateBadgeModel = preload("res://scripts/rules/range_state_badge_model.gd")

const WOUND_NAMES := {
	0: "OK",
	1: "Stunned",
	2: "Wounded",
	3: "Incapacitated",
	4: "Mortally Wounded",
}

static func target_text(target_name: String, target_profile_key: String, cover_level: int, wound_severity: int, armor_quality_pips: int, profile: Dictionary, behavior_context: Dictionary = {}) -> String:
	var profile_name := String(profile.get("name", target_profile_key))
	var source_note := String(profile.get("source_note", "")).strip_edges()
	var parts := PackedStringArray([
		"%s: %s" % [target_name, profile_name],
		"scale %s" % String(profile.get("scale", "character")),
		"cover %d" % maxi(cover_level, 0),
		"wound %s" % String(WOUND_NAMES.get(wound_severity, "Down")),
		"soak %s" % _pool_text(profile.get("soak_pool", {})),
		_armor_text(profile.get("armor", {}), armor_quality_pips),
		_fire_text(profile),
	])
	var behavior_text := _behavior_text(behavior_context)
	if behavior_text != "":
		parts.append(behavior_text)
	if source_note != "":
		parts.append(source_note)
	return " | ".join(parts)

static func _behavior_text(context: Dictionary) -> String:
	if context.is_empty():
		return ""
	var current_state := String(context.get("current_state", "inert"))
	var next_state := String(context.get("next_state", current_state))
	var current_badge: Dictionary = RangeStateBadgeModel.badge_for_state(current_state)
	var next_badge: Dictionary = RangeStateBadgeModel.badge_for_state(next_state)
	var paused_text := " paused" if not bool(context.get("live_enabled", true)) else ""
	return "live%s %s now (%s), next %s" % [
		paused_text,
		String(current_badge.get("text", current_state.to_upper())),
		RangeStateBadgeModel.explanation_for_state(current_state),
		String(next_badge.get("text", next_state.to_upper())),
	]

static func _fire_text(profile: Dictionary) -> String:
	var attack_pool: Dictionary = profile.get("attack_pool", {})
	var damage_pool: Dictionary = profile.get("damage_pool", {})
	if not _pool_has_value(attack_pool) or not _pool_has_value(damage_pool):
		return "inert target"
	return "armed %s atk %s dmg %s" % [
		String(profile.get("weapon_name", "Weapon")),
		_pool_text(attack_pool),
		_pool_text(damage_pool),
	]

static func _armor_text(armor: Dictionary, armor_quality_pips: int) -> String:
	if armor.is_empty() or not ArmorConditionModel.has_soak_protection(armor):
		return "armor none"
	return "%s covers %s q %+d" % [
		String(armor.get("name", "Armor")),
		_coverage_text(ArmorConditionModel.covered_locations(armor)),
		armor_quality_pips,
	]

static func _coverage_text(locations: Array) -> String:
	if locations.is_empty():
		return "none"
	var labels := PackedStringArray()
	for location in locations:
		labels.append(String(location).replace("_", " "))
	return ", ".join(labels)

static func _pool_text(pool: Dictionary) -> String:
	var dice := int(pool.get("dice", 0))
	var pips := int(pool.get("pips", 0))
	var text := "%dD" % dice
	if pips > 0:
		text += "+%d" % pips
	elif pips < 0:
		text += "%d" % pips
	return text

static func _pool_has_value(pool: Dictionary) -> bool:
	return int(pool.get("dice", 0)) > 0 or int(pool.get("pips", 0)) != 0
