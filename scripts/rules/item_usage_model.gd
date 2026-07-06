extends RefCounted

static func use_item(sheet: Dictionary, rules: Object, target_state: Dictionary, item: Dictionary, seed_val: int) -> Dictionary:
	var template: String = item.get("template_key", item.get("template_id", ""))
	
	if template == "medpac":
		return _use_medpac(sheet, rules, target_state, item, seed_val)
	elif template == "power_pack" or template == "blaster_cell":
		return _use_power_pack(sheet, target_state, item)
	elif template == "ship_repair_patch":
		return _use_ship_repair_patch(sheet, rules, target_state, item, seed_val)
		
	return {"ok": false, "reason": "unusable_item"}

static func _use_medpac(sheet: Dictionary, rules: Object, target_state: Dictionary, item: Dictionary, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var first_aid_skill := String(sheet.get("first_aid", sheet.get("technical", "2D")))
	var pool: Dictionary = rules.parse_pool(first_aid_skill)
	var roll: Dictionary = rules.roll_pool(pool, rng)
	var roll_total = int(roll.get("total", 0))
	
	# Difficulty based on wound severity, simplify to 14 for prototype
	var difficulty = 14
	var quality = float(item.get("quality", 50.0)) / 100.0
	
	# Quality affects the effective roll
	var effective_roll = int(roll_total * (0.5 + quality))
	
	var new_item = item.duplicate(true)
	
	if effective_roll >= difficulty:
		var next_target = target_state.duplicate(true)
		var current_wounds = int(next_target.get("wounds", 1))
		next_target["wounds"] = maxi(0, current_wounds - 1)
		
		# Condition decreases for medpacs
		var condition = int(new_item.get("condition", new_item.get("max_condition", 5))) - 1
		new_item["condition"] = condition
		
		var consumed = false
		if condition <= 0:
			var stack = int(new_item.get("stack_count", 1))
			if stack > 1:
				new_item["stack_count"] = stack - 1
				new_item["condition"] = int(new_item.get("max_condition", 5))
			else:
				consumed = true
		
		return {
			"ok": true,
			"target_state": next_target,
			"item": new_item,
			"consumed": consumed,
			"roll": effective_roll,
			"difficulty": difficulty
		}
	else:
		# Condition still decreases on failure
		var condition = int(new_item.get("condition", new_item.get("max_condition", 5))) - 1
		new_item["condition"] = condition
		
		var consumed = false
		if condition <= 0:
			var stack = int(new_item.get("stack_count", 1))
			if stack > 1:
				new_item["stack_count"] = stack - 1
				new_item["condition"] = int(new_item.get("max_condition", 5))
			else:
				consumed = true
		
		return {
			"ok": false,
			"reason": "heal_failed",
			"target_state": target_state,
			"item": new_item,
			"consumed": consumed,
			"roll": effective_roll,
			"difficulty": difficulty
		}

static func _use_power_pack(sheet: Dictionary, target_state: Dictionary, item: Dictionary) -> Dictionary:
	var next_target = target_state.duplicate(true)
	var shots = int(item.get("stats", {}).get("shots", 20))
	var quality = float(item.get("quality", 50.0)) / 100.0
	var effective_shots = int(shots * (0.5 + quality))
	
	var ammo_dict: Dictionary = next_target.get("ammo", {})
	if typeof(ammo_dict) != TYPE_DICTIONARY:
		ammo_dict = {}
	
	# Ammo is now completely item-instance based and automatically counted from inventory
	# by ammo_model.gd. Manual usage of a pack could restore a specific weapon's shots,
	# but we do not mutate the legacy packs counter.
	
	var new_item = item.duplicate(true)
	var stack = int(new_item.get("stack_count", 1))
	var consumed = false
	if stack > 1:
		new_item["stack_count"] = stack - 1
	else:
		consumed = true
	
	return {
		"ok": true,
		"target_state": next_target,
		"item": new_item,
		"consumed": consumed,
		"ammo_added": effective_shots
	}
	
static func _use_ship_repair_patch(sheet: Dictionary, rules: Object, target_state: Dictionary, item: Dictionary, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var repair_skill := String(sheet.get("starship_repair", sheet.get("technical", "2D")))
	var pool: Dictionary = rules.parse_pool(repair_skill)
	var roll: Dictionary = rules.roll_pool(pool, rng)
	var roll_total = int(roll.get("total", 0))
	
	var difficulty = 10
	var quality = float(item.get("quality", 50.0)) / 100.0
	var effective_roll = int(roll_total * (0.5 + quality))
	
	var new_item = item.duplicate(true)
	var stack = int(new_item.get("stack_count", 1))
	var consumed = false
	if stack > 1:
		new_item["stack_count"] = stack - 1
	else:
		consumed = true
		
	if effective_roll >= difficulty:
		var next_target = target_state.duplicate(true)
		var repairs = int(item.get("stats", {}).get("repairs_hull", 15))
		var effective_repairs = int(repairs * quality) + (effective_roll - difficulty)
		
		next_target["hull"] = int(next_target.get("hull", 0)) + effective_repairs
		
		return {
			"ok": true,
			"target_state": next_target,
			"item": new_item,
			"consumed": consumed,
			"roll": effective_roll,
			"repairs": effective_repairs
		}
	else:
		return {
			"ok": false,
			"reason": "repair_failed",
			"target_state": target_state,
			"item": new_item,
			"consumed": consumed,
			"roll": effective_roll
		}
