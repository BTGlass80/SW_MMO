extends SceneTree
## Dedicated escape-hatch / no-softlock guard (DIV-0027). Ticks the REAL scripts/rules/downed_model.gd
## with a server-owned SEEDED rng (no arena/RPC) to prove a downed player has a bounded, guaranteed exit.
##   (1) sev-4 (mortally_wounded), NO medic, NO yield: the bleed-out reaches 'die' within
##       <= MORTAL_CERTAIN_ROUNDS across a spread of seeds (termination is seed-INDEPENDENT).
##   (2) sev-3 (incapacitated) is STABLE per WEG (Guide_19 §1): with the AFK safety net DISABLED (the
##       shipped default, owner ruling 2026-07-03 = WEG faithfulness) it HOLDS indefinitely with NO
##       auto-death — resolution is yield (net layer) or a medic's First Aid, never spontaneous. (If the
##       optional safety net is re-enabled (>0) it deteriorates to sev-4 then bleeds out — also tested.)
##   (3) revive: a tick whose severity was lowered below the floor (medic) returns 'revived', no death.
##   (4) determinism: same seed + entry -> identical action.
## No sev-4 infinite loop is reachable; sev-3 is intentionally stable (yield/medic is the always-available exit).

const Downed = preload("res://scripts/rules/downed_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- (1) sev-4 bleed-out terminates within <= MORTAL_CERTAIN_ROUNDS, for many seeds ---
	for s in range(20):
		var rng := _seeded(1000 + s)
		var entry := {"severity": 4, "rounds": 0}
		var died := false
		var iterations := 0
		for _i in range(Downed.MORTAL_CERTAIN_ROUNDS + 1):  # a hard cap that MUST be enough
			iterations += 1
			var res := Downed.downed_tick(entry, rng)
			var action := String(res.get("action", ""))
			if action == "die":
				died = true
				break
			# feed a 'hold' back (carry the incremented rounds) — the medic-less passive case
			entry["severity"] = int(res.get("next_severity", 4))
			entry["rounds"] = int(res.get("rounds", 0))
		_assert_true(died, "seed %d: sev-4 bleeds out to death" % (1000 + s))
		_assert_true(iterations <= Downed.MORTAL_CERTAIN_ROUNDS, "seed %d: death within <= MORTAL_CERTAIN_ROUNDS (%d iters)" % [1000 + s, iterations])

	# --- (2) sev-3 (incapacitated): WEG-STABLE when the AFK safety net is DISABLED (shipped default),
	#     or deteriorate-then-bleed-out when it is enabled. Test whichever is configured. ---
	var rng3 := _seeded(55)
	var e3 := {"severity": 3, "rounds": 0}
	if Downed.INCAP_DETERIORATE_WINDOWS <= 0:
		# WEG faithfulness (owner ruling): a stable incapacitated player NEVER auto-deteriorates or
		# auto-dies. It HOLDS indefinitely — the exit is yield (net layer) or a medic. Tick far beyond
		# any plausible window count and require a stable 'hold' every time (no 'deteriorate'/'die').
		for i in range(50):
			var res := Downed.downed_tick(e3, rng3)
			_assert_equal(String(res.get("action", "")), "hold", "disabled safety net: sev-3 HOLDS stable (tick %d) — no auto-death, yield/medic only" % (i + 1))
			_assert_equal(int(res.get("next_severity", 3)), 3, "sev-3 severity never spontaneously worsens (tick %d)" % (i + 1))
			e3["severity"] = int(res.get("next_severity", 3))
			e3["rounds"] = int(res.get("rounds", 0))
	else:
		# Optional safety net enabled: deteriorate at exactly INCAP_DETERIORATE_WINDOWS, then bleed out.
		var deteriorated_at := -1
		for i in range(Downed.INCAP_DETERIORATE_WINDOWS + 2):
			var res := Downed.downed_tick(e3, rng3)
			var action := String(res.get("action", ""))
			if action == "deteriorate":
				deteriorated_at = i + 1
				e3["severity"] = int(res.get("next_severity", 4))
				e3["rounds"] = int(res.get("rounds", 0))
				break
			_assert_equal(action, "hold", "sev-3 holds until deterioration (tick %d)" % (i + 1))
			e3["severity"] = int(res.get("next_severity", 3))
			e3["rounds"] = int(res.get("rounds", 0))
		_assert_equal(deteriorated_at, Downed.INCAP_DETERIORATE_WINDOWS, "sev-3 deteriorates at exactly INCAP_DETERIORATE_WINDOWS")
		_assert_equal(int(e3["severity"]), 4, "post-deterioration severity is 4 (mortally_wounded)")
		var died3 := false
		for _j in range(Downed.MORTAL_CERTAIN_ROUNDS + 1):
			var res := Downed.downed_tick(e3, rng3)
			if String(res.get("action", "")) == "die":
				died3 = true
				break
			e3["severity"] = int(res.get("next_severity", 4))
			e3["rounds"] = int(res.get("rounds", 0))
		_assert_true(died3, "a deteriorated sev-3 then bleeds out to death")

	# --- (3) revive: a sub-floor severity returns 'revived', never death ---
	var rrev := _seeded(9)
	_assert_equal(String(Downed.downed_tick({"severity": 2, "rounds": 8}, rrev).get("action", "")), "revived", "a medic'd (sub-floor) entry resolves as revived, not death")

	# --- (4) determinism: same seed + entry -> identical action ---
	var da := Downed.downed_tick({"severity": 4, "rounds": 6}, _seeded(321))
	var db := Downed.downed_tick({"severity": 4, "rounds": 6}, _seeded(321))
	_assert_equal(String(da.get("action", "")), String(db.get("action", "")), "server-owned RNG is reproducible (same seed+entry)")

	if _failures.is_empty():
		print("downed_softlock_smoke: OK")
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
