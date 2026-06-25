extends SceneTree
## Headless smoke test: JSON wire round-trip fidelity for RPC payloads.
##
## Mirrors the pattern used by Godot RPCs: data crosses the wire as a serialised
## Dictionary.  We proxy that with JSON.stringify -> JSON.parse_string (which is
## structurally identical to what var_to_str / str_to_var does for plain dicts of
## primitives).  The test is a REGRESSION GUARD: it must FAIL if any field the
## client reads is dropped, renamed, or silently type-changed in a way the client
## does not expect.
##
## Two payloads are exercised:
##   1. A combat exchange envelope built by CombatEventEnvelopeModel — all fields
##      are primitives / nested dicts of primitives, so a perfect round-trip is
##      guaranteed and asserted.
##   2. A WorldState snapshot — primitive fields (tick, id, name, yaw) round-trip
##      cleanly.  The 'pos' field is a Vector3; JSON.stringify converts it to a
##      string such as "(x, y, z)".  The test asserts the STRING form contains the
##      coordinate data so the client can parse it — this documents the real
##      behaviour and will break if the field is dropped entirely.

const CombatEventEnvelopeModel = preload("res://scripts/rules/combat_event_envelope_model.gd")
const WorldState = preload("res://scripts/net/world_state.gd")

var _failures: Array[String] = []

func _init() -> void:
	_test_envelope_round_trip()
	_test_snapshot_round_trip()
	_finish()

