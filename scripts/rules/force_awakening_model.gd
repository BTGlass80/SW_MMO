extends RefCounted
## Pure "SWG Village" Force-awakening track (Wave F / DIV-0011 — the earned, rare, hidden unlock).
##
## Owner decision 2026-07-01: force_sensitive is NOT chargen-selectable and NOT open — it is EARNED
## via a hidden, multi-phase 'awakening' modeled on SWG's Village of Aurilia, adapted to Clone Wars
## 20 BBY (underground Force-latents, not the open Jedi Order). This model owns a 4-phase achievement
## gate on `sheet.force_unlock`, advanced ONLY by deterministic in-play signals (lifetime CP spent,
## distinct zones, combat disables, First-Aid heals given, wound recoveries, tense-zone ticks) plus
## a server-owned RARE manifest roll behind a hard attunement prerequisite and a server-wide soft cap.
## On Phase-4 completion `apply_completion` flips `sheet.force_sensitive=true`, activating the
## off-by-default force_skills_model.
##
## All-static, NO RNG of its own — the two chance rolls take an explicit server-owned RNG so the
## server keeps ownership of every die (headlessly testable with a seeded RNG). Every rarity dial is
## a tunable const exposed at the top.

const ForceSkillsModel := preload("res://scripts/rules/force_skills_model.gd")

# --- phases: DORMANT -> 1 -> 2 -> 3 -> 4 -> COMPLETE ---
const PHASE_DORMANT := 0   # no latent stirring yet
const PHASE_COMPLETE := 5   # awakened (force_sensitive flipped)

# --- rarity dials (owner-tunable; defaulted RARE per the 2026-07-02 ruling) ---
const MANIFEST_CHANCE_PER_TICK := 0.02   # DORMANT->1 rare manifest roll (~2%/Director tick)
const AWAKEN_CHANCE_PER_TICK := 0.10     # phase 4 -> COMPLETE final awaken roll
const AWAKEN_SERVER_SOFT_CAP := 8        # server-wide cap on awakened + in-progress latents (manifest gate)
const MANIFEST_PREREQ_ATTUNEMENT := 10   # hard floor of attunement before a manifest can even roll

# Weighted "attunement" contribution per deterministic signal. Rare/meaningful acts (visiting new
# places, disabling a foe, saving an ally, surviving a wound) weigh more than raw CP grinding.
const SIGNAL_WEIGHTS := {
	"cp_spent": 1,        # lifetime Character Points spent on skill raises
	"zones_visited": 3,   # distinct zones the character has entered
	"disables": 2,        # combat disables / kills credited
	"heals_given": 2,     # First-Aid heals applied to allies
	"recoveries": 2,      # wounds survived + recovered from
	"tense_ticks": 1,     # Director ticks spent in a high-alert / lawless / contested zone
}
# Cumulative attunement required to advance OUT of each in-progress phase (index = current phase).
# Phase 4's 100 is the prerequisite for the awaken roll (not an automatic advance).
const ADVANCE_THRESHOLD := {1: 25, 2: 45, 3: 70, 4: 100}

# A fresh, dormant track (seeded at chargen). All signals at zero.
static func initial_unlock() -> Dictionary:
	return {
		"phase": PHASE_DORMANT,
		"signals": {"cp_spent": 0, "zones_visited": 0, "disables": 0, "heals_given": 0, "recoveries": 0, "tense_ticks": 0},
	}

# Normalize a possibly-partial / JSON-widened unlock dict (ints re-coerced from float on reload).
static func _normalized(unlock: Dictionary) -> Dictionary:
	var base := initial_unlock()
	var out := {"phase": int(unlock.get("phase", PHASE_DORMANT)), "signals": {}}
	var sig_in: Dictionary = unlock.get("signals", {})
	for k in (base["signals"] as Dictionary):
		(out["signals"] as Dictionary)[k] = int(sig_in.get(k, 0))
	return out

# NON-mutating: accrue `amount` (clamped >= 0) of a known signal. Unknown keys are ignored.
static func record_signal(unlock: Dictionary, signal_key: String, amount: int = 1) -> Dictionary:
	var next := _normalized(unlock)
	if not (next["signals"] as Dictionary).has(signal_key) or amount <= 0:
		return next
	(next["signals"] as Dictionary)[signal_key] = int((next["signals"] as Dictionary)[signal_key]) + amount
	return next

# Weighted attunement score from the accrued signals.
static func attunement_score(unlock: Dictionary) -> int:
	var sig: Dictionary = _normalized(unlock)["signals"]
	var score := 0
	for k in SIGNAL_WEIGHTS:
		score += int(sig.get(k, 0)) * int(SIGNAL_WEIGHTS[k])
	return score

