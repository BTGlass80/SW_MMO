extends RefCounted
## PT1 prep — combat-envelope REPLAY core (pure, headless-testable).
##
## The server owns ALL RNG: every exchange resolves from an explicit exchange_seed, and the
## broadcast envelope (combat_event_envelope_model.gd) records that seed plus the full event list.
## Given the OPTIONAL replay_inputs block (attach_replay_inputs — the exact pre-exchange
## state/target/pools/distance/cover/stance the producer passed in), seed+inputs fully determine
## the outcome, so the exchange can be RE-RUN and compared field-for-field against what was
## recorded — combat debugging + player-dispute resolution for free.
##
## Two modes:
##  - FULL   (replay_inputs present): re-run ground_combat_model.resolve_exchange[_with_action_window]
##    from the recorded seed+inputs, rebuild the envelope, and diff recomputed vs recorded
##    (events, state_delta, flags, ...). match=true iff the replay REPRODUCES the record.
##  - PARTIAL (today's live envelopes, no replay_inputs): verify everything that IS verifiable
##    from the envelope alone — derived-field consistency (event_count/event_types vs events),
##    seed lineage (every event carries the envelope's exchange_seed/round), and the
##    exchange_completed cross-checks against state_delta/flags.
##
## All comparisons are JSON-tolerant (a stored envelope round-trips ints to floats).
## Consumed by tools/envelope_replay.gd (CLI) and scripts/tests/envelope_replay_smoke.gd.

const GroundCombatModel = preload("res://scripts/rules/ground_combat_model.gd")
const CombatEventEnvelopeModel = preload("res://scripts/rules/combat_event_envelope_model.gd")

const MODE_FULL := "full"
const MODE_PARTIAL := "partial"

## Top-level envelope keys a FULL replay must reproduce (events are diffed separately,
## event-by-event, for the readable report).
const FULL_COMPARE_KEYS: Array[String] = [
	"exchange_seed", "round", "valid", "invalid_action_window",
	"event_count", "event_types", "state_delta", "flags",
]

## Per-event fields surfaced in the readable OK lines (diffs always show every differing field).
const EVENT_REPORT_FIELDS: Array[String] = [
	"success", "hit", "blocked", "attack_total", "difficulty", "margin",
	"damage_total", "soak_total", "wound_key", "wound_severity",
	"player_wound_severity", "target_disabled", "next_round",
]

## Replay a recorded envelope. `rules` is a D6 rules instance (scripts/rules/d6_rules.gd).
## Returns {mode, match: bool, mismatches: Array[String], lines: Array[String], recomputed: Dictionary}.
static func replay(rules: Object, envelope: Dictionary) -> Dictionary:
	if CombatEventEnvelopeModel.has_replay_inputs(envelope):
		var inputs: Dictionary = _dict(envelope.get("replay_inputs", {}))
		# Dispatch on the block's kind: incoming-fire windows re-run resolve_incoming_fire_window; every
		# other/legacy block (no kind, or "exchange") re-runs resolve_exchange as before.
		if String(inputs.get("kind", "")) == CombatEventEnvelopeModel.REPLAY_KIND_INCOMING:
			return _replay_full_incoming(rules, envelope)
		return _replay_full(rules, envelope)
	return _replay_partial(envelope)

