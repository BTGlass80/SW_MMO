extends RefCounted
## Pure creature harvesting / salvage model (Wave F depth; DIV-0023).
##
## Turns a DISABLED creature into a sellable good. It is the runtime path for the
## latent `harvest` blocks already carried in data/creatures_clone_wars.json
## (keys: good, resource, optional difficulty, optional yield, note). ~15 creatures
## carry one (e.g. krayt_dragon -> krayt_dragon_pearl, acklay -> acklay_chitin,
## gornt -> gornt_meat); the rest yield nothing.
##
## Pure / socket-free / all-static, NO nodes, NO RNG of its own. Every randomized
## step is a pure function of an explicit `seed:int` the SERVER owns (same rule as
## creature_spawn_model / economy_model.roll_loot) — NEVER randomize(). Pool math is
## delegated to a passed `rules` object (the D6Rules autoload, or a fresh instance in
## tests), matching force_skills_model / chargen_model / derived_stats_model.
##
## FIDELITY: WEG D6 R&E has a survival / creature-handling skill for field-dressing a
## kill vs a difficulty. This is a legible MMO/economy translation of that (like
## DIV-0018 economy and DIV-0020 quests): TUNABLE CONTENT inside the already-unlocked
## economy, NOT an owner-gated fork. It is a PURE TRANSLATION OF THE DATA — it never
## invents a good that is not in the creature's harvest block.
##
## PRICING IS DEFERRED TO THE SERVER. Harvest goods live only in the creatures file
## and carry no catalog `cost`, so this model returns a good DESCRIPTOR
## (good key + resource + quantity + a quality tier) and stops there. The server maps
## that to credits or an inventory good exactly as economy_model.sell_price(list_cost)
## already takes a server-supplied list cost — this model invents no price.

# --- tunable content constants (all safe to retune; none are WEG-fixed values) ---
const DEFAULT_YIELD := 1               # quantity when the harvest block has no `yield`
const DEFAULT_RESOURCE := "salvage"    # resource bucket when the block omits `resource` (e.g. acklay_chitin)
const FIELD_DRESS_SKILL := "survival"  # WEG governing skill; first_aid / creature-handling are also apt
const PARTIAL_MARGIN := 5              # miss the difficulty by up to this and you still recover a reduced yield

# Outcome tiers (returned under "tier"). Success = full yield; partial = reduced,
# damaged salvage; failure = spoiled, nothing recovered.
const TIER_NONE := "none"
const TIER_SUCCESS := "success"
const TIER_PARTIAL := "partial"
const TIER_FAILURE := "failure"


# Accepts a creature_key String, a spawn dict (creature_spawn_model.roll_spawn shape,
# has "creature_key"), or a raw creature entry (has "id"). Returns "" if none.
static func _resolve_creature_key(source) -> String:
	if typeof(source) == TYPE_STRING:
		return String(source)
	if typeof(source) == TYPE_DICTIONARY:
		if source.has("creature_key"):
			return String(source["creature_key"])
		if source.has("id"):
			return String(source["id"])
	return ""


# The raw `harvest` block for a creature, or {} when the creature is unknown or has
# no harvest hook. (creature_spawn_model.roll_spawn does NOT copy harvest, so we
# always look it up from creatures_data by key.)
static func harvest_block(creatures_data: Dictionary, creature_key: String) -> Dictionary:
	var creatures: Dictionary = creatures_data.get("creatures", {})
	var c: Dictionary = creatures.get(creature_key, {})
	var block: Variant = c.get("harvest", {})
	if typeof(block) != TYPE_DICTIONARY:
		return {}
	return block


# True only when the source resolves to a known creature with a non-empty `good`.
static func has_harvest(source, creatures_data: Dictionary) -> bool:
	var key := _resolve_creature_key(source)
	if key == "":
		return false
	var block := harvest_block(creatures_data, key)
	return not block.is_empty() and String(block.get("good", "")) != ""


# RNG-free preview of what a creature would drop (for UI / server planning). Reports
# harvestable, the good key, resource, whether a skill check gates it, its difficulty
# (0 when ungated), and the raw yield spec. Never rolls.
static func describe(source, creatures_data: Dictionary) -> Dictionary:
	var key := _resolve_creature_key(source)
	var block := harvest_block(creatures_data, key) if key != "" else {}
	var good := String(block.get("good", ""))
	if good == "":
		return {
			"harvestable": false, "creature_key": key, "good": "", "resource": "",
			"gated": false, "difficulty": 0, "yield": DEFAULT_YIELD,
		}
	var resource := String(block.get("resource", DEFAULT_RESOURCE))
	if resource == "":
		resource = DEFAULT_RESOURCE
	var gated := block.has("difficulty")
	return {
		"harvestable": true,
		"creature_key": key,
		"good": good,
		"resource": resource,
		"gated": gated,
		"difficulty": int(block.get("difficulty", 0)) if gated else 0,
		"yield": block.get("yield", DEFAULT_YIELD),
	}


# Pure band decision, split out so it is testable without RNG. margin = skill total -
# difficulty. >= 0 is full success; a near-miss within PARTIAL_MARGIN recovers half
# the yield (rounded down; a single-unit good rounds to 0 = ruined); a worse miss
# recovers nothing.
static func outcome_for_margin(margin: int, full_yield: int) -> Dictionary:
	if margin >= 0:
		return {"tier": TIER_SUCCESS, "success": true, "quantity": maxi(full_yield, 0)}
	if margin >= -PARTIAL_MARGIN:
		return {"tier": TIER_PARTIAL, "success": false, "quantity": maxi(int(full_yield / 2), 0)}
	return {"tier": TIER_FAILURE, "success": false, "quantity": 0}


