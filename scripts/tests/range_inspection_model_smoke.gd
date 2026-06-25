extends SceneTree

const RangeInspectionModel = preload("res://scripts/rules/range_inspection_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var b1_text := RangeInspectionModel.target_text(
		"B1 behind cargo - medium",
		"b1_training_silhouette",
		2,
		1,
		0,
		{
			"name": "B1 Training Silhouette",
			"attack_pool": {"dice": 3, "pips": 0},
			"damage_pool": {"dice": 3, "pips": 2},
			"soak_pool": {"dice": 2, "pips": 0},
			"armor": {},
			"scale": "character",
			"weapon_name": "Remote Stun Blaster",
			"source_note": "Uses B1 strength baseline from Clone Wars combat templates.",
		}
	)
	_assert_equal(
		b1_text,
		"B1 behind cargo - medium: B1 Training Silhouette | scale character | cover 2 | wound Stunned | soak 2D | armor none | armed Remote Stun Blaster atk 3D dmg 3D+2 | Uses B1 strength baseline from Clone Wars combat templates.",
		"armed B1 target inspection"
	)

	var walker_text := RangeInspectionModel.target_text(
		"Walker-scale moving armor plate",
		"walker_armor_plate",
		0,
		0,
		0,
		{
			"name": "Walker-Scale Armor Plate",
			"attack_pool": {"dice": 0, "pips": 0},
			"damage_pool": {"dice": 0, "pips": 0},
			"soak_pool": {"dice": 4, "pips": 0},
			"armor": {},
			"scale": "walker",
			"weapon_name": "Walker Plate Tester",
			"source_note": "Prototype cross-scale target for character weapons versus walker-scale body.",
		}
	)
	_assert_equal(
		walker_text,
		"Walker-scale moving armor plate: Walker-Scale Armor Plate | scale walker | cover 0 | wound OK | soak 4D | armor none | inert target | Prototype cross-scale target for character weapons versus walker-scale body.",
		"inert walker target inspection"
	)

	var armored_text := RangeInspectionModel.target_text(
		"Armored test target",
		"armored_test",
		0,
		2,
		-1,
		{
			"name": "Armored Test",
			"attack_pool": {"dice": 0, "pips": 0},
			"damage_pool": {"dice": 0, "pips": 0},
			"soak_pool": {"dice": 2, "pips": 0},
			"armor": {
				"name": "Training Blast Vest",
				"protection_energy": "0D+1",
				"protection_physical": "1D",
				"coverage": ["torso"],
			},
			"scale": "character",
		}
	)
	_assert_equal(armored_text.contains("Training Blast Vest covers torso q -1"), true, "armored target coverage and quality")

	var behavior_text := RangeInspectionModel.target_text(
		"B1 moving remote",
		"b1_training_silhouette",
		0,
		0,
		0,
		{
			"name": "B1 Training Silhouette",
			"attack_pool": {"dice": 3, "pips": 0},
			"damage_pool": {"dice": 3, "pips": 2},
			"soak_pool": {"dice": 2, "pips": 0},
			"armor": {},
			"scale": "character",
			"weapon_name": "Remote Stun Blaster",
		},
		{
			"live_enabled": true,
			"current_state": "covering",
			"next_state": "ready",
		}
	)
	_assert_equal(behavior_text.contains("live COVER now (applying covering pressure), next READY"), true, "behavior context text")

	var paused_behavior_text := RangeInspectionModel.target_text(
		"B1 pinned remote",
		"b1_training_silhouette",
		0,
		0,
		0,
		{
			"name": "B1 Training Silhouette",
			"attack_pool": {"dice": 3, "pips": 0},
			"damage_pool": {"dice": 3, "pips": 2},
			"soak_pool": {"dice": 2, "pips": 0},
			"armor": {},
			"scale": "character",
			"weapon_name": "Remote Stun Blaster",
		},
		{
			"live_enabled": false,
			"current_state": "pinned",
			"next_state": "waiting",
		}
	)
	_assert_equal(paused_behavior_text.contains("live paused PINNED now (pinned by near miss), next WAIT"), true, "paused behavior context text")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("range_inspection_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
