extends RefCounted
# recovery_model.gd
#
# Wound RECOVERY / healing model for the WEG Star Wars D6 Revised & Expanded wound
# ladder. Pure + stateless (every function is `static func`); no nodes, no sockets,
# no rendering, no _process. ALL randomness flows through a caller-supplied
# RandomNumberGenerator (the SERVER owns the seed); this file NEVER calls
# randomize(). See docs/DIVERGENCE_LEDGER.md (E2/E3 wound-ladder + recovery rows).
#
# Scope: recovery mechanics ONLY — stun expiry, First Aid/Medicine heal checks, the
# Mortally Wounded death roll, and the post-death (-1D) debuff window. Owner-gated
# death-PENALTY systems (corpse loot, gear decay, insurance, respawn timers) live
# elsewhere and are intentionally NOT modeled here.
#
# Grounding (read-only reference):
#   - C:\SW_MUSH\docs\design\Guide_19_Medical_Death.md
#       §1 The Wound Ladder (stun timers "typically 2" rounds; Mortally Wounded
#           rolls a death check each round, "most die within 3-5 rounds").
#       §3 Getting Healed (heal = First Aid/Medicine skill vs. a wound-level
#           difficulty; on success the wound level drops by ONE step).
#       §5 The wound-state debuff (-1D for 1 real-time hour after death).
#   - C:\SW_MUSH\docs\design\Guide_01_WEG_D6_Core_Mechanics.md §7 (wound ladder /
#       stun timers expire after a set number of rounds).
#   - WEG R&E rulebook: Mortally Wounded characters roll 2D each round; if the 2D
#       total is LESS THAN the number of rounds spent Mortally Wounded, they die.
#
# Level ordering is owned by E2's WoundLadderModel.LEVELS (worst-increasing index):
#   ["healthy","stunned","wounded","wounded_twice","incapacitated",
#    "mortally_wounded","dead"]. Healing walks that index toward 0 ("healthy").

const WoundLadderModel = preload("res://scripts/rules/wound_ladder_model.gd")

# --- Stun recovery ---------------------------------------------------------
# Guide_19 §1: a stun timer "lasts a few rounds (typically 2)" then lifts on its
# own — stun is the only wound-level penalty that auto-clears without intervention.
const STUN_RECOVERY_ROUNDS := 2

# --- Post-death debuff -----------------------------------------------------
# Guide_19 §5: after death/respawn a character carries a flat -1D "wound_state"
# debuff. The narrative window is one real-time hour; in ROUND terms this model
# carries the -1D for DEATH_DEBUFF_ROUNDS combat rounds after revive. (Real-time
# auto-clear / bacta clearance is a presentation/economy concern handled elsewhere.)
const DEATH_DEBUFF_ROUNDS := 6
const DEATH_DEBUFF_DICE := 1

# --- Heal difficulty table (Guide_19 §3 "Difficulty by wound level") --------
# Target's wound level -> First Aid / Medicine target number. Values are taken
# verbatim from the Guide_19 §3 table / §9 "Numbers At A Glance":
#   Stunned          Easy (8)
#   Wounded          Moderate (11)
#   Wounded Twice    Moderate+ (14)
#   Incapacitated    Difficult (16)
#   Mortally Wounded Very Difficult (21)
#   Dead             Beyond medical help (no heal possible)
# "healthy" has no wound to treat (nothing to heal -> sentinel 0 difficulty).
const HEAL_DIFFICULTY := {
	"healthy": 0,
	"stunned": 8,
	"wounded": 11,
	"wounded_twice": 14,
	"incapacitated": 16,
	"mortally_wounded": 21,
	"dead": -1,
}

# True once a stun has aged out (Guide_19 §1: stun lifts after STUN_RECOVERY_ROUNDS).
static func stun_recovered(rounds_since_stun: int) -> bool:
	return rounds_since_stun >= STUN_RECOVERY_ROUNDS

