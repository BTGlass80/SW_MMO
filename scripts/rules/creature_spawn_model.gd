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
# Threat-tier banding (Wave G / G12; re-tuned to measured lethality in G15) — the rarity
#   lever for dangerous creatures:
#   Every creature carries an additive `threat_tier` int, DERIVED FROM MEASURED green-quickstart
#   lethality (tools/balance_probe.gd P(out)/window bands): 1 trivial (<0.5%), 2 common (<3%),
#   3 elevated (<20%), 4 apex (>=20%), 5 BOSS/event (>=~90% or a named apex-legendary). Absent ->
#   DEFAULT_THREAT_TIER (2). AFTER the posture bias, the candidate pool is capped by a MAX AMBIENT
#   tier derived from the zone's alert/security (see max_threat_tier):
#     - a secured zone, or a calm (lax) alert  -> max tier 2 (common hostiles only)
#     - the default "standard" alert on a       -> max tier 3 (up to elevated)
#       contested/lawless frontier
#     - an escalated/dangerous alert            -> max tier 4 (apex eligible)
#       (high_alert/lockdown/unrest/underworld)
#   So a tier-4 apex (acklay / mutant_acklay / stalker_lizard / voroos ...) can NEVER be rolled in a
#   calm OR default zone — it only appears under an escalated alert. BOSS-class (tier 5: merdeth /
#   krayt_dragon / rancor) is NEVER ambient under ANY alert — it is spawned only through the
#   boss/event channel (`boss_spawn`, below), never through roll_spawn's ambient path (is_boss filters
#   it out everywhere). The boss/event channel is a DELIBERATE, server-driven spawn: today its live
#   trigger is an accepted bounty whose disable objective names a boss (network_manager._advance_hostiles),
#   so a boss appears only when a player OPTS IN to hunting it — never as a random ambient one-shot.
#   Banding NEVER strands the spawner: if the tier cap empties the pool it falls back to the
#   un-banded (posture, still boss-filtered) set. `candidate_keys` is intentionally left un-banded
#   (pure posture bias); `roll_spawn` and `banded_candidate_keys` apply the tier cap + boss filter.
#   FAIL-SAFE (G15): an alert string outside the known enum clamps to the SAFEST band (max tier 2)
#   with a push_warning — vocabulary drift must fail safe, never open the apex band by accident.

const DANGEROUS_ALERTS := ["high_alert", "lockdown", "unrest"]
const DANGEROUS_SECURITY := "lawless"
const CALM_SECURITY := "secured"
const CALM_ALERT := "lax"

# Threat-tier vocabulary. Additive per-creature field; absent -> DEFAULT_THREAT_TIER.
const MIN_THREAT_TIER := 1
const MAX_AMBIENT_TIER := 4           # the highest tier the AMBIENT spawner may ever roll (apex)
const BOSS_THREAT_TIER := 5           # boss/event channel — NEVER ambient under any alert
const MAX_THREAT_TIER := 5            # clamp ceiling for threat_tier_of (allows the boss band)
const DEFAULT_THREAT_TIER := 2        # sensible fallback when a creature omits threat_tier
const APEX_THREAT_TIER := 4           # apex ambient (escalated-alert only); distinct from boss

# The known zone alert vocabulary (zone_state.derive_alert_level). Anything outside this set is
# treated as unknown and fails safe to max tier 2 (see max_threat_tier).
const KNOWN_ALERTS := ["lax", "standard", "high_alert", "lockdown", "unrest", "underworld"]

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


# Boss/event-channel creatures (Wave G / G15): NEVER selectable through the ambient spawner under any
# alert. A creature is boss-class if it carries an explicit `boss: true` flag OR its threat_tier is the
# boss band (>= BOSS_THREAT_TIER). merdeth / krayt_dragon / rancor are boss — "not hard, an unkillable
# one-shot" (G15 review) — they belong to a deliberate event channel, not the ambient faucet.
func is_boss(creature: Dictionary) -> bool:
	return bool(creature.get("boss", false)) or threat_tier_of(creature) >= BOSS_THREAT_TIER


