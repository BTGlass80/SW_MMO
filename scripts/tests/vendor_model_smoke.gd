extends SceneTree

const WEAPONS_DATA_PATH = "res://data/weapons_clone_wars.json"
const ARMOR_DATA_PATH = "res://data/armor_clone_wars.json"
const DROIDS_DATA_PATH = "res://data/droids_clone_wars.json"

var _failures = []

func _init() -> void:
	# Seed RNG even though this model is deterministic (convention: never randomize()).
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	var model_script = load("res://scripts/rules/vendor_model.gd")
	var model = model_script.new()

	var weapons_data = _load_json(WEAPONS_DATA_PATH)
	var armor_data = _load_json(ARMOR_DATA_PATH)
	var droids_data = _load_json(DROIDS_DATA_PATH)

	# --- list_stock -------------------------------------------------------
	var stock: Array = model.list_stock(weapons_data, armor_data)
	var stock_keys := {}
	for entry in stock:
		stock_keys[String(entry["key"])] = entry

	# INCLUDES blaster_pistol (vendor_stocked:true weapon).
	_assert_true(stock_keys.has("blaster_pistol"), "list_stock includes blaster_pistol")
	if stock_keys.has("blaster_pistol"):
		var bp = stock_keys["blaster_pistol"]
		_assert_equal(bp["kind"], "weapon", "blaster_pistol kind is weapon")
		_assert_equal(bp["name"], "Blaster Pistol", "blaster_pistol name")
		_assert_equal(bp["base_cost"], 500, "blaster_pistol base_cost")

	# EXCLUDES a known vendor_stocked:false weapon (stun_pistol in the data).
	_assert_true(weapons_data.get("weapons", {}).get("stun_pistol", {}).get("vendor_stocked", true) == false,
		"data sanity: stun_pistol is vendor_stocked:false")
	_assert_true(not stock_keys.has("stun_pistol"), "list_stock excludes stun_pistol (vendor_stocked:false)")
	# Also confirm a faction-issued weapon (cost 0, vendor_stocked:false) is excluded.
	_assert_true(not stock_keys.has("dc17_pistol"), "list_stock excludes faction dc17_pistol")

	# Armor: blast_vest is vendor_stocked:true -> included as kind armor.
	_assert_true(stock_keys.has("blast_vest"), "list_stock includes blast_vest")
	if stock_keys.has("blast_vest"):
		_assert_equal(stock_keys["blast_vest"]["kind"], "armor", "blast_vest kind is armor")
		_assert_equal(stock_keys["blast_vest"]["base_cost"], 300, "blast_vest base_cost")
	# Armor: bounty_hunter_armor is vendor_stocked:false -> excluded.
	_assert_true(not stock_keys.has("bounty_hunter_armor"), "list_stock excludes bounty_hunter_armor")

	# Stable sorted-by-key order.
	var sorted_keys := []
	for entry in stock:
		sorted_keys.append(String(entry["key"]))
	var expected_sorted := sorted_keys.duplicate()
	expected_sorted.sort()
	_assert_equal(sorted_keys, expected_sorted, "list_stock returned sorted-by-key order")

	# --- bargain_discount -------------------------------------------------
	# Compute the expected value the same way the spec defines it.
	var expected_discount := clampf((3.0 + 1.0 / 3.0) * model.BARGAIN_PCT_PER_DIE, 0.0, 0.5)
	var actual_discount: float = model.bargain_discount(3, 1)
	_assert_true(is_equal_approx(actual_discount, expected_discount),
		"bargain_discount(3,1) == clamp((3+1/3)*0.03) [%f vs %f]" % [actual_discount, expected_discount])
	# (3 + 1/3) * 0.03 == 0.1 exactly.
	_assert_true(is_equal_approx(actual_discount, 0.1), "bargain_discount(3,1) is 0.1")
	# Zero bargain -> zero discount.
	_assert_true(is_equal_approx(model.bargain_discount(0, 0), 0.0), "bargain_discount(0,0) is 0.0")
	# Clamp ceiling at 0.5.
	_assert_true(is_equal_approx(model.bargain_discount(100, 0), 0.5), "bargain_discount clamps to 0.5")

	# --- quote ------------------------------------------------------------
	# quote(500,1.0,3,1): compute the same way, then assert the exact int.
	var expected_quote_a := int(round(500.0 * 1.0 * (1.0 - model.bargain_discount(3, 1))))
	var actual_quote_a: int = model.quote(500, 1.0, 3, 1)
	_assert_equal(actual_quote_a, expected_quote_a, "quote(500,1.0,3,1) matches recomputed int")
	_assert_equal(actual_quote_a, 450, "quote(500,1.0,3,1) == 450")

	# quote(500,0.85,0,0) == int(round(425.0)) == 425.
	_assert_equal(model.quote(500, 0.85, 0, 0), int(round(425.0)), "quote(500,0.85,0,0) == int(round(425.0))")
	_assert_equal(model.quote(500, 0.85, 0, 0), 425, "quote(500,0.85,0,0) == 425")

	# --- director_multiplier_for_event ------------------------------------
	_assert_true(is_equal_approx(model.director_multiplier_for_event("trade_boom"), 0.85),
		"director_multiplier_for_event(trade_boom) == 0.85")
	_assert_true(is_equal_approx(model.director_multiplier_for_event("merchant_arrival"), 0.9),
		"director_multiplier_for_event(merchant_arrival) == 0.9")
	_assert_true(is_equal_approx(model.director_multiplier_for_event("scarcity"), 1.0),
		"director_multiplier_for_event(unknown) == 1.0")
	_assert_true(is_equal_approx(model.director_multiplier_for_event(""), 1.0),
		"director_multiplier_for_event(empty) == 1.0")

	# --- droid bargain tiers feed bargain_discount ------------------------
	# Sanity that the droid bargain fields wire through (gn12 = 3 dice +1 pip).
	var droids: Dictionary = droids_data.get("droids", {})
	var gn12: Dictionary = droids.get("gn12", {})
	_assert_true(is_equal_approx(
			model.bargain_discount(int(gn12.get("bargain_dice", 0)), int(gn12.get("bargain_pips", 0))),
			0.1),
		"gn12 droid bargain (3,1) discount is 0.1")

	if _failures.is_empty():
		print("vendor_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _load_json(path):
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % path)
		return {}
	return parsed

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append("%s: expected true" % label)
