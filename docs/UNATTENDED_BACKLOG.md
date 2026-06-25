# Unattended Development Backlog

The self-paced unattended loop (see `docs/UNATTENDED_LOOP.md` → "Claude Code
Self-Paced Loop") works this list **top-down**, one self-contained slice per
iteration. Each slice must end at a green `tools/check_project.ps1` and a git commit,
or be reverted. Mark items `DONE` / `BLOCKED` as you go; append the commit hash.

## Guardrails (every iteration)
- **A parallel Codex session shares this repo** and owns the ART/ASSET pipeline:
  `tools/fetch_assets.py`, `tools/asset_sources.json`, `MMO_Assets/`, `assets/`,
  `docs/ASSET_CATALOG.md`, `docs/asset_previews/`. NEVER touch, stage, or revert those.
  Commit ONLY the specific files this loop changed — `git add <paths>`, NEVER
  `git add -A`. On red, revert ONLY your own files — `git checkout -- <your paths>` —
  NEVER a blanket `git checkout -- .`, `git reset --hard`, or `git clean` (those would
  destroy Codex's in-flight work). The loop's green bar is the GDScript smokes +
  runtime launch + python tests (run them directly); the full `check_project.ps1`
  `--import` step may fail on Codex's half-curated assets — that is NOT your regression.
- `C:\SW_MUSH` is STRICTLY READ-ONLY. Never write under it.
- Clone Wars era only. WEG R&E leads mechanics. Keep the pure/presentation split.
  The **server owns all RNG/seeds/dice**.
- Document any mechanic divergence in `docs/DIVERGENCE_LEDGER.md` before coding it.
- **Do NOT make owner-level decisions.** If a slice needs one, STOP that slice and
  mark it `BLOCKED: needs owner decision — <which>`. Owner decisions include:
  Force/Jedi scarcity & access, death/loot penalty model, CP progression pace/source,
  PvP-consent specifics, siege durations/capture threshold, and whether the optional
  LLM "Director flavor" layer ships on at launch.
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
