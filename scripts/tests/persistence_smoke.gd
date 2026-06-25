extends SceneTree
## Headless smoke test for the server-side persistence store (M1.4).
## Verifies: missing record -> empty / sensible default; save+load round-trips
## position and sheet; the typed helpers (pos/yaw/combat <-> record) are lossless;
## the wound-state mapping is a bijection over the severity ladder; path-unsafe ids
## are sanitized. Writes under a throwaway user:// dir and cleans up.

const PersistenceStore := preload("res://scripts/net/persistence_store.gd")
const TEST_ROOT := "user://persistence_smoke_test"

var _failures: Array[String] = []

func _init() -> void:
	_clean()
	var store: PersistenceStore = PersistenceStore.new(TEST_ROOT)

	# Missing record.
	_assert_true(not store.has_record("nobody"), "unknown character has no record")
	_assert_true(store.load_record("nobody").is_empty(), "loading an unknown record returns empty")

	# Default for a new character.
	var spawn := Vector3(-20.0, 1.2, -6.0)
	var fresh := store.load_or_create("char_a", "acct_a", "Mara", spawn)
	_assert_equal(int(fresh.get("schema_version", -1)), 1, "default record schema version")
	_assert_equal(String(fresh.get("name", "")), "Mara", "default record keeps name")
	_assert_true(PersistenceStore.record_pos(fresh, Vector3.ZERO).is_equal_approx(spawn), "default record spawns at the spawn point")

	# Save then load round-trips position + sheet.
	var moved := PersistenceStore.apply_position(fresh, Vector3(12.5, 1.2, -3.25), 1.57)
	moved = PersistenceStore.apply_combat(moved, {"player_character_points": 8, "player_force_points": 2, "player_wound_severity": 2})
	_assert_true(store.save_record("char_a", moved), "save succeeds")
	_assert_true(store.has_record("char_a"), "record exists after save")
	var reloaded := store.load_record("char_a")
	_assert_true(PersistenceStore.record_pos(reloaded, Vector3.ZERO).is_equal_approx(Vector3(12.5, 1.2, -3.25)), "position round-trips")
	_assert_approx(PersistenceStore.record_yaw(reloaded), 1.57, "yaw round-trips")
	var combat := PersistenceStore.combat_from_record(reloaded)
	_assert_equal(int(combat["player_character_points"]), 8, "CP round-trips")
	_assert_equal(int(combat["player_force_points"]), 2, "FP round-trips")
	_assert_equal(int(combat["player_wound_severity"]), 2, "wound severity round-trips through wound_state")

	# A second store pointed at the same dir sees the persisted record (survives restart).
	var store2: PersistenceStore = PersistenceStore.new(TEST_ROOT)
	_assert_true(store2.has_record("char_a"), "a fresh store instance sees the saved record")

	# Wound-state mapping is a bijection over the ladder.
	for severity in range(0, 6):
		var state := PersistenceStore.wound_state_for_severity(severity)
		_assert_equal(PersistenceStore.severity_for_wound_state(state), severity, "wound ladder round-trips at severity %d" % severity)

	# Path-unsafe ids are sanitized and stay inside the root.
	_assert_true(store.save_record("../../evil id!", {"schema_version": 1, "name": "x"}), "sanitized id saves")
	_assert_true(store.record_path("../../evil id!").begins_with(TEST_ROOT), "sanitized path stays under the root")

	_clean()
	_finish()

func _clean() -> void:
	var dir := DirAccess.open(TEST_ROOT)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)

func _finish() -> void:
	if _failures.is_empty():
		print("persistence_smoke: OK")
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
