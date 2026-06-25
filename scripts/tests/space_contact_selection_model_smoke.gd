extends SceneTree

const SpaceContactSelectionModel = preload("res://scripts/rules/space_contact_selection_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var contacts := [
		{"id": "beacon", "name": "Beacon"},
		{"id": "freighter", "name": "Freighter"},
		{"id": "", "name": "No ID"},
		{"id": "disabled", "name": "Disabled", "selection_disabled": true},
		{"id": "shadow", "name": "Sensor Shadow", "hidden_until_revealed": true},
	]
	_assert_equal(SpaceContactSelectionModel.selectable_contact_ids(contacts), ["beacon", "freighter", "shadow"], "selectable contact ids")
	_assert_equal(SpaceContactSelectionModel.cycle_contact_id(contacts, "", 1), "beacon", "empty current cycles to first")
	_assert_equal(SpaceContactSelectionModel.cycle_contact_id(contacts, "beacon", 1), "freighter", "next contact")
	_assert_equal(SpaceContactSelectionModel.cycle_contact_id(contacts, "freighter", -1), "beacon", "previous contact")
	_assert_equal(SpaceContactSelectionModel.cycle_contact_id(contacts, "shadow", 1), "beacon", "next wraps")
	_assert_equal(SpaceContactSelectionModel.cycle_contact_id(contacts, "beacon", -1), "shadow", "previous wraps")
	_assert_equal(SpaceContactSelectionModel.cycle_contact_id([], "beacon", 1), "", "empty contacts")
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("space_contact_selection_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
