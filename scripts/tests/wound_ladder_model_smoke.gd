extends SceneTree
# Headless smoke for scripts/rules/wound_ladder_model.gd (DIV-0008).
# Asserts the canonical WEG R&E cumulative wound ladder: per-level penalties,
# single-hit severity mapping (including the sev3 -> -2D FIX), and every required
# cumulative escalation transition. Stateless model -> call statics off the script.

const WoundLadderModel = preload("res://scripts/rules/wound_ladder_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- LEVELS array shape ---
	_assert_equal(
		WoundLadderModel.LEVELS,
		["healthy", "stunned", "wounded", "wounded_twice", "incapacitated", "mortally_wounded", "dead"],
		"LEVELS is the worst-increasing WEG ladder"
	)

	# --- penalty_dice_for_level for EVERY level ---
	_assert_equal(WoundLadderModel.penalty_dice_for_level("healthy"), 0, "healthy penalty 0D")
	_assert_equal(WoundLadderModel.penalty_dice_for_level("stunned"), 1, "stunned penalty -1D")
	_assert_equal(WoundLadderModel.penalty_dice_for_level("wounded"), 1, "wounded penalty -1D")
	_assert_equal(WoundLadderModel.penalty_dice_for_level("wounded_twice"), 2, "wounded_twice penalty -2D")
	_assert_equal(WoundLadderModel.penalty_dice_for_level("incapacitated"), 2, "incapacitated penalty -2D")
	_assert_equal(WoundLadderModel.penalty_dice_for_level("mortally_wounded"), 2, "mortally_wounded penalty -2D")
	_assert_equal(WoundLadderModel.penalty_dice_for_level("dead"), 0, "dead penalty 0D (moot)")
	_assert_equal(WoundLadderModel.penalty_dice_for_level("bogus"), 0, "unknown level penalty 0D")

	# --- penalty_dice_for_severity: the FIX. ---
	_assert_equal(WoundLadderModel.penalty_dice_for_severity(0), 0, "severity 0 -> 0D")
	_assert_equal(WoundLadderModel.penalty_dice_for_severity(1), 1, "severity 1 -> 1D")
	_assert_equal(WoundLadderModel.penalty_dice_for_severity(2), 1, "severity 2 -> 1D")
	# THE FIX: old ground_combat _wound_penalty_dice silently returned 0D here.
	_assert_equal(WoundLadderModel.penalty_dice_for_severity(3), 2, "FIX: severity 3 -> 2D (was 0D)")
	_assert_equal(WoundLadderModel.penalty_dice_for_severity(4), 2, "severity 4 -> 2D (was 0D)")
	_assert_equal(WoundLadderModel.penalty_dice_for_severity(5), 0, "severity 5 -> 0D (dead, moot)")

	# --- level_for_severity for 0..5 ---
	_assert_equal(WoundLadderModel.level_for_severity(0), "healthy", "severity 0 -> healthy")
	_assert_equal(WoundLadderModel.level_for_severity(1), "stunned", "severity 1 -> stunned")
	_assert_equal(WoundLadderModel.level_for_severity(2), "wounded", "severity 2 -> wounded")
	_assert_equal(WoundLadderModel.level_for_severity(3), "incapacitated", "severity 3 -> incapacitated (single-hit chart skips wounded_twice)")
	_assert_equal(WoundLadderModel.level_for_severity(4), "mortally_wounded", "severity 4 -> mortally_wounded")
	_assert_equal(WoundLadderModel.level_for_severity(5), "dead", "severity 5 -> dead")

	# --- cumulative escalation transitions ---
	# Wounded + Wounded -> Incapacitated (WEG R&E cumulative, Guide_01 line 410).
	_assert_equal(WoundLadderModel.escalate("wounded", 2), "incapacitated", "wounded + wounded -> incapacitated")
	# Stun on an already-wounded character -> Wounded Twice (Guide_01 line 413).
	_assert_equal(WoundLadderModel.escalate("wounded", 1), "wounded_twice", "stun on wounded -> wounded_twice")
	# Stun on healthy -> stunned.
	_assert_equal(WoundLadderModel.escalate("healthy", 1), "stunned", "stun on healthy -> stunned")
	# Wounded Twice + Wounded -> Incapacitated.
	_assert_equal(WoundLadderModel.escalate("wounded_twice", 2), "incapacitated", "wounded_twice + wounded -> incapacitated")
	# Stun on wounded_twice stays wounded_twice (deepening cap before incapacitation).
	_assert_equal(WoundLadderModel.escalate("wounded_twice", 1), "wounded_twice", "stun on wounded_twice -> wounded_twice")
	# Incapacitated + ANY further damage -> Mortally Wounded (Guide_01 line 411).
	_assert_equal(WoundLadderModel.escalate("incapacitated", 1), "mortally_wounded", "incapacitated + stun -> mortally_wounded")
	_assert_equal(WoundLadderModel.escalate("incapacitated", 2), "mortally_wounded", "incapacitated + wound -> mortally_wounded")
	# Mortally Wounded + ANY further damage -> Dead (Guide_01 line 412).
	_assert_equal(WoundLadderModel.escalate("mortally_wounded", 1), "dead", "mortally_wounded + stun -> dead")
	_assert_equal(WoundLadderModel.escalate("mortally_wounded", 2), "dead", "mortally_wounded + wound -> dead")
	# Direct incoming level worse than the transition wins.
	_assert_equal(WoundLadderModel.escalate("healthy", 3), "incapacitated", "healthy + sev3 -> incapacitated (direct wins)")
	_assert_equal(WoundLadderModel.escalate("healthy", 5), "dead", "healthy + sev5 -> dead")
	_assert_equal(WoundLadderModel.escalate("wounded", 5), "dead", "wounded + sev5 -> dead")
	_assert_equal(WoundLadderModel.escalate("stunned", 5), "dead", "any + sev5 -> dead")
	_assert_equal(WoundLadderModel.escalate("dead", 2), "dead", "dead is absorbing")

	# severity 0 leaves the level unchanged (every rung).
	for level in WoundLadderModel.LEVELS:
		_assert_equal(WoundLadderModel.escalate(level, 0), level, "sev0 leaves %s unchanged" % level)

	# Monotonic: a milder incoming hit never downgrades the current level.
	_assert_equal(WoundLadderModel.escalate("incapacitated", 0), "incapacitated", "monotonic: sev0 cannot downgrade incapacitated")
	_assert_equal(WoundLadderModel.escalate("wounded_twice", 1), "wounded_twice", "monotonic: stun cannot downgrade wounded_twice")
	# A direct sev that maps below current must not reduce current (worse-of merge).
	_assert_equal(WoundLadderModel.escalate("mortally_wounded", 0), "mortally_wounded", "monotonic: sev0 cannot downgrade mortally_wounded")
	_assert_equal(WoundLadderModel.escalate("incapacitated", 2), "mortally_wounded", "incapacitated never drops to wounded on a wound hit")

	# level_index sanity.
	_assert_equal(WoundLadderModel.level_index("dead"), 6, "dead index is 6")
	_assert_equal(WoundLadderModel.level_index("healthy"), 0, "healthy index is 0")
	_assert_equal(WoundLadderModel.level_index("bogus"), 0, "unknown level index is 0")

	if _failures.is_empty():
		print("wound_ladder_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
