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
- **Green bar:** the **full** `check_project.ps1` (import + runtime launch + GDScript
  smokes + python tests). A0 fixed the `--import` break (the A0 colormap fix is live);
  the old "import can fail on a half-curated Kenney asset" caveat is **stale**.
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

### M2.2 — Director world events  [STATUS: DONE] (self-extended)
The Director now fires deterministic, one-at-a-time world events per zone (no LLM —
the LLM "flavor" layer stays owner-gated). `zone_state.gd` rolls `hash(tick:zone) % 100`
against `EVENT_CHANCE` when no event is active, picks a type from a fixed 12-event menu
keyed off the zone's dominant influence (republic crackdown/checkpoint, hutt bounty/
auction, cis propaganda/pirate, else a neutral Tatooine list), and exposes the headline
in `zone_summary` (`event` / `event_type`). The client renders a NEWS line in the HUD and
logs `[news] <headline>` on change. A `--director-tick <secs>` server override speeds the
slow tick for headless verification.
- Acceptance: `zone_state_smoke` (event fires within 40 ticks, valid type, deterministic)
  + full gate green; two-process check: a client receives `[news]` headlines over the wire.

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

### C3 — Progression model  [STATUS: DONE]
Pure `scripts/rules/progression_model.gd`: WEG advancement costs (raise a skill: CP =
the skill's current die code rounded; attributes per R&E), and the DIV-0007 DUAL-TRACK
CP wallet (gameplay CP + slow RP-prestige CP), with spend-validation. Pure +
`progression_smoke`.
- Acceptance: `progression_smoke` + full gate green.

### C4 — Wire CP earning + spending  [STATUS: DONE] (Wave C complete)
Award gameplay CP for combat (disabling the shared target) on the dual track; an RPC to
spend CP to raise a skill; persist via the store. Client shows CP wallet + a raise action.
- Acceptance: full gate green; two-process check: defeating the target awards CP and a
  spend raises a skill and persists.

## Wave D — Combat uses the character sheet  (owner-chosen 2026-06-25; loop RESUMED)

The owner's next pick: make chargen + progression actually change how you fight.
Today `combat_arena.gd` uses one shared trainee pool (`_player_pools` from
`data/prototype_combatants.json`) for every player. Drive each player's combat pools
from their own persisted `sheet` instead.

### D1 — Per-character combat pools  [STATUS: DONE]
- In `scripts/net/combat_arena.gd`, split pools into the shared TARGET side (stays
  from combat_data) and a PER-PLAYER side built from the character sheet:
  attacker_pool = DEX + blaster-skill bonus; player_dodge_pool = DEX + dodge bonus;
  player_soak_pool = STR; damage_pool = a default starter blaster (no inventory yet —
  note it); attacker_scale = character. Add `set_player_sheet(peer_id, sheet)` that
  (re)builds that player's pools. Keep `register_player` WITHOUT a sheet using the
  current trainee pools (backward-compatible; existing tests stay green).
- In `scripts/net/network_manager.gd`, on `register_account` pass the loaded
  character's `sheet` to the arena (`set_player_sheet`) so combat reflects real stats.
- Extend `combat_arena_smoke`: a stronger sheet (higher DEX / blaster) yields a bigger
  attacker pool than a weaker one; default (no sheet) still works.
- Acceptance: full gate green; two-process check that a character who raised Blaster
  fires with a larger shot pool (visible in the combat envelope's `shot_pool`).
  KNOWN follow-up: damage still uses a default weapon until an inventory/equipment
  system exists (a later slice / owner-scoped).

### D2 — Combat uses equipped weapon + armor  [STATUS: DONE]
Chargen sheets now carry a starter `equipment: {weapon, armor}` (blaster_pistol +
blast_vest). `combat_arena` takes weapon/armor catalogs and builds each player's
`damage_pool` from the equipped weapon and `player_armor` from the equipped armor
(fallback to defaults when absent). NetworkManager loads `weapons_clone_wars.json` +
`armor_clone_wars.json` and passes them to the arena. KNOWN follow-up (D3): an actual
inventory/equipment-swap system so players can change loadout.

## Wave E — Persistent-world depth & faithfulness  (stocked 2026-06-25 by a 5-reader codebase audit)

This wave was generated by a full subsystem audit (rules / netcode / world-sim+data /
tests / docs). It is deliberately DEEP and BREADTH-FIRST so the unattended loop can
**parallelize**: the `[PAR]` items are pure-model+test (or docs/test-only) slices that
each create their OWN new files and can run CONCURRENTLY (batch 2–4 per tick via the
Workflow tool, isolating with `isolation:'worktree'` when several run at once, then
integrate the green ones serially on main and run the gate once per integration). The
`[HOT]` items edit the shared hot files (`network_manager.gd` / `net_world.gd`) and MUST
be done ONE AT A TIME on the main tree. See `docs/SESSION_HANDOFF.md` →
"Parallelization playbook." Do the `[PAR]` pure substrate first; it unblocks the `[HOT]`
features and adds the test coverage the loop relies on. **Divergence-ledger-first**
items are flagged: add the `DIVERGENCE_LEDGER.md` row IN the same slice, before/with the
code (these are faithful WEG restorations, NOT owner forks).

### E1 — Reconcile stale roadmap docs  [STATUS: DONE] [PAR] [docs] [S]
Docs-only: move `docs/MULTIPLAYER_FOUNDATION.md` Status/Roadmap forward (M1.3b/M1.4/M1.5
DONE; add M2.0–2.2 + Wave C + Wave D); delete the self-contradicted "loop has STOPPED at
Wave C" paragraph in `docs/NIGHTLY_HANDOFF.md`; mark `docs/NEXT_DECISIONS.md`
resolved/archived (its 3 questions are long-decided). Also correct the stale "`--import`
can fail on half-curated assets" note in `docs/UNATTENDED_LOOP.md` + this file's
Guardrails — A0 fixed it; the FULL `check_project.ps1` is the green bar now.
- Acceptance: gate stays green (no code touched); every "DONE" claim has a matching Log row + on-disk script/test. Good zero-risk first tick.

### E2 — Restore WEG cumulative wound ladder + Wounded-Twice  [STATUS: DONE] [PAR] [rules] [M] (ledger-first)
New pure `scripts/rules/wound_ladder_model.gd`: canonical WEG ladder
(Healthy/Stunned/Wounded/Wounded-Twice/Incapacitated/Mortally/Dead), per-level penalty
dice (Wounded −1D, Wounded-Twice −2D, stun −1D each), cumulative escalation
(Wounded+Wounded→Incapacitated, Incap+any→Mortally, Mortally+any→Dead,
stun-on-wounded→Wounded-Twice). Keep `d6_rules.wound_for_damage_margin` as the single-hit
chart but route `ground_combat_model` severity accumulation + `_wound_penalty_dice`
through the new model so severity-3 yields −2D, not the current silent 0D. Grounded in
SW_MUSH Guide_01 / Guide_19 §1. **Add a DIVERGENCE_LEDGER row** for the prior collapsed ladder.
- Files: `scripts/rules/wound_ladder_model.gd`, `scripts/rules/ground_combat_model.gd`, `scripts/tests/wound_ladder_model_smoke.gd`, `tools/check_project.ps1`, `docs/DIVERGENCE_LEDGER.md`.
- Acceptance: new smoke (penalty dice per level + all escalation transitions) green & wired; `ground_combat_model_smoke` still passes; full gate green; new DIV row.

### E3 — Wound recovery / healing model  [STATUS: DONE] [PAR] [rules] [M] (depends E2)
New pure `scripts/rules/recovery_model.gd`: stun-timer auto-expiry (2 rounds → Healthy),
First Aid/Medicine heal check vs wound-level difficulty (Guide_19 §3 table), mortally-
wounded death roll (2D < rounds_mortally_wounded ⇒ dead), post-death −1D debuff timer.
All seed-driven via a passed rng; no nodes/sockets. **No** owner-gated death-PENALTY
(loot/insurance) logic — recovery mechanics only.
- Acceptance: `recovery_model_smoke` green & wired (seeded heal drops exactly one level; deterministic death roll; timers); full gate green.

### E4 — Derived-stats model  [STATUS: DONE] [PAR] [rules] [S]
New pure `scripts/rules/derived_stats_model.gd`: Move (from the unused `move` field in
`species_clone_wars.json`), base soak (= Strength), Strength melee bonus, stun-knockout
threshold (= Strength dice). Optionally surfaced via `character_sheet_model` `derived()`.
- Acceptance: `derived_stats_model_smoke` green & wired; existing `character_sheet_model_smoke` unchanged; full gate green.

### E5 — Weapon-driven range bands  [STATUS: DONE] [PAR*] [rules] [M] (ledger-first; *edits d6_rules.gd — serialize with other d6_rules edits)
Add `range_band_for_weapon(distance, ranges_array)` to `d6_rules.gd` using each weapon's
own `[short_min,short_max,med_max,long_max]` from `weapons_clone_wars.json` (point-blank
below short_min), falling back to the fixed `RANGE_BANDS` when no ranges passed. Thread an
optional `weapon_ranges` arg through `resolve_ranged_attack` without breaking callers.
**Add a DIVERGENCE_LEDGER row** for the prior single fixed-band approximation.
- Acceptance: `rules_smoke` extended (per-weapon bands + legacy fallback) green; full gate green; new DIV row.

### E6 — Default-off Force-skill data hook  [STATUS: DONE] [PAR*] [rules] [M] (ledger-first; *edits chargen_model.gd)
New pure `scripts/rules/force_skills_model.gd` + extend `chargen_model.gd`: declare WEG
Control/Sense/Alter as a data hook defaulting to 0D and INACTIVE unless `force_sensitive`
is true; helpers `force_skill_pool()` / `can_use_force()` return empty/false when not
sensitive. **No power list, NO scarcity/access policy** (owner-gated) — only the
off-by-default plumbing. **Add a DIVERGENCE_LEDGER row** noting Force access/scarcity stays an open owner decision.
- Acceptance: `force_skills_model_smoke` green & wired; `chargen_smoke` still green (force_sensitive false, no Force budget); full gate green; new DIV row.

### E7 — `get_effective_security` single combat gate  [STATUS: DONE] [PAR] [world-sim] [M]
Implement WORLD_SIM_DESIGN §3.2 as a pure function (new `scripts/net/security_gate.gd` or
a `zone_state` static): resolve order room-faction-override → city-citizen upgrade →
territory-claim upgrade → Director overlay → single effective tier. Pure only; do NOT wire
into the live attack path (hot file) here. PvP-consent stays owner-gated/out of scope.
- Acceptance: `security_gate_smoke` green & wired (override/citizen/claim/hutt-surge precedence); full gate green; no hot-file edits.

### E8 — Pending-zone-influence accrual model  [STATUS: DONE] [PAR] [world-sim] [M]
New pure `scripts/net/pending_influence_model.gd`: accumulate per-character
`{zone_id, axis, delta}` (the schema's `world_hooks.pending_zone_influence`) and
fold-and-clear into a `zone_state` influence delta at recompute. Pure substrate only — do
NOT wire combat into it here (that's the [HOT] E24). Establishes the player→world loop.
- Acceptance: `pending_influence_smoke` green & wired (clamp, fold-then-clear, deterministic, missing-zone no-op); full gate green.

### E9 — Org membership + claim-command validator  [STATUS: DONE] [PAR] [world-sim] [M]
New pure `scripts/net/org_model.gd`: membership (one faction + ≤3 guilds, ranks per
FACTION_TERRITORY_DESIGN §1, claim at rank 3+) and a claim-command validator composing
org rank + territory influence + zone security into allow/deny. Pure substrate for the
[HOT] E23 RPC layer. Siege transitions excluded (owner-gated).
- Acceptance: `org_model_smoke` green & wired (faction/guild caps, rank-3 gate, secured-zone & influence-floor rejection); full gate green.

### E10 — Creature spawn-table model  [STATUS: DONE] [PAR] [world-sim] [M]
New pure `scripts/rules/creature_spawn_model.gd` consuming the orphaned
`creatures_clone_wars.json`: given zone alert/security + a seed, deterministically pick a
creature + pack size (pack_count range, hostile flag). Model only (no spawn/AI/nodes).
- Acceptance: `creature_spawn_smoke` green & wired (deterministic selection, pack sizes in range, char_sheet/natural_attack present); full gate green.

### E11 — NPC vendor / price model  [STATUS: DONE] [PAR] [world-sim] [M]
New pure `scripts/rules/vendor_model.gd` consuming `weapons`/`armor` (filtered
`vendor_stocked`) + the orphaned `droids_clone_wars.json` bargain tiers: deterministic
price model with a Director `trade_boom`/`merchant_arrival` multiplier and droid bargain
discount; list/quote functions; exclude contraband/faction-issued. Model only (no economy persistence).
- Acceptance: `vendor_smoke` green & wired; full gate green.

### E12 — Faction-reputation model  [STATUS: DONE] [PAR] [world-sim] [S]
New pure `scripts/rules/reputation_model.gd`: per-character rep on the four faction axes +
Bounty Hunters' Guild, clamped apply/delta, derived standing tiers
(hostile/neutral/friendly/allied), serializable to the `org` rep shape. Model only.
- Acceptance: `reputation_smoke` green & wired; full gate green.

### E13 — Director event mechanical effects + event→influence nudges  [STATUS: OPEN] [PAR*] [world-sim] [M] (*edits zone_state.gd — serialize with E2-route/other zone edits)
In `zone_state.gd`: a pure, owner-tunable `EVENT_EFFECTS` table mapping each of the 12
event types to bounded modifiers (smuggling/vendor/spawn/perception) surfaced in
`zone_summary`, plus the documented per-tick active-event influence nudges (crackdown →
republic +1/tick, cis_propaganda → cis +1/tick, pirate/auction → hutt +1/tick), clamped,
deterministic. Closes the documented causal loop (events were flavor-only).
- Acceptance: `zone_state_smoke` extended (effect lookups + clamped nudges, deterministic); full gate green; no 20 Hz-path change.

### E14 — Data-drive world_builder set-dressing  [STATUS: OPEN] [PAR] [world-sim] [S]
Add `data/mos_eisley_props.json` (extra props referencing ONLY GLB models world_builder
already uses — crates/barrels/ships — with position/rotation/scale); `world_builder`
optionally reads it, falling back to the hardcoded layout when absent. **No asset-pipeline
files touched.**
- Acceptance: `world_builder_smoke` extended (parses + deterministic placement); solo + net build identically; full gate green.

### E15 — Snapshot zone-merge smoke  [STATUS: DONE] [PAR] [tests] [S]
`scripts/tests/snapshot_merge_smoke.gd`: replicate `_build_snapshot`'s merge (WorldState
snapshot + `zones.zone_summary` under `zone`) and assert the merged shape clients consume.
- Acceptance: wired & green ("snapshot_merge_smoke: OK"); fails if a zone key is missing.

### E16 — Wire round-trip fidelity smoke  [STATUS: DONE] [PAR] [tests] [S]
`scripts/tests/wire_roundtrip_smoke.gd`: run a snapshot + a combat envelope through
JSON/var round-trip; assert no field/type loss on the RPC payloads.
- Acceptance: wired & green; breaking a field type locally makes it fail.

### E17 — Skill→attribute resolution smoke  [STATUS: DONE] [PAR] [tests] [S]
`scripts/tests/skill_attribute_smoke.gd`: replicate `_load_skill_attributes` over
`weg_skill_catalog.json`; assert known maps (blaster→dexterity, starship_gunnery→
mechanical, …) + sane default. Locks the lookup behind server skill-raises.
- Acceptance: wired & green.

### E18 — Chargen→persistence lifecycle smoke  [STATUS: DONE] [PAR] [tests] [S]
`scripts/tests/character_lifecycle_smoke.gd`: Chargen build → PersistenceStore save →
reload; assert CP/FP/wound + attributes/skills survive. Verifies the create→persist→reload
chain `register_account`/`_create_character` depend on (using tested pure pieces only).
- Acceptance: wired & green; throwaway `user://` dir cleaned; RNG seeded.

### E19 — CP-award-on-disable rule smoke  [STATUS: DONE] [PAR] [tests] [S]
`scripts/tests/cp_award_smoke.gd`: model the post-disable reward (Progression.award
'gameplay' 3 per shooter) and assert the wallet gain is spendable. Guards the `_award_cp`
economy hook without editing `network_manager.gd`.
- Acceptance: wired & green.

### E20 — Harden combat_event_log ordering asserts  [STATUS: DONE] [PAR] [tests] [S]
Extend `combat_event_log_model_smoke.gd`: assert trim-keeps-newest ordering + stable
kind-filter chronological order. Test-file only.
- Acceptance: gate green; reversing trim order in the model locally fails the smoke.

### E21 — Seed multiple zones + snapshot routing  [STATUS: OPEN] [HOT] [netcode] [M]
Add `data/zones_clone_wars.json` (spaceport secured, port-fringe contested, dune-sea
lawless, …); replace the single hardcoded `add_zone` in `start_server` with a data loop
that ticks ALL zones; give each player a `current_zone_id`; `_build_snapshot` emits that
player's zone summary. Precondition for territory claims (needs a contested/lawless zone)
and ambient sim. Add `zones_smoke`.
- Acceptance: N zones server-side with distinct bases; player snapshot reflects their zone; full gate green; two-process check shows a contested/lawless zone available.

### E22 — Inventory / equipment-swap RPC (D3)  [STATUS: OPEN] [HOT] [netcode] [M]
`submit_equip(slot, item_key)` [any_peer, reliable]: validate item in the loaded
weapon/armor catalog + ownership (simple inventory list on the sheet), write
`sheet.equipment`, persist, `arena.set_player_sheet`, reply. Completes the half-wired
equip path (read path already exists). Add `equip_smoke`.
- Acceptance: invalid/unowned rejected; valid swap changes the damage/armor pool and survives save+reload; full gate green; two-process check.

### E23 — Org claim/release command RPCs  [STATUS: OPEN] [HOT] [netcode] [M] (depends E9; E21 helps)
Wire the instantiated Territory into the RPC surface: `submit_claim_node` /
`submit_release_claim` validated via the E9 org-model + zone security; fold a compact
territory summary into the snapshot/reply so the 60s resource tick stops being a no-op.
Excludes the owner-gated siege loop.
- Acceptance: claim a contested/lawless node → treasury credited next resource tick; secured/already-claimed rejected; full gate green; two-process check.

### E24 — Player actions feed zone influence  [STATUS: OPEN] [HOT] [netcode] [M] (depends E8)
On combat target-disable (and/or periodic presence), call
`zones.apply_influence_delta(zone, axis, delta)` via the E8 pending-influence model so
player activity shifts faction influence and the derived alert/security visibly move.
- Acceptance: after N disables, influence on the chosen axis changes and at threshold the alert tier flips; snapshot reflects it; full gate green.

### E25 — Chat / emote RPC for RP  [STATUS: OPEN] [HOT] [netcode] [M]
Pure `scripts/net/chat_model.gd` (validate/normalize: strip control chars, clamp length,
channel whitelist say/emote/ooc) + `submit_chat`/`apply_chat` broadcast RPCs + a HUD
last-N-lines panel. First real social/RP channel on the wire.
- Acceptance: `chat_model_smoke` green; a line round-trips to all peers in a two-process run; full gate green.

### E26 — Account auth/ownership guard + rate-limit + cache  [STATUS: OPEN] [HOT] [netcode] [M]
Close the identity-spoofing gap: bind a peer to an account via a server-side
`account_secret` in the record (first claim sets it; wrong secret rejected); add
per-peer reliable-RPC rate limiting + an in-memory record cache (kill the
load+rewrite-per-call I/O in `submit_skill_raise`). Add `account_auth_smoke`.
- Acceptance: wrong-secret peer can't load/overwrite an existing character; correct secret loads; skill-raise no longer re-reads JSON each call; full gate green.

### E27 — Ambient NPC sim model + snapshot  [STATUS: OPEN] [HOT] [netcode] [L] (depends E21; E10 helps)
Pure `scripts/net/ambient_sim_model.gd` advanced by the Director tick: deterministically
spawn/despawn a small NPC roster keyed to zone event/alert (positions in bounds, hash-
seeded like zone_state), folded into the snapshot as `npcs[]` so clients can render them.
The spawn/sim foundation beyond headline-only events.
- Acceptance: `ambient_sim_model_smoke` green (deterministic count by alert, in-bounds, despawn on expiry); snapshot carries `npcs`; full gate green.

## Log
(iterations append here: `- <date> <ITEM> DONE <hash> — <note>` or `BLOCKED — <why>`)
- 2026-06-25 E15+E16+E17+E18+E19+E20 DONE (Wave E test-coverage batch 5) — six regression-guard smokes authored concurrently by the **gdscript-test-author** subagent (author→adversarial-review per slice, 12 agents), each cross-checking its asserted literals against the REAL source; all six passed standalone first try. **E15** `snapshot_merge_smoke` (replicates `network_manager._build_snapshot` merging WorldState snapshot + `zones.zone_summary` under `zone`; fails if the zone key/keys go missing). **E16** `wire_roundtrip_smoke` (a real envelope + snapshot through JSON.stringify→parse; guards field/type loss on RPC payloads — reviewer verified the Vector3→JSON-string behavior against Godot 4.6 `json.cpp`). **E17** `skill_attribute_smoke` (replicates `_load_skill_attributes` over `weg_skill_catalog.json`; all 16 skill→attribute maps + the dexterity default verified against the catalog; locks the lookup behind server skill-raises). **E18** `character_lifecycle_smoke` (Chargen build → PersistenceStore save → reload; CP/FP/wound/attributes/skills/equipment survive; throwaway user:// cleaned). **E19** `cp_award_smoke` (models the `_award_cp` reward via the pure progression_model — award 3 gameplay CP then spend it on a raise; guards the economy hook). **E20** extended `combat_event_log_model_smoke` (trim-keeps-newest ordering + stable chronological kind-filter; would fail if trim kept oldest or the filter order shuffled). 5 new smokes wired (E20 extends an already-wired test); full gate GREEN (49 GDScript smokes + 7 python + import + launch). No source files touched (test-only).
- 2026-06-25 E5+E6 DONE (Wave E rules batch 4, ledger-first) — two additive, backward-compatible rules edits authored concurrently by the **d6-rules-engineer** subagent (disjoint files), integrated with one full gate; all affected smokes (rules_smoke/chargen_smoke/all combat) stayed green. **E5** weapon-driven range bands: `d6_rules.range_band_for_weapon(distance, ranges)` uses each weapon's own `[short_min,short_max,med_max,long_max]` (point-blank<short_min=VE5, Short=E10, Medium=M15, Long=D20, beyond=Extreme30; malformed→fixed-table fallback), threaded through `resolve_ranged_attack` via a FINAL optional `weapon_ranges: Array = []` arg so every existing caller is byte-identical; `rules_smoke` extended (per-weapon bands for blaster_pistol [3,10,30,120] + legacy fallback + a divergence case). Live ground-combat callers don't pass weapon_ranges yet (tracked wiring follow-up). **DIV-0010** added. **E6** default-off Force data hook: new pure `scripts/rules/force_skills_model.gd` (static) declares WEG control/sense/alter at 0D, INACTIVE unless `sheet.force_sensitive` (default false); `can_use_force`/`force_skill_pool`/`initial_force_skills`; `chargen_model.build_sheet` now carries the `force_skills` hook (additive — `force_sensitive` stays false, `chargen_smoke` unaffected). NO power list / NO access-scarcity policy (owner-gated). **DIV-0011** added (Force access/scarcity = OPEN owner decision). 1 new smoke wired (`force_skills_model_smoke`); full gate GREEN (44 GDScript smokes + 7 python + import + launch).
- 2026-06-25 E2+E3 DONE (Wave E rules batch 3, ledger-first) — restored the WEG cumulative wound ladder + recovery, authored by the **d6-rules-engineer** subagent (sequential workflow: E2 then E3, adversarial review each). **E2** new pure `scripts/rules/wound_ladder_model.gd` (all `static func`): canonical WEG ladder (healthy/stunned/wounded/wounded_twice/incapacitated/mortally_wounded/dead), per-level penalty dice, `level_for_severity`, `penalty_dice_for_severity` (0,1,1,**2,2**,0 — the FIX vs the old silent 0D for sev≥3), and a TOTAL cumulative `escalate()` (wounded+wounded→incap, stun-on-wounded→wounded_twice, incap+any→mortally, mortally+any→dead, monotonic). `ground_combat_model._wound_penalty_dice` now delegates to it — **edit scoped to ONLY that body + the preload const** (maxi accumulation + wound_name_for_severity untouched), so `ground_combat_model_smoke`/`combat_arena_smoke`/`net_smoke` stay green. **DIV-0008** added. Wiring `escalate()` into live action-window accumulation is a tracked follow-up (would shift the seeded combat smokes). **E3** new pure `scripts/rules/recovery_model.gd` (static, RNG passed in): stun auto-expiry (2 rounds), First Aid/Medicine `heal_check` vs Guide_19 §3 difficulties (8/11/14/16/21, drops one level on success), Mortally-Wounded `death_roll` (2D < rounds → dead), post-death −1D debuff window. **DIV-0009** added for the recovery timing/roll approximations (death debuff 6 rounds vs 1 real-time hour; heal roll without the Wild Die). The E3 reviewer caught + fixed a real `:=`-on-preloaded-const-`.find()` parse trap (→ explicit `var idx: int`). 2 new smokes wired; full gate GREEN (43 GDScript smokes + 7 python + import + launch).
- 2026-06-25 E7+E8+E9 DONE (Wave E [PAR] batch 2) — three world-sim pure substrate models in `scripts/net/*`, authored concurrently via a Workflow (author→adversarial-review per slice, 6 agents), integrated serially + ONE full gate; all 3 smokes passed standalone first try (the batch-1 `:=`-on-untyped lesson was fed to the agents as an explicit warning). **E7** `scripts/net/security_gate.gd` (+smoke): pure `get_effective_security` implementing WORLD_SIM_DESIGN §3.2's 4-step precedence (room override REPLACE → citizen one-step upgrade captured as a safety FLOOR → claim lawless→contested → Director overlay hutt≥80 downgrade / republic_crackdown upgrade), floor enforced last via `more_secure`. Pure only — NOT wired into the live attack path (that stays for a [HOT] slice). **E8** `scripts/net/pending_influence_model.gd` (+smoke): non-mutating accrual of `world_hooks.pending_zone_influence` ({zone_id,axis,delta}) with add/fold_zone/clear_zone/fold_and_clear/apply_deltas (clamped 0–100); the player→world influence substrate for [HOT] E24. **E9** `scripts/net/org_model.gd` (+smoke): membership validation (one faction + ≤3 guilds, rank gates 3=claim/5=city) + `can_claim_command` composing rank + zone security + influence floor, REUSING `territory_model.CLAIMABLE_BASES`/`CLAIM_MIN_INFLUENCE` (one source of truth); substrate for [HOT] E23. 3 new smokes wired; full gate GREEN (41 GDScript smokes + 7 python + import + launch). No ledger rows (no divergences; E8/E9 axis enums match `zone_state` FACTIONS).
- 2026-06-25 E4+E10+E11+E12 DONE (Wave E [PAR] batch 1) — authored concurrently via a Workflow (author→adversarial-review per slice, 8 agents), each writing its own NEW files on the main tree; integrated serially + ONE full gate. **E4** `scripts/rules/derived_stats_model.gd` (+smoke): WEG derived stats — move_for_species (species.move, default 10), base_soak/strength_melee_bonus (STR pool), melee_damage_pool (STR + weapon STR-bonus, pip-vs-dice aware), stun_knockout_threshold (STR dice count). **E12** `scripts/rules/reputation_model.gd` (+smoke): per-character rep on 5 signed axes (republic/cis/hutt/independent/bounty_hunters_guild) in [-100,100], non-mutating apply_delta (unknown axis no-op), standing_tier (hostile/neutral/friendly/allied), serialize. **E10** `scripts/rules/creature_spawn_model.gd` (+smoke): consumes the orphaned creatures JSON — seed-driven deterministic roll_spawn + candidate_keys biased by zone alert/security (dangerous→hostile, calm→non-hostile). **E11** `scripts/rules/vendor_model.gd` (+smoke): consumes weapons/armor (vendor_stocked filter) + droid bargain tiers — list_stock, bargain_discount (3%/die, clamp 0.5), quote (Director multiplier × bargain), director_multiplier_for_event. 4 new smokes wired into check_project.ps1; full gate GREEN (38 GDScript smokes + 7 python + import + launch). NOTE: the gate caught two `:=`-on-untyped-`rules`/`model` parse errors the static reviewers missed (E4 model line, E12 test) — fixed to explicit `: Dictionary`. No ledger rows (none of these are divergences). NOTE for future wiring: E12 rep is multi-axis SIGNED while player_persistence.schema.json org.faction_rep is a single unsigned scalar — a mapping decision deferred to the [HOT] wiring slice.
- 2026-06-25 E1 DONE — docs-only reconcile (zero code touched). `MULTIPLAYER_FOUNDATION.md`: status header + Roadmap advanced (M1.3 DONE not "core/wiring next"; added M1.3b/M1.4/M1.5/M2.0–2.2/Wave C/Wave D, Wave E in-progress; Verified count → 34 smokes + 7 python). `NIGHTLY_HANDOFF.md`: deleted the self-contradicted "loop has STOPPED at Wave C" sentence (the same paragraph already records D1/D2/Wave E). `NEXT_DECISIONS.md`: ARCHIVED banner (its 3 questions long-resolved → Bay 94 / training-then-live targets / scripted one-way import). Stale "`--import` can fail on half-curated assets" caveat corrected in `UNATTENDED_LOOP.md` + this file's Guardrails (A0 colormap fix is live; full gate is the bar). Gate unaffected (markdown only) — baseline was green at HEAD 5ba15f0.
- 2026-06-25 AUDIT + WAVE E STOCKED — a 5-reader Workflow audit (rules/netcode/world-sim+data/tests/docs, ~560k tokens) mapped the whole prototype and produced the **Wave E** queue above (E1–E27): parallel-safe pure-model + test + docs slices `[PAR]` and serialized hot-file feature slices `[HOT]`. Also wrote `docs/SESSION_HANDOFF.md` as the clean-session entry point (parallelization playbook + re-arm-the-loop contract, since the CronCreate driver is session-only and dies on session switch). Owner-gated forks re-confirmed parked (siege tuning, Force/Jedi access policy, PvP-consent, LLM-Director-at-launch, death-PENALTY numbers, CP award-rate tuning, visual A1b/P1). Loop now: push all day, batch `[PAR]` via Workflow, serialize `[HOT]`, scoped commits, full gate + two-process bar.
- 2026-06-25 ASSET-PIPELINE NOTE (session 43c92aa7, the origin session A0 adopted) — Re-verified the full `check_project.ps1` GREEN on the current tree (import + 33 GDScript smokes + 7 python); A0's colormap-texture fix is live (796 texture PNGs under `assets/3d/`, incl. `GLB format/Textures/colormap.png`). Corrected `docs/ASSET_PIPELINE.md`: IP framing now matches [[mmo-direction]] #4 (private/fan project uses the SW setting/rules/names freely; only the *downloadable* art layer stays generic CC0) and the doc is session-agnostic per #5 (was framed as a "Codex handoff"). Added a new Claude memory `windows-tls-interception` documenting why `fetch_assets.py` relaxes `VERIFY_X509_STRICT` (HTTPS-scanning CA on this machine) — relevant to ANY future Python HTTPS here, not just assets. FYI: an earlier note of mine guessed the `--import` break was a half-curated `nature-kit`; that was WRONG — A0's root cause (external `colormap.png` dropped by GLB-only curate) is correct. (self-extended world-sim): `zone_state.gd` fires one deterministic event at a time per zone from a fixed 12-event menu (no LLM), `hash(tick:zone) % EVENT_CHANCE`, type chosen by dominant influence (republic/hutt/cis/neutral), exposed in `zone_summary` as `event`/`event_type`; client shows a NEWS HUD line + logs `[news] <headline>`. Added a `--director-tick` server override for fast headless verification. zone_state_smoke extended (fires <40 ticks, valid type, deterministic). Verified over the wire: a client received neutral Tatooine headlines (sandstorm/distress/krayt/trade-boom). Full gate green (37 smokes). Next self-extended: D3 inventory/equipment swap, or org/claim command layer + guard NPCs.
- 2026-06-25 LOOP RESUMED — owner chose Wave D (combat uses the character sheet). Next: D1. Now driven by a recurring CronCreate timer (job, every ~10 min) instead of manual /loop; no owner questions.
- 2026-06-25 D2 DONE — combat uses equipped gear: chargen sheets carry starter `equipment {weapon: blaster_pistol, armor: blast_vest}`; combat_arena takes weapon/armor catalogs and sets each player's damage_pool from the equipped weapon + player_armor from the equipped armor (defaults when absent); NetworkManager loads weapons_clone_wars.json + armor_clone_wars.json and passes them in. chargen_smoke + combat_arena_smoke extended (equipped heavy_blaster -> 5D damage; no-equipment -> default). Full gate green (37 smokes). Next self-extended: D3 inventory/equipment swap, or org/claim command layer.
- 2026-06-25 D1 DONE — `combat_arena.gd` now builds each player's combat pools from their character sheet (attacker = DEX + blaster bonus, dodge = DEX + dodge bonus, soak = STR; damage = a default starter blaster until inventory exists; target side stays shared). `register_player`/`set_player_sheet` accept a sheet (no sheet = trainee fallback, backward-compatible). NetworkManager applies the sheet on login and re-applies on a skill raise (raise takes effect in combat immediately). `combat_arena_smoke` extended. Verified over the wire: a new quickstart char fought with attack pool DEX 3D and raising blaster grew it to 3D+1. Full gate green (37 smokes). KNOWN follow-up: damage uses a default weapon until an inventory/equipment system exists.
- 2026-06-24 LOOP RESUMED — owner chose Wave C (Character Creation & Progression). Next: C1.
- 2026-06-24 C4 DONE — wired CP earn/spend: disabling the shared target awards gameplay CP (`_award_cp` -> the character's persisted `sheet.cp_wallet`, COMBAT_CP_REWARD=3, tunable); `submit_skill_raise(skill)` RPC validates via progression_model against the char's wallet + governing attribute (from the skill catalog) + current bonus, applies the new bonus to the sheet, persists, and replies; server pushes the wallet via `apply_wallet`. Client shows a CP HUD + `K` raises Blaster (+`--raise-skill` headless). Verified over the wire: a new quickstart char earned CP from kills and raised `blaster 0D -> 0D+1 (cost 3)`, persisted. Full gate green (37 smokes). **WAVE C COMPLETE.**
- 2026-06-24 LOOP STOP (Wave C complete) — backlog dry of unblocked, non-owner-decision, non-visual items. Remaining needs the owner: visual check (A1b/P1) + design calls (siege/Drop-6D tuning, Force/Jedi access, PvP-consent, LLM-Director-at-launch). Handed back.
- 2026-06-24 C3 DONE — pure `scripts/rules/progression_model.gd` (WEG R&E / Guide_09): skill_raise_cost = total-pool dice (attribute + skill bonus), cost steps up at die boundaries, optional guild discount; DIV-0007 dual-track wallet {gameplay_cp, rp_cp} with `raise_skill` (adds a pip to the bonus, spends gameplay-first then RP, rejects if short) + `award`. `progression_smoke` (cost table, dual-track spend, boundary step-up, insufficient-CP rejection). Full gate green (37 smokes). Next: C4 wires CP earn (combat) + a spend RPC + persist.
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
