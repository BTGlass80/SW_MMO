extends RefCounted
## Pure, server-authoritative per-character faction-reputation model (Wave E12).
##
## Tracks a character's standing on the four Director faction axes used elsewhere
## (republic/cis/hutt/independent — confirmed against scripts/net/zone_state.gd
## FACTIONS) PLUS a fifth axis "bounty_hunters_guild" (the Guild that posts the
## Clone Wars-era bounties the Director surfaces). This is DISTINCT from a zone's
## non-zero-sum faction *influence* (0-100): reputation is signed personal standing
## in [-100, 100], one value per axis, per character.
##
## Non-mutating: apply_delta returns a NEW dict and never edits its input, so the
## server can fold deltas without aliasing the live save. No nodes/RNG/sockets, so
## it is headlessly unit-testable. serialize() yields a flat {axis:int} map suitable
## for the persistence 'org' rep field (player_persistence.schema.json has only a
## scalar faction_rep today; no schema dictates a multi-axis shape, so a flat map
## per the E12 spec is acceptable).

const AXES := ["republic", "cis", "hutt", "independent", "bounty_hunters_guild"]
const REP_MIN := -100
const REP_MAX := 100

## Every axis seeded to neutral 0.
func initial_reputation() -> Dictionary:
	var rep := {}
	for axis in AXES:
		rep[axis] = 0
	return rep

## Clamp a raw reputation value into the allowed [REP_MIN, REP_MAX] band.
func clamp_value(v: int) -> int:
	return clampi(v, REP_MIN, REP_MAX)

## Return a NEW reputation dict (the input is duplicated first and never mutated)
## with `axis` adjusted by `delta` and re-clamped. An UNKNOWN axis (not in AXES)
## leaves the duplicated rep unchanged — no stray key is added.
func apply_delta(rep: Dictionary, axis: String, delta: int) -> Dictionary:
	var next: Dictionary = rep.duplicate(true)
	if not AXES.has(axis):
		return next
	var current := int(next[axis]) if next.has(axis) else 0
	next[axis] = clamp_value(current + delta)
	return next

## Map a reputation value to a standing tier. Thresholds:
##   value <  -25            -> "hostile"
##   -25 <= value <=  24     -> "neutral"
##    25 <= value <=  74     -> "friendly"
##   value >=  75            -> "allied"
func standing_tier(value: int) -> String:
	if value < -25:
		return "hostile"
	if value <= 24:
		return "neutral"
	if value <= 74:
		return "friendly"
	return "allied"

## Flat {axis:int} copy restricted to AXES: drops stray keys and fills any missing
## axis with 0. Suitable for the persistence 'org' rep field.
func serialize(rep: Dictionary) -> Dictionary:
	var out := {}
	for axis in AXES:
		out[axis] = clamp_value(int(rep[axis])) if rep.has(axis) else 0
	return out
