extends RefCounted

const MIN_QUALITY_PIPS := -6
const MAX_QUALITY_PIPS := 6
const LOCATION_FULL := "full"
const LOCATION_TORSO := "torso"
const LOCATION_HEAD := "head"
const LOCATION_LEFT_ARM := "left_arm"
const LOCATION_RIGHT_ARM := "right_arm"
const LOCATION_LEFT_LEG := "left_leg"
const LOCATION_RIGHT_LEG := "right_leg"
const DEFAULT_HIT_LOCATIONS := [
	LOCATION_TORSO,
	LOCATION_RIGHT_ARM,
	LOCATION_LEFT_ARM,
	LOCATION_RIGHT_LEG,
	LOCATION_LEFT_LEG,
	LOCATION_HEAD,
]

static func has_soak_protection(armor: Dictionary) -> bool:
	return _pool_text_has_pips(String(armor.get("protection_energy", armor.get("energy", "0D")))) or _pool_text_has_pips(String(armor.get("protection_physical", armor.get("physical", "0D"))))

static func normalize_location(location: String) -> String:
	var cleaned := location.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if cleaned == "" or cleaned == "all" or cleaned == "body" or cleaned == "covered":
		return LOCATION_FULL
	if cleaned == "chest" or cleaned == "abdomen" or cleaned == "body_armor":
		return LOCATION_TORSO
	if cleaned == "helmet" or cleaned == "face":
		return LOCATION_HEAD
	if cleaned == "left_hand":
		return LOCATION_LEFT_ARM
	if cleaned == "right_hand":
		return LOCATION_RIGHT_ARM
	if cleaned == "left_foot":
		return LOCATION_LEFT_LEG
	if cleaned == "right_foot":
		return LOCATION_RIGHT_LEG
	return cleaned

static func covered_locations(armor: Dictionary) -> Array:
	if armor.is_empty() or not has_soak_protection(armor):
		return []
	if not armor.has("coverage"):
		return [LOCATION_FULL]
	var coverage: Variant = armor.get("coverage", [])
	var raw_locations: Array = []
	if typeof(coverage) == TYPE_ARRAY:
		raw_locations = coverage
	elif typeof(coverage) == TYPE_STRING:
		raw_locations = String(coverage).split(",", false)
	else:
		raw_locations = [coverage]
	var locations := []
	for raw_location in raw_locations:
		var normalized := normalize_location(String(raw_location))
		if normalized != "" and not locations.has(normalized):
			locations.append(normalized)
	return locations

static func covers_location(armor: Dictionary, location: String) -> bool:
	var normalized := normalize_location(location)
	var locations := covered_locations(armor)
	if locations.has(LOCATION_FULL):
		return true
	if locations.has(normalized):
		return true
	if (normalized == LOCATION_LEFT_ARM or normalized == LOCATION_RIGHT_ARM) and locations.has("arms"):
		return true
	if (normalized == LOCATION_LEFT_LEG or normalized == LOCATION_RIGHT_LEG) and locations.has("legs"):
		return true
	return false

static func armor_for_location(armor: Dictionary, location: String) -> Dictionary:
	if covers_location(armor, location):
		return armor
	return {}

static func hit_location_for_attack(attack: Dictionary, override_location: String = "") -> String:
	var override := normalize_location(override_location)
	if override != "" and override != LOCATION_FULL:
		return override
	var attack_roll: Dictionary = attack.get("attack", {})
	var total := int(attack_roll.get("total", attack.get("attack_total", attack.get("total", 0))))
	return DEFAULT_HIT_LOCATIONS[absi(total) % DEFAULT_HIT_LOCATIONS.size()]

static func degradation_pips_for_damage(armor: Dictionary, damage: Dictionary) -> int:
	if not has_soak_protection(armor) or int(damage.get("margin", 0)) <= 0:
		return 0
	var wound: Dictionary = damage.get("wound", {})
	var severity := int(wound.get("severity", 0))
	if severity >= 3:
		return 2
	return 1

static func apply_degradation(state: Dictionary, quality_key: String, armor: Dictionary, damage: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var degraded := degradation_pips_for_damage(armor, damage)
	if degraded <= 0:
		next["armor_degraded_pips"] = 0
		next["armor_quality_pips_before"] = int(next.get(quality_key, 0))
		next["armor_quality_pips_after"] = int(next.get(quality_key, 0))
		return next
	var before := clampi(int(next.get(quality_key, 0)), MIN_QUALITY_PIPS, MAX_QUALITY_PIPS)
	var after := clampi(before - degraded, MIN_QUALITY_PIPS, MAX_QUALITY_PIPS)
	next[quality_key] = after
	next["armor_degraded_pips"] = before - after
	next["armor_quality_pips_before"] = before
	next["armor_quality_pips_after"] = after
	return next

static func degradation_text(label: String, before: int, after: int, degraded: int) -> String:
	if degraded <= 0 or before == after:
		return ""
	return "%s armor %+d->%+d" % [label, before, after]

static func _pool_text_has_pips(pool_text: String) -> bool:
	var cleaned := pool_text.strip_edges().to_upper().replace(" ", "")
	if cleaned == "" or not cleaned.contains("D"):
		return false
	var parts := cleaned.split("D", false)
	var dice := int(parts[0]) if parts.size() > 0 and parts[0] != "" else 0
	var pips := 0
	if parts.size() > 1 and parts[1] != "":
		pips = int(parts[1])
	return dice > 0 or pips > 0
