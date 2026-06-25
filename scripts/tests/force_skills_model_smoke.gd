extends SceneTree
## Headless smoke test for the default-off Force-skill data hook (E6).
## Verifies the three WEG Force skills are declared, that the hook is OFF unless the
## sheet is force-sensitive, that the initial block is all 0D, and that pools are
## empty for non-sensitive sheets / non-Force skills but parse for active ones.

const ForceSkills := preload("res://scripts/rules/force_skills_model.gd")

var _failures: Array[String] = []
var _rules: Object

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()

	# The three WEG R&E Force skills, in canonical order.
	_assert_equal(ForceSkills.FORCE_SKILLS, ["control", "sense", "alter"], "FORCE_SKILLS list")

	# Off by default: only a force-sensitive sheet can use the Force.
	_assert_equal(ForceSkills.can_use_force({"force_sensitive": false}), false, "non-sensitive cannot use Force")
	_assert_equal(ForceSkills.can_use_force({"force_sensitive": true}), true, "sensitive can use Force")
	_assert_equal(ForceSkills.can_use_force({}), false, "missing flag defaults off")

	# Initial Force-skill block is all 0D (inactive).
	var initial: Dictionary = ForceSkills.initial_force_skills()
	for skill in ForceSkills.FORCE_SKILLS:
		_assert_equal(String(initial.get(skill, "")), "0D", "initial %s is 0D" % skill)

	# A non-sensitive sheet yields an empty pool even for a real Force skill.
	var inactive_pool: Dictionary = ForceSkills.force_skill_pool(_rules, {"force_sensitive": false}, "control")
	_assert_equal(_rules.pool_to_string(inactive_pool), "0D", "non-sensitive control pool is 0D")

	# A force-sensitive sheet with a stored code yields that pool.
	var active_sheet := {"force_sensitive": true, "force_skills": {"control": "2D"}}
	var active_pool: Dictionary = ForceSkills.force_skill_pool(_rules, active_sheet, "control")
	_assert_equal(_rules.pool_to_string(active_pool), "2D", "sensitive control pool is 2D")

	# A non-Force skill is never a Force-skill pool, even on a sensitive sheet.
	var sensitive_sheet := {"force_sensitive": true, "force_skills": ForceSkills.initial_force_skills()}
	var non_force_pool: Dictionary = ForceSkills.force_skill_pool(_rules, sensitive_sheet, "blaster")
	_assert_equal(_rules.pool_to_string(non_force_pool), "0D", "blaster is not a Force skill")

	# force_skills() returns {} when absent, the stored dict otherwise.
	_assert_equal(ForceSkills.force_skills({}).size(), 0, "force_skills absent -> empty")
	_assert_equal(int(ForceSkills.force_skills(active_sheet).size()), 1, "force_skills returns stored dict")

	if _rules.has_method("free"):
		_rules.free()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("force_skills_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
