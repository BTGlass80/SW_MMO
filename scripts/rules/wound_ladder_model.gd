extends RefCounted
# wound_ladder_model.gd
#
# Canonical WEG Star Wars D6 Revised & Expanded CUMULATIVE wound ladder, including
# the "Wounded Twice" tier (-2D) that the prototype's ground_combat penalty table had
# silently collapsed. Pure + stateless (every function is `static func`); no nodes,
# no RNG, no rendering. See docs/DIVERGENCE_LEDGER.md DIV-0008.
#
# Grounding (read-only reference):
#   - C:\SW_MUSH\docs\design\Guide_01_WEG_D6_Core_Mechanics.md §7 (Wound Penalties,
#     WoundLevel HEALTHY(0)..DEAD(6), apply_wound() cumulative rules lines 392-413).
#   - C:\SW_MUSH\docs\design\Guide_19_Medical_Death.md §1 (The Wound Ladder).
#   - WEG R&E p.83 damage chart + cumulative wound escalation.
#
# WEG / SW_MUSH wound ladder (worst-increasing index):
#   0 healthy          0D  penalty   can act
#   1 stunned         -1D  penalty   can act  (per active stun in WEG; here one step)
#   2 wounded         -1D  penalty   can act
#   3 wounded_twice   -2D  penalty   can act
#   4 incapacitated    -   (out, cannot act -> penalty is moot, modeled as 0D)
#   5 mortally_wounded -   (bleeding out, cannot act -> penalty moot, 0D)
#   6 dead             -   (out -> penalty moot, 0D)

# Worst-increasing index. Index in this array IS the ladder rank used by escalate().
const LEVELS := [
	"healthy",
	"stunned",
	"wounded",
	"wounded_twice",
	"incapacitated",
	"mortally_wounded",
	"dead",
]

# Per-level dice penalty applied to all rolls (Guide_19 §1 ladder table,
# Guide_01 §7 / WoundLevel.penalty_dice lines 392-394).
#   healthy          0D  — no penalty.
#   stunned         -1D  — glancing blow fog (WEG: -1D per active stun timer).
#   wounded         -1D  — real injury until healed.
#   wounded_twice   -2D  — cumulative damage past the first wound.
#   incapacitated    0   — unconscious / out; cannot act so the penalty is moot.
#   mortally_wounded 0   — bleeding out; cannot act so the penalty is moot.
#   dead             0   — out; penalty moot.
static func penalty_dice_for_level(level: String) -> int:
	match level:
		"healthy":
			return 0
		"stunned":
			return 1
		"wounded":
			return 1
		"wounded_twice":
			return 2
		"incapacitated":
			return 0  # (out) — cannot act; WEG penalty is moot (Guide_19 §1 / Guide_01 §7 L393)
		"mortally_wounded":
			return 0  # (bleeding) — cannot act; penalty moot
		"dead":
			return 0
		_:
			return 0

# Maps the SINGLE-HIT damage chart severity (0-5, as produced by
# D6Rules.wound_for_damage_margin) to a ladder level. The single-hit chart never
# yields "wounded_twice" on its own (that tier is purely cumulative via escalate()):
#   0 -> healthy, 1 -> stunned, 2 -> wounded, 3 -> incapacitated,
#   4 -> mortally_wounded, 5 -> dead.
static func level_for_severity(severity: int) -> String:
	match severity:
		0:
			return "healthy"
		1:
			return "stunned"
		2:
			return "wounded"
		3:
			return "incapacitated"
		4:
			return "mortally_wounded"
		5:
			return "dead"
		_:
			# Defensive: clamp out-of-range below 0 to healthy, above 5 to dead.
			if severity < 0:
				return "healthy"
			return "dead"

# Penalty dice for a single-hit severity. The actable wound tiers route through the
# ladder (wounded_twice now yields -2D via escalate(), where ground_combat's old
# _wound_penalty_dice silently returned 0D). Per WEG canon (Guide_19 §1 / Guide_01 §7
# L393) the "out" tiers carry NO penalty — a downed character takes no actions, so the
# penalty is moot:
#   sev 0 -> 0D  (healthy)        — UNCHANGED from old ground_combat
#   sev 1 -> 1D  (stunned)        — UNCHANGED
#   sev 2 -> 1D  (wounded)        — UNCHANGED
#   sev 3 -> 0D  (incapacitated, out/moot — can't act)
#   sev 4 -> 0D  (mortally, out/moot — can't act)
#   sev 5 -> 0D  (dead, moot)
static func penalty_dice_for_severity(severity: int) -> int:
	return penalty_dice_for_level(level_for_severity(severity))

# Returns the ladder index (rank) of a level; unknown levels rank as healthy (0).
static func level_index(level: String) -> int:
	var idx := LEVELS.find(level)
	if idx < 0:
		return 0
	return idx

