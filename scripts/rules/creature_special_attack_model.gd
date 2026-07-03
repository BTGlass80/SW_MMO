extends RefCounted
## Pure creature special-attack rider model (lights up the latent `special_attack` blocks on the
## Clone Wars creatures in data/creatures_clone_wars.json). ~12 creatures carry structured POISON
## and/or RESTRAINT riders that combat currently ignores; this turns them into two server-appliable
## shapes:
##
##   POISON   -> a deterministic per-round damage SCHEDULE honoring `onset` (rounds of delay before
##               it starts) and `rounds` (how many damage ticks). Each tick is a REAL WEG damage roll
##               of the rider's `damage` code via the injected `rules` (D6Rules) + a server-owned seed.
##   RESTRAINT-> an opposed-break DESCRIPTOR {kind, hold_damage, break_check:"opposed brawling/STR",
##               note, ...} the server re-applies each round until the target wins the break check.
##
## Data shapes (read-only; see data/creatures_clone_wars.json):
##   "special_attack": { "poison":    { "damage":"2D+2", "rounds":2, "onset":1, "note":"..." } }
##   "special_attack": { "restraint": { "kind":"grapple", "hold_damage":"STR+2D"|"", "note":"...",
##                                       "dex_penalty":"2D"(optional) } }
## A creature may carry BOTH (e.g. preying_makthier: restraint + poison).
##
## Pure / presentation split: NO nodes, input, sockets, or rendering, and NO RNG of its own — it never
## calls randomize(); every roll is driven by the explicit integer `seed` the SERVER supplies, so the
## same (rider, seed) always produces the identical schedule. All-static; `rules` (the D6Rules autoload,
## or a fresh d6_rules instance in tests) is passed in for pool math / rolling. Matches the style of
## hostile_npc_model.gd (STR-relative damage resolution) and creature_spawn_model.gd (seed-driven).
##
## The SERVER wiring into live combat (applying schedule ticks / holding a target until broken) is a
## later HOT slice; this file is the pure, headlessly-testable rider logic only.
##
## Divergence: see the proposed DIV row in the model report — WEG venom is often an interval STR/stamina
## RESIST roll rather than automatic per-round damage; the prototype resolves the encoded damage code as
## a deterministic per-round WEG roll, and models restraint as an opposed-break descriptor.

const BREAK_CHECK := "opposed brawling/STR"

# --- Rider access ------------------------------------------------------------------------------

# The raw `special_attack` block for a creature key ({} if the creature has none, or key is unknown).
# Returns an INDEPENDENT deep copy: the rider is read-only over the shared creatures_data, and the
# server mutates the baked bundle it applies (consuming poison rounds, marking ticks), so handing back
# a live reference would corrupt the global creature table for every future spawn of this key.
static func special_attack_for(creatures_data: Dictionary, creature_key: String) -> Dictionary:
	if creature_key == "":
		return {}
	var creatures: Dictionary = creatures_data.get("creatures", {})
	var c: Dictionary = creatures.get(creature_key, {})
	var sa = c.get("special_attack", {})
	if typeof(sa) == TYPE_DICTIONARY:
		return (sa as Dictionary).duplicate(true)
	return {}

# Same, keyed off a creature_spawn_model.roll_spawn result. Honors a spawn that already embeds its own
# "special_attack" (future-proofing); otherwise looks the rider up by the spawn's creature_key. The
# embedded block is likewise deep-copied so a mutated bundle never aliases the caller's spawn.
static func special_attack_for_spawn(creatures_data: Dictionary, spawn: Dictionary) -> Dictionary:
	var embedded = spawn.get("special_attack", null)
	if typeof(embedded) == TYPE_DICTIONARY:
		return (embedded as Dictionary).duplicate(true)
	return special_attack_for(creatures_data, String(spawn.get("creature_key", "")))

static func has_special_attack(creatures_data: Dictionary, creature_key: String) -> bool:
	return not special_attack_for(creatures_data, creature_key).is_empty()

# The poison / restraint sub-riders out of a raw special_attack block ({} when absent).
static func poison_rider(rider: Dictionary) -> Dictionary:
	var p = rider.get("poison", {})
	return p if typeof(p) == TYPE_DICTIONARY else {}

static func restraint_rider(rider: Dictionary) -> Dictionary:
	var r = rider.get("restraint", {})
	return r if typeof(r) == TYPE_DICTIONARY else {}

# --- POISON ------------------------------------------------------------------------------------

# The parsed damage pool for a poison rider ("2D+2", "5D", "0D", "4D", ...). Flat codes only (poison
# venom is never STR-relative in the data), so parse_pool_or_pips covers every case incl. "" -> 0D.
static func poison_damage_pool(rules: Object, poison: Dictionary) -> Dictionary:
	return rules.parse_pool_or_pips(String(poison.get("damage", "")).strip_edges())