static func _replay_full(rules: Object, envelope: Dictionary) -> Dictionary:
	var mismatches: Array[String] = []
	var lines: Array[String] = []
	var exchange_seed := int(envelope.get("exchange_seed", -1))
	if exchange_seed < 0:
		mismatches.append("exchange_seed: recorded=%d — unseeded exchange, not deterministically replayable" % exchange_seed)
		return {"mode": MODE_FULL, "match": false, "mismatches": mismatches, "lines": lines, "recomputed": {}}

	var inputs: Dictionary = envelope.get("replay_inputs", {})
	var state: Dictionary = _dict(inputs.get("state", {}))
	var target_state: Dictionary = _dict(inputs.get("target_state", {}))
	var pools: Dictionary = _dict(inputs.get("pools", {}))
	var distance := float(inputs.get("distance", 0.0))
	var cover := int(inputs.get("target_cover_level", 0))
	var stance := String(inputs.get("defender_defense_stance", GroundCombatModel.DEFENSE_NONE))
	var action_window: Dictionary = _dict(inputs.get("action_window", {}))

	var ground: RefCounted = GroundCombatModel.new()
	var result: Dictionary
	if action_window.is_empty():
		result = ground.resolve_exchange(rules, state, target_state, pools, distance, cover, exchange_seed, stance)
	else:
		result = ground.resolve_exchange_with_action_window(rules, state, target_state, pools, distance, cover, action_window, exchange_seed, stance)
	var recomputed: Dictionary = CombatEventEnvelopeModel.envelope_for_result(
		result,
		String(envelope.get("exchange_kind", "ground_range")),
		String(envelope.get("channel", "local"))
	)

	lines.append("mode=FULL seed=%d kind=%s: re-ran resolve_exchange%s from replay_inputs" % [
		exchange_seed,
		String(envelope.get("exchange_kind", "ground_range")),
		"" if action_window.is_empty() else "_with_action_window",
	])
	for key in FULL_COMPARE_KEYS:
		var field_diffs: Array[String] = []
		_diff(key, envelope.get(key), recomputed.get(key), field_diffs)
		if field_diffs.is_empty():
			lines.append("  %s: OK (%s)" % [key, _fmt(recomputed.get(key))])
		else:
			for d in field_diffs:
				lines.append("  DIFF %s" % d)
				mismatches.append(d)
	if not action_window.is_empty():
		var aw_diffs: Array[String] = []
		_diff("action_window", envelope.get("action_window"), recomputed.get("action_window"), aw_diffs)
		for d in aw_diffs:
			lines.append("  DIFF %s" % d)
			mismatches.append(d)

	_compare_events(_array(envelope.get("events", [])), _array(recomputed.get("events", [])), mismatches, lines)
	return {"mode": MODE_FULL, "match": mismatches.is_empty(), "mismatches": mismatches, "lines": lines, "recomputed": recomputed}

## FULL replay of an INCOMING-FIRE envelope (resolve_hostile_aggression / resolve_incoming_fire_window):
## re-run resolve_incoming_fire_window from the recorded seed + replay_inputs (state/pools/incoming),
## rebuild the envelope, and diff recomputed vs recorded exactly like the exchange path.
static func _replay_full_incoming(rules: Object, envelope: Dictionary) -> Dictionary:
	var mismatches: Array[String] = []
	var lines: Array[String] = []
	var exchange_seed := int(envelope.get("exchange_seed", -1))
	if exchange_seed < 0:
		mismatches.append("exchange_seed: recorded=%d — unseeded incoming-fire window, not deterministically replayable" % exchange_seed)
		return {"mode": MODE_FULL, "match": false, "mismatches": mismatches, "lines": lines, "recomputed": {}}

	var inputs: Dictionary = envelope.get("replay_inputs", {})
	var state: Dictionary = _dict(inputs.get("state", {}))
	var pools: Dictionary = _dict(inputs.get("pools", {}))
	var incoming: Array = _array(inputs.get("incoming", []))

	var ground: RefCounted = GroundCombatModel.new()
	var result: Dictionary = ground.resolve_incoming_fire_window(rules, state, pools, incoming, exchange_seed)
	var recomputed: Dictionary = CombatEventEnvelopeModel.envelope_for_result(
		result,
		String(envelope.get("exchange_kind", "ground_range")),
		String(envelope.get("channel", "local"))
	)

	lines.append("mode=FULL(incoming_fire) seed=%d: re-ran resolve_incoming_fire_window from replay_inputs (%d incoming)" % [exchange_seed, incoming.size()])
	for key in FULL_COMPARE_KEYS:
		var field_diffs: Array[String] = []
		_diff(key, envelope.get(key), recomputed.get(key), field_diffs)
		if field_diffs.is_empty():
			lines.append("  %s: OK (%s)" % [key, _fmt(recomputed.get(key))])
		else:
			for d in field_diffs:
				lines.append("  DIFF %s" % d)
				mismatches.append(d)

	_compare_events(_array(envelope.get("events", [])), _array(recomputed.get("events", [])), mismatches, lines)
	return {"mode": MODE_FULL, "match": mismatches.is_empty(), "mismatches": mismatches, "lines": lines, "recomputed": recomputed}

