extends RefCounted
# downed_model.gd
#
# Pure decision core for Wave G1 death TIERING + the mandatory downed escape hatch
# (DIV-0027, extends DIV-0006 death penalty + DIV-0019 PvP death). Stateless: every
# function is `static func`; no nodes, no sockets, no rendering, no _process. All
# randomness flows through a caller-supplied RandomNumberGenerator (the SERVER owns
# the seed); this file NEVER calls randomize(). Keeps the tier classification +
# bleed-out + safety-net deterioration headlessly unit-testable so the softlock-guard
# smoke asserts the REAL production decision, not a mirror.
#
# Tiering (owner ruling 2026-07-03): sev 5 = death (DIV-0006 full penalty + respawn,
# UNCHANGED); sev 3-4 = downed-in-the-field (NO penalty, frozen where they fell by the
# arena's DISABLED guard). A downed player is never softlocked:
#   (a) mortally_wounded (sev 4) bleeds out via recovery_model.death_roll, provably
#       terminating (2D maxes at 12, so `died` is CERTAIN once rounds >= 13);
#   (b) a downed player may voluntarily yield (network_manager.submit_yield);
#   safety net: an untreated incapacitated (sev 3) DETERIORATES to sev 4 after
#   INCAP_DETERIORATE_WINDOWS combat windows (tunable; <= 0 disables) so a passive/AFK
#   player also resolves. First Aid (DIV-0013) dropping below DISABLED revives.
#
# Grounding (read-only reference):
#   - C:\SW_MUSH\docs\design\Guide_19_Medical_Death.md §1 (wound ladder: incapacitated
#       is stable/unconscious; mortally_wounded rolls a death check each round, "most
#       die within 3-5 rounds").
#   - recovery_model.death_roll (WEG R&E): 2D each round; total < rounds -> dies.

const Recovery = preload("res://scripts/rules/recovery_model.gd")

# Mirrors CombatArena.DISABLED_SEVERITY (the "out"/downed floor) and
# PvpRules.PVP_DEATH_SEVERITY (the death tier). Kept local so the pure model has no
# net-layer dependency; the smokes assert these agree with the shipped constants.
const DISABLED_SEVERITY := 3
const KILL_SEVERITY := 5
# Sev-3 (incapacitated) safety net: after this many downed combat windows an untreated
# incapacitated player deteriorates to mortally_wounded (sev 4), which then bleeds out.
# ~12 windows @ 5s = ~60s. Set <= 0 to DISABLE (yield-only for sev 3).
const INCAP_DETERIORATE_WINDOWS := 12
# Proof bound: recovery_model.death_roll's 2D maxes at 12, so `died` is certain once the
# mortally-wounded round count reaches this. Used by the softlock-guard smoke.
const MORTAL_CERTAIN_ROUNDS := 13

# Route a takeout severity: "kill" (sev >= 5 -> full death), "downed" (3-4 -> in-field),
# or "none" (< 3, not a takeout).
static func classify(sev: int) -> String:
	if sev >= KILL_SEVERITY:
		return "kill"
	if sev >= DISABLED_SEVERITY:
		return "downed"
	return "none"

# True for the downed band only (3-4): disabled but not dead.
static func is_downed_severity(sev: int) -> bool:
	return sev >= DISABLED_SEVERITY and sev < KILL_SEVERITY

# One downed combat-window tick. Deterministic given (entry, rng). Reads
# {severity:int, rounds:int}; returns {action, next_severity, rounds}:
#   sev >= KILL      -> "die"          (a finishing hit already put them dead)
#   sev <  DISABLED  -> "revived"      (a medic dropped them below the downed floor)
#   sev == 4         -> death_roll; "die" if it fails, else "hold" (carry rounds+1)
#   sev == 3         -> "hold" (rounds+1) until INCAP_DETERIORATE_WINDOWS, then
#                       "deteriorate" (next_severity 4, rounds reset) — the safety net.
# next_severity/rounds are what the CALLER should store for the next tick.
static func downed_tick(entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var sev := int(entry.get("severity", DISABLED_SEVERITY))
	var rounds := int(entry.get("rounds", 0))
	if sev >= KILL_SEVERITY:
		return {"action": "die", "next_severity": sev, "rounds": rounds}
	if sev < DISABLED_SEVERITY:
		return {"action": "revived", "next_severity": sev, "rounds": rounds}
	if sev == 4:
		var next_rounds := rounds + 1
		var roll: Dictionary = Recovery.death_roll(rng, next_rounds)
		if bool(roll.get("died", false)):
			return {"action": "die", "next_severity": sev, "rounds": next_rounds}
		return {"action": "hold", "next_severity": sev, "rounds": next_rounds}
	# sev == 3 (incapacitated): stable/unconscious, no death roll — but a safety net so a
	# passive/AFK medic-less player still auto-resolves.
	var r := rounds + 1
	if INCAP_DETERIORATE_WINDOWS > 0 and r >= INCAP_DETERIORATE_WINDOWS:
		return {"action": "deteriorate", "next_severity": 4, "rounds": 0}
	return {"action": "hold", "next_severity": sev, "rounds": r}
