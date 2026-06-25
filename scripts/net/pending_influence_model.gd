extends RefCounted
## Pure pending-zone-influence accrual model (Wave E / E8 substrate).
##
## Backs world_hooks.pending_zone_influence in
## data/schemas/player_persistence.schema.json: an Array of
## {zone_id:String, axis:String, delta:int} entries, where axis is one of the four
## Director influence axes (republic/cis/hutt/independent — mirrors
## scripts/net/zone_state.gd FACTIONS). These are UNCOMMITTED faction-influence
## deltas a character generated (kills, missions, PvP) that survive a crash between
## the action and the next Director recompute.
##
## This is PURE substrate ONLY: it accrues deltas per character, then folds-and-clears
## a zone's accrued deltas into a zone_state-shaped influence delta at Director
## recompute. It does NOT wire combat in (that is the [HOT] E24) and owns no RNG.
##
## EVERY function here is NON-MUTATING — it returns NEW Arrays/Dicts and never edits
## its inputs. Summation is order-independent and fully deterministic.
##
## Pure/socket-free so it is headlessly unit-testable.

const FACTIONS := ["republic", "cis", "hutt", "independent"]
const INFLUENCE_MIN := 0
const INFLUENCE_MAX := 100

## Return a COPY of `pending` with a new {zone_id, axis, delta} entry appended.
## An UNKNOWN axis (not in FACTIONS) is a no-op (returns the copy unchanged); an
## empty zone_id is likewise a no-op. NON-mutating: `pending` is never edited.
func add_pending(pending: Array, zone_id: String, axis: String, delta: int) -> Array:
	var out: Array = pending.duplicate(true)
	if zone_id == "":
		return out
	if not FACTIONS.has(axis):
		return out
	out.append({"zone_id": zone_id, "axis": axis, "delta": int(delta)})
	return out

## Sum deltas per axis over entries whose zone_id matches `zone_id`. Returns
## {axis: summed_int} containing ONLY the axes that actually appeared. A zone with
## no matching entries returns {} (missing-zone no-op). Order-independent.
func fold_zone(pending: Array, zone_id: String) -> Dictionary:
	var summed := {}
	for entry in pending:
		var e: Dictionary = entry
		if String(e.get("zone_id", "")) != zone_id:
			continue
		var axis := String(e.get("axis", ""))
		if not FACTIONS.has(axis):
			continue
		summed[axis] = int(summed.get(axis, 0)) + int(e.get("delta", 0))
	return summed

## Return a COPY of `pending` with all entries for `zone_id` REMOVED. Entries for
## OTHER zones are kept. NON-mutating: `pending` is never edited.
func clear_zone(pending: Array, zone_id: String) -> Array:
	var out: Array = []
	for entry in pending:
		var e: Dictionary = entry
		if String(e.get("zone_id", "")) != zone_id:
			out.append(e.duplicate(true))
	return out

## Director-recompute helper: fold a zone's accrued deltas AND drop them in one call.
## Returns {"deltas": fold_zone(...), "remaining": clear_zone(...)}.
func fold_and_clear(pending: Array, zone_id: String) -> Dictionary:
	return {
		"deltas": fold_zone(pending, zone_id),
		"remaining": clear_zone(pending, zone_id),
	}

## Apply folded `deltas` ({axis:int}) onto a zone_state-shaped `influence`
## ({axis:int}). Returns a COPY of `influence` where each axis present in `deltas`
## is set to clamp(influence[axis] + delta, INFLUENCE_MIN, INFLUENCE_MAX). Axes not
## in FACTIONS are ignored. NON-mutating: `influence` is never edited.
func apply_deltas(influence: Dictionary, deltas: Dictionary) -> Dictionary:
	var out: Dictionary = influence.duplicate(true)
	for axis in deltas:
		if not FACTIONS.has(axis):
			continue
		var updated := int(out.get(axis, 0)) + int(deltas[axis])
		out[axis] = clampi(updated, INFLUENCE_MIN, INFLUENCE_MAX)
	return out
