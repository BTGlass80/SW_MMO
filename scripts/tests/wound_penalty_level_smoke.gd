extends SceneTree
## G14 (DIV-0008): the wounded_twice -2D action penalty is LIVE.
##
## The phantom this kills: a wounded_twice combatant fought at -1D because every live derivation
## computed the penalty from the SEVERITY int, which collapses wounded/wounded_twice to 2
## (severity_for_level) -> penalty_dice_for_severity(2) -> "wounded" -> -1D. The header/comments
## claimed -2D; the wire applied -1D.
##
## This smoke proves the fix end-to-end: with the wound LEVEL STRING threaded through the exchange,
## a wounded_twice combatant whose severity int is STILL 2 fights at -2D, while a wounded combatant
## (same int) fights at -1D. Both a pure resolve_exchange row and a LIVE combat_arena window are
## asserted. All RNG is seeded (server-owned); nothing calls randomize().

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const GroundCombatModel := preload("res://scripts/rules/ground_combat_model.gd")
const Recovery := preload("res://scripts/rules/recovery_model.gd")

var _failures: Array[String] = []
var _rules: Object

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()

	_test_pure_resolve_exchange()
	_test_live_arena_window()
	_test_incoming_fire_window()
	_test_heal_preserves_wounded_twice()

	if _rules.has_method("free"):
		_rules.free()
	_finish()

# --- Pure model: resolve_exchange derives the player penalty from the LEVEL STRING, not the int. ---
func _test_pure_resolve_exchange() -> void:
	var ground := GroundCombatModel.new()
	var pools := {
		"attacker_pool": _rules.parse_pool("5D"),
		"damage_pool": _rules.parse_pool("4D"),
		"damage_pool_fp": _rules.parse_pool("8D"),
		"player_dodge_pool": _rules.parse_pool("3D"),
		"player_soak_pool": _rules.parse_pool("3D"),
		"target_attack_pool": _rules.parse_pool("3D"),
		"target_soak_pool": _rules.parse_pool("2D"),
		"attacker_scale": "character",
		"target_scale": "character",
	}
	var target_state := {"wound_severity": 0, "name": "Dummy"}

	# wounded_twice: severity int is 2 (the collapse), level string is "wounded_twice" -> LIVE -2D.
	var wt_state: Dictionary = ground.initial_state()
	wt_state["player_wound_severity"] = 2
	wt_state["player_wound_level"] = "wounded_twice"
	var wt_result: Dictionary = ground.resolve_exchange(_rules, wt_state, target_state, pools, 10.0, 0, 24601)
	print("  pure resolve_exchange: severity_int=2, level='wounded_twice' -> penalty_dice=%d (expect 2)" % int(wt_result.get("player_wound_penalty_dice", -1)))
	_assert_equal(int(wt_result.get("player_wound_penalty_dice", -1)), 2,
		"resolve_exchange: wounded_twice level (severity int 2) applies -2D")

	# wounded control: same severity int 2, level "wounded" -> -1D.
	var w_state: Dictionary = ground.initial_state()
	w_state["player_wound_severity"] = 2
	w_state["player_wound_level"] = "wounded"
	var w_result: Dictionary = ground.resolve_exchange(_rules, w_state, target_state, pools, 10.0, 0, 24601)
	_assert_equal(int(w_result.get("player_wound_penalty_dice", -1)), 1,
		"resolve_exchange: wounded level applies -1D (control)")

	# Back-compat: a pure caller that passes NO level, only severity 2, still gets -1D via the fallback.
	var s_state: Dictionary = ground.initial_state()
	s_state["player_wound_severity"] = 2  # no player_wound_level key
	var s_result: Dictionary = ground.resolve_exchange(_rules, s_state, target_state, pools, 10.0, 0, 24601)
	_assert_equal(int(s_result.get("player_wound_penalty_dice", -1)), 1,
		"resolve_exchange: severity-only (no level) falls back to -1D")

