extends SceneTree

# Wave G / G15 (DIV-0028): seeded per-alert SPAWN-MIX invariants. Pure + seeded (server owns RNG),
# no combat, no randomize(). Asserts, over many seeded ambient rolls per alert band:
#   (1) the max threat_tier that appears matches the documented band cap for that (alert, security);
#   (2) NO boss-class creature (merdeth / krayt_dragon / rancor, tier 5 / boss:true) EVER appears in the
#       ambient mix at ANY alert — the ambient spawner must never select the boss/event channel;
#   (3) at the DEFAULT alert ("standard") nothing ambient exceeds tier 3 (the P(out)<20% band);
#   (4) an unknown alert string fails safe to max tier 2.
# This is the acceptance-instrument twin of tools/balance_probe.gd section (C), pinned as a fast smoke.

const CREATURE_DATA_PATH = "res://data/creatures_clone_wars.json"
const BOSS_KEYS = ["krayt_dragon", "merdeth", "rancor"]
const ROLLS = 3000

var _failures = []

func _init() -> void:
	var model = load("res://scripts/rules/creature_spawn_model.gd").new()
	var creatures_data = _load_json(CREATURE_DATA_PATH)
	var creatures: Dictionary = creatures_data.get("creatures", {})
	_assert_true(not creatures.is_empty(), "creature data has creatures")

	# scenario: [label, alert, security, expected_max_tier] — all KNOWN alerts (roll_spawn does not warn).
	var scenarios := [
		["secured", "standard", "secured", 2],
		["lax/lawless", "lax", "lawless", 2],
		["standard/lawless DEFAULT", "standard", "lawless", 3],
		["standard/contested DEFAULT", "standard", "contested", 3],
		["high_alert/lawless", "high_alert", "lawless", 4],
		["lockdown/contested", "lockdown", "contested", 4],
		["unrest/lawless", "unrest", "lawless", 4],
		["underworld/lawless", "underworld", "lawless", 4],
	]

	for sc in scenarios:
		var label := String(sc[0])
		var alert := String(sc[1])
		var security := String(sc[2])
		var expected_cap := int(sc[3])
		var max_seen := 0
		var boss_seen := false
		for s in range(ROLLS):
			var pick := String(model.roll_spawn(creatures_data, alert, security, s * 31 + 5).get("creature_key", ""))
			if pick == "":
				continue
			var c: Dictionary = creatures.get(pick, {})
			max_seen = maxi(max_seen, model.threat_tier_of(c))
			if model.is_boss(c) or BOSS_KEYS.has(pick):
				boss_seen = true
		_assert_true(max_seen <= expected_cap, "[%s] max ambient tier %d <= band cap %d" % [label, max_seen, expected_cap])
		_assert_true(not boss_seen, "[%s] NO boss-class creature EVER ambient" % label)

	# --- Direct band-cap checks (PURE max_threat_tier — no warning, safe under the gate) ---
	_assert_equal(model.max_threat_tier("standard", "lawless"), 3, "DEFAULT (standard/lawless) caps ambient at tier 3 (P(out)<20% band)")

	# --- Unknown-alert FAIL-SAFE: tested via the PURE path (banded_candidate_keys / max_threat_tier), NOT
	# roll_spawn — roll_spawn's push_warning would write to stderr and trip the stderr-is-fatal gate. ---
	for bad_alert in ["calm", "", "APOCALYPSE"]:
		_assert_true(not model.is_known_alert(bad_alert), "'%s' is an unknown alert" % bad_alert)
		_assert_equal(model.max_threat_tier(bad_alert, "lawless"), 2, "unknown alert '%s' fails safe to max tier 2" % bad_alert)
		var band: Array = model.banded_candidate_keys(creatures_data, bad_alert, "lawless")
		for key in band:
			_assert_true(model.threat_tier_of(creatures.get(key, {})) <= 2, "fail-safe band all tier<=2 for '%s' (%s)" % [bad_alert, key])
			_assert_true(not model.is_boss(creatures.get(key, {})), "fail-safe band excludes boss for '%s' (%s)" % [bad_alert, key])

	# --- Every boss is filtered from the banded pool at the MOST permissive ambient band. ---
	var hottest: Array = model.banded_candidate_keys(creatures_data, "lockdown", "lawless")
	for boss in BOSS_KEYS:
		_assert_true(not hottest.has(boss), "boss %s absent even from the most permissive (lockdown) ambient band" % boss)

	if _failures.is_empty():
		print("creature_spawn_mix_smoke: OK")
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

func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
