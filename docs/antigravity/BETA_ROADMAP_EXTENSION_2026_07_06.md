# Beta Roadmap Extension - Thin Live MMO Track

Date: 2026-07-06
Author: Codex
Audience: Antigravity and future release-candidate implementers

## Verdict

The project is close enough to extend the roadmap, but not by broadening into the old
"5x to 10x larger" beta shape. The right beta target is a thin, server-authoritative,
playable MMO slice that can survive small-group live play, produce useful telemetry,
and iterate without corrupting persistence or widening into parked systems.

This document supersedes any beta interpretation that requires player cities,
sieges, multiplayer space, broad planet rollout, or runtime LLM features before live.
Those remain post-live or explicitly parked until the owner unlocks them.

## Current Acceptance Basis

Treat the latest work as conditionally accepted for roadmap expansion once the full
gate is green from the current tree.

Known cleanup folded into this pass:

- `space_map_overlay.gd` now routes asteroid extraction through the live
  `Net.send_space_harvest("asteroid_field")` API instead of the removed
  `send_space_mine` client helper.
- `ROADMAP_EXTENSION_REQUEST_2026_07_06.md` metadata was corrected so it no longer
  calls an older commit "current HEAD."
- The map remains Codex-owned unless the owner explicitly reassigns it. Antigravity
  should not broaden map geometry while driving beta readiness.

## What "Beta" Means Here

Beta is not a feature-complete SWG replacement. Beta means:

- 10 to 20 trusted players can log in, create characters, play the ground loop,
  fight, die, recover, trade, earn, spend, and persist through restarts.
- The operator can diagnose crashes, economy imbalance, stuck players, bad
  migrations, and combat oddities from logs and telemetry without guesswork.
- The content surface is small but coherent: Mos Eisley plus a tight set of nearby
  jobs, POIs, vendors, trainers, creatures, and risk zones.
- Every new faucet lands with a paired sink or an explicit telemetry-backed offset.
- Space remains a solo connected mode until ground beta proves real players return.

## Phase B0 - Acceptance Cleanup

Goal: make the current tree unambiguously reviewable.

Required:

- Run the full project gate from a fresh capture set if the capture age check fails.
- Confirm there are no live script references to removed space-mining APIs.
- Keep roadmap/request docs aligned with actual HEAD and actual implementation files.
- Leave old review docs intact, but make the active beta direction easy to find.

Exit criteria:

- `tools/check_project.ps1` is green.
- `rg "send_space_mine|submit_space_mine" scripts` has no results.
- The active roadmap points here for beta scope.

## Phase B1 - Beta Candidate Stabilization

Goal: make the first hour of play dependable.

Build or verify:

- Login/start flow, character creation, spawn, death/respawn, reconnect, and logout.
- Crash-safe persistence across repeated server restarts and schema-version bumps.
- Clear operator commands for teleport, unstuck, grant/remove credits, inspect sheet,
  inspect inventory, and force-save.
- A small regression suite around player lifecycle, inventory, credits, death/downed,
  and combat envelope persistence.
- A manual playtest checklist for a new account from spawn to first completed loop.

Exit criteria:

- A fresh player can complete the first-hour loop without admin intervention.
- A restarted server preserves character sheet, inventory, credits, location, wounds,
  and recent world state.
- Admin recovery tools can fix a stuck player without editing save files by hand.

## Phase B2 - Economy And Item Spine

Goal: make earning, spending, carrying, selling, and consuming items feel real.

Build or verify:

- Item instance identity is preserved through loot, reward, inventory, vendor, bazaar,
  crafting input, and decay/repair paths.
- Bazaar/vendor flows sell actual player-owned instances, not just template names.
- Solo space cargo converts into grounded item/resource families at landing.
- Repair, ammo, medical care, travel, insurance, fees, and market listing costs create
  recurring sinks that match new or richer faucets.
- `tools/telemetry_tally.py` is run against every PT1 session log and unknown
  credit-bearing events are treated as blockers.

Exit criteria:

- A player can earn an item, list it, sell it, spend the proceeds, and have every step
  survive restart.
- A new faucet cannot merge unless its matching sink or offset is documented and
  tested.
- Economy telemetry produces per-character inflow/outflow reports suitable for tuning.

## Phase B3 - PT1 Soak And Telemetry

Goal: prove the loop under small live pressure before calling it beta.

Build or verify:

- A 20-client or 20-bot soak path that covers movement, combat, loot, vendor use,
  death/downed, reconnect, and persistence.
