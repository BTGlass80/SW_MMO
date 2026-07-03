extends SceneTree
## Closes the G14 verifier's coverage gap: NO end-to-end First-Aid-at-14 test existed. Drives the REAL
## heal path against a LIVE wounded_twice arena patient and proves the Guide_19 par.3 difficulty 14 is used
## (NOT the collapsed 11) and that the healed level round-trips through the arena WITHOUT collapsing the tier.
##
## network_manager is a Node autoload that is not headlessly instantiable, so — like heal_flow_smoke /
## hostile_aggression_smoke — this drives the directly-instantiable CombatArena + the REAL recovery_model
## and MIRRORS network_manager.submit_heal's seam around them: _live_wound_state reads the arena's
## `player_wound_level` STRING (level-first), Recovery.heal_check rolls the healer's pool vs that level's
## difficulty, and the write-back passes BOTH the new level string and its int to set_player_combat.
##
## The bug this guards: if the seam derived the wound level from the severity INT (2) instead of the live
## LEVEL STRING, a live wounded_twice patient would collapse to 'wounded' -> heal at difficulty 11 and skip
## a ladder rung. The level string (14) must win. Deterministic; server-owned SEEDED rng; no randomize().

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const Recovery := preload("res://scripts/rules/recovery_model.gd")
const WoundLadder := preload("res://scripts/rules/wound_ladder_model.gd")
const PersistenceStore := preload("res://scripts/net/persistence_store.gd")

var _failures: Array[String] = []
var _rules: Object
var _rng := RandomNumberGenerator.new()

