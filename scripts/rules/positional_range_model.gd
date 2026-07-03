extends RefCounted

# Positional combat-range model (first slice of positional truth).
#
# Given two SERVER-OWNED positions and a weapon's range spec, derive the WEG
# range band + difficulty for a shot at that distance. This retires the nominal
# distance constants (combat_arena.PVP_DISTANCE = 12 / network_manager.HOSTILE_DISTANCE
# = 10) with real geometry: the range difficulty a shooter faces now falls out of
# where the two combatants actually stand, not a hard-coded constant.
#
# Pure, all-static, no RNG, no nodes-in-tree, socket-free -> headlessly testable.
# It owns NO band table of its own: every band decision is delegated to
# d6_rules.range_band_for_weapon so there is exactly ONE WEG band system in the
# codebase (point-blank / short / medium / long / extreme, difficulties 5/10/15/20/30).
# It also does NOT roll or invent cover -- the cover level is passed through from
# the world/zone exactly as combat_arena already supplies it (0..4).
#
# Shape of a result Dictionary (from solve()):
#   {
#     "distance":     float,   # meters between the two positions
#     "band":         String,  # WEG band name, e.g. "Point Blank" / "Short" / ... / "Extreme"
#     "difficulty":   int,     # range difficulty target number (5/10/15/20/30)
#     "cover_level":  int,     # 0..4, passed through unchanged from the caller
#     "weapon_ranges": Array,  # the [sn, sx, mx, lx] used ([] when defaulted)
#     "out_of_range": bool,    # true beyond long range -> Extreme / max (Heroic 30) difficulty
#   }

const RULES_SCRIPT := preload("res://scripts/rules/d6_rules.gd")

# --- geometry -----------------------------------------------------------------

# Coerce a position argument to a Vector3. Accepts:
#   - Vector3 (returned as-is)
#   - Vector2 (mapped onto the X/Z ground plane: (x, 0, y))
#   - Dictionary {"x","y","z"} (any missing axis -> 0.0; {"x","z"} also works)
#   - Array [x, y, z] (or [x, z] -> ground plane)
# Anything else -> Vector3.ZERO (a safe origin rather than a crash).
static func to_vector3(p) -> Vector3:
	match typeof(p):
		TYPE_VECTOR3:
			return p
		TYPE_VECTOR2:
			return Vector3(p.x, 0.0, p.y)
		TYPE_DICTIONARY:
			return Vector3(
				float(p.get("x", 0.0)),
				float(p.get("y", 0.0)),
				float(p.get("z", 0.0))
			)
		TYPE_ARRAY:
			var arr: Array = p
			if arr.size() >= 3:
				return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
			if arr.size() == 2:
				return Vector3(float(arr[0]), 0.0, float(arr[1]))
			return Vector3.ZERO
	return Vector3.ZERO

# Straight-line distance in meters between two positions (any accepted form).
static func distance_between(a, b) -> float:
	return to_vector3(a).distance_to(to_vector3(b))

# --- weapon range resolution --------------------------------------------------

# Resolve a weapon argument to its [short_min, short_max, medium_max, long_max]
# ranges array. Accepts:
#   - null / anything unrecognized       -> [] (band system then falls back to fixed WEG bands)
#   - an Array (already a ranges spec)    -> returned as-is
#   - a weapon spec Dictionary            -> its "ranges" field ([] if absent)
#   - a String weapon key + `catalog`     -> the entry's "ranges" from the catalog
# `catalog` may be the weapons_clone_wars.json root ({"weapons": {...}}) OR the
# inner "weapons" map directly; both are handled.
# Every path returns a DEFENSIVE COPY of the ranges array so the value echoed back in solve()'s
# result never aliases a live, long-lived structure (the shared weapon catalog, a weapon-spec dict,
# or the caller's own array). Without this, a consumer editing result["weapon_ranges"] would silently
# corrupt the catalog for every future shot with that weapon. Elements are numbers (immutable), so a
# shallow duplicate is sufficient.
static func weapon_ranges_for(weapon, catalog = null) -> Array:
	if weapon is Array:
		return (weapon as Array).duplicate()
	match typeof(weapon):
		TYPE_DICTIONARY:
			var r = weapon.get("ranges", [])
			return (r as Array).duplicate() if r is Array else []
		TYPE_STRING:
			var entry := _lookup_weapon(String(weapon), catalog)
			var r2 = entry.get("ranges", [])
			return (r2 as Array).duplicate() if r2 is Array else []
	return []

static func _lookup_weapon(key: String, catalog) -> Dictionary:
	if typeof(catalog) != TYPE_DICTIONARY:
		return {}
	var weapons = catalog.get("weapons", catalog)
	if typeof(weapons) != TYPE_DICTIONARY:
		return {}
	var entry = weapons.get(key, {})
	return entry if typeof(entry) == TYPE_DICTIONARY else {}

# --- band lookup --------------------------------------------------------------

# The WEG range band + difficulty for `distance` given `weapon_ranges`, delegated
# wholesale to d6_rules.range_band_for_weapon (which itself falls back to the fixed
# RANGE_BANDS table when `weapon_ranges` is empty/malformed). Returns the SAME
# {"name","max","difficulty"} shape d6_rules produces -- no parallel band system.
#
# `rules` is an optional D6Rules instance (the autoload, or any d6_rules.gd node).
# When null a throwaway instance is created and freed within the call so this stays
# usable headlessly without the autoload registered (and leaks nothing at exit).
static func band_for_distance(distance: float, weapon_ranges: Array = [], rules: Object = null) -> Dictionary:
	var r: Object = rules
	var owns := false
	if r == null:
		r = RULES_SCRIPT.new()
		owns = true
	var band: Dictionary = r.range_band_for_weapon(float(distance), weapon_ranges)
	if owns:
		r.free()
	return band

# --- top-level solve ----------------------------------------------------------

# Given a shooter position, a target position, and a weapon (spec Dictionary,
# ranges Array, or weapon-key String + `catalog`), return the positional range
# result Dictionary documented at the top of this file. `cover_level` (0..4) is
# passed through unchanged from the world/zone -- this model never rolls cover.
static func solve(from_pos, to_pos, weapon = null, cover_level: int = 0, rules: Object = null, catalog = null) -> Dictionary:
	var distance := distance_between(from_pos, to_pos)
	var weapon_ranges := weapon_ranges_for(weapon, catalog)
	var band := band_for_distance(distance, weapon_ranges, rules)
	var band_name := String(band.get("name", ""))
	return {
		"distance": distance,
		"band": band_name,
		"difficulty": int(band.get("difficulty", 10)),
		"cover_level": clampi(int(cover_level), 0, 4),
		"weapon_ranges": weapon_ranges,
		"out_of_range": band_name == "Extreme",
	}
