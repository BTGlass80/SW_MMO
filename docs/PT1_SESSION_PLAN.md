# PT1 Session Plan - Thin Live MMO Beta Rehearsal

Date: 2026-07-06
Target length: 30 to 45 minutes
Players: 3 to 10 trusted humans for first rehearsal; expand only after clean results

PT1 is not a content tour. It is a spine test: login, persistence, movement, vendor,
mission/economy, combat, recovery, trade/list/use, telemetry, and operator recovery.

## Host Pre-Session Checklist

- Full gate green from the exact tree being tested, with output saved as
  `sessions\<SESSION_ID>\gate.txt`.
- Fresh `sessions\<SESSION_ID>\` bundle opened with
  `.\tools\pt1_bundle.ps1 -Action Start -SessionId <SESSION_ID>`.
- `persistence_before.zip` captured in that bundle.
- Server launched from `docs/BETA_RUNBOOK.md`.
- Port, reset policy, known issues, and feedback location sent to players using
  `docs/PT1_INVITE_PACKET.md`.
- At least one allowlisted operator logged in and able to run `/admin list`.
- `docs/KNOWN_ISSUES.md` reviewed aloud: no public internet exposure, rough admin
  allowlist, possible corpse-loot roughness, and test-only affordances.

## Player Pre-Session Checklist

- Use a fresh or explicitly approved test character.
- Do not use test-only launch flags or scripts.
- Report any stuck state immediately instead of relogging repeatedly.
- Save one feedback template per player using `docs/PT1_FEEDBACK_TEMPLATE.md`.

## Route

### 0-5 Minutes: Login And Spawn

Expected path:

- Connect to the PT1 server.
- Create or load a character.
- Confirm nameplate, movement, camera, health/wound display, and starting inventory.
- Operator runs `/admin list` and verifies all players are visible.

Pass signal:

- Every player can move in Mos Eisley without admin intervention.
- Reconnect works for at least one volunteer before the group moves on.

### 5-12 Minutes: Vendor And First Economy Touch

Expected path:

- Open a vendor or starter interaction.
- Buy or sell one low-risk item.
- Confirm credits changed and the item state is understandable.
- One player uses `/admin inspect <char_id>` with the operator watching, not as a fix.

Pass signal:

- Credits and inventory persist after one voluntary reconnect.
- No unknown credit-bearing telemetry appears after the session tally.

### 12-22 Minutes: Mission Or Job Loop

Expected path:

- Take a starter job anchored near Mos Eisley.
- Travel to the job area without leaving the thin beta scope.
- Complete one objective that pays credits, item rewards, influence, or progress.
- Return or complete the loop as designed.

Pass signal:

- At least half the group completes the loop without live developer narration.
- Players can describe what they earned and what it cost them.

### 22-32 Minutes: Combat And Recovery

Expected path:

- Fight a controlled PvE target or agreed safe PvP/damage test.
- Verify combat messaging, wounds, downed/death outcome if it happens, and recovery.
- Use medical item or recovery command only if the intended gameplay path fails.

Pass signal:

- A losing player can recover or respawn without softlock.
- Combat envelopes and death/downed telemetry explain the outcome.

### 32-40 Minutes: Trade, Listing, Or Item Use

Expected path:

- Trade, list, buy, consume, repair, or otherwise mutate an item instance.
- Reconnect one participant after the item mutation.
- Operator uses `/admin inspect <char_id>` to verify inventory state if needed.

Pass signal:

- Item identity survives the flow and reconnect.
- A fee, repair, travel, listing, or other sink appears where expected.

### 40-45 Minutes: Shutdown Proof

Expected path:

- Operator announces shutdown.
- Operator runs `/admin export_telemetry`.
- Stop server cleanly.
- Close the bundle with
  `.\tools\pt1_bundle.ps1 -Action Close -SessionId <SESSION_ID>`.
- Audit the bundle with
  `.\tools\pt1_bundle.ps1 -Action Audit -SessionId <SESSION_ID> -RequireFeedback`.
- Restart briefly and verify one character reconnects with expected credits,
  inventory, wounds, and zone.

Pass signal:

- The restored or restarted world has no character loss, item loss, duplicated money,
  or unrecoverable stuck state.

## Operator Intervention Rules

Allowed recovery commands:

- `/admin unstuck <char_id>` for broken navigation or bad spawn.
- `/admin teleport <char_id> tatooine.mos_eisley.spaceport` for route recovery.
- `/admin clear_space <char_id>` only for accidental space-state leakage.
- `/admin force_save <char_id>` before a controlled restart/reconnect proof.
- `/admin kick <char_id>` only for wedged network sessions.

Every command use must be recorded with timestamp, character id, reason, and whether
it fixed the issue.

## Stop-The-Test Conditions

Stop immediately if any condition in `docs/BETA_RUNBOOK.md` section 8 occurs. Do not
try to play through save corruption, duplicated economy state, repeated stuck states,
or unclear PvP/consent harm.

## Post-Session Checklist

- Copy watchdog logs, server log, telemetry JSONL, backups, and feedback templates
  into the session folder. The close command copies logs/telemetry and runs the
  telemetry tally by default.
- Update `docs/KNOWN_ISSUES.md` before another live window.
- Fill `sessions\<SESSION_ID>\triage.md` from `docs/PT1_TRIAGE_TEMPLATE.md`:
  - P0: blocks next PT1
  - P1: must fix before beta candidate
  - P2: polish or tuning
  - Content: more depth inside existing Mos Eisley scope
  - Parked: multiplayer space, sieges, player cities, runtime LLM, broad planet rollout
