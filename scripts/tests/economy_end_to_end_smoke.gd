extends SceneTree

const HarvestModel = preload("res://scripts/rules/harvest_model.gd")
const CraftingModel = preload("res://scripts/rules/crafting_model.gd")
const BazaarModel = preload("res://scripts/rules/bazaar_model.gd")
const ItemUsageModel = preload("res://scripts/rules/item_usage_model.gd")
const D6Rules = preload("res://scripts/rules/d6_rules.gd")

var _failures: Array[String] = []

func _init():
	_run_end_to_end()

func _submit_bazaar_list(record: Dictionary, bazaar_listings: Dictionary, item_id: String, price: int) -> Dictionary:
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
	var character_id := String(record.get("id", "crafter_1"))
	var outcome := BazaarModel.list_item(bazaar_listings, target_item, price, character_id, credits)
	if bool(outcome.get("ok", false)):
		inventory.remove_at(target_idx)
		sheet["inventory"] = inventory
		sheet["credits"] = credits - int(outcome.get("fee", 0))
		record["sheet"] = sheet
		return {"ok": true, "listings": outcome["listings"], "listing_id": outcome["listing"]["id"]}
	return outcome

func _submit_bazaar_buy(buyer_record: Dictionary, seller_record: Dictionary, bazaar_listings: Dictionary, listing_id: String) -> Dictionary:
	var buyer_sheet: Dictionary = buyer_record.get("sheet", {})
	var buyer_credits := int(buyer_sheet.get("credits", 0))
	var buyer_char := String(buyer_record.get("id", "buyer_1"))
	
	var outcome := BazaarModel.buy_item(bazaar_listings, listing_id, buyer_char, buyer_credits)
	if bool(outcome.get("ok", false)):
		var seller_char := String(outcome["seller_id"])
		var price := int(outcome["price"])
		var item: Dictionary = outcome["item"]
		
		buyer_sheet["credits"] = buyer_credits - price
		var buyer_inv: Array = buyer_sheet.get("inventory", [])
		buyer_inv.append(item)
		buyer_sheet["inventory"] = buyer_inv
		buyer_record["sheet"] = buyer_sheet
		
		if seller_char == String(seller_record.get("id", "crafter_1")):
			var seller_sheet: Dictionary = seller_record.get("sheet", {})
			seller_sheet["credits"] = int(seller_sheet.get("credits", 0)) + price
			seller_record["sheet"] = seller_sheet
			
		return {"ok": true, "listings": outcome["listings"], "item": item}
	return outcome

