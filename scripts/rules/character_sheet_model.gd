extends RefCounted

const ArmorConditionModel = preload("res://scripts/rules/armor_condition_model.gd")

const ATTRIBUTE_KEYS = [
	"dexterity",
	"knowledge",
	"mechanical",
	"perception",
	"strength",
	"technical",
]

func initial_sheet(character_name = "Character"):
	var attributes = {}
	for attribute in ATTRIBUTE_KEYS:
		attributes[attribute] = "3D"
	return {
		"name": character_name,
		"species": "Human",
		"attributes": attributes,
		"skill_bonuses": {},
		"equipment": {},
		"character_points": 5,
		"force_points": 1,
		"dark_side_points": 0,
		"wound_severity": 0,
		"scale": "character",
	}

func canonical_key(label):
	return String(label).strip_edges().to_lower().replace(" ", "_").replace("-", "_").replace("/", "_")

func attribute_pool(rules, sheet, attribute):
	var key = canonical_key(attribute)
	var attributes = sheet.get("attributes", {})
	return rules.parse_pool(String(attributes.get(key, "0D")))

func skill_attribute(catalog, skill_name):
	var skills = catalog.get("skills", {})
	var skill = skills.get(canonical_key(skill_name), {})
	return String(skill.get("attribute", ""))

func skill_pool(rules, sheet, catalog, skill_name):
	var parent = skill_attribute(catalog, skill_name)
	if parent == "":
		return {"dice": 0, "pips": 0}
	var base = attribute_pool(rules, sheet, parent)
	var bonuses = sheet.get("skill_bonuses", {})
	var bonus = rules.parse_pool(String(bonuses.get(canonical_key(skill_name), "0D")))
	return rules.add_pools(base, bonus)

func combat_pools_from_sheet(rules, sheet, catalog, gear):
	var equipment = sheet.get("equipment", {})
	var weapons = gear.get("weapons", {})
	var armors = gear.get("armors", {})
	var weapon_key = String(equipment.get("weapon", ""))
	var armor_key = String(equipment.get("armor", ""))
	var weapon = weapons.get(weapon_key, {})
	var result = {}
	result["attacker_pool"] = skill_pool(rules, sheet, catalog, "blaster")
	result["player_dodge_pool"] = skill_pool(rules, sheet, catalog, "dodge")
	result["damage_pool"] = rules.parse_pool(String(weapon.get("damage", "0D")))
	result["player_soak_pool"] = attribute_pool(rules, sheet, "strength")
	result["player_armor"] = armors.get(armor_key, {})
	result["attacker_scale"] = String(sheet.get("scale", "character"))
	result["character_points"] = int(sheet.get("character_points", 0))
	result["force_points"] = int(sheet.get("force_points", 0))
	result["wound_severity"] = int(sheet.get("wound_severity", 0))
	return result

func armor_summary_lines(armor: Dictionary, armor_quality_pips: int = 0) -> PackedStringArray:
	var lines := PackedStringArray()
	if armor.is_empty() or not ArmorConditionModel.has_soak_protection(armor):
		lines.append("Armor: None")
		return lines
	lines.append("Armor: %s E%s P%s Dex%s" % [
		String(armor.get("name", "Armor")),
		String(armor.get("protection_energy", armor.get("energy", "0D"))),
		String(armor.get("protection_physical", armor.get("physical", "0D"))),
		String(armor.get("dexterity_penalty", "0D")),
	])
	lines.append("Coverage: %s" % _coverage_text(ArmorConditionModel.covered_locations(armor)))
	lines.append("Quality: %+d pips" % armor_quality_pips)
	return lines

func _coverage_text(locations: Array) -> String:
	if locations.is_empty():
		return "none"
	var labels := PackedStringArray()
	for location in locations:
		labels.append(String(location).replace("_", " "))
	return ", ".join(labels)
