extends RefCounted

const PHASE_INITIATIVE := "initiative"
const PHASE_DECLARATION := "declaration"
const PHASE_RESOLUTION := "resolution"
const PHASE_COMPLETE := "complete"
const ACTION_FULL_DODGE := "full_dodge"
const ACTION_FULL_PARRY := "full_parry"

func initial_state(window_seconds: float = 5.0) -> Dictionary:
	return {
		"window": 1,
		"window_seconds": window_seconds,
		"phase": PHASE_INITIATIVE,
		"initiative_order": [],
		"declaration_order": [],
		"declarations": {},
	}

func resolve_initiative(rules: Object, state: Dictionary, participants: Array, seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()

	var next_state := state.duplicate(true)
	var rolls: Array = []
	for participant in participants:
		if typeof(participant) != TYPE_DICTIONARY:
			continue
		var participant_id := String(participant.get("id", ""))
		if participant_id == "":
			continue
		var pool: Dictionary = participant.get("perception_pool", {"dice": 2, "pips": 0})
		var roll: Dictionary = rules.roll_pool(pool, rng)
		rolls.append({
			"id": participant_id,
			"name": String(participant.get("name", participant_id)),
			"side": String(participant.get("side", "")),
			"initiative": int(roll["total"]),
			"roll": roll,
			"active": bool(participant.get("active", true)),
		})

	rolls.sort_custom(_sort_initiative_desc)
	var initiative_order: Array[String] = []
	for entry in rolls:
		if bool(entry.get("active", true)):
			initiative_order.append(String(entry["id"]))
	var declaration_order := initiative_order.duplicate()
	declaration_order.reverse()

	next_state["phase"] = PHASE_DECLARATION
	next_state["initiative_order"] = initiative_order
	next_state["declaration_order"] = declaration_order
	return {
		"window": int(next_state.get("window", 1)),
		"seed": seed,
		"rolls": rolls,
		"initiative_order": initiative_order,
		"declaration_order": declaration_order,
		"state": next_state,
	}

func declare_actions(state: Dictionary, participant_id: String, actions: Array, options: Dictionary = {}) -> Dictionary:
	var next_state := state.duplicate(true)
	var declarations: Dictionary = next_state.get("declarations", {})
	var normalized := normalize_declaration(actions, options)
	if bool(normalized["valid"]):
		declarations[participant_id] = normalized
	next_state["declarations"] = declarations
	return {
		"valid": bool(normalized["valid"]),
		"errors": normalized["errors"],
		"declaration": normalized,
		"state": next_state,
	}

func normalize_declaration(actions: Array, options: Dictionary = {}) -> Dictionary:
	var normalized_actions: Array = []
	var errors: Array[String] = []
	var has_full_dodge := false
	var has_full_parry := false
	for action in actions:
		var normalized_action := _normalize_action(action)
		var action_type := String(normalized_action.get("type", ""))
		if action_type == "":
			continue
		if action_type == ACTION_FULL_DODGE:
			has_full_dodge = true
		if action_type == ACTION_FULL_PARRY:
			has_full_parry = true
		normalized_actions.append(normalized_action)

	if has_full_dodge and has_full_parry:
		errors.append("Full dodge and full parry cannot be declared together.")
	if (has_full_dodge or has_full_parry) and normalized_actions.size() > 1:
		errors.append("Full defense must be the only action in the window.")
	if int(options.get("character_points", 0)) > 0 and bool(options.get("force_point", false)):
		errors.append("Character Points and Force Points cannot be declared in the same window.")

	var action_count := normalized_actions.size()
	return {
		"valid": errors.is_empty(),
		"actions": normalized_actions,
		"action_count": action_count,
		"multi_action_penalty_dice": maxi(action_count - 1, 0),
		"character_points": clampi(int(options.get("character_points", 0)), 0, 5),
		"force_point": bool(options.get("force_point", false)),
		"errors": errors,
	}

func ready_for_resolution(state: Dictionary, active_ids: Array) -> bool:
	var declarations: Dictionary = state.get("declarations", {})
	for active_id in active_ids:
		if not declarations.has(String(active_id)):
			return false
	return true

func begin_resolution(state: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	next_state["phase"] = PHASE_RESOLUTION
	return next_state

func complete_window(state: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	next_state["window"] = int(next_state.get("window", 1)) + 1
	next_state["phase"] = PHASE_INITIATIVE
	next_state["initiative_order"] = []
	next_state["declaration_order"] = []
	next_state["declarations"] = {}
	return next_state

func _normalize_action(action: Variant) -> Dictionary:
	if typeof(action) == TYPE_DICTIONARY:
		var action_copy: Dictionary = action.duplicate(true)
		action_copy["type"] = String(action_copy.get("type", "")).strip_edges().to_lower()
		return action_copy
	return {"type": String(action).strip_edges().to_lower()}

func _sort_initiative_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_init := int(a.get("initiative", 0))
	var b_init := int(b.get("initiative", 0))
	if a_init == b_init:
		return String(a.get("id", "")) < String(b.get("id", ""))
	return a_init > b_init
