extends RefCounted

const ActionWindowModel = preload("res://scripts/rules/action_window_model.gd")

static func player_declaration_for_state(state: Dictionary, target_id: String = "") -> Dictionary:
	var actions := _player_actions_for_state(state, target_id)
	var options := {
		"character_points": int(state.get("pending_attack_cp", 0)) + int(state.get("pending_soak_cp", 0)),
		"force_point": bool(state.get("force_point_active", false)),
	}
	var model := ActionWindowModel.new()
	var declaration: Dictionary = model.normalize_declaration(actions, options)
	declaration["participant_id"] = "trainee"
	return declaration

static func remote_declarations_for_incoming(incoming_attacks: Array) -> Dictionary:
	var declarations := {}
	var model := ActionWindowModel.new()
	for i in range(incoming_attacks.size()):
		var incoming: Dictionary = incoming_attacks[i]
		var source_id := String(incoming.get("source_id", "remote_%d" % i))
		if source_id == "":
			source_id = "remote_%d" % i
		declarations[source_id] = model.normalize_declaration([{"type": "attack", "target_id": "trainee"}])
	return declarations

static func active_participant_ids(incoming_attacks: Array, include_player: bool = true) -> Array:
	var ids := []
	if include_player:
		ids.append("trainee")
	for i in range(incoming_attacks.size()):
		var incoming: Dictionary = incoming_attacks[i]
		var source_id := String(incoming.get("source_id", "remote_%d" % i))
		if source_id == "":
			source_id = "remote_%d" % i
		if not ids.has(source_id):
			ids.append(source_id)
	return ids

static func declaration_summary(player_declaration: Dictionary, remote_count: int = 0) -> String:
	var action_text := _action_text(player_declaration.get("actions", []))
	var cp := int(player_declaration.get("character_points", 0))
	var fp := bool(player_declaration.get("force_point", false))
	var resource_text := ""
	if cp > 0:
		resource_text = " CP%d" % cp
	elif fp:
		resource_text = " FP"
	return "decl %s%s / remotes %d" % [action_text, resource_text, maxi(remote_count, 0)]

static func assemble_resolution_window(combat_state: Dictionary, incoming_attacks: Array = [], target_id: String = "") -> Dictionary:
	var model := ActionWindowModel.new()
	var window_state: Dictionary = model.initial_state(float(combat_state.get("action_window_seconds", 5.0)))
	window_state["window"] = int(combat_state.get("round", 1))
	window_state["phase"] = "declaration"

	var player_declaration := player_declaration_for_state(combat_state, target_id)
	var remote_declarations := remote_declarations_for_incoming(incoming_attacks)
	var active_ids := active_participant_ids(incoming_attacks)

	var next_state := window_state
	var declaration_errors := []
	var player_result: Dictionary = model.declare_actions(
		next_state,
		"trainee",
		player_declaration.get("actions", []),
		_declaration_options(player_declaration)
	)
	next_state = player_result["state"]
	if not bool(player_result.get("valid", false)):
		declaration_errors.append_array(player_result.get("errors", []))

	for source_id in remote_declarations.keys():
		var remote_declaration: Dictionary = remote_declarations[source_id]
		var remote_result: Dictionary = model.declare_actions(
			next_state,
			String(source_id),
			remote_declaration.get("actions", []),
			_declaration_options(remote_declaration)
		)
		next_state = remote_result["state"]
		if not bool(remote_result.get("valid", false)):
			declaration_errors.append_array(remote_result.get("errors", []))

	var ready := declaration_errors.is_empty() and model.ready_for_resolution(next_state, active_ids)
	if ready:
		next_state = model.begin_resolution(next_state)

	return {
		"window": int(next_state.get("window", 1)),
		"phase": String(next_state.get("phase", "")),
		"ready": ready,
		"active_ids": active_ids,
		"declaration_count": Dictionary(next_state.get("declarations", {})).size(),
		"player_declaration": player_declaration,
		"remote_declarations": remote_declarations,
		"errors": declaration_errors,
		"state": next_state,
	}

static func _player_actions_for_state(state: Dictionary, target_id: String) -> Array:
	var defense := String(state.get("player_defense", "none"))
	if defense == "full_dodge":
		return [{"type": "full_dodge"}]
	var actions := []
	if target_id != "":
		actions.append({"type": "attack", "target_id": target_id})
	if defense == "dodge":
		actions.append({"type": "dodge"})
	if actions.is_empty():
		actions.append({"type": "wait"})
	return actions

static func _action_text(actions: Variant) -> String:
	if typeof(actions) != TYPE_ARRAY:
		return "none"
	var names := PackedStringArray()
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_type := String(action.get("type", "")).strip_edges()
		if action_type != "":
			names.append(action_type)
	if names.is_empty():
		return "none"
	return "+".join(names)

static func _declaration_options(declaration: Dictionary) -> Dictionary:
	return {
		"character_points": int(declaration.get("character_points", 0)),
		"force_point": bool(declaration.get("force_point", false)),
	}
