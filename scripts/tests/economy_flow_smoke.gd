extends SceneTree
## Flow guard for the Wave F economy RPCs (S7-S10). network_manager is a Node autoload that is not
## headlessly instantiable, so — like heal_flow_smoke / claim_flow_smoke — this mirrors its
## submit_buy / submit_sell / submit_vendor_list / _award_credits COMPOSITION around the REAL
## EconomyModel + VendorModel + ReputationModel: the merged priced catalog, the buy-price stack
## (Director multiplier x Bargain x rep discount), the credit debit/credit + inventory mutation, and
## the reject precedence. economy_model_smoke / vendor_model_smoke cover the pure math; this locks the
## server composition (DIV-0018).

const EconomyModel := preload("res://scripts/rules/economy_model.gd")
const VendorModel := preload("res://scripts/rules/vendor_model.gd")
const ReputationModel := preload("res://scripts/rules/reputation_model.gd")

var _failures: Array[String] = []
var _rules
var _vendor
var _reputation

# --- faithful mirrors of the network_manager helpers ---
func _build_catalog(weapons: Dictionary, armor: Dictionary) -> Dictionary:
	var cat := {}
	for k in weapons:
		var w: Dictionary = weapons[k]
		cat[String(k)] = {"cost": int(w.get("cost", 0)), "vendor_stocked": bool(w.get("vendor_stocked", false)), "name": String(w.get("name", k)), "kind": "weapon"}
	for k in armor:
		var a: Dictionary = armor[k]
		cat[String(k)] = {"cost": int(a.get("cost", 0)), "vendor_stocked": bool(a.get("vendor_stocked", false)), "name": String(a.get("name", k)), "kind": "armor"}
	return cat

func _bargain(sheet: Dictionary) -> Dictionary:
	var p: Dictionary = _rules.parse_pool(String((sheet.get("skills", {}) as Dictionary).get("bargain", "0D")))
	return {"dice": int(p.get("dice", 0)), "pips": int(p.get("pips", 0))}

func _rep_tier(record: Dictionary) -> String:
	var org: Variant = record.get("org", {})
	if typeof(org) != TYPE_DICTIONARY:
		return "neutral"
	return _reputation.standing_tier(int((org as Dictionary).get("faction_rep", 0)))

func _buy_price(record: Dictionary, list_cost: int, event_type: String) -> int:
	var b := _bargain(record.get("sheet", {}))
	return EconomyModel.buy_price(list_cost, _vendor.director_multiplier_for_event(event_type), int(b["dice"]), int(b["pips"]), _rep_tier(record), _vendor)

func _buy(record: Dictionary, catalog: Dictionary, key: String, event_type: String) -> Dictionary:
	if not catalog.has(key):
		return {"ok": false, "reason": "unknown_item", "price": 0}
	var price := _buy_price(record, int((catalog[key] as Dictionary)["cost"]), event_type)
	var result: Dictionary = EconomyModel.buy(record.get("sheet", {}), key, price, catalog)
	if bool(result["ok"]):
		record["sheet"] = result["sheet"]
	return {"ok": bool(result["ok"]), "reason": String(result["reason"]), "price": price}

func _sell(record: Dictionary, catalog: Dictionary, instance_id: String) -> Dictionary:
	var sheet: Dictionary = record.get("sheet", {})
	var key := ""
	for item in EconomyModel._owned_list(sheet):
		if typeof(item) == TYPE_DICTIONARY and item.get("instance_id", "") == instance_id:
			key = item.get("template_id", "")
			break
	if key == "":
		return {"ok": false, "reason": "not_owned", "price": 0}
	if not catalog.has(key):
		return {"ok": false, "reason": "unknown_item", "price": 0}
	var price := EconomyModel.sell_price(int((catalog[key] as Dictionary)["cost"]))
	var result: Dictionary = EconomyModel.sell(sheet, instance_id, price)
	if bool(result["ok"]):
		record["sheet"] = result["sheet"]
	return {"ok": bool(result["ok"]), "reason": String(result["reason"]), "price": price}

