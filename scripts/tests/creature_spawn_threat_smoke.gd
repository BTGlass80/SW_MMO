extends SceneTree

# Wave G / G12 (spawn-banding half), re-tuned in G15 (DIV-0028): per-creature threat tiers
# DERIVED FROM MEASURED lethality + a boss/event channel + a fail-safe alert clamp. Verifies:
#   - every creature carries a threat_tier in 1..5;
#   - the named apex-legendary predators (krayt dragon / merdeth / rancor) are BOSS (tier 5,
#     boss:true) and are NEVER selectable through the ambient spawner under ANY alert;
#   - tier-4 apex creatures are ambient ONLY under an escalated alert (never calm/default);
#   - an unknown alert string fails safe to max tier 2.
# Pure + seeded (server owns RNG) — never randomize().

const CREATURE_DATA_PATH = "res://data/creatures_clone_wars.json"
const BOSS_KEYS = ["krayt_dragon", "merdeth", "rancor"]

var _failures = []

func _init() -> void:
	var model_script = load("res://scripts/rules/creature_spawn_model.gd")
	var model = model_script.new()

	var creatures_data = _load_json(CREATURE_DATA_PATH)
	var creatures: Dictionary = creatures_data.get("creatures", {})
	_assert_true(not creatures.is_empty(), "creature data has creatures")

	# --- 1) EVERY creature carries a threat_tier in 1..5. ---
	for key in creatures.keys():
		var c: Dictionary = creatures[key]
		_assert_true(c.has("threat_tier"), "%s has threat_tier" % key)
		var t := int(c.get("threat_tier", -1))
		_assert_true(t >= 1 and t <= 5, "%s threat_tier in 1..5 (got %d)" % [key, t])

	# --- 2) The three named apex-legendary predators are BOSS: tier 5 + boss:true + hostile. ---
	for boss in BOSS_KEYS:
		_assert_true(creatures.has(boss), "boss %s exists in data" % boss)
		_assert_equal(int((creatures.get(boss, {}) as Dictionary).get("threat_tier", -1)), 5, "%s is threat_tier 5 (boss)" % boss)
		_assert_true(model.is_boss(creatures.get(boss, {})), "%s is_boss()" % boss)
		_assert_true(bool((creatures.get(boss, {}) as Dictionary).get("hostile", false)), "boss %s is hostile" % boss)

	# A non-boss (e.g. tier-4 apex acklay) is NOT is_boss.
	_assert_true(not model.is_boss(creatures.get("acklay", {})), "tier-4 acklay is NOT boss")

	# --- 3) max_threat_tier maps alert/security -> the documented band (never the boss band). ---
	_assert_equal(model.max_threat_tier("lax", "lawless"), 2, "calm(lax) lawless -> max tier 2")
	_assert_equal(model.max_threat_tier("standard", "lawless"), 3, "standard lawless -> max tier 3 (elevated)")
	_assert_equal(model.max_threat_tier("standard", "contested"), 3, "standard contested -> max tier 3 (elevated)")
	_assert_equal(model.max_threat_tier("high_alert", "lawless"), 4, "high_alert lawless -> max tier 4 (apex)")
	_assert_equal(model.max_threat_tier("lockdown", "contested"), 4, "lockdown contested -> max tier 4 (apex)")
	_assert_equal(model.max_threat_tier("unrest", "lawless"), 4, "unrest lawless -> max tier 4 (apex)")
	_assert_equal(model.max_threat_tier("underworld", "lawless"), 4, "underworld lawless -> max tier 4 (apex)")
	_assert_equal(model.max_threat_tier("standard", "secured"), 2, "secured zone is always calm (max tier 2)")
	_assert_equal(model.max_threat_tier("high_alert", "secured"), 2, "secured zone stays calm even at high_alert")

	# --- 3b) FAIL-SAFE (G15): an unknown alert clamps to the SAFEST band (max tier 2). ---
	_assert_equal(model.max_threat_tier("calm", "lawless"), 2, "unknown alert 'calm' fails safe to max tier 2")
	_assert_equal(model.max_threat_tier("", "lawless"), 2, "empty alert fails safe to max tier 2")
	_assert_equal(model.max_threat_tier("APOCALYPSE", "contested"), 2, "unknown alert never opens the apex band")

	# --- 4) A calm/low-alert lawless band excludes tier-4 apex AND boss (never returned). ---
	var calm_band: Array = model.banded_candidate_keys(creatures_data, "lax", "lawless")
	_assert_true(not calm_band.is_empty(), "calm(lax) lawless band is non-empty (tier<=2 hostiles exist)")
	for boss in BOSS_KEYS:
		_assert_true(not calm_band.has(boss), "calm band excludes boss %s" % boss)
	var calm_all_low := true
	for key in calm_band:
		if model.threat_tier_of(creatures.get(key, {})) > 2:
			calm_all_low = false
	_assert_true(calm_all_low, "calm(lax) lawless band is all threat_tier <= 2")
	_assert_true(_is_sorted(calm_band), "calm band is sorted (stable indexing)")

	# --- 5) A high-alert band includes tier-4 apex but STILL excludes every boss. ---
	var apex_band: Array = model.banded_candidate_keys(creatures_data, "high_alert", "lawless")
	_assert_true(apex_band.has("acklay"), "high_alert lawless band includes tier-4 apex acklay")
	for boss in BOSS_KEYS:
		_assert_true(not apex_band.has(boss), "high_alert band STILL excludes boss %s (never ambient)" % boss)

	# --- 6) Determinism: same (alert, security, seed) -> identical banded roll. ---
	var roll_a: Dictionary = model.roll_spawn(creatures_data, "lax", "lawless", 4242)
	var roll_b: Dictionary = model.roll_spawn(creatures_data, "lax", "lawless", 4242)
	_assert_true(not roll_a.is_empty(), "calm band roll returns a spawn")
	_assert_equal(roll_a.get("creature_key", ""), roll_b.get("creature_key", ""), "same seed -> same creature_key")

	# --- 6b) Over many seeds: NO boss EVER rolls at any KNOWN alert; a high-alert band DOES roll tier-4 apex. ---
	var saw_boss := false
	var saw_apex_hot := false
	var alerts := ["lax", "standard", "high_alert", "lockdown", "unrest", "underworld"]
	for s in range(600):
		for a in alerts:
			var pick := String(model.roll_spawn(creatures_data, a, "lawless", s * 7 + alerts.find(a)).get("creature_key", ""))
			if BOSS_KEYS.has(pick):
				saw_boss = true
		var hot_pick := String(model.roll_spawn(creatures_data, "high_alert", "lawless", s).get("creature_key", ""))
		if model.threat_tier_of(creatures.get(hot_pick, {})) == 4:
			saw_apex_hot = true
	_assert_true(not saw_boss, "no boss EVER rolled through the ambient spawner at ANY known alert (600 seeds x 6 alerts)")
	_assert_true(saw_apex_hot, "at least one tier-4 apex rolled in a high_alert lawless zone (600 seeds)")

	# An UNKNOWN alert also fails safe: the banded pool clamps to tier<=2 and excludes every boss. Tested
	# via banded_candidate_keys / max_threat_tier (the PURE query path) — NOT roll_spawn, whose push_warning
	# diagnostic would write to stderr and trip the gate's stderr-is-fatal harness.
	_assert_true(not model.is_known_alert("calm"), "'calm' is an unknown alert (drives the fail-safe)")
	var failsafe_band: Array = model.banded_candidate_keys(creatures_data, "calm", "lawless")
	_assert_true(not failsafe_band.is_empty(), "unknown-alert fail-safe band is non-empty")
	for key in failsafe_band:
		_assert_true(model.threat_tier_of(creatures.get(key, {})) <= 2, "unknown-alert fail-safe band is all tier <= 2 (%s)" % key)
		_assert_true(not model.is_boss(creatures.get(key, {})), "unknown-alert fail-safe band excludes boss (%s)" % key)

	# --- 7) Fallback: a creature with no threat_tier defaults to 2 (and clamps to the boss ceiling). ---
	_assert_equal(model.threat_tier_of({}), 2, "missing threat_tier -> default 2")
	_assert_equal(model.threat_tier_of({"threat_tier": 9}), 5, "threat_tier above 5 clamps to 5")
	_assert_equal(model.threat_tier_of({"threat_tier": 0}), 1, "threat_tier below 1 clamps to 1")
	_assert_true(model.is_boss({"threat_tier": 5}), "tier-5 is boss")
	_assert_true(model.is_boss({"boss": true, "threat_tier": 2}), "an explicit boss:true flag marks a boss even at a low tier")

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
