extends SceneTree
## Headless smoke for the pure ambient-NPC sim (E27). Verifies alert-keyed population,
## in-bounds + valid-kind spawns, determinism, carry-over of unexpired NPCs, and despawn
## on expiry.

const Ambient := preload("res://scripts/net/ambient_sim_model.gd")
const BOUNDS := {"min_x": -10.0, "max_x": 10.0, "min_z": -5.0, "max_z": 5.0, "y": 1.2}

var _failures: Array[String] = []

func _init() -> void:
	# Target population by alert.
	_assert_equal(Ambient.target_population("lockdown"), 5, "lockdown population")
	_assert_equal(Ambient.target_population("lax"), 2, "lax population")
	_assert_equal(Ambient.target_population("unknown_alert"), Ambient.DEFAULT_POP, "unknown alert -> default population")

	# Advance from empty: spawns exactly target NPCs, in-bounds, valid kinds, expiry set.
	var r0: Array = Ambient.advance([], "z.test", "underworld", 0, BOUNDS)
	_assert_equal(r0.size(), Ambient.target_population("underworld"), "spawns up to target for underworld")
	var kinds: Array = Ambient.kinds_for("underworld")
	for npc in r0:
		var n: Dictionary = npc
		var pos: Dictionary = n["pos"]
		_assert_true(float(pos["x"]) >= float(BOUNDS["min_x"]) and float(pos["x"]) <= float(BOUNDS["max_x"]), "npc x within bounds")
		_assert_true(float(pos["z"]) >= float(BOUNDS["min_z"]) and float(pos["z"]) <= float(BOUNDS["max_z"]), "npc z within bounds")
		_assert_true(kinds.has(String(n["kind"])), "npc kind drawn from the alert roster")
		_assert_equal(int(n["expires_at_tick"]), Ambient.NPC_LIFESPAN, "npc expiry = tick + lifespan")

	# Determinism: same inputs -> identical roster.
	var r0b: Array = Ambient.advance([], "z.test", "underworld", 0, BOUNDS)
	_assert_equal(r0, r0b, "advance is deterministic")

	# Carry-over: next tick keeps unexpired NPCs (no new spawns when already at target).
	var r1: Array = Ambient.advance(r0, "z.test", "underworld", 1, BOUNDS)
	_assert_equal(r1.size(), Ambient.target_population("underworld"), "population stays at target across a tick")
	_assert_equal(String((r1[0] as Dictionary)["id"]), String((r0[0] as Dictionary)["id"]), "an unexpired NPC carries over (same id)")

	# Despawn on expiry: after lifespan, the tick-0 NPCs are gone and fresh ones respawn.
	var r_expired: Array = Ambient.advance(r0, "z.test", "underworld", Ambient.NPC_LIFESPAN + 1, BOUNDS)
	var old_ids := {}
	for npc in r0:
		old_ids[String((npc as Dictionary)["id"])] = true
	var any_old := false
	for npc in r_expired:
		if old_ids.has(String((npc as Dictionary)["id"])):
			any_old = true
	_assert_true(not any_old, "expired NPCs despawn (no tick-0 ids survive past lifespan)")
	_assert_equal(r_expired.size(), Ambient.target_population("underworld"), "fresh NPCs respawn to target after expiry")

	# A calmer alert keeps fewer ambient NPCs.
	var lax: Array = Ambient.advance([], "z.test", "lax", 0, BOUNDS)
	_assert_equal(lax.size(), 2, "lax spawns fewer NPCs")

	if _failures.is_empty():
		print("ambient_sim_model_smoke: OK")
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
