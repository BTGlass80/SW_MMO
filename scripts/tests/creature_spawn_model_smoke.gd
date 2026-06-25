extends SceneTree

const CREATURE_DATA_PATH = "res://data/creatures_clone_wars.json"

var _failures = []

func _init() -> void:
	var model_script = load("res://scripts/rules/creature_spawn_model.gd")
	var model = model_script.new()

	var creatures_data = _load_json(CREATURE_DATA_PATH)
	var creatures: Dictionary = creatures_data.get("creatures", {})
	_assert_true(not creatures.is_empty(), "creature data has creatures")

	# --- Determinism: same (alert, security, seed) -> identical roll twice. ---
	var spawn_a = model.roll_spawn(creatures_data, "high_alert", "lawless", 4242)
	var spawn_b = model.roll_spawn(creatures_data, "high_alert", "lawless", 4242)
	_assert_true(not spawn_a.is_empty(), "deterministic roll returns a spawn")
	_assert_equal(spawn_a.get("creature_key", ""), spawn_b.get("creature_key", ""), "same seed -> same creature_key")
	_assert_equal(spawn_a.get("pack_size", -1), spawn_b.get("pack_size", -2), "same seed -> same pack_size")

	# --- pack_size within [min,max] of the chosen creature. ---
	var chosen = creatures.get(String(spawn_a.get("creature_key", "")), {})
	var pc: Array = chosen.get("pack_count", [1, 1])
	var pack_min := int(pc[0])
	var pack_max := int(pc[1])
	var pack_size := int(spawn_a.get("pack_size", -1))
	_assert_true(pack_size >= pack_min and pack_size <= pack_max, "pack_size within [min,max] of chosen creature")

	# --- char_sheet / natural_attack non-empty AND hostile is a bool. ---
	var sheet: Dictionary = spawn_a.get("char_sheet", {})
	var attack: Dictionary = spawn_a.get("natural_attack", {})
	_assert_true(not sheet.is_empty(), "result.char_sheet is non-empty")
	_assert_true(not attack.is_empty(), "result.natural_attack is non-empty")
	_assert_true(typeof(spawn_a.get("hostile")) == TYPE_BOOL, "result.hostile is a bool")

	# --- candidate_keys: dangerous vs calm differ; sets are pure by hostility. ---
	var dangerous_keys: Array = model.candidate_keys(creatures_data, "high_alert", "lawless")
	var calm_keys: Array = model.candidate_keys(creatures_data, "lax", "secured")
	_assert_true(not dangerous_keys.is_empty(), "dangerous candidate set non-empty")
	_assert_true(not calm_keys.is_empty(), "calm candidate set non-empty")
	_assert_true(dangerous_keys != calm_keys, "dangerous and calm candidate sets differ")

	var dangerous_all_hostile := true
	for key in dangerous_keys:
		if not bool(creatures.get(key, {}).get("hostile", false)):
			dangerous_all_hostile = false
	_assert_true(dangerous_all_hostile, "dangerous candidate set is all hostile")

	var calm_all_nonhostile := true
	for key in calm_keys:
		if bool(creatures.get(key, {}).get("hostile", false)):
			calm_all_nonhostile = false
	_assert_true(calm_all_nonhostile, "calm candidate set is all non-hostile")

	# --- candidate_keys is sorted (stable indexing) for both postures. ---
	_assert_true(_is_sorted(dangerous_keys), "dangerous candidate set is sorted")
	_assert_true(_is_sorted(calm_keys), "calm candidate set is sorted")

	# --- Neutral posture returns all creatures (no bias). ---
	var neutral_keys: Array = model.candidate_keys(creatures_data, "normal", "monitored")
	_assert_equal(neutral_keys.size(), creatures.size(), "neutral posture returns all creatures")

	# --- Empty data -> empty candidate set and empty spawn. ---
	_assert_true(model.candidate_keys({"creatures": {}}, "high_alert", "lawless").is_empty(), "empty data -> empty candidate set")
	_assert_true(model.roll_spawn({"creatures": {}}, "high_alert", "lawless", 1).is_empty(), "empty data -> empty spawn")

	if _failures.is_empty():
		print("creature_spawn_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _load_json(path):
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % path)
		return {}
	return parsed

func _is_sorted(arr: Array) -> bool:
	var copy := arr.duplicate()
	copy.sort()
	return copy == arr

func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