# ---------------------------------------------------------------------------
# 1. Combat exchange envelope – all primitives, perfect round-trip expected.
# ---------------------------------------------------------------------------
func _test_envelope_round_trip() -> void:
	# Build a representative result dict (mirrors combat_event_envelope_model_smoke.gd)
	var result = {
		"round": 3,
		"exchange_seed": 98765,
		"action_window": {
			"ready": true,
			"phase": "resolution",
			"window": 3,
			"active_ids": ["pilot_a", "b1_droid"],
			"declaration_count": 2,
			"errors": [],
		},
		"events": [
			{"type": "player_attack", "exchange_seed": 98765},
			{"type": "target_damage", "exchange_seed": 98765},
		],
		"state": {
			"round": 4,
			"player_wound_severity": 0,
			"player_character_points": 7,
			"player_force_points": 2,
		},
		"target_state": {"wound_severity": 1},
		"encounter_state": {
			"kind": "ground_assault",
			"tick_index": 12,
			"live_enabled": true,
			"current": {"armed": 3, "ready": 2, "covered": 1},
			"next": {"armed": 3, "ready": 1, "covered": 2},
		},
		"target_disabled": false,
		"force_point_spent": true,
		"already_disabled": false,
		"player_attack_skipped": false,
	}

	var envelope = CombatEventEnvelopeModel.envelope_for_result(result, "ground_range_shot", "zone_a")

	# Perform the JSON round-trip.
	var json_str = JSON.stringify(envelope)
	var rt = JSON.parse_string(json_str)

	_assert_true(rt != null, "envelope: JSON.parse_string returns non-null")
	_assert_true(typeof(rt) == TYPE_DICTIONARY, "envelope: round-trip is a Dictionary")

	# --- Top-level scalar fields ---
	# version is int 1 in the model; JSON may return float so the client uses int().
	_assert_equal(int(rt.get("version", -1)), CombatEventEnvelopeModel.ENVELOPE_VERSION,
		"envelope rt: version int")
	_assert_equal(String(rt.get("message_type", "")), CombatEventEnvelopeModel.MESSAGE_TYPE,
		"envelope rt: message_type string")
	_assert_equal(String(rt.get("channel", "")), "zone_a",
		"envelope rt: channel string")
	_assert_equal(String(rt.get("exchange_kind", "")), "ground_range_shot",
		"envelope rt: exchange_kind string")
	_assert_equal(int(rt.get("round", -1)), 3,
		"envelope rt: round int")
	_assert_equal(int(rt.get("exchange_seed", -1)), 98765,
		"envelope rt: exchange_seed int")
	_assert_equal(bool(rt.get("valid", false)), true,
		"envelope rt: valid bool")
	_assert_equal(bool(rt.get("invalid_action_window", true)), false,
		"envelope rt: invalid_action_window bool")
	_assert_equal(int(rt.get("event_count", -1)), 2,
		"envelope rt: event_count int")

	# --- event_types array ---
	var et = rt.get("event_types", [])
	_assert_true(typeof(et) == TYPE_ARRAY, "envelope rt: event_types is Array")
	_assert_equal((et as Array).size(), 2, "envelope rt: event_types has 2 entries")
	_assert_equal(String((et as Array)[0]), "player_attack", "envelope rt: event_types[0] string")
	_assert_equal(String((et as Array)[1]), "target_damage", "envelope rt: event_types[1] string")

	# --- action_window sub-dict ---
	var aw = rt.get("action_window", {})
	_assert_true(typeof(aw) == TYPE_DICTIONARY, "envelope rt: action_window is Dictionary")
	_assert_equal(bool((aw as Dictionary).get("present", false)), true,
		"envelope rt: action_window.present bool")
	_assert_equal(bool((aw as Dictionary).get("ready", false)), true,
		"envelope rt: action_window.ready bool")
	_assert_equal(String((aw as Dictionary).get("phase", "")), "resolution",
		"envelope rt: action_window.phase string")
	_assert_equal(int((aw as Dictionary).get("window", -1)), 3,
		"envelope rt: action_window.window int")
	_assert_equal(int((aw as Dictionary).get("declaration_count", -1)), 2,
		"envelope rt: action_window.declaration_count int")
	var ai = (aw as Dictionary).get("active_ids", [])
	_assert_true(typeof(ai) == TYPE_ARRAY, "envelope rt: active_ids is Array")
	_assert_equal((ai as Array).size(), 2, "envelope rt: active_ids length")
	_assert_equal(String((ai as Array)[0]), "pilot_a", "envelope rt: active_ids[0]")
	var ae = (aw as Dictionary).get("errors", null)
	_assert_true(ae != null and typeof(ae) == TYPE_ARRAY, "envelope rt: action_window.errors is Array")
	_assert_equal((ae as Array).size(), 0, "envelope rt: no errors")

	# --- state_delta sub-dict ---
	var sd = rt.get("state_delta", {})
	_assert_true(typeof(sd) == TYPE_DICTIONARY, "envelope rt: state_delta is Dictionary")
	_assert_equal(int((sd as Dictionary).get("next_round", -1)), 4,
		"envelope rt: state_delta.next_round int")
	_assert_equal(int((sd as Dictionary).get("player_wound_severity", -1)), 0,
		"envelope rt: state_delta.player_wound_severity int")
	_assert_equal(int((sd as Dictionary).get("target_wound_severity", -999)), 1,
		"envelope rt: state_delta.target_wound_severity int")
	_assert_equal(int((sd as Dictionary).get("player_character_points", -1)), 7,
		"envelope rt: state_delta.player_character_points int")
	_assert_equal(int((sd as Dictionary).get("player_force_points", -1)), 2,
		"envelope rt: state_delta.player_force_points int")

	# --- encounter_state sub-dict ---
	var es = rt.get("encounter_state", {})
	_assert_true(typeof(es) == TYPE_DICTIONARY, "envelope rt: encounter_state is Dictionary")
	_assert_equal(bool((es as Dictionary).get("present", false)), true,
		"envelope rt: encounter_state.present bool")
	_assert_equal(String((es as Dictionary).get("kind", "")), "ground_assault",
		"envelope rt: encounter_state.kind string")
	_assert_equal(int((es as Dictionary).get("tick_index", -1)), 12,
		"envelope rt: encounter_state.tick_index int")
	_assert_equal(bool((es as Dictionary).get("live_enabled", false)), true,
		"envelope rt: encounter_state.live_enabled bool")
	var ec = (es as Dictionary).get("current", {})
	_assert_true(typeof(ec) == TYPE_DICTIONARY, "envelope rt: encounter_state.current is Dictionary")
	_assert_equal(int((ec as Dictionary).get("ready", -1)), 2,
		"envelope rt: encounter_state.current.ready int")
	var en = (es as Dictionary).get("next", {})
	_assert_equal(int((en as Dictionary).get("covered", -1)), 2,
		"envelope rt: encounter_state.next.covered int")

	# --- flags sub-dict ---
	var fl = rt.get("flags", {})
	_assert_true(typeof(fl) == TYPE_DICTIONARY, "envelope rt: flags is Dictionary")
	_assert_equal(bool((fl as Dictionary).get("already_disabled", true)), false,
		"envelope rt: flags.already_disabled bool")
	_assert_equal(bool((fl as Dictionary).get("target_disabled", true)), false,
		"envelope rt: flags.target_disabled bool")
	_assert_equal(bool((fl as Dictionary).get("player_attack_skipped", true)), false,
		"envelope rt: flags.player_attack_skipped bool")
	_assert_equal(bool((fl as Dictionary).get("force_point_spent", false)), true,
		"envelope rt: flags.force_point_spent bool")

	# --- events array survives (client reads it) ---
	var evts = rt.get("events", null)
	_assert_true(evts != null and typeof(evts) == TYPE_ARRAY, "envelope rt: events is Array")
	_assert_equal((evts as Array).size(), 2, "envelope rt: events length preserved")

	# --- Verify no top-level key was silently dropped ---
	for key in ["version", "message_type", "channel", "exchange_kind", "round",
				"exchange_seed", "valid", "invalid_action_window", "action_window",
				"events", "event_count", "event_types", "state_delta",
				"encounter_state", "flags"]:
		_assert_true(rt.has(key), "envelope rt: top-level key '%s' present" % key)

