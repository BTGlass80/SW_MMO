extends RefCounted

# Creature spawn-table model (Wave E / E10).
#
# Pure, deterministic, server-owned. Consumes data/creatures_clone_wars.json
# (top-level "creatures" map). No nodes, no rendering, no randomize() — every
# spawn is keyed off an explicit integer seed the SERVER supplies, so the same
# (zone_alert, zone_security, seed) always produces the identical spawn.
#
# Each creature entry looks like:
#   { id, name, species, scale, hostile(bool), pack_count:[min,max],
#     char_sheet{attributes,skills,move,...}, natural_attack{name,to_hit_skill,damage} }
#
# Posture bias (candidate_keys):
#   - DANGEROUS posture -> prefer HOSTILE creatures.
#       dangerous = (zone_alert in ["high_alert","lockdown","unrest"])
#                   OR (zone_security == "lawless")
#   - CALM posture -> prefer NON-HOSTILE creatures.
#       calm = (zone_security == "secured") OR (zone_alert == "lax")
#   - NEUTRAL (neither of the above) -> all creatures, no bias.
#   Dangerous takes precedence over calm if both somehow match.
#   If a bias leaves the eligible list EMPTY, fall back to ALL creature keys.
#   The returned Array is ALWAYS sorted so seed-based indexing is stable.
#
# Threat-tier banding (Wave G / G12) — the rarity lever for apex predators:
#   Every creature carries an additive `threat_tier` int (1 trivial/ambient ..
#   4 apex/rare; default 2 when absent). AFTER the posture bias, the candidate
#   pool is capped by a MAX threat tier derived from the zone's alert/security
#   (see max_threat_tier):
#     - a secured zone, or a calm (lax) alert  -> max tier 2 (common hostiles only)
#     - the default "standard" alert on a       -> max tier 3 (up to dangerous)
#       contested/lawless frontier
#     - an escalated/dangerous alert            -> max tier 4 (apex eligible)
#       (high_alert/lockdown/unrest/underworld)
#   So a tier-4 apex (krayt dragon / merdeth / rancor) can NEVER be rolled in a
#   calm zone — it only appears under an escalated alert. Banding NEVER strands
#   the spawner: if the tier cap empties the pool it falls back to the un-banded
#   (posture) set. `candidate_keys` is intentionally left un-banded (pure posture
#   bias); `roll_spawn` and `banded_candidate_keys` apply the tier cap.

const DANGEROUS_ALERTS := ["high_alert", "lockdown", "unrest"]
const DANGEROUS_SECURITY := "lawless"
const CALM_SECURITY := "secured"
const CALM_ALERT := "lax"

# Threat-tier vocabulary. Additive per-creature field; absent -> DEFAULT_THREAT_TIER.
const MIN_THREAT_TIER := 1
const MAX_THREAT_TIER := 4
const DEFAULT_THREAT_TIER := 2        # sensible fallback when a creature omits threat_tier
const APEX_THREAT_TIER := 4           # krayt dragon / merdeth / rancor — never ambient

# Alert levels that unlock the APEX band (tier 4) in a non-secured zone. These are the
# escalated/"dangerous" zone states (zone_state.derive_alert_level): a Republic clampdown,
# a lockdown, CIS unrest, or Hutt underworld dominance. A quiet frontier is NOT one of these.
const APEX_ALERTS := ["high_alert", "lockdown", "unrest", "underworld"]


func is_dangerous_posture(zone_alert: String, zone_security: String) -> bool:
	return DANGEROUS_ALERTS.has(zone_alert) or zone_security == DANGEROUS_SECURITY


func is_calm_posture(zone_alert: String, zone_security: String) -> bool:
	return zone_security == CALM_SECURITY or zone_alert == CALM_ALERT


# Returns a SORTED Array of creature keys eligible for this posture (see header
# for the rule). Always sorted; falls back to ALL keys when a bias is empty.
func candidate_keys(creatures_data: Dictionary, zone_alert: String, zone_security: String) -> Array:
	var creatures: Dictionary = creatures_data.get("creatures", {})
	var all_keys: Array = creatures.keys()
	all_keys.sort()
	if all_keys.is_empty():
		return []

	# Dangerous takes precedence over calm when both match.
	if is_dangerous_posture(zone_alert, zone_security):
		var hostile_keys := _keys_by_hostility(creatures, all_keys, true)
		if hostile_keys.is_empty():
			return all_keys
		return hostile_keys

	if is_calm_posture(zone_alert, zone_security):
		var calm_keys := _keys_by_hostility(creatures, all_keys, false)
		if calm_keys.is_empty():
			return all_keys
		return calm_keys

	# Neutral posture: no bias.
	return all_keys