# --- Live wire: a combat_arena window carries the -2D into the player_attack event. ---
func _test_live_arena_window() -> void:
	var data := _combat_data()

	# A wounded_twice shooter (severity int 2, explicit level string) fights the dummy at -2D.
	var wt := CombatArena.new(_rules, data)
	wt.register_player(2, "Twice", {"attributes": {"dexterity": "3D", "strength": "2D"}, "skills": {"blaster": "1D"}})
	wt.set_player_combat(2, {"player_wound_severity": 2, "player_wound_level": "wounded_twice"})
	wt.submit_fire_intent(2, {"aim": 0})
	var wt_pen := _player_attack_penalty(wt.resolve_window(778899))
	print("  live arena window: wounded_twice shooter -> player_attack wound_penalty_dice=%d (expect 2)" % wt_pen)
	_assert_equal(wt_pen, 2, "live arena: wounded_twice player_attack event carries -2D")

	# Control: a wounded shooter (same severity int) fights at -1D in the same live path.
	var w := CombatArena.new(_rules, data)
	w.register_player(2, "Once", {"attributes": {"dexterity": "3D", "strength": "2D"}, "skills": {"blaster": "1D"}})
	w.set_player_combat(2, {"player_wound_severity": 2, "player_wound_level": "wounded"})
	w.submit_fire_intent(2, {"aim": 0})
	var w_pen := _player_attack_penalty(w.resolve_window(778899))
	print("  live arena window: wounded shooter (same int) -> player_attack wound_penalty_dice=%d (expect 1)" % w_pen)
	_assert_equal(w_pen, 1, "live arena: wounded player_attack event carries -1D (control)")

	# The severity int alone (set_player_combat derives level "wounded" from severity 2) stays -1D,
	# confirming ONLY an explicit wounded_twice level reaches the -2D tier.
	var s := CombatArena.new(_rules, data)
	s.register_player(2, "IntOnly", {"attributes": {"dexterity": "3D", "strength": "2D"}, "skills": {"blaster": "1D"}})
	s.set_player_combat(2, {"player_wound_severity": 2})
	s.submit_fire_intent(2, {"aim": 0})
	var s_pen := _player_attack_penalty(s.resolve_window(778899))
	_assert_equal(s_pen, 1, "live arena: severity-2-only shooter (derived 'wounded') stays -1D")

# --- Issue 1: the INCOMING-fire path (unprovoked hostile aggression -> resolve_incoming_fire_window)
# derives the VICTIM's dodge/soak penalty from the LEVEL STRING, so a wounded_twice victim dodges at -2D. ---
func _test_incoming_fire_window() -> void:
	var ground := GroundCombatModel.new()
	var pools := {
		"player_dodge_pool": _rules.parse_pool("4D"),
		"player_soak_pool": _rules.parse_pool("3D"),
		"player_armor": {},
		"target_attack_pool": _rules.parse_pool("4D"),
		"target_damage_pool": _rules.parse_pool("4D"),
		"damage_pool": _rules.parse_pool("4D"),
		"target_scale": "creature",
	}
	var incoming := [{
		"source_id": "hostile",
		"source_name": "Massiff",
		"attack_pool": _rules.parse_pool("4D"),
		"damage_pool": _rules.parse_pool("4D"),
		"scale": "creature",
		"distance": 6.0,
		"cover_level": 0,
		"wound_severity": 0,
	}]

	# wounded_twice victim: severity int 2 (collapsed), level string 'wounded_twice' -> LIVE -2D on the dodge/soak.
	var wt_state := ground.initial_state()
	wt_state["player_wound_severity"] = 2
	wt_state["player_wound_level"] = "wounded_twice"
	var wt := ground.resolve_incoming_fire_window(_rules, wt_state, pools, incoming, 33445)
	var wt_pen := _incoming_penalty(wt)
	print("  incoming-fire window: wounded_twice victim -> player_wound_penalty_dice=%d (expect 2)" % wt_pen)
	_assert_equal(wt_pen, 2, "incoming-fire: wounded_twice victim dodges at -2D")

	# wounded control: same severity int 2, level 'wounded' -> -1D.
	var w_state := ground.initial_state()
	w_state["player_wound_severity"] = 2
	w_state["player_wound_level"] = "wounded"
	var w := ground.resolve_incoming_fire_window(_rules, w_state, pools, incoming, 33445)
	_assert_equal(_incoming_penalty(w), 1, "incoming-fire: wounded victim dodges at -1D (control)")

	# Back-compat: severity-only (no level) still falls back to -1D for any pure caller.
	var s_state := ground.initial_state()
	s_state["player_wound_severity"] = 2
	var s := ground.resolve_incoming_fire_window(_rules, s_state, pools, incoming, 33445)
	_assert_equal(_incoming_penalty(s), 1, "incoming-fire: severity-only victim falls back to -1D")

