# Wave G Backlog — from the Fable external review (2026-07-02)

**Source:** an external code+design review by Fable, run against the review snapshot
`SW_MMO_Prototype_review_20260702_221957.zip` (post-Wave-F: S0–S19 + DIV-0019 PvP wired).
The reviewer **executed the gate independently** on Linux Godot 4.6.3 (72/72 GD smokes + 7/7
python, green), read every `scripts/rules/*` and `scripts/net/*` at symbol level, and ran a
**Monte Carlo probe through the live arena** (~57k action windows). Full text lives in
[`docs/fable/`](fable/):
- `SW_MMO_review_fable_2026-07-02.md` — the review (P0/P1/P2 + Wave-G queue G1–G9).
- `SW_MMO_livefire_balance_probe_2026-07-02.md` — live-fire + balance numbers (queue G10–G12).
- `SW_MMO_path_forward_2026-07-02.md` — strategy addendum (PT1, posture, process).
- `balance_probe.gd` — the probe tool, now relocated to [`tools/balance_probe.gd`](../tools/balance_probe.gd).

This file distills that into the project's house backlog format so the items are tracked and
executable. **House rules still apply** (`docs/SESSION_HANDOFF.md` §§3–4): `[PAR]` pure-model+test
slices can batch in worktrees; `[HOT]` slices (`network_manager.gd`/`net_world.gd`/`combat_arena.gd`)
go **one at a time on main** with a two-process check; document any mechanic divergence in
`docs/DIVERGENCE_LEDGER.md` **before** coding; the server owns all RNG/seeds.

> The review's headline: **Wave F shipped lethality and PvP, but three seams that were "acceptable
> follow-ups" while combat was non-lethal graduated to _prerequisites_ the moment real damage went
> live.** Those are G1–G3 (the P0s). Do them before building more breadth on top of Wave F.

---

## P0 — reconcile BEFORE building further on Wave F

### G1 — PvP death tiering — **DECIDED: true tiering (fork A), owner 2026-07-03**  `[HOT]` (depends on G2)
**What:** `pvp_rules_model.PVP_DEATH_SEVERITY = 5` + `is_kill(sev>=5)` and the two
`pvp_rules_model_smoke` asserts ("sev 3/4 is 'out', not dead") describe tiered death — but the live
wire kills at `DISABLED_SEVERITY (3)`: `combat_arena.resolve_window` records a casualty at
`new_def >= 3` and `network_manager._resolve_combat_window` routes **every** casualty to
`_handle_player_death`. `is_kill` is never called on the live path — **dead code whose smoke asserts
the opposite of shipped behavior.** A sev-3 PvP hit kills+respawns today.
**Why:** a green test encoding unwired semantics is the worst phantom — it has a CI badge. Pick one
truth and make model, smoke, wire, and DIV-0019 all say it.
**How (DECIDED = fork A, true tiering):** wire `is_kill`/`PVP_DEATH_SEVERITY` onto the live path so
**sev 5 = death; sev 3–4 = downed-in-the-field** (medic-relevant, not an instant kill); fix the two
`pvp_rules_model_smoke` asserts + the DIV-0019 "casualties" sentence to match. **Mandatory escape-hatch
bundle** (without it a downed lawless player with no friendly medic is *softlocked* — DIV-0012 excludes
incap/mortal from self-recovery and F32 blocks movement): (a) wire the built-but-unwired
`recovery_model.death_roll` on the Director tick for `mortally_wounded`; (b) add a **yield/respawn**
command for a downed (sev 3) player. **Build as one seam with G2, `escalate()` FIRST** — under
`escalate()` most PvE/PvP outs arrive as *incapacitated-by-accumulation* (probe §D: 258/300 vs 197/300),
which is exactly the "downed, medic-relevant" state this tiering keys on, so G2's distributions inform
G1's tuning. This also applies to PvE death (DIV-0006) — reconcile both so a downed PvE player isn't
softlocked either.
**Files:** `scripts/rules/pvp_rules_model.gd`, `scripts/tests/pvp_rules_model_smoke.gd`,
`docs/DIVERGENCE_LEDGER.md` (DIV-0019).
**Verify:** smoke asserts what ships; gate green.

