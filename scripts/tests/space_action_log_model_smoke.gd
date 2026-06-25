extends SceneTree

const SpaceActionLogModel = preload("res://scripts/rules/space_action_log_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var log_entries: Array = []
	log_entries = SpaceActionLogModel.append_entry(log_entries, "Sensors", "Sensor sweep resolved contacts.", 3)
	log_entries = SpaceActionLogModel.append_entry(log_entries, "Gunnery", "Gunnery hit target.", 3)
	log_entries = SpaceActionLogModel.append_entry(log_entries, "Repair", "Damage control repaired shields.", 3)
	_assert_equal(log_entries.size(), 3, "log stores up to limit")
	log_entries = SpaceActionLogModel.append_entry(log_entries, "Comms", "Hail opened a channel.", 3)
	_assert_equal(log_entries.size(), 3, "log remains capped")
	_assert_equal(log_entries[0]["category"], "Gunnery", "oldest entry rolls off")
	_assert_equal(
		SpaceActionLogModel.summary_text(log_entries),
		"Recent: Gunnery: Gunnery hit target. | Repair: Damage control repaired shields. | Comms: Hail opened a channel.",
		"summary text"
	)
	var truncated := SpaceActionLogModel.append_entry([], "Sensors", "abcdefghijklmnopqrstuvwxyz", 4, 12)
	_assert_equal(truncated[0]["text"], "abcdefghi...", "long text truncates")
	var tagged := SpaceActionLogModel.append_entry([], "Gunnery", "Returned fire.", 4, 72, "Threat")
	_assert_equal(tagged[0]["tag"], "Threat", "tag is preserved on log entry")
	_assert_equal(SpaceActionLogModel.summary_text(tagged), "Recent: Gunnery (Threat): Returned fire.", "summary includes compact tag")
	_assert_equal(SpaceActionLogModel.tag_for_cue_level("critical"), "Alert", "critical cue maps to alert tag")
	_assert_equal(SpaceActionLogModel.tag_for_cue_level("threat"), "Threat", "threat cue maps to threat tag")
	_assert_equal(SpaceActionLogModel.tag_for_cue_level("repair"), "Repair", "repair cue maps to repair tag")
	_assert_equal(SpaceActionLogModel.tag_for_cue_level("notice"), "Status", "notice cue maps to status tag")
	_assert_equal(SpaceActionLogModel.tag_for_cue_level("guidance"), "Next", "guidance cue maps to next tag")
	_assert_equal(SpaceActionLogModel.tag_for_cue_level("none"), "", "empty cue level maps to no tag")
	var consumed := SpaceActionLogModel.consume_cue_tag("threat")
	_assert_equal(consumed["tag"], "Threat", "consume cue tag returns mapped tag")
	_assert_equal(consumed["cue_level"], "", "consume cue tag clears pending cue level")
	var second_entry := SpaceActionLogModel.append_entry(tagged, "Target", "Selected Visible Patrol.", 4, 72, consumed["cue_level"])
	_assert_equal(
		SpaceActionLogModel.summary_text(second_entry),
		"Recent: Gunnery (Threat): Returned fire. | Target: Selected Visible Patrol.",
		"consumed cue level does not tag later entry"
	)
	_assert_equal(SpaceActionLogModel.summary_text([]), "Recent: none", "empty summary")
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("space_action_log_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