## Event-by-event readable comparison: recomputed vs recorded.
static func _compare_events(recorded: Array, recomputed: Array, mismatches: Array[String], lines: Array[String]) -> void:
	if recorded.size() != recomputed.size():
		var d := "events.size: recorded=%d recomputed=%d" % [recorded.size(), recomputed.size()]
		mismatches.append(d)
		lines.append("  DIFF %s" % d)
	for i in range(mini(recorded.size(), recomputed.size())):
		var rec: Dictionary = _dict(recorded[i])
		var cmp: Dictionary = _dict(recomputed[i])
		var event_type := String(cmp.get("type", rec.get("type", "?")))
		var diffs: Array[String] = []
		_diff("events[%d]" % i, rec, cmp, diffs)
		if diffs.is_empty():
			lines.append("  [%d] %s: OK (%s)" % [i, event_type, _event_summary(cmp)])
		else:
			lines.append("  [%d] %s: DIFF" % [i, event_type])
			for d in diffs:
				lines.append("      %s" % d)
				mismatches.append(d)

## PARTIAL mode — no replay_inputs: verify what the envelope alone can prove. The seed is recorded
## but the resolution inputs are not, so the dice cannot be re-rolled; instead check that the
## envelope is internally coherent (derived fields really derive from the recorded events) and
## that every event shares the envelope's seed/round lineage.
static func _replay_partial(envelope: Dictionary) -> Dictionary:
	var mismatches: Array[String] = []
	var lines: Array[String] = []
	var exchange_seed := int(envelope.get("exchange_seed", -1))
	var events: Array = _array(envelope.get("events", []))
	lines.append("mode=PARTIAL seed=%d: no replay_inputs on this envelope — verifying internal consistency + seed lineage only" % exchange_seed)
	if exchange_seed >= 0:
		lines.append("  exchange_seed is recorded: fully replayable once the producer attaches replay_inputs")
	else:
		lines.append("  exchange_seed is UNSEEDED (<0): this exchange can never be deterministically replayed")

	_check(int(envelope.get("event_count", -1)) == events.size(),
		"event_count: recorded=%s events.size=%d" % [_fmt(envelope.get("event_count")), events.size()],
		"event_count matches events (%d)" % events.size(), mismatches, lines)

	var types := []
	for event in events:
		types.append(String(_dict(event).get("type", "")))
	_check(_values_equal(envelope.get("event_types", []), types),
		"event_types: recorded=%s derived=%s" % [_fmt(envelope.get("event_types")), _fmt(types)],
		"event_types match events (%s)" % _fmt(types), mismatches, lines)

	for i in range(events.size()):
		var event: Dictionary = _dict(events[i])
		var event_type := String(event.get("type", "?"))
		var event_ok := true
		if event.has("exchange_seed") and int(event["exchange_seed"]) != exchange_seed:
			event_ok = false
			var d := "events[%d].exchange_seed: recorded=%s envelope=%d" % [i, _fmt(event["exchange_seed"]), exchange_seed]
			mismatches.append(d)
			lines.append("  [%d] %s: DIFF %s" % [i, event_type, d])
		if event.has("round") and int(event["round"]) != int(envelope.get("round", -1)):
			event_ok = false
			var d2 := "events[%d].round: recorded=%s envelope=%s" % [i, _fmt(event["round"]), _fmt(envelope.get("round"))]
			mismatches.append(d2)
			lines.append("  [%d] %s: DIFF %s" % [i, event_type, d2])
		if event_ok:
			lines.append("  [%d] %s: OK (%s)" % [i, event_type, _event_summary(event)])
		if event_type == "exchange_completed":
			var delta: Dictionary = _dict(envelope.get("state_delta", {}))
			var flags: Dictionary = _dict(envelope.get("flags", {}))
			_check(_values_equal(event.get("next_round"), delta.get("next_round")),
				"exchange_completed.next_round=%s vs state_delta.next_round=%s" % [_fmt(event.get("next_round")), _fmt(delta.get("next_round"))],
				"exchange_completed.next_round matches state_delta", mismatches, lines)
			_check(_values_equal(event.get("player_wound_severity"), delta.get("player_wound_severity")),
				"exchange_completed.player_wound_severity=%s vs state_delta=%s" % [_fmt(event.get("player_wound_severity")), _fmt(delta.get("player_wound_severity"))],
				"exchange_completed.player_wound_severity matches state_delta", mismatches, lines)
			_check(_values_equal(event.get("target_disabled"), flags.get("target_disabled")),
				"exchange_completed.target_disabled=%s vs flags.target_disabled=%s" % [_fmt(event.get("target_disabled")), _fmt(flags.get("target_disabled"))],
				"exchange_completed.target_disabled matches flags", mismatches, lines)

	return {"mode": MODE_PARTIAL, "match": mismatches.is_empty(), "mismatches": mismatches, "lines": lines, "recomputed": {}}

