# Unattended Development Backlog

The self-paced unattended loop (see `docs/UNATTENDED_LOOP.md` → "Claude Code
Self-Paced Loop") works this list **top-down**, one self-contained slice per
iteration. Each slice must end at a green `tools/check_project.ps1` and a git commit,
or be reverted. Mark items `DONE` / `BLOCKED` as you go; append the commit hash.

## Guardrails (every iteration)
- **Single driver as of 2026-06-24 — Claude owns EVERYTHING, including the art/asset
  pipeline** (`tools/fetch_assets.py`, `tools/asset_sources.json`, `MMO_Assets/`,
  `assets/`, `docs/ASSET_CATALOG.md`). Adopt and maintain them. Prefer clean, scoped
  logical commits (`git add <paths>`). If the owner says Codex is actively running
  again, switch to strictly scoped commits and never revert files you didn't change.
- **Green bar:** GDScript smokes + runtime launch + python tests (run directly). The
  full `check_project.ps1 --import` currently fails on a half-curated Kenney asset —
  fix it in item A0, then the full gate is the bar again.
- `C:\SW_MUSH` is STRICTLY READ-ONLY. Never write under it.
- Clone Wars era only. WEG R&E leads mechanics. Keep the pure/presentation split.
  The **server owns all RNG/seeds/dice**.
- Document any mechanic divergence in `docs/DIVERGENCE_LEDGER.md` before coding it.
- **Do NOT make owner-level decisions.** If a slice needs one, STOP that slice and
  mark it `BLOCKED: needs owner decision — <which>`. STILL-OPEN owner decisions:
  Force/Jedi scarcity & access, PvP-consent specifics, siege durations/capture
  threshold, and whether the optional LLM "Director flavor" layer ships on at launch.
  DECIDED 2026-06-24 (use these): death penalty = partial loss + durability + insurance,
  credits kept (DIV-0006); CP progression = dual-track, fast gameplay-driven + slow
  RP-prestige (DIV-0007).
- Per iteration: implement → run the gate → if GREEN: `git add -A && git commit`,
  mark the item DONE (+hash), append a one-line note to `docs/NIGHTLY_HANDOFF.md`;
  if RED: fix, or `git checkout -- .` to revert and mark the item BLOCKED with the error.
- Stop the loop when: the list is dry, the top unblocked item needs an owner decision,
  or 3 consecutive iterations make no progress. Leave a clear status here for the owner.

## Queue

### 1. M1.3b — Combat netcode wiring  [STATUS: DONE]
Wire the verified `scripts/net/combat_arena.gd` into live multiplayer.
- `NetworkManager` (server): load `data/prototype_combatants.json`, hold a `CombatArena`,
  `register_player` on peer connect / `remove_player` on disconnect.
- `@rpc` `submit_fire_intent(target_id, aim, cover, cp, fp)` (client→server, validated).
- A ~5s server combat-window timer → `resolve_window(server_seed)` (server-owned seed)
  → broadcast each envelope via `@rpc` `apply_combat_envelope(envelope)`.
- `net_world` client: LMB/raycast sends a fire intent (aim from RMB); a HUD combat log
  renders incoming envelopes ("<shooter> hit <target> → Wounded", etc.); show the
  shared target's wound state.
- Acceptance: import clean; `net_smoke` + `combat_arena_smoke` + full gate green; a
  two-process headless run logs a client fire intent → server resolution → envelope
  received by the client (`[net]`/`[combat]` lines).

### A0 — Adopt the asset pipeline & restore the full gate  [STATUS: TODO] (next)
Claude now owns the asset pipeline (single-driver decision). Make it ours and green.
- Diagnose why `check_project.ps1 --import` fails on the missing
  `assets/3d/kenney/nature-kit/Isometric/ground_pathCornerSmall_NW.png` (likely a stale
  `.godot` import record or an un-curated pack referenced by a curated model). Fix it
  (re-run `python tools/fetch_assets.py curate`, remove the dangling reference, or
  clear+rebuild the import) WITHOUT discarding the curated `assets/3d/` content.
- Decide git policy for assets: gitignore the large raw `MMO_Assets/*.zip` archives;
  track curated `assets/3d/` + the pipeline scripts/catalog. Add to `.gitignore`.
- Read `docs/ASSET_CATALOG.md` + `tools/fetch_assets.py` to understand the pipeline.
- Acceptance: full `check_project.ps1` green again (import passes); pipeline + curated
  assets committed; raw zips gitignored.

### A1 — Greybox → low-poly: integrate Kenney models into the world  [STATUS: TODO]
Replace procedural box geometry in `scripts/world/world_builder.gd` with curated
Kenney GLB models (modular-space-kit / city-kit-industrial / factory-kit / blaster-kit)
where they fit, keeping the same collision + layout. Both solo and net worlds benefit
(they share the builder). Incremental — start with the spaceport-row buildings.
- Acceptance: `world_builder_smoke` + runtime launch + full gate green; the world
  visibly uses real low-poly models (note for owner visual check).

### 2. M1.4 — Persistence backbone (JSON first)  [STATUS: TODO]
Server-side persistence per `data/schemas/player_persistence.schema.json`.
- A pure `scripts/net/persistence_store.gd` (save/load a player record: position,
  combat state, name) to a JSON file under a server data dir (NOT under `C:\SW_MUSH`).
- `NetworkManager` (server): on join, load the record for the client's account/character
  id (client passes `--account <id>`; default a stable per-machine id); on disconnect
  (and on a periodic autosave), save.
- Acceptance: new `persistence_smoke` (pure save/load round-trip + missing-file default)
  green; full gate green; two-process run: a client reconnect restores last position
  (logged).

### 3. M1.5 — Player identity / nameplate  [STATUS: TODO]
Client sends a chosen display name on join (`--name <name>`); server uses it in
snapshots and combat envelopes instead of `Spacer-N`.
- Acceptance: `net_smoke` covers the name flow; full gate green.

### 4. M2.0 — Zone & security-state scaffold  [STATUS: TODO]
Pure `scripts/net/zone_state.gd` backed by `data/schemas/security_zone.schema.json` +
`faction_zone_state.schema.json`: track a zone's security tier (secured/contested/
lawless) and per-faction influence; a SLOW Director tick (default ~30s, deterministic,
no LLM) that nudges influence and re-derives the tier. Expose the current tier in the
snapshot. Ground it in `docs/WORLD_SIM_DESIGN.md`.
- Acceptance: `zone_state_smoke` (tier derivation + deterministic tick) green; full gate green.

