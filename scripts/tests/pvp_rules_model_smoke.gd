extends SceneTree
## Smoke for the pure zone-based PvP model (Wave F / DIV-0019): the consent/lethality predicate
## (lawless-only, same-zone; contested is PROTECTED for PvP — distinct from creature lethality), the
## defender pool/state remap into the target_* shape ground_combat_model consumes, the kill threshold,
## and the full-loot tier. All-static + deterministic.

const Pvp = preload("res://scripts/rules/pvp_rules_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- can_fire: lawless-only, same-zone ---
	var ok := Pvp.can_fire("z", "z", "lawless", "lawless")
	_assert_equal(bool(ok["allowed"]), true, "same-zone lawless PvP is allowed")
	_assert_equal(String(ok["reason"]), "", "allowed fire has no reason")
	_assert_equal(String(Pvp.can_fire("z", "z", "secured", "secured")["reason"]), "protected_zone", "secured zone is PROTECTED")
	_assert_equal(String(Pvp.can_fire("z", "z", "contested", "contested")["reason"]), "protected_zone", "contested is PROTECTED for PvP (distinct from creature lethality)")
	_assert_equal(String(Pvp.can_fire("a", "b", "lawless", "lawless")["reason"]), "different_zone", "cross-zone fire rejected")
	_assert_equal(String(Pvp.can_fire("z", "z", "lawless", "secured")["reason"]), "protected_target", "a target in a protected tier is safe (defensive)")
	_assert_equal(String(Pvp.can_fire("", "z", "lawless", "lawless")["reason"]), "no_zone", "an empty zone is rejected")
	_assert_equal(bool(Pvp.can_fire("z", "z", "contested", "contested", ["lawless", "contested"])["allowed"]), true, "open_tiers override widens PvP if ever configured")

	# --- defender pool remap ---
	var dpools := Pvp.defender_target_pools({
		"attacker_pool": {"dice": 5, "pips": 0}, "damage_pool": {"dice": 4, "pips": 0},
		"player_soak_pool": {"dice": 3, "pips": 0}, "player_dodge_pool": {"dice": 6, "pips": 1},
		"player_armor": {}, "attacker_scale": "character"})
	_assert_equal(int((dpools["target_attack_pool"] as Dictionary)["dice"]), 5, "defender attack pool -> target_attack_pool")
	_assert_equal(int((dpools["target_damage_pool"] as Dictionary)["dice"]), 4, "defender damage pool -> target_damage_pool")
	_assert_equal(int((dpools["target_soak_pool"] as Dictionary)["dice"]), 3, "defender soak pool -> target_soak_pool")
	# G3 (DIV-0019): the defender's DODGE pool is carried so resolve_exchange can build the reaction dodge.
	_assert_equal(int((dpools["target_dodge_pool"] as Dictionary)["dice"]), 6, "defender dodge pool -> target_dodge_pool (dice)")
	_assert_equal(int((dpools["target_dodge_pool"] as Dictionary)["pips"]), 1, "defender dodge pool -> target_dodge_pool (pips)")
	# A defender with NO dodge pool remaps to a safe empty 0D pool (no crash in resolve_exchange).
	_assert_equal(int((Pvp.defender_target_pools({})["target_dodge_pool"] as Dictionary)["dice"]), 0, "absent dodge pool -> 0D")
	_assert_equal(String(dpools["target_scale"]), "character", "scale carried")
	_assert_equal(bool(dpools["target_stun_mode"]), false, "PvP deals REAL damage (stun_mode false)")

	# --- defender state projection ---
	_assert_equal(Pvp.defender_target_state({"player_wound_severity": 4, "player_armor_quality_pips": 1}, "B"),
		{"wound_severity": 4, "armor_quality_pips": 1, "name": "B"}, "defender live state -> target_state shape")

	# --- kill threshold + full-loot tier (DIV-0027: is_kill is THE routing predicate) ---
	# sev 5 -> _handle_player_death (full DIV-0006 penalty + respawn); sev 3-4 -> _handle_player_downed
	# (downed-in-field: NOT respawned, no penalty, escape hatches). is_kill(3/4)==false now means DOWNED.
	_assert_equal(Pvp.is_kill(5), true, "sev 5 routes to death (respawn)")
	_assert_equal(Pvp.is_kill(4), false, "sev 4 (mortally) is DOWNED, not dead (bleeds out via death_roll)")
	_assert_equal(Pvp.is_kill(3), false, "sev 3 (incapacitated) is DOWNED, not dead (yield / deteriorate)")
	_assert_equal(Pvp.is_full_loot("lawless"), true, "lawless corpse is full-loot")
	_assert_equal(Pvp.is_full_loot("contested"), false, "contested corpse is not full-loot")
	_assert_equal(Pvp.is_full_loot("secured"), false, "secured corpse is not full-loot")

	if _failures.is_empty():
		print("pvp_rules_model_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
