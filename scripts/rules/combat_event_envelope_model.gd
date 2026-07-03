extends RefCounted

const ENVELOPE_VERSION := 1
const MESSAGE_TYPE := "combat.exchange.resolved"
const REPLAY_INPUTS_VERSION := 1
# Which resolver a replay_inputs block re-runs. The default/legacy attach_replay_inputs block carries NO
# "kind" key and is treated as EXCHANGE (attack-and-return, ground_combat_model.resolve_exchange); the
# incoming-fire variant marks itself INCOMING so envelope_replay_model re-runs resolve_incoming_fire_window.
const REPLAY_KIND_EXCHANGE := "exchange"
const REPLAY_KIND_INCOMING := "incoming_fire"

static func envelope_for_result(result: Dictionary, exchange_kind: String = "ground_range", channel: String = "local") -> Dictionary:
	var events: Array = result.get("events", [])
	var action_window: Dictionary = result.get("action_window", {})
	return {
		"version": ENVELOPE_VERSION,
		"message_type": MESSAGE_TYPE,
		"channel": channel,
		"exchange_kind": exchange_kind,
		"round": int(result.get("round", result.get("action_window", {}).get("window", 0))),
		"exchange_seed": int(result.get("exchange_seed", -1)),
		"valid": not bool(result.get("invalid_action_window", false)),
		"invalid_action_window": bool(result.get("invalid_action_window", false)),
		"action_window": _action_window_summary(action_window),
		"events": events,
		"event_count": events.size(),
		"event_types": _event_types(events),
		"state_delta": _state_delta(result),
		"encounter_state": _encounter_state_summary(result.get("encounter_state", {})),
		"flags": _result_flags(result),
	}

# PT1 replay prep: OPTIONAL, purely ADDITIVE block a producer CAN attach so the exchange is
# re-runnable later from the envelope alone (dev debugging / player-dispute resolution). These are
# the EXACT arguments the producer passed to ground_combat_model.resolve_exchange[_with_action_window]
# BEFORE resolution (pre-exchange state/target/pools), plus the envelope's own exchange_seed — the
# server owns all RNG, so seed+inputs fully determine the outcome. Every pre-existing envelope field
# stays byte-identical (this returns a COPY with one new key); an envelope without the block still
# flows everywhere unchanged, and the replay tool (tools/envelope_replay.gd via
# scripts/rules/envelope_replay_model.gd) degrades to PARTIAL consistency checks for it.
static func attach_replay_inputs(envelope: Dictionary, state: Dictionary, target_state: Dictionary, pools: Dictionary, distance: float, target_cover_level: int, defender_defense_stance: String = "none", action_window: Dictionary = {}) -> Dictionary:
	var out := envelope.duplicate(true)
	out["replay_inputs"] = {
		"present": true,
		"version": REPLAY_INPUTS_VERSION,
		"state": state.duplicate(true),
		"target_state": target_state.duplicate(true),
		"pools": pools.duplicate(true),
		"distance": distance,
		"target_cover_level": target_cover_level,
		"defender_defense_stance": defender_defense_stance,
		"action_window": action_window.duplicate(true),
	}
	return out

# PT1 replay prep (INCOMING-FIRE variant): the resolve_hostile_aggression / resolve_incoming_fire_window
# path is NOT an attack-and-return exchange — the victim only TAKES fire, so it cannot be re-run through
# resolve_exchange. Its replay inputs are the victim's pre-hit state, the merged defensive+attacker pools,
# and the incoming-attack list (each a {attack_pool, damage_pool, scale, distance, cover_level,
# wound_severity} dict), plus the envelope's exchange_seed. Marked kind=incoming_fire so envelope_replay_model
# re-runs resolve_incoming_fire_window (not resolve_exchange). Same discipline as attach_replay_inputs:
# returns a COPY with one new key, never mutates/broadcasts — server/log side only (it carries pools).
static func attach_replay_inputs_incoming(envelope: Dictionary, state: Dictionary, pools: Dictionary, incoming_attacks: Array, exchange_seed: int) -> Dictionary:
	var out := envelope.duplicate(true)
	out["replay_inputs"] = {
		"present": true,
		"version": REPLAY_INPUTS_VERSION,
		"kind": REPLAY_KIND_INCOMING,
		"state": state.duplicate(true),
		"pools": pools.duplicate(true),
		"incoming": incoming_attacks.duplicate(true),
		"exchange_seed": exchange_seed,
	}
	return out

static func has_replay_inputs(envelope: Dictionary) -> bool:
	var inputs: Variant = envelope.get("replay_inputs", {})
	if typeof(inputs) != TYPE_DICTIONARY:
		return false
	return bool((inputs as Dictionary).get("present", false))

static func _action_window_summary(action_window: Dictionary) -> Dictionary:
	if action_window.is_empty():
		return {
			"present": false,
			"ready": false,
			"phase": "",
			"active_ids": [],
			"declaration_count": 0,
			"errors": [],
		}
	return {
		"present": true,
		"ready": bool(action_window.get("ready", false)),
		"phase": String(action_window.get("phase", "")),
		"window": int(action_window.get("window", 0)),
		"active_ids": action_window.get("active_ids", []),
		"declaration_count": int(action_window.get("declaration_count", 0)),
		"errors": action_window.get("errors", []),
	}

static func _event_types(events: Array) -> Array:
	var types := []
	for event in events:
		if typeof(event) == TYPE_DICTIONARY:
			types.append(String(Dictionary(event).get("type", "")))
	return types

static func _state_delta(result: Dictionary) -> Dictionary:
	var state: Dictionary = result.get("state", {})
	var target_state: Dictionary = result.get("target_state", {})
	return {
		"next_round": int(state.get("round", 0)),
		"player_wound_severity": int(state.get("player_wound_severity", 0)),
		"target_wound_severity": int(target_state.get("wound_severity", -1)),
		"player_character_points": int(state.get("player_character_points", -1)),
		"player_force_points": int(state.get("player_force_points", -1)),
	}

static func _encounter_state_summary(encounter_state: Dictionary) -> Dictionary:
	if encounter_state.is_empty():
		return {"present": false}
	return {
		"present": true,
		"kind": String(encounter_state.get("kind", "")),
		"tick_index": int(encounter_state.get("tick_index", -1)),
		"live_enabled": bool(encounter_state.get("live_enabled", false)),
		"current": encounter_state.get("current", {}),
		"next": encounter_state.get("next", {}),
	}

static func _result_flags(result: Dictionary) -> Dictionary:
	return {
		"already_disabled": bool(result.get("already_disabled", false)),
		"target_disabled": bool(result.get("target_disabled", false)),
		"player_attack_skipped": bool(result.get("player_attack_skipped", false)),
		"force_point_spent": bool(result.get("force_point_spent", false)),
	}