# One deterministic poison tick for a given (absolute) round. `round_number` is 1-indexed from the moment
# of application, already past the onset delay. The per-round seed is derived from the server seed so ANY
# single tick is independently reproducible (same (seed, round_number) -> same roll).
static func poison_tick(poison: Dictionary, rules: Object, seed: int, round_number: int) -> Dictionary:
	var pool: Dictionary = poison_damage_pool(rules, poison)
	var rng := RandomNumberGenerator.new()
	rng.seed = _derive_seed(seed, round_number)
	var roll: Dictionary = rules.roll_pool(pool, rng)
	return {
		"round": round_number,
		"damage": String(poison.get("damage", "")),
		"pool": pool,
		"pool_text": rules.pool_to_string(pool),
		"roll": roll,
		"total": int(roll["total"]),
	}

# The full per-round poison SCHEDULE. Length == `rounds` (the number of damage ticks / the venom's
# duration); the `onset` delay is honored in each entry's absolute `round` field, so the first tick lands
# on round (onset + 1) and the last on round (onset + rounds). Returns [] for a missing/empty poison
# rider or a non-positive `rounds`. Deterministic given `seed`.
static func poison_schedule(poison: Dictionary, rules: Object, seed: int) -> Array:
	var out: Array = []
	if poison.is_empty():
		return out
	var rounds := int(poison.get("rounds", 1))
	if rounds <= 0:
		return out
	var onset := maxi(int(poison.get("onset", 0)), 0)
	for i in range(rounds):
		out.append(poison_tick(poison, rules, seed, onset + i + 1))
	return out

# --- RESTRAINT ---------------------------------------------------------------------------------

# The opposed-break descriptor the server re-applies each round until the target breaks free.
# {kind, hold_damage(code), has_hold_damage, break_check, note, [dex_penalty]}. hold_damage is the RAW
# WEG code (may be "" for a pure hold with no crush damage — e.g. glim_worm / voroos); resolve it against
# the creature's Strength via resolve_hold_damage_pool. Returns {} for an empty restraint rider.
static func restraint_descriptor(restraint: Dictionary) -> Dictionary:
	if restraint.is_empty():
		return {}
	var hold := String(restraint.get("hold_damage", ""))
	var desc := {
		"kind": String(restraint.get("kind", "grapple")),
		"hold_damage": hold,
		"has_hold_damage": hold.strip_edges() != "",
		"break_check": BREAK_CHECK,
		"note": String(restraint.get("note", "")),
	}
	if restraint.has("dex_penalty"):
		desc["dex_penalty"] = String(restraint.get("dex_penalty", ""))
	return desc

# Resolve a restraint's hold_damage code into a pool, honoring WEG STR-relative codes
# ("STR", "STR+2D", "STR+2D+2") against the passed Strength pool, or a flat code ("1D"), or "" -> 0D.
# Mirrors hostile_npc_model._resolve_damage. The SERVER rolls this pool each held round.
static func resolve_hold_damage_pool(rules: Object, restraint: Dictionary, str_pool: Dictionary) -> Dictionary:
	return _resolve_damage_code(rules, String(restraint.get("hold_damage", "")).strip_edges(), str_pool)

# --- One-stop bundle (server convenience) ------------------------------------------------------

# Fully-baked rider bundle for a spawn: the poison schedule (seeded) + the restraint descriptor, plus
# a has_special_attack flag. {} riders for creatures without one. hold_damage stays a code (the server
# resolves it with the spawn's real Strength via resolve_hold_damage_pool).
static func describe_spawn(creatures_data: Dictionary, spawn: Dictionary, rules: Object, seed: int) -> Dictionary:
	var rider: Dictionary = special_attack_for_spawn(creatures_data, spawn)
	return {
		"creature_key": String(spawn.get("creature_key", "")),
		"has_special_attack": not rider.is_empty(),
		"poison": poison_rider(rider),
		"poison_schedule": poison_schedule(poison_rider(rider), rules, seed),
		"restraint": restraint_descriptor(restraint_rider(rider)),
	}

# Same bundle, keyed directly off a creature_key + data.
static func describe(creatures_data: Dictionary, creature_key: String, rules: Object, seed: int) -> Dictionary:
	return describe_spawn(creatures_data, {"creature_key": creature_key}, rules, seed)

# --- internals ---------------------------------------------------------------------------------

# STR-relative-aware damage-code resolver (shared by restraint hold_damage). "" -> 0D.
static func _resolve_damage_code(rules: Object, text: String, str_pool: Dictionary) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {"dice": 0, "pips": 0}
	if t.to_upper().begins_with("STR"):
		var rest := t.substr(3).strip_edges()
		if rest.begins_with("+"):
			rest = rest.substr(1).strip_edges()
		if rest == "":
			return str_pool.duplicate()
		return rules.add_pools(str_pool, rules.parse_pool_or_pips(rest))
	return rules.parse_pool_or_pips(t)

# Deterministic per-round seed so any single poison tick is independently reproducible off the server
# seed. 2654435761 is the 32-bit golden-ratio constant (good spread, stays inside int64 for real rounds).
static func _derive_seed(seed: int, round_number: int) -> int:
	return seed + round_number * 2654435761
