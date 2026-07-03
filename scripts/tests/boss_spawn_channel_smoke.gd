extends SceneTree

# Wave G / G15 (DIV-0028) FIX: the boss/event channel. Pure + seeded (server owns RNG), no nodes, no
# randomize(). Proves the doc/ledger "boss channel" claim is REAL in the wire, and that every SHIPPED
# disable-bounty naming a boss-class creature is completable through it. Asserts:
#   (1) creature_spawn_model.boss_spawn builds a valid, HOSTILE spawn (matching creature_key, tier 5)
#       for each boss key (krayt_dragon / merdeth / rancor);
#   (2) boss_spawn REFUSES a non-boss key (that belongs to the ambient path) and an unknown key -> {};
#   (3) it is deterministic (same seed -> identical spawn);
#   (4) the ambient roll_spawn still NEVER yields a boss key (the channel is the only boss path);
#   (5) CONTENT GUARANTEE: for every shipped disable quest whose objective.target_key is boss-class,
#       boss_spawn produces a hostile spawn AND a quest_model disable event with that creature_key
#       drives the quest to complete — i.e. q_krayt_bounty / q_rancor_sighting are NOT dead quests.

const CREATURE_DATA_PATH = "res://data/creatures_clone_wars.json"
const QUEST_DATA_PATH = "res://data/quests_clone_wars.json"
const BOSS_KEYS = ["krayt_dragon", "merdeth", "rancor"]
const NON_BOSS_KEYS = ["glim_worm", "acklay", "bantha", "tymp"]  # ambient (incl. tier-4 apex acklay)
const QuestModel = preload("res://scripts/rules/quest_model.gd")

var _failures = []

func _init() -> void:
	var model = load("res://scripts/rules/creature_spawn_model.gd").new()
	var creatures_data = _load_json(CREATURE_DATA_PATH)
	var creatures: Dictionary = creatures_data.get("creatures", {})
	_assert_true(not creatures.is_empty(), "creature data has creatures")

	# (1) boss_spawn builds a valid hostile spawn for each boss key.
	for boss in BOSS_KEYS:
		_assert_true(creatures.has(boss), "boss key %s present in data" % boss)
		_assert_true(model.is_boss_key(creatures_data, boss), "is_boss_key true for %s" % boss)
		var spawn: Dictionary = model.boss_spawn(creatures_data, boss, 12345)
		_assert_true(not spawn.is_empty(), "boss_spawn(%s) is non-empty" % boss)
		_assert_equal(String(spawn.get("creature_key", "")), boss, "boss_spawn(%s) creature_key" % boss)
		_assert_true(bool(spawn.get("hostile", false)), "boss_spawn(%s) is hostile (a fightable target)" % boss)
		_assert_equal(int(spawn.get("threat_tier", 0)), 5, "boss_spawn(%s) carries tier 5" % boss)
		_assert_true(int(spawn.get("pack_size", 0)) >= 1, "boss_spawn(%s) pack_size >= 1" % boss)

	# (2) boss_spawn REFUSES a non-boss key and an unknown key.
	for nb in NON_BOSS_KEYS:
		_assert_true(not model.is_boss_key(creatures_data, nb), "is_boss_key false for non-boss %s" % nb)
		_assert_true(model.boss_spawn(creatures_data, nb, 7).is_empty(), "boss_spawn refuses non-boss %s -> {}" % nb)
	_assert_true(not model.is_boss_key(creatures_data, "not_a_real_creature"), "is_boss_key false for unknown key")
	_assert_true(model.boss_spawn(creatures_data, "not_a_real_creature", 7).is_empty(), "boss_spawn refuses unknown key -> {}")

	# (3) determinism: same seed -> identical spawn.
	var a: Dictionary = model.boss_spawn(creatures_data, "krayt_dragon", 99)
	var b: Dictionary = model.boss_spawn(creatures_data, "krayt_dragon", 99)
	_assert_equal(String(a.get("creature_key", "")), String(b.get("creature_key", "")), "boss_spawn deterministic (creature_key)")
	_assert_equal(int(a.get("pack_size", -1)), int(b.get("pack_size", -2)), "boss_spawn deterministic (pack_size)")

	# (4) the ambient roll_spawn NEVER yields a boss at even the hottest band (the channel is the only path).
	for s in range(2000):
		var pick := String(model.roll_spawn(creatures_data, "lockdown", "lawless", s * 17 + 3).get("creature_key", ""))
		if BOSS_KEYS.has(pick):
			_failures.append("ambient roll_spawn leaked boss %s (seed idx %d)" % [pick, s])
			break

	# (5) CONTENT GUARANTEE: every shipped disable quest with a boss target is completable end-to-end.
	var quest_data = _load_json(QUEST_DATA_PATH)
	var boss_bounties := 0
	for q in quest_data.get("quests", []):
		var qd: Dictionary = q
		var objective: Dictionary = qd.get("objective", {})
		if String(objective.get("kind", "")) != "disable":
			continue
		var target := String(objective.get("target_key", ""))
		if target == "" or not model.is_boss_key(creatures_data, target):
			continue
		boss_bounties += 1
		var qid := String(qd.get("id", ""))
		# The boss/event channel can spawn this bounty's target.
		var spawn: Dictionary = model.boss_spawn(creatures_data, target, 4242)
		_assert_true(not spawn.is_empty(), "%s: boss target %s is spawnable via boss_spawn" % [qid, target])
		_assert_equal(String(spawn.get("creature_key", "")), target, "%s: spawn creature_key matches target %s" % [qid, target])
		# ...and a disable event carrying that creature_key drives the quest to complete.
		var defs := QuestModel.defs_from_data(quest_data)
		var count := int(objective.get("count", 1))
		var quests := QuestModel.accept(QuestModel.initial_quests(), qid)
		for _i in range(count):
			quests = QuestModel.record_event(quests, defs, {"type": "disable", "creature_key": String(spawn.get("creature_key", ""))})
		_assert_true(QuestModel.is_complete(quests, qid), "%s completes from %d boss-channel disable(s)" % [qid, count])
	# Guard the guard: the shipped roster HAS boss bounties (else this section is vacuously green).
	_assert_true(boss_bounties >= 2, "shipped roster has >= 2 boss disable-bounties (q_krayt_bounty + q_rancor_sighting), found %d" % boss_bounties)

	if _failures.is_empty():
		print("boss_spawn_channel_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _load_json(path):
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % path)
		return {}
	return parsed

func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
