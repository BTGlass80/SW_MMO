extends SceneTree
## Pure-model smoke for scripts/rules/player_status_badge_model.gd.
## Covers: healthy = inactive/no badge; each single status; the PRIORITY when several
## statuses stack (held + poisoned + wounded -> the right top badge + a coherent combined
## readout); the poison count text; and the boundary (poison_rounds_left 0 = not poisoned).

const StatusBadge = preload("res://scripts/rules/player_status_badge_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- healthy + clean = INACTIVE (no badge, empty combined) ---
	var healthy := StatusBadge.badge_for("healthy", 0, false)
	_assert_equal(healthy["active"], false, "healthy inactive")
	_assert_equal(healthy["text"], "", "healthy empty text")
	_assert_equal(healthy["combined"], "", "healthy empty combined")
	_assert_equal(healthy["priority"], StatusBadge.PRIORITY_HEALTHY, "healthy priority 0")
	_assert_equal((healthy["parts"] as Array).size(), 0, "healthy no parts")

	# empty / unknown-blank wound is also inactive when clean
	_assert_equal(StatusBadge.badge_for("", 0, false)["active"], false, "blank wound inactive")

	# --- single: hurt (stunned / wounded / wounded_twice) ---
	var stunned := StatusBadge.badge_for("stunned", 0, false)
	_assert_equal(stunned["active"], true, "stunned active")
	_assert_equal(stunned["text"], "Stunned", "stunned text matches _condition_pretty")
	_assert_equal(stunned["color_key"], "stunned", "stunned color_key")
	_assert_equal(stunned["priority"], StatusBadge.PRIORITY_HURT, "stunned priority hurt")
	_assert_equal(stunned["combined"], "Stunned", "stunned combined")

	var wounded := StatusBadge.badge_for("wounded", 0, false)
	_assert_equal(wounded["text"], "Wounded", "wounded text")
	_assert_equal(wounded["color_key"], "wounded", "wounded color_key")

	var wounded_twice := StatusBadge.badge_for("wounded_twice", 0, false)
	_assert_equal(wounded_twice["text"], "Wounded Twice", "wounded_twice text")
	_assert_equal(wounded_twice["color_key"], "wounded", "wounded_twice shares wounded color")
	_assert_equal(wounded_twice["priority"], StatusBadge.PRIORITY_HURT, "wounded_twice is hurt not downed")

	# --- single: downed (incapacitated / mortally_wounded / dead) ---
	var incap := StatusBadge.badge_for("incapacitated", 0, false)
	_assert_equal(incap["active"], true, "incap active")
	_assert_equal(incap["text"], "Incapacitated", "incap text")
	_assert_equal(incap["short"], "DOWN", "incap short DOWN")
	_assert_equal(incap["color_key"], "downed", "incap color_key downed")
	_assert_equal(incap["priority"], StatusBadge.PRIORITY_DOWNED, "incap priority downed")

	_assert_equal(StatusBadge.badge_for("mortally_wounded", 0, false)["text"], "Mortally Wounded", "mortally text")
	_assert_equal(StatusBadge.badge_for("dead", 0, false)["text"], "Dead", "dead text")
	_assert_equal(StatusBadge.badge_for("dead", 0, false)["priority"], StatusBadge.PRIORITY_DOWNED, "dead downed priority")
	# unknown non-healthy wound is treated as serious (downed/red), like the legacy nameplate
	_assert_equal(StatusBadge.badge_for("liquefied", 0, false)["color_key"], "downed", "unknown wound -> downed color")

	# --- single: restrained ("Held") on an otherwise healthy player ---
	var held := StatusBadge.badge_for("healthy", 0, true)
	_assert_equal(held["active"], true, "held active on healthy")
	_assert_equal(held["text"], "Held", "held text")
	_assert_equal(held["short"], "Held", "held short")
	_assert_equal(held["color_key"], "restrained", "held color_key")
	_assert_equal(held["priority"], StatusBadge.PRIORITY_RESTRAINED, "held priority")

	# --- single: poisoned + the count text / short "☠ n" ---
	var poisoned := StatusBadge.badge_for("healthy", 3, false)
	_assert_equal(poisoned["active"], true, "poisoned active on healthy")
	_assert_equal(poisoned["text"], "Poisoned (3)", "poison count text")
	_assert_equal(poisoned["short"], "☠ 3", "poison short skull count")
	_assert_equal(poisoned["color_key"], "poisoned", "poison color_key")
	_assert_equal(poisoned["priority"], StatusBadge.PRIORITY_POISONED, "poison priority")
	# a different count flows into the text
	_assert_equal(StatusBadge.badge_for("healthy", 1, false)["text"], "Poisoned (1)", "poison count 1")

	# --- boundary: poison_rounds_left 0 = NOT poisoned ---
	_assert_equal(StatusBadge.badge_for("healthy", 0, false)["active"], false, "poison 0 inactive")
	# negative is also treated as clear
	_assert_equal(StatusBadge.badge_for("healthy", -2, false)["active"], false, "poison negative inactive")

	# --- PRIORITY when statuses stack ---
	# held + poisoned + wounded -> top badge is "Held" (restrained > poisoned > hurt),
	# combined readout ordered by priority.
	var stacked := StatusBadge.badge_for("wounded", 4, true)
	_assert_equal(stacked["text"], "Held", "stack top = Held (restrained beats poison+wound)")
	_assert_equal(stacked["priority"], StatusBadge.PRIORITY_RESTRAINED, "stack top priority = restrained")
	_assert_equal(stacked["combined"], "Held · Poisoned (4) · Wounded", "stack combined priority order")
	_assert_equal((stacked["parts"] as Array).size(), 3, "stack has 3 parts")

	# downed + held + poisoned -> downed wins the top badge; the wound leads the combined.
	var downed_stack := StatusBadge.badge_for("incapacitated", 3, true)
	_assert_equal(downed_stack["text"], "Incapacitated", "downed beats held+poison")
	_assert_equal(downed_stack["priority"], StatusBadge.PRIORITY_DOWNED, "downed top priority")
	_assert_equal(downed_stack["combined"], "Incapacitated · Held · Poisoned (3)", "downed stack combined")

	# poisoned + wounded (no held) -> poison wins, wound trails.
	var poison_wound := StatusBadge.badge_for("wounded", 2, false)
	_assert_equal(poison_wound["text"], "Poisoned (2)", "poison beats wound")
	_assert_equal(poison_wound["combined"], "Poisoned (2) · Wounded", "poison+wound combined")

	# --- extra_status_text: the non-wound HUD suffix (Held / Poisoned only) ---
	_assert_equal(StatusBadge.extra_status_text(0, false), "", "no extra when clean")
	_assert_equal(StatusBadge.extra_status_text(2, false), "Poisoned (2)", "extra poison only")
	_assert_equal(StatusBadge.extra_status_text(0, true), "Held", "extra held only")
	_assert_equal(StatusBadge.extra_status_text(5, true), "Held · Poisoned (5)", "extra both, held first")

	# --- from_entry: null-safe snapshot read (fields absent when inactive) ---
	_assert_equal(StatusBadge.from_entry({"wound": "healthy"})["active"], false, "from_entry clean healthy inactive")
	_assert_equal(StatusBadge.from_entry({})["active"], false, "from_entry empty dict inactive")
	var entry_badge := StatusBadge.from_entry({"wound": "wounded", "status_poison_rounds_left": 3, "status_restrained": true})
	_assert_equal(entry_badge["text"], "Held", "from_entry stacked top = Held")
	_assert_equal(entry_badge["combined"], "Held · Poisoned (3) · Wounded", "from_entry combined")
	# also honors the "wound_state" alias
	_assert_equal(StatusBadge.from_entry({"wound_state": "stunned"})["text"], "Stunned", "from_entry wound_state alias")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("player_status_badge_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
