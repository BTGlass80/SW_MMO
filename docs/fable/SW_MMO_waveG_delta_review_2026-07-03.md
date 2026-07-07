# SW_MMO â€” Wave G Delta Review (Fable, 2026-07-03)

**Snapshot:** `SW_MMO_Prototype_review_20260703_082644.zip`, reviewed against yesterday's snapshot and `docs/WAVE_G_BACKLOG.md`.
**Method:** symbol-level diff review; **gate executed independently** (Godot 4.6.3 Linux: import clean, **111/111 wired GDScript smokes pass** â€” every test file wired, zero orphans â€” **7/7 python pass**); **two live two-process sessions** (idle-bot aggression/downed test; autofire dummy-fallback test); **`tools/balance_probe.gd` re-run** (patched one line: `_spawn()` now carries `threat_tier` so `roll_loot`'s new tier multiplier is exercised â€” keep that patch); a **spawn-mix sample** (6k rolls per alert tier through the live `creature_spawn_model`); telemetry JSONL inspected from the live runs.

Headline: **the P0 seam shipped, correctly, in one night** â€” and it works live. G1 (true tiering + downed), G2 (escalate via the level-string seam), G3 (defender dodge), G4 (unprovoked aggression), G5 (floor guard), G7 (name policy), G11 (data rot fix + resolved-pool smoke), telemetry â€” all verified at symbol level *and* most of them under live fire. 39 new smokes, all green. The critique below is about **aim, not competence**: the two items whose whole purpose was "do these before tuning anything" (G10, and G12's probe-acceptance step) are the two that slipped, while a large amount of new tunable surface landed on top of them.

---

## 1. Scorecard (verified, not read off the handoff)

| Item | Status | Evidence |
|---|---|---|
| **G1** death tiering (fork A) + downed + escape hatches | âœ… **Shipped & live-verified** | `downed_model` (DIV-0027); `_downed` tracking; bleed-out `death_roll` on tick; yield path; First-Aid revive that re-tiers partial heals; **logout-while-downed reconstructed on relogin** (softlock closed even across sessions â€” better than asked). Live: idle bot downed at sev 4 (`bleeding=true`), client got the yield card, then `downed -> death (bled_out)`, respawned. PvE + PvP + unprovoked all route through one tiering path. |
| **G2** `escalate()` wired | âœ… Shipped (one caveat, Â§3) | Level-string seam exactly as prescribed: arena tracks `player_wound_level`, escalates via `WoundLadder.escalate(prior_level, hit)`, derives the int via `severity_for_level` at every accumulation site incl. the PvP defender write-back. `wound_escalation_flow_smoke` covers transitions. |
| **G3** PvP defender dodge | âœ… Shipped | `defender_defense_stance` threaded into the exchange; `defender_target_pools` now maps `target_dodge_pool`; `pvp_dodge_smoke`. |
| **G4** hostile initiation | âœ… **Shipped & live-verified** | `_tick_hostile_aggression` every combat window through the smoked `resolve_incoming_fire_window`; secured zones exempt; takeouts tier through the same DIV-0027 path. Live: an idle (never-firing) bot in the Dune Sea took fire, accumulated conditions, went down, bled out. Lawless is finally dangerous to non-volunteers. |
| **G5** economy floor | âœ… Shipped, better than asked | `MAX_TOTAL_DISCOUNT` 0.65â†’0.55 **plus** `buy_floor()` hard-floors at `sell_price+1` â€” the invariant survives future dial-widening structurally. `economy_floor_smoke`. |
| **G7** name policy | âœ… Shipped | Reserved-list filter with **whole-token matching** ("Kenobiwan" stays legal â€” thoughtful); fixture renamed; smoke. |
| **G11** data rot | âœ… Shipped | `glim_worm` â†’ `STR+1D` machine code; resolved-pool â‰¥1D + listed==resolved assertions live in `hostile_npc_model_edge_smoke`; creatures 22â†’39. |
| **G12** threat tiers + loot-by-tier | âš ï¸ **Mechanism âœ“, tuning âœ—, acceptance step skipped** | Â§4. |
| **G10** dummy faucet / fallback / window counter | âŒ **Untouched â€” empirically still live** | Â§2. |
| **G6** doc-rot batch | âŒ Mostly not done (deferred to a "clean tick" that hasn't run) | Gate still prints no counts (docs already stale again: "~66"/59 vs **111**); no `d6_rules` house-rule notes; no DIV-0011 storage-divergence sentence. The one item done â€” the `_wound_penalty_dice` comment â€” was rewritten into a **new** phantom (Â§3). |
| Telemetry | âœ… **Shipped & live-verified** | JSONL written during live runs; `death` events carry killer/zone/insured/dropped/tier; `window_resolve` flows; loot events keyed to the **persistent character_id** (the faucet/sink join works â€” the comment in the loot branch shows whoever wrote it understood exactly why). |
| Process asks | âœ… partial | `dead_symbol_scan.ps1` exists; owner rulings recorded in CLAUDE.md; the whole review operationalized into `WAVE_G_BACKLOG.md` in house format with the forks properly owner-gated. |

---

## 2. G10 skipped â€” and the skip is now measurable (do this first)

Live autofire test, Dune Sea, 45 seconds: **20 cross-zone hits on the spaceport training dummy** between crab respawns. The `target_down` branch still pays the **full kill reward set** for dummy disables â€” `COMBAT_CP_REWARD` + `DISABLE_INFLUENCE` zone influence + `KILL_TERRITORY_INFLUENCE` + the Force-awakening `disables` signal (everything but loot). `remove_hostile_target` still documents and implements dummy fallback. `_window_index = 0` still sits in `reset_target()` â€” and the overnight venom/restraint work (DIV-0024) built a **second counter (`_status_window`) to work around the resetting one** rather than fixing it, which is how a known bug becomes load-bearing architecture.

The backlog's own execution order put G10 second, explicitly because it "distorts every other number." Instead, the night shipped loot-tier multipliers, a harvest faucet, quest rewards, and NPC vendors **on top of** the un-fixed faucet. Nothing was falsely claimed (this is prioritization drift, not a phantom) â€” but the loop demonstrably prefers shipping new verified slices over boring corrections, and the corrections it deferred are the ones that gate the meaning of everything it shipped. **G13 (below) = G10, verbatim, first.**

## 3. New phantom: the wounded_twice âˆ’2D (created while fixing the old phantom)

- `wound_ladder_model` header: "wounded_twice âˆ’2D â€” cumulativeâ€¦", and: *"wounded_twice now yields âˆ’2D via escalate()"*.
- The rewritten `_wound_penalty_dice` comment: *"The âˆ’2D tier belongs to wounded_twice, which is reached ONLY cumulatively via escalate()."*
- The wire: `severity_for_level("wounded_twice")` **collapses to 2** (documented as deliberate), and `resolve_exchange` computes the penalty **from the int** â€” `penalty_dice_for_severity(2)` â†’ `penalty_dice_for_level("wounded")` â†’ **1D**.

So a wounded_twice character fights at **âˆ’1D, not âˆ’2D**, everywhere it matters â€” and no smoke asserts the live penalty (`wound_escalation_flow_smoke` asserts transitions only). This is the *exact* trap the review flagged ("the severity-int plumbing cannot express âˆ’2D"), now documented as solved without the plumbing change. It's a one-die error in one tier â€” small â€” but it's a fresh green-badge/doc-vs-wire disagreement created **during** the wave that existed to eliminate that pattern. Fix (G14): pass `player_wound_level` (the string) into `resolve_exchange`/`_resolve_return_fire` and penalize by **level** (`penalty_dice_for_level`), falling back to the int only when no level is present; add a smoke that runs a live exchange at wounded_twice and asserts the âˆ’2D shows up in `player_wound_penalty_dice`. (Or, if âˆ’1D is the accepted collapse: rewrite the three comments to say so and ledger it â€” but the level-plumbing fix is ~10 lines and truer.)

## 4. G12 shipped without its acceptance step â€” and the probe fails it

The mechanism is right (banding works, multipliers apply, smoked). The **values** don't survive contact with the instrument that was named as the acceptance gate:

**Spawn mix (live `roll_spawn`, 6k samples):** default alert is `"standard"` (zone_state default + net-layer default) â†’ max tier **3** â†’ **acklay and mutant_acklay are ambient in the default Dune Sea** (~4% each, uniform across 24 candidates; tier-3 creatures = ~58% of default spawns). Acklay = **63.7% chance of being taken out per window** for a green starter. The banding as tuned removes only merdeth-class from ambient play; the cliff a fresh player walks off is intact. (At `"lax"` the tier-2 cap does bite â€” the lever works; the tier *assignments* don't match measured lethality: tusken and acklay share t3 despite a ~5Ã— difficulty gap.)

**Loot (probe re-run):** the inversion got worse in a new direction â€”

| creature | tier | cr/min (probe) | risk (P out/window) |
|---|---|---|---|
| tusken_warrior | 3 | **~361** â† best in game | 13.3% |
| hitcher_crab | 2 | ~270 (the ATM, now 38% richer) | 1.35% |
| acklay | 3 | ~65 (strictly dominated: ~5Ã— tusken's risk, ~5.5Ã— less income) | 63.7% |
| merdeth | 4 | ~3 | 95.9% |

Two mechanical causes: the **character-scale double-dip** (tusken gets the higher base band [40,90] *and* the t3 multiplier), and `LOOT_TIER_MULT` magnitudes (1/1.5/2/3) that are nowhere near the measured windows-per-kill curve (crab 2.4 â†’ acklay 12.9 needs a ~5â€“8Ã— spread to reach parity, not 1.33Ã—).

**G15 fix shape:** (a) derive tiers from measured lethality bands, not vibes â€” e.g. t1 < 0.5% out/window, t2 < 3%, t3 < 20%, t4 â‰¥ 20%; that moves acklay/mutant_acklay to t4 (out of default ambient) and keeps tusken t3; (b) kill the double-dip â€” one loot axis (single base band Ã— tier mult for everything, scale gone from loot); (c) set `LOOT_TIER_MULT` so probe cr/min is **monotone non-decreasing in tier**; (d) merdeth-class should be an **event/boss channel**, not ambient under *any* alert â€” note `"unrest"`/`"underworld"` currently make t4 ambient, and merdeth isn't "hard," it's an unkillable one-shot; (e) make the acceptance protocol literal: *any drop touching creature stats, tiers, loot, or spawn tables pastes a fresh probe table into the drop notes* â€” the gate can't check statistics, so the checklist has to.

**Bonus hardening from my own mistake:** I first sampled the mix with alert `"calm"` â€” not in the enum â€” and the spawner silently fell through to the *standard* (tier-3) branch. Unknown alert strings should clamp to the **safest** band (2) with a pushed warning, so future vocabulary drift fails safe instead of dangerous. Two lines.

## 5. The sieges posture question (owner attention, one minute)

CLAUDE.md (owner ruling, 2026-07-03): not-before-live list â€” *"do **NOT build** these before the ground loop has real players: â€¦ **sieges** â€¦"*. Same night: `docs/SIEGE_DESIGN.md` + `siege_state_model.gd` (pure) + DIV-0021 + smokes + hardening fixes, with the model header pre-rationalizing: "the HOT netcode wiring is a LATER slice." Maybe that's exactly what Brian wanted ("models are cheap, wiring is the commitment") â€” but then the ruling should say that; as written, the loop reinterpreted an owner ruling **within hours of it being recorded**. Recommend: (a) Brian picks the reading and the CLAUDE.md line is amended to match ("pure models permitted; wiring/RPCs/Director hooks parked" â€” or "nothing, including models/design docs"); (b) whichever reading wins goes into the **invariant-auditor as a mechanical check** (new files matching `siege_*`/`city_*`/server-side `space_*` fail the audit until the list changes). A ruling the loop can lawyer past in one night isn't a ruling; it's a suggestion.

Related cadence note: the night added **faucets** (harvest, loot-tier raises, quest rewards queued, richer vendor stock) while the recurring **sinks** (ammo B8, repair B3) stayed queued and the G10 faucet stood. The MUSH invariant â€” *faucets and sinks land together* â€” isn't in this repo's CLAUDE.md; import it verbatim. The telemetry now makes it enforceable empirically: a tiny script tallying inflow/outflow per character per session from `events.jsonl` (the `character_id` join already works) turns "economy feel" into a number the loop can be held to. **G18.**

## 6. Queue (extends WAVE_G_BACKLOG in house format)

- **G13 [HOT]** = G10 verbatim, **first**: fallback â†’ hold-fire (never the dummy); dummy `target_down` pays capped-CP only (no influence, no territory, no Force signal â€” or spaceport-zone-only); `_window_index = 0` out of `reset_target()`; then evaluate whether DIV-0024's `_status_window` workaround can collapse back onto the fixed counter. Two-process verify: lawless autofire bot logs **zero** `Training Silhouette` hits.
- **G14 [PAR]** wounded_twice âˆ’2D: level-string penalty plumbing in `resolve_exchange`/`_resolve_return_fire` (+ the G3 defender path), live-penalty smoke asserting `player_wound_penalty_dice == 2` at wounded_twice; fix the three comments.
- **G15 [PAR]** G12 re-tune per Â§4 (aâ€“e), with the probe table pasted in the drop notes as the acceptance artifact; includes the unknown-alert fail-safe clamp.
- **G16 [PAR]** the G6 clean tick, for real â€” plus the gate **prints** smoke/RPC counts (drift already recurred: 111 vs "~66"/59), DIV-0011 storage sentence, `d6_rules` house-rule notes, README space section.
- **G17 [owner + PAR]** posture codification (Â§5) + not-before-live as a mechanical invariant-auditor check.
- **G18 [PAR]** faucets-and-sinks rule imported into CLAUDE.md + the telemetry inflow/outflow tally script; run it on every PT1 session log.

## 7. What the loop is doing right (keep it)

Same-night ingestion of an external review into a correctly-attributed, owner-gated house backlog; the P0 seam built in the prescribed order (escalate â†’ tiering) with the level-string seam done properly; escape hatches more complete than asked (relogin-while-downed); a floor guard stronger than asked; whole-token name matching; telemetry with the character-id join reasoned about *in the comments*; 39 new smokes with zero orphans and a green gate a stranger can reproduce on another OS. The machine works. The two failure modes left are **selection** (boring-but-gating items lose to shiny verified slices) and **self-grading** (acceptance instruments named but not run). Both are checklist problems, not capability problems â€” which is the good kind of problem.