# Non-mutating per-round tick of a stun state dictionary. Expects a
# {"level": String, "rounds_remaining": int} shape; decrements the counter and,
# at <= 0, clears back to "healthy" (and pins rounds_remaining at 0). Returns a
# fresh duplicate; the input dictionary is never modified.
static func tick_stun(stun_state: Dictionary) -> Dictionary:
	var next := stun_state.duplicate(true)
	var remaining := int(next.get("rounds_remaining", STUN_RECOVERY_ROUNDS)) - 1
	if remaining <= 0:
		next["rounds_remaining"] = 0
		next["level"] = "healthy"
	else:
		next["rounds_remaining"] = remaining
	return next

# Heal difficulty (First Aid/Medicine target number) for a wound level. Unknown
# levels and "healthy" return 0 (nothing to treat); "dead" returns -1 (beyond
# medical help). Guide_19 §3.
static func heal_difficulty_for_level(level: String) -> int:
	return int(HEAL_DIFFICULTY.get(level, 0))

# Sum a {"dice":int,"pips":int} pool as a plain roll total: each die is rng-rolled
# 1..6, pips add flat. Deterministic given the rng's seed/state. (Recovery checks
# do not use the Wild Die / explosion here — a First Aid roll is a straight skill
# total against a fixed difficulty per Guide_19 §3.)
static func roll_pool_total(rng: RandomNumberGenerator, pool: Dictionary) -> int:
	var dice := int(pool.get("dice", 0))
	var pips := int(pool.get("pips", 0))
	var total := pips
	for _i in range(maxi(dice, 0)):
		total += rng.randi_range(1, 6)
	return total

# First Aid / Medicine heal check (Guide_19 §3). Rolls heal_pool vs. the current
# wound level's difficulty number. On SUCCESS (roll_total >= difficulty) the level
# drops EXACTLY ONE step toward "healthy" (WoundLadderModel.LEVELS index - 1,
# clamped at 0). On FAILURE the level is unchanged. "healthy" and "dead" cannot be
# meaningfully healed (no wound / beyond help) -> always healed:false, unchanged.
static func heal_check(rng: RandomNumberGenerator, heal_pool: Dictionary, current_level: String) -> Dictionary:
	var level := current_level
	if WoundLadderModel.LEVELS.find(level) < 0:
		level = "healthy"
	var difficulty := heal_difficulty_for_level(level)
	var roll_total := roll_pool_total(rng, heal_pool)

	# Nothing to treat (healthy = 0) or beyond medical help (dead = -1).
	if level == "healthy" or level == "dead" or difficulty <= 0:
		return {
			"success": false,
			"roll_total": roll_total,
			"difficulty": difficulty,
			"new_level": level,
			"healed": false,
		}

	var success := roll_total >= difficulty
	var new_level := level
	if success:
		# Explicit int type (not ':=') so inference never depends on the parser
		# resolving Array.find()'s return type through a preloaded-script const.
		var idx: int = WoundLadderModel.LEVELS.find(level)
		var lower := maxi(idx - 1, 0)
		new_level = String(WoundLadderModel.LEVELS[lower])
	return {
		"success": success,
		"roll_total": roll_total,
		"difficulty": difficulty,
		"new_level": new_level,
		"healed": success and new_level != level,
	}

# Mortally Wounded death roll (WEG R&E). Each round a Mortally Wounded character
# rolls 2D; if the total is LESS THAN the number of rounds spent Mortally Wounded,
# the character dies. Deterministic given rng + rounds_mortally_wounded.
static func death_roll(rng: RandomNumberGenerator, rounds_mortally_wounded: int) -> Dictionary:
	var roll_total := rng.randi_range(1, 6) + rng.randi_range(1, 6)
	var died := roll_total < rounds_mortally_wounded
	return {
		"roll_total": roll_total,
		"died": died,
		"rounds": rounds_mortally_wounded,
	}

# Post-death debuff dice (Guide_19 §5). Returns DEATH_DEBUFF_DICE (-1D) while still
# inside the post-revive window, else 0 once it has elapsed.
static func death_debuff_dice(rounds_since_revive: int) -> int:
	if rounds_since_revive < DEATH_DEBUFF_ROUNDS:
		return DEATH_DEBUFF_DICE
	return 0
