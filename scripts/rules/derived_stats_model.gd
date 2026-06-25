extends RefCounted

# Derived-stats model (Wave E / E4).
#
# Pure, scene-independent WEG D6 derived statistics computed from a character
# sheet (shape from character_sheet_model.gd) and the species data table
# (data/species_clone_wars.json). All dice math is delegated to a 'rules'
# instance (the D6Rules autoload / d6_rules.gd) passed in by the caller, exactly
# like character_sheet_model.gd -- this model never constructs an autoload.

const DEFAULT_MOVE := 10

func canonical_key(label):
	return String(label).strip_edges().to_lower().replace(" ", "_").replace("-", "_").replace("/", "_")

# Base movement (meters/round) for a species. Defaults to DEFAULT_MOVE when the
# species or its move field is missing.
func move_for_species(species_data: Dictionary, species_key: String) -> int:
	var species := {}
	var raw_species: Variant = species_data.get("species", {})
	if typeof(raw_species) == TYPE_DICTIONARY:
		species = raw_species
	var entry: Variant = species.get(canonical_key(species_key), null)
	if typeof(entry) != TYPE_DICTIONARY:
		return DEFAULT_MOVE
	if not entry.has("move"):
		return DEFAULT_MOVE
	return int(entry.get("move", DEFAULT_MOVE))

# WEG base soak = the Strength attribute pool.
func base_soak(rules, sheet) -> Dictionary:
	return _strength_pool(rules, sheet)

# The Strength pool used as the base for melee/brawling damage
# (WEG: melee damage = STR + weapon STR-bonus).
func strength_melee_bonus(rules, sheet) -> Dictionary:
	return _strength_pool(rules, sheet)

# Full melee/brawling damage pool = STR + weapon STR-bonus.
# weapon_bonus is a pool string like "+2" or "1D"; empty -> just STR.
func melee_damage_pool(rules, sheet, weapon_bonus) -> Dictionary:
	var base := _strength_pool(rules, sheet)
	var bonus_text := String(weapon_bonus).strip_edges().to_upper().replace(" ", "")
	if bonus_text == "":
		return base
	# A pip-only bonus ("+2" / "2") has no "D"; rules.parse_pool would read it as
	# whole dice. Treat such forms as pips so "+2" adds two pips, not two dice.
	if not bonus_text.contains("D"):
		var pip_text := bonus_text
		if pip_text.begins_with("+"):
			pip_text = pip_text.substr(1)
		return rules.add_pips(base, int(pip_text))
	var bonus: Dictionary = rules.parse_pool(bonus_text)
	return rules.add_pools(base, bonus)

# WEG stun knockout is gauged in Strength DICE only (pips ignored).
func stun_knockout_threshold(rules, sheet) -> int:
	var pool := _strength_pool(rules, sheet)
	return int(pool.get("dice", 0))

func _strength_pool(rules, sheet) -> Dictionary:
	var attributes: Variant = sheet.get("attributes", {})
	var strength_text := "0D"
	if typeof(attributes) == TYPE_DICTIONARY:
		strength_text = String(attributes.get("strength", "0D"))
	return rules.parse_pool(strength_text)
