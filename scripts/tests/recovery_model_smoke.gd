extends SceneTree
# recovery_model_smoke.gd — headless SceneTree smoke test for recovery_model.gd (E3).
# All RNG is explicitly seeded; never randomize().

const RecoveryModel = preload("res://scripts/rules/recovery_model.gd")
const WoundLadderModel = preload("res://scripts/rules/wound_ladder_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- Stun recovery (Guide_19 §1: stun lifts after STUN_RECOVERY_ROUNDS=2) ---
	_assert_equal(RecoveryModel.STUN_RECOVERY_ROUNDS, 2, "stun recovery constant is 2 rounds")
	_assert_equal(RecoveryModel.stun_recovered(2), true, "stun recovered at 2 rounds")
	_assert_equal(RecoveryModel.stun_recovered(3), true, "stun recovered past window")
	_assert_equal(RecoveryModel.stun_recovered(1), false, "stun not recovered at 1 round")
	_assert_equal(RecoveryModel.stun_recovered(0), false, "stun not recovered at 0 rounds")

	# tick_stun is non-mutating and reaches healthy at <= 0.
	var stun_state := {"level": "stunned", "rounds_remaining": 2}
	var after_one: Dictionary = RecoveryModel.tick_stun(stun_state)
	_assert_equal(stun_state["rounds_remaining"], 2, "tick_stun does not mutate input")
	_assert_equal(after_one["rounds_remaining"], 1, "tick_stun decrements to 1")
	_assert_equal(after_one["level"], "stunned", "still stunned with rounds remaining")
	var after_two: Dictionary = RecoveryModel.tick_stun(after_one)
	_assert_equal(after_two["rounds_remaining"], 0, "tick_stun decrements to 0")
	_assert_equal(after_two["level"], "healthy", "stun clears to healthy at 0")
	# Ticking again from healthy/0 stays clamped at 0 + healthy.
	var after_three: Dictionary = RecoveryModel.tick_stun(after_two)
	_assert_equal(after_three["rounds_remaining"], 0, "tick_stun clamps at 0")
	_assert_equal(after_three["level"], "healthy", "tick_stun stays healthy")

	# --- Heal difficulty table (Guide_19 §3) ---
	_assert_equal(RecoveryModel.heal_difficulty_for_level("stunned"), 8, "stunned difficulty Easy(8)")
	_assert_equal(RecoveryModel.heal_difficulty_for_level("wounded"), 11, "wounded difficulty Moderate(11)")
	_assert_equal(RecoveryModel.heal_difficulty_for_level("wounded_twice"), 14, "wounded_twice difficulty 14")
	_assert_equal(RecoveryModel.heal_difficulty_for_level("incapacitated"), 16, "incapacitated difficulty Difficult(16)")
	_assert_equal(RecoveryModel.heal_difficulty_for_level("mortally_wounded"), 21, "mortally difficulty Very Difficult(21)")

	# --- Heal check: clearly-passing roll drops EXACTLY one level toward healthy ---
	# wounded(11): pool {10D,+11} -> min total 21 >= 11, always succeeds regardless of dice.
	var pass_rng := RandomNumberGenerator.new()
	pass_rng.seed = 424242
	var pass_pool := {"dice": 10, "pips": 11}
	var heal_pass: Dictionary = RecoveryModel.heal_check(pass_rng, pass_pool, "wounded")
	_assert_equal(heal_pass["success"], true, "clearly-passing heal succeeds")
	_assert_equal(heal_pass["healed"], true, "clearly-passing heal sets healed flag")
	_assert_equal(heal_pass["difficulty"], 11, "heal check uses wounded difficulty")
	# wounded -> index 2; one step toward healthy = index 1 = "stunned".
	_assert_equal(heal_pass["new_level"], "stunned", "wounded heals exactly one level to stunned")
	_assert_equal(
		WoundLadderModel.LEVELS.find(heal_pass["new_level"]),
		WoundLadderModel.LEVELS.find("wounded") - 1,
		"heal drops exactly one ladder index",
	)
	_assert_equal(bool(heal_pass["roll_total"] >= heal_pass["difficulty"]), true, "pass roll_total clears difficulty")

	# Same passing pool on wounded_twice -> drops exactly one to wounded.
	var pass_rng2 := RandomNumberGenerator.new()
	pass_rng2.seed = 99
	var heal_pass2: Dictionary = RecoveryModel.heal_check(pass_rng2, pass_pool, "wounded_twice")
	_assert_equal(heal_pass2["success"], true, "clearly-passing heal succeeds on wounded_twice")
	_assert_equal(heal_pass2["new_level"], "wounded", "wounded_twice heals exactly one level to wounded")
	_assert_equal(heal_pass2["healed"], true, "wounded_twice heal sets healed flag")

	# --- Heal check: clearly-failing roll leaves the level unchanged ---
	# wounded(11): pool {1D,+0} -> max total 6 < 11, always fails regardless of dice.
	var fail_rng := RandomNumberGenerator.new()
	fail_rng.seed = 7
	var fail_pool := {"dice": 1, "pips": 0}
	var heal_fail: Dictionary = RecoveryModel.heal_check(fail_rng, fail_pool, "wounded")
	_assert_equal(heal_fail["success"], false, "clearly-failing heal fails")
	_assert_equal(heal_fail["healed"], false, "clearly-failing heal does not set healed")
	_assert_equal(heal_fail["new_level"], "wounded", "failed heal leaves level unchanged")
	_assert_equal(bool(heal_fail["roll_total"] < heal_fail["difficulty"]), true, "fail roll_total under difficulty")

	# healthy/dead are never healed (no wound / beyond help).
	var edge_rng := RandomNumberGenerator.new()
	edge_rng.seed = 11
	var heal_healthy: Dictionary = RecoveryModel.heal_check(edge_rng, pass_pool, "healthy")
	_assert_equal(heal_healthy["healed"], false, "healthy cannot be healed further")
	_assert_equal(heal_healthy["new_level"], "healthy", "healthy stays healthy")
	var heal_dead: Dictionary = RecoveryModel.heal_check(edge_rng, pass_pool, "dead")
	_assert_equal(heal_dead["healed"], false, "dead is beyond medical help")
	_assert_equal(heal_dead["new_level"], "dead", "dead stays dead")

	# --- Death roll: deterministic FIXED outcomes (seed-independent by design) ---
	# 2D total is always in [2,12]. rounds=2 -> total < 2 impossible -> survives.
	# rounds=13 -> total < 13 always -> dies. Both are fixed regardless of the seed.
	var death_rng := RandomNumberGenerator.new()
	death_rng.seed = 1337
	var survive: Dictionary = RecoveryModel.death_roll(death_rng, 2)
	_assert_equal(survive["died"], false, "2D death roll at rounds=2 always survives")
	_assert_equal(survive["rounds"], 2, "death roll echoes rounds")
	_assert_equal(bool(survive["roll_total"] >= 2 and survive["roll_total"] <= 12), true, "2D total in range")

	var death_rng2 := RandomNumberGenerator.new()
	death_rng2.seed = 1337
	var perish: Dictionary = RecoveryModel.death_roll(death_rng2, 13)
	_assert_equal(perish["died"], true, "2D death roll at rounds=13 always dies")
	_assert_equal(perish["rounds"], 13, "death roll echoes rounds for fatal case")

	# Determinism: same seed + same rounds reproduces the identical roll total.
	var repeat_rng := RandomNumberGenerator.new()
	repeat_rng.seed = 1337
	var perish_replay: Dictionary = RecoveryModel.death_roll(repeat_rng, 13)
	_assert_equal(perish_replay["roll_total"], perish["roll_total"], "same seed reproduces death roll total")

	# --- Post-death debuff window (Guide_19 §5) ---
	_assert_equal(RecoveryModel.death_debuff_dice(0), 1, "debuff active at revive")
	_assert_equal(RecoveryModel.death_debuff_dice(RecoveryModel.DEATH_DEBUFF_ROUNDS - 1), 1, "debuff active inside window")
	_assert_equal(RecoveryModel.death_debuff_dice(RecoveryModel.DEATH_DEBUFF_ROUNDS), 0, "debuff clears at window end")
	_assert_equal(RecoveryModel.death_debuff_dice(RecoveryModel.DEATH_DEBUFF_ROUNDS + 5), 0, "debuff clears past window")

	if _failures.is_empty():
		print("recovery_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
