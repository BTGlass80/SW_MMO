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

## Engine, language, validation
- Godot 4.6.3 stable, GDScript only (C# deferred).
- Headless console binary: `C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe`.
- Run one smoke test:
  `& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://scripts/tests/<name>.gd`
- Full gate (python tests + import + launch + all GDScript smokes): `.\tools\check_project.ps1`
  (it fails on any `SCRIPT ERROR`/`Parse Error`).

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
M2.0–M2.2 zone/security Director + world events; **Wave C** (chargen + dual-track CP) and
**Wave D** (combat uses the real sheet + equipped gear) COMPLETE. The full
`tools/check_project.ps1` is the green bar (it passes today).

Next work = `docs/UNATTENDED_BACKLOG.md` → **Wave E** (E1–E27). Canonical architecture/
roadmap: `docs/MULTIPLAYER_FOUNDATION.md`. Full feature inventory + session notes:
`docs/NIGHTLY_HANDOFF.md` (do not duplicate it here).

## Subagents available (.claude/agents/)
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
