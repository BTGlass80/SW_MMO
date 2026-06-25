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

### A0 — Adopt the asset pipeline & restore the full gate  [STATUS: DONE]
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

### A1 — Greybox → low-poly: integrate Kenney models (increment 1)  [STATUS: DONE]
Added `instance_model`/`place_model` (cached PackedScene) helpers to
`scripts/world/world_builder.gd`; parked real Kenney craft on Bays 86/87 + by the
speeder shop (Bay 94 left clear for the range); swapped crate-stack visuals to
factory-kit crate models (box collision preserved); scattered survival-kit barrels.
Additive/visual-only, so all existing collision + layout is intact. Both solo and net
worlds get it (shared builder). **Scales/orientations are first-pass — owner visual
check worthwhile.** Building-model swaps are the follow-up A1b.

### A1b — Building models + visual scale tuning  [STATUS: DEFERRED — awaits owner visual check]
Swap hab-block/tower/landing-pad procedural boxes for city-kit-industrial /
space-station-kit / modular-buildings models, scaled to fit each existing collision
footprint (measure model AABB after instancing, scale-to-fit, keep the box collision).
Tune the increment-1 ship/crate/barrel scales from owner visual feedback.
- Acceptance: `world_builder_smoke` + runtime launch + full gate green.

### 2. M1.4 — Persistence backbone (JSON first)  [STATUS: DONE]
Server-side persistence per `data/schemas/player_persistence.schema.json`.
- A pure `scripts/net/persistence_store.gd` (save/load a player record: position,
  combat state, name) to a JSON file under a server data dir (NOT under `C:\SW_MUSH`).
- `NetworkManager` (server): on join, load the record for the client's account/character
  id (client passes `--account <id>`; default a stable per-machine id); on disconnect
  (and on a periodic autosave), save.
- Acceptance: new `persistence_smoke` (pure save/load round-trip + missing-file default)
  green; full gate green; two-process run: a client reconnect restores last position
  (logged).

### 3. M1.5 — Player identity / nameplate  [STATUS: DONE]
Client sends a chosen display name on join (`--name <name>`); server uses it in
snapshots and combat envelopes instead of `Spacer-N`.
- Acceptance: `net_smoke` covers the name flow; full gate green.

### 4. M2.0 — Zone & security-state scaffold  [STATUS: DONE]
Pure `scripts/net/zone_state.gd` backed by `data/schemas/security_zone.schema.json` +
`faction_zone_state.schema.json`: track a zone's security tier (secured/contested/
lawless) and per-faction influence; a SLOW Director tick (default ~30s, deterministic,
no LLM) that nudges influence and re-derives the tier. Expose the current tier in the
snapshot. Ground it in `docs/WORLD_SIM_DESIGN.md`.
- Acceptance: `zone_state_smoke` (tier derivation + deterministic tick) green; full gate green.

### 5. M2.1 — Territory claim scaffold  [STATUS: DONE]
Pure `scripts/net/territory_model.gd` backed by `territory_claim.schema.json`: claim a
node (precondition: influence threshold), accrue passive income on the Director tick.
Ground it in `docs/FACTION_TERRITORY_DESIGN.md`. (The full Drop-6D siege loop is later
and partly owner-gated — do NOT build siege durations/thresholds here.)
- Acceptance: `territory_smoke` (claim precondition + income accrual) green; full gate green.

### 6. P1 — Client polish  [STATUS: DEFERRED — awaits owner visual check]
In `net_world`: smoother remote-avatar interpolation, a clean combat-log panel, and a
target-state readout. Presentation only.
- Acceptance: import + runtime-launch checks clean; full gate green.

### 7. Content drop 2 — vehicles/starships + droids  [STATUS: DONE]
One-way extract era-appropriate vehicles/starships + droid models from read-only
`C:\SW_MUSH` into new `data/*.json` with provenance; extend `content_smoke`.
- Acceptance: `content_smoke` green; full gate green.