# The single-hit SEVERITY int (0-5) that represents a ladder level — the inverse the arena uses to
# derive its `player_wound_severity` int from the level string it accumulates via escalate(). MUST
# stay in lockstep with PersistenceStore.severity_for_wound_state (persistence uses the same mapping);
# the wound-ladder smoke asserts they agree. NOTE the deliberate collapse: `wounded_twice` has no
# single-hit severity (it is purely cumulative) so it shares `wounded`'s int (2) — the level STRING,
# not this int, is the cross-window source of truth for accumulation (severity 2 -> level_for_severity
# gives "wounded", never "wounded_twice", so escalation must key off the level, not the int).
static func severity_for_level(level: String) -> int:
	match level:
		"healthy": return 0
		"stunned": return 1
		"wounded", "wounded_twice": return 2
		"incapacitated": return 3
		"mortally_wounded": return 4
		"dead": return 5
	return 0

# CUMULATIVE WEG escalation (Guide_19 §1, Guide_01 §7 apply_wound lines 409-413).
# Deterministic and TOTAL: defined for every (current_level, severity in 0..5).
#
# Cumulative transition rules:
#   * Monotonic: a hit never reduces the current level.
#   * severity 0 (no damage) -> current_level unchanged.
#   * stun (sev 1) on 'healthy' -> 'stunned'.
#   * stun (sev 1) on 'wounded' or 'wounded_twice' -> 'wounded_twice'
#       (a fresh stun on an already-wounded character deepens the wound; WEG: it
#        is treated as a wound, pushing toward Wounded Twice — Guide_01 line 413).
#   * 'wounded'        + wounded (sev 2) -> 'incapacitated'  (Guide_01 line 410).
#   * 'wounded_twice'  + wounded (sev 2) -> 'incapacitated'.
#   * 'incapacitated'  + ANY further damage (sev >= 1) -> 'mortally_wounded'
#       (Guide_01 line 411).
#   * 'mortally_wounded' + ANY further damage (sev >= 1) -> 'dead' (Guide_01 line 412).
#   * 'dead' is absorbing: stays 'dead'.
#
# Then a DIRECT incoming level worse than the cumulative transition wins:
#   result = worse-of( cumulative_transition , level_for_severity(incoming) ).
# So 'healthy' + incapacitating hit (sev 3) -> 'incapacitated', and anything + a
# killing hit (sev 5) -> 'dead'.
#
# Full cumulative-transition table (before the direct-level merge), rows = current
# level, cols = incoming severity:
#                | sev0 | sev1(stun) | sev2(wound) | sev3 | sev4 | sev5
#   healthy      | =    | stunned    | wounded     | inc  | mort | dead
#   stunned      | =    | stunned*   | wounded     | inc  | mort | dead
#   wounded      | =    | w_twice    | incapacit.  | inc  | mort | dead
#   wounded_twice| =    | w_twice    | incapacit.  | inc  | mort | dead
#   incapacitated| =    | mortally   | mortally    | mort | mort | dead
#   mortally     | =    | dead       | dead        | dead | dead | dead
#   dead         | =    | dead       | dead        | dead | dead | dead
#   (* stun-on-stunned stays stunned here; the direct-level merge with
#      level_for_severity(sev>=3) supplies the worse tier when relevant.)
static func escalate(current_level: String, incoming_severity: int) -> String:
	var current := current_level
	if LEVELS.find(current) < 0:
		current = "healthy"

	# severity 0 never changes anything.
	if incoming_severity <= 0:
		return current

	# Dead is absorbing.
	if current == "dead":
		return "dead"

	var transition := current

	match current:
		"healthy":
			# Fresh single hit: ladder level for the incoming severity.
			transition = level_for_severity(incoming_severity)
		"stunned":
			if incoming_severity == 1:
				transition = "stunned"
			else:
				transition = level_for_severity(incoming_severity)
		"wounded", "wounded_twice":
			if incoming_severity == 1:
				# Stun on an already-wounded character deepens to Wounded Twice.
				transition = "wounded_twice"
			elif incoming_severity == 2:
				# Wounded + Wounded -> Incapacitated.
				transition = "incapacitated"
			else:
				transition = level_for_severity(incoming_severity)
		"incapacitated":
			# Any further damage -> Mortally Wounded.
			transition = "mortally_wounded"
		"mortally_wounded":
			# Any further damage -> Dead.
			transition = "dead"
		_:
			transition = current

	# A direct incoming level worse than the cumulative transition wins.
	var direct := level_for_severity(incoming_severity)
	var transition_idx := level_index(transition)
	var direct_idx := level_index(direct)
	var current_idx := level_index(current)
	var result_idx := maxi(maxi(transition_idx, direct_idx), current_idx)
	return LEVELS[result_idx]
