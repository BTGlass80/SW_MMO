extends SceneTree
## Headless smoke test for the pending-zone-influence accrual model (Wave E / E8).
## Verifies: add_pending appends + is NON-mutating + axis-validates; fold_zone sums
## per-axis per-zone and ignores other zones / missing zones; clear_zone removes a
## zone's entries (and is a no-op for an absent zone) while keeping others;
## fold_and_clear combines the two; apply_deltas clamps high and low to [0,100].
## No RNG anywhere — fully deterministic.

const PendingInfluence := preload("res://scripts/net/pending_influence_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var m: PendingInfluence = PendingInfluence.new()

	# --- add_pending: appends one entry, NON-mutating ---
	var base: Array = []
	var p1: Array = m.add_pending(base, "tatooine.spaceport", "hutt", 3)
	_assert_equal(base.size(), 0, "add_pending does not mutate the original Array")
	_assert_equal(p1.size(), 1, "add_pending appends exactly one entry")
	var e0: Dictionary = p1[0]
	_assert_equal(String(e0["zone_id"]), "tatooine.spaceport", "appended entry zone_id")
	_assert_equal(String(e0["axis"]), "hutt", "appended entry axis")
	_assert_equal(int(e0["delta"]), 3, "appended entry delta")

	# --- add_pending: unknown axis "jedi" is a no-op (returns copy unchanged) ---
	var p_jedi: Array = m.add_pending(p1, "tatooine.spaceport", "jedi", 9)
	_assert_equal(p_jedi.size(), 1, "add_pending with unknown axis 'jedi' is a no-op")

	# --- add_pending: empty zone_id is a no-op ---
	var p_empty: Array = m.add_pending(p1, "", "hutt", 5)
	_assert_equal(p_empty.size(), 1, "add_pending with empty zone_id is a no-op")

	# --- fold_zone: sums two hutt entries (+3,+4) for one zone, ignores another zone ---
	var pending: Array = []
	pending = m.add_pending(pending, "tatooine.spaceport", "hutt", 3)
	pending = m.add_pending(pending, "tatooine.spaceport", "hutt", 4)
	pending = m.add_pending(pending, "tatooine.dune_sea", "hutt", 99)  # other zone, ignored
	pending = m.add_pending(pending, "tatooine.spaceport", "republic", 2)
	var folded: Dictionary = m.fold_zone(pending, "tatooine.spaceport")
	_assert_equal(int(folded.get("hutt", 0)), 7, "fold_zone sums two hutt entries (+3,+4) -> 7")
	_assert_true(not folded.has("independent"), "fold_zone only contains axes that appeared")
	_assert_equal(int(folded.get("republic", -999)), 2, "fold_zone keeps a distinct axis for the same zone")
	# Confirm the other zone's 99 was NOT folded into the spaceport total.
	var folded_other: Dictionary = m.fold_zone(pending, "tatooine.dune_sea")
	_assert_equal(int(folded_other.get("hutt", 0)), 99, "fold_zone of the other zone returns its own total")

	# --- fold_zone: a zone with no entries -> {} (missing-zone no-op) ---
	var folded_missing: Dictionary = m.fold_zone(pending, "narshaddaa.undercity")
	_assert_true(folded_missing.is_empty(), "fold_zone of a zone with no entries -> {}")

	# --- clear_zone: of a missing zone leaves the Array unchanged ---
	var cleared_missing: Array = m.clear_zone(pending, "narshaddaa.undercity")
	_assert_equal(cleared_missing.size(), pending.size(), "clear_zone of an absent zone leaves the Array unchanged")

	# --- fold_and_clear: keeps OTHER zones' entries in "remaining", removes the folded zone ---
	var fac: Dictionary = m.fold_and_clear(pending, "tatooine.spaceport")
	var fac_deltas: Dictionary = fac["deltas"]
	var fac_remaining: Array = fac["remaining"]
	_assert_equal(int(fac_deltas.get("hutt", 0)), 7, "fold_and_clear deltas mirror fold_zone")
	_assert_equal(int(pending.size()), 4, "fold_and_clear does not mutate the input Array")
	# Only the single dune_sea entry should remain.
	_assert_equal(fac_remaining.size(), 1, "fold_and_clear removes the folded zone's entries")
	var rem0: Dictionary = fac_remaining[0]
	_assert_equal(String(rem0["zone_id"]), "tatooine.dune_sea", "fold_and_clear keeps OTHER zones' entries")

	# --- apply_deltas: clamps HIGH (hutt 98 + 5 -> 100) and LOW (republic 2 + -10 -> 0) ---
	var influence: Dictionary = {"republic": 2, "cis": 10, "hutt": 98, "independent": 30}
	var deltas: Dictionary = {"hutt": 5, "republic": -10}
	var applied: Dictionary = m.apply_deltas(influence, deltas)
	_assert_equal(int(applied["hutt"]), 100, "apply_deltas clamps high (98 + 5 -> 100)")
	_assert_equal(int(applied["republic"]), 0, "apply_deltas clamps low (2 + -10 -> 0)")
	_assert_equal(int(applied["cis"]), 10, "apply_deltas leaves untouched axes alone")
	_assert_equal(int(applied["independent"]), 30, "apply_deltas leaves untouched axes alone (independent)")
	# NON-mutating check on the input influence.
	_assert_equal(int(influence["hutt"]), 98, "apply_deltas does not mutate the input influence")
	# Unknown axis in deltas is ignored.
	var applied_unknown: Dictionary = m.apply_deltas(influence, {"jedi": 50})
	_assert_true(not applied_unknown.has("jedi"), "apply_deltas ignores axes not in FACTIONS")

	# --- determinism: summation is order-independent ---
	var order_a: Array = []
	order_a = m.add_pending(order_a, "z", "cis", 5)
	order_a = m.add_pending(order_a, "z", "cis", -2)
	order_a = m.add_pending(order_a, "z", "cis", 1)
	var order_b: Array = []
	order_b = m.add_pending(order_b, "z", "cis", 1)
	order_b = m.add_pending(order_b, "z", "cis", 5)
	order_b = m.add_pending(order_b, "z", "cis", -2)
	_assert_equal(int(m.fold_zone(order_a, "z").get("cis", 0)), int(m.fold_zone(order_b, "z").get("cis", 0)), "fold_zone is order-independent")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("pending_influence_smoke: OK")
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