## Wave C — Character Creation & Progression  (owner-chosen 2026-06-24; loop RESUMED)

The owner picked this as the next wave. Mostly engineering, grounded in
`C:\SW_MUSH\docs\design\Guide_02_Character_Creation.md` + `Guide_09_CP_Progression.md`,
`data/species_clone_wars.json` + `data/weg_skill_catalog.json`, and the DIV-0007
dual-track CP decision. WEG R&E leads the math. Owner-gated items NOT in this wave:
Force/Jedi access (force_sensitive stays a data hook, default false).

### C1 — Chargen rules model  [STATUS: DONE]
Pure `scripts/rules/chargen_model.gd`: validate a character build against WEG R&E +
species data — attribute dice allocated within the species min/max and the species
attribute-dice budget; starting skill dice budget; produce a starting sheet
(attributes, skills, CP/FP, wound_state healthy) in the `data/schemas/player_persistence`
`sheet` shape. Support the 7 WEG templates as quick-start presets if cheap. Pure +
`chargen_smoke` (valid build accepted, over-budget/out-of-range rejected, sheet shape).
- Acceptance: `chargen_smoke` + full gate green.

### C2 — Server chargen flow  [STATUS: DONE]
New characters run chargen on first login: extend the register/create path so a client
with no saved record sends {species, attributes, skills, name} (validated by C1) and the
server persists the resulting sheet via the M1.4 store; a quick-start default build if
none provided. Existing characters load as today.
- Acceptance: full gate green; two-process check: a new account creates a character that
  persists and reloads with its sheet.

