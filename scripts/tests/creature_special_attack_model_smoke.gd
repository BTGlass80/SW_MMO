extends SceneTree
## Smoke for the pure creature special-attack rider model, exercised against REAL data
## (data/creatures_clone_wars.json). Covers: poison schedule length/onset offsets/per-tick damage
## (hitcher_crab 2D+2 onset 1, spor_crawler 5D onset 0), a restraint break descriptor (stalker_lizard
## constriction, glim_worm empty-hold grapple, preying_makthier restraint+poison combo), a non-special
## creature yielding nothing, an unknown key being safe, the 0D paralytic poison case, and determinism
## (same seed -> same schedule). All rolls are SEED-driven; no randomize().

const CREATURE_DATA_PATH := "res://data/creatures_clone_wars.json"
const Model = preload("res://scripts/rules/creature_special_attack_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var rules = load("res://scripts/rules/d6_rules.gd").new()
	var data := _load_json(CREATURE_DATA_PATH)
	var creatures: Dictionary = data.get("creatures", {})
	_assert_true(not creatures.is_empty(), "creature data has creatures")
	_assert_true(creatures.has("hitcher_crab") and creatures.has("spor_crawler"), "expected test creatures present")

	# --- hitcher_crab: poison 2D+2, rounds 2, onset 1 -----------------------------------------
	var hc_rider := Model.special_attack_for(data, "hitcher_crab")
	_assert_true(not hc_rider.is_empty(), "hitcher_crab has a special_attack rider")
	var hc_poison := Model.poison_rider(hc_rider)
	_assert_true(not hc_poison.is_empty(), "hitcher_crab has a poison rider")
	var hc_sched := Model.poison_schedule(hc_poison, rules, 777)
	# length honors `rounds` (2); onset (1) is carried in the round numbers (first=2, last=3).
	_assert_equal(hc_sched.size(), 2, "hitcher_crab schedule length == rounds (2)")
	_assert_equal(int(hc_sched[0]["round"]), 2, "onset 1 -> first tick on round onset+1 (2)")
	_assert_equal(int(hc_sched[1]["round"]), 3, "last tick on round onset+rounds (3)")
	_assert_equal(String(hc_sched[0]["pool_text"]), "2D+2", "hitcher_crab tick pool is 2D+2")
	for tick in hc_sched:
		_assert_true(int(tick["total"]) >= 1, "each hitcher_crab tick deals >= 1 real WEG damage")

	# --- spor_crawler: poison 5D, rounds 3, onset 0 -------------------------------------------
	var sc_poison := Model.poison_rider(Model.special_attack_for(data, "spor_crawler"))
	_assert_true(not sc_poison.is_empty(), "spor_crawler has a poison rider")
	var sc_sched := Model.poison_schedule(sc_poison, rules, 51)
	_assert_equal(sc_sched.size(), 3, "spor_crawler schedule length == rounds (3)")
	_assert_equal(int(sc_sched[0]["round"]), 1, "onset 0 -> first tick on round 1")
	_assert_equal(String(sc_sched[0]["pool_text"]), "5D", "spor_crawler tick pool is 5D")
	for tick in sc_sched:
		_assert_true(int(tick["total"]) >= 1, "each spor_crawler 5D tick deals >= 1 damage")

	# --- restraint: stalker_lizard constriction, STR-relative hold_damage ---------------------
	var sl_restraint := Model.restraint_rider(Model.special_attack_for(data, "stalker_lizard"))
	var sl_desc := Model.restraint_descriptor(sl_restraint)
	_assert_true(not sl_desc.is_empty(), "stalker_lizard yields a restraint descriptor")
	_assert_equal(String(sl_desc["kind"]), "constriction", "stalker_lizard restraint kind is constriction")
	_assert_equal(String(sl_desc["break_check"]), "opposed brawling/STR", "break_check is opposed brawling/STR")
	_assert_true(bool(sl_desc["has_hold_damage"]), "stalker_lizard has crush hold_damage")
	# hold_damage "STR+2D+2" resolved against STR 3D -> 5D+2.
	var sl_hold := Model.resolve_hold_damage_pool(rules, sl_restraint, {"dice": 3, "pips": 0})
	_assert_equal(rules.pool_to_string(sl_hold), "5D+2", "STR+2D+2 @ STR 3D resolves to 5D+2")

	# --- restraint with EMPTY hold_damage: glim_worm grapple ----------------------------------
	var gw_restraint := Model.restraint_rider(Model.special_attack_for(data, "glim_worm"))
	var gw_desc := Model.restraint_descriptor(gw_restraint)
	_assert_true(not gw_desc.is_empty(), "glim_worm yields a restraint descriptor")
	_assert_equal(String(gw_desc["hold_damage"]), "", "glim_worm hold_damage is empty")
	_assert_true(not bool(gw_desc["has_hold_damage"]), "empty hold_damage -> has_hold_damage false")
	var gw_hold := Model.resolve_hold_damage_pool(rules, gw_restraint, {"dice": 4, "pips": 0})
	_assert_equal(rules.pool_to_string(gw_hold), "0D", "empty hold_damage resolves to 0D (pure hold, no crush)")

	# --- combo creature: preying_makthier carries BOTH restraint AND poison -------------------
	if creatures.has("preying_makthier"):
		var pm := Model.describe(data, "preying_makthier", rules, 9)
		_assert_true(bool(pm["has_special_attack"]), "preying_makthier has_special_attack")
		_assert_equal((pm["poison_schedule"] as Array).size(), 5, "preying_makthier poison lasts 5 rounds")
		_assert_true(not (pm["restraint"] as Dictionary).is_empty(), "preying_makthier also has a restraint descriptor")
		_assert_equal(String((pm["restraint"] as Dictionary).get("dex_penalty", "")), "2D", "restraint carries the 2D dex_penalty rider")

	# --- 0D paralytic poison (rock_wart): schedule present, ticks are 0 (status, not HP) -------
	if creatures.has("rock_wart"):
		var rw_poison := Model.poison_rider(Model.special_attack_for(data, "rock_wart"))
		var rw_sched := Model.poison_schedule(rw_poison, rules, 3)
		_assert_equal(rw_sched.size(), int(rw_poison.get("rounds", -1)), "rock_wart 0D schedule length == rounds")
		if not rw_sched.is_empty():
			_assert_equal(int(rw_sched[0]["total"]), 0, "0D paralytic tick deals 0 HP damage (server reads it as a status)")

	# --- non-special creature yields NOTHING --------------------------------------------------
	_assert_true(creatures.has("worrt"), "worrt present (a creature without special_attack)")
	_assert_true(Model.special_attack_for(data, "worrt").is_empty(), "worrt has no special_attack rider")
	_assert_true(not Model.has_special_attack(data, "worrt"), "has_special_attack false for worrt")
	var worrt_desc := Model.describe(data, "worrt", rules, 1)
	_assert_true(not bool(worrt_desc["has_special_attack"]), "describe: worrt has_special_attack false")
	_assert_true((worrt_desc["poison_schedule"] as Array).is_empty(), "worrt yields an empty poison schedule")
	_assert_true((worrt_desc["restraint"] as Dictionary).is_empty(), "worrt yields no restraint descriptor")

	# --- unknown creature_key is SAFE ---------------------------------------------------------
	_assert_true(Model.special_attack_for(data, "does_not_exist").is_empty(), "unknown key -> empty rider")
	_assert_true(Model.poison_schedule(Model.poison_rider({}), rules, 1).is_empty(), "empty rider -> empty schedule")
	_assert_true(Model.restraint_descriptor({}).is_empty(), "empty restraint -> empty descriptor")
	var missing := Model.describe(data, "does_not_exist", rules, 1)
	_assert_true(not bool(missing["has_special_attack"]), "unknown key describe: has_special_attack false")

	# --- determinism: same seed -> identical schedule -----------------------------------------
	var det_a := Model.poison_schedule(hc_poison, rules, 4242)
	var det_b := Model.poison_schedule(hc_poison, rules, 4242)
	_assert_equal(_totals(det_a), _totals(det_b), "same seed -> identical schedule totals")
	_assert_equal(_rounds(det_a), _rounds(det_b), "same seed -> identical schedule rounds")
	# and a single tick reproduces its schedule entry off the same (seed, round).
	var lone := Model.poison_tick(hc_poison, rules, 4242, 2)
	_assert_equal(int(lone["total"]), int(det_a[0]["total"]), "poison_tick(seed, round) reproduces the schedule entry")

	# --- REGRESSION: the rider is READ-ONLY over the shared creatures_data. describe()/
	# special_attack_for must hand back an INDEPENDENT copy, never a live reference into the global
	# creature table -- the server will consume/mutate a baked bundle (decrementing rounds, marking
	# ticks) and that must NOT corrupt every future spawn of the same creature key. ---
	var src_rounds := int(((creatures["hitcher_crab"] as Dictionary)["special_attack"] as Dictionary)["poison"]["rounds"])
	var baked := Model.describe(data, "hitcher_crab", rules, 1)
	var baked_poison := baked["poison"] as Dictionary
	if not baked_poison.is_empty():
		baked_poison["rounds"] = 999  # simulate the server mutating the bundle it is applying
	var src_rounds_after := int(((creatures["hitcher_crab"] as Dictionary)["special_attack"] as Dictionary)["poison"]["rounds"])
	_assert_equal(src_rounds_after, src_rounds, "mutating a baked bundle must NOT corrupt the shared creature table")
	# special_attack_for itself returns an independent copy: mutating one lookup can't be seen by the next.
	var rider_a := Model.special_attack_for(data, "hitcher_crab")
	(rider_a["poison"] as Dictionary)["rounds"] = 42
	var rider_b := Model.special_attack_for(data, "hitcher_crab")
	_assert_equal(int((rider_b["poison"] as Dictionary)["rounds"]), 2, "special_attack_for returns an independent copy (rider mutation does not leak)")

	if _failures.is_empty():
		print("creature_special_attack_model_smoke: OK")
		rules.free()  # d6_rules extends Node
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		rules.free()
		quit(1)

func _totals(schedule: Array) -> Array:
	var out: Array = []
	for t in schedule:
		out.append(int(t["total"]))
	return out

func _rounds(schedule: Array) -> Array:
	var out: Array = []
	for t in schedule:
		out.append(int(t["round"]))
	return out

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
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
