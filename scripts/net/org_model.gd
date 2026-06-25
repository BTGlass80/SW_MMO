extends RefCounted
## Pure org-membership + claim-command validator (Wave E9).
##
## A character belongs to ONE faction (Director influence axis) and up to THREE
## guilds (Guide_10). Ranks gate territorial actions: claim/guard at rank 3+, found
## or expand a city at rank 5 (org leader). This model validates the persisted org
## record (player_persistence.schema.json::org) and answers whether a character may
## issue a claim command at a given zone, COMPOSING with the existing territory claim
## preconditions in territory_model.gd (one source of truth for the zone-security +
## influence-floor check — no duplicated thresholds here).
##
## Grounds docs/FACTION_TERRITORY_DESIGN.md §1-§2 / Guide_10 / Guide_11. Siege
## (hostile-takeover) transitions are an OPEN OWNER DECISION and are NOT built here.
##
## Pure/socket-free so it is headlessly unit-testable. No nodes, RNG, or sockets.

const TerritoryModel := preload("res://scripts/net/territory_model.gd")

const MAX_GUILDS := 3
const RANK_CLAIM := 3   # claim/guard a node
const RANK_CITY := 5    # found/expand a player city (org leader)
const FACTION_AXES := ["republic", "cis", "hutt", "independent"]

## Validate the persisted org record. Returns {"valid": bool, "reason": String}.
## Reports the FIRST failure only; "" reason when valid.
func validate_membership(org: Dictionary) -> Dictionary:
	var faction_id: Variant = org.get("faction_id", null)
	if typeof(faction_id) != TYPE_STRING or String(faction_id) == "":
		return {"valid": false, "reason": "no_faction"}
	if not FACTION_AXES.has(String(org.get("faction_axis", ""))):
		return {"valid": false, "reason": "bad_axis"}
	var rank: Variant = org.get("faction_rank", 0)
	if typeof(rank) != TYPE_INT or int(rank) < 0:
		return {"valid": false, "reason": "negative_rank"}
	if _guild_ids(org).size() > MAX_GUILDS:
		return {"valid": false, "reason": "too_many_guilds"}
	return {"valid": true, "reason": ""}

## True when the org record passes validation (is a real one-faction member).
func is_member(org: Dictionary) -> bool:
	return bool(validate_membership(org)["valid"])

## Number of guilds the character belongs to (0..MAX_GUILDS for a valid record).
func guild_count(org: Dictionary) -> int:
	return _guild_ids(org).size()

## Rank-5 org leader in a valid faction may found/expand a city.
func can_found_city(org: Dictionary) -> bool:
	return is_member(org) and int(org.get("faction_rank", 0)) >= RANK_CITY

## Whether this character may issue a claim command at a zone, COMPOSING membership
## rank with territory_model's zone-security + influence-floor preconditions.
## Returns {"allowed": bool, "reason": String}. Denials in fixed order:
##   invalid member -> validate_membership reason; rank < RANK_CLAIM -> "rank";
##   zone not claimable -> "secured_zone"; below influence floor -> "influence".
func can_claim_command(org: Dictionary, zone_security_base: String, org_influence: int) -> Dictionary:
	var membership: Dictionary = validate_membership(org)
	if not bool(membership["valid"]):
		return {"allowed": false, "reason": String(membership["reason"])}
	if int(org.get("faction_rank", 0)) < RANK_CLAIM:
		return {"allowed": false, "reason": "rank"}
	if not TerritoryModel.CLAIMABLE_BASES.has(zone_security_base):
		return {"allowed": false, "reason": "secured_zone"}
	if org_influence < TerritoryModel.CLAIM_MIN_INFLUENCE:
		return {"allowed": false, "reason": "influence"}
	return {"allowed": true, "reason": ""}

# --- internal helpers ---
func _guild_ids(org: Dictionary) -> Array:
	var ids: Variant = org.get("guild_ids", [])
	if typeof(ids) != TYPE_ARRAY:
		return []
	return ids
