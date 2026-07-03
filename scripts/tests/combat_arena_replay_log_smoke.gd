extends SceneTree
## PT1 replay — SERVER-SIDE replay-inputs attach (the HOT follow-up). combat_arena now returns, alongside
## the CLEAN broadcast `envelopes`, a parallel `replay_envelopes` array: a per-shot COPY enriched with
## combat_event_envelope_model.attach_replay_inputs[_incoming] (BOTH sheets' pools + pre-exchange state).
## The net layer broadcasts the clean copy via apply_combat_envelope and writes the enriched copy to a
## dedicated server-side JSONL (envelopes.jsonl) for dispute replay.
##
## CRITICAL INVARIANT proved here: the replay_inputs block (both sheets' pools) must NEVER ride the RPC
## payload. So for BOTH producer sites (resolve_window exchange @ ~504 + resolve_hostile_aggression
## incoming-fire @ ~601):
##   (1) the broadcast envelope has NO "replay_inputs" key;
##   (2) the logged COPY has_replay_inputs == true;
##   (3) stripping replay_inputs off the copy is BYTE-IDENTICAL to the broadcast envelope (the copy adds
##       exactly one key — the broadcast bytes are unchanged);
##   (4) the logged copy actually REPLAYS in FULL mode (exchange re-runs resolve_exchange; incoming re-runs
##       resolve_incoming_fire_window) and reproduces the recorded outcome — the whole point of the log.
##
## Pure / deterministic: server-owned SEEDED rng; no nodes, sockets, RNG-in-model, or randomize().

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const HostileNpc := preload("res://scripts/rules/hostile_npc_model.gd")
const CombatEventEnvelopeModel := preload("res://scripts/rules/combat_event_envelope_model.gd")
const EnvelopeReplayModel := preload("res://scripts/rules/envelope_replay_model.gd")

var _failures: Array[String] = []
var _rules: Object

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	var data := _combat_data()

	# A strong lethal hostile so a single provoked window produces a resolved envelope with damage texture.
	var krayt := {
		"hostile": true, "scale": "creature", "pack_size": 1,
		"char_sheet": {"attributes": {"strength": "6D"}, "skills": {"melee_combat": "6D"}},
		"natural_attack": {"to_hit_skill": "melee_combat", "damage": "STR+3D"},
	}
	var krayt_pools: Dictionary = HostileNpc.attack_pools_from_creature(_rules, krayt)

	# --- SITE 1: resolve_window (EXCHANGE path). A shooter fires at the hostile; the window returns a clean
	#     broadcast envelope + an enriched replay copy. ---
	var arena := CombatArena.new(_rules, data, "b1_training_silhouette", {"heavy_blaster": {"damage": "7D", "skill": "blaster"}}, {})
	arena.register_hostile_target("z", krayt_pools, {"distance": 6.0, "cover_level": 0, "name": "Krayt Dragon"}, krayt)
	arena.register_player(1, "Shooter", {"attributes": {"dexterity": "4D", "strength": "3D"}, "skills": {"blaster": "3D"}, "equipment": {"weapon": "heavy_blaster"}})
	arena.set_player_target(1, "z")
	arena.set_player_lethal(1, true)
	arena.submit_fire_intent(1, {"aim": 3})
	var wres: Dictionary = arena.resolve_window(770077)
	var w_env: Array = wres.get("envelopes", [])
	var w_rep: Array = wres.get("replay_envelopes", [])
	_assert_true(w_env.size() >= 1, "resolve_window produced a broadcast envelope")
	_assert_equal(w_rep.size(), w_env.size(), "replay_envelopes is parallel to envelopes (one per shot)")
	_check_pair(w_env[0], w_rep[0], "resolve_window (exchange)")
	# The exchange copy replays in FULL and reproduces (JSON round-trip = the real storage path).
	_assert_full_reproduces(w_rep[0], EnvelopeReplayModel.MODE_FULL, "resolve_window exchange")

	# --- SITE 2: resolve_hostile_aggression (INCOMING-FIRE path). An idle victim takes unprovoked fire; the
	#     enriched copy carries a kind=incoming_fire block that re-runs resolve_incoming_fire_window. ---
	var arena2 := CombatArena.new(_rules, data)
	arena2.register_hostile_target("z", krayt_pools, {"distance": 6.0, "cover_level": 0, "name": "Krayt Dragon"}, krayt)
	arena2.register_player(2, "Idle Bot", {"attributes": {"dexterity": "3D", "strength": "1D"}, "skills": {}})
	var hres: Dictionary = arena2.resolve_hostile_aggression("z", [2], 880088)
	var h_env: Array = hres.get("envelopes", [])
	var h_rep: Array = hres.get("replay_envelopes", [])
	_assert_true(h_env.size() >= 1, "resolve_hostile_aggression produced a broadcast envelope")
	_assert_equal(h_rep.size(), h_env.size(), "hostile-aggression replay_envelopes is parallel to envelopes")
	_check_pair(h_env[0], h_rep[0], "resolve_hostile_aggression (incoming_fire)")
	_assert_equal(String((((h_rep[0] as Dictionary).get("replay_inputs", {})) as Dictionary).get("kind", "")),
		CombatEventEnvelopeModel.REPLAY_KIND_INCOMING, "the incoming-fire copy is marked kind=incoming_fire")
	# The incoming-fire copy replays in FULL (via resolve_incoming_fire_window) and reproduces.
	_assert_full_reproduces(h_rep[0], EnvelopeReplayModel.MODE_FULL, "resolve_hostile_aggression incoming")

	if _rules.has_method("free"):
		_rules.free()
	_finish()

