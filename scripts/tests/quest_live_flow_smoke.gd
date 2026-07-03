extends SceneTree
## Live-wiring smoke for quests (DIV-0020): guards the SERVER composition + cross-data integrity that
## the pure quest_model_smoke can't. Two jobs:
##   (A) Integrity — every shipped quest's objective resolves to REAL content (a hostile creature id, a
##       real zone id) with a non-zero reward + a giver. This is the check that would have caught the
##       q_krayt_bounty -> krayt_dragon gap: the pure model happily matches a target_key string even when
##       no such creature exists, so only a cross-file check keeps the notice board free of dead quests.
##   (B) Composition — mirrors the network_manager.gd helpers (_record_quests backfill, the
##       "write/push only when changed" no-op, and the claim -> credit-reward-feed ordering) so the live
##       server path stays honest without instantiating the (non-headless) Net autoload.
## Deterministic; no RNG.

const Quest = preload("res://scripts/rules/quest_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var quests_data := _load("res://data/quests_clone_wars.json")
	var creatures: Dictionary = _load("res://data/creatures_clone_wars.json").get("creatures", {})
	var zone_ids := {}
	for z in _load("res://data/zones_clone_wars.json").get("zones", []):
		zone_ids[String((z as Dictionary).get("zone_id", ""))] = true
	var defs := Quest.defs_from_data(quests_data)
	_assert_true(defs.size() >= 12, "at least 12 quests wired (got %d)" % defs.size())
	_assert_true(creatures.size() > 0 and zone_ids.size() > 0, "creatures + zones data loaded")

	# --- (A) cross-data integrity: no dead quests -----------------------------------------------
	for qid in defs:
		var qdef: Dictionary = defs[qid]
		var obj: Dictionary = qdef.get("objective", {})
		var kind := String(obj.get("kind", ""))
		_assert_true(kind in ["disable", "reach_zone", "earn_credits"], "%s: known objective kind (%s)" % [qid, kind])
		match kind:
			"disable":
				var tk := String(obj.get("target_key", ""))
				if tk != "":
					_assert_true(creatures.has(tk), "%s: disable target '%s' is a real creature" % [qid, tk])
					_assert_true(bool((creatures.get(tk, {}) as Dictionary).get("hostile", false)),
						"%s: disable target '%s' is huntable (hostile)" % [qid, tk])
				_assert_true(int(obj.get("count", 1)) >= 1, "%s: disable count >= 1" % qid)
			"reach_zone":
				_assert_true(zone_ids.has(String(obj.get("zone_id", ""))), "%s: reach_zone '%s' is a real zone" % [qid, String(obj.get("zone_id", ""))])
			"earn_credits":
				_assert_true(int(obj.get("count", 0)) > 0, "%s: earn_credits target > 0" % qid)
		var reward: Dictionary = qdef.get("reward", {})
		_assert_true(int(reward.get("credits", 0)) + int(reward.get("cp", 0)) > 0, "%s: reward is not empty" % qid)
		_assert_true(String(qdef.get("giver", "")) != "", "%s: has a giver" % qid)
	# explicit regression guard for the gap this drop closed
	_assert_true(creatures.has("krayt_dragon"), "the krayt bounty's target creature exists")
	_assert_equal(String((defs.get("q_krayt_bounty", {}) as Dictionary).get("objective", {}).get("target_key", "")),
		"krayt_dragon", "q_krayt_bounty still targets krayt_dragon")

	# --- (B1) _record_quests backfill: a legacy record with no "quests" key -> an empty block --------
	var legacy_record := {"sheet": {}, "species": "human"}  # predates DIV-0020
	var backfilled := _record_quests(legacy_record)
	_assert_equal(backfilled, {}, "a record without quests backfills to an empty block")
	_assert_equal(Quest.record_event(backfilled, defs, {"type": "disable", "creature_key": "womp_rat"}), {},
		"feeding a legacy/empty block is a no-op (no accepted quests)")

	# --- (B2) write/push only when changed: an unrelated event returns an EQUAL block ---------------
	var accepted := Quest.accept(Quest.initial_quests(), "q_pest_control")  # a disable quest
	var unchanged := Quest.record_event(accepted, defs, {"type": "travel", "zone_id": "tatooine.dune_sea"})
	_assert_equal(unchanged, accepted, "an unrelated event yields an unchanged block (server skips persist+push)")
	var changed := Quest.record_event(accepted, defs, {"type": "disable", "creature_key": "womp_rat"})
	_assert_true(changed != accepted, "a relevant event yields a changed block (server persists+pushes)")

	# --- (B3) claim -> credit-reward feed ordering (mirrors submit_claim_quest -> _award_credits) ----
	# Accept both a disable quest and an earn_credits quest; complete + claim the disable one; then feed
	# its credit reward as the server would. The claimed quest must NOT re-progress; the OTHER quest must.
	var q := Quest.accept(Quest.initial_quests(), "q_pest_control")
	q = Quest.accept(q, "q_hustle_500")  # earn_credits 500
	for ck in ["womp_rat", "hitcher_crab", "scurrier"]:
		q = Quest.record_event(q, defs, {"type": "disable", "creature_key": ck})
	_assert_equal(bool((q["q_pest_control"] as Dictionary)["complete"]), true, "3 disables complete the kill quest")
	var claim := Quest.claim(q, defs, "q_pest_control")
	_assert_equal(bool(claim["ok"]), true, "claim ok")
	var reward_credits := int((claim["reward"] as Dictionary)["credits"])
	_assert_equal(reward_credits, 180, "kill-quest reward is 180 credits")
	q = claim["quests"]
	# the server now routes those 180 credits through _award_credits -> _feed_quest_event(credits)
	q = Quest.record_event(q, defs, {"type": "credits", "amount": reward_credits})
	_assert_equal(bool((q["q_pest_control"] as Dictionary)["claimed"]), true, "claimed quest stays claimed after a later credit feed")
	_assert_equal(int((q["q_pest_control"] as Dictionary)["progress"]), 3, "claimed quest does not re-progress")
	_assert_equal(int((q["q_hustle_500"] as Dictionary)["progress"]), reward_credits, "the reward credits advance the OTHER earn_credits quest")
	_assert_equal(bool((q["q_hustle_500"] as Dictionary)["complete"]), false, "180 < 500 so it is not yet complete")

	if _failures.is_empty():
		print("quest_live_flow_smoke: OK")
		quit(0)
	else:
		for fail in _failures:
			printerr(fail)
		quit(1)

# Mirror of NetworkManager._record_quests: a record's quest block, backfilling a legacy record.
func _record_quests(record: Dictionary) -> Dictionary:
	var qv: Variant = record.get("quests", null)
	return qv if typeof(qv) == TYPE_DICTIONARY else Quest.initial_quests()

func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % path)
		return {}
	return parsed

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
