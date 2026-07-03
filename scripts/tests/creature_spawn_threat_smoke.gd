extends SceneTree

# Wave G / G12 (spawn-banding half): per-creature threat tiers + alert-banded hostile
# spawns. Verifies that apex predators (krayt dragon / merdeth / rancor) are tier 4 and
# NEVER selectable in a calm/low-alert zone, and only become eligible under an escalated
# alert. Pure + seeded (server owns RNG) — never randomize().

const CREATURE_DATA_PATH = "res://data/creatures_clone_wars.json"
const APEX_KEYS = ["krayt_dragon", "merdeth", "rancor"]

var _failures = []

func _init() -> void:
	var model_script = load("res://scripts/rules/creature_spawn_model.gd")
	var model = model_script.new()

	var creatures_data = _load_json(CREATURE_DATA_PATH)
	var creatures: Dictionary = creatures_data.get("creatures", {})
	_assert_true(not creatures.is_empty(), "creature data has creatures")

	# --- 1) EVERY creature carries a threat_tier in 1..4. ---
	for key in creatures.keys():
		var c: Dictionary = creatures[key]
		_assert_true(c.has("threat_tier"), "%s has threat_tier" % key)
		var t := int(c.get("threat_tier", -1))
		_assert_true(t >= 1 and t <= 4, "%s threat_tier in 1..4 (got %d)" % [key, t])

	# --- 2) The three named apex predators are present and tier 4. ---
	for apex in APEX_KEYS:
		_assert_true(creatures.has(apex), "apex %s exists in data" % apex)
		_assert_equal(int((creatures.get(apex, {}) as Dictionary).get("threat_tier", -1)), 4, "%s is threat_tier 4" % apex)
		_assert_true(bool((creatures.get(apex, {}) as Dictionary).get("hostile", false)), "apex %s is hostile" % apex)

	# --- 3) max_threat_tier maps alert/security -> the documented band. ---
	_assert_equal(model.max_threat_tier("lax", "lawless"), 2, "calm(lax) lawless -> max tier 2")
	_assert_equal(model.max_threat_tier("standard", "lawless"), 3, "standard lawless -> max tier 3 (elevated)")
	_assert_equal(model.max_threat_tier("standard", "contested"), 3, "standard contested -> max tier 3 (elevated)")
	_assert_equal(model.max_threat_tier("high_alert", "lawless"), 4, "high_alert lawless -> max tier 4 (apex)")
	_assert_equal(model.max_threat_tier("lockdown", "contested"), 4, "lockdown contested -> max tier 4 (apex)")
	_assert_equal(model.max_threat_tier("unrest", "lawless"), 4, "unrest lawless -> max tier 4 (apex)")
	_assert_equal(model.max_threat_tier("standard", "secured"), 2, "secured zone is always calm (max tier 2)")
	_assert_equal(model.max_threat_tier("high_alert", "secured"), 2, "secured zone stays calm even at high_alert")

	# --- 4) A calm/low-alert lawless band excludes tier-4 apex (never returned). ---
	var calm_band: Array = model.banded_candidate_keys(creatures_data, "lax", "lawless")
	_assert_true(not calm_band.is_empty(), "calm(lax) lawless band is non-empty (tier<=2 hostiles exist)")
	for apex in APEX_KEYS:
		_assert_true(not calm_band.has(apex), "calm band excludes apex %s" % apex)
	var calm_all_low := true
	for key in calm_band:
		if model.threat_tier_of(creatures.get(key, {})) > 2:
			calm_all_low = false
	_assert_true(calm_all_low, "calm(lax) lawless band is all threat_tier <= 2")
	_assert_true(_is_sorted(calm_band), "calm band is sorted (stable indexing)")

	# --- 5) A high-alert band includes all three apex predators. ---
	var apex_band: Array = model.banded_candidate_keys(creatures_data, "high_alert", "lawless")
	for apex in APEX_KEYS:
		_assert_true(apex_band.has(apex), "high_alert lawless band includes apex %s" % apex)

	# --- 6) Determinism: same (alert, security, seed) -> identical banded roll. ---
	var roll_a: Dictionary = model.roll_spawn(creatures_data, "lax", "lawless", 4242)
	var roll_b: Dictionary = model.roll_spawn(creatures_data, "lax", "lawless", 4242)
	_assert_true(not roll_a.is_empty(), "calm band roll returns a spawn")
	_assert_equal(roll_a.get("creature_key", ""), roll_b.get("creature_key", ""), "same seed -> same creature_key")

	# --- 6b) Over many seeds a calm band NEVER rolls an apex; a high-alert band CAN. ---
	var saw_apex_calm := false
	var saw_apex_hot := false
	for s in range(400):
		var calm_pick := String(model.roll_spawn(creatures_data, "lax", "lawless", s).get("creature_key", ""))
		if APEX_KEYS.has(calm_pick):
			saw_apex_calm = true
		var hot_pick := String(model.roll_spawn(creatures_data, "high_alert", "lawless", s).get("creature_key", ""))
		if APEX_KEYS.has(hot_pick):
			saw_apex_hot = true
	_assert_true(not saw_apex_calm, "no apex EVER rolled in a calm(lax) lawless zone (400 seeds)")
	_assert_true(saw_apex_hot, "at least one apex rolled in a high_alert lawless zone (400 seeds)")

	# --- 7) Fallback: a creature with no threat_tier defaults to 2 (and clamps). ---
	_assert_equal(model.threat_tier_of({}), 2, "missing threat_tier -> default 2")
	_assert_equal(model.threat_tier_of({"threat_tier": 9}), 4, "threat_tier above 4 clamps to 4")
	_assert_equal(model.threat_tier_of({"threat_tier": 0}), 1, "threat_tier below 1 clamps to 1")

	# The default(2) is respected by the tier filter: included at cap 2, excluded at cap 1.
	var synth := {"mystery_beast": {"name": "Mystery", "hostile": true}}  # NO threat_tier
	var synth_keys := ["mystery_beast"]
	_assert_true(model.keys_within_tier(synth, synth_keys, 2).has("mystery_beast"), "no-tier creature (default 2) passes a max-tier-2 cap")
	_assert_true(not model.keys_within_tier(synth, synth_keys, 1).has("mystery_beast"), "no-tier creature (default 2) excluded by a max-tier-1 cap")

	# A full spawn on synthetic no-tier data still works (banding falls back, never strands).
	var synth_data := {"creatures": {"mystery_beast": {"name": "Mystery", "hostile": true, "char_sheet": {}, "natural_attack": {}}}}
	var synth_band: Array = model.banded_candidate_keys(synth_data, "lax", "lawless")
	_assert_true(synth_band.has("mystery_beast"), "no-tier creature is spawnable in a calm band (default 2 <= 2)")

	if _failures.is_empty():
		print("creature_spawn_threat_smoke: OK")
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
