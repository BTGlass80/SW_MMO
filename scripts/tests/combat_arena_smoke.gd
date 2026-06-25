extends SceneTree
## Headless smoke test for the server-authoritative combat arena (M1.3).
## Verifies: a fire intent resolves to a versioned combat envelope; resolution is
## deterministic under a fixed server seed (replayable/auditable); damage does not
## decrease; multiple shooters each get an envelope; an empty window is a no-op; and
## a disabled target reports already-disabled. All dice are server-owned here.

const CombatArena := preload("res://scripts/net/combat_arena.gd")

var _failures: Array[String] = []
var _rules: Object

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	var data := _combat_data()

	# 1. A single fire intent resolves to one well-formed envelope.
	var a1 := CombatArena.new(_rules, data)
	a1.register_player(2, "Mara")
	a1.set_player_name(2, "Mara Jade")  # M1.5: chosen display name flows into envelopes
	a1.submit_fire_intent(2, {"aim": 3})
	var r1: Dictionary = a1.resolve_window(4242)
	var env1: Array = r1.get("envelopes", [])
	_assert_equal(env1.size(), 1, "one shooter yields one envelope")
	if env1.size() == 1:
		var e: Dictionary = env1[0]
		_assert_equal(String(e.get("message_type", "")), "combat.exchange.resolved", "envelope message type")
		_assert_equal(int(e.get("shooter_id", -1)), 2, "envelope carries shooter id")
		_assert_equal(String(e.get("shooter_name", "")), "Mara Jade", "envelope carries the chosen display name")
		_assert_true(int(e.get("event_count", 0)) > 0, "envelope carries combat events")
		_assert_true(e.has("action_window"), "envelope carries the action window summary")

	# 2. Determinism: same seed + same setup => identical target outcome.
	var a2 := CombatArena.new(_rules, data)
	a2.register_player(2, "Mara")
	a2.submit_fire_intent(2, {"aim": 3})
	var r2: Dictionary = a2.resolve_window(4242)
	_assert_equal(
		int((r2.get("target_state", {}) as Dictionary).get("wound_severity", -1)),
		int((r1.get("target_state", {}) as Dictionary).get("wound_severity", -2)),
		"same server seed reproduces the same target outcome"
	)

	# 3. Empty window is a no-op (intents were consumed in step 1).
	var r_empty: Dictionary = a1.resolve_window(99)
	_assert_equal((r_empty.get("envelopes", []) as Array).size(), 0, "no intents => no envelopes")

	# 4. Two shooters each get an envelope in one window.
	var b := CombatArena.new(_rules, data)
	b.register_player(2, "A")
	b.register_player(3, "B")
	b.submit_fire_intent(2, {"aim": 3})
	b.submit_fire_intent(3, {"aim": 3})
	var rb: Dictionary = b.resolve_window(777)
	_assert_equal((rb.get("envelopes", []) as Array).size(), 2, "two shooters yield two envelopes")

	# 5. Damage never decreases across windows (severity is a max).
	var c := CombatArena.new(_rules, data)
	c.register_player(2, "A")
	var prev := 0
	var monotone := true
	for w in range(15):
		c.submit_fire_intent(2, {"aim": 3})
		c.resolve_window(2000 + w)
		var sev := int(c.target_state().get("wound_severity", 0))
		if sev < prev:
			monotone = false
		prev = sev
	_assert_true(monotone, "target wound severity is monotonic across windows")

	# 6. A target reaches disabled and then reports already-disabled.
	var d := CombatArena.new(_rules, data)
	d.register_player(2, "A")
	var disabled := false
	for w in range(80):
		d.submit_fire_intent(2, {"aim": 3})
		d.resolve_window(3000 + w)
		if d.target_disabled():
			disabled = true
			break
	_assert_true(disabled, "sustained fire disables the training target")
	if disabled:
		d.submit_fire_intent(2, {"aim": 3})
		var rd: Dictionary = d.resolve_window(9001)
		var de: Array = rd.get("envelopes", [])
		_assert_true(de.size() == 1 and bool((de[0].get("flags", {}) as Dictionary).get("already_disabled", false)), "firing at a disabled target reports already-disabled")

	if _rules.has_method("free"):
		_rules.free()
	_finish()

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {
			"blaster": "4D+1", "dodge": "4D", "soak": "3D",
			"weapon": "training_blaster", "armor": "blast_vest", "scale": "character",
		},
		"weapons": {
			"training_blaster": {"damage": "4D"},
			"remote_stun_blaster": {"damage": "3D+2"},
		},
		"armors": {
			"blast_vest": {"protection_energy": "0D+1", "protection_physical": "1D", "dexterity_penalty": "-1D", "coverage": ["torso"]},
		},
		"targets": {
			"b1_training_silhouette": {
				"blaster": "3D", "weapon": "remote_stun_blaster", "soak": "2D",
				"scale": "character", "distance": 12.0, "cover_level": 0, "name": "B1 Training Remote",
			},
		},
	}

func _finish() -> void:
	if _failures.is_empty():
		print("combat_arena_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
