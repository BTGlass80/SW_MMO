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

## 2026-07-06 Roadmap Extension - From Machine Soak To Human PT1

The project has now crossed an important threshold: the full gate includes a serial
PT1 20-client soak smoke, lifecycle live smoke, item identity smoke, space cargo live
RPC smoke, world capture/collision/grounding smokes, and the standard pure model suite.
That is enough to continue unattended development, but it is not enough to declare
human beta complete.

The next roadmap is an execution queue, not a scope expansion. Continue proving the
thin live MMO under increasingly realistic operation.

## Phase B8 - Gate And Harness Hardening

Goal: make the validation system trustworthy under unattended development.

Build or verify:

- Keep heavyweight live smokes, including `pt1_soak_live_smoke.gd`, isolated from the
  normal concurrent smoke pool.
- Add a no-leftover-process check around every multi-process smoke that starts servers
  or clients.
- Make all live smokes account-isolated, port-isolated, and deterministic enough that
  random item quality or spawn timing cannot decide pass/fail.
- Remove scratch scripts, throwaway `test_*.gd` files, and generated logs before every
  handoff.
- Keep visual captures fresh when running the full gate; stale captures are a real
  gate failure, not a warning to ignore.

Exit criteria:

- Three consecutive full gates pass from a clean process table.
- No smoke leaves Godot server/client children running after failure or success.
- The gate output remains the sole trusted source for smoke and RPC counts.

## Phase B9 - Operator Readiness Drill

Goal: prove that the beta can be operated by someone other than the implementer.

Current closure note:

- The beta runbook now uses explicit session bundles, manual persistence backups,
  a deliberate PT1 port convention, telemetry tally steps, and stop-the-test
  thresholds.
- `tools/pt1_bundle.ps1` opens/closes PT1 evidence bundles, captures
  before/after persistence backups, copies watchdog logs and telemetry, and runs the
  telemetry tally; `tools/check_project.ps1` parses PowerShell tools so syntax drift
  fails the gate. `tests/test_pt1_session_bundle.py` exercises the Start/Close bundle
  path against disposable save/log/telemetry data, including `gate.txt` capture and
  a per-session `triage.md` copy from `docs/PT1_TRIAGE_TEMPLATE.md`; it also covers
  the tool-assisted `Restore` action against a temp save directory and bundle
  `Audit` pass/fail behavior, including red-gate and unknown-credit-telemetry
  rejection.
- The admin command surface now covers `list`, `inspect` with inventory details,
  `teleport`, `unstuck`, `grant`, `force_save`, `clear_space`, `kick`,
  `clear_listing`, and `export_telemetry`; `admin_commands_smoke.gd` covers the
  recovery-critical paths.
- Remaining B9 proof is operational: run the documented launch/backup/restore flow
  with a real server session and preserve the bundle.

Build or verify:

- Run the server through the documented beta runbook: launch, observe, stop, backup,
  restore, restart, and inspect logs.
- Add or verify operator commands for teleport, unstuck, inspect sheet, grant/remove
  credits, force-save, clear space state, and kick/disconnect.
- Confirm telemetry files are named, rotated or archived, and readable by
  `tools/telemetry_tally.py`.
- Produce a single session bundle format: gate output, telemetry JSONL, server log,
  known issues, and PT1 feedback notes.

Exit criteria:

- A fresh operator can run a 30-minute private session from docs without editing save
  files by hand.
- Backups can be restored and the restored world passes a reconnect/persistence smoke.
- Telemetry tally runs on the session log without unknown credit-bearing events.

## Phase B10 - Human PT1 Preparation

Goal: make the first strangers night schedulable.

Current closure note:

- `docs/PT1_SESSION_PLAN.md` now defines a 30 to 45 minute route through login,
  vendor/economy, mission/job, combat/recovery, item mutation, telemetry export, and
  shutdown proof.
- `docs/PT1_FEEDBACK_TEMPLATE.md` now maps player feedback to that route.
- `docs/PT1_INVITE_PACKET.md` gives the owner/operator a fill-in scheduling packet
  and player-facing message for the first trusted rehearsal.
- `docs/PT1_TRIAGE_TEMPLATE.md` gives B11 a concrete P0/P1/P2/content/parked queue
  format to fill immediately after the rehearsal.
- Remaining B10 proof is a host rehearsal from the runbook, followed by an actual
  human PT1 or explicitly labeled rehearsal.

Build or verify:

- A 30 to 45 minute scripted PT1 route: create character, learn controls, use vendor,
  complete a mission, travel, fight, recover, trade or list an item, and submit feedback.
- A pre-session checklist for host and players: build/version, port, accounts, reset
  policy, known issues, emergency commands, and where feedback goes.
- A post-session checklist: archive logs, run telemetry tally, preserve saves, record
  blockers, and sort feedback into bugs/tuning/content/docs.
- A clear "stop the test" threshold for crashes, save corruption, stuck players,
  economy exploit, or consent/PvP violation.

Exit criteria:

- The owner can schedule PT1 without needing a live developer to explain every step.
- The session route exercises the beta spine rather than wandering into parked scope.
- Known issues explicitly separate acceptable roughness from PT1 blockers.

## Phase B11 - Post-PT1 Triage And Tuning

Goal: let human evidence decide the next work.

Build or verify:

- Convert PT1 results into a ranked queue: P0 blockers, P1 release risks, P2 polish,
  and parked/post-live ideas.
- Tune economy only from telemetry: credit faucets, sinks, vendor prices, repair costs,
  insurance, travel fees, loot, mission rewards, and bazaar fees.
- Tune combat/recovery only from combat envelopes, death/downed logs, and player
  feedback.
- Add focused smokes for every PT1 blocker before fixing it when practical.

Exit criteria:

- No beta claim is based only on subjective impressions; every change cites telemetry,
  feedback, a reproduced bug, or a deliberate owner ruling.
- The follow-up queue is smaller and sharper after each triage pass.

## Phase B12 - Live Beta Candidate

Goal: decide whether the project is ready for a small live beta window.

Build or verify:

- 3 consecutive full gates green after PT1 fixes.
- A 60-minute 20-client soak green after PT1 fixes.
- A successful human PT1 or PT1 rehearsal with no save corruption, no unrecoverable
  stuck states, and no economy exploit that requires a wipe.
- Known issues updated with owner-approved acceptable beta roughness.
- Runbook, feedback template, reset policy, and telemetry workflow all current.

Exit criteria:

- The owner can open a small, trusted beta window knowing how to start, stop, restore,
  observe, triage, and patch the game.
- The next roadmap expansion is a post-beta live-ops queue, not more pre-beta scope.

## Unattended Development Goal

If this roadmap is handed to Codex as an unattended goal, use this objective:

```text
Drive SW_MMO_Prototype from the current gate-green machine-soak state to a human PT1
ready beta candidate. Work only inside the thin-live beta track. Keep multiplayer
space, sieges, player cities, runtime LLM, broad planet rollout, and map broadening
parked. Execute B8 through B12 in order: harden the gate/harness, prove operator
readiness, prepare the human PT1 route and checklists, triage any PT1 evidence into
tests and fixes, and stop only when the full gate is green, telemetry is clean, known
issues are current, and the owner can schedule or run a small trusted beta session from
the docs. Preserve user changes, avoid scratch files, run the full gate after code or
harness changes, and report blockers precisely.
```

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
