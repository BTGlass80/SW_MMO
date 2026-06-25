# Multiplayer Foundation (Milestone M1)

Status as of 2026-06-24: **M1.1 and M1.2 complete and verified; M1.3 combat core
complete and verified (RPC/HUD wiring next).** This is the start of turning the
single-player slice into a server-authoritative shared world — the owner-chosen
first priority (see "Direction" below).

## Direction (owner decisions, 2026-06-24)

1. **Multiplayer foundation first** — make it actually networked.
2. **WEG action-window combat** — real-time movement, attacks resolved
   server-side in short (~5s) D6 action windows. Server owns RNG/seeds.
3. **Player-driven & persistent world** — faction influence + territory players
   permanently reshape; guild sieges as a pillar.
4. **Private/fan IP** — Star Wars + WEG D6 used freely, no abstraction tax.

## Architecture

Server-authoritative, explicit-RPC (no scene replication yet). Chosen because it
keeps the authority/anti-cheat story simple and maps directly onto action-window
combat: client sends an intent → server resolves with its own seed → broadcasts.

```
Client (presentation, camera, input)            Server (authoritative)
  net_world.gd                                     net_world.gd  (--server)
    reads snapshot -> renders avatars                Net.start_server()
    local input -> Net.set_local_input(...)          WorldState  <- the truth
  Net (network_manager.gd autoload)  <--ENet-->    Net (network_manager.gd autoload)
    submit_input.rpc_id(1, move, yaw, jump)  ----->   set_input() on WorldState
    apply_snapshot(...)  <---------- broadcast -----  state.tick(); snapshot()
```

### Files

- `scripts/net/world_state.gd` — **pure, socket-free authoritative sim**: player
  registry, input intents, deterministic movement, world bounds, snapshot. This
  is where gameplay truth lives so it is unit-testable with no networking. The
  later combat/faction/territory truth belongs here (or sibling pure models).
- `scripts/net/network_manager.gd` — the `Net` autoload. ENet transport, peer
  join/leave, RPCs (`submit_input` client→server, `apply_snapshot` server→clients),
  fixed-tick server simulation (20 Hz) and client input send (20 Hz). In the solo
  `main.tscn` it stays in `Mode.NONE` and does nothing.
- `scripts/net/net_world.gd` + `scenes/net_world.tscn` — the networked entry. The
  server runs headless with no visuals; the client builds a camera/HUD, renders
  one capsule avatar per player from the snapshot, hides its own (first person),
  and forwards input. Geometry here is a minimal shared ground for now (see M1.2).
- `scripts/tests/net_smoke.gd` — headless smoke test of `world_state.gd` (join,
  deterministic movement, input clamping, bounds, snapshot shape, leave). Wired
  into `tools/check_project.ps1`.

## How to run

Server (dedicated, headless):

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . res://scenes/net_world.tscn -- --server
```

Client (connect to a host; default 127.0.0.1):

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1
```

Notes:
- Everything after `--` is a user arg (`OS.get_cmdline_user_args()`).
- Default port 24555 (`NetworkManager.DEFAULT_PORT`).
- The solo experience is unchanged: `res://scenes/main.tscn` is still the project
  main scene.

## Verified (2026-06-24)

- `net_smoke: OK`, `world_builder_smoke: OK`, `content_smoke: OK`,
  `combat_arena_smoke: OK`, and the **full `check_project.ps1` suite green** (32
  GDScript smokes + 7 python tests). The `main.gd` rewrite to use the shared builder
  regressed nothing.
- End-to-end ENet handshake proven with two headless processes: client connects,
  server registers the peer (`players=1`), client receives authoritative
  snapshots over RPC, clean disconnect (`players=0`).
- Solo `main.tscn` still boots clean with the `Net` autoload present.

## Roadmap

- **M1.1 Net core** — DONE.
- **M1.2 Shared Mos Eisley + replicated avatars** — DONE (logic). `main.gd`'s
  geometry is extracted into `scripts/world/world_builder.gd`; both the solo
  (`main.tscn`) and networked (`net_world.tscn`) worlds build the same settlement
  from it (no duplication, covered by `world_builder_smoke`). The net client
  renders one capsule+nameplate avatar per player from snapshots, hides its own
  (first person), and interpolates remote avatars. Verified headlessly (full gate
  green + two-process handshake with the real settlement). REMAINING: a human
  visual check of two GUI clients walking Bay 94 together (cannot be done headless).
- **M1.3 Server-authoritative WEG action-window combat** — CORE DONE.
  `scripts/net/combat_arena.gd` (pure, server-owned) holds a shared training target
  + per-player combat state, queues fire intents, and resolves them in WEG
  initiative order each window via `action_window_model.gd` (initiative +
  declarations) + `ground_combat_model.gd` (attack/damage/return-fire) + `D6Rules`,
  under a **server-owned seed**, emitting one `combat.exchange.resolved` envelope
  per shooter. Deterministic/replayable; covered by `combat_arena_smoke`.
  REMAINING (M1.3b wiring): hold a `CombatArena` on the server in `NetworkManager`
  (load `prototype_combatants.json`, register players on join); a `submit_fire_intent`
  RPC; a ~5s window timer calling `resolve_window(server_seed)`; broadcast envelopes
  via an `apply_combat_envelope` RPC; client fire-on-click + a HUD combat log. The
  client raycast becomes aim intent the server re-validates (seed + all dice already
  server-side in the arena).
- **M1.4 Persistence backbone** — accounts/characters; save/load position + sheet
  (JSON first, then SQLite per the architecture doc).

## Constraints

- Keep `C:\SW_MUSH` read-only. Clone Wars era only. WEG R&E leads mechanics.
