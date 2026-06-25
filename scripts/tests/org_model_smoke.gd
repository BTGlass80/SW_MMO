extends SceneTree
## Headless smoke test for the org-membership + claim-command validator (Wave E9).
## Verifies: one-faction membership validation (axis, rank, guild cap), the FIRST-
## failure reason vocabulary, the claim-command denial ordering (rank -> secured_zone
## -> influence), and that it COMPOSES with the real territory_model thresholds
## (CLAIM_MIN_INFLUENCE / CLAIMABLE_BASES) rather than hardcoding duplicates.

const Org := preload("res://scripts/net/org_model.gd")
const Territory := preload("res://scripts/net/territory_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var org: Org = Org.new()

	# A canonical valid one-faction member with 2 guilds.
	var member := {
		"faction_id": "org_hutt_cartel",
		"faction_axis": "hutt",
		"faction_rank": 4,
		"faction_rep": 62,
		"guild_ids": ["guild_slicers", "guild_smugglers"],
		"faction_switch_cooldown_unix": 0,
	}

	# --- validate_membership: happy path ---
	var v_ok: Dictionary = org.validate_membership(member)
	_assert_true(bool(v_ok["valid"]), "one-faction member with 2 guilds validates")
	_assert_equal(String(v_ok["reason"]), "", "valid membership has empty reason")
	_assert_true(org.is_member(member), "is_member true for a valid record")
	_assert_equal(org.guild_count(member), 2, "guild_count counts the two guilds")

	# --- validate_membership: faction_id null -> no_faction ---
	var no_faction: Dictionary = member.duplicate()
	no_faction["faction_id"] = null
	var v_no_faction: Dictionary = org.validate_membership(no_faction)
	_assert_true(not bool(v_no_faction["valid"]), "null faction_id is invalid")
	_assert_equal(String(v_no_faction["reason"]), "no_faction", "null faction_id reason is no_faction")
	_assert_true(not org.is_member(no_faction), "is_member false for a null-faction record")

	# Empty-string faction_id is also no_faction.
	var empty_faction: Dictionary = member.duplicate()
	empty_faction["faction_id"] = ""
	_assert_equal(String(org.validate_membership(empty_faction)["reason"]), "no_faction", "empty faction_id reason is no_faction")

	# --- validate_membership: bad axis ---
	var bad_axis: Dictionary = member.duplicate()
	bad_axis["faction_axis"] = "imperial"
	_assert_equal(String(org.validate_membership(bad_axis)["reason"]), "bad_axis", "out-of-vocab axis reason is bad_axis")

	# --- validate_membership: negative rank ---
	var neg_rank: Dictionary = member.duplicate()
	neg_rank["faction_rank"] = -1
	_assert_equal(String(org.validate_membership(neg_rank)["reason"]), "negative_rank", "negative rank reason is negative_rank")

	# Rank 0 is a valid (non-negative) rank.
	var rank0: Dictionary = member.duplicate()
	rank0["faction_rank"] = 0
	_assert_true(bool(org.validate_membership(rank0)["valid"]), "rank 0 is a valid non-negative rank")

	# --- validate_membership: too many guilds ---
	var four_guilds: Dictionary = member.duplicate()
	four_guilds["guild_ids"] = ["g1", "g2", "g3", "g4"]
	var v_four: Dictionary = org.validate_membership(four_guilds)
	_assert_true(not bool(v_four["valid"]), "4 guilds is invalid")
	_assert_equal(String(v_four["reason"]), "too_many_guilds", "4 guilds reason is too_many_guilds")
	_assert_equal(org.guild_count(four_guilds), 4, "guild_count reports the raw count")

	# Exactly MAX_GUILDS (3) is allowed.
	var three_guilds: Dictionary = member.duplicate()
	three_guilds["guild_ids"] = ["g1", "g2", "g3"]
	_assert_true(bool(org.validate_membership(three_guilds)["valid"]), "exactly MAX_GUILDS guilds validates")

	# --- can_claim_command: composes membership rank + territory thresholds ---
	# Sanity-bind the test to the REAL territory_model constants.
	_assert_equal(Territory.CLAIM_MIN_INFLUENCE, 20, "territory CLAIM_MIN_INFLUENCE is 20 (one source of truth)")
	_assert_true(Territory.CLAIMABLE_BASES.has("contested"), "contested is claimable per territory_model")
	_assert_true(Territory.CLAIMABLE_BASES.has("lawless"), "lawless is claimable per territory_model")
	_assert_true(not Territory.CLAIMABLE_BASES.has("secured"), "secured is NOT claimable per territory_model")

	var ample: int = Territory.CLAIM_MIN_INFLUENCE + 50   # well over the floor

	# Rank 2 (below RANK_CLAIM) in a contested zone with ample influence -> rank.
	var rank2: Dictionary = member.duplicate()
	rank2["faction_rank"] = 2
	var c_rank: Dictionary = org.can_claim_command(rank2, "contested", ample)
	_assert_true(not bool(c_rank["allowed"]), "rank 2 cannot claim")
	_assert_equal(String(c_rank["reason"]), "rank", "below RANK_CLAIM reason is rank")

	# Rank 3 in a secured zone -> secured_zone (membership + rank pass, zone fails).
	var rank3: Dictionary = member.duplicate()
	rank3["faction_rank"] = 3
	var c_secured: Dictionary = org.can_claim_command(rank3, "secured", ample)
	_assert_true(not bool(c_secured["allowed"]), "rank 3 cannot claim a secured zone")
	_assert_equal(String(c_secured["reason"]), "secured_zone", "secured zone reason is secured_zone")

	# Rank 3 in a claimable zone but below the influence floor -> influence.
	var below: int = Territory.CLAIM_MIN_INFLUENCE - 1
	var c_inf_lawless: Dictionary = org.can_claim_command(rank3, "lawless", below)
	_assert_true(not bool(c_inf_lawless["allowed"]), "below floor cannot claim (lawless)")
	_assert_equal(String(c_inf_lawless["reason"]), "influence", "below floor reason is influence (lawless)")
	var c_inf_contested: Dictionary = org.can_claim_command(rank3, "contested", below)
	_assert_equal(String(c_inf_contested["reason"]), "influence", "below floor reason is influence (contested)")

	# Rank 3 in a lawless zone with influence at/over the floor -> allowed.
	var c_ok: Dictionary = org.can_claim_command(rank3, "lawless", Territory.CLAIM_MIN_INFLUENCE)
	_assert_true(bool(c_ok["allowed"]), "rank 3 + lawless + influence at floor is allowed")
	_assert_equal(String(c_ok["reason"]), "", "allowed claim has empty reason")

	# Denial ordering: an invalid member is rejected BEFORE the rank/zone checks.
	var bad_member: Dictionary = member.duplicate()
	bad_member["faction_id"] = null
	bad_member["faction_rank"] = 2
	var c_invalid: Dictionary = org.can_claim_command(bad_member, "secured", below)
	_assert_true(not bool(c_invalid["allowed"]), "invalid member cannot claim")
	_assert_equal(String(c_invalid["reason"]), "no_faction", "invalid member reports validate_membership reason first")

	# --- can_found_city: rank gate at RANK_CITY ---
	var rank4: Dictionary = member.duplicate()
	rank4["faction_rank"] = 4
	var rank5: Dictionary = member.duplicate()
	rank5["faction_rank"] = 5
	var rank6: Dictionary = member.duplicate()
	rank6["faction_rank"] = 6
	_assert_true(not org.can_found_city(rank4), "rank 4 cannot found a city")
	_assert_true(org.can_found_city(rank5), "rank 5 can found a city")
	_assert_true(org.can_found_city(rank6), "rank 6 can found a city")
	# A non-member at high rank still cannot found a city.
	var bad_high: Dictionary = member.duplicate()
	bad_high["faction_id"] = null
	bad_high["faction_rank"] = 9
	_assert_true(not org.can_found_city(bad_high), "non-member cannot found a city regardless of rank")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("org_model_smoke: OK")
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
