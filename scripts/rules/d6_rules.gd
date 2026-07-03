extends Node

const DIFFICULTIES = {
	"very_easy": 5,
	"easy": 10,
	"moderate": 15,
	"difficult": 20,
	"very_difficult": 25,
	"heroic": 30,
}

const RANGE_BANDS = [
	{"name": "Point Blank", "max": 4.0, "difficulty": 5},
	{"name": "Short", "max": 16.0, "difficulty": 10},
	{"name": "Medium", "max": 32.0, "difficulty": 15},
	{"name": "Long", "max": 56.0, "difficulty": 20},
]

const COVER_NAMES = {
	0: "None",
	1: "1/4",
	2: "1/2",
	3: "3/4",
	4: "Full",
}

const SCALE_VALUES = {
	"character": 0,
	"speeder": 2,
	"walker": 4,
	"starfighter": 6,
	"corvette": 9,
	"capital": 12,
	"battlestation": 24,
}

const SCALE_ALIASES = {
	"characters": "character",
	"creature": "character",
	"creatures": "character",
	"droid": "character",
	"droids": "character",
	"speeders": "speeder",
	"landspeeder": "speeder",
	"landspeeders": "speeder",
	"swoop": "speeder",
	"swoops": "speeder",
	"walkers": "walker",
	"starfighters": "starfighter",
	"starship": "starfighter",
	"starships": "starfighter",
	"capital_ship": "capital",
	"capital_ships": "capital",
	"station": "battlestation",
	"stations": "battlestation",
	"battle_station": "battlestation",
	"battle_stations": "battlestation",
}

func normalize_pool(dice: int, pips: int = 0) -> Dictionary:
	while pips >= 3:
		dice += 1
		pips -= 3
	while pips < 0 and dice > 0:
		dice -= 1
		pips += 3
	return {"dice": max(dice, 0), "pips": max(pips, 0)}

func parse_pool(text: String) -> Dictionary:
	var cleaned := text.strip_edges().to_upper().replace(" ", "")
	var parts := cleaned.split("D", false)
	if parts.size() == 0:
		return {"dice": 0, "pips": 0}

	var dice := int(parts[0])
	var pips := 0
	if parts.size() > 1 and parts[1] != "":
		pips = int(parts[1])
	return normalize_pool(dice, pips)

func pool_to_string(pool: Dictionary) -> String:
	var normalized := normalize_pool(int(pool.get("dice", 0)), int(pool.get("pips", 0)))
	var dice := int(normalized["dice"])
	var pips := int(normalized["pips"])
	if pips == 0:
		return "%dD" % dice
	return "%dD+%d" % [dice, pips]

func add_pips(pool: Dictionary, pip_delta: int) -> Dictionary:
	return normalize_pool(int(pool.get("dice", 0)), int(pool.get("pips", 0)) + pip_delta)

func add_pools(a: Dictionary, b: Dictionary) -> Dictionary:
	var total_pips := int(a.get("dice", 0)) * 3 + int(a.get("pips", 0))
	total_pips += int(b.get("dice", 0)) * 3 + int(b.get("pips", 0))
	return normalize_pool(int(total_pips / 3), total_pips % 3)

func subtract_pools(pool: Dictionary, penalty: Dictionary) -> Dictionary:
	var total_pips := int(pool.get("dice", 0)) * 3 + int(pool.get("pips", 0))
	total_pips -= int(penalty.get("dice", 0)) * 3 + int(penalty.get("pips", 0))
	total_pips = maxi(total_pips, 0)
	return normalize_pool(int(total_pips / 3), total_pips % 3)

func apply_multi_action_penalty(pool: Dictionary, num_actions: int) -> Dictionary:
	var penalty := maxi(num_actions - 1, 0)
	var new_dice := maxi(int(pool.get("dice", 0)) - penalty, 0)
	var new_pips := int(pool.get("pips", 0)) if new_dice > 0 else 0
	return normalize_pool(new_dice, new_pips)

func apply_wound_penalty(pool: Dictionary, wound_dice: int) -> Dictionary:
	var penalty := maxi(wound_dice, 0)
	var new_dice := maxi(int(pool.get("dice", 0)) - penalty, 0)
	var new_pips := int(pool.get("pips", 0)) if new_dice > 0 else 0
	return normalize_pool(new_dice, new_pips)

func apply_force_point(pool: Dictionary) -> Dictionary:
	return normalize_pool(int(pool.get("dice", 0)) * 2, int(pool.get("pips", 0)) * 2)

