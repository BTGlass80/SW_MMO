extends SceneTree
## Live Two-Player Economy Proof (RWD Priority 5)
## Upgrades the economy loop test from model-synthetic to server-composed. 
## Mirrors network_manager.gd JSON handling for submit_bazaar_list, submit_buy, and submit_use_item.

const Rules = preload("res://scripts/rules/d6_rules.gd")
const Crafting = preload("res://scripts/rules/crafting_model.gd")
const Bazaar = preload("res://scripts/rules/bazaar_model.gd")
const ItemUsage = preload("res://scripts/rules/item_usage_model.gd")
const ItemInstance = preload("res://scripts/rules/item_instance.gd")

var _failures: Array[String] = []

# Mirrors network_manager.gd submit_bazaar_list
func _submit_bazaar_list(record: Dictionary, bazaar_listings: Dictionary, item_id: String, price: int, telemetry_log: Array) -> Dictionary:
	var sheet: Dictionary = record.get("sheet", {})
	var inventory: Array = sheet.get("inventory", [])
	var target_idx := -1
	var target_item: Dictionary = {}
	for i in range(inventory.size()):
		var val = inventory[i]
		if typeof(val) == TYPE_DICTIONARY and (String(val.get("id", "")) == item_id or String(val.get("instance_id", "")) == item_id):
			target_idx = i
			target_item = val
			break
			
	if target_idx == -1:
		return {"ok": false, "reason": "item_not_in_inventory"}
		
	var credits := int(sheet.get("credits", 0))
	var character_id := String(record.get("id", ""))
	var outcome := Bazaar.list_item(bazaar_listings, target_item, price, character_id, credits)
	if bool(outcome.get("ok", false)):
		inventory.remove_at(target_idx)
		sheet["inventory"] = inventory
		sheet["credits"] = credits - int(outcome["fee"])
		record["sheet"] = sheet
		telemetry_log.append({"event": "bazaar_list", "item_id": item_id, "price": price, "fee": outcome["fee"]})
		return {"ok": true, "listings": outcome["listings"], "record": record, "fee": outcome["fee"]}
	return {"ok": false, "reason": outcome.get("reason", "failed")}

# Mirrors network_manager.gd submit_bazaar_buy
func _submit_bazaar_buy(buyer_record: Dictionary, seller_record: Dictionary, bazaar_listings: Dictionary, listing_id: String, telemetry_log: Array) -> Dictionary:
	var buyer_sheet: Dictionary = buyer_record.get("sheet", {})
	var buyer_credits := int(buyer_sheet.get("credits", 0))
	var buyer_char := String(buyer_record.get("id", ""))
	
	var outcome := Bazaar.buy_item(bazaar_listings, listing_id, buyer_char, buyer_credits)
	if bool(outcome.get("ok", false)):
		var seller_char := String(outcome["seller_id"])
		var price := int(outcome["price"])
		var item: Dictionary = outcome["item"]
		
		buyer_sheet["credits"] = buyer_credits - price
		var buyer_inv: Array = buyer_sheet.get("inventory", [])
		buyer_inv.append(item)
		buyer_sheet["inventory"] = buyer_inv
		buyer_record["sheet"] = buyer_sheet
		
		if seller_char == String(seller_record.get("id", "")):
			var seller_sheet: Dictionary = seller_record.get("sheet", {})
			seller_sheet["credits"] = int(seller_sheet.get("credits", 0)) + price
			seller_record["sheet"] = seller_sheet
			
		telemetry_log.append({"event": "bazaar_buy", "listing_id": listing_id, "price": price})
		return {"ok": true, "listings": outcome["listings"], "buyer_record": buyer_record, "seller_record": seller_record}
	return {"ok": false, "reason": outcome.get("reason", "failed")}

# Mirrors network_manager.gd submit_use_item
func _submit_use_item(peer_record: Dictionary, target_record: Dictionary, instance_id: String, telemetry_log: Array, rng_seed: int) -> Dictionary:
	var rules = Rules.new()
	var sheet: Dictionary = peer_record.get("sheet", {})
	var inventory: Array = sheet.get("inventory", [])
	var item_idx := -1
	var item: Dictionary = {}
	for i in range(inventory.size()):
		var inv_item = inventory[i]
		if typeof(inv_item) == TYPE_DICTIONARY and String(inv_item.get("instance_id", inv_item.get("id", ""))) == instance_id:
			item_idx = i
			item = inv_item
			break
			
	if item_idx == -1:
		return {"ok": false, "reason": "item_not_found"}
		
	var target_sheet: Dictionary = target_record.get("sheet", {})
	var result = ItemUsage.use_item(sheet, rules, target_sheet, item, rng_seed)
	
	if bool(result.get("ok", false)):
		var consumed = bool(result.get("consumed", false))
		var new_item = result.get("item", item)
		
		if consumed:
			inventory.remove_at(item_idx)
		else:
			inventory[item_idx] = new_item
			
		sheet["inventory"] = inventory
		peer_record["sheet"] = sheet
		target_record["sheet"] = result.get("target_state", target_sheet)
		telemetry_log.append({"event": "item_use", "item_key": item.get("template_key", item.get("template_id", ""))})
		
		return {"ok": true, "peer_record": peer_record, "target_record": target_record, "used_item": new_item}
	return {"ok": false, "reason": result.get("reason", "failed")}
	
