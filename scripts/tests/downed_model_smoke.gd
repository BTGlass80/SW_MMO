extends SceneTree
## Logic smoke for the pure death-tiering + downed decision core (DIV-0027). Drives the REAL
## scripts/rules/downed_model.gd + recovery_model.gd (network_manager is not headlessly instantiable, so
## the classification/bleed-out/deteriorate decisions live in the pure model). Confirms: the tier bands
## (none/downed/kill), the is_kill routing predicate, the PersistenceStore severity round-trip at the
## 3/4/5 tiers (so the int the classifier keys on is unambiguous), and the seeded downed_tick transitions.
## All RNG is seeded; no randomize().

const Downed = preload("res://scripts/rules/downed_model.gd")
const Pvp = preload("res://scripts/rules/pvp_rules_model.gd")
const PersistenceStore = preload("res://scripts/net/persistence_store.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- classify: the tier bands ---
	_assert_equal(Downed.classify(2), "none", "sev 2 (wounded) is not a takeout")
	_assert_equal(Downed.classify(3), "downed", "sev 3 (incapacitated) is DOWNED")
	_assert_equal(Downed.classify(4), "downed", "sev 4 (mortally_wounded) is DOWNED")
	_assert_equal(Downed.classify(5), "kill", "sev 5 (dead) is a KILL")

	# --- is_downed_severity: the downed band only (3-4) ---
	_assert_equal(Downed.is_downed_severity(2), false, "sev 2 is below the downed floor")
	_assert_equal(Downed.is_downed_severity(3), true, "sev 3 is downed")
	_assert_equal(Downed.is_downed_severity(4), true, "sev 4 is downed")
	_assert_equal(Downed.is_downed_severity(5), false, "sev 5 is dead, not downed")

	# --- the routing predicate agrees with the pure model + the shipped arena floor ---
	_assert_equal(Pvp.is_kill(3), false, "is_kill(3)==false -> _handle_player_downed")
	_assert_equal(Pvp.is_kill(4), false, "is_kill(4)==false -> _handle_player_downed")
	_assert_equal(Pvp.is_kill(5), true, "is_kill(5)==true -> _handle_player_death")
	_assert_equal(Downed.KILL_SEVERITY, Pvp.PVP_DEATH_SEVERITY, "KILL_SEVERITY mirrors PvpRules.PVP_DEATH_SEVERITY")
	_assert_equal(Downed.DISABLED_SEVERITY, 3, "DISABLED_SEVERITY mirrors CombatArena.DISABLED_SEVERITY")

	# --- PersistenceStore severity round-trip at the 3/4/5 tiers (unambiguous classification int) ---
	_assert_equal(PersistenceStore.severity_for_wound_state("incapacitated"), 3, "incapacitated -> 3")
	_assert_equal(PersistenceStore.severity_for_wound_state("mortally_wounded"), 4, "mortally_wounded -> 4")
	_assert_equal(PersistenceStore.severity_for_wound_state("dead"), 5, "dead -> 5")
	_assert_equal(PersistenceStore.wound_state_for_severity(3), "incapacitated", "3 -> incapacitated")
	_assert_equal(PersistenceStore.wound_state_for_severity(4), "mortally_wounded", "4 -> mortally_wounded")
	_assert_equal(PersistenceStore.wound_state_for_severity(5), "dead", "5 -> dead")

	# --- downed_tick: sev-4 bleed-out is DETERMINISTIC for a fixed seed + carries rounds ---
	var r1 := _seeded(4242)
	var t1 := Downed.downed_tick({"severity": 4, "rounds": 0}, r1)
	var r2 := _seeded(4242)
	var t2 := Downed.downed_tick({"severity": 4, "rounds": 0}, r2)
	_assert_equal(String(t1.get("action", "")), String(t2.get("action", "")), "sev-4 downed_tick is deterministic for a fixed seed")
	_assert_equal(int(t1.get("rounds", -1)), 1, "sev-4 downed_tick carries rounds -> 1")
	_assert_equal(int(t1.get("next_severity", 0)), 4, "sev-4 downed_tick keeps severity 4 on a hold/die")

	# --- downed_tick: sev-3 (incapacitated) is STABLE. The AFK safety net is DISABLED by default
	#     (INCAP_DETERIORATE_WINDOWS <= 0, owner ruling 2026-07-03 = WEG faithfulness: incapacitated is
	#     stable/unconscious), so sev-3 HOLDS at any round count and never auto-deteriorates or auto-dies;
	#     the exit is yield (net layer) or a medic's First Aid. (If re-enabled (>0), downed_softlock_smoke
	#     covers the deteriorate-then-bleed-out path.) ---
	var rng := _seeded(7)
	_assert_true(Downed.INCAP_DETERIORATE_WINDOWS <= 0, "AFK safety net is DISABLED by default (WEG-faithful stable sev-3)")
	var s3a := Downed.downed_tick({"severity": 3, "rounds": 0}, rng)
	_assert_equal(String(s3a.get("action", "")), "hold", "sev-3 holds at round 0 (stable, no auto-death)")
	var s3b := Downed.downed_tick({"severity": 3, "rounds": 999}, rng)
	_assert_equal(String(s3b.get("action", "")), "hold", "sev-3 holds even at a huge round count (never auto-deteriorates when disabled)")
	_assert_equal(int(s3b.get("next_severity", 0)), 3, "sev-3 severity never spontaneously worsens when the safety net is off")
	_assert_true(Downed.MORTAL_CERTAIN_ROUNDS >= 13, "the bleed-out proof bound is >= 13 (2D max 12)")

	# --- a severity below the floor returns 'revived' (a medic dropped them out of the downed band) ---
	_assert_equal(String(Downed.downed_tick({"severity": 2, "rounds": 3}, rng).get("action", "")), "revived", "sub-floor severity resolves as revived")

	if _failures.is_empty():
		print("downed_model_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _seeded(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