# A character counts against the server soft cap once it has begun awakening (phase >= 1),
# whether still in-progress or COMPLETE.
static func counts_toward_cap(unlock: Dictionary) -> bool:
	return int(_normalized(unlock)["phase"]) >= 1

static func is_complete(unlock: Dictionary) -> bool:
	return int(_normalized(unlock)["phase"]) >= PHASE_COMPLETE

# Eligible to ROLL the DORMANT->1 manifest: still dormant, attuned past the prerequisite, and the
# server is under its soft cap of latents (a manifest ADDS a new latent to the count).
static func can_manifest(unlock: Dictionary, server_awakened_count: int) -> bool:
	return int(_normalized(unlock)["phase"]) == PHASE_DORMANT \
		and attunement_score(unlock) >= MANIFEST_PREREQ_ATTUNEMENT \
		and server_awakened_count < AWAKEN_SERVER_SOFT_CAP

# Roll the manifest if eligible. Returns {unlock, manifested}.
static func try_manifest(rng: RandomNumberGenerator, unlock: Dictionary, server_awakened_count: int) -> Dictionary:
	var next := _normalized(unlock)
	if not can_manifest(next, server_awakened_count):
		return {"unlock": next, "manifested": false}
	if rng.randf() >= MANIFEST_CHANCE_PER_TICK:
		return {"unlock": next, "manifested": false}
	next["phase"] = 1
	return {"unlock": next, "manifested": true}

# Deterministic advancement through phases 1..4 as accumulated attunement crosses each threshold.
# Never enters COMPLETE (that needs the awaken roll). Returns {unlock, advanced, phase}.
static func try_advance(unlock: Dictionary) -> Dictionary:
	var next := _normalized(unlock)
	var advanced := false
	var score := attunement_score(next)
	while int(next["phase"]) >= 1 and int(next["phase"]) <= 3 \
			and score >= int(ADVANCE_THRESHOLD[int(next["phase"])]):
		next["phase"] = int(next["phase"]) + 1
		advanced = true
	return {"unlock": next, "advanced": advanced, "phase": int(next["phase"])}

# At phase 4 with the prerequisite attunement, roll the final awaken. NOT cap-gated: a phase-4
# latent already counts toward the cap, so completing does not add a new latent. Returns {unlock, awakened}.
static func try_awaken(rng: RandomNumberGenerator, unlock: Dictionary) -> Dictionary:
	var next := _normalized(unlock)
	if int(next["phase"]) != 4 or attunement_score(next) < int(ADVANCE_THRESHOLD[4]):
		return {"unlock": next, "awakened": false}
	if rng.randf() >= AWAKEN_CHANCE_PER_TICK:
		return {"unlock": next, "awakened": false}
	next["phase"] = PHASE_COMPLETE
	return {"unlock": next, "awakened": true}

# One Director-tick step of the whole track (the single entry point the server calls per candidate).
# Order: manifest (if dormant) -> deterministic advance -> awaken (if phase 4). Returns
# {unlock, changed, event, phase} where event is "manifest" | "advance" | "awaken" | "".
static func director_tick(rng: RandomNumberGenerator, unlock: Dictionary, server_awakened_count: int) -> Dictionary:
	var next := _normalized(unlock)
	if is_complete(next):
		return {"unlock": next, "changed": false, "event": "", "phase": int(next["phase"])}
	var event := ""
	if int(next["phase"]) == PHASE_DORMANT:
		var m := try_manifest(rng, next, server_awakened_count)
		next = m["unlock"]
		if bool(m["manifested"]):
			event = "manifest"
	var adv := try_advance(next)
	next = adv["unlock"]
	if bool(adv["advanced"]) and event == "":
		event = "advance"
	if int(next["phase"]) == 4:
		var a := try_awaken(rng, next)
		next = a["unlock"]
		if bool(a["awakened"]):
			event = "awaken"
	return {"unlock": next, "changed": event != "", "event": event, "phase": int(next["phase"])}

# NON-mutating: on COMPLETE, flip the sheet force-sensitive and ensure the (off-by-default)
# force-skill block exists so force_skills_model activates. The Force POWER list + Dark Side
# economy remain owner-gated — this only lights up the existing data hook. Returns a new sheet.
static func apply_completion(sheet: Dictionary) -> Dictionary:
	var next := sheet.duplicate(true)
	next["force_sensitive"] = true
	if not next.has("force_skills") or typeof(next["force_skills"]) != TYPE_DICTIONARY \
			or (next["force_skills"] as Dictionary).is_empty():
		next["force_skills"] = ForceSkillsModel.initial_force_skills()
	var unlock: Dictionary = next.get("force_unlock", initial_unlock())
	unlock["phase"] = PHASE_COMPLETE
	next["force_unlock"] = unlock
	return next