func _init() -> void:
	var rules = Rules.new()
	var telemetry_log = []
	var bazaar_listings = {}
	
	# Full JSON records (as they sit in _record_cache)
	var crafter_record = {
		"id": "crafter_1",
		"sheet": {
			"inventory": [],
			"credits": 1000,
			"attributes": {"knowledge": "3D", "technical": "4D"},
			"survival": "5D", 
			"first_aid": "4D",
			"search": "6D", 
			"survey": "6D",
			"wounds": 0,
			"wound_state": "healthy"
		}
	}
	
	var buyer_record = {
		"id": "buyer_1",
		"sheet": {
			"inventory": [],
			"credits": 5000,
			"attributes": {"technical": "2D"},
			"first_aid": "10D",
			"wounds": 2,
			"wound_state": "wounded"
		}
	}
	
	# Step 1: Resource gathering
	var crafter_sheet = crafter_record["sheet"]
	var survey_res = Crafting.roll_survey(crafter_sheet, rules, "mos_eisley", 1234, 100000)
	if not _assert_equal(bool(survey_res.get("ok", false)), true, "Survey should succeed"): return
	var deposit = survey_res
	var harvest_res = Crafting.harvest_resource(crafter_sheet, rules, deposit, 5678, 100050)
	crafter_sheet = harvest_res.get("sheet", crafter_sheet)
	crafter_sheet["inventory"].append(ItemInstance.create("resource_stack", "Organic Tissue", "resource", 50.0, 1, "world", {}, {"resource_type": "organic_tissue"}))
	crafter_sheet["inventory"].append(ItemInstance.create("resource_stack", "Medical Biogel", "resource", 50.0, 1, "world", {}, {"resource_type": "medical_biogel"}))
	crafter_sheet["inventory"][0]["stack_count"] = 5
	crafter_sheet["inventory"][1]["stack_count"] = 5
	
	# Step 2: Craft a medpac instance
	var craft_res = Crafting.craft_item(crafter_sheet, "basic_medpac", rules, 9012, "crafter_1")
	if not _assert_equal(bool(craft_res.get("ok", false)), true, "Craft medpac"): return
	var medpac = craft_res.get("item", {})
	_assert_equal(medpac.get("template_id", ""), "medpac", "Crafted item has correct template_id")
	_assert_equal(medpac.has("instance_id"), true, "Crafted item has instance_id")
	
	crafter_record["sheet"] = craft_res.get("target_state", crafter_sheet)
	crafter_record["sheet"]["inventory"].append(medpac)
	
	# Step 3: List on Bazaar (Server composition mirror)
	var instance_id = medpac["instance_id"]
	var list_res = _submit_bazaar_list(crafter_record, bazaar_listings, instance_id, 1500, telemetry_log)
	if not _assert_equal(bool(list_res.get("ok", false)), true, "Submit bazaar list"): return
	bazaar_listings = list_res["listings"]
	crafter_record = list_res["record"]
	
	var listing_ids = bazaar_listings.keys()
	_assert_equal(listing_ids.size(), 1, "1 listing created")
	var listing_id = listing_ids[0]
	
	# Step 4: Buy from Bazaar (Server composition mirror)
	var buy_res = _submit_bazaar_buy(buyer_record, crafter_record, bazaar_listings, listing_id, telemetry_log)
	if not _assert_equal(bool(buy_res.get("ok", false)), true, "Submit bazaar buy"): return
	bazaar_listings = buy_res["listings"]
	buyer_record = buy_res["buyer_record"]
	crafter_record = buy_res["seller_record"]
	
	# Step 5: Verify credits moved
	_assert_equal(int(buyer_record["sheet"]["credits"]), 5000 - 1500, "Buyer paid 1500")
	var list_fee = int(list_res["fee"])
	_assert_equal(int(crafter_record["sheet"]["credits"]), 1000 - list_fee + 1500, "Crafter paid fee and got 1500")
	
	# Verify item moved
	var buyer_inv = buyer_record["sheet"]["inventory"]
	_assert_equal(buyer_inv.size(), 1, "Buyer has 1 item")
	_assert_equal(buyer_inv[0]["instance_id"], instance_id, "Item instance_id matches")
	_assert_equal(buyer_inv[0]["created_by"], "crafter_1", "Item provenance intact")
	
	# Step 6: Use item (Server composition mirror)
	var initial_condition = buyer_inv[0].get("condition", 5)
	var use_res = _submit_use_item(buyer_record, buyer_record, instance_id, telemetry_log, 3456)
	if not _assert_equal(bool(use_res.get("ok", false)), true, "Submit use item: %s" % str(use_res)): return
	
	var used_item = use_res["used_item"]
	_assert_equal(used_item.get("condition", 5), initial_condition - 1, "Medpac condition degraded after use")
	
	# Verify telemetry logged all steps
	var events = []
	for evt in telemetry_log:
		events.append(evt["event"])
	_assert_true(events.has("bazaar_list"), "telemetry logged bazaar_list")
	_assert_true(events.has("bazaar_buy"), "telemetry logged bazaar_buy")
	_assert_true(events.has("item_use"), "telemetry logged item_use")
	
	if _failures.is_empty():
		print("economy_live_loop_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> bool:
	if str(actual) != str(expected):
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
		for failure in _failures:
			printerr(failure)
		quit(1)
		return false
	return true

func _assert_true(actual: bool, label: String) -> bool:
	if not actual:
		_failures.append("%s: expected true, got false" % label)
		for failure in _failures:
			printerr(failure)
		quit(1)
		return false
	return true
