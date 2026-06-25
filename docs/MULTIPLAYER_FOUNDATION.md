# Multiplayer Foundation (Milestone M1)

Status as of 2026-06-25: **M1.1 → M1.5 complete and verified, plus M2.0–M2.2
(zone/security Director + world events), Waves C (chargen + dual-track CP),
D (combat uses the real sheet + equipped gear), and E (E1–E27 persistent-world depth
+ hardening + F1/F2/F3) — all COMPLETE.** The single-player slice is now a
server-authoritative shared world: clients send intents, the server owns
`WorldState` truth + all RNG/seeds, ticks the sim (20 Hz) and a slow Director (~30s),
resolves WEG action-window combat, routes per-player snapshots across multiple zones,
and persists per-character JSON. **The unblocked, non-owner-gated backlog is now dry**
(see the Wave E entry below + `docs/SESSION_HANDOFF.md` §0/§5); next depth is owner-gated.
See "Direction" below for the owner-chosen priorities and `docs/SESSION_HANDOFF.md` for
the clean-session entry point.

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

## Verified (2026-06-25)

- The **full `check_project.ps1` suite is green** (import + 2s runtime launch + 34
  GDScript smokes + 7 python tests), including `net_smoke`, `world_builder_smoke`,
  `content_smoke`, `combat_arena_smoke`, `zone_state_smoke`, `territory_smoke`,
  `chargen_smoke`, `progression_smoke`, and `persistence_smoke`. The A0 colormap fix
  made `--import` green; the old "import can fail on half-curated assets" caveat is
  stale — the full gate is the bar.
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
- **M1.3 Server-authoritative WEG action-window combat** — DONE.
  `scripts/net/combat_arena.gd` (pure, server-owned) holds a shared training target
  + per-player combat state, queues fire intents, and resolves them in WEG
  initiative order each window via `action_window_model.gd` (initiative +
  declarations) + `ground_combat_model.gd` (attack/damage/return-fire) + `D6Rules`,
  under a **server-owned seed**, emitting one `combat.exchange.resolved` envelope
  per shooter. Deterministic/replayable; covered by `combat_arena_smoke`.
- **M1.3b Combat netcode wiring** — DONE. `NetworkManager` holds the server
  `CombatArena` (loads `prototype_combatants.json`, registers players on join), a
  `submit_fire_intent` RPC, a ~5s window timer → `resolve_window(server_seed)`, and an
  `apply_combat_envelope` broadcast; the `net_world` client fires on LMB / aims on RMB
  and renders a HUD combat log. Verified end-to-end via a two-process autofire run.
- **M1.4 Persistence backbone (JSON)** — DONE. Pure `scripts/net/persistence_store.gd`
  saves/loads one JSON record per character (shape per
  `data/schemas/player_persistence.schema.json`) under `user://persistence`;
  `register_account` restores on login, saves on disconnect + 30s autosave. Covered by
  `persistence_smoke`; reconnect-restores-position verified over the wire.
- **M1.5 Player identity / nameplate** — DONE. Clients pass `--name`; it flows into
  snapshot nameplates, combat envelopes, and the persisted record.
- **M2.0 Zone & security-state scaffold** — DONE. Pure `scripts/net/zone_state.gd`:
  per-zone faction influence (republic/cis/hutt/independent) with a DERIVED alert level
  + effective security tier, advanced by a slow deterministic ~30s Director tick (no
  LLM). Folded into the snapshot. Covered by `zone_state_smoke`.
- **M2.1 Territory-claim scaffold** — DONE. Pure `scripts/net/territory_model.gd`: an
  org claims a contested/lawless node (influence-floor precondition), accruing passive
  income on a 60s resource tick. Covered by `territory_smoke`. (The Drop-6D siege loop
  is deliberately NOT built — owner-gated tuning.)
- **M2.2 Director world events** — DONE. `zone_state.gd` fires one deterministic event
  at a time per zone from a fixed 12-event menu keyed off dominant influence, surfaced
  in `zone_summary` and rendered as a client NEWS line. Still no LLM (owner-gated).
- **Wave C — Character creation & dual-track progression** — DONE. Pure
  `scripts/rules/chargen_model.gd` (WEG R&E build validation → starting sheet) +
  `scripts/rules/progression_model.gd` (DIV-0007 dual-track CP wallet); server chargen
  on first login; CP earned on combat target-disable and spent via a `submit_skill_raise`
  RPC. Covered by `chargen_smoke` / `progression_smoke`.
- **Wave D — Combat uses the character sheet** — DONE. `combat_arena.gd` builds each
  player's attack/dodge/soak/damage/armor pools from their persisted sheet + equipped
  weapon/armor (catalogs loaded by `NetworkManager`), with a trainee fallback when no
  sheet is set.
- **Wave E — Persistent-world depth & faithfulness** — DONE (E1–E27 + hardening +
  F1/F2/F3; `docs/UNATTENDED_BACKLOG.md` Log). Pure-model slices: WEG wound ladder
  (`wound_ladder_model`) + recovery (`recovery_model`), derived stats
  (`derived_stats_model`), per-weapon range bands, an off-by-default Force hook
  (`force_skills_model`, owner-gated — DIV-0011), `security_gate`, `pending_influence_model`,
  `org_model`, `creature_spawn_model`, `vendor_model`, `reputation_model`, `chat_model`,
  `account_auth_model`, `ambient_sim_model`. [HOT] netcode: multi-zone per-player snapshot
  routing, equipment-swap, org claim/release commands with treasury income, the player→
  influence causal loop (F1 territory accrual from combat), zone-scoped chat/emote (F2) +
  global OOC, account-auth + per-peer rate-limit + record cache, and a Director-paced
  ambient NPC sim. RPC surface grew 8→16. Two MEDIUM `register_account` bugs found by
  adversarial review and fixed (and locked into the gate by the F4 regression guard).
  Gate at **56 GDScript smokes**, green at every commit.
  Note: `creature_spawn_model`/`vendor_model`/`reputation_model` are modeled + smoke-tested
  but **not yet wired into `net_world`** (live spawns/shops/rep-on-action need owner
  economy/spawn-rate/value calls).
- **Status:** the planned multiplayer foundation is feature-complete and hardened; the
  unblocked, non-owner-gated backlog is **dry**. Further depth (siege durations/capture
  thresholds, Force/Jedi access policy, PvP-consent, death penalties, CP rates, the
  economy wiring above) is **owner-gated** — see `docs/SESSION_HANDOFF.md` §5.

## Constraints

- Keep `C:\SW_MUSH` read-only. Clone Wars era only. WEG R&E leads mechanics.
