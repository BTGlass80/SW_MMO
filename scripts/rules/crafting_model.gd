extends RefCounted

const ItemInstance := preload("res://scripts/rules/item_instance.gd")

static func load_json(path: String) -> Variant:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

static func get_resources(path: String = "res://data/resources_clone_wars.json") -> Array:
	var data = load_json(path)
	if data is Dictionary and data.has("resources"):
		return data["resources"] as Array
	return []

static func get_schematics(path: String = "res://data/schematics_clone_wars.json") -> Array:
	var data = load_json(path)
	if data is Dictionary and data.has("schematics"):
		return data["schematics"] as Array
	return []

static func get_resource_spawns(path: String = "res://data/resource_spawns_clone_wars.json") -> Array:
	var data = load_json(path)
	if data is Dictionary and data.has("resource_spawns"):
		return data["resource_spawns"] as Array
	return []

# Survey deposits by zone. Quality, density, and distance are rolled deterministically from seeds.
static func roll_survey(sheet: Dictionary, rules: Object, zone_id: String, seed_val: int, current_time: int, resources_path: String = "res://data/resources_clone_wars.json", spawns_path: String = "res://data/resource_spawns_clone_wars.json") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	# Roll survey check
	var skill_val := String(sheet.get("search", sheet.get("survey", "2D")))
	var pool: Dictionary = rules.parse_pool(skill_val)
	var roll: Dictionary = rules.roll_pool(pool, rng)
	var roll_total = int(roll.get("total", 0))
	var difficulty = 10
	var margin = roll_total - difficulty
	
	if roll.get("complication", false) or margin <= -5:
		return {"ok": false, "reason": "survey_failed", "roll": roll_total, "margin": margin}
	
	var all_res := get_resources(resources_path)
	var spawns := get_resource_spawns(spawns_path)
	
	var matched_spawn: Dictionary = {}
	for sp in spawns:
		if sp.get("zone_id", "") == zone_id:
			matched_spawn = sp
			break
			
	var active_keys: Array = matched_spawn.get("active_resources", [])
	
	var matched: Array = []
	for res in all_res:
		if active_keys.is_empty() or active_keys.has(res.get("key", "")):
			matched.append(res)
			
	if matched.is_empty():
		return {"ok": false, "reason": "no_resources_in_zone"}
		
	# Select resource based on spawn weight
	var total_weight := 0
	for res in matched:
		total_weight += int(res.get("spawn_weight", 10))
		
	var roll_val := rng.randi_range(0, max(0, total_weight - 1))
	var selected_res: Dictionary = matched[0]
	var running_sum := 0
	for res in matched:
		running_sum += int(res.get("spawn_weight", 10))
		if roll_val < running_sum:
			selected_res = res
			break
			
	var res_key: String = selected_res.get("key", "")
	var res_name: String = selected_res.get("name", "Unknown Resource")
	var res_diff := int(selected_res.get("survey_difficulty", 10))
	
	if roll_total < res_diff and margin < 0:
		return {"ok": false, "reason": "survey_failed_difficulty", "roll": roll_total, "difficulty": res_diff}
	
	# Zone modifiers
	var z_qual: float = float(matched_spawn.get("quality_modifier", 1.0))
	var z_dens: float = float(matched_spawn.get("density_modifier", 1.0))
	
	# Roll quality and density with margin bonus
	var margin_bonus = max(0, margin)
	var quality := int(clamp(rng.randi_range(40, 90) * z_qual + (margin_bonus * 2), 1, 100))
	var density := int(clamp(rng.randi_range(20, 90) * z_dens + margin_bonus, 1, 100))
	var distance: int = maxi(1, rng.randi_range(5, 30) - margin_bonus)
	
	var deposit_id := "dep_%d_%d" % [seed_val, current_time]
	var expires_at := current_time + 300 # 5 minutes TTL
	
	return {
		"ok": true,
		"deposit_id": deposit_id,
		"type": res_key,
		"name": res_name,
		"quality": quality,
		"density": density,
		"distance": distance,
		"expires_at": expires_at,
		"roll": roll_total
	}

static func harvest_resource(sheet: Dictionary, rules: Object, deposit: Dictionary, seed_val: int, current_time: int) -> Dictionary:
	if current_time > deposit.get("expires_at", 0):
		return {"ok": false, "reason": "deposit_expired"}
		
	var next_sheet: Dictionary = sheet.duplicate(true)
	var r_type: String = deposit.get("type", "")
	var q: float = float(deposit.get("quality", 50.0))
	var res_name: String = deposit.get("name", r_type)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	# Harvest amount based on density and a minor variable roll
	var density: int = int(deposit.get("density", 20))
	var base_yield: int = maxi(1, density / 10)
	var yield_amt: int = base_yield + rng.randi_range(0, 2)
	
	var inventory: Array = next_sheet.get("inventory", [])
	var found_item: Dictionary = {}
	var found_idx: int = -1
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if item.get("template_id", "") == "resource_stack" and item.get("stats", {}).get("resource_type", "") == r_type:
			found_item = item.duplicate(true)
			found_idx = i
			break

	if found_idx >= 0:
		var current_count = int(found_item.get("stack_count", 0))
		var current_q = float(found_item.get("quality", 0.0))
		var new_count = current_count + yield_amt
		var new_q = ((current_q * current_count) + (q * yield_amt)) / float(new_count)
		found_item["stack_count"] = new_count
		found_item["quality"] = new_q
		inventory[found_idx] = found_item
	else:
		var new_item = ItemInstance.create("resource_stack", res_name, "resource", q, 1, "world", {}, {"resource_type": r_type})
		new_item["stack_count"] = yield_amt
		inventory.append(new_item)
		
	next_sheet["inventory"] = inventory
	return {"sheet": next_sheet, "ok": true, "type": r_type, "count": yield_amt, "quality": q}