### G2 — Wire `wound_ladder_model.escalate()` into live accumulation  `[HOT]` (+ `[PAR]` re-seed)
**What:** `escalate()` (cumulative WEG ladder: Wounded+Wounded → Incapacitated, etc.) is complete,
correct, and tested — but **never called live**. Every live accumulation site uses `maxi(old, new)`:
`ground_combat_model.resolve_exchange`, `_resolve_return_fire`, and the DIV-0019 PvP defender
write-back. Consequence now that lethality shipped: **attrition cannot kill** — Wounded+Wounded stays
Wounded forever; death needs a single margin-16+ hit.
**Why (sharpened by the probe, §D):** against real monsters the single-hit regime dominates, so
`escalate()` barely moves *monster* lethality — **but near-peer PvP is where it matters**: under
`maxi()`, two similar players in lawless can trade Wounded results forever and neither can die without
a freak roll. **P0-2 is primarily a PvP-correctness prerequisite.** It also reshapes the meaning of
DIV-0016's sparring cap (cap=2 "because wounded_twice isn't wired" is load-bearing on this gap).
**How:** wire `escalate()` into the three sites. **Trap:** severity ints and ladder indices diverge at
3 (`level_for_severity(3)`=incapacitated; `LEVELS[3]`=wounded_twice). Cross the boundary via **level
strings** (`escalate(level, incoming_severity)` → `level_index`), never raw ints; persist `wound_state`
as the level string (already does) and derive the arena's severity int at the seam. Re-seed the
affected combat smokes; update DIV-0008 status from "follow-up" to "wired".
**Alternative (if not wiring):** re-ledger explicitly — "maxi accumulation is the accepted MMO model;
one-shot-only death is intended" — and re-tune hostile damage knowing it. (Design G2 and G1 as **one
seam, escalate first**: under `escalate()` most outs arrive as incapacitated-by-accumulation, which is
exactly what the G1 fork-A tiering would key on.)
**Files:** `scripts/rules/ground_combat_model.gd`, `scripts/net/combat_arena.gd`,
`scripts/rules/wound_ladder_model.gd` (seam), affected smokes, `docs/DIVERGENCE_LEDGER.md` (DIV-0008).
**Verify:** a new smoke: two sub-lethal hits escalate a level; gate green; re-run `balance_probe`.

### G3 — PvP defenders cannot dodge (the WEG reaction layer is absent in PvP only)  `[HOT]`
**What:** `PvpRules.defender_target_pools` maps attack/damage/soak/armor/scale but **no dodge pool**,
and `resolve_exchange`'s attack calls `resolve_ranged_attack(..., {})` with empty defense. A passive
victim's cover is read from their *intent* (absent → 0), not persistent state. Net: against another
player's attack your `dodge`/`full_dodge` and cover do **nothing** — defense is armor + Strength soak
only. Full-dodge as a defender is pure downside.
**Why:** in a system whose entire defensive identity is the reaction dodge, this is the biggest
fidelity hole in the PvP slice — and it's not in DIV-0019's follow-up list.
**How (mostly plumbing, no new mechanics):** in the `is_pvp` branch, build the defender's defense from
their declared stance + `player_dodge_pool` (wound/armor-penalized like `_resolve_return_fire` already
does) and pass it into `resolve_ranged_attack`; `prepare_ranged_defense` already caches one dodge roll
reused across a window — built for exactly this. Read defender cover from persistent state
(`_players[def]["state"].player_cover_level`), falling back to intent.
**Files:** `scripts/rules/pvp_rules_model.gd`, `scripts/net/combat_arena.gd`,
`scripts/rules/ground_combat_model.gd`.
**Verify:** smoke — declared-dodge defender raises attacker's effective difficulty; full-dodge defender
skips their own attack AND applies vs incoming; two-process PvP check.

