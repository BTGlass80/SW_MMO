extends SceneTree

var _failures = []

func _init() -> void:
	var model_script = load("res://scripts/rules/reputation_model.gd")
	var model = model_script.new()

	# Seed a deterministic RNG even though the model uses none, per harness convention.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20204

	# --- AXES + constants ---
	_assert_equal(model.AXES.size(), 5, "five reputation axes")
	_assert_equal(model.AXES, ["republic", "cis", "hutt", "independent", "bounty_hunters_guild"], "axis names match zone_state + guild")
	_assert_equal(model.REP_MIN, -100, "REP_MIN")
	_assert_equal(model.REP_MAX, 100, "REP_MAX")

	# --- initial_reputation: every axis -> 0 ---
	var initial: Dictionary = model.initial_reputation()
	_assert_equal(initial.size(), 5, "initial reputation has one entry per axis")
	for axis in model.AXES:
		_assert_equal(int(initial.get(axis, 999)), 0, "initial %s is zero" % axis)

	# --- clamp_value bounds ---
	_assert_equal(model.clamp_value(200), 100, "clamp_value(200) clamps to REP_MAX")
	_assert_equal(model.clamp_value(-200), -100, "clamp_value(-200) clamps to REP_MIN")
	_assert_equal(model.clamp_value(50), 50, "clamp_value(50) passes through")

	# --- apply_delta clamps at the high end ---
	var start := {"republic": 90, "cis": 0, "hutt": 0, "independent": 0, "bounty_hunters_guild": 0}
	var bumped: Dictionary = model.apply_delta(start, "republic", 50)
	_assert_equal(int(bumped["republic"]), 100, "apply_delta clamps 90 + 50 -> 100")

	# --- apply_delta is NON-mutating (original dict unchanged) ---
	_assert_equal(int(start["republic"]), 90, "apply_delta does not mutate the original dict")

	# apply_delta also clamps at the low end and handles negative deltas.
	var low: Dictionary = model.apply_delta({"hutt": -90}, "hutt", -50)
	_assert_equal(int(low["hutt"]), -100, "apply_delta clamps -90 + -50 -> -100")

	# apply_delta on a missing-but-known axis treats current as 0.
	var fresh: Dictionary = model.apply_delta(model.initial_reputation(), "bounty_hunters_guild", 30)
	_assert_equal(int(fresh["bounty_hunters_guild"]), 30, "apply_delta on known axis from 0")

	# --- unknown axis -> no new key, rep returned unchanged ---
	var before_unknown: Dictionary = model.initial_reputation()
	var after_unknown: Dictionary = model.apply_delta(before_unknown, "jedi", 40)
	_assert_equal(after_unknown.has("jedi"), false, "unknown axis 'jedi' adds no stray key")
	_assert_equal(after_unknown.size(), 5, "unknown axis leaves dict size unchanged")
	_assert_equal(after_unknown, before_unknown, "unknown axis returns rep unchanged")

	# --- standing_tier boundaries ---
	_assert_equal(model.standing_tier(-26), "hostile", "standing_tier(-26) is hostile")
	_assert_equal(model.standing_tier(-25), "neutral", "standing_tier(-25) is neutral")
	_assert_equal(model.standing_tier(24), "neutral", "standing_tier(24) is neutral")
	_assert_equal(model.standing_tier(25), "friendly", "standing_tier(25) is friendly")
	_assert_equal(model.standing_tier(74), "friendly", "standing_tier(74) is friendly")
	_assert_equal(model.standing_tier(75), "allied", "standing_tier(75) is allied")
	# Extra spot checks at the extremes.
	_assert_equal(model.standing_tier(-100), "hostile", "standing_tier(-100) is hostile")
	_assert_equal(model.standing_tier(0), "neutral", "standing_tier(0) is neutral")
	_assert_equal(model.standing_tier(100), "allied", "standing_tier(100) is allied")

	# --- serialize drops a stray key and includes all five axes ---
	var messy := {"republic": 12, "hutt": -40, "jedi": 99}
	var serialized: Dictionary = model.serialize(messy)
	_assert_equal(serialized.has("jedi"), false, "serialize drops stray 'jedi' key")
	_assert_equal(serialized.size(), 5, "serialize includes exactly the five axes")
	_assert_equal(int(serialized["republic"]), 12, "serialize keeps present axis value")
	_assert_equal(int(serialized["hutt"]), -40, "serialize keeps negative axis value")
	_assert_equal(int(serialized["cis"]), 0, "serialize fills missing 'cis' with 0")
	_assert_equal(int(serialized["independent"]), 0, "serialize fills missing 'independent' with 0")
	_assert_equal(int(serialized["bounty_hunters_guild"]), 0, "serialize fills missing guild axis with 0")

	if _failures.is_empty():
		print("reputation_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
