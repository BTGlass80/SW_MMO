extends SceneTree
## Headless smoke test for the authoritative networking core.
##
## Exercises the pure, socket-free WorldState (server-side simulation): join,
## input intent, deterministic movement, world bounds, snapshot shape, leave.
## No ENet here — the network transport is verified separately with two
## processes; this guards the authoritative game logic the server runs each tick.

const WorldState := preload("res://scripts/net/world_state.gd")

var _failures: Array[String] = []

func _init() -> void:
	var state: WorldState = WorldState.new()

	# Join.
	state.add_player(2, "Mara")
	_assert_equal(state.player_count(), 1, "one player after join")
	_assert_true(state.has_player(2), "player 2 is registered")
	var joined: Dictionary = state.get_player(2)
	_assert_equal(joined.get("name", ""), "Mara", "join keeps display name")
	_assert_true((joined.get("pos") as Vector3).is_equal_approx(WorldState.SPAWN_POINT), "spawns at spawn point")

	# Default-named join.
	state.add_player(3)
	_assert_equal(state.get_player(3).get("name", ""), "Spacer-3", "default name derives from peer id")

	# Authoritative forward movement (W = move.y -1 = -Z) for 0.5s.
	state.set_input(2, Vector2(0.0, -1.0), 0.0, false)
	state.tick(0.5)
	var moved: Vector3 = state.get_player(2).get("pos")
	var expected_z := WorldState.SPAWN_POINT.z - WorldState.MOVE_SPEED * 0.5
	_assert_approx(moved.z, expected_z, "forward input integrates along -Z")
	_assert_approx(moved.y, WorldState.GROUND_Y, "movement stays on the ground plane")
	_assert_approx(moved.x, WorldState.SPAWN_POINT.x, "pure forward input leaves X unchanged")

	# A player with no input does not drift.
	var idle_before: Vector3 = state.get_player(3).get("pos")
	state.tick(0.5)
	_assert_true((state.get_player(3).get("pos") as Vector3).is_equal_approx(idle_before), "idle player does not move")

	# Input is clamped to unit length (no speed-hacking via huge vectors).
	state.set_input(3, Vector2(30.0, 40.0), 0.0, false)
	_assert_approx((state.get_player(3).get("move") as Vector2).length(), 1.0, "oversized input is normalized")

	# World bounds hold under sustained movement.
	state.set_input(2, Vector2(1.0, 0.0), 0.0, false)
	for i in range(600):
		state.tick(0.1)
	var bounded: Vector3 = state.get_player(2).get("pos")
	_assert_true(absf(bounded.x) <= WorldState.HALF_BOUNDS + 0.001, "X stays within world bounds")
	_assert_true(absf(bounded.z) <= WorldState.HALF_BOUNDS + 0.001, "Z stays within world bounds")

	# Snapshot shape.
	var snap: Dictionary = state.snapshot()
	_assert_true(snap.has("tick"), "snapshot carries a tick index")
	_assert_equal((snap.get("players", []) as Array).size(), 2, "snapshot lists every player")
	var first: Dictionary = (snap.get("players") as Array)[0]
	for key in ["id", "name", "pos", "yaw"]:
		_assert_true(first.has(key), "snapshot entry has '%s'" % key)

	# Identity: a login can authoritatively rename + reposition a player (M1.5).
	state.restore_player(3, Vector3(1.0, WorldState.GROUND_Y, 2.0), 0.5, "Mara Jade")
	_assert_equal(state.get_player(3).get("name", ""), "Mara Jade", "restore_player updates the display name")
	_assert_true((state.get_player(3).get("pos") as Vector3).is_equal_approx(Vector3(1.0, WorldState.GROUND_Y, 2.0)), "restore_player snaps position")
	# Empty name leaves the existing name untouched.
	state.restore_player(3, Vector3(1.0, WorldState.GROUND_Y, 2.0), 0.5, "")
	_assert_equal(state.get_player(3).get("name", ""), "Mara Jade", "restore_player with empty name keeps the current name")

	# Leave.
	state.remove_player(2)
	state.remove_player(3)
	_assert_equal(state.player_count(), 0, "no players after everyone leaves")

	# DIV-0015: per-player move_speed scales authoritative distance (isolated state). A
	# faster species (e.g. wookiee ~1.1x) out-travels the baseline in equal time; the
	# default (move-10 species) is unchanged.
	var sstate: WorldState = WorldState.new()
	sstate.add_player(1, "Base")
	sstate.add_player(2, "Fast")
	sstate.set_move_speed(2, WorldState.MOVE_SPEED * 1.1)
	sstate.set_input(1, Vector2(0.0, -1.0), 0.0, false)
	sstate.set_input(2, Vector2(0.0, -1.0), 0.0, false)
	sstate.tick(0.5)
	var base_z := (sstate.get_player(1).get("pos") as Vector3).z
	var fast_z := (sstate.get_player(2).get("pos") as Vector3).z
	_assert_approx(base_z, WorldState.SPAWN_POINT.z - WorldState.MOVE_SPEED * 0.5, "default move_speed is the baseline")
	_assert_approx(fast_z, WorldState.SPAWN_POINT.z - WorldState.MOVE_SPEED * 1.1 * 0.5, "custom move_speed scales distance")
	_assert_true(fast_z < base_z, "a 1.1x player out-travels the baseline in equal time")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("net_smoke: OK")
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

func _assert_approx(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.0001:
		_failures.append("%s: expected ~%f, got %f" % [label, expected, actual])