# Parse a pool string, treating a PIP-ONLY token (no "D", e.g. "+2" or "2") as pips rather than
# dice. parse_pool() splits on "D" and reads the leading int as DICE, so it misreads "+2" as 2D
# (a whole extra die). WEG writes pip-only armor protection / penalties in the bare "+2" form, so
# the armor pipeline must use this. Mirrors the guard in derived_stats_model.melee_damage_pool.
func parse_pool_or_pips(text: String) -> Dictionary:
	var cleaned := text.strip_edges().to_upper().replace(" ", "")
	if cleaned == "":
		return {"dice": 0, "pips": 0}
	if not cleaned.contains("D"):
		if cleaned.begins_with("+"):
			cleaned = cleaned.substr(1)
		return normalize_pool(0, int(cleaned))
	return parse_pool(cleaned)

func armor_protection_pool(armor: Dictionary, damage_type: String = "energy", armor_quality_pips: int = 0) -> Dictionary:
	var key := "protection_energy" if damage_type.strip_edges().to_lower() != "physical" else "protection_physical"
	var fallback_key := "energy" if key == "protection_energy" else "physical"
	var protection := parse_pool_or_pips(String(armor.get(key, armor.get(fallback_key, "0D"))))
	if armor_quality_pips != 0 and (int(protection["dice"]) > 0 or int(protection["pips"]) > 0):
		protection = add_pips(protection, armor_quality_pips)
	return protection

func armor_dexterity_penalty_pool(armor: Dictionary) -> Dictionary:
	var penalty_text := String(armor.get("dexterity_penalty", armor.get("dex_penalty", "0D"))).strip_edges()
	if penalty_text.begins_with("-"):
		penalty_text = penalty_text.substr(1)
	return parse_pool_or_pips(penalty_text)

func apply_armor_dexterity_penalty(pool: Dictionary, armor: Dictionary) -> Dictionary:
	return subtract_pools(pool, armor_dexterity_penalty_pool(armor))

func apply_armor_to_soak(strength_pool: Dictionary, armor: Dictionary, damage_type: String = "energy", armor_quality_pips: int = 0) -> Dictionary:
	return add_pools(strength_pool, armor_protection_pool(armor, damage_type, armor_quality_pips))

func canonical_scale_name(scale: Variant) -> String:
	if typeof(scale) == TYPE_DICTIONARY:
		return canonical_scale_name(scale.get("scale", "character"))
	if typeof(scale) == TYPE_INT or typeof(scale) == TYPE_FLOAT:
		var numeric := int(scale)
		for key in SCALE_VALUES:
			if int(SCALE_VALUES[key]) == numeric:
				return String(key)
		return "character"

	var key := String(scale).strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	return String(SCALE_ALIASES.get(key, key))

func scale_value(scale: Variant) -> int:
	var key := canonical_scale_name(scale)
	return int(SCALE_VALUES.get(key, 0))

func scale_difference(attacker_scale: Variant, defender_scale: Variant) -> int:
	return scale_value(defender_scale) - scale_value(attacker_scale)

func apply_scale_to_attack_pool(pool: Dictionary, attacker_scale: Variant, defender_scale: Variant) -> Dictionary:
	var diff := scale_difference(attacker_scale, defender_scale)
	if diff > 0:
		return normalize_pool(int(pool.get("dice", 0)) + diff, int(pool.get("pips", 0)))
	return normalize_pool(int(pool.get("dice", 0)), int(pool.get("pips", 0)))

func apply_scale_to_dodge_pool(pool: Dictionary, attacker_scale: Variant, defender_scale: Variant) -> Dictionary:
	var diff := scale_difference(attacker_scale, defender_scale)
	if diff < 0:
		return normalize_pool(int(pool.get("dice", 0)) + abs(diff), int(pool.get("pips", 0)))
	return normalize_pool(int(pool.get("dice", 0)), int(pool.get("pips", 0)))

func apply_scale_to_damage_pool(pool: Dictionary, attacker_scale: Variant, defender_scale: Variant) -> Dictionary:
	var diff := scale_difference(attacker_scale, defender_scale)
	if diff < 0:
		return normalize_pool(int(pool.get("dice", 0)) + abs(diff), int(pool.get("pips", 0)))
	return normalize_pool(int(pool.get("dice", 0)), int(pool.get("pips", 0)))

func apply_scale_to_soak_pool(pool: Dictionary, attacker_scale: Variant, defender_scale: Variant) -> Dictionary:
	var diff := scale_difference(attacker_scale, defender_scale)
	if diff > 0:
		return normalize_pool(int(pool.get("dice", 0)) + diff, int(pool.get("pips", 0)))
	return normalize_pool(int(pool.get("dice", 0)), int(pool.get("pips", 0)))