# ---------------------------------------------------------------------------
# 2. WorldState snapshot – primitive fields + pos string form.
# ---------------------------------------------------------------------------
func _test_snapshot_round_trip() -> void:
	var state = WorldState.new()

	# Seed is irrelevant here (no randomness in snapshot construction), but we
	# add two deterministic players so the snapshot has real content.
	state.add_player(10, "Ahsoka")
	state.add_player(11, "Rex")

	# Give player 10 a non-spawn position by applying a seeded tick.
	state.set_input(10, Vector2(0.0, -1.0), 0.785)  # 45-degree heading, forward
	state.tick(1.0)  # advance 1 second

	var snap = state.snapshot()

	# Perform the JSON round-trip.
	var json_str = JSON.stringify(snap)
	var rt = JSON.parse_string(json_str)

	_assert_true(rt != null, "snapshot: JSON.parse_string returns non-null")
	_assert_true(typeof(rt) == TYPE_DICTIONARY, "snapshot: round-trip is a Dictionary")

	# --- Top-level keys present ---
	_assert_true(rt.has("tick"), "snapshot rt: 'tick' key present")
	_assert_true(rt.has("players"), "snapshot rt: 'players' key present")

	# tick advances; the state ran 1 tick.
	_assert_equal(int(rt.get("tick", -1)), 1, "snapshot rt: tick int = 1 after one tick")

	# --- players array ---
	var players_rt = rt.get("players", null)
	_assert_true(players_rt != null and typeof(players_rt) == TYPE_ARRAY,
		"snapshot rt: players is Array")
	_assert_equal((players_rt as Array).size(), 2, "snapshot rt: two players in snapshot")

	# Find each player by id in the round-tripped array.
	var p10 = {}
	var p11 = {}
	for entry in (players_rt as Array):
		if typeof(entry) == TYPE_DICTIONARY:
			var eid = int((entry as Dictionary).get("id", -1))
			if eid == 10:
				p10 = entry
			elif eid == 11:
				p11 = entry

	_assert_true(not p10.is_empty(), "snapshot rt: player 10 entry found")
	_assert_true(not p11.is_empty(), "snapshot rt: player 11 entry found")

	# id survives as int-coercible.
	_assert_equal(int(p10.get("id", -1)), 10, "snapshot rt: player 10 id int")
	_assert_equal(int(p11.get("id", -1)), 11, "snapshot rt: player 11 id int")

	# name survives as string.
	_assert_equal(String(p10.get("name", "")), "Ahsoka", "snapshot rt: player 10 name string")
	_assert_equal(String(p11.get("name", "")), "Rex", "snapshot rt: player 11 name string")

	# yaw survives as float-coercible.
	# Player 10 was given yaw 0.785; player 11 has default yaw 0.0.
	_assert_true(p11.has("yaw"), "snapshot rt: player 11 has yaw key")
	_assert_approx(float(p11.get("yaw", -99.0)), 0.0, "snapshot rt: player 11 yaw ~0.0")
	_assert_true(p10.has("yaw"), "snapshot rt: player 10 has yaw key")
	_assert_approx(float(p10.get("yaw", -99.0)), 0.785, "snapshot rt: player 10 yaw ~0.785")

	# pos: Vector3 is not JSON-native — JSON.stringify converts it to a string.
	# The client must know this and parse it.  Assert the key is present and that
	# the string form contains the expected coordinate data.
	_assert_true(p10.has("pos"), "snapshot rt: player 10 has pos key")
	_assert_true(p11.has("pos"), "snapshot rt: player 11 has pos key")

	# Player 11 (idle) stayed at SPAWN_POINT, y = GROUND_Y = 1.2.
	# The string form from Godot JSON.stringify for a Vector3(x, y, z) is
	# the native GDScript string representation: "(x, y, z)".
	var p11_pos_str = String(p11.get("pos", ""))
	_assert_true(p11_pos_str.length() > 0, "snapshot rt: player 11 pos string non-empty")
	# y coordinate is 1.2 (GROUND_Y) — assert the string encodes it.
	_assert_true(p11_pos_str.contains("1.2"), "snapshot rt: player 11 pos string encodes GROUND_Y 1.2")

	# Player 10 moved along -Z for 1 s at MOVE_SPEED (6.5).
	# Expected z ≈ SPAWN_POINT.z - 6.5 = -6.0 - 6.5 = -12.5
	# (yaw = 0.785 rad ≈ 45°, so movement spreads across X and Z, but
	#  we only verify y=1.2 appears in the pos string as a regression guard.)
	var p10_pos_str = String(p10.get("pos", ""))
	_assert_true(p10_pos_str.length() > 0, "snapshot rt: player 10 pos string non-empty")
	_assert_true(p10_pos_str.contains("1.2"), "snapshot rt: player 10 pos string encodes GROUND_Y 1.2")

	# Confirm every per-player key the client accesses is present.
	for key in ["id", "name", "pos", "yaw"]:
		_assert_true(p10.has(key), "snapshot rt: player 10 has '%s' key" % key)
		_assert_true(p11.has(key), "snapshot rt: player 11 has '%s' key" % key)

	# WorldState extends RefCounted — no .free() needed; it is reference-counted.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _finish() -> void:
	if _failures.is_empty():
		print("wire_roundtrip_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true, got false" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_approx(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.001:
		_failures.append("%s: expected ~%f, got %f" % [label, expected, actual])