# The per-creature threat tier, clamped to [MIN_THREAT_TIER, MAX_THREAT_TIER].
# Absent/invalid -> DEFAULT_THREAT_TIER (2) so legacy data and partial entries never break.
func threat_tier_of(creature: Dictionary) -> int:
	var t := int(creature.get("threat_tier", DEFAULT_THREAT_TIER))
	return clampi(t, MIN_THREAT_TIER, MAX_THREAT_TIER)


# The MAX threat tier a zone may spawn, derived from its alert + security (see header).
# Apex (tier 4) requires an escalated/dangerous alert in a non-secured zone; a secured
# zone or a lax alert caps at tier 2; the default "standard" alert caps at the tier-3
# "elevated" band. A tier-4 apex is therefore unreachable in any calm/low-alert zone.
func max_threat_tier(zone_alert: String, zone_security: String) -> int:
	# A secured zone is always calm for spawn purposes: trivial/common creatures only.
	if zone_security == CALM_SECURITY:
		return 2
	# Escalated alert in a non-secured zone -> apex predators become eligible.
	if APEX_ALERTS.has(zone_alert):
		return APEX_THREAT_TIER
	# A calm (lax) alert caps at common hostiles even in a lawless frontier.
	if zone_alert == CALM_ALERT:
		return 2
	# Default ("standard" alert on a contested/lawless frontier): elevated, up to tier 3.
	return 3


# Filter `keys` to those whose creature threat_tier is <= max_tier. Order preserved.
func keys_within_tier(creatures: Dictionary, keys: Array, max_tier: int) -> Array:
	var out: Array = []
	for key in keys:
		if threat_tier_of(creatures.get(key, {})) <= max_tier:
			out.append(key)
	return out


# The posture-biased candidate set (candidate_keys) AFTER applying the zone's threat-tier
# cap. Sorted (stable indexing). NEVER strands the spawner: if the tier cap empties the
# pool, falls back to the un-banded posture set (preserving the pre-banding behavior).
func banded_candidate_keys(creatures_data: Dictionary, zone_alert: String, zone_security: String) -> Array:
	var base := candidate_keys(creatures_data, zone_alert, zone_security)
	if base.is_empty():
		return []
	var creatures: Dictionary = creatures_data.get("creatures", {})
	var banded := keys_within_tier(creatures, base, max_threat_tier(zone_alert, zone_security))
	return banded if not banded.is_empty() else base


# Deterministic single spawn roll. The SERVER owns `seed`. The candidate pool is the
# posture bias capped by the zone's threat-tier band (banded_candidate_keys), so apex
# predators are only ever rolled under an escalated alert.
# Returns {} when there are no candidates; otherwise:
#   { creature_key, name, scale, hostile, pack_size, char_sheet, natural_attack }
func roll_spawn(creatures_data: Dictionary, zone_alert: String, zone_security: String, seed: int) -> Dictionary:
	var keys := banded_candidate_keys(creatures_data, zone_alert, zone_security)
	if keys.is_empty():
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var pick: String = String(keys[rng.randi_range(0, keys.size() - 1)])
	var creatures: Dictionary = creatures_data.get("creatures", {})
	var c: Dictionary = creatures.get(pick, {})

	var pc: Array = c.get("pack_count", [1, 1])
	var pack_min := 1
	var pack_max := 1
	if pc.size() >= 2:
		pack_min = int(pc[0])
		pack_max = int(pc[1])
	elif pc.size() == 1:
		pack_min = int(pc[0])
		pack_max = int(pc[0])
	if pack_max < pack_min:
		pack_max = pack_min
	var pack_size := rng.randi_range(pack_min, pack_max)

	return {
		"creature_key": pick,
		"name": String(c.get("name", pick)),
		"scale": String(c.get("scale", "creature")),
		"hostile": bool(c.get("hostile", false)),
		"pack_size": pack_size,
		"char_sheet": c.get("char_sheet", {}),
		"natural_attack": c.get("natural_attack", {}),
		# G12: carry the creature's threat_tier into the spawn so economy_model.roll_loot can grade the
		# reward by risk (without this the loot side defaults every kill to tier 2 = a flat x1.5 bump).
		"threat_tier": threat_tier_of(c),
	}


func _keys_by_hostility(creatures: Dictionary, sorted_keys: Array, want_hostile: bool) -> Array:
	var out: Array = []
	for key in sorted_keys:
		var c: Dictionary = creatures.get(key, {})
		if bool(c.get("hostile", false)) == want_hostile:
			out.append(key)
	return out