# The MAX AMBIENT threat tier a zone may spawn, derived from its alert + security (see header). PURE
# (no side effects) so it is freely testable. Never returns the boss band. Apex (tier 4) requires an
# escalated/dangerous alert in a non-secured zone; a secured zone or a lax alert caps at tier 2; the
# default "standard" alert caps at the tier-3 "elevated" band. FAIL-SAFE (G15): an alert outside
# KNOWN_ALERTS clamps to the safest band (tier 2) — vocabulary drift can NEVER open the apex band. The
# accompanying push_warning diagnostic lives in roll_spawn (the live ambient entry point), NOT here, so
# this stays a pure query the harness can call without tripping the stderr-is-fatal gate.
func max_threat_tier(zone_alert: String, zone_security: String) -> int:
	# A secured zone is always calm for spawn purposes: trivial/common creatures only.
	if zone_security == CALM_SECURITY:
		return 2
	# Vocabulary drift must fail SAFE: an unknown alert can never open the apex band.
	if not KNOWN_ALERTS.has(zone_alert):
		return 2
	# Escalated alert in a non-secured zone -> apex predators become eligible.
	if APEX_ALERTS.has(zone_alert):
		return APEX_THREAT_TIER
	# A calm (lax) alert caps at common hostiles even in a lawless frontier.
	if zone_alert == CALM_ALERT:
		return 2
	# Default ("standard" alert on a contested/lawless frontier): elevated, up to tier 3.
	return 3


# True when `zone_alert` is a recognized zone-alert level (zone_state.derive_alert_level). An unknown
# value drives the fail-safe clamp in max_threat_tier. Pure predicate (no side effects).
func is_known_alert(zone_alert: String) -> bool:
	return KNOWN_ALERTS.has(zone_alert)


# Filter `keys` to those whose creature threat_tier is <= max_tier AND that are NOT boss-class. Boss
# creatures are excluded regardless of max_tier — the ambient path never selects them. Order preserved.
func keys_within_tier(creatures: Dictionary, keys: Array, max_tier: int) -> Array:
	var out: Array = []
	for key in keys:
		var c: Dictionary = creatures.get(key, {})
		if not is_boss(c) and threat_tier_of(c) <= max_tier:
			out.append(key)
	return out


# The posture-biased candidate set (candidate_keys) AFTER applying the zone's threat-tier cap AND the
# boss filter. Sorted (stable indexing). NEVER strands the spawner: if the tier cap empties the pool it
# falls back to the un-banded posture set — but STILL boss-filtered, so a boss can never leak in through
# the fallback either (a boss is NEVER ambient under any alert).
func banded_candidate_keys(creatures_data: Dictionary, zone_alert: String, zone_security: String) -> Array:
	var base := candidate_keys(creatures_data, zone_alert, zone_security)
	if base.is_empty():
		return []
	var creatures: Dictionary = creatures_data.get("creatures", {})
	var banded := keys_within_tier(creatures, base, max_threat_tier(zone_alert, zone_security))
	if not banded.is_empty():
		return banded
	# Fallback: the posture set with boss-class removed (never the raw base, which may hold a boss).
	# If that is somehow empty too, return it empty (roll_spawn -> {} and the caller retries) rather
	# than ever leaking a boss into the ambient path.
	var non_boss: Array = []
	for key in base:
		if not is_boss(creatures.get(key, {})):
			non_boss.append(key)
	return non_boss


