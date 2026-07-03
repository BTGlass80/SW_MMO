extends SceneTree
## Bounty-book persistence round-trip guard (DIV-0022). The bounty book is the ONLY persisted consent
## state (duels are in-memory), stored in world_state.dat next to the territory ledger. This mirrors the
## territory persistence coverage: serialize -> JSON stringify -> parse (which widens ints to float) ->
## apply_persisted_bounties, and assert the standing contracts survive with typed ints and still resolve.

const PvpConsent := preload("res://scripts/rules/pvp_consent_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# Build a book with a stacked, multi-contributor contract + a second single contract.
	var st := PvpConsent.new_state()
	st = PvpConsent.place_bounty(st, "char_dax", "char_vask", 1000, 1000.0)["state"]
	st = PvpConsent.place_bounty(st, "char_ric", "char_vask", 500, 1300.0)["state"]
	st = PvpConsent.place_bounty(st, "char_dax", "char_greeb", 250, 1400.0)["state"]
	_assert_equal(PvpConsent.bounty_pot(st, "char_vask"), 1500, "pre-save: char_vask pot accumulated to 1500")

	# Serialize -> JSON round-trip (the world_state.dat path) -> restore onto a FRESH state.
	var book := PvpConsent.bounties_to_dict(st)
	var world := {"bounties": book}  # exactly how _save_world_state nests it
	var text := JSON.stringify(world, "\t")
	var parsed: Variant = JSON.parse_string(text)
	_assert_true(typeof(parsed) == TYPE_DICTIONARY, "the persisted world blob parses back to a Dictionary")
	var restored := PvpConsent.apply_persisted_bounties(PvpConsent.new_state(), (parsed as Dictionary).get("bounties", {}))

	# The contracts survive with the RIGHT pots and typed ints (JSON widened them to float mid-flight).
	_assert_true(PvpConsent.has_bounty(restored, "char_vask"), "char_vask's contract survived the restart")
	_assert_true(PvpConsent.has_bounty(restored, "char_greeb"), "char_greeb's contract survived the restart")
	_assert_equal(PvpConsent.bounty_pot(restored, "char_vask"), 1500, "the accumulated pot restored exactly")
	_assert_equal(PvpConsent.bounty_pot(restored, "char_greeb"), 250, "the single contract restored exactly")
	var rec: Dictionary = (restored.get("bounties", {}) as Dictionary).get("char_vask", {})
	_assert_equal(typeof(rec.get("pot_credits")), TYPE_INT, "pot_credits is re-int'd (not a JSON float)")
	_assert_equal(typeof((rec.get("contributors", []) as Array).size()), TYPE_INT, "contributors restored as an array")
	_assert_equal((rec.get("contributors", []) as Array).size(), 2, "both of char_vask's contributors survived")
	_assert_equal(typeof(((rec.get("contributors", []) as Array)[0] as Dictionary).get("amount")), TYPE_INT, "a contributor amount is re-int'd")

	# The restored book still ENFORCES eligibility (a restart must not lose the anti-self-collect guard).
	_assert_true(PvpConsent.bounty_eligible(restored, "char_hunter", "char_vask", "lawless"), "a hunter is still eligible post-restart")
	_assert_true(not PvpConsent.bounty_eligible(restored, "char_dax", "char_vask", "lawless"), "a contributor is still blocked post-restart")

	# And collection still pays the right pot + clears the record.
	var col := PvpConsent.collect_bounty(restored, "char_vask", "char_hunter")
	_assert_equal(int(col.get("payout", 0)), 1500, "post-restart collection pays the full restored pot")
	_assert_true(not PvpConsent.has_bounty(col["state"], "char_vask"), "the restored contract clears on collection")

	if _failures.is_empty():
		print("bounty_persistence_smoke: OK")
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
