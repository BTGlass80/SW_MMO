extends RefCounted
## Pure, server-authoritative effective-security gate (E7 scaffold).
##
## Implements docs/WORLD_SIM_DESIGN.md §3.2 "Effective security (single gate)" as a
## PURE function. Every combat initiation (player attack, NPC aggro, space fire, a
## siege no-consent window) is meant to route through ONE server resolver so no combat
## skips it; this model IS that resolver's pure core (NOT wired into any hot path here).
##
## Security tiers mirror zone_state.gd: TIERS index 0 = SAFEST. "upgrade" = toward
## "secured" (lower index); "downgrade" = toward "lawless" (higher index). The base
## tier is NEVER mutated — only the EFFECTIVE value shifts.
##
## Resolution order (applied IN SEQUENCE):
##   1. Room faction override (e.g. a Republic garrison interior is effectively
##      "lawless" for a hostile-standing character): a non-empty per-room override
##      REPLACES the base for that character.
##   2. City citizen upgrade: a citizen inside their player city is upgraded ONE step
##      (contested->secured, lawless->contested). This upgraded tier is captured as a
##      SAFETY FLOOR and enforced LAST ("most-permissive last word"), so a later
##      hostile downgrade can never make a citizen LESS safe than their city allows.
##   3. Territory claim upgrade: in a claimed LAWLESS node, an owning-org member is
##      treated as "contested" (consent protection on home turf).
##   4. Director overlay (transient, mirrors zone_state.derive_security_overlay):
##      hutt_influence >= 80 downgrades one tier; an active republic_crackdown upgrades
##      contested->secured.
## After steps 1->4 the captured citizen floor is re-applied via more_secure() so it
## wins as the last word.
##
## Pure/socket-free so it is headlessly unit-testable. PvP consent is out of scope
## (owner-gated).

const TIERS := ["secured", "contested", "lawless"]  # index 0 = safest

# Director overlay thresholds (mirror zone_state.gd / security_zone.schema.json).
const HUTT_SURGE_DOWNGRADE_AT := 80

## One step toward "secured" (lower index), clamped at the safe end. Unknown -> "secured".
func upgrade_tier(tier: String) -> String:
	var idx := TIERS.find(tier)
	if idx < 0:
		return "secured"
	return TIERS[maxi(idx - 1, 0)]

## One step toward "lawless" (higher index), clamped at the dangerous end. Unknown -> "secured".
func downgrade_tier(tier: String) -> String:
	var idx := TIERS.find(tier)
	if idx < 0:
		return "secured"
	return TIERS[mini(idx + 1, TIERS.size() - 1)]

## The safer (lower-index) of two tiers. Unknown tiers fall back to the dangerous end
## so a known tier always wins the comparison.
func more_secure(a: String, b: String) -> String:
	var ia := TIERS.find(a)
	var ib := TIERS.find(b)
	if ia < 0:
		ia = TIERS.size() - 1
	if ib < 0:
		ib = TIERS.size() - 1
	return TIERS[mini(ia, ib)]

## Resolve the effective security tier for a character at a node. See header for the
## algorithm. ctx keys (all optional, sane defaults):
##   room_override (String tier or "")  — non-empty REPLACES the base (step 1)
##   is_city_citizen (bool)             — one-step upgrade + safety floor (step 2)
##   is_claim_member (bool)             — lawless->contested for owning-org (step 3)
##   hutt_influence (int)               — >= 80 downgrades one tier (step 4)
##   republic_crackdown_active (bool)   — upgrades contested->secured (step 4)
func get_effective_security(base_tier: String, ctx: Dictionary) -> String:
	# Normalize the starting tier (unknown -> safest, matching zone_state defaults).
	var tier := base_tier if TIERS.has(base_tier) else "secured"

	# Step 1: room faction override REPLACES the base for this character.
	var room_override := String(ctx.get("room_override", ""))
	if room_override != "" and TIERS.has(room_override):
		tier = room_override

	# Step 2: city citizen upgrade — capture the upgraded tier as a SAFETY FLOOR.
	var citizen_floor: String = ""
	if bool(ctx.get("is_city_citizen", false)):
		tier = upgrade_tier(tier)
		citizen_floor = tier

	# Step 3: territory claim upgrade — a claimed LAWLESS node is "contested" for members.
	if bool(ctx.get("is_claim_member", false)) and tier == "lawless":
		tier = "contested"

	# Step 4: Director overlay (transient). Hutt surge downgrades; crackdown upgrades.
	if int(ctx.get("hutt_influence", 0)) >= HUTT_SURGE_DOWNGRADE_AT:
		tier = downgrade_tier(tier)
	if bool(ctx.get("republic_crackdown_active", false)) and tier == "contested":
		tier = "secured"

	# Enforce the citizen floor LAST: most-permissive last word. A hostile downgrade
	# can never make a citizen less safe than their own city allows.
	if citizen_floor != "":
		tier = more_secure(tier, citizen_floor)

	return tier