---

## P1 — will bite the next wave

### G4 — Hostiles never initiate  `[HOT]`
**What:** hostiles only fire as **return fire inside a player-initiated exchange**. A player who never
presses fire stands beside a Dune Sea spawn unharmed — lawless zones are dangerous only to volunteers,
which undercuts the death loop, the insurance sink, and the zone fantasy at once.
**How:** `ground_combat_model.resolve_incoming_fire_window` **already exists** (multi-attacker,
prepared-dodge, fully smoked) with no live caller for hostiles. Add a Director-tick (or per-window when
a hostile is engaged and no intent arrived) unprovoked-attack path through it; keep lawless+contested
gating.
**Verify:** two-process — an idle bot in `tatooine.dune_sea` takes fire and can die.

### G5 — Economy arbitrage floor guard  `[PAR]`
**What:** `MAX_TOTAL_DISCOUNT = 0.65` ⇒ buy floor = 0.35×list, while `SELL_RATE = 0.40` ⇒ sell =
0.40×list. **Floor < sell = a buy→sell money printer** when stacked discounts reach the floor.
Unreachable today (bargain caps at 50%, needs ~17D) but one dial-turn away.
**How:** enforce `MAX_TOTAL_DISCOUNT <= 1.0 - SELL_RATE - ε` (or compute sell from *paid* price) + a
smoke asserting `buy_floor(list) > sell_price(list)` for **every** catalog item.
**Files:** `scripts/rules/economy_model.gd`, new `scripts/tests/economy_floor_smoke.gd`.

### G6 — Doc-rot / hygiene batch  `[PAR]`
Cheap, high-value corrections the gate structurally can't catch. **Note:** deferred out of the live
edit path to avoid colliding with the running overnight loop; do these in a clean tick.
- **P2-1 stale comment → live phantom:** `ground_combat_model._wound_penalty_dice` comment says
  "sev 3→2, 4→2 (the fix)" but the delegate `penalty_dice_for_severity` returns **0** for 3/4
  (out-tiers moot). Fix the comment — it will mislead exactly the G2 session.
- **P2-2 count drift:** CLAUDE.md "~66 smokes", SESSION_HANDOFF "59", actual wired = **72**; RPC surface
  SESSION_HANDOFF "21", actual `@rpc` = **33**. Make `check_project.ps1` **print** the smoke + RPC
  counts and have docs say "see the gate output," never a literal (kills the drift class permanently).
- **P2-3 README "Current Slice" unreadable:** the space paragraph is one ~600-word comma-chained
  sentence — the first thing a fresh session/human reads. Rewrite as short bullets; push detail into
  `docs/SPACE_SLICE.md`.
- **P1-5 ledger the `force_sensitive` storage divergence:** SW_MUSH treats it as *derived* state
  (never stored); the MMO stores it as a sheet field flipped by `force_awakening_model.apply_completion`.
  Add one sentence to DIV-0011 so a MUSH-habituated session doesn't "helpfully fix" it.
- **P2-6 unledgered `d6_rules` house rules (3 lines):** (a) Wild-Die 1 always applies the harshest R&E
  option (wild=0 AND drop highest); (b) FP doubling applied **before** MAP/aim (penalties/bonuses not
  doubled); (c) `roll_pool` floors totals at 1. Add a ledger row or `d6_rules` header note for each.
- **P2-5 pip-drop convention:** `apply_multi_action_penalty`/`apply_wound_penalty` zero pips at 0D while
  `subtract_pools` preserves them. Harmless today; pick one convention, note it in the `d6_rules` header.

