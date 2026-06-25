extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	var rules_script: GDScript = load("res://scripts/rules/d6_rules.gd")
	var rules: Node = rules_script.new()
	var model_script: GDScript = load("res://scripts/rules/action_window_model.gd")
	var model: RefCounted = model_script.new()

	var state: Dictionary = model.initial_state()
	_assert_equal(state["window"], 1, "initial action window")
	_assert_equal(state["phase"], "initiative", "initial phase")
	_assert_equal(state["window_seconds"], 5.0, "initial window seconds")

	var participants := [
		{"id": "trainee", "name": "Trainee", "side": "player", "perception_pool": {"dice": 3, "pips": 0}},
		{"id": "remote_a", "name": "Remote A", "side": "npc", "perception_pool": {"dice": 2, "pips": 1}},
		{"id": "remote_b", "name": "Remote B", "side": "npc", "perception_pool": {"dice": 2, "pips": 0}},
	]
	var initiative_a: Dictionary = model.resolve_initiative(rules, state, participants, 6060)
	var initiative_b: Dictionary = model.resolve_initiative(rules, state, participants, 6060)
	_assert_equal(initiative_a["rolls"], initiative_b["rolls"], "same initiative seed replays rolls")
	_assert_equal(initiative_a["state"]["phase"], "declaration", "initiative advances to declaration")
	_assert_equal(initiative_a["initiative_order"].size(), 3, "initiative order has active participants")

	var expected_declaration_order: Array = initiative_a["initiative_order"].duplicate()
	expected_declaration_order.reverse()
	_assert_equal(initiative_a["declaration_order"], expected_declaration_order, "declaration order is reverse initiative")

	var declaration: Dictionary = model.normalize_declaration([
		{"type": "attack", "target_id": "remote_a"},
		{"type": "dodge"},
	])
	_assert_equal(declaration["valid"], true, "attack plus dodge declaration is valid")
	_assert_equal(declaration["action_count"], 2, "two declared actions")
	_assert_equal(declaration["multi_action_penalty_dice"], 1, "two actions create one penalty die")

	var full_dodge: Dictionary = model.normalize_declaration([
		{"type": "full_dodge"},
	])
	_assert_equal(full_dodge["valid"], true, "single full dodge is valid")
	_assert_equal(full_dodge["multi_action_penalty_dice"], 0, "single full dodge has no multi-action penalty")

	var illegal_full_dodge: Dictionary = model.normalize_declaration([
		{"type": "full_dodge"},
		{"type": "attack", "target_id": "remote_a"},
	])
	_assert_equal(illegal_full_dodge["valid"], false, "full dodge plus attack is invalid")

	var cp_fp: Dictionary = model.normalize_declaration([
		{"type": "attack", "target_id": "remote_a"},
	], {"character_points": 1, "force_point": true})
	_assert_equal(cp_fp["valid"], false, "cp and force point cannot mix")

	var declared: Dictionary = model.declare_actions(initiative_a["state"], "trainee", [{"type": "attack"}])
	_assert_equal(declared["valid"], true, "declare action succeeds")
	_assert_equal(declared["state"]["declarations"].has("trainee"), true, "declaration stored by participant")
	_assert_equal(model.ready_for_resolution(declared["state"], ["trainee"]), true, "ready when all active ids declared")
	_assert_equal(model.ready_for_resolution(declared["state"], ["trainee", "remote_a"]), false, "not ready while active id is undeclared")

	var resolving: Dictionary = model.begin_resolution(declared["state"])
	_assert_equal(resolving["phase"], "resolution", "begin resolution phase")
	var next_window: Dictionary = model.complete_window(resolving)
	_assert_equal(next_window["window"], 2, "complete window advances counter")
	_assert_equal(next_window["phase"], "initiative", "complete window resets phase")
	_assert_equal(next_window["declarations"].is_empty(), true, "complete window clears declarations")

	rules.free()
	rules_script = null
	model_script = null

	if _failures.is_empty():
		print("action_window_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
