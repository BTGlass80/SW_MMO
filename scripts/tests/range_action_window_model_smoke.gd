extends SceneTree

const RangeActionWindowModel = preload("res://scripts/rules/range_action_window_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var attack_state := {
		"player_defense": "dodge",
		"pending_attack_cp": 1,
		"pending_soak_cp": 0,
		"force_point_active": false,
	}
	var attack_decl := RangeActionWindowModel.player_declaration_for_state(attack_state, "remote_a")
	_assert_equal(attack_decl["valid"], true, "attack plus dodge declaration is valid")
	_assert_equal(attack_decl["action_count"], 2, "attack plus dodge counts as two actions")
	_assert_equal(attack_decl["multi_action_penalty_dice"], 1, "attack plus dodge creates one penalty die")
	_assert_equal(attack_decl["character_points"], 1, "pending attack cp enters declaration")

	var full_dodge_decl := RangeActionWindowModel.player_declaration_for_state({"player_defense": "full_dodge"}, "remote_a")
	_assert_equal(full_dodge_decl["valid"], true, "full dodge declaration is valid")
	_assert_equal(full_dodge_decl["actions"].size(), 1, "full dodge suppresses attack declaration")
	_assert_equal(full_dodge_decl["actions"][0]["type"], "full_dodge", "full dodge is declared alone")

	var waiting_decl := RangeActionWindowModel.player_declaration_for_state({"player_defense": "none"}, "")
	_assert_equal(waiting_decl["actions"][0]["type"], "wait", "empty player input becomes wait declaration")

	var illegal_resources := RangeActionWindowModel.player_declaration_for_state({
		"player_defense": "none",
		"pending_attack_cp": 1,
		"force_point_active": true,
	}, "remote_a")
	_assert_equal(illegal_resources["valid"], false, "cp plus force point remains invalid")

	var incoming := [
		{"source_id": "remote_a"},
		{"source_id": "remote_b"},
		{"source_id": "remote_a"},
	]
	var remote_decls := RangeActionWindowModel.remote_declarations_for_incoming(incoming)
	_assert_equal(remote_decls.size(), 2, "remote declarations are keyed by source id")
	_assert_equal(remote_decls["remote_a"]["actions"][0]["target_id"], "trainee", "remote targets trainee")
	var active_ids := RangeActionWindowModel.active_participant_ids(incoming)
	_assert_equal(active_ids, ["trainee", "remote_a", "remote_b"], "active ids include player and unique remotes")
	var summary := RangeActionWindowModel.declaration_summary(attack_decl, 2)
	_assert_equal(summary.contains("attack+dodge CP1 / remotes 2"), true, "summary includes actions, cp, and remotes")

	var assembled := RangeActionWindowModel.assemble_resolution_window(
		{
			"round": 7,
			"action_window_seconds": 5.0,
			"player_defense": "dodge",
			"pending_attack_cp": 1,
			"pending_soak_cp": 0,
			"force_point_active": false,
		},
		incoming,
		"remote_a"
	)
	_assert_equal(assembled["ready"], true, "assembled window is ready when player and remotes declared")
	_assert_equal(assembled["phase"], "resolution", "ready assembled window advances to resolution phase")
	_assert_equal(assembled["window"], 7, "assembled window keeps range round")
	_assert_equal(assembled["active_ids"], ["trainee", "remote_a", "remote_b"], "assembled window active ids are stable")
	_assert_equal(assembled["declaration_count"], 3, "assembled window stores unique declarations")
	_assert_equal(Dictionary(assembled["state"]["declarations"]).has("trainee"), true, "assembled state stores player declaration")
	_assert_equal(Dictionary(assembled["state"]["declarations"]).has("remote_b"), true, "assembled state stores remote declaration")

	var illegal_window := RangeActionWindowModel.assemble_resolution_window({
		"round": 8,
		"player_defense": "none",
		"pending_attack_cp": 1,
		"force_point_active": true,
	}, incoming, "remote_a")
	_assert_equal(illegal_window["ready"], false, "invalid player declaration prevents ready window")
	_assert_equal(illegal_window["phase"], "declaration", "invalid window stays in declaration phase")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("range_action_window_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
