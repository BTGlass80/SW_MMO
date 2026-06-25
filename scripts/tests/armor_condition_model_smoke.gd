extends SceneTree

const ArmorConditionModel = preload("res://scripts/rules/armor_condition_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var vest := {
		"protection_energy": "0D+1",
		"protection_physical": "1D",
	}
	var no_armor := {
		"protection_energy": "0D",
		"protection_physical": "0D",
	}
	var torso_vest := {
		"protection_energy": "0D+1",
		"protection_physical": "1D",
		"coverage": ["torso"],
	}
	var stunned_damage := {"margin": 2, "wound": {"severity": 1}}
	var severe_damage := {"margin": 12, "wound": {"severity": 3}}
	var no_damage := {"margin": 0, "wound": {"severity": 0}}

	_assert_equal(ArmorConditionModel.has_soak_protection(vest), true, "vest has soak protection")
	_assert_equal(ArmorConditionModel.has_soak_protection(no_armor), false, "empty armor has no soak protection")
	_assert_equal(ArmorConditionModel.covered_locations(vest), ["full"], "missing coverage means full coverage for existing armor")
	_assert_equal(ArmorConditionModel.covered_locations(torso_vest), ["torso"], "explicit coverage is normalized")
	_assert_equal(ArmorConditionModel.covers_location(torso_vest, "chest"), true, "torso armor covers chest alias")
	_assert_equal(ArmorConditionModel.covers_location(torso_vest, "left_arm"), false, "torso armor does not cover arms")
	_assert_equal(ArmorConditionModel.armor_for_location(torso_vest, "torso").is_empty(), false, "covered location returns armor")
	_assert_equal(ArmorConditionModel.armor_for_location(torso_vest, "left_arm").is_empty(), true, "uncovered location returns empty armor")
	_assert_equal(ArmorConditionModel.hit_location_for_attack({"attack": {"total": 12}}), "torso", "attack total derives deterministic hit location")
	_assert_equal(ArmorConditionModel.hit_location_for_attack({"attack": {"total": 12}}, "left hand"), "left_arm", "hit location override is normalized")
	_assert_equal(ArmorConditionModel.degradation_pips_for_damage(vest, no_damage), 0, "no damage does not degrade armor")
	_assert_equal(ArmorConditionModel.degradation_pips_for_damage(no_armor, stunned_damage), 0, "missing armor does not degrade")
	_assert_equal(ArmorConditionModel.degradation_pips_for_damage(vest, stunned_damage), 1, "light damage degrades armor by one pip")
	_assert_equal(ArmorConditionModel.degradation_pips_for_damage(vest, severe_damage), 2, "incapacitating damage degrades armor by two pips")

	var state := {"armor_quality_pips": 0}
	var next := ArmorConditionModel.apply_degradation(state, "armor_quality_pips", vest, stunned_damage)
	_assert_equal(next["armor_quality_pips"], -1, "armor quality drops after damage")
	_assert_equal(next["armor_degraded_pips"], 1, "degraded pips reported")
	_assert_equal(next["armor_quality_pips_before"], 0, "before quality reported")
	_assert_equal(next["armor_quality_pips_after"], -1, "after quality reported")
	_assert_equal(state["armor_quality_pips"], 0, "input state is not mutated")

	var battered := {"armor_quality_pips": -6}
	var capped := ArmorConditionModel.apply_degradation(battered, "armor_quality_pips", vest, severe_damage)
	_assert_equal(capped["armor_quality_pips"], -6, "armor quality lower bound is capped")
	_assert_equal(capped["armor_degraded_pips"], 0, "capped armor reports no new degradation")
	_assert_equal(ArmorConditionModel.degradation_text("Target", 0, -1, 1), "Target armor +0->-1", "degradation text")
	_assert_equal(ArmorConditionModel.degradation_text("Target", -1, -1, 0), "", "quiet text when unchanged")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("armor_condition_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
