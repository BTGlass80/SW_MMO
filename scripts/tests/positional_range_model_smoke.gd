extends SceneTree

# Smoke test for scripts/rules/positional_range_model.gd.
#
# Verifies the pure positional -> WEG range band derivation:
#   - two positions collapse to the right straight-line distance (Vector3 / dict / Vector2 forms),
#   - point-blank / short / medium / long / extreme distances map to the SAME bands + difficulties
#     d6_rules.range_band_for_weapon reports for the same weapon ranges (no parallel band system),
#   - missing/empty weapon ranges fall back to d6_rules' fixed RANGE_BANDS table,
#   - beyond-long distance is flagged out_of_range at max (Heroic 30) difficulty,
#   - cover_level is passed through unchanged (and clamped 0..4),
#   - the model is deterministic (same inputs -> identical result; no RNG).

const Model := preload("res://scripts/rules/positional_range_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var rules: Node = load("res://scripts/rules/d6_rules.gd").new()

	# Blaster pistol ranges [short_min, short_max, medium_max, long_max] (data/weapons_clone_wars.json).
	var bp_ranges: Array = [3, 10, 30, 120]

	# --- distance_between: geometry across accepted position forms ---
	_assert_eq(Model.distance_between(Vector3(0, 0, 0), Vector3(8, 0, 0)), 8.0, "vector3 distance along X")
	_assert_eq(Model.distance_between({"x": 0, "y": 0, "z": 0}, {"x": 0, "y": 0, "z": 25}), 25.0, "dict distance along Z")
	_assert_eq(Model.distance_between(Vector3(0, 0, 0), Vector3(3, 4, 0)), 5.0, "3-4-5 triangle distance")
	_assert_eq(Model.distance_between(Vector2(0, 0), Vector2(0, 12)), 12.0, "vector2 maps onto ground plane")
	_assert_eq(Model.distance_between(Vector3(5, 9, 5), Vector3(5, 9, 5)), 0.0, "coincident positions are zero distance")

	# --- solve(): band + difficulty must match d6_rules.range_band_for_weapon exactly ---
	# Point-blank (distance 0 and 2 both < short_min 3).
	_assert_band(rules, 0.0, bp_ranges, "Point Blank", 5, "zero distance is point blank")
	_assert_band(rules, 2.0, bp_ranges, "Point Blank", 5, "2m is point blank")
	# Short (<= short_max 10).
	_assert_band(rules, 8.0, bp_ranges, "Short", 10, "8m is short")
	# The retired nominal PVP distance (12m) with a blaster pistol lands in Medium here
	# because 12 > short_max 10 -- exactly the positional truth the constant elided.
	_assert_band(rules, 12.0, bp_ranges, "Medium", 15, "12m (old PVP_DISTANCE) is medium for a blaster pistol")
	# Medium (<= medium_max 30).
	_assert_band(rules, 25.0, bp_ranges, "Medium", 15, "25m is medium")
	# Long (<= long_max 120).
	_assert_band(rules, 100.0, bp_ranges, "Long", 20, "100m is long")
	# Extreme / out of range (> long_max 120) -> max (Heroic 30) difficulty.
	var extreme: Dictionary = Model.solve(Vector3.ZERO, Vector3(200, 0, 0), bp_ranges)
	_assert_eq(extreme["band"], "Extreme", "200m is extreme")
	_assert_eq(extreme["difficulty"], 30, "extreme difficulty is 30")
	_assert_eq(extreme["out_of_range"], true, "beyond long range is flagged out_of_range")
	_assert_eq(Model.solve(Vector3.ZERO, Vector3(100, 0, 0), bp_ranges)["out_of_range"], false, "in-range shot is not out_of_range")

	# --- solve() distance field mirrors distance_between ---
	var solved: Dictionary = Model.solve(Vector3(0, 0, 0), Vector3(0, 0, 25), bp_ranges)
	_assert_eq(solved["distance"], 25.0, "solve reports the straight-line distance")
	_assert_eq(solved["weapon_ranges"], bp_ranges, "solve echoes the weapon ranges used")

	# --- weapon input forms: ranges Array, weapon spec Dict, weapon key + catalog ---
	var bp_spec := {"name": "Blaster Pistol", "ranges": bp_ranges, "damage": "4D"}
	_assert_eq(Model.solve(Vector3.ZERO, Vector3(25, 0, 0), bp_spec)["difficulty"], 15, "weapon-spec dict resolves ranges (25m medium)")
	var catalog := {"weapons": {"blaster_pistol": bp_spec}}
	_assert_eq(Model.solve(Vector3.ZERO, Vector3(25, 0, 0), "blaster_pistol", 0, rules, catalog)["difficulty"], 15, "weapon-key + catalog resolves ranges (25m medium)")
	# The inner weapons map (not the root) is also accepted as a catalog.
	_assert_eq(Model.solve(Vector3.ZERO, Vector3(8, 0, 0), "blaster_pistol", 0, rules, catalog["weapons"])["difficulty"], 10, "inner weapons map works as catalog (8m short)")
	# Unknown weapon key -> no ranges -> fixed-band fallback (see below).
	_assert_eq(
		Model.solve(Vector3.ZERO, Vector3(24, 0, 0), "no_such_weapon", 0, rules, catalog)["band"],
		String(rules.range_band_for_distance(24.0)["name"]),
		"unknown weapon key falls back to the fixed band"
	)

	# --- missing/empty ranges fall back to d6_rules' fixed RANGE_BANDS table ---
	# (empty ranges -> range_band_for_weapon -> range_band_for_distance).
	for d: float in [12.0, 24.0, 50.0, 100.0]:
		var fixed: Dictionary = rules.range_band_for_distance(d)
		var got: Dictionary = Model.solve(Vector3.ZERO, Vector3(d, 0, 0), null)
		_assert_eq(got["band"], String(fixed["name"]), "default band name matches fixed table at %sm" % d)
		_assert_eq(got["difficulty"], int(fixed["difficulty"]), "default band difficulty matches fixed table at %sm" % d)

	# --- band_for_distance helper agrees with the underlying rule, with and without an injected rules ---
	_assert_eq(
		Model.band_for_distance(25.0, bp_ranges, rules),
		rules.range_band_for_weapon(25.0, bp_ranges),
		"band_for_distance(rules) mirrors range_band_for_weapon"
	)
	_assert_eq(
		Model.band_for_distance(25.0, bp_ranges),
		rules.range_band_for_weapon(25.0, bp_ranges),
		"band_for_distance() with no injected rules still mirrors range_band_for_weapon"
	)

	# --- cover_level is passed through unchanged and clamped 0..4 (never invented/rolled) ---
	_assert_eq(Model.solve(Vector3.ZERO, Vector3(8, 0, 0), bp_ranges, 3)["cover_level"], 3, "cover_level passes through")
	_assert_eq(Model.solve(Vector3.ZERO, Vector3(8, 0, 0), bp_ranges, 9)["cover_level"], 4, "cover_level clamps to 4")
	_assert_eq(Model.solve(Vector3.ZERO, Vector3(8, 0, 0), bp_ranges, -2)["cover_level"], 0, "cover_level clamps to 0")

	# --- determinism: no RNG, so repeated calls are identical ---
	var d1: Dictionary = Model.solve(Vector3(1, 2, 3), Vector3(9, 2, 3), bp_ranges, 2, rules)
	var d2: Dictionary = Model.solve(Vector3(1, 2, 3), Vector3(9, 2, 3), bp_ranges, 2, rules)
	_assert_eq(d1, d2, "solve is deterministic for identical inputs")

	# --- REGRESSION: the echoed weapon_ranges must be a DEFENSIVE COPY, never a live reference to
	# the shared weapon catalog. A weapon-key solve pulls ranges out of the long-lived catalog; if the
	# result aliased that array, a consumer appending/editing weapon_ranges would silently corrupt the
	# catalog for every future shot with that weapon. ---
	var cat2 := {"weapons": {"blaster_pistol": {"name": "BP", "ranges": [3, 10, 30, 120]}}}
	var leak_solve: Dictionary = Model.solve(Vector3.ZERO, Vector3(8, 0, 0), "blaster_pistol", 0, rules, cat2)
	(leak_solve["weapon_ranges"] as Array).append(9999)  # try to corrupt the catalog through the echo
	_assert_eq((cat2["weapons"]["blaster_pistol"]["ranges"] as Array), [3, 10, 30, 120], "solve() must not leak a live ref to the catalog ranges")
	# An Array passed directly is also defensively copied, not echoed by reference.
	var in_arr: Array = [3, 10, 30, 120]
	var arr_solve: Dictionary = Model.solve(Vector3.ZERO, Vector3(8, 0, 0), in_arr, 0, rules)
	_assert_eq(is_same(arr_solve["weapon_ranges"], in_arr), false, "solve() returns a defensive copy of a passed ranges array, not the same reference")

	rules.free()

	if _failures.is_empty():
		print("positional_range_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_band(rules: Node, distance: float, ranges: Array, expected_name: String, expected_diff: int, label: String) -> void:
	# Cross-check the model against the authoritative d6_rules band for the same inputs.
	var canon: Dictionary = rules.range_band_for_weapon(distance, ranges)
	_assert_eq(String(canon["name"]), expected_name, "%s (canon band name)" % label)
	_assert_eq(int(canon["difficulty"]), expected_diff, "%s (canon band difficulty)" % label)
	var got: Dictionary = Model.solve(Vector3.ZERO, Vector3(distance, 0, 0), ranges)
	_assert_eq(got["band"], expected_name, "%s (model band name)" % label)
	_assert_eq(got["difficulty"], expected_diff, "%s (model band difficulty)" % label)
	_assert_eq(got["distance"], distance, "%s (model distance)" % label)
