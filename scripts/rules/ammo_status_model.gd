extends RefCounted
## Pure PRESENTATION model for the DIV-0029 ammo HUD readout (client-side DISPLAY only — no nodes, RNG,
## or sockets, so it is headlessly unit-testable). It turns the per-peer "you".ammo snapshot block —
## built server-side by network_manager._ammo_summary as {weapon, uses_ammo, shots, capacity, packs} —
## into a HUD line, a warning-tint DECISION (reusing the wound-severity color language via a color_key
## net_world maps through _status_color), and a client-side auto-reload inference. Everything that
## BRANCHES (the low/dry thresholds, the reload diff) lives here; the actual Color values + Label wiring
## stay in net_world.gd. It reads its input null-safe so an absent/legacy "you".ammo block renders clean.

const LOW_AMMO_FRACTION := 0.20   # warn (tint the readout) once the magazine drops under 20% of capacity

## Show an ammo readout at all? Only for an ammo-tracked weapon. A melee / single_use weapon
## (uses_ammo=false) or an empty/absent block hides it (returns false).
static func should_show(ammo: Dictionary) -> bool:
	return bool(ammo.get("uses_ammo", false))

## The readout line, e.g. "Ammo 4/6 | packs 2". Only meaningful when should_show(ammo) is true; the
## fields are read null-safe + floored at 0 so a malformed block never renders a negative count.
static func readout_text(ammo: Dictionary) -> String:
	return "Ammo %d/%d | packs %d" % [
		maxi(int(ammo.get("shots", 0)), 0),
		maxi(int(ammo.get("capacity", 0)), 0),
		maxi(int(ammo.get("packs", 0)), 0),
	]

## Fully DRY: no shot in the magazine AND no carried pack to reload from — the exact state the server
## rejects a real shot for (out_of_ammo). Non-ammo weapon -> false.
static func is_dry(ammo: Dictionary) -> bool:
	if not should_show(ammo):
		return false
	return int(ammo.get("shots", 0)) <= 0 and int(ammo.get("packs", 0)) <= 0

## LOW ammo (the "tint the readout" trigger): the magazine is under LOW_AMMO_FRACTION of capacity, OR
## the weapon is fully dry. Non-ammo weapon / zero-capacity block -> false.
static func is_low(ammo: Dictionary) -> bool:
	if not should_show(ammo):
		return false
	if is_dry(ammo):
		return true
	var capacity := int(ammo.get("capacity", 0))
	if capacity <= 0:
		return false
	return float(maxi(int(ammo.get("shots", 0)), 0)) / float(capacity) < LOW_AMMO_FRACTION

## The wound-severity-palette color KEY for the readout tint (net_world maps it via _status_color, so
## NO new colors are invented): "downed" (red) when fully dry, "wounded" (orange) when low, else
## "healthy" (green — a comfortable magazine). Non-ammo weapon -> "healthy".
static func color_key(ammo: Dictionary) -> String:
	if is_dry(ammo):
		return "downed"
	if is_low(ammo):
		return "wounded"
	return "healthy"

## Did a server auto-reload happen between two consecutive readouts? True when the SAME equipped
## weapon's carried packs DROPPED and the magazine REFILLED (the server auto_reload spends a pack + tops
## the weapon up). Distinguishes a reload from a vendor pack-SELL (packs drop but shots do NOT rise) and
## a weapon SWAP (different weapon key). A purely client-side inference off the snapshot diff — the
## caller passes the PREVIOUS snapshot's ammo block as `prev` and the current one as `cur`.
static func reload_happened(prev: Dictionary, cur: Dictionary) -> bool:
	if not should_show(prev) or not should_show(cur):
		return false
	if String(prev.get("weapon", "")) != String(cur.get("weapon", "")):
		return false
	if int(cur.get("packs", 0)) >= int(prev.get("packs", 0)):
		return false
	return int(cur.get("shots", 0)) > int(prev.get("shots", 0))
