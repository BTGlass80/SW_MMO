extends SceneTree
## Flow guard for the LIVE harvest wiring (DIV-0023, Seam 1, Option A). network_manager is a Node autoload
## not headlessly instantiable, so — like death_flow_smoke mirrors _resolve_combat_window / _handle_player_death
## — this mirrors the SERVER COMPOSITION around the pure harvest_model + the new data/harvest_values table:
## a harvestable hostile disable -> HarvestModel.roll_harvest -> a value lookup -> a credit award > 0; a
## NON-harvestable creature -> no harvest award; determinism under a fixed server seed; and the value table
## covers EVERY resource bucket used by a real harvest block. harvest_model_smoke covers the pure roll math;
## this locks the credit wiring (the good descriptor -> credits path).

const Harvest := preload("res://scripts/rules/harvest_model.gd")
const CREATURE_DATA_PATH := "res://data/creatures_clone_wars.json"
const HARVEST_VALUES_PATH := "res://data/harvest_values_clone_wars.json"

var _failures: Array[String] = []
var _rules: Object

# --- mirrors of the network_manager server helpers under test ---

# mirror of _harvest_value_per_unit: per-good override -> resource bucket -> default.
func _value_per_unit(table: Dictionary, good: String, resource: String) -> int:
	var by_good: Dictionary = table.get("by_good", {})
	if by_good.has(good):
		return maxi(int(by_good[good]), 0)
	var by_resource: Dictionary = table.get("by_resource", {})
	if by_resource.has(resource):
		return maxi(int(by_resource[resource]), 0)
	return maxi(int(table.get("default", 0)), 0)

# mirror of _maybe_harvest: roll -> quantity>0 gate -> value*qty awarded to the shooter's wallet.
# Returns the credits GRANTED (0 when nothing recovered / non-harvestable). No arena/state/RPC.
func _harvest_award(source, data: Dictionary, table: Dictionary, skill_pool, seed: int) -> Dictionary:
	if not Harvest.has_harvest(source, data):
		return {"granted": 0, "good": "", "quantity": 0}
	var result: Dictionary = Harvest.roll_harvest(_rules, source, data, skill_pool, seed)
	var qty := int(result.get("quantity", 0))
	if not bool(result.get("harvestable", false)) or qty <= 0:
		return {"granted": 0, "good": String(result.get("good", "")), "quantity": 0}
	var value := _value_per_unit(table, String(result.get("good", "")), String(result.get("resource", ""))) * qty
	return {"granted": value, "good": String(result.get("good", "")), "quantity": qty, "resource": String(result.get("resource", ""))}

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	var data := _load_json(CREATURE_DATA_PATH)
	var table := _load_json(HARVEST_VALUES_PATH)
	var creatures: Dictionary = data.get("creatures", {})
	_assert_true(not creatures.is_empty(), "creature data has creatures")
	_assert_true(table.has("by_resource") and table.has("default"), "harvest value table has by_resource + default")
	_assert_true(String(table.get("source_policy", "")) != "", "harvest value table carries a source_policy note")

	# --- a harvestable ungated creature (gornt) grants credits = value(good) * quantity ---
	var g := _harvest_award("gornt", data, table, null, 11)
	_assert_equal(String(g["good"]), "gornt_meat", "gornt yields gornt_meat")
	_assert_equal(int(g["quantity"]), 1, "gornt yield 1")
	_assert_true(int(g["granted"]) > 0, "a harvestable disable grants harvest credits > 0")
	_assert_equal(int(g["granted"]), _value_per_unit(table, "gornt_meat", "organic") * 1, "gornt credits = value * quantity")

	# --- yield honored end to end: voroos yields 2 -> credits = value * 2 ---
	var v := _harvest_award("voroos", data, table, null, 11)
	_assert_equal(int(v["quantity"]), 2, "voroos yield 2 honored through the wiring")
	_assert_equal(int(v["granted"]), _value_per_unit(table, "voroos_hide", "organic") * 2, "voroos credits scale with quantity")

	# --- the fortune good: a skilled dresser clears krayt difficulty 15 -> the big pearl value ---
	var pearl := _harvest_award("krayt_dragon", data, table, {"dice": 20, "pips": 0}, 7)
	_assert_true(int(pearl["granted"]) > int(g["granted"]), "a krayt pearl is worth far more than gornt meat")
	_assert_equal(int(pearl["granted"]), _value_per_unit(table, "krayt_dragon_pearl", "gem"), "pearl credits = its by_good override")

	# --- a gated FAILURE grants nothing: untrained (0D) vs krayt difficulty 15 -> quantity 0 -> 0 credits ---
	var failed := _harvest_award("krayt_dragon", data, table, {"dice": 0, "pips": 0}, 7)
	_assert_equal(int(failed["granted"]), 0, "an untrained field-dresser recovers nothing from the krayt -> no credits")

	# --- a NON-harvestable creature grants nothing beyond loot (worrt has no harvest block) ---
	var none := _harvest_award("worrt", data, table, "5D", 11)
	_assert_equal(int(none["granted"]), 0, "a non-harvestable creature grants NO harvest credits")
	_assert_equal(String(none["good"]), "", "non-harvestable -> empty good")
	# a spawn-dict source resolves identically to the key
	var from_spawn := _harvest_award({"creature_key": "gornt", "hostile": true}, data, table, null, 11)
	_assert_equal(int(from_spawn["granted"]), int(g["granted"]), "a spawn-dict source harvests the same as the key")

	# --- determinism: same seed -> identical grant on a GATED (dice-rolling) creature ---
	var d1 := _harvest_award("draagax", data, table, "3D", 5150)
	var d2 := _harvest_award("draagax", data, table, "3D", 5150)
	_assert_equal(int(d1["granted"]), int(d2["granted"]), "same seed -> identical harvest credits (deterministic)")
	_assert_equal(String(d1["good"]), "draagax_fang", "draagax yields draagax_fang")

	# --- the value table covers EVERY resource bucket used by a real harvest block ---
	# (blocks with no `resource` key fall to Harvest.DEFAULT_RESOURCE, so include that bucket too.)
	var by_resource: Dictionary = table.get("by_resource", {})
	var seen := {}
	var harvest_blocks := 0
	for ckey in creatures.keys():
		var block := Harvest.harvest_block(data, String(ckey))
		if block.is_empty() or String(block.get("good", "")) == "":
			continue
		harvest_blocks += 1
		var res := String(block.get("resource", Harvest.DEFAULT_RESOURCE))
		if res == "":
			res = Harvest.DEFAULT_RESOURCE
		seen[res] = true
		# every real good, harvested by an expert, grants a positive credit value
		var award := _harvest_award(String(ckey), data, table, "20D", 2024)
		_assert_true(int(award["granted"]) > 0, "%s grants positive harvest credits with an expert dresser" % ckey)
	for res in seen.keys():
		_assert_true(by_resource.has(String(res)), "value table's by_resource covers the '%s' bucket" % res)
	_assert_true(harvest_blocks >= 10, "at least ten creatures carry a harvest block (sanity)")

	if _rules.has_method("free"):
		_rules.free()

	if _failures.is_empty():
		print("harvest_wire_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % path)
		return {}
	return parsed

func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