### G7 — Name policy: rename fixture + reserved-name filter  `[PAR]`
**What:** `wire_roundtrip_smoke.gd` names a test player **"Ahsoka"** (pollutes the canonical-name
grep); there's no reserved-name filter, so players could self-name as canonical figures.
**How:** rename the fixture (keeps the era grep clean), then add a chargen-time reserved/canonical-name
filter (port the MUSH name-policy list).
**Files:** `scripts/tests/wire_roundtrip_smoke.gd`, `scripts/rules/chargen_model.gd`, new smoke.
*(Note P1-2 — one-hostile-per-zone + forced engagement — is **accepted v1**; just ledger it and fold
multi-spawn + target selection into the positional-truth work, G9.)*

---

## Balance-probe-driven (live-fire findings, §§A–F of the probe doc)

### G10 — De-fang the dummy faucet + fix fallback/window-counter  `[HOT]`
**What (observed on a live server):** between a hostile's death and its next respawn, a lawless bot's
fire intents **fell through to the shared spaceport training dummy** (cross-zone), and dummy disables
take the **same reward branch as real kills** — `COMBAT_CP_REWARD` + zone influence + territory
influence + a Force-awakening `disables` signal. One shared, zero-risk, every-window-killable dummy =
an **infinite CP/influence faucet** competing with risk-priced content. Also `reset_target()` zeroes
`_window_index`, so the global window counter (stamped into every envelope) resets on any dummy
disable — corrupts future replay/ordering tooling.
**How:** hostile-death fallback → **no target / hold fire** (not the global dummy); dummy disables pay
**reduced/zero** influence + drop the Force feed (keep capped CP for onboarding if desired); move
`_window_index = 0` out of `reset_target()`.
**Files:** `scripts/net/combat_arena.gd`, `scripts/net/network_manager.gd`.

