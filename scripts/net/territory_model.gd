extends RefCounted
## Pure org-territory model (M2.1 scaffold).
##
## An org claims a node in a CONTESTED or LAWLESS zone (precondition: org influence
## in the zone >= a foothold threshold); secured zones cannot be claimed. Each claim
## accrues passive resource income to its org treasury on the slow resource tick,
## scaled by org influence tier (foothold/dominant/control) and the node's risk
## (lawless yields more than contested). Claiming upgrades a lawless node to contested
## FOR OWNING-ORG MEMBERS (home-turf PvP-consent protection). Grounds Guide_11 /
## docs/FACTION_TERRITORY_DESIGN.md; shape per data/schemas/territory_claim.schema.json.
##
## SEPARATE from Director zone influence (zone_state.gd). The siege / Drop-6D
## hostile-takeover loop is an OPEN OWNER DECISION and is intentionally NOT built here.
##
## Pure/socket-free so it is headlessly unit-testable.

const SCHEMA_VERSION := 1
const CLAIMABLE_BASES := ["contested", "lawless"]
# Org-influence -> tier thresholds (Guide_11; owner-tunable starting points).
const CLAIM_MIN_INFLUENCE := 20   # foothold: minimum to claim at all
const DOMINANT_AT := 40
const CONTROL_AT := 70
# Org territory-influence a member's kill-in-zone earns (FACTION_TERRITORY_DESIGN §2): play feeds
# claim eligibility. Co-located with the claim floor so the earn->claim relationship is gate-testable;
# network_manager re-exports it for the combat->territory wiring. Owner-tunable.
const KILL_TERRITORY_INFLUENCE := 2

var claims: Dictionary = {}        # claim_id -> claim dict
var org_credits: Dictionary = {}   # org_id -> treasury credits (income accrues here)
var _node_claims: Dictionary = {}  # node_id -> claim_id (one claim per node)

func can_claim(node_id: String, zone_security_base: String, org_influence: int) -> bool:
	if _node_claims.has(node_id):
		return false  # one claim per node
	if not CLAIMABLE_BASES.has(zone_security_base):
		return false  # secured zones cannot be claimed
	return org_influence >= CLAIM_MIN_INFLUENCE

func claim_node(claim_id: String, node_id: String, zone_id: String, org_id: String, zone_security_base: String, org_influence: int) -> Dictionary:
	if not can_claim(node_id, zone_security_base, org_influence):
		return {}  # rejected
	var claim := {
		"schema_version": SCHEMA_VERSION,
		"claim_id": claim_id,
		"node_id": node_id,
		"zone_id": zone_id,
		"org_id": org_id,
		"security_effective": security_effective(zone_security_base),
		"influence_tier_at_claim": influence_tier(org_influence),
		"income": {"last_yield": {}},
		"siege": null,
		"extra": {"risk_base": zone_security_base},
	}
	claims[claim_id] = claim
	_node_claims[node_id] = claim_id
	if not org_credits.has(org_id):
		org_credits[org_id] = 0
	return claim

func release_claim(claim_id: String) -> void:
	if claims.has(claim_id):
		_node_claims.erase(String((claims[claim_id] as Dictionary).get("node_id", "")))
		claims.erase(claim_id)

func has_claim(claim_id: String) -> bool:
	return claims.has(claim_id)

func get_claim(claim_id: String) -> Dictionary:
	return claims.get(claim_id, {})

func claim_for_node(node_id: String) -> String:
	return String(_node_claims.get(node_id, ""))

func claim_count() -> int:
	return claims.size()

func get_org_credits(org_id: String) -> int:
	return int(org_credits.get(org_id, 0))

## Slow resource tick: every claim yields income to its org treasury. Returns the
## per-org credit gain this tick. Deterministic (no RNG).
func accrue_income() -> Dictionary:
	var gained := {}
	for claim_id in claims:
		var claim: Dictionary = claims[claim_id]
		var risk_base := String((claim.get("extra", {}) as Dictionary).get("risk_base", "contested"))
		var payout := income_for(risk_base, String(claim["influence_tier_at_claim"]))
		var org := String(claim["org_id"])
		org_credits[org] = int(org_credits.get(org, 0)) + int(payout["credits"])
		gained[org] = int(gained.get(org, 0)) + int(payout["credits"])
		claim["income"] = {"last_yield": payout}
	return gained

# --- F59: persistence (org claims + treasuries survive a server restart) ---
## Serialize the org-claim state. The _node_claims index is DERIVED (one claim per node) and is
## rebuilt from claims on restore, so it is not stored.
func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"claims": claims.duplicate(true),
		"org_credits": org_credits.duplicate(true),
	}

## Restore the org-claim state produced by to_dict(); rebuilds the node->claim index.
func apply_persisted(data: Dictionary) -> void:
	if data.is_empty():
		return
	claims = (data.get("claims", {}) as Dictionary).duplicate(true)
	var saved_credits: Dictionary = data.get("org_credits", {})
	org_credits = {}
	for org_id in saved_credits:
		org_credits[org_id] = int(saved_credits[org_id])  # JSON numbers parse as float; keep credits int
	_node_claims = {}
	for claim_id in claims:
		var node_id := String((claims[claim_id] as Dictionary).get("node_id", ""))
		if node_id != "":
			_node_claims[node_id] = claim_id

# --- pure derivation (static) ---
static func influence_tier(org_influence: int) -> String:
	if org_influence >= CONTROL_AT:
		return "control"
	if org_influence >= DOMINANT_AT:
		return "dominant"
	return "foothold"

static func security_effective(zone_security_base: String) -> String:
	# Claiming upgrades a lawless node to contested for owning-org members.
	if zone_security_base == "lawless":
		return "contested"
	return zone_security_base

static func income_for(risk_base: String, tier: String) -> Dictionary:
	var base := 100
	var qty := 1
	match tier:
		"control":
			base = 300
			qty = 3
		"dominant":
			base = 200
			qty = 2
		_:
			base = 100
			qty = 1
	# Lawless: higher risk, higher reward (and rarer resources).
	var lawless := risk_base == "lawless"
	var credits := int(round(base * (1.5 if lawless else 1.0)))
	var resource_type := "rare" if lawless else "metal"
	return {"credits": credits, "resources": [{"type": resource_type, "qty": qty}]}
