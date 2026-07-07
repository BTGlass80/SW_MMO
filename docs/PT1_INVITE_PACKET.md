# PT1 Invite Packet

Date: 2026-07-06
Audience: owner, operator, and trusted PT1 players

Use this packet when scheduling the first human PT1 rehearsal. It is deliberately
small: the runbook remains the operator source of truth, while this gives players
the exact expectations they need before joining.

## Host Fill-In

- Session id:
- Date and time:
- Expected duration: 45 minutes
- Server address:
- Port:
- Voice/text coordination channel:
- Feedback return location:
- Reset policy: test saves may be wiped after the session unless the owner says
  otherwise.
- Known issues link: `docs/KNOWN_ISSUES.md`
- Route link: `docs/PT1_SESSION_PLAN.md`
- Feedback form: `docs/PT1_FEEDBACK_TEMPLATE.md`

## Host Send-To-Players Message

We are running a private PT1 rehearsal for the SW MMO prototype. This is not a
content tour or a public beta; it is a 45-minute spine test for login, movement,
vendors, mission/job flow, combat/recovery, item state, reconnect, telemetry, and
operator recovery.

Please join with a fresh or explicitly approved test character. Do not use test
launch flags, scripts, or shortcuts. If you get stuck, lose items, duplicate credits,
cannot recover from wounds/death, or see confusing PvP/consent behavior, stop and
tell the operator immediately instead of trying to play around it.

After the session, fill out `docs/PT1_FEEDBACK_TEMPLATE.md`. The most useful feedback
is specific: what you were doing, what changed on your sheet/inventory/credits, what
you expected, and whether reconnect changed anything.

Known rough edges:

- Private LAN/trusted VPN only; transport is not encrypted.
- Admin commands exist only for recovery and will be logged.
- Some presentation roughness is expected, but stuck states, stray collision, save
  corruption, duplicated economy state, and unclear death/recovery are blockers.

## Operator Preflight

- Run the full gate and save output as `gate.txt`.
- Open the session bundle:
  `.\tools\pt1_bundle.ps1 -Action Start -SessionId <SESSION_ID>`
- Launch with `docs/BETA_RUNBOOK.md` section 4.
- Log in as an allowlisted operator and verify `/admin list`.
- Confirm every player has the feedback template before starting the route.

## Operator Closing

- Run `/admin export_telemetry`.
- Stop the server cleanly.
- Close the bundle:
  `.\tools\pt1_bundle.ps1 -Action Close -SessionId <SESSION_ID>`
- Audit the bundle:
  `.\tools\pt1_bundle.ps1 -Action Audit -SessionId <SESSION_ID> -RequireFeedback`
- Attach feedback templates to the session folder.
- Fill `triage.md` from `docs/PT1_TRIAGE_TEMPLATE.md`.
- Update `docs/KNOWN_ISSUES.md` before another live window.

## Minimum Pass For Scheduling The Next Rehearsal

- No server crash or repeated disconnect wave.
- No missing/duplicated character, credit, inventory, or item-instance state.
- No unrecoverable stuck state.
- No downed/death softlock.
- No unknown credit-bearing telemetry in `telemetry_tally.txt`.
- Feedback produces a ranked P0/P1/P2/content/parked list.
