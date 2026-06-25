extends SceneTree
## Headless smoke test for the world-sim zone director (M2.0).
## Verifies alert-level + security-overlay derivation (pure thresholds), the slow
## deterministic Director tick (decay toward baseline, tick index, re-derivation),
## influence deltas, effective security, snapshot summary, and determinism.

const ZoneState := preload("res://scripts/net/zone_state.gd")
const ZONE := "tatooine.mos_eisley.spaceport"

var _failures: Array[String] = []

func _init() -> void:
	# --- alert-level derivation + precedence ---
	_assert_equal(ZoneState.derive_alert_level({"republic": 75, "hutt": 75}), "lockdown", "Republic >=70 is lockdown (outranks Hutt surge)")
	_assert_equal(ZoneState.derive_alert_level({"republic": 30, "hutt": 75}), "underworld", "Hutt >=70 is underworld")
	_assert_equal(ZoneState.derive_alert_level({"republic": 30, "cis": 45, "hutt": 20}), "unrest", "CIS >=40 is unrest")
	_assert_equal(ZoneState.derive_alert_level({"republic": 55, "cis": 10, "hutt": 20}), "high_alert", "Republic 50-69 is high_alert")
	_assert_equal(ZoneState.derive_alert_level({"republic": 10, "cis": 10, "hutt": 10, "independent": 10}), "lax", "all-low influence is lax")
	_assert_equal(ZoneState.derive_alert_level({"republic": 40, "cis": 10, "hutt": 40, "independent": 30}), "standard", "mid influence is standard")

	# --- security overlay derivation ---
	_assert_equal(ZoneState.derive_security_overlay("secured", {"hutt": 85}, []), "contested", "Hutt surge downgrades secured -> contested")
	_assert_equal(ZoneState.derive_security_overlay("secured", {"hutt": 50}, []), null, "no surge -> no overlay")
	_assert_equal(ZoneState.derive_security_overlay("lawless", {"hutt": 95}, []), null, "lawless cannot downgrade further (overlay == base)")
	_assert_equal(ZoneState.derive_security_overlay("contested", {"hutt": 10}, [{"type": "republic_crackdown"}]), "secured", "crackdown upgrades contested -> secured")

	# --- a live zone, deterministic tick ---
	var dir: ZoneState = ZoneState.new()
	dir.add_zone(ZONE, "secured", {"republic": 60, "cis": 5, "hutt": 40, "independent": 25}, {"republic": 50, "cis": 5, "hutt": 40, "independent": 25}, "Mos Eisley Spaceport")
	_assert_true(dir.has_zone(ZONE), "zone registered")
	_assert_equal(String(dir.get_zone(ZONE).get("alert_level", "")), "high_alert", "republic 60 derives high_alert at add")
	_assert_equal(dir.effective_security(ZONE), "secured", "base secured with no surge")

	# Decay toward baseline (republic 60 -> 50) over ticks.
	for i in range(20):
		dir.director_tick()
	_assert_equal(int(dir.get_zone(ZONE).get("influence", {}).get("republic", -1)), 50, "republic decays to baseline 50")
	_assert_equal(int(dir.get_zone(ZONE).get("tick", -1)), 20, "tick index advances per slow tick")

	# Influence delta drives a tier downgrade, then decays back.
	dir.apply_influence_delta(ZONE, "hutt", 45)  # 40 -> 85
	_assert_equal(dir.effective_security(ZONE), "contested", "Hutt surge makes the zone contested")
	_assert_equal(String(dir.get_zone(ZONE).get("alert_level", "")), "underworld", "Hutt 85 -> underworld alert")
	for i in range(10):
		dir.director_tick()  # hutt 85 -> 75 after 10 ticks; still >= 70 underworld but < 80 surge
	_assert_true(int(dir.get_zone(ZONE).get("influence", {}).get("hutt", 0)) < 80, "hutt decays below surge threshold")
	_assert_equal(dir.effective_security(ZONE), "secured", "effective security returns to base after surge decays")

	# Snapshot summary shape.
	var summary := dir.zone_summary(ZONE)
	for key in ["zone_id", "alert_level", "effective_security", "security_base", "influence", "tick"]:
		_assert_true(summary.has(key), "zone summary has '%s'" % key)

	# Determinism: same setup + same ticks -> identical influence.
	var a: ZoneState = ZoneState.new()
	var b: ZoneState = ZoneState.new()
	for d in [a, b]:
		d.add_zone(ZONE, "contested", {"republic": 30, "cis": 50, "hutt": 20, "independent": 40}, {"republic": 20, "cis": 20, "hutt": 20, "independent": 20})
		d.apply_influence_delta(ZONE, "cis", 10)
		for i in range(7):
			d.director_tick()
	_assert_equal(a.get_zone(ZONE).get("influence"), b.get_zone(ZONE).get("influence"), "director tick is deterministic")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("zone_state_smoke: OK")
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