func _run_end_to_end():
	var rules = D6Rules.new()
	var rng_seed = 999
	
	# Initial Player Records
	var crafter_record = {
		"id": "crafter_1",
		"sheet": {
			"scholar_biology": "4D",
			"inventory": [],
			"credits": 500,
			"wounds": 0
		}
	}
	
	var buyer_record = {
		"id": "buyer_1",
		"sheet": {
			"first_aid": "10D",
			"inventory": [],
			"credits": 5000,
			"wounds": 2
		}
	}
	
	# Phase 1: Survey & Harvest
	var deposit_tissue = {"density": 50, "type": "organic_tissue", "name": "Organic Tissue", "quality": 60.0, "expires_at": 1000}
	var deposit_biogel = {"density": 30, "type": "medical_biogel", "name": "Medical Biogel", "quality": 75.0, "expires_at": 1000}
	
	var h1 = CraftingModel.harvest_resource(crafter_record.get("sheet"), rules, deposit_tissue, rng_seed, 0)
	if not h1.get("ok", false):
		_fail("Failed to harvest organic tissue.")
		
	var h2 = CraftingModel.harvest_resource(h1.get("sheet", crafter_record.get("sheet")), rules, deposit_biogel, rng_seed + 1, 0)
	if not h2.get("ok", false):
		_fail("Failed to harvest medical biogel.")
		
	var c_sheet = h2.get("sheet", crafter_record.get("sheet"))
	crafter_record["sheet"] = c_sheet
	
	# Verify harvest added to inventory
	if c_sheet["inventory"].size() != 2:
		_fail("Crafter inventory should have 2 resource stacks, found %d." % c_sheet["inventory"].size())

	# Phase 2: Craft
	var c = CraftingModel.craft_item(c_sheet, "basic_medpac", rules, rng_seed + 2, "crafter_1")
	if not c.get("ok", false):
		_fail("Failed to craft medpac.")
	crafter_record["sheet"] = c.get("sheet", c_sheet)
	
	var crafted_item = c.get("item", {})
	if crafted_item.is_empty():
		_fail("Crafting did not return an item.")
		
	var instance_id = crafted_item.get("instance_id", "")
	if instance_id == "":
		_fail("Crafted medpac has no instance_id.")
		
	if int(crafted_item.get("stack_count", 0)) != 1:
		_fail("Medpac should have stack_count of 1.")

	# Phase 3: List on Bazaar
	var bazaar_listings: Dictionary = {}
	var l = _submit_bazaar_list(crafter_record, bazaar_listings, instance_id, 250)
	if not l.get("ok", false):
		_fail("Failed to list medpac on bazaar. Reason: " + l.get("reason", "unknown"))
	else:
		bazaar_listings = l["listings"]
	
	var listing_id = l.get("listing_id", "")
	if not bazaar_listings.has(listing_id):
		_fail("Bazaar does not contain the listed item.")
		
	# Check crafter inventory no longer has it
	for i in crafter_record["sheet"]["inventory"]:
		if i.get("instance_id") == instance_id:
			_fail("Crafter inventory still contains the item after listing.")

	# Phase 4: Buy
	var b = _submit_bazaar_buy(buyer_record, crafter_record, bazaar_listings, listing_id)
	if not b.get("ok", false):
		_fail("Buyer failed to buy medpac from bazaar.")
	else:
		bazaar_listings = b["listings"]
	
	if buyer_record["sheet"]["credits"] != 4750:
		_fail("Buyer credits not deducted properly. Expected 4750, got %d." % buyer_record["sheet"]["credits"])
		
	if crafter_record["sheet"]["credits"] != 738:
		_fail("Crafter credits not awarded properly. Expected 738, got %d." % crafter_record["sheet"]["credits"])
		
	var found_in_buyer = false
	var buyer_item = {}
	for i in buyer_record["sheet"]["inventory"]:
		if i.get("instance_id") == instance_id:
			found_in_buyer = true
			buyer_item = i
			break
			
	if not found_in_buyer:
		_fail("Buyer did not receive the purchased item.")
		
	# Phase 5: Use
	var u = ItemUsageModel.use_item(buyer_record["sheet"], rules, buyer_record["sheet"], buyer_item, rng_seed + 3)
	if not u.get("ok", false):
		_fail("Buyer failed to use medpac. Reason: " + u.get("reason", "unknown"))
		
	var next_buyer_sheet = u.get("target_state", buyer_record["sheet"])
	var consumed = u.get("consumed", false)
	var used_item = u.get("item", buyer_item)
	
	if next_buyer_sheet["wounds"] >= 2:
		_fail("Wounds were not healed by the medpac. Wounds: %d" % next_buyer_sheet["wounds"])
		
	if consumed:
		for idx in range(buyer_record["sheet"]["inventory"].size() - 1, -1, -1):
			if buyer_record["sheet"]["inventory"][idx].get("instance_id") == instance_id:
				buyer_record["sheet"]["inventory"].remove_at(idx)
		
		var still_has = false
		for item in buyer_record["sheet"]["inventory"]:
			if item.get("instance_id") == instance_id:
				still_has = true
		if still_has:
			_fail("Item was consumed but inventory is not empty.")
	else:
		if int(used_item.get("condition", 0)) >= int(buyer_item.get("condition", 5)):
			_fail("Item was not consumed but condition did not decrease.")
			
	_finish()

func _fail(msg: String):
	_failures.append(msg)

func _finish():
	if _failures.is_empty():
		print("economy_end_to_end_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)
