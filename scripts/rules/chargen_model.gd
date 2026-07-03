extends RefCounted
## Pure WEG D6 R&E character-creation rules (C1).
##
## Validates a character build and produces a starting sheet in the
## data/schemas/player_persistence `sheet` shape. WEG R&E (Guide_02): distribute
## exactly 18D (54 pips) of attribute dice among the six attributes, each within the
## species min/max; spend up to 7D (21 pips) of skill-dice bonuses above the parent
## attribute (unspent is lost). Starting CP 5 / FP 1. Force-sensitivity is an
## OWNER-GATED data hook — declared here as a flag only, default false; no Jedi rules.
##
## Pure/socket-free: pool math is delegated to a passed `rules` object (the D6Rules
## autoload, or a fresh instance in tests), so this is headlessly unit-testable.

const ForceSkillsModel = preload("res://scripts/rules/force_skills_model.gd")
const ForceAwakeningModel = preload("res://scripts/rules/force_awakening_model.gd")  # DIV-0011 earned-unlock seed
const EconomyModel = preload("res://scripts/rules/economy_model.gd")  # single source for STARTING_CREDITS

const ATTRS := ["dexterity", "knowledge", "mechanical", "perception", "strength", "technical"]
const ATTRIBUTE_PIPS := 54   # 18D total to distribute (exactly)
const SKILL_PIPS := 21       # 7D total skill-dice budget (a maximum)
const START_CP := 5
const START_FP := 1
const STARTER_WEAPON := "blaster_pistol"   # data/weapons_clone_wars.json
const STARTER_ARMOR := "blast_vest"        # data/armor_clone_wars.json
# Owned-item inventory a fresh character starts with (equip-swap candidates, E22). Keys
# are real catalog entries: the equipped sidearm + vest, plus a concealed hold-out
# blaster and a blast helmet so a loadout swap is possible from the first login.
const STARTER_INVENTORY := ["blaster_pistol", "blast_vest", "hold_out_blaster", "blast_helmet"]

static func _pips(rules: Object, code: String) -> int:
	var pool: Dictionary = rules.parse_pool(code)
	return int(pool["dice"]) * 3 + int(pool["pips"])

static func _pips_to_code(rules: Object, pips: int) -> String:
	return String(rules.pool_to_string(rules.normalize_pool(0, maxi(pips, 0))))

## Reserved / canonical Star Wars character names a player may not self-name as (Wave G
## item G7). Ported (one-way, read-only) from the SW_MUSH inspiration's server-side chargen
## policy — C:\SW_MUSH\engine\chargen_validator.py `FORBIDDEN_NAMES` — and generalized per
## C:\SW_MUSH\CLAUDE.md's hard invariant "Canonical Clone Wars figures never appear as
## open-world NPCs": the same principle applied to player self-naming, and broadened past
## Clone Wars to the other eras' most recognizable figures (Vader, Leia, Han, etc.) since a
## player could otherwise dodge the block by picking an OT-era name instead.
##
## Matching (see `is_reserved_name`): case-insensitive, and matched against the WHOLE
## submitted name and each individual whitespace-separated token, never a substring — so
## ordinary original names that merely CONTAIN a reserved word (e.g. "Kenobiwan",
## "Reximus") are NOT falsely rejected. Multi-word entries below (e.g. "shaak ti",
## "han solo") therefore only trip on an exact full-name match, since their individual
## words alone ("ti", "solo", "bane") are too common/ordinary to block on their own.
const RESERVED_NAMES := [
	# Jedi / Clone Wars principals
	"anakin", "skywalker", "obi-wan", "obiwan", "kenobi", "padme", "padmé", "amidala",
	"ahsoka", "tano", "yoda", "mace", "windu", "qui-gon", "quigon",
	"palpatine", "sidious", "dooku", "grievous", "maul", "ventress", "asajj", "vader",
	"rex", "cody", "satine", "kryze",
	# Multi-word-only entries: their bare component words are ordinary enough that
	# blocking them individually would over-reject real players.
	"shaak ti", "plo koon", "kit fisto", "luminara unduli", "barriss offee",
	"cad bane", "hondo ohnaka", "wedge antilles", "biggs darklighter",
	# Original-trilogy principals — still canonical figures, blocked across eras.
	"leia", "organa", "luke", "chewbacca", "lando", "calrissian", "boba", "jango",
	"fett", "tarkin", "jabba", "han solo",
]

## True if `name` is (or contains, as a whole word/token) a reserved canonical Star Wars
## figure name. Case-insensitive. See RESERVED_NAMES doc comment for the matching rule.
static func is_reserved_name(name: String) -> bool:
	var normalized := String(name).strip_edges().to_lower()
	if normalized == "":
		return false
	if RESERVED_NAMES.has(normalized):
		return true
	for token in normalized.split(" ", false):
		if RESERVED_NAMES.has(token):
			return true
	return false