func _award(record: Dictionary, amount: int) -> void:  # mirror _award_credits (floored at 0)
	var sheet: Dictionary = record["sheet"]
	sheet["credits"] = maxi(int(sheet.get("credits", 0)) + amount, 0)
	record["sheet"] = sheet

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	_vendor = VendorModel.new()
	_reputation = ReputationModel.new()

	var weapons := {
		"blaster_pistol": {"cost": 500, "vendor_stocked": true, "name": "Blaster Pistol"},
		"hold_out_blaster": {"cost": 275, "vendor_stocked": true, "name": "Hold-Out Blaster"},
		"disruptor": {"cost": 900, "vendor_stocked": false, "name": "Contraband Disruptor"},
	}
	var armor := {"blast_vest": {"cost": 300, "vendor_stocked": true, "name": "Blast Vest"}}
	var catalog := _build_catalog(weapons, armor)
	_assert_true(catalog.has("blaster_pistol") and catalog.has("blast_vest"), "merged catalog carries weapons + armor")
	_assert_equal(int((catalog["blast_vest"] as Dictionary)["cost"]), 300, "armor cost merged")

	# --- BUY: primary sink. Debits credits, appends to inventory; precedence unknown -> not_stocked -> afford ---
	var rec := {"sheet": {"credits": 1000, "skills": {}, "equipment": {}, "inventory": []}}
	var b1 := _buy(rec, catalog, "blaster_pistol", "")
	_assert_true(bool(b1["ok"]) and int(b1["price"]) == 500, "buy blaster_pistol at list 500 (markup 1.0)")
	_assert_equal(int((rec["sheet"] as Dictionary)["credits"]), 500, "credits debited to 500")
	var rec_has_blaster = false
	for item in (rec["sheet"]["inventory"] as Array):
		if typeof(item) == TYPE_DICTIONARY and item.get("template_id", "") == "blaster_pistol":
			rec_has_blaster = true
			break
	_assert_true(rec_has_blaster, "bought item enters inventory")
	_buy(rec, catalog, "blaster_pistol", "")  # -> 0
	_assert_equal(int((rec["sheet"] as Dictionary)["credits"]), 0, "second buy zeroes the wallet")
	_assert_equal(String(_buy(rec, catalog, "blaster_pistol", "")["reason"]), "cannot_afford", "broke -> cannot_afford")
	_assert_equal(String(_buy(rec, catalog, "nope", "")["reason"]), "unknown_item", "unknown item rejected")
	_assert_equal(String(_buy(rec, catalog, "disruptor", "")["reason"]), "not_stocked", "contraband (vendor_stocked false) -> not_stocked")

	# --- SELL: 40% buy-back; rejects not-owned + equipped ---
	var rec2 := {"sheet": {"credits": 1000, "skills": {}, "equipment": {}, "inventory": ["hold_out_blaster"]}}
	rec2["sheet"]["inventory"] = EconomyModel._owned_list(rec2["sheet"])
	var holdout_id = ""
	for item in (rec2["sheet"]["inventory"] as Array):
		if typeof(item) == TYPE_DICTIONARY and item.get("template_id", "") == "hold_out_blaster":
			holdout_id = item.get("instance_id", "")
			break
	var s1 := _sell(rec2, catalog, holdout_id)
	_assert_true(bool(s1["ok"]) and int(s1["price"]) == 110, "sell hold_out (275) pays 40% = 110")
	_assert_equal(int((rec2["sheet"] as Dictionary)["credits"]), 1110, "sell credits the wallet")
	_assert_equal(String(_sell(rec2, catalog, holdout_id)["reason"]), "not_owned", "cannot sell what you no longer own")
	var rec3 := {"sheet": {"credits": 0, "skills": {}, "equipment": {"weapon": "blaster_pistol"}, "inventory": ["blaster_pistol"]}}
	rec3["sheet"]["inventory"] = EconomyModel._owned_list(rec3["sheet"])
	var blaster_id = ""
	for item in (rec3["sheet"]["inventory"] as Array):
		if typeof(item) == TYPE_DICTIONARY and item.get("template_id", "") == "blaster_pistol":
			blaster_id = item.get("instance_id", "")
			break
	_assert_equal(String(_sell(rec3, catalog, blaster_id)["reason"]), "equipped", "cannot sell a currently-equipped item")
	_assert_equal(String(_sell(rec3, catalog, "ghost_item")["reason"]), "not_owned", "sell unknown item rejected")

	# --- PRICE STACK: Director multiplier x Bargain x rep discount, all through the server helper ---
	var plain := {"sheet": {"credits": 9999, "skills": {}}}
	_assert_equal(_buy_price(plain, 500, "trade_boom"), 425, "trade_boom (0.85) drops 500 -> 425")
	var haggler := {"sheet": {"credits": 9999, "skills": {"bargain": "3D"}}}
	_assert_equal(_buy_price(haggler, 500, ""), 455, "Bargain 3D (9%) drops 500 -> 455")
	var allied := {"sheet": {"credits": 9999, "skills": {}}, "org": {"faction_rep": 80}}
	_assert_equal(_rep_tier(allied), "allied", "faction_rep 80 -> allied standing")
	_assert_equal(_buy_price(allied, 500, ""), 450, "allied rep (10%) drops 500 -> 450")

	# --- vendor stock listing: only stocked items, buy >= sell ---
	var stock: Array = _vendor.list_stock({"weapons": weapons}, {"armor": armor})
	var keys := []
	for it in stock:
		keys.append(String((it as Dictionary)["key"]))
	_assert_true(not keys.has("disruptor"), "vendor stock excludes contraband")
	_assert_true(keys.has("blaster_pistol") and keys.has("blast_vest"), "vendor stock includes the stocked items")
	for it in stock:
		var lc := int((it as Dictionary)["base_cost"])
		_assert_true(EconomyModel.sell_price(lc) <= EconomyModel.buy_price(lc, 1.0, 0, 0, "neutral", _vendor), "buy >= sell for %s (the churn spread)" % String((it as Dictionary)["key"]))

	# --- _award_credits floors at 0 ---
	var rec4 := {"sheet": {"credits": 500}}
	_award(rec4, -2000)
	_assert_equal(int((rec4["sheet"] as Dictionary)["credits"]), 0, "credit debit floors at 0 (never negative)")
	_award(rec4, 30)
	_assert_equal(int((rec4["sheet"] as Dictionary)["credits"]), 30, "credit gain adds normally")

	if _rules.has_method("free"):
		_rules.free()
	if _failures.is_empty():
		print("economy_flow_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
