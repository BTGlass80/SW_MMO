extends RefCounted
## Pure zone-based PvP mapping + consent/lethality predicate (Wave F / DIV-0019). Turns a TARGET
## PLAYER's stored arena pools + live state into the target_* shape ground_combat_model already
## consumes — so a player target plugs into resolve_exchange_with_action_window exactly like the
## training dummy (DIV-0016) and hostile creatures (DIV-0017), EXCEPT target_stun_mode=false (REAL
## damage) and the DIV-0016 sparring cap is NOT applied (PvP is lethal). Owner ruling 2026-07-02:
## open PvP is LAWLESS-ONLY (distinct from creature lethality, which also covers contested).
## All-static, no nodes/sockets/RNG.

const OPEN_PVP_TIERS := ["lawless"]    # open PvP: lawless ONLY (secured + contested are PROTECTED)
const FULL_LOOT_TIERS := ["lawless"]   # a dropped corpse is third-party lootable here
const PVP_DEATH_SEVERITY := 5          # the 'dead' tier a PvP hit must reach to fire DIV-0006

# THE consent/lethality predicate. Takes BOTH zones AND both tiers so a same-zone check and a
# both-open check are one call; a cross-boundary shot is rejected with a distinct reason.
# Returns {"allowed": bool, "reason": String}.
#   reasons: "no_zone" | "different_zone" | "protected_zone" | "protected_target" | ""
static func can_fire(shooter_zone: String, target_zone: String,
		shooter_tier: String, target_tier: String,
		open_tiers: Array = OPEN_PVP_TIERS) -> Dictionary:
	if shooter_zone == "" or target_zone == "":
		return {"allowed": false, "reason": "no_zone"}
	if shooter_zone != target_zone:
		return {"allowed": false, "reason": "different_zone"}
	if not open_tiers.has(shooter_tier):
		return {"allowed": false, "reason": "protected_zone"}
	if not open_tiers.has(target_tier):
		return {"allowed": false, "reason": "protected_target"}
	return {"allowed": true, "reason": ""}

# Remap a DEFENDER's attacker-shaped arena pools (_players[def]["pools"]) into the target_* keys
# ground_combat_model reads for incoming-attack resolution. target_stun_mode=false => REAL wound.
# G3 (DIV-0019): also carry the defender's DODGE pool (target_dodge_pool) so resolve_exchange can
# build the defender's WEG reaction dodge against the attacker's shot — the reaction layer that was
# absent in PvP (attack passed an EMPTY defense, so only armor + Strength soak defended).
static func defender_target_pools(defender_pools: Dictionary) -> Dictionary:
	return {
		"target_attack_pool": (defender_pools.get("attacker_pool", {"dice": 0, "pips": 0}) as Dictionary).duplicate(true),
		"target_damage_pool": (defender_pools.get("damage_pool", {"dice": 0, "pips": 0}) as Dictionary).duplicate(true),
		"target_soak_pool": (defender_pools.get("player_soak_pool", {"dice": 0, "pips": 0}) as Dictionary).duplicate(true),
		"target_dodge_pool": (defender_pools.get("player_dodge_pool", {"dice": 0, "pips": 0}) as Dictionary).duplicate(true),
		"target_armor": (defender_pools.get("player_armor", {}) as Dictionary).duplicate(true),
		"target_scale": String(defender_pools.get("attacker_scale", "character")),
		"target_stun_mode": false,
	}

# {wound_severity, armor_quality_pips, name} view of a live defender player-state (the target_state
# resolve_exchange reads/writes). player_wound_severity -> wound_severity; pips carry.
static func defender_target_state(defender_state: Dictionary, display_name: String) -> Dictionary:
	return {
		"wound_severity": int(defender_state.get("player_wound_severity", 0)),
		"armor_quality_pips": int(defender_state.get("player_armor_quality_pips", 0)),
		"name": display_name,
	}

static func is_kill(target_severity: int) -> bool:
	return target_severity >= PVP_DEATH_SEVERITY

static func is_full_loot(security_tier: String, loot_tiers: Array = FULL_LOOT_TIERS) -> bool:
	return loot_tiers.has(security_tier)