# Faithful mirror of network_manager._live_wound_state: the LIVE combat wound is the arena's
# player_wound_level STRING (falling back to the severity-derived level only when no level is present),
# never the autosave-lagged sheet. THIS is the line that must not collapse wounded_twice -> wounded.
func _live_wound_state(arena: Object, peer_id: int, sheet: Dictionary) -> String:
	if arena != null and arena.has_player(peer_id):
		var ps: Dictionary = arena.player_state(peer_id)
		var lvl := String(ps.get("player_wound_level", ""))
		if lvl != "":
			return lvl
		return PersistenceStore.wound_state_for_severity(int(ps.get("player_wound_severity", 0)))
	return String(sheet.get("wound_state", "healthy"))

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	_rng.seed = 141414
	var data := _combat_data()

	# --- ground truth: the Guide_19 par.3 heal difficulties differ by tier — wounded=11, wounded_twice=14 ---
	_assert_equal(Recovery.heal_difficulty_for_level("wounded"), 11, "Guide_19: wounded heals at difficulty 11")
	_assert_equal(Recovery.heal_difficulty_for_level("wounded_twice"), 14, "Guide_19: wounded_twice heals at difficulty 14")
	# The COLLAPSE trap: a severity-int-derived level (2 -> 'wounded') would heal at 11 — the wrong tier.
	_assert_equal(PersistenceStore.wound_state_for_severity(2), "wounded", "the severity int 2 derives 'wounded' (collapses wounded_twice) — the trap the level string avoids")

	# --- a LIVE wounded_twice arena patient ---
	var arena := CombatArena.new(_rules, data)
	arena.register_player(51, "Patient", {"attributes": {"dexterity": "2D", "strength": "2D"}, "skills": {}})
	arena.set_player_combat(51, {"player_wound_severity": 2, "player_wound_level": "wounded_twice"})
	# submit_heal reads the LIVE level via _live_wound_state — it must be the wounded_twice STRING, not 'wounded'.
	var t_sheet := {"wound_state": "wounded"}  # deliberately STALE (autosave lag): the arena must win, not this
	var level := _live_wound_state(arena, 51, t_sheet)
	_assert_equal(level, "wounded_twice", "_live_wound_state reads the LIVE wounded_twice LEVEL STRING (not the stale sheet's 'wounded')")

	# --- the REAL heal check runs at difficulty 14 (the whole point) ---
	# Build the healer's First-Aid pool the way submit_heal does (Technical + first_aid skill). BIG so the
	# SUCCESS is deterministic; the assertion under test is the DIFFICULTY (14), not the roll.
	var heal_pool: Dictionary = _rules.add_pools(_rules.parse_pool("4D"), _rules.parse_pool("16D"))  # a very strong medic
	var result: Dictionary = Recovery.heal_check(_rng, heal_pool, level)
	_assert_equal(int(result.get("difficulty", -1)), 14, "First Aid on a LIVE wounded_twice patient uses Guide_19 difficulty 14 (NOT the collapsed 11)")
	_assert_true(int(result.get("difficulty", -1)) != 11, "the difficulty is NOT the collapsed-wounded 11")
	_assert_true(bool(result.get("healed", false)), "the strong medic pool clears difficulty 14 and heals")
	var new_level := String(result.get("new_level", level))
	_assert_equal(new_level, "wounded", "a successful heal drops wounded_twice by exactly ONE ladder rung -> wounded")

	# --- the healed level round-trips through the arena WITHOUT collapsing (the second half of the G14 fix) ---
	arena.set_player_combat(51, {"player_wound_severity": PersistenceStore.severity_for_wound_state(new_level), "player_wound_level": new_level})
	_assert_equal(String(arena.player_state(51).get("player_wound_level", "")), "wounded", "the healed level persists into the arena as 'wounded' (not lost/collapsed)")
	_assert_equal(int(arena.player_state(51).get("player_wound_severity", -1)), 2, "wounded still reads severity 2 after the write-back")
	# and the NEXT First Aid now correctly reads the shallower tier — difficulty 11, proving the level moved.
	var level2 := _live_wound_state(arena, 51, t_sheet)
	_assert_equal(level2, "wounded", "after the heal the LIVE level is 'wounded'")
	var result2: Dictionary = Recovery.heal_check(_rng, heal_pool, level2)
	_assert_equal(int(result2.get("difficulty", -1)), 11, "the FOLLOW-UP First Aid drops to difficulty 11 (14 -> 11 progression proves the level string is load-bearing)")

	# --- a FAILED heal leaves the LIVE wounded_twice tier intact at difficulty 14 (no silent collapse) ---
	var arena3 := CombatArena.new(_rules, data)
	arena3.register_player(52, "Patient2", {"attributes": {"dexterity": "2D", "strength": "2D"}, "skills": {}})
	arena3.set_player_combat(52, {"player_wound_severity": 2, "player_wound_level": "wounded_twice"})
	var none_pool := {"dice": 0, "pips": 0}  # fails every difficulty
	var fail: Dictionary = Recovery.heal_check(_rng, none_pool, _live_wound_state(arena3, 52, {}))
	_assert_equal(int(fail.get("difficulty", -1)), 14, "a failing heal still evaluated difficulty 14 (the tier is read live, not collapsed)")
	_assert_true(not bool(fail.get("healed", false)), "the empty pool fails the difficulty-14 check")
	_assert_equal(String(fail.get("new_level", "")), "wounded_twice", "a failed First Aid leaves the wounded_twice tier unchanged")

	if _rules.has_method("free"):
		_rules.free()
	_finish()

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {
			"blaster": "4D+1", "dodge": "4D", "soak": "3D",
			"weapon": "training_blaster", "armor": "blast_vest", "scale": "character",
		},
		"weapons": {"training_blaster": {"damage": "4D"}, "remote_stun_blaster": {"damage": "3D+2"}},
		"armors": {"blast_vest": {"protection_energy": "0D+1", "protection_physical": "1D", "dexterity_penalty": "-1D", "coverage": ["torso"]}},
		"targets": {
			"b1_training_silhouette": {
				"blaster": "3D", "weapon": "remote_stun_blaster", "soak": "2D",
				"scale": "character", "distance": 12.0, "cover_level": 0, "name": "B1 Training Remote",
			},
		},
	}

func _finish() -> void:
	if _failures.is_empty():
		print("first_aid_at_fourteen_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