- Server tick, RPC, snapshot, combat envelope, persistence write, and economy telemetry
  counters.
- A runbook for starting, observing, stopping, archiving logs, and replaying the
  session.
- A compact feedback template for players that asks about blockers, confusion, fun,
  economy feel, combat feel, and performance.

Exit criteria:

- A 60-minute soak completes without corrupting persistence or wedging the server.
- Telemetry can explain where credits/items entered and left the world.
- At least one human PT1 session produces actionable feedback without requiring live
  developer narration.

## Phase B4 - Thin Content Depth

Goal: deepen Mos Eisley instead of expanding the map footprint.

Build or verify:

- 10 to 20 repeatable or branching missions anchored to existing POIs.
- Creature, scavenger, militia, Separatist-adjacent, underworld, medical, trading,
  and courier loops that reuse the same economy and combat spine.
- Trainers and profession starter tasks that explain progression through doing.
- POI-specific rewards and risks that make different parts of the playspace matter.
- Clone Wars framing throughout: no old-era Imperial/Rebel/stormtrooper defaults.

Exit criteria:

- A player can spend multiple sessions in Mos Eisley without exhausting all practical
  jobs in the first hour.
- Content variety comes from roles, risk, reward, and social/economic choices, not
  raw map sprawl.

## Phase B5 - Combat, PvP, And Recovery Closure

Goal: make WEG-grounded combat fair enough for trusted beta play.

Build or verify:

- Defender dodge and hostile initiation rules from the Wave G follow-ups.
- True tiered death: severity 3 to 4 downed-in-field, severity 5 death, with no
  indefinite softlock.
- Wound escalation, downed recovery, yield/respawn, medical intervention, and insurance
  all wired through the same authoritative server path.
- PvP consent and lawless-zone messaging are explicit in UI and telemetry.
- Combat outcomes are reproducible enough from envelopes and logs to debug disputes.

Exit criteria:

- A player can lose, recover, and understand why.
- PvP cannot silently bypass consent/risk rules.
- Medical and insurance systems create meaningful sinks without griefing softlocks.

## Phase B6 - Solo Space As Connected Support

Goal: keep space useful without opening the parked multiplayer-space project.

Allowed before beta:

- Solo route costs, travel timing, cargo manifests, mining/harvest, salvage, docking,
  landing customs, and ground inventory handoff.
- Pure design/model work that documents future server-authoritative space.
- Tests that prove solo space cargo lands as deterministic ground resources/items.

Not allowed before beta:

- Server-side multiplayer space simulation.
- New `scripts/net/*` space authority wiring beyond already-approved cargo handoff.
- Space snapshots, space combat RPC expansion, or multiplayer ship replication.

Exit criteria:

- Space supports the ground economy as a solo side loop.
- No beta task expands into parked multiplayer-space architecture.

## Phase B7 - Beta Launch Readiness

Goal: make a small release operable, reversible, and learnable.

Build or verify:

- Versioned beta runbook: install, configure, launch, stop, backup, restore, migrate.
- Save reset and save migration policy, including what players keep across resets.
- Known-issues document split into "acceptable for beta" and "blocks beta."
- Operator dashboard or log bundle with server health, economy, combat, and persistence
  summaries.
- A weekly beta triage rhythm: telemetry review, bug scrub, economy adjustment,
  content patch, and regression gate.

Exit criteria:

- A non-author developer can run the beta from docs and recover from common failures.
- The owner can decide whether to reset, migrate, or patch based on evidence.
- The next roadmap expansion is driven by player data, not speculative breadth.

## Explicitly Parked Until After Beta

Do not let these enter the beta critical path:

- Multiplayer space simulation or combat.
- Sieges.
- Player cities.
- Runtime LLM calls.
- Broad planet rollout.
- Large authored map expansion beyond fixing the existing Mos Eisley playspace.

## Direction To Antigravity

Stay out of the map lane unless explicitly asked. The map has consumed too many cycles
and too much review bandwidth. Your release-worthy work should now concentrate on:

- Green gate discipline and stale-doc cleanup.
- Economy/item identity.
- Lifecycle/persistence hardening.
- PT1 soak and telemetry.
- Combat/PvP/recovery closure.
- Thin Mos Eisley content depth using existing POIs.

When in doubt, choose the smallest server-authoritative loop that creates evidence
from real players. Do not make beta bigger; make beta survivable.
