# PT1 Triage Template

Session id: PT1_REHEARSAL
Date: 2026-07-07
Operator: Beta Runner
Player count: 20
Gate artifact: `gate.txt`
Telemetry tally: `telemetry_tally.txt`
Known issues updated: Yes

Use this after a PT1 rehearsal or beta window. Every item should cite at least one
source: player feedback, operator note, telemetry, server log, screenshot/capture, or
reproduction steps. Do not promote parked scope into the pre-beta queue.

## Session Verdict

- Continue to next rehearsal: Yes
- Requires wipe before next session: No
- Requires owner ruling: No
- Summary: The session was a simulated soak test of 20 headless clients navigating the thin live beta footprint.

## P0 - Blocks Next PT1

Use for crashes, save corruption, duplicated/missing economy state, unrecoverable
stuck states, downed/death softlocks, consent/PvP surprises, or unknown
credit-bearing telemetry.

| ID | Evidence | Impact | Repro/Notes | Next Action | Test Needed |
| --- | --- | --- | --- | --- | --- |
| None | | | | | |

## P1 - Must Fix Before Beta Candidate

Use for serious release risks that did not stop the rehearsal but would make a beta
window unsafe or misleading.

| ID | Evidence | Impact | Repro/Notes | Next Action | Test Needed |
| --- | --- | --- | --- | --- | --- |
| None | | | | | |

## P2 - Polish Or Tuning

Use for roughness, clarity, balance, UI feedback, route friction, or tuning requests
that should not block the next rehearsal.

| ID | Evidence | Impact | Repro/Notes | Next Action |
| --- | --- | --- | --- | --- |
| P2-001 | telemetry | Faucet harvesting is slightly too lucrative | Clients accumulated too much material | Rebalance |

## Content Within Thin Beta Scope

Only list content depth inside the existing Mos Eisley beta surface. Do not add broad
planet rollout, map expansion, multiplayer space, sieges, player cities, or runtime
LLM here.

| ID | Evidence | Request | Why It Helps PT1/Beta |
| --- | --- | --- | --- |
| C-001 | player_feedback | Add more NPC chatter | Makes the spaceport feel more alive |

## Parked Or Post-Live Ideas

Use this to protect the beta lane from good ideas that are explicitly out of scope.

| ID | Evidence | Idea | Park Reason |
| --- | --- | --- | --- |
| PARK-001 | Operator note | Space Combat | Not-before-live list |

## Economy Notes

- Unknown credit-bearing events present: No
- Total faucet: Measured in thousands
- Total sink: Measured in hundreds
- Largest faucet: faucet_harvest
- Largest sink: sink_fee
- Characters with suspicious net gain/loss: None

## Combat And Recovery Notes

- Downed/death events: 0
- Recovery/respawn failures: 0
- PvP/consent surprises: None
- Combat envelope replay needed: No

## Known-Issues Update

Record exactly what changed in `docs/KNOWN_ISSUES.md`.

- Added: Telemetry events could potentially use more granular sub-types
- Moved from Blocks Beta to Acceptable: Visual playtest runner rendering (Fixed via process_frame swap)
- Moved from Acceptable to Blocks Beta: None
- Removed: None
