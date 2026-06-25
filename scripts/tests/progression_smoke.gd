extends SceneTree
## Headless smoke test for WEG advancement + the dual-track CP wallet (C3).

const Progression := preload("res://scripts/rules/progression_model.gd")

var _failures: Array[String] = []
var _rules: Object

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()

	# Cost = total-pool dice (attribute + skill bonus). Guide_09 table.
	_assert_equal(Progression.skill_raise_cost(_rules, "3D", "1D+1"), 4, "total 4D+1 costs 4 CP")
	_assert_equal(Progression.skill_raise_cost(_rules, "3D", "2D"), 5, "total 5D costs 5 CP")
	_assert_equal(Progression.skill_raise_cost(_rules, "2D", "0D"), 2, "untrained 2D attribute costs 2 CP")

	# Guild discount: floor(5 * 0.8) = 4.
	_assert_equal(Progression.skill_raise_cost(_rules, "3D", "2D", 0.8), 4, "20% guild discount on a 5 CP cost -> 4")

	# Affordability against the combined wallet.
	_assert_true(not Progression.can_raise(_rules, Progression.new_wallet(3, 0), "3D", "1D+1"), "3 CP cannot afford a 4 CP raise")
	_assert_true(Progression.can_raise(_rules, Progression.new_wallet(5, 0), "3D", "1D+1"), "5 CP can afford a 4 CP raise")

	# Raise adds one pip to the skill BONUS and deducts the cost.
	var r := Progression.raise_skill(_rules, Progression.new_wallet(10, 0), "3D", "1D+1")
	_assert_true(bool(r["ok"]), "raise succeeds with enough CP")
	_assert_equal(int(r["cost"]), 4, "raise cost is 4")
	_assert_equal(String(r["new_skill_bonus"]), "1D+2", "skill bonus 1D+1 -> 1D+2")
	_assert_equal(int((r["wallet"] as Dictionary)["gameplay_cp"]), 6, "10 - 4 = 6 gameplay CP left")

	# Dual track: gameplay spent first, then RP-prestige.
	var split := Progression.raise_skill(_rules, Progression.new_wallet(3, 5), "3D", "1D+1")
	_assert_equal(int((split["wallet"] as Dictionary)["gameplay_cp"]), 0, "gameplay CP drained first")
	_assert_equal(int((split["wallet"] as Dictionary)["rp_cp"]), 4, "RP CP covers the remainder (5 - 1 = 4)")

	# Insufficient CP: rejected, wallet untouched.
	var poor := Progression.raise_skill(_rules, Progression.new_wallet(2, 1), "3D", "1D+1")
	_assert_true(not bool(poor["ok"]), "insufficient CP is rejected")
	_assert_equal(String(poor["reason"]), "insufficient_cp", "rejection reason")
	_assert_equal(Progression.wallet_total(poor["wallet"]), 3, "wallet unchanged on rejection")

	# Cost steps up at a die boundary: 4D+2 raise -> 5D, then the next pip costs 5.
	var at_boundary := Progression.raise_skill(_rules, Progression.new_wallet(20, 0), "3D", "1D+2")
	_assert_equal(String(at_boundary["new_skill_bonus"]), "2D", "1D+2 -> 2D rolls a die")
	_assert_equal(Progression.skill_raise_cost(_rules, "3D", "2D"), 5, "after crossing to 5D total the pip cost rises to 5")

	# Earning on the two tracks.
	var w := Progression.award(Progression.new_wallet(), "gameplay", 5)
	w = Progression.award(w, "rp", 3)
	_assert_equal(int(w["gameplay_cp"]), 5, "gameplay award")
	_assert_equal(int(w["rp_cp"]), 3, "rp award")

	if _rules.has_method("free"):
		_rules.free()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("progression_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
