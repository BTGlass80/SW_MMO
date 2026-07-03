extends SceneTree
## Smoke for the pure dialogue-selection model. Deterministic, NO RNG. Loads the real
## data/npcs_clone_wars.json, then checks: npcs_from_data parses; greeting returns the opening line
## (and a non-empty role fallback when there are no lines); next_line rotates deterministically and
## never errors on an empty dialogue_lines list; faction_flavor is deterministic and axis-aware.

const Dialogue = preload("res://scripts/rules/dialogue_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- load + parse the real data file ---
	var f := FileAccess.open("res://data/npcs_clone_wars.json", FileAccess.READ)
	_assert_true(f != null, "npcs data file opens")
	var data: Dictionary = JSON.parse_string(f.get_as_text()) if f != null else {}
	var npcs := Dialogue.npcs_from_data(data)
	_assert_true(npcs.has("wuher") and npcs.has("venn_kator") and npcs.has("djas_puhr"), "npcs_from_data keys by id")
	_assert_true(npcs.size() >= 15, "all named NPCs parse (>= the seed roster; got %d)" % npcs.size())

	# --- greeting returns the first dialogue line for a real NPC ---
	var wuher: Dictionary = npcs["wuher"]
	_assert_equal(Dialogue.greeting(wuher), "You drinking, or just taking up space?", "greeting is the first line")
	_assert_equal(Dialogue.greeting(wuher), Dialogue.next_line(wuher, 0), "greeting == next_line at talk_count 0")

	# --- greeting falls back to a non-empty role default when there are no lines ---
	var mute := {"id": "mute_guard", "name": "Silent Sentry", "role": "gate sentry", "faction_axis": "hutt", "dialogue_lines": []}
	var fb := Dialogue.greeting(mute)
	_assert_true(fb != "", "empty-lines NPC still greets with a non-empty fallback")
	# robust to a totally missing dialogue_lines field, too
	var no_field := {"id": "x", "role": "drifter"}
	_assert_true(Dialogue.greeting(no_field) != "", "missing dialogue_lines field falls back non-empty")

	# --- next_line cycles deterministically over a 3-line NPC: 0,1,2,3 -> lines 0,1,2,0 ---
	var three := {
		"id": "three_liner",
		"name": "Test Trader",
		"role": "trader",
		"faction_axis": "independent",
		"dialogue_lines": ["line-A", "line-B", "line-C"],
	}
	_assert_equal(Dialogue.next_line(three, 0), "line-A", "talk 0 -> line 0")
	_assert_equal(Dialogue.next_line(three, 1), "line-B", "talk 1 -> line 1")
	_assert_equal(Dialogue.next_line(three, 2), "line-C", "talk 2 -> line 2")
	_assert_equal(Dialogue.next_line(three, 3), "line-A", "talk 3 wraps back to line 0")
	_assert_equal(Dialogue.next_line(three, 4), "line-B", "talk 4 -> line 1")
	_assert_equal(Dialogue.next_line(three, -1), "line-C", "negative talk_count wraps via posmod")
	# same cycle holds on a real 3-line NPC (venn_kator)
	var venn: Dictionary = npcs["venn_kator"]
	_assert_equal(Dialogue.next_line(venn, 3), Dialogue.next_line(venn, 0), "real 3-line NPC cycles at talk 3")

	# --- next_line never errors on an empty dialogue_lines list ---
	_assert_true(Dialogue.next_line(mute, 0) != "", "empty-lines next_line(0) is a non-empty fallback")
	_assert_true(Dialogue.next_line(mute, 7) != "", "empty-lines next_line(7) never crashes, stays non-empty")

	# --- faction_flavor: deterministic + axis-aware ---
	var rep := {"id": "trooper", "name": "Trooper", "role": "clone", "faction_axis": "republic"}
	var aligned := Dialogue.faction_flavor(rep, "republic")
	var opposed := Dialogue.faction_flavor(rep, "cis")
	var neutral := Dialogue.faction_flavor(rep, "independent")
	_assert_true(aligned != "", "shared axis yields a non-empty (friendly) prefix")
	_assert_true(opposed != "", "opposed axis yields a non-empty (cool) prefix")
	_assert_equal(neutral, "", "neutral axis yields no prefix")
	_assert_true(aligned != opposed, "friendly and cool prefixes differ")
	_assert_equal(Dialogue.faction_flavor(rep, ""), "", "empty player axis is neutral")
	# determinism: identical inputs always give identical output
	_assert_equal(Dialogue.faction_flavor(rep, "republic"), aligned, "faction_flavor is deterministic (aligned)")
	_assert_equal(Dialogue.faction_flavor(rep, "cis"), opposed, "faction_flavor is deterministic (opposed)")
	# relation helper sanity
	_assert_equal(Dialogue.faction_relation("hutt", "republic"), "opposed", "hutt vs republic is opposed")
	_assert_equal(Dialogue.faction_relation("independent", "independent"), "aligned", "same axis is aligned")
	_assert_equal(Dialogue.faction_relation("bounty_hunters_guild", "cis"), "neutral", "guild is neutral to CIS")

	# --- convenience combiner is just flavor + next_line ---
	_assert_equal(Dialogue.line_with_flavor(rep, 0, "cis"), opposed + Dialogue.next_line(rep, 0), "line_with_flavor composes flavor + next_line")

	if _failures.is_empty():
		print("dialogue_model_smoke: OK")
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