func roll_pool(pool: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var normalized := normalize_pool(int(pool.get("dice", 0)), int(pool.get("pips", 0)))
	var dice := int(normalized["dice"])
	var pips := int(normalized["pips"])

	if dice <= 0:
		return {
			"pool": pool_to_string(normalized),
			"normal_dice": [],
			"wild_rolls": [],
			"removed_die": 0,
			"pips": pips,
			"total": max(pips, 0),
			"exploded": false,
			"complication": false,
		}

	var normal_dice: Array[int] = []
	for i in range(max(dice - 1, 0)):
		normal_dice.append(rng.randi_range(1, 6))

	var wild := _roll_wild_die(rng)
	var removed_die := 0
	if bool(wild["complication"]) and normal_dice.size() > 0:
		normal_dice.sort()
		removed_die = int(normal_dice.pop_back())

	var normal_total := 0
	for die in normal_dice:
		normal_total += die

	return {
		"pool": pool_to_string(normalized),
		"normal_dice": normal_dice,
		"wild_rolls": wild["rolls"],
		"removed_die": removed_die,
		"pips": pips,
		"total": max(normal_total + int(wild["total"]) + pips, 1),
		"exploded": bool(wild["exploded"]),
		"complication": bool(wild["complication"]),
	}

func roll_cp_die(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var rolls: Array[int] = []
	var total := 0
	while true:
		var roll := rng.randi_range(1, 6)
		rolls.append(roll)
		total += roll
		if roll != 6:
			break
	return {"rolls": rolls, "total": total}

func roll_cp_dice(count: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var dice: Array = []
	var total := 0
	for i in range(clampi(count, 0, 5)):
		var cp_die := roll_cp_die(rng)
		dice.append(cp_die)
		total += int(cp_die["total"])
	return {
		"count": dice.size(),
		"dice": dice,
		"total": total,
	}

func check(pool: Dictionary, difficulty: Variant, rng: RandomNumberGenerator = null) -> Dictionary:
	var target := 10
	if typeof(difficulty) == TYPE_STRING:
		var key := String(difficulty).strip_edges().to_lower().replace(" ", "_")
		target = int(DIFFICULTIES.get(key, 10))
	else:
		target = int(difficulty)
	var result := roll_pool(pool, rng)
	result["difficulty"] = target
	result["margin"] = int(result["total"]) - target
	result["success"] = int(result["total"]) >= target
	return result

func range_band_for_distance(distance: float) -> Dictionary:
	for band in RANGE_BANDS:
		if distance <= float(band["max"]):
			return band
	return {"name": "Extreme", "max": INF, "difficulty": 30}

# Weapon-driven range bands (WEG R&E + data/weapons_clone_wars.json).
# A weapon's ranges are [short_min, short_max, medium_max, long_max] in meters.
# Range difficulties per the data file: point-blank (< short_min) = Very Easy (5),
# short = Easy (10), medium = Moderate (15), long = Difficult (20),
# beyond long_max = Extreme = Heroic (30).
# If ranges is malformed (size < 4) fall back to the fixed RANGE_BANDS table.
func range_band_for_weapon(distance: float, ranges: Array) -> Dictionary:
	if ranges.size() < 4:
		return range_band_for_distance(distance)
	if distance < float(ranges[0]):
		return {"name": "Point Blank", "max": float(ranges[0]), "difficulty": 5}
	if distance <= float(ranges[1]):
		return {"name": "Short", "max": float(ranges[1]), "difficulty": 10}
	if distance <= float(ranges[2]):
		return {"name": "Medium", "max": float(ranges[2]), "difficulty": 15}
	if distance <= float(ranges[3]):
		return {"name": "Long", "max": float(ranges[3]), "difficulty": 20}
	return {"name": "Extreme", "max": INF, "difficulty": 30}

func roll_cover_bonus(cover_level: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var clamped := clampi(cover_level, 0, 4)
	if clamped >= 4:
		return {
			"level": clamped,
			"name": COVER_NAMES[clamped],
			"bonus": 999,
			"roll": {},
			"blocks_targeting": true,
		}
	if clamped <= 0:
		return {
			"level": clamped,
			"name": COVER_NAMES[clamped],
			"bonus": 0,
			"roll": {},
			"blocks_targeting": false,
		}

	var cover_roll := roll_pool({"dice": clamped, "pips": 0}, rng)
	return {
		"level": clamped,
		"name": COVER_NAMES[clamped],
		"bonus": int(cover_roll["total"]),
		"roll": cover_roll,
		"blocks_targeting": false,
	}

func prepare_ranged_defense(defense: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var prepared := defense.duplicate(true)
	var defense_type := String(prepared.get("type", "none"))
	if defense_type != "dodge" and defense_type != "full_dodge":
		return prepared
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var defense_pool: Dictionary = prepared.get("pool", {"dice": 0, "pips": 0})
	var action_count := int(prepared.get("action_count", 1))
	if defense_type == "dodge":
		defense_pool = apply_multi_action_penalty(defense_pool, action_count)
	var defense_roll := roll_pool(defense_pool, rng)
	prepared["cached_roll"] = defense_roll
	prepared["value"] = int(defense_roll["total"])
	prepared["pool"] = defense_pool
	return prepared

func resolve_ranged_attack(attacker_pool: Dictionary, distance: float, cover_level: int = 0, rng: RandomNumberGenerator = null, defense: Dictionary = {}, attack_cp_count: int = 0, weapon_ranges: Array = []) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var band: Dictionary = range_band_for_weapon(distance, weapon_ranges) if not weapon_ranges.is_empty() else range_band_for_distance(distance)
	var cover := roll_cover_bonus(cover_level, rng)
	var base_difficulty := int(band["difficulty"])
	var defense_roll := {}
	var defense_text := ""
	var dodge_value := 0
	var dodge_replaces := false
	if not defense.is_empty():
		var defense_type := String(defense.get("type", "none"))
		if defense_type == "dodge" or defense_type == "full_dodge":
			if defense.has("cached_roll"):
				defense_roll = defense["cached_roll"]
			else:
				var defense_pool: Dictionary = defense.get("pool", {"dice": 0, "pips": 0})
				var action_count := int(defense.get("action_count", 1))
				if defense_type == "dodge":
					defense_pool = apply_multi_action_penalty(defense_pool, action_count)
				defense_roll = roll_pool(defense_pool, rng)
			dodge_value = int(defense_roll["total"])
			dodge_replaces = defense_type == "dodge"
			defense_text = "Dodge %d" % dodge_value if dodge_replaces else "FullDodge %d" % dodge_value

	var total_difficulty := int(cover["bonus"])
	if dodge_replaces:
		total_difficulty += dodge_value
	else:
		total_difficulty += base_difficulty + dodge_value
	var attack := roll_pool(attacker_pool, rng)
	var attack_cp := roll_cp_dice(attack_cp_count, rng)
	var attack_total := int(attack["total"]) + int(attack_cp["total"])

	return {
		"range_name": band["name"],
		"range_difficulty": base_difficulty,
		"distance": distance,
		"cover": cover,
		"attack": attack,
		"attack_cp": attack_cp,
		"defense": {
			"type": String(defense.get("type", "none")),
			"roll": defense_roll,
			"value": dodge_value,
			"replaces": dodge_replaces,
			"text": defense_text,
		},
		"difficulty": total_difficulty,
		"margin": attack_total - total_difficulty,
		"success": (not bool(cover["blocks_targeting"])) and attack_total >= total_difficulty,
		"blocked": bool(cover["blocks_targeting"]),
	}

func resolve_damage(damage_pool: Dictionary, soak_pool: Dictionary, rng: RandomNumberGenerator = null, stun_mode: bool = false, soak_cp_count: int = 0) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var damage_roll := roll_pool(damage_pool, rng)
	var soak_roll := roll_pool(soak_pool, rng)
	var soak_cp := roll_cp_dice(soak_cp_count, rng)
	var soak_total := int(soak_roll["total"]) + int(soak_cp["total"])
	var margin := int(damage_roll["total"]) - soak_total
	var wound := wound_for_damage_margin(margin)
	if stun_mode and margin > 3:
		wound = {"key": "stunned_unconscious", "name": "Stunned - Unconscious", "severity": 1}

	return {
		"damage_roll": damage_roll,
		"soak_roll": soak_roll,
		"soak_cp": soak_cp,
		"margin": margin,
		"wound": wound,
	}

func wound_for_damage_margin(margin: int) -> Dictionary:
	if margin <= 0:
		return {"key": "no_damage", "name": "No Damage", "severity": 0}
	if margin <= 3:
		return {"key": "stunned", "name": "Stunned", "severity": 1}
	if margin <= 8:
		return {"key": "wounded", "name": "Wounded", "severity": 2}
	if margin <= 12:
		return {"key": "incapacitated", "name": "Incapacitated", "severity": 3}
	if margin <= 15:
		return {"key": "mortally_wounded", "name": "Mortally Wounded", "severity": 4}
	return {"key": "killed", "name": "Killed", "severity": 5}

func _roll_wild_die(rng: RandomNumberGenerator) -> Dictionary:
	var rolls: Array[int] = []
	var first := rng.randi_range(1, 6)
	rolls.append(first)

	if first == 1:
		return {"rolls": rolls, "total": 0, "exploded": false, "complication": true}

	if first == 6:
		var total := 6
		while true:
			var reroll := rng.randi_range(1, 6)
			rolls.append(reroll)
			total += reroll
			if reroll != 6:
				break
		return {"rolls": rolls, "total": total, "exploded": true, "complication": false}

	return {"rolls": rolls, "total": first, "exploded": false, "complication": false}
