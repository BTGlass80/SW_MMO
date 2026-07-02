extends RefCounted
## Pure hostile-NPC combat mapping (Wave F / DIV-0017 — the shared lethal source). Turns a
## creature_spawn_model roll into the TARGET-side pool shape combat_arena / ground_combat_model
## already expect, so a hostile creature plugs into resolve_exchange_with_action_window exactly
## like the training dummy — EXCEPT target_stun_mode=false, so its return fire is a REAL wound
## (and the arena's lethal flag, S6, lifts the DIV-0016 sparring cap). All-static; `rules` (the
## D6Rules autoload, or a fresh instance in tests) is passed in for pool math. No RNG here — the
## spawn selection itself is seeded upstream in creature_spawn_model.

# Map a creature spawn (creature_spawn_model.roll_spawn shape) -> the arena target_* pools.
static func attack_pools_from_creature(rules: Object, spawn: Dictionary) -> Dictionary:
	var sheet: Dictionary = spawn.get("char_sheet", {})
	var attrs: Dictionary = sheet.get("attributes", {})
	var skills: Dictionary = sheet.get("skills", {})
	var atk: Dictionary = spawn.get("natural_attack", {})
	var str_pool: Dictionary = rules.parse_pool(String(attrs.get("strength", "2D")))
	var to_hit_skill := String(atk.get("to_hit_skill", ""))
	# to-hit pool = the creature's listed skill for its natural attack, else a modest default.
	var attack_code := "3D"
	if to_hit_skill != "" and skills.has(to_hit_skill):
		attack_code = String(skills[to_hit_skill])
	return {
		"target_attack_pool": rules.parse_pool(attack_code),
		"target_damage_pool": _resolve_damage(rules, String(atk.get("damage", "3D")), str_pool),
		"target_soak_pool": str_pool,                             # WEG: soak = Strength
		"target_armor": {},                                       # natural armor not modeled in v1
		"target_scale": String(spawn.get("scale", "creature")),
		"target_stun_mode": false,                                # REAL damage (lethal via the arena flag)
	}

# Resolve a natural-attack damage code, honoring WEG STR-relative damage ("STR", "STR+1D", "STR+2").
static func _resolve_damage(rules: Object, damage_text: String, str_pool: Dictionary) -> Dictionary:
	var t := damage_text.strip_edges()
	if t.to_upper().begins_with("STR"):
		var rest := t.substr(3).strip_edges()
		if rest.begins_with("+"):
			rest = rest.substr(1).strip_edges()
		if rest == "":
			return str_pool.duplicate()
		return rules.add_pools(str_pool, rules.parse_pool_or_pips(rest))
	return rules.parse_pool(t)

# DIV-0017: hostile creatures deal REAL (uncapped) damage in LAWLESS + CONTESTED zones (owner ruling
# 2026-07-02; starter secured Mos Eisley zones stay safe). Distinct from open-PvP, which is lawless
# ONLY (DIV-0019). Owner-tunable via lethal_tiers.
static func is_lethal_zone(security_tier: String, lethal_tiers: Array = ["lawless", "contested"]) -> bool:
	return lethal_tiers.has(security_tier)
