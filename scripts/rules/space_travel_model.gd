extends RefCounted
## Pure model for server-owned solo space travel loops (launch, harvest, land).
## Extracts the inline logic from network_manager.gd into deterministic, testable operations.
## 
## Rules:
## 1. launch_ship requires an owned ship and sets in_space=true.
## 2. harvest_cargo generates a standard ItemInstance dictionary in ship_cargo.
## 3. land_ship charges a docking fee, transfers ship_cargo into inventory, and sets in_space=false.

const ItemInstance = preload("res://scripts/rules/item_instance.gd")
const DOCKING_FEE := 50

# Validates and launches a ship. Returns a dictionary with ok, reason, and sheet state.
static func launch_ship(sheet: Dictionary, ship_id: String) -> Dictionary:
	var owned_ships: Array = sheet.get("ships", [])
	if owned_ships.is_empty():
		return {"ok": false, "reason": "no_ships_owned"}
		
	var selected_ship_id := ship_id.strip_edges()
	if selected_ship_id == "" or not owned_ships.has(selected_ship_id):
		selected_ship_id = String(owned_ships[0])
		
	var space_state: Dictionary = sheet.get("space_state", {}).duplicate(true)
	if space_state.is_empty():
		space_state = {
			"current_system": "Tatooine",
			"in_space": true,
			"ship_id": selected_ship_id,
			"ship_name": selected_ship_id.capitalize(),
			"ship_cargo": []
		}
	else:
		space_state["ship_id"] = selected_ship_id
		space_state["in_space"] = true
		
	var new_sheet = sheet.duplicate(true)
	new_sheet["space_state"] = space_state
	return {"ok": true, "sheet": new_sheet, "space_state": space_state}

# Harvests space resources (asteroids/salvage). Returns a dictionary with ok, reason, sheet state, and the harvested item.
static func harvest_cargo(sheet: Dictionary, target_key: String, rng_seed: int) -> Dictionary:
	var space_state: Dictionary = sheet.get("space_state", {})
	if space_state.is_empty() or not bool(space_state.get("in_space", false)):
		return {"ok": false, "reason": "not_in_space"}
		
	var harvest_key := target_key.strip_edges()
	if harvest_key == "":
		harvest_key = "starship_salvage"
		
	var new_sheet = sheet.duplicate(true)
	var new_space_state: Dictionary = new_sheet.get("space_state", {})
	var cargo: Array = new_space_state.get("ship_cargo", [])
	
	# Generate a space resource item instance
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var instance_id = str(rng.randi()) # Use RNG to generate stable ID based on seed
	
	var item_instance := ItemInstance.create(harvest_key, "Asteroid", "resource", 50.0, 100, "world")
	item_instance["instance_id"] = instance_id
	cargo.append(item_instance)
	
	new_space_state["ship_cargo"] = cargo
	new_sheet["space_state"] = new_space_state
	
	return {"ok": true, "sheet": new_sheet, "harvested": item_instance}

# Lands the ship, charging a fee and moving cargo to inventory. Returns a dictionary with ok, reason, and sheet state.
static func land_ship(sheet: Dictionary) -> Dictionary:
	var credits := int(sheet.get("credits", 0))
	if credits < DOCKING_FEE:
		return {"ok": false, "reason": "insufficient_credits"}
		
	var space_state: Dictionary = sheet.get("space_state", {})
	if space_state.is_empty() or not bool(space_state.get("in_space", false)):
		return {"ok": false, "reason": "not_in_space"}
		
	var new_sheet = sheet.duplicate(true)
	var new_space_state: Dictionary = new_sheet.get("space_state", {})
	
	new_space_state["in_space"] = false
	
	# Transfer cargo to inventory
	var inventory: Array = new_sheet.get("inventory", [])
	var cargo: Array = new_space_state.get("ship_cargo", [])
	for item in cargo:
		inventory.append(item)
		
	new_space_state["ship_cargo"] = []
	new_sheet["inventory"] = inventory
	
	# Pay docking fee
	new_sheet["credits"] = credits - DOCKING_FEE
	new_sheet["space_state"] = new_space_state
	
	return {"ok": true, "sheet": new_sheet, "fee_amount": DOCKING_FEE, "transferred_cargo_count": cargo.size()}
