extends RefCounted
## Pure WEG D6 R&E Force-skill DATA HOOK (E6), OFF by default.
##
## Declares the three WEG Force skills (control, sense, alter) as an inert data hook.
## This is intentionally minimal: NO power list, NO scarcity / owner-gated access
## policy, NO Jedi rules. It only provides the off-by-default plumbing so the rest of
## the system can ask "does this sheet have Force skills, and what are their pools?"
## without any of those skills being usable unless the sheet is explicitly
## force-sensitive (`force_sensitive == true`).
##
## Pure / socket-free: pool math is delegated to a passed `rules` object (the D6Rules
## autoload, or a fresh instance in tests), so this is headlessly unit-testable.

## The three WEG R&E Force skills. Order is the canonical control / sense / alter.
const FORCE_SKILLS := ["control", "sense", "alter"]

## True ONLY when the sheet is explicitly force-sensitive. Default off: a sheet with
## no `force_sensitive` flag (or a falsey one) can never use the Force.
static func can_use_force(sheet: Dictionary) -> bool:
	return bool(sheet.get("force_sensitive", false))

## The off-by-default initial Force-skill block: all three at 0D, inactive. These are
## inert unless the sheet is also force-sensitive (see `can_use_force`).
static func initial_force_skills() -> Dictionary:
	return {"control": "0D", "sense": "0D", "alter": "0D"}

## The Force-skill dice codes stored on a sheet, or {} when the sheet has none.
static func force_skills(sheet: Dictionary) -> Dictionary:
	return sheet.get("force_skills", {})

## The dice pool for one Force skill. Returns an empty {dice:0,pips:0} pool when the
## sheet is not force-sensitive OR the skill is not one of the three WEG Force skills;
## otherwise parses the stored code (defaulting to "0D" when absent).
static func force_skill_pool(rules, sheet: Dictionary, skill: String) -> Dictionary:
	if not can_use_force(sheet) or not FORCE_SKILLS.has(skill):
		return {"dice": 0, "pips": 0}
	return rules.parse_pool(String(force_skills(sheet).get(skill, "0D")))
