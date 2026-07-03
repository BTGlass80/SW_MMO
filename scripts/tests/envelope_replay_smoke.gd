extends SceneTree
## PT1 replay prep: generate a seeded exchange purely, build its envelope, attach replay_inputs,
## JSON-round-trip it (the real storage path), and assert the replay model REPRODUCES the recorded
## outcome exactly — plus tamper tests (a mutated recorded field must surface as a mismatch) and
## the PARTIAL mode contract for today's producer envelopes (no replay_inputs attached yet).

const CombatEventEnvelopeModel = preload("res://scripts/rules/combat_event_envelope_model.gd")
const EnvelopeReplayModel = preload("res://scripts/rules/envelope_replay_model.gd")

const EXCHANGE_SEED := 20260703

var _failures: Array[String] = []

func _init() -> void:
	var rules: Node = (load("res://scripts/rules/d6_rules.gd") as GDScript).new()
	var ground: RefCounted = (load("res://scripts/rules/ground_combat_model.gd") as GDScript).new()

	# A seeded exchange with some texture: one aim, one queued attack CP, an armored target.
	var state: Dictionary = ground.add_aim(ground.initial_state())
	state = ground.queue_attack_cp(state, 1)
	var target_state := {"wound_severity": 0}
	var pools := _pools()
	var result: Dictionary = ground.resolve_exchange(rules, state, target_state, pools, 9.0, 1, EXCHANGE_SEED)
	_assert(int(result.get("exchange_seed", -1)) == EXCHANGE_SEED, "exchange keeps its seed")
	_assert((result.get("events", []) as Array).size() >= 2, "exchange produced events")

	var envelope: Dictionary = CombatEventEnvelopeModel.envelope_for_result(result, "ground_range", "test")
	var with_inputs: Dictionary = CombatEventEnvelopeModel.attach_replay_inputs(envelope, state, target_state, pools, 9.0, 1)

	# attach_replay_inputs is ADDITIVE: every pre-existing envelope field stays byte-identical.
	var stripped: Dictionary = with_inputs.duplicate(true)
	stripped.erase("replay_inputs")
	_assert(stripped == envelope, "attach_replay_inputs leaves existing envelope fields byte-identical")
	_assert(CombatEventEnvelopeModel.has_replay_inputs(with_inputs), "has_replay_inputs true after attach")
	_assert(not CombatEventEnvelopeModel.has_replay_inputs(envelope), "has_replay_inputs false without the block")

	# FULL replay across a JSON round-trip (the storage/paste path) must REPRODUCE the record.
	var stored: Dictionary = JSON.parse_string(JSON.stringify(with_inputs))
	var report: Dictionary = EnvelopeReplayModel.replay(rules, stored)
	_assert(String(report["mode"]) == EnvelopeReplayModel.MODE_FULL, "replay_inputs envelope replays in FULL mode")
	_assert(bool(report["match"]), "FULL replay reproduces the recorded outcome (mismatches: %s)" % str(report["mismatches"]))
	_assert((report["lines"] as Array).size() > 0, "FULL replay emits a readable report")

	# Tamper 1: a recorded EVENT field (the player_attack roll total) -> mismatch, named in the diff.
	var tampered: Dictionary = JSON.parse_string(JSON.stringify(with_inputs))
	var tampered_events: Array = tampered["events"]
	(tampered_events[0] as Dictionary)["attack_total"] = float((tampered_events[0] as Dictionary).get("attack_total", 0)) + 3.0
	var tamper_report: Dictionary = EnvelopeReplayModel.replay(rules, tampered)
	_assert(not bool(tamper_report["match"]), "tampered event field is caught")
	_assert(_mismatch_mentions(tamper_report, "attack_total"), "tamper diff names the mutated field (got: %s)" % str(tamper_report["mismatches"]))

	# Tamper 2: a recorded state_delta field -> mismatch.
	var tampered2: Dictionary = JSON.parse_string(JSON.stringify(with_inputs))
	(tampered2["state_delta"] as Dictionary)["player_wound_severity"] = 5.0
	var tamper2_report: Dictionary = EnvelopeReplayModel.replay(rules, tampered2)
	_assert(not bool(tamper2_report["match"]), "tampered state_delta is caught")
	_assert(_mismatch_mentions(tamper2_report, "state_delta.player_wound_severity"), "state_delta diff names the path")

	# PARTIAL mode: today's live envelope (no replay_inputs) round-tripped -> consistent, mode partial.
	var bare: Dictionary = JSON.parse_string(JSON.stringify(envelope))
	var partial_report: Dictionary = EnvelopeReplayModel.replay(rules, bare)
	_assert(String(partial_report["mode"]) == EnvelopeReplayModel.MODE_PARTIAL, "no replay_inputs -> PARTIAL mode")
	_assert(bool(partial_report["match"]), "PARTIAL replay passes on an untampered envelope (mismatches: %s)" % str(partial_report["mismatches"]))

	# PARTIAL tamper: derived event_count no longer matches the recorded events -> mismatch.
	var bare_tampered: Dictionary = JSON.parse_string(JSON.stringify(envelope))
	bare_tampered["event_count"] = float(int(bare_tampered.get("event_count", 0)) + 1)
	var partial_tamper: Dictionary = EnvelopeReplayModel.replay(rules, bare_tampered)
	_assert(not bool(partial_tamper["match"]), "PARTIAL mode catches a tampered event_count")

	# FULL replay also holds through the action-window wrapper (the live resolve_window shape).
	var window := {"ready": true, "phase": "resolution", "window": 3, "active_ids": ["1"], "declaration_count": 1, "errors": []}
	var aw_result: Dictionary = ground.resolve_exchange_with_action_window(rules, state, target_state, pools, 9.0, 1, window, EXCHANGE_SEED + 7919)
	var aw_envelope: Dictionary = CombatEventEnvelopeModel.envelope_for_result(aw_result, "ground_range", "local")
	aw_envelope = CombatEventEnvelopeModel.attach_replay_inputs(aw_envelope, state, target_state, pools, 9.0, 1, "none", window)
	var aw_report: Dictionary = EnvelopeReplayModel.replay(rules, JSON.parse_string(JSON.stringify(aw_envelope)))
	_assert(String(aw_report["mode"]) == EnvelopeReplayModel.MODE_FULL, "action-window envelope replays in FULL mode")
	_assert(bool(aw_report["match"]), "action-window FULL replay reproduces the record (mismatches: %s)" % str(aw_report["mismatches"]))

	rules.free()
	_finish()

func _mismatch_mentions(report: Dictionary, needle: String) -> bool:
	for entry in (report["mismatches"] as Array):
		if String(entry).contains(needle):
			return true
	return false

func _pools() -> Dictionary:
	return {
		"attacker_pool": {"dice": 5, "pips": 1},
		"damage_pool": {"dice": 4, "pips": 0},
		"player_dodge_pool": {"dice": 4, "pips": 0},
		"player_soak_pool": {"dice": 3, "pips": 0},
		"target_attack_pool": {"dice": 3, "pips": 0},
		"target_soak_pool": {"dice": 2, "pips": 0},
		"target_armor": {
			"protection_physical": "1D",
			"protection_energy": "0D+1",
			"dexterity_penalty": "-1D",
			"coverage": ["torso"],
		},
	}

func _finish() -> void:
	if _failures.is_empty():
		print("envelope_replay_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert(condition: bool, label: String) -> void:
	if not condition:
		_failures.append("envelope_replay_smoke FAIL: %s" % label)
