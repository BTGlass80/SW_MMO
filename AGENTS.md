# SW MMO Prototype

A standalone Godot 4.6 prototype for a Clone Wars-era (20 BBY Mos Eisley) Star Wars
MMO, grounded in West End Games Star Wars D6 Revised & Expanded. It is a
successor/spinoff to the read-only SW_MUSH text game (codename "Parsec"). The repo
currently holds a deep single-player ground + 2.5D space slice plus a verified
server-authoritative networking core; the active direction is to grow it into an
actual server-authoritative, persistent, player-driven MMO.

## Standing constraints (always)
- `C:\SW_MUSH` is STRICTLY READ-ONLY reference. NEVER create, modify, or delete
  anything under it; never open `sw_mush.db` read-write. Data flows one way: out.
- **Clone Wars era only.** Old-era Imperial/Rebel/stormtrooper/Alliance/Empire
  framing is a bug unless deliberately recast to Clone Wars.
- **WEG R&E leads mechanics.** SW_MUSH is content/reference, not a 1:1 port. The
  authoritative MUSH design canon is `C:\SW_MUSH\docs\design\Guide_01..26_*.md`.
- **Document divergence first.** Any WEG/MUSH/prototype mechanic divergence gets a
  row in `docs/DIVERGENCE_LEDGER.md` BEFORE it is implemented.
- IP posture is private/fan: use Star Wars + WEG D6 content freely, no abstraction tax.
- Owner direction (2026-06-24): (1) multiplayer foundation first, (2) WEG
  action-window combat, (3) player-driven & persistent world, (4) private/fan IP.

## Program posture (owner rulings 2026-07-03, from the Fable review)
- **Launch posture: the MMO ships thin and iterates live; the MUSH ships complete.**
  The MMO is a live-service genre — launch a tight loop and grow it. The persistence
  layer is already migration-friendly (`schema_version`, JSON records, crash-safe writes).
- **Not-before-live list** (do NOT build these before the ground loop has real players):
  multiplayer space (the ~4k-line solo space model stays a SOLO mode until then — porting
  it to the server is a project the size of everything built so far), sieges, player
  cities, any runtime LLM. **Reading (owner ruling 2026-07-03, attended): pure models +
  design docs ARE permitted** (cheap, testable, they live in `scripts/rules/*` + `docs/`);
  what is PARKED is the **HOT wiring** — RPCs, Director hooks, snapshot fields, any
  `siege_*`/`city_*`/server-side `space_*` file or preload in `scripts/net/*`. Enforced
  mechanically: `check_project.ps1` fails the gate on parked wiring.
- **Faucets and sinks land together** (MUSH economy invariant, imported by owner ruling
  2026-07-03): a slice adding a credit/CP faucet (loot, quest rewards, harvest, richer
  vendor stock) must land WITH — or explicitly pair off against — a matching recurring
  sink (ammo, repair, insurance, fees), and vice versa. Verify empirically:
  `python tools/telemetry_tally.py <events.jsonl>` tallies per-character inflow/outflow
  from the live telemetry (run it on every PT1 session log; unknown credit-bearing event
  types are reported loudly, not skipped).
- **Two-games relationship = BOTH (option C), provisional — "see how they turn out."**
  SW_MUSH is the RP/canon layer; SW_MMO is the gameplay layer; shared era + data. Content
  flows ONE WAY only, out of read-only `C:\SW_MUSH`. Formalize a **scheduled weekly
  `mush-content-porter` re-extraction** (quests/NPCs/creatures/skill deltas) with a
  source-hash manifest diff, so MUSH content drift is an automated sync report, not a
  review-time surprise. (Owner mirrors the reciprocal line in the MUSH's own AGENTS.md;
  this repo cannot touch it.)
- **LLM policy = author-time, never runtime.** Keep the deterministic Director. AI flavor
  (NPC barks, event headlines, quest text) ships as reviewed JSON batches generated offline
  — never an API in the tick loop.
- **PvP death = true tiering** (DIV-0019 fork A, decided 2026-07-03): sev 5 = death; sev 3–4
  = downed-in-the-field (medic-relevant), NOT an instant kill. Requires the escape-hatch
  bundle (Director-ticked `recovery_model.death_roll` + a yield/respawn command) or a downed
  lawless player with no medic softlocks. Build it as ONE seam with the `escalate()` wiring,
  escalate first. See `docs/WAVE_G_BACKLOG.md` G1/G2.

