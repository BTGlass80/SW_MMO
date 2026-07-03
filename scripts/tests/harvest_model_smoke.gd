extends SceneTree
## Headless smoke for the pure creature-harvest model (DIV-0023). Verified against the
## REAL data/creatures_clone_wars.json harvest blocks. Deterministic: every roll is
## seeded, never randomize(). Covers: a creature WITH harvest yields its exact `good`
## and resource; a creature withOUT harvest yields nothing; difficulty gating
## (below-difficulty untrained fails, a big pool succeeds); `yield` honored; the
## RNG-free band helper; determinism (same seed -> same result); unknown key safe;
## resource defaulting; spawn-dict source.

const Harvest := preload("res://scripts/rules/harvest_model.gd")
const CREATURE_DATA_PATH := "res://data/creatures_clone_wars.json"

var _failures: Array[String] = []
var _rules: Object

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	var data := _load_json(CREATURE_DATA_PATH)
	var creatures: Dictionary = data.get("creatures", {})
	_assert_true(not creatures.is_empty(), "creature data has creatures")

	# --- a creature WITH harvest yields its EXACT good (gornt, ungated) ---
	var g := Harvest.roll_harvest(_rules, "gornt", data, null, 1)
	_assert_equal(bool(g["harvestable"]), true, "gornt is harvestable")
	_assert_equal(String(g["good"]), "gornt_meat", "gornt good is exactly gornt_meat (from data)")
	_assert_equal(String(g["resource"]), "organic", "gornt resource is organic (from data)")
	_assert_equal(bool(g["success"]), true, "ungated harvest auto-succeeds")
	_assert_equal(String(g["tier"]), Harvest.TIER_SUCCESS, "ungated tier is success")
	_assert_equal(String(g["reason"]), "auto_success", "ungated reason is auto_success")
	_assert_equal(int(g["quantity"]), 1, "gornt default yield is 1")
	_assert_equal(int(g["difficulty"]), 0, "ungated difficulty reported as 0")

	# --- a creature withOUT a harvest block yields nothing (worrt) ---
	var none := Harvest.roll_harvest(_rules, "worrt", data, null, 1)
	_assert_equal(bool(none["harvestable"]), false, "worrt is not harvestable")
	_assert_equal(String(none["good"]), "", "no harvest -> empty good")
	_assert_equal(int(none["quantity"]), 0, "no harvest -> zero quantity")
	_assert_equal(String(none["reason"]), "no_harvest", "no harvest -> reason no_harvest")
	_assert_equal(Harvest.has_harvest("worrt", data), false, "has_harvest false for worrt")
	_assert_equal(Harvest.has_harvest("gornt", data), true, "has_harvest true for gornt")

	# --- difficulty gating: krayt_dragon (difficulty 15) ---
	# untrained (0D) is a deterministic total of 0 -> clean failure, no yield.
	var untrained := Harvest.roll_harvest(_rules, "krayt_dragon", data, {"dice": 0, "pips": 0}, 7)
	_assert_equal(bool(untrained["harvestable"]), true, "krayt IS harvestable (has a block)")
	_assert_equal(bool(untrained["success"]), false, "untrained 0D fails the krayt difficulty 15")
	_assert_equal(String(untrained["tier"]), Harvest.TIER_FAILURE, "untrained 0D is a clean failure (below partial band)")
	_assert_equal(int(untrained["quantity"]), 0, "failed pearl harvest recovers nothing")
	_assert_equal(String(untrained["good"]), "krayt_dragon_pearl", "good key present even on failure")
	_assert_equal(int(untrained["difficulty"]), 15, "krayt difficulty resolved to 15 from data")
	_assert_equal(String(untrained["reason"]), "skill_failure", "gated miss -> skill_failure")

	# a huge pool clears difficulty 15 regardless of the wild die -> full yield 1.
	var expert := Harvest.roll_harvest(_rules, "krayt_dragon", data, {"dice": 20, "pips": 0}, 7)
	_assert_equal(bool(expert["success"]), true, "20D beats krayt difficulty 15")
	_assert_equal(String(expert["tier"]), Harvest.TIER_SUCCESS, "big pool -> success tier")
	_assert_equal(int(expert["quantity"]), 1, "krayt pearl yield defaults to 1 on success")
	_assert_equal(String(expert["reason"]), "skill_success", "gated hit -> skill_success")

	# spor_crawler (difficulty 10) with a string skill pool that clears it.
	var spor := Harvest.roll_harvest(_rules, "spor_crawler", data, "20D", 3)
	_assert_equal(bool(spor["success"]), true, "20D beats spor difficulty 10")
	_assert_equal(String(spor["good"]), "spor_venom", "spor good is spor_venom (from data)")
	_assert_equal(int(spor["difficulty"]), 10, "spor difficulty resolved to 10 from data")

	# --- yield honored: voroos declares yield 2 (ungated) ---
	var v := Harvest.roll_harvest(_rules, "voroos", data, null, 99)
	_assert_equal(String(v["good"]), "voroos_hide", "voroos good is voroos_hide (from data)")
	_assert_equal(int(v["quantity"]), 2, "voroos yield 2 is honored")

	# --- resource defaulting: acklay_chitin has NO resource key -> DEFAULT_RESOURCE ---
	var ack := Harvest.roll_harvest(_rules, "acklay", data, null, 1)
	_assert_equal(String(ack["good"]), "acklay_chitin", "acklay good is acklay_chitin (from data)")
	_assert_equal(String(ack["resource"]), Harvest.DEFAULT_RESOURCE, "missing resource defaults to salvage")
	_assert_equal(bool(ack["success"]), true, "acklay is ungated -> auto success")

	# --- a spawn-dict source works, not just a key string ---
	var spawn_source := {"creature_key": "gornt", "name": "Gornt", "hostile": false}
	var from_spawn := Harvest.roll_harvest(_rules, spawn_source, data, null, 1)
	_assert_equal(String(from_spawn["good"]), "gornt_meat", "spawn-dict source resolves the same good")

	# --- unknown key is safe ---
	var unknown := Harvest.roll_harvest(_rules, "does_not_exist", data, "5D", 1)
	_assert_equal(bool(unknown["harvestable"]), false, "unknown creature -> not harvestable")
	_assert_equal(String(unknown["reason"]), "unknown_creature", "unknown creature -> reason unknown_creature")
	_assert_equal(int(unknown["quantity"]), 0, "unknown creature -> zero quantity")
	# empty / non-creature sources are also safe
	_assert_equal(String(Harvest.roll_harvest(_rules, "", data, null, 1)["reason"]), "unknown_creature", "empty-string source safe")
	_assert_equal(String(Harvest.roll_harvest(_rules, 12345, data, null, 1)["reason"]), "unknown_creature", "non-string/dict source safe")

	# --- determinism: same seed -> identical result (gated creature that rolls dice) ---
	var d1 := Harvest.roll_harvest(_rules, "draagax", data, "3D", 5150)
	var d2 := Harvest.roll_harvest(_rules, "draagax", data, "3D", 5150)
	_assert_equal(String(d1["good"]), "draagax_fang", "draagax good is draagax_fang (from data)")
	_assert_equal(String(d1["tier"]), String(d2["tier"]), "same seed -> same tier")
	_assert_equal(int(d1["quantity"]), int(d2["quantity"]), "same seed -> same quantity")
	_assert_equal(bool(d1["success"]), bool(d2["success"]), "same seed -> same success")
	_assert_equal(int((d1["roll"] as Dictionary).get("total", -1)), int((d2["roll"] as Dictionary).get("total", -2)), "same seed -> same roll total")
	# a different seed is allowed to differ; just confirm it still parses to the same good/difficulty
	var d3 := Harvest.roll_harvest(_rules, "draagax", data, "3D", 6260)
	_assert_equal(String(d3["good"]), "draagax_fang", "different seed still yields the same good key")
	_assert_equal(int(d3["difficulty"]), 10, "draagax difficulty 10 from data")

	# --- RNG-free band helper (the single source of truth for success/partial/failure) ---
	var b_full := Harvest.outcome_for_margin(3, 2)
	_assert_equal(String(b_full["tier"]), Harvest.TIER_SUCCESS, "margin +3 -> success")
	_assert_equal(int(b_full["quantity"]), 2, "success keeps full yield")
	var b_zero := Harvest.outcome_for_margin(0, 2)
	_assert_equal(String(b_zero["tier"]), Harvest.TIER_SUCCESS, "margin 0 -> success (meets difficulty)")
	var b_partial := Harvest.outcome_for_margin(-2, 2)
	_assert_equal(String(b_partial["tier"]), Harvest.TIER_PARTIAL, "near miss -> partial")
	_assert_equal(int(b_partial["quantity"]), 1, "partial halves a yield-2 good to 1")
	_assert_equal(bool(b_partial["success"]), false, "partial is not a full success")
	var b_partial_edge := Harvest.outcome_for_margin(-Harvest.PARTIAL_MARGIN, 2)
	_assert_equal(String(b_partial_edge["tier"]), Harvest.TIER_PARTIAL, "miss by exactly PARTIAL_MARGIN is still partial")
	var b_partial_single := Harvest.outcome_for_margin(-1, 1)
	_assert_equal(String(b_partial_single["tier"]), Harvest.TIER_PARTIAL, "single-unit near miss is partial")
	_assert_equal(int(b_partial_single["quantity"]), 0, "a single good halves to 0 (ruined) on a partial")
	var b_fail := Harvest.outcome_for_margin(-(Harvest.PARTIAL_MARGIN + 1), 2)
	_assert_equal(String(b_fail["tier"]), Harvest.TIER_FAILURE, "a worse miss -> failure")
	_assert_equal(int(b_fail["quantity"]), 0, "failure recovers nothing")

	# --- describe() is an RNG-free preview that agrees with the data ---
	var desc := Harvest.describe("krayt_dragon", data)
	_assert_equal(bool(desc["harvestable"]), true, "describe: krayt harvestable")
	_assert_equal(bool(desc["gated"]), true, "describe: krayt is gated")
	_assert_equal(int(desc["difficulty"]), 15, "describe: krayt difficulty 15")
	_assert_equal(String(desc["good"]), "krayt_dragon_pearl", "describe: krayt good")
	_assert_equal(bool(Harvest.describe("worrt", data)["harvestable"]), false, "describe: worrt not harvestable")

	# --- EVERY real harvest block round-trips: good is preserved, resource non-empty ---
	var checked := 0
	for ckey in creatures.keys():
		var block := Harvest.harvest_block(data, String(ckey))
		if block.is_empty() or String(block.get("good", "")) == "":
			continue
		checked += 1
		var res := Harvest.roll_harvest(_rules, String(ckey), data, "20D", 2024)
		_assert_equal(String(res["good"]), String(block["good"]), "%s good matches its data block" % ckey)
		_assert_true(String(res["resource"]) != "", "%s resource is non-empty" % ckey)
		_assert_true(bool(res["success"]), "%s with a 20D dresser succeeds" % ckey)
		_assert_true(int(res["quantity"]) >= 1, "%s success yields at least 1" % ckey)
	_assert_true(checked >= 10, "at least ten real creatures carry a harvest block")

	if _rules.has_method("free"):
		_rules.free()

	if _failures.is_empty():
		print("harvest_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
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