# THE RUNTIME ENTRY POINT. Given the dice `rules`, a `source` (creature_key / spawn
# dict / creature entry), the parsed `creatures_data`, an OPTIONAL field-dressing
# `skill_pool` (a {dice,pips} dict, an "xD+y" String, or null/"" = untrained 0D), and
# the SERVER-owned `seed`, returns a structured result:
#
#   { harvestable:bool, success:bool, tier:String, good:String, resource:String,
#     quantity:int, creature_key:String, difficulty:int, reason:String, roll:Dictionary }
#
# Rules:
#   - unknown key / non-creature source -> nothing (reason "unknown_creature").
#   - no harvest block (or empty `good`) -> nothing (reason "no_harvest").
#   - no `difficulty` -> trivial field-dress: auto-success, full yield (reason
#     "auto_success"), no dice consumed.
#   - `difficulty` present -> roll the skill_pool (real WEG check via rules.check,
#     wild die included) vs the difficulty; band by outcome_for_margin.
#   `yield`: absent -> DEFAULT_YIELD; scalar -> that many (floored at 1); [min,max] ->
#   a seeded inclusive roll (may be 0 if authored that way). The skill check consumes
#   the rng BEFORE the yield roll, so results are stable for a given seed.
static func roll_harvest(rules, source, creatures_data: Dictionary, skill_pool = null, seed: int = 0) -> Dictionary:
	var key := _resolve_creature_key(source)
	if key == "":
		return _nothing("", "unknown_creature")
	var creatures: Dictionary = creatures_data.get("creatures", {})
	if not creatures.has(key):
		return _nothing(key, "unknown_creature")

	var block := harvest_block(creatures_data, key)
	var good := String(block.get("good", ""))
	if block.is_empty() or good == "":
		return _nothing(key, "no_harvest")

	var resource := String(block.get("resource", DEFAULT_RESOURCE))
	if resource == "":
		resource = DEFAULT_RESOURCE

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var gated := block.has("difficulty")
	var roll_result: Dictionary = {}
	var target := 0
	var band: Dictionary

	if not gated:
		# Trivial field-dress: nothing to roll against.
		var full_yield_ungated := _resolve_yield(block.get("yield", null), rng)
		band = {"tier": TIER_SUCCESS, "success": true, "quantity": maxi(full_yield_ungated, 0)}
	else:
		var pool := _coerce_pool(rules, skill_pool)
		roll_result = rules.check(pool, block.get("difficulty"), rng)
		target = int(roll_result.get("difficulty", 0))
		# Yield resolved AFTER the check so the check consumes the rng first (stable order).
		var full_yield := _resolve_yield(block.get("yield", null), rng)
		band = outcome_for_margin(int(roll_result.get("margin", -9999)), full_yield)

	return {
		"harvestable": true,
		"success": bool(band["success"]),
		"tier": String(band["tier"]),
		"good": good,
		"resource": resource,
		"quantity": int(band["quantity"]),
		"creature_key": key,
		"difficulty": target,
		"reason": _reason_for(gated, String(band["tier"])),
		"roll": roll_result,
	}


# --- internals ---

static func _nothing(creature_key: String, reason: String) -> Dictionary:
	return {
		"harvestable": false,
		"success": false,
		"tier": TIER_NONE,
		"good": "",
		"resource": "",
		"quantity": 0,
		"creature_key": creature_key,
		"difficulty": 0,
		"reason": reason,
		"roll": {},
	}


static func _reason_for(gated: bool, tier: String) -> String:
	if not gated:
		return "auto_success"
	match tier:
		TIER_SUCCESS:
			return "skill_success"
		TIER_PARTIAL:
			return "skill_partial"
		_:
			return "skill_failure"


# null / "" -> untrained 0D. A {dice,pips} dict passes through. An "xD+y" String is
# parsed via rules.parse_pool.
static func _coerce_pool(rules, skill_pool) -> Dictionary:
	if skill_pool == null:
		return {"dice": 0, "pips": 0}
	if typeof(skill_pool) == TYPE_DICTIONARY:
		return {"dice": int(skill_pool.get("dice", 0)), "pips": int(skill_pool.get("pips", 0))}
	if typeof(skill_pool) == TYPE_STRING:
		if String(skill_pool).strip_edges() == "":
			return {"dice": 0, "pips": 0}
		return rules.parse_pool(String(skill_pool))
	return {"dice": 0, "pips": 0}


# Honors the block's `yield`: absent -> DEFAULT_YIELD; scalar int/float -> floored at 1;
# [min,max] -> a seeded inclusive roll (respects an authored min of 0). Consumes rng
# ONLY for the range case.
static func _resolve_yield(yield_spec, rng: RandomNumberGenerator) -> int:
	if yield_spec == null:
		return DEFAULT_YIELD
	match typeof(yield_spec):
		TYPE_INT, TYPE_FLOAT:
			return maxi(int(yield_spec), 1)
		TYPE_ARRAY:
			var arr: Array = yield_spec
			if arr.size() >= 2:
				var lo := int(arr[0])
				var hi := int(arr[1])
				if hi < lo:
					hi = lo
				return maxi(rng.randi_range(lo, hi), 0)
			if arr.size() == 1:
				return maxi(int(arr[0]), 0)
			return DEFAULT_YIELD
	return DEFAULT_YIELD
