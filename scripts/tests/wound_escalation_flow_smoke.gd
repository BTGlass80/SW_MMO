extends SceneTree
## G2 seam smoke (DIV-0006/0019): the live PvP-defender wound accumulation now escalates up the WEG
## wound ladder instead of highest-hit-wins. Mirrors the combat_arena.gd PvP-defender composition
## purely (WoundLadder over a level string + the RAW single-hit severity the ground model exposes as
## `this_hit_severity`), so the seam is locked without standing up the ENet arena. Three jobs:
##   (1) headline — two sub-lethal hits (wounded + wounded) escalate to incapacitated (a casualty),
##       where the old max-wins code left the target "wounded" forever.
##   (2) NO over-escalation — a SMALL hit on an existing wound deepens by exactly one rung
##       (stun-on-wounded -> wounded_twice, NOT incapacitated). This is the case the naive
##       "feed escalate the max-folded severity" approach gets WRONG; keying on the raw single-hit
##       severity gets it right. This assertion is the whole reason the ground model exposes this_hit.
##   (3) drift guard — WoundLadder.severity_for_level agrees with PersistenceStore.severity_for_wound_state
##       for every level (the arena derives its int from the level via the former; persistence via the
##       latter — they must never diverge).
## Deterministic; no RNG.

const WoundLadder = preload("res://scripts/rules/wound_ladder_model.gd")
const PersistenceStore = preload("res://scripts/net/persistence_store.gd")

const DISABLED_SEVERITY := 3  # mirrors CombatArena.DISABLED_SEVERITY

var _failures: Array[String] = []

# Mirror of the combat_arena.gd PvP-defender accumulation seam: escalate the defender's level string
# by the raw single-hit severity, then derive the int the casualty/disabled checks read.
func _apply_pvp_hit(level: String, this_hit_severity: int) -> Dictionary:
	var new_level := WoundLadder.escalate(level, this_hit_severity)
	return {"level": new_level, "severity": WoundLadder.severity_for_level(new_level)}

func _init() -> void:
	# --- (1) headline: two sub-lethal wounded hits stack into a disabling incapacitation ---
	var d := {"level": "healthy", "severity": 0}
	d = _apply_pvp_hit(d["level"], 2)  # wounded
	_assert_equal(d["level"], "wounded", "first wounded hit -> wounded")
	_assert_equal(int(d["severity"]) >= DISABLED_SEVERITY, false, "one wounded hit does NOT disable")
	d = _apply_pvp_hit(d["level"], 2)  # wounded again
	_assert_equal(d["level"], "incapacitated", "wounded + wounded ESCALATES to incapacitated (not max-wins 'wounded')")
	_assert_equal(int(d["severity"]) >= DISABLED_SEVERITY, true, "two sub-lethal hits disable the target (a casualty)")

	# --- (2) NO over-escalation: a small hit on an existing wound deepens by exactly one rung ---
	# stun(1) on wounded -> wounded_twice (-2D), NOT incapacitated. The naive approach would feed
	# escalate the max-folded severity maxi(2,1)=2 -> escalate(wounded,2)=incapacitated (WRONG/too harsh).
	var w := _apply_pvp_hit("wounded", 1)  # stun on top of a wound
	_assert_equal(w["level"], "wounded_twice", "stun-on-wounded deepens to wounded_twice, not incapacitated")
	_assert_equal(int(w["severity"]), 2, "wounded_twice still reads as severity 2 (not yet disabled)")
	_assert_equal(int(w["severity"]) >= DISABLED_SEVERITY, false, "wounded_twice is NOT disabled")
	# and a further wounded hit on wounded_twice finishes the escalation to incapacitated
	var w2 := _apply_pvp_hit(w["level"], 2)
	_assert_equal(w2["level"], "incapacitated", "wounded_twice + wounded -> incapacitated")

	# --- miss / zero hit never escalates ---
	var m := _apply_pvp_hit("wounded", 0)
	_assert_equal(m["level"], "wounded", "a miss (this_hit 0) leaves the level unchanged")

	# --- (3) drift guard: the two int<->level mappings must agree for every level ---
	for level in ["healthy", "stunned", "wounded", "wounded_twice", "incapacitated", "mortally_wounded", "dead"]:
		_assert_equal(WoundLadder.severity_for_level(level), PersistenceStore.severity_for_wound_state(level),
			"severity_for_level agrees with persistence for '%s'" % level)
	# and the round-trip the arena seed relies on: a severity -> level -> severity is stable
	for sev in [0, 1, 2, 3, 4, 5]:
		var lvl := WoundLadder.level_for_severity(sev)
		_assert_equal(WoundLadder.severity_for_level(lvl), sev, "severity %d round-trips through its level" % sev)

	if _failures.is_empty():
		print("wound_escalation_flow_smoke: OK")
		quit(0)
	else:
		for fail in _failures:
			printerr(fail)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