# Deterministic single spawn roll. The SERVER owns `seed`. The candidate pool is the
# posture bias capped by the zone's threat-tier band (banded_candidate_keys), so apex
# predators are only ever rolled under an escalated alert.
# Returns {} when there are no candidates; otherwise:
#   { creature_key, name, scale, hostile, pack_size, char_sheet, natural_attack }
func roll_spawn(creatures_data: Dictionary, zone_alert: String, zone_security: String, seed: int) -> Dictionary:
	# FAIL-SAFE diagnostic (G15): surface vocabulary drift at the live ambient entry point. The clamp
	# itself is in max_threat_tier (pure); this only WARNS so a drifted alert is visible in the server
	# log. Kept out of the pure query path so the test harness (stderr-is-fatal) never trips on it.
	if zone_security != CALM_SECURITY and not is_known_alert(zone_alert):
		push_warning("creature_spawn_model: unknown zone_alert '%s' — clamping ambient spawns to safe max tier 2" % zone_alert)
	var keys := banded_candidate_keys(creatures_data, zone_alert, zone_security)
	if keys.is_empty():
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var pick: String = String(keys[rng.randi_range(0, keys.size() - 1)])
	var creatures: Dictionary = creatures_data.get("creatures", {})
	var c: Dictionary = creatures.get(pick, {})
	return _build_spawn(pick, c, rng)


# True when `key` names a boss/event-channel creature in `creatures_data` (see is_boss). Pure predicate;
# the boss/event channel (boss_spawn) is the only path that may spawn one — never the ambient roll.
func is_boss_key(creatures_data: Dictionary, key: String) -> bool:
	var creatures: Dictionary = creatures_data.get("creatures", {})
	if not creatures.has(key):
		return false
	return is_boss(creatures.get(key, {}))


# BOSS/EVENT CHANNEL (G15 fix): deterministically spawn ONE specific boss-class creature by key,
# bypassing the ambient posture/tier band. This is the ONLY path allowed to produce a boss — the
# ambient roll_spawn filters bosses out everywhere. The SERVER owns `seed`. Its live trigger is a
# DELIBERATE opt-in (an accepted bounty whose disable objective names this boss); it is never called
# from the random ambient faucet, so a green wanderer can never be one-shot by a random apex-legendary.
# Returns {} unless `boss_key` names a boss-class, HOSTILE creature — the channel refuses to spawn a
# non-boss (that belongs to the ambient path) or a non-hostile boss (nothing to fight).
func boss_spawn(creatures_data: Dictionary, boss_key: String, seed: int) -> Dictionary:
	var creatures: Dictionary = creatures_data.get("creatures", {})
	if not creatures.has(boss_key):
		return {}
	var c: Dictionary = creatures.get(boss_key, {})
	if not is_boss(c) or not bool(c.get("hostile", false)):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return _build_spawn(boss_key, c, rng)


# Shared spawn-dict builder for both the ambient roll (roll_spawn) and the boss/event channel
# (boss_spawn). `rng` is already seeded by the caller (the SERVER owns the seed). Pure otherwise.
func _build_spawn(key: String, c: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
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
		"creature_key": key,
		"name": String(c.get("name", key)),
		"scale": String(c.get("scale", "creature")),
		"hostile": bool(c.get("hostile", false)),
		"pack_size": pack_size,
		"char_sheet": c.get("char_sheet", {}),
		"natural_attack": c.get("natural_attack", {}),
		# G12: carry the creature's threat_tier into the spawn so economy_model.roll_loot can grade the
		# reward by risk (without this the loot side defaults every kill to tier 2 = a flat x1.5 bump).
		"threat_tier": threat_tier_of(c),
		# G16 (DIV-0028): carry the OPTIONAL per-creature loot_mult (default 1.0) so roll_loot's
		# within-tier kill-speed correction is applied in the live path, not just in the probe.
		"loot_mult": float(c.get("loot_mult", 1.0)),
	}


func _keys_by_hostility(creatures: Dictionary, sorted_keys: Array, want_hostile: bool) -> Array:
	var out: Array = []
	for key in sorted_keys:
		var c: Dictionary = creatures.get(key, {})
		if bool(c.get("hostile", false)) == want_hostile:
			out.append(key)
	return out
