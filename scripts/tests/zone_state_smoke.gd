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

	# World events fire deterministically from the Director tick, from the fixed menu.
	var ev_dir: ZoneState = ZoneState.new()
	ev_dir.add_zone("evt.zone", "contested", {"republic": 40, "cis": 10, "hutt": 30, "independent": 20}, {"republic": 40, "cis": 10, "hutt": 30, "independent": 20})
	var fired := {}
	for i in range(40):
		ev_dir.director_tick()
		if String(ev_dir.zone_summary("evt.zone").get("event_type", "")) != "":
			fired = ev_dir.zone_summary("evt.zone")
			break
	_assert_true(not fired.is_empty(), "the Director fires a world event within 40 ticks")
	_assert_true(ZoneState.EVENT_HEADLINES.has(String(fired.get("event_type", ""))), "fired event type is from the fixed 12-event menu")
	_assert_true(String(fired.get("event", "")) != "", "fired event has a player-facing headline")

	# Event firing is deterministic (same ticks -> same event).
	var ea: ZoneState = ZoneState.new()
	var eb: ZoneState = ZoneState.new()
	for dir2 in [ea, eb]:
		dir2.add_zone("z", "contested", {"republic": 40, "cis": 10, "hutt": 30, "independent": 20}, {"republic": 40, "cis": 10, "hutt": 30, "independent": 20})
		for i in range(15):
			dir2.director_tick()
	_assert_equal(ea.zone_summary("z").get("event_type"), eb.zone_summary("z").get("event_type"), "event firing is deterministic")

	# --- E13: event mechanical effects (bounded, surfaced in zone_summary) ---
	for ev_type in ZoneState.EVENT_HEADLINES.keys():
		var fx: Dictionary = ZoneState.effects_for_event(String(ev_type))
		for k in ["smuggling", "vendor", "spawn", "perception"]:
			_assert_true(fx.has(k), "event '%s' effect has '%s'" % [ev_type, k])
			_assert_true(absi(int(fx[k])) <= 2, "event '%s' effect '%s' is bounded [-2,2]" % [ev_type, k])
	_assert_equal(int(ZoneState.effects_for_event("republic_crackdown")["perception"]), 2, "crackdown raises perception")
	_assert_equal(int(ZoneState.effects_for_event("republic_crackdown")["smuggling"]), -2, "crackdown suppresses smuggling")
	_assert_equal(int(ZoneState.effects_for_event("trade_boom")["vendor"]), 2, "trade boom boosts vendor")
	var neutral_fx: Dictionary = ZoneState.effects_for_event("nonexistent_event")
	for k in ["smuggling", "vendor", "spawn", "perception"]:
		_assert_equal(int(neutral_fx[k]), 0, "unknown-event effect '%s' is neutral" % k)
	_assert_true(dir.zone_summary(ZONE).has("effects"), "zone summary carries effects")

	# --- E13: active-event influence nudge, bounded by the foothold cap ---
	# Foothold band (hutt 55): hutt events fire (hutt>=50) and nudge hutt up; baseline
	# == start so DECAY never moves it (only the nudge does), isolating the nudge.
	var nudge_dir: ZoneState = ZoneState.new()
	nudge_dir.add_zone("nudge.zone", "lawless", {"republic": 10, "cis": 10, "hutt": 55, "independent": 10}, {"republic": 10, "cis": 10, "hutt": 55, "independent": 10})
	for i in range(20):
		nudge_dir.director_tick()
	var nudged_hutt := int(nudge_dir.get_zone("nudge.zone").get("influence", {}).get("hutt", 0))
	_assert_true(nudged_hutt > 55, "active hutt events nudge hutt above baseline (got %d)" % nudged_hutt)
	_assert_true(nudged_hutt <= ZoneState.EVENT_INFLUENCE_CAP, "nudge is capped at the foothold cap (got %d)" % nudged_hutt)

	# Above the cap (hutt 75): the nudge is suppressed -> a surge decays normally, no
	# runaway (baseline == 75 so it simply stays put).
	var capped_dir: ZoneState = ZoneState.new()
	capped_dir.add_zone("capped.zone", "lawless", {"republic": 10, "cis": 10, "hutt": 75, "independent": 10}, {"republic": 10, "cis": 10, "hutt": 75, "independent": 10})
	for i in range(15):
		capped_dir.director_tick()
	_assert_equal(int(capped_dir.get_zone("capped.zone").get("influence", {}).get("hutt", 0)), 75, "hutt above the cap is not nudged")

	# The nudge is deterministic (same setup + ticks -> identical influence).
	var na: ZoneState = ZoneState.new()
	var nb: ZoneState = ZoneState.new()
	for nd in [na, nb]:
		nd.add_zone("z", "lawless", {"republic": 10, "cis": 10, "hutt": 55, "independent": 10}, {"republic": 10, "cis": 10, "hutt": 55, "independent": 10})
		for i in range(12):
			nd.director_tick()
	_assert_equal(na.get_zone("z").get("influence"), nb.get_zone("z").get("influence"), "event nudge is deterministic")

	# --- F58: world-sim state survives a SERVER RESTART (to_dict / apply_persisted roundtrip) ---
	# Mutate a zone (player influence + a couple Director ticks), serialize, then restore onto a
	# freshly re-seeded roster (as a rebooted server would) and confirm an exact reproduction.
	var live: ZoneState = ZoneState.new()
	live.add_zone("persist.zone", "contested", {"republic": 10, "hutt": 5}, {"republic": 10, "hutt": 5})
	live.apply_influence_delta("persist.zone", "hutt", 80)  # hutt -> 85 (drives alert + security)
	live.director_tick()
	live.director_tick()
	var blob := live.to_dict()
	var booted: ZoneState = ZoneState.new()
	booted.add_zone("persist.zone", "contested", {"republic": 10, "hutt": 5}, {"republic": 10, "hutt": 5})  # re-seed on boot
	booted.apply_persisted(blob)
	_assert_equal(booted.to_dict(), blob, "F58: re-seed + apply_persisted reproduces the exact saved world state")
	_assert_equal(booted.tick_index, live.tick_index, "F58: tick_index restored across restart")
	_assert_equal(booted.zone_summary("persist.zone"), live.zone_summary("persist.zone"), "F58: zone summary (influence + recomputed alert/security + events) matches after restore")
	# Defensive: a blob zone absent from the roster is ignored; a seeded zone absent from the blob keeps its seed.
	var partial: ZoneState = ZoneState.new()
	partial.add_zone("other.zone", "secured", {"republic": 20})
	partial.apply_persisted(blob)  # blob has persist.zone (not seeded here) -> ignored, no crash
	_assert_equal(int(partial.get_zone("other.zone").get("influence", {}).get("republic", -1)), 20, "F58: a zone absent from the blob keeps its seed")
	_assert_true(not partial.has_zone("persist.zone"), "F58: a blob zone absent from the roster is not added")

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