# The player_wound_penalty_dice recorded on the first incoming attack result.
func _incoming_penalty(window_result: Dictionary) -> int:
	for inc in window_result.get("incoming", []):
		return int((inc as Dictionary).get("player_wound_penalty_dice", -1))
	return -1

# --- Issue 2: heal/recovery treats a LIVE wounded_twice patient at its OWN difficulty (14) and heals it
# one rung to 'wounded' — and the arena preserves the wounded_twice LEVEL STRING across a heal write-back
# instead of collapsing it to 'wounded' via the severity-2 fallback. ---
func _test_heal_preserves_wounded_twice() -> void:
	# heal_check keys off the level string: wounded_twice -> difficulty 14 (Guide_19 par.3), heals to 'wounded'.
	var pool: Dictionary = _rules.parse_pool("6D")  # high enough to pass 14 with this seed
	var res: Dictionary = Recovery.heal_check(_make_rng(4242), pool, "wounded_twice")
	print("  heal_check('wounded_twice'): difficulty=%d (expect 14)" % int(res.get("difficulty", -1)))
	_assert_equal(int(res.get("difficulty", -1)), 14, "heal_check: wounded_twice difficulty is 14, not the collapsed 11")
	# A wounded_twice patient must never be treated at the 'wounded' difficulty (11) — that is the collapse bug.
	var wounded_diff: int = Recovery.heal_check(_make_rng(4242), pool, "wounded").get("difficulty", -1)
	_assert_equal(wounded_diff, 11, "heal_check: wounded difficulty is 11 (control)")

	# Arena round-trip: set_player_combat with the wounded_twice level string preserves it (does not collapse).
	var data := _combat_data()
	var arena := CombatArena.new(_rules, data)
	arena.register_player(2, "Patient", {"attributes": {"dexterity": "3D", "strength": "2D"}, "skills": {"blaster": "1D"}})
	arena.set_player_combat(2, {"player_wound_severity": 2, "player_wound_level": "wounded_twice"})
	_assert_equal(String(arena.player_state(2).get("player_wound_level", "")), "wounded_twice",
		"arena: set_player_combat preserves the wounded_twice level string")
	# The healed write-back (severity 2 + explicit level 'wounded') writes 'wounded', NOT re-collapsed.
	arena.set_player_combat(2, {"player_wound_severity": 2, "player_wound_level": "wounded"})
	_assert_equal(String(arena.player_state(2).get("player_wound_level", "")), "wounded",
		"arena: heal write-back with explicit level records 'wounded'")

func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

# The wound_penalty_dice recorded on the player_attack event of the first envelope, or -1 if absent.
func _player_attack_penalty(window_result: Dictionary) -> int:
	for env in window_result.get("envelopes", []):
		for ev in (env as Dictionary).get("events", []):
			if String((ev as Dictionary).get("type", "")) == "player_attack":
				return int((ev as Dictionary).get("wound_penalty_dice", -1))
	return -1

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {
			"blaster": "4D+1", "dodge": "4D", "soak": "3D",
			"weapon": "training_blaster", "armor": "blast_vest", "scale": "character",
		},
		"weapons": {
			"training_blaster": {"damage": "4D"},
			"remote_stun_blaster": {"damage": "3D+2"},
		},
		"armors": {
			"blast_vest": {"protection_energy": "0D+1", "protection_physical": "1D", "dexterity_penalty": "-1D", "coverage": ["torso"]},
		},
		"targets": {
			"b1_training_silhouette": {
				"blaster": "3D", "weapon": "remote_stun_blaster", "soak": "2D",
				"scale": "character", "distance": 12.0, "cover_level": 0, "name": "B1 Training Remote",
			},
		},
	}

func _finish() -> void:
	if _failures.is_empty():
		print("wound_penalty_level_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