# Assert the broadcast/log invariant for one (broadcast, replay-copy) pair.
func _check_pair(broadcast: Variant, copy: Variant, label: String) -> void:
	var b: Dictionary = broadcast
	var c: Dictionary = copy
	_assert_true(not b.has("replay_inputs"), "%s: broadcast envelope has NO replay_inputs (the RPC payload never carries both sheets' pools)" % label)
	_assert_true(CombatEventEnvelopeModel.has_replay_inputs(c), "%s: the logged COPY has_replay_inputs" % label)
	var stripped: Dictionary = c.duplicate(true)
	stripped.erase("replay_inputs")
	_assert_true(stripped == b, "%s: stripping replay_inputs off the copy is BYTE-IDENTICAL to the broadcast envelope (adds exactly one key)" % label)

# Assert a replay-enriched envelope reproduces in the expected mode after a JSON round-trip (storage path).
func _assert_full_reproduces(copy: Variant, expected_mode: String, label: String) -> void:
	var stored: Dictionary = JSON.parse_string(JSON.stringify(copy))
	var report: Dictionary = EnvelopeReplayModel.replay(_rules, stored)
	_assert_equal(String(report.get("mode", "")), expected_mode, "%s: logged copy replays in %s mode" % [label, expected_mode])
	_assert_true(bool(report.get("match", false)), "%s: FULL replay REPRODUCES the recorded outcome (mismatches: %s)" % [label, str(report.get("mismatches", []))])

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {
			"blaster": "4D+1", "dodge": "4D", "soak": "3D",
			"weapon": "training_blaster", "armor": "blast_vest", "scale": "character",
		},
		"weapons": {
			"training_blaster": {"damage": "4D"},
			"remote_stun_blaster": {"damage": "3D+2"},
		},
		"armors": {
			"blast_vest": {"protection_energy": "0D+1", "protection_physical": "1D", "dexterity_penalty": "-1D", "coverage": ["torso"]},
		},
		"targets": {
			"b1_training_silhouette": {
				"blaster": "3D", "weapon": "remote_stun_blaster", "soak": "2D",
				"scale": "character", "distance": 12.0, "cover_level": 0, "name": "B1 Training Remote",
			},
		},
	}

func _finish() -> void:
	if _failures.is_empty():
		print("combat_arena_replay_log_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
