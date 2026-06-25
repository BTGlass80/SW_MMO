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

const DANGEROUS_ALERTS := ["high_alert", "lockdown", "unrest"]
const DANGEROUS_SECURITY := "lawless"
const CALM_SECURITY := "secured"
const CALM_ALERT := "lax"


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


# Deterministic single spawn roll. The SERVER owns `seed`.
# Returns {} when there are no candidates; otherwise:
#   { creature_key, name, scale, hostile, pack_size, char_sheet, natural_attack }
func roll_spawn(creatures_data: Dictionary, zone_alert: String, zone_security: String, seed: int) -> Dictionary:
	var keys := candidate_keys(creatures_data, zone_alert, zone_security)
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
	}


func _keys_by_hostility(creatures: Dictionary, sorted_keys: Array, want_hostile: bool) -> Array:
	var out: Array = []
	for key in sorted_keys:
		var c: Dictionary = creatures.get(key, {})
		if bool(c.get("hostile", false)) == want_hostile:
			out.append(key)
	return out
