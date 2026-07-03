extends SceneTree
## HARDENING smoke for the pure zone-based PvP model (scripts/rules/pvp_rules_model.gd). Adversarial
## edge-case coverage beyond pvp_rules_model_smoke.gd: reason PRECEDENCE when multiple reject
## conditions apply simultaneously, the is_kill severity boundary on both sides, defender pool/state
## remap defaults on an empty/partial input (no crash), and loot-tier config overrides. All-static,
## deterministic.

const Pvp = preload("res://scripts/rules/pvp_rules_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- reason precedence: no_zone beats every other rejection ---
	_assert_equal(String(Pvp.can_fire("", "", "lawless", "lawless")["reason"]), "no_zone", "both zones empty -> no_zone (not different_zone)")
	_assert_equal(String(Pvp.can_fire("z", "", "lawless", "lawless")["reason"]), "no_zone", "target zone empty -> no_zone")
	_assert_equal(String(Pvp.can_fire("", "z", "lawless", "lawless")["reason"]), "no_zone", "shooter zone empty -> no_zone")

	# --- protected_zone (shooter-side) is reported before protected_target (target-side) ---
	_assert_equal(String(Pvp.can_fire("z", "z", "secured", "lawless")["reason"]), "protected_zone", "when BOTH sides would fail, the shooter-side gate (protected_zone) is reported first")

	# --- is_kill severity boundary, both directions ---
	_assert_equal(Pvp.is_kill(0), false, "severity 0 (no damage) is not a kill")
	_assert_equal(Pvp.is_kill(4), false, "severity 4 (mortally wounded) is not yet a kill")
	_assert_equal(Pvp.is_kill(5), true, "severity 5 (killed) IS a kill")
	_assert_equal(Pvp.is_kill(6), true, "severity above the threshold is still a kill")

	# --- is_full_loot with a config override that adds contested/secured ---
	_assert_equal(Pvp.is_full_loot("secured", ["lawless", "secured"]), true, "a widened loot_tiers config can include secured")
	_assert_equal(Pvp.is_full_loot("nonexistent_tier"), false, "an unrecognized tier is never full-loot")

	# --- can_fire with an EMPTY open_tiers override: PvP is closed everywhere, even lawless ---
	_assert_equal(String(Pvp.can_fire("z", "z", "lawless", "lawless", [])["reason"]), "protected_zone", "an empty open_tiers config closes PvP even in lawless")

	# --- defender_target_pools: fully empty input degrades to zeroed pools, no crash ---
	var empty_pools := Pvp.defender_target_pools({})
	_assert_equal(int((empty_pools["target_attack_pool"] as Dictionary)["dice"]), 0, "an empty defender_pools input defaults attack dice to 0")
	_assert_equal(int((empty_pools["target_damage_pool"] as Dictionary)["dice"]), 0, "an empty defender_pools input defaults damage dice to 0")
	_assert_equal(String(empty_pools["target_scale"]), "character", "an empty defender_pools input defaults scale to character")
	_assert_equal((empty_pools["target_armor"] as Dictionary).is_empty(), true, "an empty defender_pools input defaults armor to an empty dict")
	_assert_equal(bool(empty_pools["target_stun_mode"]), false, "PvP always deals real damage regardless of input completeness")

	# --- defender_target_state: fully empty input degrades to zeroed severity/pips, no crash ---
	var empty_state := Pvp.defender_target_state({}, "Nobody")
	_assert_equal(int(empty_state["wound_severity"]), 0, "an empty defender_state defaults wound_severity to 0")
	_assert_equal(int(empty_state["armor_quality_pips"]), 0, "an empty defender_state defaults armor_quality_pips to 0")
	_assert_equal(String(empty_state["name"]), "Nobody", "display_name passes through untouched")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("pvp_rules_model_edge_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