static func craft_item(sheet: Dictionary, schematic_key: String, rules: Object, seed_val: int, crafter_id: String, schematics_path: String = "res://data/schematics_clone_wars.json", resources_path: String = "res://data/resources_clone_wars.json") -> Dictionary:
	var schematics := get_schematics(schematics_path)
	var selected_sch: Dictionary = {}
	for sch in schematics:
		if String(sch.get("key", "")) == schematic_key:
			selected_sch = sch
			break
			
	if selected_sch.is_empty():
		return {"ok": false, "reason": "unknown_schematic"}
		
	var next_sheet: Dictionary = sheet.duplicate(true)
	var inventory: Array = next_sheet.get("inventory", [])
	
	# Verify resources
	var requires: Dictionary = selected_sch.get("requires", {})
	
	for res_type in requires.keys():
		var req_count = int(requires[res_type])
		var current_count = 0
		for item in inventory:
			if typeof(item) == TYPE_DICTIONARY and item.get("template_id", "") == "resource_stack" and item.get("stats", {}).get("resource_type", "") == res_type:
				current_count += int(item.get("stack_count", 0))
		if current_count < req_count:
			return {"ok": false, "reason": "insufficient_" + res_type}
			
	# Roll D6 Crafting check first to check for failure before consuming
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var skill_name: String = selected_sch.get("required_skill", "technical")
	var skill_val := String(next_sheet.get(skill_name, next_sheet.get("technical", "2D")))
	var pool: Dictionary = rules.parse_pool(skill_val)
	var roll: Dictionary = rules.roll_pool(pool, rng)
	var difficulty = int(selected_sch.get("difficulty", 10))
	var roll_total = int(roll.get("total", 0))
	var margin = roll_total - difficulty
	var is_fumble: bool = roll.get("complication", false)
	var is_critical: bool = roll.get("exploded", false) and margin >= 0
	
	# Evaluate outcomes according to D6 rules
	var result_state := "success"
	if is_fumble:
		result_state = "fumble"
	elif margin <= -5:
		# Failure: miss by 5+ -> no output, resources kept
		return {"ok": false, "reason": "craft_failed", "roll": roll_total, "difficulty": difficulty}
	elif margin < 0:
		result_state = "partial_success"
	elif is_critical:
		result_state = "critical_success"

	# If we reach here, resources are consumed
	var all_res := get_resources(resources_path)
	var res_map := {}
	for r in all_res:
		res_map[String(r.get("key", ""))] = r
		
	var consumed_stats := {}
	var total_units := 0
	
	for res_type in requires.keys():
		var req_count = int(requires[res_type])
		var remaining = req_count
		total_units += req_count
		
		var base_stats: Dictionary = res_map.get(res_type, {}).get("quality_stats", {})
		
		# Consume from inventory
		for i in range(inventory.size() - 1, -1, -1):
			var item = inventory[i]
			if typeof(item) == TYPE_DICTIONARY and item.get("template_id", "") == "resource_stack" and item.get("stats", {}).get("resource_type", "") == res_type:
				var current_stack = int(item.get("stack_count", 0))
				var q_pct = float(item.get("quality", 50.0)) / 100.0
				var take = mini(current_stack, remaining)
				remaining -= take
				
				for stat_name in base_stats.keys():
					var base_val = float(base_stats[stat_name])
					var eff_val = base_val * q_pct
					consumed_stats[stat_name] = consumed_stats.get(stat_name, 0.0) + (eff_val * take)
					
				item["stack_count"] = current_stack - take
				if int(item["stack_count"]) <= 0:
					inventory.remove_at(i)
					
				if remaining <= 0:
					break
					
	for stat_name in consumed_stats.keys():
		consumed_stats[stat_name] = consumed_stats[stat_name] / float(total_units)
		
	next_sheet["inventory"] = inventory
	
	# Evaluate base quality formula
	var formula: String = selected_sch.get("quality_formula", "")
	var final_quality := 50.0
	if formula != "":
		var expr := Expression.new()
		var vars := PackedStringArray()
		var vals := []
		for k in consumed_stats.keys():
			vars.append(k)
			vals.append(consumed_stats[k])
		var err = expr.parse(formula, vars)
		if err == OK:
			var result = expr.execute(vals)
			if not expr.has_execute_failed():
				final_quality = float(result)
				
	# Apply outcome modifiers
	var output_def: Dictionary = selected_sch.get("output", {}).duplicate(true)
	
	if result_state == "critical_success":
		final_quality += margin * 2.0 + 20.0 # Huge bonus
	elif result_state == "success":
		final_quality += margin * 2.0
	elif result_state == "partial_success":
		final_quality -= 20.0
		# Damaged output
		output_def["max_condition"] = max(1, int(output_def.get("max_condition", 1)) - 1)
	elif result_state == "fumble":
		final_quality = 1.0 # Flawed item
		output_def["max_condition"] = 1
		
	final_quality = clampf(final_quality, 1.0, 100.0)
		
	# Build unique item instance on success
	var item_inst = ItemInstance.create_from_output(output_def, final_quality, crafter_id, requires)
	
	inventory.append(item_inst)
	next_sheet["inventory"] = inventory
	
	# Legacy ammo mutation removed (power packs are now fully item instance driven)
		
	return {
		"ok": true,
		"sheet": next_sheet,
		"item": item_inst,
		"quality": final_quality,
		"roll": roll_total,
		"difficulty": difficulty,
		"result_state": result_state
	}