### C3 — Progression model  [STATUS: TODO]
Pure `scripts/rules/progression_model.gd`: WEG advancement costs (raise a skill: CP =
the skill's current die code rounded; attributes per R&E), and the DIV-0007 DUAL-TRACK
CP wallet (gameplay CP + slow RP-prestige CP), with spend-validation. Pure +
`progression_smoke`.
- Acceptance: `progression_smoke` + full gate green.

### C4 — Wire CP earning + spending  [STATUS: TODO]
Award gameplay CP for combat (disabling the shared target) on the dual track; an RPC to
spend CP to raise a skill; persist via the store. Client shows CP wallet + a raise action.
- Acceptance: full gate green; two-process check: defeating the target awards CP and a
  spend raises a skill and persists.

## Log
(iterations append here: `- <date> <ITEM> DONE <hash> — <note>` or `BLOCKED — <why>`)
- 2026-06-24 LOOP RESUMED — owner chose Wave C (Character Creation & Progression). Next: C1.
- 2026-06-24 C2 DONE — server chargen flow: `register_account(account_id, name, build)` now runs `_create_character` for NEW characters — validates the requested WEG build (or a deterministic quick-start) via chargen_model against the server-loaded species data, persists the resulting sheet via the M1.4 store. Client passes `--species`/`--quickstart`. Verified over the wire: a new `--species rodian --quickstart` account created `species=rodian dex=3D+1 cp=5` (species-aware), persisted. Existing characters load unchanged. Full gate green (36 smokes). Combat still uses the shared trainee pools — using the per-character sheet IN combat is a later slice.
- 2026-06-24 C1 DONE — pure `scripts/rules/chargen_model.gd` (WEG R&E): validate_build enforces exactly 18D attributes within species min/max + a 7D skill budget, produces the player_persistence `sheet` (CP 5 / FP 1 / force_sensitive false / healthy); default_build gives a deterministic in-range quick-start. `chargen_smoke`. Full gate green (36 smokes). NOTE: a parallel session owns the asset pipeline (`docs/ASSET_PIPELINE.md` etc.) — kept scoped commits.
- 2026-06-24 Content drop 2 DONE — one-way extract from read-only SW_MUSH: `data/starships_clone_wars.json` (6 era-appropriate civilian craft; GCW/Imperial ships excluded — content_smoke asserts none leak), `data/droids_clone_wars.json` (3 commerce droids), `data/creatures_clone_wars.json` (22 wildlife). content_smoke extended; manifest updated. Full gate green.
- 2026-06-24 **LOOP STOP** — backlog dry of unblocked, non-owner-decision, non-visual items. Remaining: A1b/P1 (DEFERRED, need owner visual check) and the owner-gated features (org/claim commands, guard NPCs, siege/Drop-6D, Force/Jedi, death penalty, LLM-Director-at-launch). Handed back to owner.
- 2026-06-24 M2.1 DONE — pure `scripts/net/territory_model.gd`: an org claims a node in a contested/lawless zone (precondition: influence >= foothold floor; secured not claimable; one claim per node), deriving influence tier (foothold/dominant/control) + member effective-security (lawless->contested upgrade); passive income accrues to org treasuries on a 60s resource tick, scaled by tier x risk (lawless > contested). `territory_smoke`. NetworkManager holds the registry + resource tick (no-op until the future org/claim command layer). Siege/Drop-6D deliberately NOT built (owner-gated). Full gate green (35 smokes).
- 2026-06-24 M2.0 DONE — pure `scripts/net/zone_state.gd` world-sim director: per-zone faction influence (republic/cis/hutt/independent) with DERIVED alert level (lockdown/high_alert/standard/lax/underworld/unrest) + DERIVED effective security tier (hutt>=80 downgrades; crackdown upgrades contested), advanced by a slow deterministic 30s Director tick (decay->baseline, no LLM — owner decision left off). Server seeds a Mos Eisley zone and folds its posture into the snapshot; client shows an alert/security badge. `zone_state_smoke` + two-process check (`zone=high_alert/secured`). Full gate green (34 smokes).
- 2026-06-24 M1.5 DONE — client `--name <name>` flows via `register_account(account_id, display_name)`; server applies it to the WorldState player name (snapshot nameplates), the CombatArena player name (`set_player_name` → combat envelopes), and persists it. Coverage in net_smoke (restore_player rename) + combat_arena_smoke (named shooter). Verified over the wire: a `--name "Mara Jade"` client shows `Mara Jade hit B1 ...` in the combat log. Full gate green.
- 2026-06-24 M1.4 DONE — pure `scripts/net/persistence_store.gd` (JSON per character, schema-shaped per player_persistence.schema.json) + `persistence_smoke`. NetworkManager: `register_account` RPC loads/restores a character on login (position + CP/FP/wound), saves on disconnect + 30s autosave; client passes `--account`. Verified end-to-end: a client autowalked from spawn to z=-58, disconnected, and a reconnect with the same account was restored to (-20,1.2,-58). Full gate green.
- 2026-06-24 A1 DONE (increment 1) — `instance_model`/`place_model` helpers in world_builder; parked Kenney craft on Bays 86/87 + speeder shop, crate-stack visuals → factory-kit crate models (collision kept), survival-kit barrels added. Solo + net worlds both updated (shared builder). Gate green. Scales are first-pass → owner visual check worthwhile. Buildings deferred to A1b.
- 2026-06-24 A0 DONE — root-caused the broken `--import`: Kenney "GLB format" GLBs reference an external Textures/colormap.png that `curate` dropped (only kept .glb). Fixed `_curated_members` in fetch_assets.py to also extract GLB-format textures (drop FBX/OBJ dupes), re-curated all 11 packs (--force), reimported clean (0 errors). gitignored MMO_Assets/ (925M raw zips) + __pycache__; tracked curated assets/3d/ (41M). Full `check_project.ps1` GREEN again.
- 2026-06-24 M1.3b DONE — combat netcode wired (CombatArena on server, submit_fire_intent RPC, 5s window timer, apply_combat_envelope broadcast, client fire/aim + HUD combat log). Verified end-to-end: two-process autofire run shows client intent → server WEG resolution (own seed) → envelope → client playback. Smokes/launch/python all green. NOTE: full `check_project.ps1 --import` currently fails on Codex's half-curated Kenney asset (not our code).