### G11 — Resolved-pool content smoke + fix prose stat strings  `[PAR]`
**What:** several creatures' prose stat strings silently degrade through
`HostileNpc.attack_pools_from_creature`: **`glim_worm` resolves to 0D damage** (a "lethal hostile" that
can't deal damage); `mip_swarm`/`spor_crawler` are the same rot class; and a to-hit **fallback masks
missing skill wiring** (listed atk never reaches the resolver → silent 3D; `merdeth`/`acklay` resolve
*above* their listed value — data and resolver disagree silently).
**How:** extend `content_smoke` to assert, for every `hostile:true` creature, that resolved
`target_damage_pool` and `target_attack_pool` are **≥ 1D** and (where a listed stat exists) **match**
it — turns the whole rot class into a gate failure. Fix `glim_worm`/`mip_swarm`/`spor_crawler` to
machine dice codes; reconcile listed-vs-resolved attack stats. The probe's §B block is a ready template.
**Files:** `data/creatures_clone_wars.json`, `scripts/tests/content_smoke.gd`.

### G12 — `threat_tier` + alert-banded spawn table + loot-by-tier  `[PAR]` (probe = acceptance)
**What (the threat cliff, §C/§E):** the ambient spawn table spans **free ATM → 20-second death →
instant execution → invulnerable wall**, chosen by zone-alert bias, so a fresh player entering the Dune
Sea rolls dice on *which economy they entered* — the single biggest PT1 feel risk. And **risk/reward
are anti-correlated**: loot keys on *scale* only, so the trivial crab (~195 cr/min, near-zero risk)
strictly dominates the deadly acklay (~37 cr/min). Tactics barely help up-tier (reaction dodge
*replaces* the already-low range-10 difficulty; cover is marginal vs 6–8D pools) — survivability comes
from **tier selection, not micro**.
**How:** add a `threat_tier` field per creature; **band the spawn table by zone alert** (calm lawless =
tiers 1–2 only; escalation unlocks upper tiers); treat `merdeth`-class as **event/boss** content, never
ambient. Make **loot tier per creature** (band × threat_tier) so reward tracks risk. Re-run
`tools/balance_probe.gd` as the acceptance step.
**Files:** `data/creatures_clone_wars.json`, `scripts/rules/creature_spawn_model.gd`,
`scripts/rules/economy_model.gd` (loot bands), smokes.
*(Player-guide note to add with this: survivability = tier selection, not tactics — there is no
tactical escape hatch from an up-tier spawn.)*

---

## Owner forks — DO NOT auto-build (surface for a decision)

1. ✅ **DECIDED 2026-07-03 — PvP death tiering = fork A (true tiering).** sev 5 = death; sev 3–4 =
   downed-in-field, with the mandatory escape-hatch bundle (Director `death_roll` + yield/respawn). Built
   as one seam with G2 (escalate first). See G1/G2 above; recorded in `CLAUDE.md` program posture.
2. ✅ **DECIDED 2026-07-03 — two-games relationship = both (option C), provisional ("see how they turn
   out").** SW_MUSH = RP/canon layer; SW_MMO = gameplay layer; shared era+data; content flows one way out
   of read-only SW_MUSH. Formalize the weekly `mush-content-porter` re-extraction cadence. Recorded in
   `CLAUDE.md`. (Owner mirrors the reciprocal line in the MUSH's CLAUDE.md; this repo can't touch it.)
3. ✅ **DECIDED 2026-07-03 — launch posture adopted.** *"The MMO ships thin and iterates live; the MUSH
   ships complete."* + the not-before-live list (multiplayer space stays solo until the ground loop has
   real players; sieges; player cities; runtime LLM). Written into `CLAUDE.md`. LLM policy also set:
   author-time, never runtime.
4. **First Strangers Night (PT1)** — the highest-information next milestone: 5–10 outside players for one
   evening running a scripted ~30-min loop (chargen → range → travel → Dune Sea fight → die/respawn →
   insure → buy/sell → lawless duel → org claim). Let PT1 *pull* priorities. Its ship list is small: the
   three P0s, G4 hostile-initiation, the presentation wave already in flight, the auth bundle (below),
   and telemetry.
5. **Auth/crypto bundle (G8, gate on "before any non-LAN playtest"):** `check_secret` stores/compares
   secrets in **plaintext** JSON over **unencrypted ENet**; unsecured accounts are first-claimer-wins.
   Godot ships `Crypto`/`HashingContext` — salted hash at rest is a small slice; DTLS (or an explicit
   "dev transport" banner) for flight. Not now; it gates strangers.
6. **Positional-truth spike (G9) — the next fidelity cliff.** Distance is a profile constant
   (`HOSTILE_DISTANCE`, `PVP_DISTANCE=12`) and cover is intent-supplied, while `WorldState` already owns
   authoritative positions. Deriving combat distance from server positions and cover from world/zone
   data **retires three follow-ups at once** (positional PvP range, defender cover, hostile engagement
   radius) — the single biggest step from "action windows bolted to a lobby" toward the
   `REALTIME_D6_TRANSLATION.md` thesis. Design doc first (`world-sim-designer`), then slices.
7. **LLM policy — author-time, never runtime (resolves the parked fork with a *shape*):** keep the
   deterministic Director; if AI flavor is wanted (NPC barks, event headlines, quest text), generate
   **batches offline** that ship as reviewed JSON — the MUSH questline authoring pattern. "Yes at the
   authoring desk; no in the tick loop."

---

## Process / infrastructure recommendations (mostly `[PAR]`, low cost, high leverage)

- **Telemetry before tuning** — one structured JSONL server log (death: killer/zone/severity-path;
  buy/sell: item/price/discounts; loot; travel; window-resolve per-shooter severities; awaken-phase
  transitions), one writer func routed from existing print sites. You can't tune insurance/loot/TTK you
  can't see, and PT1's entire value is this data. **Do before PT1.**
- **Seam audit as a rule, not a favor** — after any wave touching `network_manager`/`net_world`/
  `combat_arena`, one mandatory read-only tick by a fresh agent hunting doc↔model↔wire disagreements
  only (this review was that pass; P0-1 is why convention alone wasn't enough).
- **Dead-symbol detector in the gate** — for each public func/const in `scripts/rules`+`scripts/net`,
  grep call sites outside its own smoke; report orphans. `is_kill`/`PVP_DEATH_SEVERITY` would have
  flagged the day they shipped.
- **Invariant-auditor agent** (mirror the MUSH kit): era grep + `FORBIDDEN_SHIPS`, no `randomize()`/
  client RNG in models, no trust of `_intents`/client fields in HOT files, divergence-row-before-
  mechanic-change, smoke-asserts-match-wired-behavior.
- **`mush-content-porter` re-extraction cadence** — the 06-24 quest/data port is ~10 heavy MUSH
  content-days stale (MUSH is now at ~35 questlines and moved combat-objective completion to
  defeat-at-INCAPACITATED, which matches the MMO's `DISABLED_SEVERITY=3`). Make it a scheduled weekly
  sync with a source-hash manifest diff, not a one-time port. Reuse the MUSH's proven quest shape
  (giver → skill checks → combat → return, funnel-routed rewards) when wiring DIV-0020 — don't invent a
  parallel objective grammar.
- **Nearly-free wins:** (a) **envelope replay tool** — envelopes already carry exchange seeds; a dev
  command that re-runs `resolve_exchange` from a pasted envelope gives combat debugging + player-dispute
  resolution for free. (b) **server watchdog** — auto-restart + the existing crash-safe persistence =
  a survivable PT1 evening. (c) **20-bot headless soak test** — the client affordances (`--autofire`,
  `--travel`, `--fire-nearest`, `--quickstart`) already exist; a script launching 20 bots for 30 min
  watching tick time + snapshot size finds the first scaling wall before humans do.

---

## Key balance numbers worth keeping (from the live probe — see the probe doc for full tables)

- **Threat cliff (green profile, quickstart human), P(taken out)/window · median time-to-out · farm rate:**
  `hitcher_crab` 1.35% · ~3.2 min · **~195 cr/min** · `tusken_warrior` 13.3% · **~20 s** · ~194 cr/min ·
  `acklay` 63.7% · 1 window · ~37 cr/min · `merdeth` 95.9% (82.5% killed outright) · 1 window · ~1 cr/min.
- **`escalate()` vs `maxi()`** (hitcher_crab/green): median windows-to-out 38 → **22 (−42%)**; but
  against high-tier monsters the single-hit regime dominates and it barely moves — **the win is in
  near-peer PvP** (see G2).
- **Economy:** loot keys on scale only, so risk and reward are **anti-correlated** at the top (crab
  dominates); heavy blaster (750) ≈ 4 min of safe crab farming; insurance ≈ break-even on the starter
  kit, mandatory at tusken-tier death rates. Combat perf is a non-issue (~57k arena windows well under
  the probe timeout).

---

## Suggested execution order

1. **G2 → G1, plus G3** (the P0 seam): `escalate()` (G2) FIRST, then G1 true-tiering + the escape-hatch
   bundle (they're one seam); G3 (PvP defender dodge) in parallel.
2. **G10, G11** (de-fang the faucet + stop silent data rot — both cheap, both distort every other number).
3. **G4** (hostile initiation — makes lawless actually dangerous), **G5** (floor guard), **G6/G7** (doc + name hygiene).
4. **G12** (threat tiers + loot-by-tier), with `tools/balance_probe.gd` as acceptance.
5. **Telemetry + soak test**, then schedule **PT1**. Owner forks (2, 3, and G1-A) whenever the owner steers.

*Do not wire `tools/balance_probe.gd` into the gate — it's statistical and slow; run it on demand as the
acceptance instrument for the spawn-table / loot-tier / `escalate()` drops.*
