extends SceneTree
## Dedicated SOFTLOCK-GUARD (DIV-0027). Proves a medic-less downed player ALWAYS resolves in bounded time
## by ticking the REAL scripts/rules/downed_model.gd with a server-owned SEEDED rng (no arena/RPC). This
## is the escape-hatch proof the execution plan mandates: tiering-without-a-bounded-exit is a softlock.
##   (1) sev-4, NO medic, NO yield: the bleed-out reaches 'die' within <= MORTAL_CERTAIN_ROUNDS, for a
##       spread of seeds (termination is seed-INDEPENDENT).
##   (2) sev-3, NO medic, NO yield: deteriorates to sev-4 exactly at INCAP_DETERIORATE_WINDOWS, then the
##       sev-4 bleed-out reaches 'die' — BOTH tiers auto-resolve with ZERO player input.
##   (3) revive: a tick whose severity was lowered below the floor (medic) returns 'revived', no death.
##   (4) determinism: same seed + entry -> identical action.
## No infinite loop is reachable for either tier.

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

	# --- (2) sev-3 deteriorates at exactly INCAP_DETERIORATE_WINDOWS, then bleeds out ---
	var rng3 := _seeded(55)
	var e3 := {"severity": 3, "rounds": 0}
	var deteriorated_at := -1
	for i in range(Downed.INCAP_DETERIORATE_WINDOWS + 2):
		var res := Downed.downed_tick(e3, rng3)
		var action := String(res.get("action", ""))
		if action == "deteriorate":
			deteriorated_at = i + 1  # number of ticks taken
			e3["severity"] = int(res.get("next_severity", 4))
			e3["rounds"] = int(res.get("rounds", 0))
			break
		_assert_equal(action, "hold", "sev-3 holds until deterioration (tick %d)" % (i + 1))
		e3["severity"] = int(res.get("next_severity", 3))
		e3["rounds"] = int(res.get("rounds", 0))
	_assert_equal(deteriorated_at, Downed.INCAP_DETERIORATE_WINDOWS, "sev-3 deteriorates at exactly INCAP_DETERIORATE_WINDOWS")
	_assert_equal(int(e3["severity"]), 4, "post-deterioration severity is 4 (mortally_wounded)")
	# continue from sev-4 -> must reach death
	var died3 := false
	for _j in range(Downed.MORTAL_CERTAIN_ROUNDS + 1):
		var res := Downed.downed_tick(e3, rng3)
		if String(res.get("action", "")) == "die":
			died3 = true
			break
		e3["severity"] = int(res.get("next_severity", 4))
		e3["rounds"] = int(res.get("rounds", 0))
	_assert_true(died3, "a deteriorated sev-3 then bleeds out to death (zero player input)")

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