## Engine, language, validation
- Godot 4.6.3 stable, GDScript only (C# deferred).
- Headless console binary: `C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe`.
- Run one smoke test:
  `& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://scripts/tests/<name>.gd`
- Full gate (python tests + import + launch + all GDScript smokes): `.\tools\check_project.ps1`
  (it fails on any `SCRIPT ERROR`/`Parse Error`, enforces the not-before-live invariant, and
  PRINTS the wired smoke + RPC counts — trust that output, never a count literal in a doc).
- Push `origin master` after every gate-green commit (owner ruling 2026-07-03).

## Architecture: pure / presentation split
- **Pure, scene-independent logic** (RefCounted / SceneTree-testable, no nodes,
  input, sockets, or rendering): `scripts/rules/*` and `scripts/net/world_state.gd`.
  This is where gameplay truth lives so it is headlessly unit-testable.
- **Presentation / controllers**: `scripts/world/*` and
  `scripts/net/{network_manager,net_world}.gd`.
- **Autoloads** (`project.godot`): `D6Rules` = `scripts/rules/d6_rules.gd` (WEG dice
  core); `Net` = `scripts/net/network_manager.gd` (networking, idle in solo).

## Test-harness convention
Headless `SceneTree` scripts in `scripts/tests/*.gd`: do work in `_init()`, collect
failures, print `"<name>: OK"` + `quit(0)` on pass, or `printerr(...)` + `quit(1)` on
fail (see `scripts/tests/rules_smoke.gd`, `net_smoke.gd`). Seed all RNG; never
`randomize()`. Every test is wired into `tools/check_project.ps1`.

## Netcode model
Server-authoritative, explicit RPC (no scene replication). Clients send input/fire
INTENTS; the **server** owns `WorldState` truth, owns ALL RNG/seeds/dice, ticks the
sim (20 Hz), and broadcasts snapshots. Combat resolves in ~5s WEG action windows via
`scripts/rules/action_window_model.gd` + `D6Rules`, broadcast as
`scripts/rules/combat_event_envelope_model.gd` envelopes. Solo `scenes/main.tscn` is
unchanged; the net world is `scenes/net_world.tscn`.

## Current status & where to start
**Starting a fresh/unattended session? Read `docs/SESSION_HANDOFF.md` FIRST** — it is the
clean-session entry point (current state, the re-armable all-day loop contract, the
parallelization playbook, guardrails, and the owner-gated park list).

Done & verified: M1.1 net core → M1.2 shared Mos Eisley + replicated avatars → M1.3/M1.3b
server-authoritative WEG action-window combat → M1.4 JSON persistence → M1.5 nameplates →
M2.0–M2.2 zone/security Director + world events; **Wave C** (chargen + dual-track CP),
**Wave D** (combat uses the real sheet + equipped gear), and **Wave E (E1–E27)** — the full
persistent player-driven loop — COMPLETE, followed by a long **F1–F75** hardening/depth series,
**Wave F** (the owner-unlocked systems: lethal death/respawn, WEG-anchored economy,
SWG-"Village" Force unlock), and **Wave G** (the external Fable review seam fixes: true death
tiering + downed, cumulative wound escalation, PvP defender dodge, hostile initiation, threat
tiers, telemetry). The full `tools/check_project.ps1` is the green bar (green at every commit;
it prints the smoke + RPC counts — trust the gate output, not doc literals).

Where to start: read `docs/SESSION_HANDOFF.md` (clean-session entry point) then
`docs/WAVE_G_BACKLOG.md` **§ Delta follow-ups** (the ACTIVE queue: G14–G18 + the PT1 prep
track). Canonical roadmap: `docs/MULTIPLAYER_FOUNDATION.md`; full feature inventory + session
notes: `docs/NIGHTLY_HANDOFF.md`; divergences: `docs/DIVERGENCE_LEDGER.md`. Owner-gated forks +
latest rulings live in `docs/SESSION_HANDOFF.md` §5 and the WAVE_G_BACKLOG owner-forks list.
Design docs awaiting their (parked or queued) wiring: `docs/SIEGE_DESIGN.md` (wiring PARKED —
not-before-live), `docs/PVP_CONSENT_DESIGN.md` (duel/bounty wiring queued, NOT parked).

## Subagents available (.Codex/agents/)
- **d6-rules-engineer** (opus) — implement/verify WEG D6 mechanics in `scripts/rules/*`
  and `d6_rules.gd`; owns the divergence ledger. Use for any dice/CP/FP/scale/soak/
  wound/Force rule work.
- **godot-netcode-engineer** (opus) — server-authoritative ENet/RPC/snapshots/
  action-window combat/persistence on `Net` + `WorldState`. Use for multiplayer work.
- **world-sim-designer** (opus) — DESIGNS (docs + data schemas, no code) the persistent
  world simulator, Director AI, factions, territory, player cities, scenes/plots. Use
  for system design grounded in the MUSH guides.
- **mush-content-porter** (sonnet) — extract curated Clone Wars data from read-only
  `C:\SW_MUSH` (guides/YAML/`sw_mush.db`) into standalone JSON under `data/`. Use to
  import content one-way.
- **gdscript-test-author** (sonnet) — write headless `SceneTree` smoke tests for pure
  models, wire them into `check_project.ps1`, confirm green. Use to add test coverage.
- **lowpoly-scene-builder** (sonnet) — procedural blocky GDScript scene/mesh builders
  in the `main.gd` art language; build the shared `scripts/world/world_builder.gd`. Use
  for world geometry.
