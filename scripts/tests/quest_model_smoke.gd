extends SceneTree
## Smoke for the pure quest model (overnight C2 / DIV-0020): accept -> event progress -> complete ->
## claim-once reward, across the disable / reach_zone / earn_credits objective kinds. Deterministic.

const Quest = preload("res://scripts/rules/quest_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- load the real data file's defs ---
	var f := FileAccess.open("res://data/quests_clone_wars.json", FileAccess.READ)
	_assert_true(f != null, "quests data file opens")
	var data: Dictionary = JSON.parse_string(f.get_as_text()) if f != null else {}
	var defs := Quest.defs_from_data(data)
	_assert_true(defs.has("q_pest_control") and defs.has("q_dune_scout"), "defs parse from data")

	# --- disable objective (count 3), untargeted ---
	var q := Quest.accept(Quest.initial_quests(), "q_pest_control")
	_assert_equal(bool((q["q_pest_control"] as Dictionary)["complete"]), false, "freshly accepted quest is incomplete")
	q = Quest.record_event(q, defs, {"type": "disable", "creature_key": "hitcher_crab"})
	q = Quest.record_event(q, defs, {"type": "travel", "zone_id": "tatooine.dune_sea"})  # unrelated -> no progress
	_assert_equal(int((q["q_pest_control"] as Dictionary)["progress"]), 1, "one disable = 1 progress; unrelated events ignored")
	q = Quest.record_event(q, defs, {"type": "disable", "creature_key": "womp_rat"})
	q = Quest.record_event(q, defs, {"type": "disable", "creature_key": "tusken"})
	_assert_equal(bool((q["q_pest_control"] as Dictionary)["complete"]), true, "3 disables completes the kill quest")
	_assert_equal(int((q["q_pest_control"] as Dictionary)["progress"]), 3, "progress caps at the objective count")
	# extra events don't overshoot / re-progress a complete quest
	q = Quest.record_event(q, defs, {"type": "disable", "creature_key": "x"})
	_assert_equal(int((q["q_pest_control"] as Dictionary)["progress"]), 3, "progress never exceeds count")

	# --- claim-once reward ---
	_assert_equal(Quest.can_claim(q, "q_pest_control"), true, "a complete, unclaimed quest is claimable")
	var c := Quest.claim(q, defs, "q_pest_control")
	_assert_equal(bool(c["ok"]), true, "claim succeeds")
	_assert_equal(int((c["reward"] as Dictionary)["credits"]), 180, "reward credits from data")
	_assert_equal(int((c["reward"] as Dictionary)["cp"]), 3, "reward CP from data")
	q = c["quests"]
	_assert_equal(Quest.can_claim(q, "q_pest_control"), false, "cannot re-claim")
	_assert_equal(bool(Quest.claim(q, defs, "q_pest_control")["ok"]), false, "second claim is a no-op")

	# --- targeted disable: only the named creature counts ---
	var kb := Quest.accept(Quest.initial_quests(), "q_krayt_bounty")
	kb = Quest.record_event(kb, defs, {"type": "disable", "creature_key": "womp_rat"})  # wrong target
	_assert_equal(int((kb["q_krayt_bounty"] as Dictionary)["progress"]), 0, "a non-target disable does not advance a targeted bounty")
	kb = Quest.record_event(kb, defs, {"type": "disable", "creature_key": "krayt_dragon"})
	_assert_equal(bool((kb["q_krayt_bounty"] as Dictionary)["complete"]), true, "the targeted creature completes the bounty")

	# --- reach_zone ---
	var dz := Quest.accept(Quest.initial_quests(), "q_dune_scout")
	dz = Quest.record_event(dz, defs, {"type": "travel", "zone_id": "tatooine.mos_eisley.market_district"})  # wrong zone
	_assert_equal(bool((dz["q_dune_scout"] as Dictionary)["complete"]), false, "wrong zone does not complete reach_zone")
	dz = Quest.record_event(dz, defs, {"type": "travel", "zone_id": "tatooine.dune_sea"})
	_assert_equal(bool((dz["q_dune_scout"] as Dictionary)["complete"]), true, "reaching the target zone completes it")

	# --- earn_credits accumulates amounts ---
	var ec := Quest.accept(Quest.initial_quests(), "q_first_earnings")
	ec = Quest.record_event(ec, defs, {"type": "credits", "amount": 120})
	_assert_equal(bool((ec["q_first_earnings"] as Dictionary)["complete"]), false, "120 < 200 not complete")
	ec = Quest.record_event(ec, defs, {"type": "credits", "amount": 90})
	_assert_equal(bool((ec["q_first_earnings"] as Dictionary)["complete"]), true, "cumulative 210 >= 200 completes it")

	# --- non-accepted quest ignores events (no auto-accept) ---
	var none := Quest.record_event(Quest.initial_quests(), defs, {"type": "disable", "creature_key": "x"})
	_assert_equal(none.is_empty(), true, "events do not auto-accept quests")

	if _failures.is_empty():
		print("quest_model_smoke: OK")
		quit(0)
	else:
		for fail in _failures:
			printerr(fail)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