static func _check(ok: bool, fail_text: String, ok_text: String, mismatches: Array[String], lines: Array[String]) -> void:
	if ok:
		lines.append("  %s" % ok_text)
	else:
		mismatches.append(fail_text)
		lines.append("  DIFF %s" % fail_text)

## Deep diff with JSON tolerance (int 4 == float 4.0). Appends "path: recorded=X recomputed=Y".
static func _diff(path: String, recorded: Variant, recomputed: Variant, out: Array[String]) -> void:
	var tr := typeof(recorded)
	var tc := typeof(recomputed)
	if tr == TYPE_DICTIONARY and tc == TYPE_DICTIONARY:
		var keys := {}
		for k in (recorded as Dictionary):
			keys[k] = true
		for k in (recomputed as Dictionary):
			keys[k] = true
		for k in keys:
			_diff("%s.%s" % [path, str(k)], (recorded as Dictionary).get(k), (recomputed as Dictionary).get(k), out)
		return
	if tr == TYPE_ARRAY and tc == TYPE_ARRAY:
		var ra := recorded as Array
		var ca := recomputed as Array
		if ra.size() != ca.size():
			out.append("%s.size: recorded=%d recomputed=%d" % [path, ra.size(), ca.size()])
		for i in range(mini(ra.size(), ca.size())):
			_diff("%s[%d]" % [path, i], ra[i], ca[i], out)
		return
	if not _values_equal(recorded, recomputed):
		out.append("%s: recorded=%s recomputed=%s" % [path, _fmt(recorded), _fmt(recomputed)])

static func _values_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return absf(float(a) - float(b)) < 0.0005
	if ta == TYPE_DICTIONARY and tb == TYPE_DICTIONARY:
		var diffs: Array[String] = []
		_diff("", a, b, diffs)
		return diffs.is_empty()
	if ta == TYPE_ARRAY and tb == TYPE_ARRAY:
		var adiffs: Array[String] = []
		_diff("", a, b, adiffs)
		return adiffs.is_empty()
	if ta != tb:
		return false
	return a == b

static func _event_summary(event: Dictionary) -> String:
	var bits: Array[String] = []
	for field in EVENT_REPORT_FIELDS:
		if event.has(field):
			bits.append("%s=%s" % [field, _fmt(event[field])])
	return ", ".join(bits)

static func _fmt(value: Variant) -> String:
	if typeof(value) == TYPE_FLOAT and absf(float(value) - roundf(float(value))) < 0.0005:
		return str(int(roundf(float(value))))
	return str(value)

static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}

static func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []
