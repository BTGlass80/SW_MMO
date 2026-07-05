extends SceneTree

const WorldState := preload("res://scripts/net/world_state.gd")

var _failures: Array[String] = []

func _init() -> void:
	print("Starting automated release playtest...")
	
	var state = WorldState.new()
	state._catalog = {
		"blaster_pistol": {"kind": "weapon", "name": "Blaster Pistol", "damage": 10},
		"basic_medpac": {"kind": "consumable", "name": "Basic Medpac", "heal": 1},
		"organic_resource": {"kind": "resource", "name": "Organic Resource"},
		"starship_salvage": {"kind": "resource", "name": "Starship Salvage"}
	}
	state._recipes = {
		"basic_medpac": {"result": "basic_medpac", "inputs": {"organic_resource": 1}}
	}
	
	# 3. Client Join & Character Creation
	state.add_player(1, "Pilot A")
	state.add_player(2, "Hunter B")
	
	# Give starting credits
	state.test_grant_credits(1, 1000)
	state.test_grant_credits(2, 5000)
	
	# 4. Core Story 1: New Player First Hour
	# Chat
	var chat_packet = {"cmd": "chat", "msg": "Hello there!"}
	state.process_client_intent(1, chat_packet)
	
	# Vendor Buy
	var vendor_buy = {"cmd": "vendor_buy", "item_key": "blaster_pistol"}
	state.process_client_intent(2, vendor_buy)
	
	# Equip
	var inventory = state.get_player(2).get("inventory", [])
	var item_inst = ""
	if inventory.size() > 0:
		item_inst = inventory[0].get("instance_id", "")
	var equip = {"cmd": "equip", "instance_id": item_inst}
	state.process_client_intent(2, equip)
	
	# Harvest (Mock)
	var grant_resource = {"cmd": "admin_grant", "type": "item", "item_id": "organic_resource"}
	# Since we can't easily mock the full harvest loop here without Director, we just grant the item for the test.
	var p1_sheet = state.get_player(1)
	p1_sheet["inventory"] = p1_sheet.get("inventory", [])
	p1_sheet["inventory"].append({"instance_id": "res_1", "template_id": "organic_resource", "quantity": 1})
	state._set_player_sheet(1, p1_sheet)
	
	# Combat (Mock getting a wound)
	var p2_sheet = state.get_player(2)
	p2_sheet["wounds"] = 1
	p2_sheet["wound_state"] = "wounded"
	state._set_player_sheet(2, p2_sheet)
	
	# 5. Core Story 2: Player Economy
	# Crafting
	var craft = {"cmd": "craft", "recipe_id": "basic_medpac"}
	state.process_client_intent(1, craft)
	
	# List on Bazaar
	p1_sheet = state.get_player(1)
	var medpac_inst = ""
	for it in p1_sheet.get("inventory", []):
		if it.get("template_id") == "basic_medpac":
			medpac_inst = it.get("instance_id")
			break
			
	var list_bazaar = {"cmd": "bazaar_list", "instance_id": medpac_inst, "price": 1500}
	state.process_client_intent(1, list_bazaar)
	
	# Buy from Bazaar
	var listings = state.get_bazaar_listings()
	var listing_id = ""
	for id in listings.keys():
		listing_id = id
		break
		
	var buy_bazaar = {"cmd": "bazaar_buy", "listing_id": listing_id}
	state.process_client_intent(2, buy_bazaar)
	
	# Use Item
	p2_sheet = state.get_player(2)
	var bought_medpac = ""
	for it in p2_sheet.get("inventory", []):
		if it.get("template_id") == "basic_medpac":
			bought_medpac = it.get("instance_id")
			break
			
	var use_item = {"cmd": "use_item", "instance_id": bought_medpac}
	state.process_client_intent(2, use_item)
	
	p2_sheet = state.get_player(2)
	if p2_sheet.get("wounds", 1) != 0:
		_fail("Hunter B wound was not healed.")
		
	# 6. Core Story 3: Space Cargo
	var space_launch = {"cmd": "space_launch"}
	state.process_client_intent(1, space_launch)
	
	p1_sheet = state.get_player(1)
	var space_state = p1_sheet.get("space_state", {})
	space_state["in_space"] = true
	space_state["ship_cargo"] = [{"template_id": "starship_salvage", "quantity": 1}]
	p1_sheet["space_state"] = space_state
	state._set_player_sheet(1, p1_sheet)
	
	var space_land = {"cmd": "space_land"}
	state.process_client_intent(1, space_land)
	
	p1_sheet = state.get_player(1)
	var has_salvage = false
	for it in p1_sheet.get("inventory", []):
		if it.get("template_id") == "starship_salvage":
			has_salvage = true
			break
			
	if not has_salvage:
		_fail("Pilot A did not receive space cargo upon landing.")
		
	_finish()

func _fail(msg: String):
	_failures.append(msg)
	
func _finish():
	if _failures.is_empty():
		print("release_playtest_auto: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)
