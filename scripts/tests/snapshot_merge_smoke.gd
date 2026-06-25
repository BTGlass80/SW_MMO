extends SceneTree
## Smoke test for the _build_snapshot zone-merge shape.
##
## Replicates what network_manager.gd:_build_snapshot() does:
##   snap = state.snapshot()
##   snap["zone"] = zones.zone_summary(CURRENT_ZONE)
##   return snap
##
## Asserts the merged dict has all WorldState player/world keys AND a "zone" key
## carrying the full ZoneState.zone_summary() shape. The test FAILS if "zone" is
## missing, empty, or lacks any of the expected per-zone keys.

const WorldState = preload("res://scripts/net/world_state.gd")
const ZoneState  = preload("res://scripts/net/zone_state.gd")

## Mirrors network_manager.gd CURRENT_ZONE constant exactly.
const CURRENT_ZONE := "tatooine.mos_eisley.spaceport"

var _failures: Array[String] = []

func _init() -> void:
	# --- Build WorldState: register a player and tick once ---
	var state: WorldState = WorldState.new()
	state.add_player(1, "Obi-Wan")
	state.set_input(1, Vector2(0.0, -1.0), 0.0, false)
	state.tick(1.0 / 20.0)   # one 20 Hz server tick

	# --- Build ZoneState exactly as network_manager start_server() does ---
	var zones: ZoneState = ZoneState.new()
	zones.add_zone(
		CURRENT_ZONE,
		"secured",
		{"republic": 55, "cis": 5, "hutt": 42, "independent": 25},
		{"republic": 50, "cis": 5, "hutt": 40, "independent": 25},
		"Mos Eisley Spaceport District"
	)

	# --- Replicate _build_snapshot() merge ---
	var snap: Dictionary = state.snapshot()
	_assert_true(not snap.has("zone"), "WorldState snapshot does not pre-populate zone key")
	var zone_summary: Dictionary = zones.zone_summary(CURRENT_ZONE)
	snap["zone"] = zone_summary

	# --- WorldState fields must survive the merge ---
	_assert_true(snap.has("tick"), "merged snapshot has 'tick'")
	_assert_true(snap.has("players"), "merged snapshot has 'players'")
	_assert_equal(int(snap.get("tick", -1)), 1, "tick index advanced to 1 after one tick")
	var players: Array = snap.get("players", [])
	_assert_equal(players.size(), 1, "one player in merged snapshot")
	var player_entry: Dictionary = players[0] as Dictionary
	for key in ["id", "name", "pos", "yaw"]:
		_assert_true(player_entry.has(key), "player entry has '%s'" % key)
	_assert_equal(int(player_entry.get("id", -1)), 1, "player id is 1")
	_assert_equal(String(player_entry.get("name", "")), "Obi-Wan", "player name survived merge")

	# --- Zone key must be present and non-empty ---
	_assert_true(snap.has("zone"), "merged snapshot has 'zone' key")
	var zone: Dictionary = snap.get("zone", {}) as Dictionary
	_assert_true(not zone.is_empty(), "zone dict is non-empty")

	# --- Zone summary keys (all returned by ZoneState.zone_summary()) ---
	for key in ["zone_id", "display_name", "alert_level", "effective_security",
				"security_base", "influence", "event", "event_type", "tick"]:
		_assert_true(zone.has(key), "zone dict has key '%s'" % key)

	# --- Zone field values match what we added ---
	_assert_equal(String(zone.get("zone_id", "")), CURRENT_ZONE, "zone_id matches CURRENT_ZONE")
	_assert_equal(String(zone.get("display_name", "")), "Mos Eisley Spaceport District", "display_name correct")
	_assert_equal(String(zone.get("security_base", "")), "secured", "security_base is secured")

	# effective_security: hutt=42 < 80 (HUTT_SURGE_DOWNGRADE_AT), no active events,
	# so overlay is null and effective_security equals security_base "secured".
	_assert_equal(String(zone.get("effective_security", "")), "secured", "effective_security matches base (no Hutt surge)")

	# alert_level: republic=55 >= HIGH_ALERT_REPUBLIC(50) but <LOCKDOWN(70), hutt=42 <70,
	# cis=5 <40, so alert is "high_alert".
	_assert_equal(String(zone.get("alert_level", "")), "high_alert", "alert_level is high_alert for rep=55")

	# influence dict must carry all four factions with clamped values from add_zone()
	var influence: Dictionary = zone.get("influence", {}) as Dictionary
	_assert_true(influence.has("republic"),     "influence has republic")
	_assert_true(influence.has("cis"),          "influence has cis")
	_assert_true(influence.has("hutt"),         "influence has hutt")
	_assert_true(influence.has("independent"),  "influence has independent")
	_assert_equal(int(influence.get("republic", -1)), 55,  "republic influence is 55")
	_assert_equal(int(influence.get("hutt",    -1)), 42,  "hutt influence is 42")
	_assert_equal(int(influence.get("cis",     -1)),  5,  "cis influence is 5")
	_assert_equal(int(influence.get("independent", -1)), 25, "independent influence is 25")

	# event and event_type are strings (may be "" when no event fired at tick 0)
	_assert_true(typeof(zone.get("event", "")) == TYPE_STRING, "event is a String")
	_assert_true(typeof(zone.get("event_type", "")) == TYPE_STRING, "event_type is a String")

	# zone tick is 0 (add_zone fires before any director_tick)
	_assert_equal(int(zone.get("tick", -1)), 0, "zone tick is 0 at add_zone time")

	# --- Mutating the returned summary does not corrupt ZoneState's internal copy ---
	zone["alert_level"] = "TAMPERED"
	var fresh_summary: Dictionary = zones.zone_summary(CURRENT_ZONE)
	_assert_equal(String(fresh_summary.get("alert_level", "")), "high_alert", "zone_summary returns independent copy")

	# --- Empty zone_id returns an empty dict (no crash) ---
	var missing: Dictionary = zones.zone_summary("does_not_exist")
	_assert_true(missing.is_empty(), "zone_summary returns empty dict for unknown zone_id")

	# --- After a director_tick the tick counter advances and influence decays toward baseline ---
	zones.director_tick()
	var after_tick: Dictionary = zones.zone_summary(CURRENT_ZONE)
	_assert_equal(int(after_tick.get("tick", -1)), 1, "zone tick advances to 1 after director_tick")
	# republic 55 > baseline 50 -> decays by 1 to 54
	var after_inf: Dictionary = after_tick.get("influence", {}) as Dictionary
	_assert_equal(int(after_inf.get("republic", -1)), 54, "republic influence decays toward baseline after tick")
	# hutt 42 > baseline 40 -> decays by 1 to 41
	_assert_equal(int(after_inf.get("hutt", -1)), 41, "hutt influence decays toward baseline after tick")

	# After decay: republic=54 still >= 50 HIGH_ALERT_REPUBLIC, still "high_alert"
	_assert_equal(String(after_tick.get("alert_level", "")), "high_alert", "alert_level still high_alert after one decay tick")

	# --- Zone key absent means zone is empty: guard against missing key ---
	var no_zone_snap: Dictionary = state.snapshot()
	# no_zone_snap has no "zone" key — clients must tolerate this for solo/offline mode
	_assert_true(not no_zone_snap.has("zone"), "raw WorldState snapshot has no zone key (solo-mode safe)")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("snapshot_merge_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true, got false" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