## Validate an attribute (+ optional skill) allocation against a species. Returns
## {valid, errors, sheet}. `attributes`/`skills` are {key: "XD+y"} dice codes.
## `character_name`, when non-empty, is checked against the reserved-name policy above;
## an empty string skips the name check (callers that don't yet have a name to validate).
static func validate_build(rules: Object, species: Dictionary, attributes: Dictionary, skills: Dictionary = {}, character_name: String = "") -> Dictionary:
	var errors: Array = []
	var ranges: Dictionary = species.get("attributes", {})

	var total := 0
	for attribute in ATTRS:
		if not attributes.has(attribute):
			errors.append("missing attribute: %s" % attribute)
			continue
		var p := _pips(rules, String(attributes[attribute]))
		total += p
		var span: Dictionary = ranges.get(attribute, {})
		if span.has("min") and p < _pips(rules, String(span["min"])):
			errors.append("%s below species minimum %s" % [attribute, span["min"]])
		if span.has("max") and p > _pips(rules, String(span["max"])):
			errors.append("%s above species maximum %s" % [attribute, span["max"]])
	if total != ATTRIBUTE_PIPS:
		errors.append("attributes must total exactly 18D (got %s)" % _pips_to_code(rules, total))

	var skill_total := 0
	for key in skills:
		var sp := _pips(rules, String(skills[key]))
		if sp < 0:
			errors.append("skill %s cannot be negative" % key)
		skill_total += sp
	if skill_total > SKILL_PIPS:
		errors.append("skill dice exceed the 7D budget (spent %s)" % _pips_to_code(rules, skill_total))

	if character_name != "" and is_reserved_name(character_name):
		errors.append("character name '%s' is reserved for a canonical Star Wars figure" % character_name)

	var valid := errors.is_empty()
	return {
		"valid": valid,
		"errors": errors,
		"skill_pips_spent": skill_total,
		"sheet": build_sheet(rules, attributes, skills) if valid else {},
	}

## Produce the persisted `sheet` from a (validated) allocation.
static func build_sheet(rules: Object, attributes: Dictionary, skills: Dictionary = {}) -> Dictionary:
	var attr := {}
	for attribute in ATTRS:
		attr[attribute] = String(rules.pool_to_string(rules.parse_pool(String(attributes.get(attribute, "2D")))))
	var sk := {}
	for key in skills:
		sk[key] = String(rules.pool_to_string(rules.parse_pool(String(skills[key]))))
	return {
		"attributes": attr,
		"skills": sk,
		"character_points": START_CP,
		"force_points": START_FP,
		"force_sensitive": false,
		"force_skills": ForceSkillsModel.initial_force_skills(),
		"force_unlock": ForceAwakeningModel.initial_unlock(),  # DIV-0011: dormant SWG-Village track
		"wound_state": "healthy",
		"credits": EconomyModel.STARTING_CREDITS,  # Wave F: WEG-anchored economy (DIV-0018)
		"equipment": {"weapon": STARTER_WEAPON, "armor": STARTER_ARMOR},
		"inventory": STARTER_INVENTORY.duplicate(),
	}

## A deterministic quick-start attribute allocation: each attribute at its species
## minimum, then the remaining pips distributed round-robin into attributes with
## headroom until exactly 18D is spent. Always within species ranges when feasible.
static func default_build(rules: Object, species: Dictionary) -> Dictionary:
	var ranges: Dictionary = species.get("attributes", {})
	var pips := {}
	var total := 0
	for attribute in ATTRS:
		var mn := _pips(rules, String((ranges.get(attribute, {}) as Dictionary).get("min", "2D")))
		pips[attribute] = mn
		total += mn
	var remaining := ATTRIBUTE_PIPS - total
	while remaining > 0:
		var progressed := false
		for attribute in ATTRS:
			if remaining <= 0:
				break
			var mx := _pips(rules, String((ranges.get(attribute, {}) as Dictionary).get("max", "4D")))
			if int(pips[attribute]) < mx:
				pips[attribute] = int(pips[attribute]) + 1
				remaining -= 1
				progressed = true
		if not progressed:
			break  # species ranges cannot reach 18D (infeasible)
	var attributes := {}
	for attribute in ATTRS:
		attributes[attribute] = _pips_to_code(rules, int(pips[attribute]))
	return attributes

## Convenience: a full valid default character sheet for a species (no skills spent).
static func default_sheet(rules: Object, species: Dictionary) -> Dictionary:
	return build_sheet(rules, default_build(rules, species), {})
