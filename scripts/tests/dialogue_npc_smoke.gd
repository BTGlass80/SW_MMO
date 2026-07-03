extends SceneTree
## Integration smoke: scripts/rules/dialogue_model.gd against the REAL data/npcs_clone_wars.json.
## dialogue_model_smoke.gd already unit-tests the model with a few spot-checked NPCs; this test
## instead walks EVERY named NPC in the real data (plus a synthetic empty-dialogue_lines entry,
## since none of the 15 shipped entries happen to ship empty), proving greeting()/next_line()
## never crash and always return non-empty text, that next_line() cycles deterministically
## against each NPC's own real line count, and that faction_flavor() is deterministic across
## the game's real faction axes (both as declared in the data and as carried by real NPCs).

const Dialogue := preload("res://scripts/rules/dialogue_model.gd")

var _failures: Array[String] = []

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	_assert_true(f != null, "%s opens" % path)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _init() -> void:
	var data := _load_json("res://data/npcs_clone_wars.json")
	var npcs := Dialogue.npcs_from_data(data)
	var raw_npcs: Array = data.get("npcs", [])
	_assert_equal(npcs.size(), raw_npcs.size(), "npcs_from_data parses every real NPC by id")
	_assert_true(npcs.size() >= 1, "the real data actually has named NPCs (test isn't vacuous)")

	# The real data ships every NPC with non-empty dialogue_lines today; append a synthetic
	# empty-lines entry so the "never crash on any real entry, incl. any with empty
	# dialogue_lines" requirement is genuinely exercised even though none of the 15 shipped
	# entries happen to be empty.
	var all_ids: Array = npcs.keys()
	var synthetic_empty := {"id": "__synthetic_empty_lines__", "name": "Silent Sentry", "role": "gate sentry", "faction_axis": "hutt", "dialogue_lines": []}
	var synthetic_id := String(synthetic_empty["id"])
	npcs[synthetic_id] = synthetic_empty
	all_ids.append(synthetic_id)

	var saw_empty := false
	for id in all_ids:
		var npc: Dictionary = npcs[id]
		var lines := Dialogue.lines_of(npc)
		if lines.is_empty():
			saw_empty = true

		# --- greeting() never crashes and is always non-empty ---
		var greet := Dialogue.greeting(npc)
		_assert_true(greet != "", "NPC '%s' greeting() is non-empty" % id)
		if not lines.is_empty():
			_assert_equal(greet, String(lines[0]), "NPC '%s' greeting() == its first dialogue line" % id)
			_assert_equal(greet, Dialogue.next_line(npc, 0), "NPC '%s' greeting() == next_line(npc, 0)" % id)

		# --- next_line(npc, 0..4) never crashes, is always non-empty, and cycles deterministically ---
		var seen: Array[String] = []
		for talk_count in range(5):
			var line := Dialogue.next_line(npc, talk_count)
			_assert_true(line != "", "NPC '%s' next_line(%d) is non-empty" % [id, talk_count])
			seen.append(line)
			_assert_equal(Dialogue.next_line(npc, talk_count), line, "NPC '%s' next_line(%d) is deterministic across repeat calls" % [id, talk_count])
		if not lines.is_empty():
			var n := lines.size()
			for talk_count in range(5):
				_assert_equal(seen[talk_count], String(lines[talk_count % n]), "NPC '%s' next_line(%d) cycles mod its %d real dialogue lines" % [id, talk_count, n])
		else:
			for talk_count in range(5):
				_assert_equal(seen[talk_count], seen[0], "NPC '%s' (empty dialogue_lines) next_line is the same non-empty fallback at every talk_count" % id)

	_assert_true(saw_empty, "the empty-dialogue_lines edge case was actually exercised (via the synthetic entry)")

	# --- faction_flavor is deterministic across the real faction axes declared in the data,
	# in every (npc_axis, player_axis) combination ---
	var axes: Array = data.get("faction_axes", [])
	_assert_true(axes.size() >= 2, "the real data declares at least two faction axes")
	for npc_axis in axes:
		for player_axis in axes:
			var probe := {"id": "probe", "name": "Probe", "role": "probe", "faction_axis": String(npc_axis)}
			var flavor_a := Dialogue.faction_flavor(probe, String(player_axis))
			var flavor_b := Dialogue.faction_flavor(probe, String(player_axis))
			_assert_equal(flavor_b, flavor_a, "faction_flavor(npc_axis=%s, player_axis=%s) is deterministic across repeat calls" % [String(npc_axis), String(player_axis)])
			var relation := Dialogue.faction_relation(String(npc_axis), String(player_axis))
			if relation == "aligned":
				_assert_true(flavor_a != "", "aligned axis pair (%s, %s) yields a non-empty flavor prefix" % [String(npc_axis), String(player_axis)])
			elif relation == "neutral":
				_assert_equal(flavor_a, "", "neutral axis pair (%s, %s) yields no flavor prefix" % [String(npc_axis), String(player_axis)])

	# --- faction_flavor is deterministic for every REAL NPC's actual faction_axis, too ---
	for id in npcs:
		if id == synthetic_id:
			continue
		var npc: Dictionary = npcs[id]
		for player_axis in axes:
			var flavor_a := Dialogue.faction_flavor(npc, String(player_axis))
			var flavor_b := Dialogue.faction_flavor(npc, String(player_axis))
			_assert_equal(flavor_b, flavor_a, "NPC '%s' faction_flavor(player_axis=%s) is deterministic" % [id, String(player_axis)])

	if _failures.is_empty():
		print("dialogue_npc_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