### 5. M2.1 — Territory claim scaffold  [STATUS: TODO]
Pure `scripts/net/territory_model.gd` backed by `territory_claim.schema.json`: claim a
node (precondition: influence threshold), accrue passive income on the Director tick.
Ground it in `docs/FACTION_TERRITORY_DESIGN.md`. (The full Drop-6D siege loop is later
and partly owner-gated — do NOT build siege durations/thresholds here.)
- Acceptance: `territory_smoke` (claim precondition + income accrual) green; full gate green.

### 6. P1 — Client polish  [STATUS: TODO]
In `net_world`: smoother remote-avatar interpolation, a clean combat-log panel, and a
target-state readout. Presentation only.
- Acceptance: import + runtime-launch checks clean; full gate green.

### 7. Content drop 2 — vehicles/starships + droids  [STATUS: TODO]
One-way extract era-appropriate vehicles/starships + droid models from read-only
`C:\SW_MUSH` into new `data/*.json` with provenance; extend `content_smoke`.
- Acceptance: `content_smoke` green; full gate green.

## Log
(iterations append here: `- <date> <ITEM> DONE <hash> — <note>` or `BLOCKED — <why>`)
- 2026-06-24 M1.3b DONE — combat netcode wired (CombatArena on server, submit_fire_intent RPC, 5s window timer, apply_combat_envelope broadcast, client fire/aim + HUD combat log). Verified end-to-end: two-process autofire run shows client intent → server WEG resolution (own seed) → envelope → client playback. Smokes/launch/python all green. NOTE: full `check_project.ps1 --import` currently fails on Codex's half-curated Kenney asset (not our code).
