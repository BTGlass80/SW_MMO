extends RefCounted
## Pure WEG ammo / power-pack recurring-sink model (DIV-0029). 
## Upgraded to use actual item instances in the inventory.

const ItemInstance := preload("res://scripts/rules/item_instance.gd")

const PACK_COST := 25
const STARTING_PACKS := 2
const PACK_ITEM_KEY := "blaster_power_pack"

static func shots_per_weapon(weapon_dict: Dictionary) -> int:
	return maxi(int(weapon_dict.get("ammo", 0)), 0)

static func uses_ammo(weapon_dict: Dictionary) -> bool:
	if bool(weapon_dict.get("single_use", false)):
		return false
	return shots_per_weapon(weapon_dict) > 0

## The starting inventory items chargen grants.
static func initial_packs() -> Array:
	var arr = []
	for i in range(STARTING_PACKS):
		arr.append(ItemInstance.create(PACK_ITEM_KEY, "Blaster Power Pack", "ammo", 50.0, 100, "chargen"))
	return arr

static func packs(sheet: Dictionary) -> int:
	var inventory: Array = sheet.get("inventory", [])
	var count = 0
	for item in inventory:
		if typeof(item) == TYPE_DICTIONARY:
			var tid = item.get("template_id", item.get("template_key", ""))
			if tid == PACK_ITEM_KEY or tid == "power_pack" or tid == "power_pack_standard":
				count += int(item.get("stack_count", 1))
	return count

static func shots_left(sheet: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> int:
	var ammo: Dictionary = sheet.get("ammo", {})
	return maxi(int(ammo.get(weapon_key, shots_per_weapon(weapon_dict))), 0)

static func ensure_init(sheet: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> Dictionary:
	if not uses_ammo(weapon_dict):
		return sheet
	var ammo: Dictionary = sheet.get("ammo", {})
	
	if not ammo.has("migrated_packs"):
		ammo["migrated_packs"] = true
		add_packs(sheet, STARTING_PACKS)
		
	if not ammo.has(weapon_key):
		ammo[weapon_key] = shots_per_weapon(weapon_dict)
		
	sheet["ammo"] = ammo
	return sheet

static func can_fire(sheet: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> bool:
	if not uses_ammo(weapon_dict):
		return true
	if shots_left(sheet, weapon_key, weapon_dict) > 0:
		return true
	return packs(sheet) > 0

static func auto_reload(sheet: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> Dictionary:
	var inventory: Array = sheet.get("inventory", [])
	var found_idx = -1
	for i in range(inventory.size()):
		var item = inventory[i]
		if typeof(item) == TYPE_DICTIONARY:
			var tid = item.get("template_id", item.get("template_key", ""))
			if tid == PACK_ITEM_KEY or tid == "power_pack" or tid == "power_pack_standard":
				found_idx = i
				break
			
	if found_idx == -1:
		return {"ok": false, "packs_left": 0}
		
	var item = inventory[found_idx]
	var qty = int(item.get("stack_count", 1))
	if qty <= 1:
		inventory.remove_at(found_idx)
	else:
		item["stack_count"] = qty - 1
		inventory[found_idx] = item
		
	sheet["inventory"] = inventory
	
	var ammo: Dictionary = sheet.get("ammo", {})
	ammo[weapon_key] = shots_per_weapon(weapon_dict)
	sheet["ammo"] = ammo
	
	return {"ok": true, "packs_left": packs(sheet)}

static func consume(sheet: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> Dictionary:
	if not uses_ammo(weapon_dict):
		return {"ok": true, "shots_left": -1, "reloaded": false, "packs_left": packs(sheet)}
	ensure_init(sheet, weapon_key, weapon_dict)
	
	var ammo: Dictionary = sheet.get("ammo", {})
	var reloaded := false
	if int(ammo.get(weapon_key, 0)) <= 0:
		var r := auto_reload(sheet, weapon_key, weapon_dict)
		if not bool(r.get("ok", false)):
			return {"ok": false, "shots_left": 0, "reloaded": false, "packs_left": 0}
		reloaded = true
		ammo = sheet.get("ammo", {}) # refresh reference
		
	ammo[weapon_key] = int(ammo[weapon_key]) - 1
	sheet["ammo"] = ammo
	return {"ok": true, "shots_left": int(ammo[weapon_key]), "reloaded": reloaded, "packs_left": packs(sheet)}

static func add_packs(sheet: Dictionary, n: int) -> Dictionary:
	var inventory: Array = sheet.get("inventory", [])
	# Since it's stackable, try to find existing to stack
	var found = false
	for i in range(inventory.size()):
		var item = inventory[i]
		if typeof(item) == TYPE_DICTIONARY:
			var tid = item.get("template_id", item.get("template_key", ""))
			if tid == PACK_ITEM_KEY or tid == "power_pack" or tid == "power_pack_standard":
				item["stack_count"] = int(item.get("stack_count", 1)) + n
				inventory[i] = item
				found = true
				break
	if not found:
		var inst = ItemInstance.create(PACK_ITEM_KEY, "Blaster Power Pack", "ammo", 50.0, 100, "world")
		inst["stack_count"] = n
		inventory.append(inst)
	sheet["inventory"] = inventory
	return sheet

static func remove_pack(sheet: Dictionary) -> Dictionary:
	var inventory: Array = sheet.get("inventory", [])
	var found_idx = -1
	for i in range(inventory.size()):
		var item = inventory[i]
		if typeof(item) == TYPE_DICTIONARY:
			var tid = item.get("template_id", item.get("template_key", ""))
			if tid == PACK_ITEM_KEY or tid == "power_pack" or tid == "power_pack_standard":
				found_idx = i
				break
	if found_idx == -1:
		return {"ok": false, "packs_left": 0}
		
	var item = inventory[found_idx]
	var qty = int(item.get("stack_count", 1))
	if qty <= 1:
		inventory.remove_at(found_idx)
	else:
		item["stack_count"] = qty - 1
		inventory[found_idx] = item
	
	sheet["inventory"] = inventory
	return {"ok": true, "packs_left": packs(sheet)}
