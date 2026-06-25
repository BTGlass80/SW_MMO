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

### E13 — Director event mechanical effects + event→influence nudges  [STATUS: DONE] [PAR*] [world-sim] [M] (*edits zone_state.gd — serialize with E2-route/other zone edits)
In `zone_state.gd`: a pure, owner-tunable `EVENT_EFFECTS` table mapping each of the 12
event types to bounded modifiers (smuggling/vendor/spawn/perception) surfaced in
`zone_summary`, plus the documented per-tick active-event influence nudges (crackdown →
republic +1/tick, cis_propaganda → cis +1/tick, pirate/auction → hutt +1/tick), clamped,
deterministic. Closes the documented causal loop (events were flavor-only).
- Acceptance: `zone_state_smoke` extended (effect lookups + clamped nudges, deterministic); full gate green; no 20 Hz-path change.

### E14 — Data-drive world_builder set-dressing  [STATUS: DONE] [PAR] [world-sim] [S]
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

### E21 — Seed multiple zones + snapshot routing  [STATUS: DONE] [HOT] [netcode] [M]
Add `data/zones_clone_wars.json` (spaceport secured, port-fringe contested, dune-sea
lawless, …); replace the single hardcoded `add_zone` in `start_server` with a data loop
that ticks ALL zones; give each player a `current_zone_id`; `_build_snapshot` emits that
player's zone summary. Precondition for territory claims (needs a contested/lawless zone)
and ambient sim. Add `zones_smoke`.
- Acceptance: N zones server-side with distinct bases; player snapshot reflects their zone; full gate green; two-process check shows a contested/lawless zone available.

### E22 — Inventory / equipment-swap RPC (D3)  [STATUS: DONE] [HOT] [netcode] [M]
`submit_equip(slot, item_key)` [any_peer, reliable]: validate item in the loaded
weapon/armor catalog + ownership (simple inventory list on the sheet), write
`sheet.equipment`, persist, `arena.set_player_sheet`, reply. Completes the half-wired
equip path (read path already exists). Add `equip_smoke`.
- Acceptance: invalid/unowned rejected; valid swap changes the damage/armor pool and survives save+reload; full gate green; two-process check.

### E23 — Org claim/release command RPCs  [STATUS: DONE] [HOT] [netcode] [M] (depends E9; E21 helps)
Wire the instantiated Territory into the RPC surface: `submit_claim_node` /
`submit_release_claim` validated via the E9 org-model + zone security; fold a compact
territory summary into the snapshot/reply so the 60s resource tick stops being a no-op.
Excludes the owner-gated siege loop.
- Acceptance: claim a contested/lawless node → treasury credited next resource tick; secured/already-claimed rejected; full gate green; two-process check.

### E24 — Player actions feed zone influence  [STATUS: DONE] [HOT] [netcode] [M] (depends E8)
On combat target-disable (and/or periodic presence), call
`zones.apply_influence_delta(zone, axis, delta)` via the E8 pending-influence model so
player activity shifts faction influence and the derived alert/security visibly move.
- Acceptance: after N disables, influence on the chosen axis changes and at threshold the alert tier flips; snapshot reflects it; full gate green.

### E25 — Chat / emote RPC for RP  [STATUS: DONE] [HOT] [netcode] [M]
Pure `scripts/net/chat_model.gd` (validate/normalize: strip control chars, clamp length,
channel whitelist say/emote/ooc) + `submit_chat`/`apply_chat` broadcast RPCs + a HUD
last-N-lines panel. First real social/RP channel on the wire.
- Acceptance: `chat_model_smoke` green; a line round-trips to all peers in a two-process run; full gate green.

### E26 — Account auth/ownership guard + rate-limit + cache  [STATUS: DONE] [HOT] [netcode] [M]
Close the identity-spoofing gap: bind a peer to an account via a server-side
`account_secret` in the record (first claim sets it; wrong secret rejected); add
per-peer reliable-RPC rate limiting + an in-memory record cache (kill the
load+rewrite-per-call I/O in `submit_skill_raise`). Add `account_auth_smoke`.
- Acceptance: wrong-secret peer can't load/overwrite an existing character; correct secret loads; skill-raise no longer re-reads JSON each call; full gate green.

### E27 — Ambient NPC sim model + snapshot  [STATUS: DONE] [HOT] [netcode] [L] (depends E21; E10 helps)
Pure `scripts/net/ambient_sim_model.gd` advanced by the Director tick: deterministically
spawn/despawn a small NPC roster keyed to zone event/alert (positions in bounds, hash-
seeded like zone_state), folded into the snapshot as `npcs[]` so clients can render them.
The spawn/sim foundation beyond headline-only events.
- Acceptance: `ambient_sim_model_smoke` green (deterministic count by alert, in-bounds, despawn on expiry); snapshot carries `npcs`; full gate green.

## Log
(iterations append here: `- <date> <ITEM> DONE <hash> — <note>` or `BLOCKED — <why>`)
- 2026-06-25 WAVE-E FOLLOW-UP F20 (org chat channel) [HOT] — added a faction-coordination chat channel that leverages the org system (F12). chat extended (E25/F2): `ooc`=galaxy-wide, `say`/`emote`=zone-local, and now `org`=all CONNECTED same-org members in ANY zone (cross-zone faction comms). `chat_model` whitelists `org` + formats it `[Org] Name: text` (pure, static); `submit_chat` routes `org` to peers whose `_peer_orgs[pid]` matches the sender's org (mirrors F2's zone routing but keyed on org), rejecting a sender with no org (`org-chat with no org — not delivered`). No client change — the existing `--chat <channel:text>` affordance + the shared `format_line` cover it. Standard MMO channel scoping — NOT a WEG/MUSH mechanic divergence (same as F2), not ledger-flagged. `chat_model_smoke` extended (org whitelisted + `[Org]` format). Full gate GREEN (58 GDScript smokes + 7 python + import + launch). **Two-process PASSED (3 clients):** an org message from a hutt member in the spaceport reached a fellow hutt member in the DUNE_SEA (different zone → `[chat] [Org] …: regroup94`) but did NOT reach a no-org player in the SAME zone as the sender — org-scoped, cross-zone, members-only.
- 2026-06-25 WAVE-E FOLLOW-UP F19 (First Aid targets the nearest wounded ally) [HOT, client-only] — closed the medical loop's last usability gap. The H key / `--heal-other` picked the FIRST other player (`_first_other_peer`), which is often healthy → a wasted `no_wound` rejection. Now `_best_heal_target()` scans the snapshot's player entries (which carry `wound` from F17 + `pos` from F13, and are already same-zone via F13) and returns the NEAREST player whose wound is non-healthy (0 if none); the H key and the headless `--heal-other` both use it (H now says "no wounded ally nearby" when none). So a medic reliably heals whoever's hurt + closest instead of a random/healthy bystander. Pure client presentation/targeting, no server change (not ledger-flagged). Full gate GREEN (58 GDScript smokes + 7 python + import + launch). **Two-process PASSED (3 clients):** with a WOUNDED ally (`f19ally`) AND a HEALTHY bystander (`f19by`) both in range, the medic's First Aid correctly targeted the wounded ally — `[firstaid] peer … -> peer … (f19ally): wounded -> stunned` (a no_wound pick of the bystander would have produced NO [firstaid] log). Completes the medical loop: F8 heal + F9 own-condition + F17 see-others + F19 target-the-wounded.
- 2026-06-25 WAVE-E FOLLOW-UP F18 (melee-weapon combat pools fix; wire derived-stats melee) — fixed a latent combat bug + wired the orphaned `derived_stats_model.melee_damage_pool`. Two issues in `combat_arena._pools_from_sheet`: (1) the attack pool ALWAYS used the `blaster` skill, ignoring the equipped weapon's real skill (`melee_combat`/`bowcaster`/…); (2) melee weapons encode damage as `STR+ND` (knife STR+1D … vibroaxe STR+3D+1, 8 in the catalog) but `parse_pool("STR+3D")` returns **0D** (`int("STR+3")==0`), so a melee-armed player dealt ZERO damage. Now the attack pool uses the equipped weapon's OWN skill (`DEX + skills[weapon.skill]`, untrained → just DEX) and a `STR+`-prefixed damage resolves as `STR + bonus` via the now-wired `derived_stats.melee_damage_pool`; ranged weapons (flat pool) are unchanged. Pure-model fix (combat_arena is pure net logic with a smoke); NO net-wiring change. NOT ledger-flagged — a correctness fix, and for currently-reachable play (the blaster starter, skill=blaster) behavior is IDENTICAL. **KNOWN:** melee weapons aren't yet ACQUIRABLE — `equipment_model` gates equip to OWNED items and a quickstart only owns its blaster/vest, so the fix is latent-but-correct until an inventory/acquisition (vendor/economy, owner-gated) path exists. `combat_arena_smoke` extended (melee vibroblade: STR 2D + 3D = 5D damage; attack = DEX 3D + melee_combat 1D = 4D, not blaster). Full gate GREEN (58 GDScript smokes + 7 python + import + launch). **Two-process:** equip(vibroblade) is correctly rejected `not_owned` (ownership gate); a no-regression autofire run confirmed the live RANGED path still resolves (8 hits, blaster unchanged).
- 2026-06-25 WAVE-E FOLLOW-UP F17 (other players' condition on nameplates) [HOT] — closed a medical-loop usability gap: First Aid (F8) lets you heal an ally and F9 shows your OWN condition, but the snapshot's player entries carried no wound (only the per-peer `you` block did), so you couldn't SEE who's hurt — a medic healed blindly. Server `_build_snapshot` now enriches each (zone-filtered) player entry with its live `wound` (from `arena.player_state(pid).player_wound_severity`, fresh dicts so safe); the client shows it on each REMOTE player's nameplate — healthy → just the name; wounded → "Name — Condition" tinted by severity (reuses the F9 colours) — and logs `[nameplate] <name> is <Condition>` on change. Now a medic can identify the wounded ally to target. Pure presentation surfaced from existing live state — no new mechanic (not ledger-flagged); the pure WorldState.snapshot() is untouched (enrichment is network_manager-side, so wire/snapshot smokes unaffected). Full gate GREEN (58 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** an observer ("Medic") saw a `--start-wound wounded` ally's nameplate as `[nameplate] Wounded-Ally is Wounded` — other players' conditions are now visible. Completes the medical loop's usability (F8 heal + F9 own + F17 see-others).
- 2026-06-25 WAVE-E FOLLOW-UP F16 (render ambient NPCs) [HOT, client-only] — made E27's ambient sim VISIBLE (the F9/F12 pattern): the server simulates + broadcasts a per-zone NPC roster (`snapshot.npcs` = {id, kind, pos}), but the client only COUNTED them — the world looked empty. `net_world` now renders each ambient NPC as a muted, desaturated capsule marker (distinct from the saturated player avatars) with a kind label, reconciled each snapshot (`_reconcile_npcs`: spawn new, lerp existing, free despawned). Because the roster is per-zone, the markers naturally swap when the player travels (F11/DIV-0014). Logs `[npc] showing N` on count change. Pure presentation, client-only (NO server change — the data already existed; not ledger-flagged). Full gate GREEN (58 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** with a short Director tick the server populated the spaceport (`[ambient] tick 1 … spaceport: 4`) and the client rendered them (`[npc] showing 0` → `[npc] showing 4 ambient NPC(s)`) — the world is now populated, NPCs visible.
- 2026-06-25 WAVE-E FOLLOW-UP F15 (per-species movement speed) [HOT] — wired the built-but-ORPHANED `derived_stats_model` (no net-layer reference existed): `world_state` moved ALL players at one fixed `MOVE_SPEED=6.5`, ignoring each species' WEG Move rate (wookiee 11 / mon_calamari 9 / others 10). **Documented DIV-0015 BEFORE coding.** `world_state` now carries a per-player `move_speed` (default = the 6.5 baseline, so existing feel/tests are untouched) + `set_move_speed()`, and `tick()` integrates each player's own speed. At login the server computes `MOVE_SPEED × species_move / DerivedStats.DEFAULT_MOVE` via the now-wired `derived_stats_model.move_for_species` and sets it server-authoritatively. Pure/presentation split honored (movement truth stays in the pure `world_state`; the speed comes from the pure `derived_stats_model`; `network_manager` only wires them). Movement is server-owned (clients follow snapshots, no client-side speed) so no client change is needed. `net_smoke` extended to lock the effect (a 1.1× player out-travels the baseline in equal time; baseline unchanged). Full gate GREEN (58 GDScript smokes + 7 python + import + launch). **Two-process PASSED (3 species):** server assigned `wookiee move=11 speed=7.15`, `human move=10 speed=6.50`, `mon_calamari move=9 speed=5.85` — species now mechanically distinct for movement. Divergence: DIV-0015 (m/round→real-time ratio-to-baseline; absolute base 6.5 unchanged).
- 2026-06-25 WAVE-E FOLLOW-UP F14 (zone subsystem regression guard) — added `scripts/tests/zone_flow_smoke.gd`, a headless gate guard for the zone subsystem's network_manager COMPOSITION (F11 travel/DIV-0014 + F13 visibility), previously only two-process verified. Following the claim_flow/auth_flow/heal_flow pattern, it replicates the three zone wirings and locks: (1) `submit_change_zone` precedence `unregistered → unknown_zone → already_here → travel` (on travel: updates the peer zone AND persists `record.zone`); (2) register zone resolution — explicit `build.zone` wins, else fall back to the persisted `record.zone`, an invalid zone is ignored (keeps current); (3) the F13 same-zone player filter — a viewer sees only same-zone players (incl. itself), never cross-zone. Test-only; full gate GREEN (58 GDScript smokes + 7 python + import + launch). Not ledger-flagged. With F14 all four current [HOT] composition chains (claims F3, auth F4, First Aid F10, zone F14) are gate-guarded, not just two-process verified; F14 also locks the F11 persistence-restore + F13 visibility invariants.
- 2026-06-25 WAVE-E FOLLOW-UP F13 (zone-scoped player visibility) [HOT] — completed the zone model: the per-peer snapshot's PLAYER LIST was still GLOBAL, so a player in the dune_sea saw avatars of players in the spaceport (different conceptual places that share the prototype's one Mos Eisley geometry) — inconsistent with zone-scoped chat (F2) + travel (F11). `_build_snapshot` now FILTERS the player list to same-zone peers (`_peer_zones[pid] == zone_id`); the viewer's own entry is always kept (it's in its own zone — needed for the first-person camera). Safe because `state.snapshot()` returns a fresh dict + fresh entries per call (verified), so per-peer mutation can't corrupt other peers' snapshots. The client's existing avatar reconciliation now makes a traveler's capsule appear/vanish for others as they enter/leave the zone; status reads "players in zone" and logs `[presence] players_here=N` on change. Standard MMO zone visibility — NOT a WEG mechanic divergence (same reasoning as F2; consistent with DIV-0001), not ledger-flagged. Full gate GREEN (57 GDScript smokes + 7 python + import + launch; world_state.snapshot() untouched). **Two-process PASSED (3 clients):** A+C in the spaceport each saw `players_here=2` while B alone in the dune_sea saw `players_here=1` — cross-zone players are invisible, same-zone players see each other (without the filter all three would see 3).
- 2026-06-25 WAVE-E FOLLOW-UP F12 (org / territory HUD readout) [HOT, client-only] — made the org/territory system VISIBLE (the F9 pattern): the per-peer `snapshot.territory` block (E23: org_id + treasury + claims_in_zone) was already broadcast but the client only ever read it inside the claim-RESULT handler — an org member could NOT see their org, treasury, or holdings. `net_world` now shows an "Org: <name> · <treasury> cr · <N> claim(s) here" HUD that updates each snapshot (blank for a no-org player) and logs `[org] …` on change. Because the territory block is zone-scoped (`claims_in_zone`), the readout tracks F11 travel (you see your org's holdings in whatever zone you're standing in). Pure presentation, client-only (NO server change — the data already existed; not ledger-flagged). Full gate GREEN (57 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** a hutt-org player in the lawless dune_sea saw `[org] org_hutt_cartel treasury=0 claims_here=0`, claimed node n1 (`[territory] claimed n1 … tier foothold`), and the HUD updated to `[org] org_hutt_cartel treasury=0 claims_here=1` — org standing now live-visible.
- 2026-06-25 WAVE-E FOLLOW-UP F11 (inter-zone travel) [HOT] — unlocked the multi-zone world: `_peer_zones` was only ever set at connect/register, so a player was LOCKED to their login zone — the whole per-zone stack (snapshot routing, zone-scoped chat F2, ambient E27, territory view) was only reachable by reconnecting with `--zone`. **Documented DIV-0014 BEFORE coding.** New `submit_change_zone(zone_id)` RPC: validates the zone is loaded (`unknown_zone`/`already_here` rejected), updates `_peer_zones[sender]` (so snapshot/chat/ambient/territory all follow), PERSISTS `record.zone` (restored on next login — register now falls back to the saved zone when no `--zone` is given), and replies `zone_result`. Command fast-travel to any loaded zone (no adjacency/route/cost yet — DIV-0014). Snapshot now carries a cached `zone_list` ([{id,name}], static); client gets a `T` key (cycle-travel through loaded zones), a `--travel <zone_id>` headless affordance, `zone_replied` handling, and logs `[zone] now in <name>` when the snapshot zone changes. Pure/presentation split honored (no pure-model change; zone_state untouched). Full gate GREEN (57 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** a client traveled spaceport→dune_sea and its SNAPSHOT zone followed — `[zone] now in Mos Eisley Spaceport District (secured)` → `[zone] now in The Dune Sea (lawless)` (server `[zone] peer … traveled to tatooine.dune_sea`). Zone persistence is wired (record.zone save + register restore) via the same `_cached_save`/load path. Divergence: DIV-0014 (command fast-travel vs MUSH spatial exits; extends DIV-0001).
- 2026-06-25 WAVE-E FOLLOW-UP F10 (First-Aid precedence regression guard) — added `scripts/tests/heal_flow_smoke.gd`, a headless gate guard for the `submit_heal` COMPOSITION PRECEDENCE (DIV-0013 / F8) that was previously only two-process verified. Following the claim_flow/auth_flow replicate-the-wiring pattern, it composes the REAL `recovery_model` and locks the order `self → no_target → out_of_range → no_wound → beyond_help → already_treated → heal`, asserting: self-target precedes any wound check; an out-of-zone (even healthy) target is `out_of_range` before the wound tier; `no_wound`/`beyond_help` precede the retry gate; a big pool walks the ladder down (`wounded → stunned → healthy`, re-heal allowed once the level CHANGES) then `no_wound`; and a FAILED roll trips the per-target retry gate (`already_treated`, no spam-to-success). Deterministic via fixed/extreme pools (20D always clears ≤incap difficulty, 0D always fails) + a seeded RNG. Test-only; full gate GREEN (57 GDScript smokes + 7 python + import + launch). Not ledger-flagged. With F10, all three [HOT] validation-precedence chains (claims F3, auth F4, First Aid F10) are now gate-guarded, not just two-process verified.
- 2026-06-25 WAVE-E FOLLOW-UP F9 (player condition / wound readout) [HOT] — made the F7/F8 wound system VISIBLE: it was fully functional server-side but a player had NO way to see their own wound (the snapshot didn't carry it; only TARGET wounds showed, via combat envelopes). `_build_snapshot` now folds a per-peer `you = {wound}` block (the player's OWN live `player_wound_severity` from the combat arena, mapped to a label) into each per-peer snapshot — pure presentation data surfaced from existing live state, NO new mechanic (not ledger-flagged). Client shows a colour-coded "Condition: …" HUD label (green healthy → amber wounded → red incapacitated/mortally) that updates as the server changes the wound (combat damage, natural recovery DIV-0012, First Aid DIV-0013) and logs `[condition] you=<level>` on change. Pure/presentation split honored (server emits data; client renders). Full gate GREEN (56 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** a `--start-wound wounded` client's condition readout flowed `you=wounded -> you=stunned -> you=healthy` as natural recovery healed it — the wound is now live-visible to the player.
- 2026-06-25 WAVE-E FOLLOW-UP F8 (First Aid — a medic heals a wounded ally) [HOT] — extends F7 with the Guide_19 §3 medical-aid path (the follow-up F7 flagged). **Documented DIV-0013 BEFORE coding.** New `submit_heal(target_id)` RPC: a healer First-Aids another CONNECTED player in the SAME zone (never self); heal pool = the healer's Technical attribute + `first_aid` skill, rolled via `Recovery.heal_check` vs the target's wound-level difficulty (server-owned `_server_rng`); on success the target's wound drops one level, is persisted, and refreshes ONLY the target's live combat penalty (`set_player_combat` merges just `player_wound_severity`). UNLIKE natural self-recovery (DIV-0012) it CAN treat `incapacitated` + stabilize `mortally_wounded`; `healthy`→no_wound, `dead`→beyond_help rejected; NO death roll/penalty (owner-gated DIV-0006, untouched). A per-target retry gate (`_heal_treated`, cleaned on disconnect per the F6 lesson) blocks re-treating the same wound LEVEL until it changes — no spam-to-success. Introduces the first COOPERATIVE player-targeting (heal, not PvP — so non-owner-gated). Client: `heal_replied` signal, an `H` key (First-Aid the first other player in the snapshot), `_first_other_peer()` (reads `last_snapshot.players` for an id≠self), and a `--heal-other` headless affordance. Pure/presentation split honored (WEG math stays in `recovery_model`). Full gate GREEN (56 GDScript smokes + 7 python + import + launch). **Two-process PASSED (2 clients):** a medic (`fa_medic1`) First-Aided a stunned ally (`fa_ally1`) over the wire — `[firstaid] … stunned -> healthy (First Aid 3D rolled 15 vs 8)` server-side + the medic's client got the `heal_result`. Divergence: DIV-0013 (per-target retry-gate approximation of WEG per-healer; straight pool sum per DIV-0009).
- 2026-06-25 WAVE-E FOLLOW-UP F7 (wire natural wound recovery into the live loop) [HOT] — closed the persistent wound→recovery loop: the Wave-E `recovery_model` (DIV-0009) existed with a smoke but was NEVER referenced in the net layer, so a wounded character stayed wounded FOREVER (the persisted `sheet.wound_state` only ever escalated). **Documented DIV-0012 BEFORE coding.** `network_manager` now runs `_recover_wounds()` once per Director tick (= one recovery interval; server-owned `_server_rng`): each CONNECTED character whose persisted wound is a "can still act" tier (stunned/wounded/wounded_twice) makes a NATURAL self-recovery `Recovery.heal_check` with their OWN Strength pool vs the Guide_19 §3 difficulty (8/11/14); on success the wound drops exactly one level, is persisted via `_cached_save`, and refreshes ONLY the live combat penalty (`set_player_combat({player_wound_severity})` merges just that field, so depleted CP/FP are untouched). incapacitated/mortally_wounded/dead are EXCLUDED (need First Aid/Medicine by another — a later slice — and the lethal tiers are owner-gated death, DIV-0006); no death roll is auto-run. Added a `--start-wound <tier>` headless test affordance (new chars seed a recoverable wound via the build dict → `_create_character`). Pure/presentation split honored (all WEG math stays in the pure `recovery_model`; network_manager only schedules + persists). Full gate GREEN (56 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** a new `woundrec1` (Strength 3D) started `wounded` and the server healed it `wounded -> stunned (rolled 11 vs 11)` then `stunned -> healthy (rolled 9 vs 8)` over recovery ticks — natural recovery resolving server-authoritatively. Divergence: DIV-0012 (live wiring of DIV-0009; heal-pool = own Strength + the ~30s interval are documented approximations, NOT owner balance rulings).
- 2026-06-25 WAVE-E FOLLOW-UP F6 (evict the record cache on disconnect) [HOT] — fixed the unbounded-`_record_cache` leak the E26 Log flagged as a known follow-up. `_on_peer_disconnected` cleaned the five per-peer (int-keyed) maps but NEVER evicted the character-id-keyed `_record_cache`, so on a long-running persistent server every character that ever logged in stayed cached for the server's lifetime, and a record outlived the session that owned it (latent stale-cache risk). Fix: capture `character_id` before the per-peer map erase, then `_record_cache.erase(character_id)` AFTER `_save_peer` has flushed final state to disk — safe because the single-session lock means no other peer holds the character and the next login does a fresh read-through. Bounds the cache to currently-connected players. Logs `[cache] evicted <id> on disconnect (cache size=N)` only on a real eviction (`Dictionary.erase` returns bool). The zone/faction-keyed `_territory_influence`/`_pending_zone_influence`/`_ambient` are intentionally persistent and correctly NOT touched. No new pure model/smoke (network_manager is a Node autoload, not headlessly instantiable; verified two-process like the other [HOT] state-lifecycle work). Not ledger-flagged (robustness, no mechanic). Full gate GREEN (56 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** a `leaktest` client registered (`[persist] … -> leaktest`, cache populated), was hard-killed, and the server (after the ENet peer timeout) logged `[cache] evicted leaktest on disconnect (cache size=0)` + `[net] peer … left (players=0)` — the cache emptied on disconnect.
- 2026-06-25 WAVE-E FOLLOW-UP F5 (expose in-play CP/FP spend on the client) [HOT] — connected an already-built, gate-tested, server-validated WEG combat mechanic that players literally could not reach: the client ALWAYS sent `cp:0, fp:false` on every fire intent, so a player could never spend a Character Point (+1D each) or burn a Force Point (double all dice) in combat. `net_world.gd` now stages them for the NEXT shot — **C** cycles 0..5 CP, **F** toggles a Force Point (HUD/status + controls line updated), sent on LMB fire and reset after; headless `--fire-cp N` / `--fire-fp` affordances stage them on the autofire path; and the combat log surfaces the actual spend per shot (`[+NCP]` / `[Force Point]`, read from the envelope's `attack_cp_spent`/`force_point_spent`). Server-only change is ZERO — `combat_arena.submit_fire_intent` already clamped cp 0-5 + bool fp and `ground_combat_model` already resolved them (`queue_attack_cp`/`activate_force_point`, FP doubles pools, both consumed from the per-player pool). No new pure model, no new smoke (the resolution is covered by `ground_combat_model_smoke`/`combat_arena_smoke`; net_world is a scene controller, verified two-process like the other client affordances). NOT ledger-flagged — exposes existing faithful WEG rules, introduces no mechanic/divergence. Full gate GREEN (56 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** an autofire client with `--fire-cp 2 --fire-fp` logged `… → Wounded [+2CP]` (CP 5→3), `[+2CP]` (3→1), `[+1CP]` (server clamped the requested 2 to the 1 left → 0), then `[Force Point]` (FP 1→0), then plain shots once both pools were exhausted — demonstrating client-staged spend resolving server-authoritatively with pool depletion + clamping. (Observed: the model spends CP first and reserves the Force Point until CP is gone — CP and an active FP don't stack per `_queue_cp`; pre-existing `ground_combat_model` behavior, untouched here.)
- 2026-06-25 WAVE-E FOLLOW-UP F4 (register-account regression guard) — added `scripts/tests/auth_flow_smoke.gd`, a headless gate guard for the `register_account` COMPOSITION PRECEDENCE (E26 + the post-Wave-E hardening) that was previously only two-process verified — the exact wiring where adversarial review found 2 MEDIUM latent bugs. Following the claim_flow/E15-E20 replicate-the-wiring pattern, it composes the REAL `AccountAuthModel` and locks the order `rate-limit → auth(secret) → single-session lock → bind → org set/CLEAR`, asserting: fresh-unsecured claim binds the secret; a wrong secret is denied `bad_secret` and never binds the peer; **auth precedes the lock** (a wrong secret + a session conflict reports `bad_secret`, not `already_logged_in`); **BUG #2** the single-session lock denies a second peer on an owned char `already_logged_in` while allowing a different char + the SAME peer re-binding its own; **BUG #1** a peer re-registering from an org char to a no-org char CLEARS `_peer_orgs`/`_peer_axes` (no stale faction) and returning to the org char re-sets them; and a drained token bucket is `rate_limited` before auth/bind. Test-only; full gate GREEN (56 GDScript smokes + 7 python + import + launch). Not ledger-flagged. With F4, the two confirmed hardening fixes are now gate-guarded, not just two-process verified.
- 2026-06-25 DOC RECONCILIATION (handoff truth-up, zero-risk) — with the backlog dry, brought the clean-session entry docs in line with the shipped state so the next session orients correctly. `docs/SESSION_HANDOFF.md`: §0 TL;DR now states Wave E (E1–E27) + hardening + F1/F2/F3 COMPLETE, gate at **55 GDScript smokes** (was "34"), DIV-0001..0011, and an explicit **"backlog DRY → needs an owner steer; confirm green and HOLD"** status; §1 first-actions step 4/5 reflect Wave E done + the hold-if-dry rule (was "pick the top Wave E batch / E1 opener"); §7 RPC surface corrected **8 → 16** (8 client→server `any_peer` + 8 server→client `authority`, enumerated), the net-layer/key-files map gains the Wave E pure models + the claim command layer + per-peer state, and the data line now states creatures/vendor/reputation are **modeled+smoked but not yet wired into `net_world`** (economy/spawn-rate/value = owner calls) while starships/droids stay latent. `docs/MULTIPLAYER_FOUNDATION.md`: header + roadmap "Wave E — IN PROGRESS" → DONE (full E-tier summary, RPC 8→16, the 2 register_account fixes, the modeled-not-wired caveat) + a "backlog dry / owner-gated next" status line. Docs-only (the gate never parses markdown); full gate re-run GREEN (55 GDScript smokes + 7 python + import + launch) to confirm the tree is still green. Not ledger-flagged.
- 2026-06-25 WAVE-E FOLLOW-UP F3 (claim-flow regression guard) — added `scripts/tests/claim_flow_smoke.gd`, a headless gate guard for the `submit_claim_node` validation PRECEDENCE (E23 + the int-coercion fix) that was previously only two-process verified. Following the E15-E20 pattern, it composes the REAL `OrgModel` + `TerritoryModel` exactly as the RPC does and locks the reason ordering: no_org → membership/rank → secured_zone → influence → node_unavailable (+ rank-before-secured precedence, valid claim, contested-zone claimable). Test-only; full gate GREEN (55 GDScript smokes + 7 python + import + launch). Not ledger-flagged.
- 2026-06-25 WAVE-E FOLLOW-UP F2 (zone-scoped say) — completed the documented E25 follow-up: `submit_chat` now delivers `say`/`emote` ONLY to peers in the speaker's current zone (`_peer_zones`-keyed per-peer `apply_chat.rpc_id`, incl. the sender), while `ooc` stays a galaxy-wide broadcast — standard MMO proximity chat. Delivery-only change (the pure `chat_model` + its smoke are untouched; message shape unchanged). Full gate GREEN (54 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** a spaceport player's `say` did NOT reach a dune_sea player (different zone), while a dune_sea player's `ooc` reached the spaceport player (global); each speaker received their own local line. Not ledger-flagged (standard chat scoping, not a WEG/MUSH divergence).
- 2026-06-25 WAVE-E FOLLOW-UP F1 (territory-influence accrual from combat) — completed the documented E23 follow-up so org territory claims are EARNABLE through play, not test-seeded. On a combat target-disable (the same hook as E24's Director-influence accrual), a shooter WITH an org now earns `KILL_TERRITORY_INFLUENCE = 2` (FACTION_TERRITORY_DESIGN §2's documented kill-in-zone value) into their org's `_territory_influence` for their current zone via the new `_accrue_territory_influence`. This closes the persistent-world loop end-to-end: play (kills in a zone) → org territory influence → claim a node at the influence floor (E23) → treasury income on the resource tick (E23). No new owner decision (fixed documented value); no new pure model (reuses the E23 helpers + territory_model). Full gate GREEN (54 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** an autofire republic-org player in the lawless dune_sea had an early claim denied `(influence)` (rank ok, not yet earned), then kills accrued org territory influence 6→12→18→24 (past the CLAIM_MIN_INFLUENCE=20 floor → now claimable). Not ledger-flagged. KNOWN follow-ups still open: presence/mission/PvP territory-influence sources (the hourly-presence rate needs an owner timescale call), vendor-purchase item acquisition, zone-scoped say.
- 2026-06-25 POST-WAVE-E HARDENING (review-driven) — with the defined backlog dry, ran a 4-dimension adversarial code review (Workflow, 8 agents: state/cache lifecycle, RPC correctness, security/validation, determinism/snapshot) over the Wave E [HOT] netcode. The 6 determinism findings were all correctly REJECTED (GDScript Dictionary iteration is insertion-ordered + the sim ops are order-independent + RNG is seeded), as was a name-persistence false positive. **2 MEDIUM latent bugs CONFIRMED + FIXED in `register_account` (both invisible to the stock once-per-session client, hence missed by the gate/two-process — they bite a re-registering or duplicate client):** (1) `_peer_orgs`/`_peer_axes` were only SET when the loaded record had an org, never CLEARED — a same-session re-register from an org-character to a no-org one left a stale org_id/axis, mis-reporting another org's treasury in the snapshot + accruing Director influence to the wrong faction; fixed with an `else` that erases both (matching the "always refresh" comment). (2) no single-session lock — two authorized peers (same correct secret) could bind one character → last-writer-wins save clobbering + a shared mutable cached record; fixed by rejecting the bind (`already_logged_in`) when another connected peer already owns the character. Full gate GREEN (54 smokes); two-process verified the single-session lock (first session loads, a concurrent second on the same account is denied `already_logged_in`). Not ledger-flagged.
- 2026-06-25 **WAVE E COMPLETE (E1–E27 all DONE).** The full breadth-first Wave E queue is shipped: E1 (docs) + E2–E20 + E13/E14 ([PAR]/[PAR*] pure-model + test substrate) + E21–E27 (the [HOT] netcode tier, each two-process verified). DIV-0008..0011 added. The gate grew 34 → 54 GDScript smokes and was GREEN at every commit. The persistent player-driven MMO loop is now live end-to-end: chargen + dual-track CP + WEG wound ladder/recovery + per-weapon range bands + an off-by-default Force hook; multiple zones with per-player snapshot routing; a Director with mechanical event effects + a player→influence causal loop; equipment swaps, org territory claims with treasury income, chat/emote, account-auth + rate-limit + a record cache, and a Director-paced ambient NPC sim. Owner-gated forks remain parked (siege tuning, Force access/scarcity, PvP-consent, LLM-Director, death-penalty numbers, CP award rates, visual A1b/P1). **The unattended backlog is now DRY of unblocked non-owner-gated items** — next work needs an owner steer (a new wave) or tackles the parked visual/design items.
- 2026-06-25 E27 DONE (Wave E [HOT] #7, FINAL) — ambient NPC sim + snapshot. New pure `scripts/net/ambient_sim_model.gd` (static): `advance(roster, zone_id, alert, tick, bounds)` deterministically (hash-seeded like zone_state) maintains a small per-zone NPC roster — `target_population` keyed to alert (lockdown/underworld 5, high_alert/unrest 4, standard 3, lax 2), archetypes keyed to alert, in-bounds positions, `NPC_LIFESPAN`-tick lifespan with despawn-on-expiry + respawn-to-target. `network_manager` advances every zone's roster on the Director tick (`_advance_ambient`, after the influence fold + `director_tick`) and folds `npcs[]` for the player's zone into the per-peer snapshot. `net_world` logs the snapshot npc count. New `ambient_sim_model_smoke` (alert-keyed count, in-bounds, valid kinds, determinism, carry-over, despawn-on-expiry). Full gate GREEN (54 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** the server advanced all 4 zones (`[ambient] tick 1 npc counts {spaceport:4, port_fringe:3, market_district:3, dune_sea:3}`, stable/deterministic) and a spaceport client's snapshots carried `npcs=4`. Not ledger-flagged. KNOWN follow-up: client-side NPC rendering + NPC AI/behavior (this is the spawn/sim foundation only).
- 2026-06-25 E26 DONE (Wave E [HOT] #6) — account auth/ownership guard + reliable-RPC rate-limit + record cache; closes the identity-spoofing gap. New pure `scripts/net/account_auth_model.gd` (static): `check_secret(stored, provided)` (unsecured account claimed by the provided secret; secured requires an exact match; backward-compatible with pre-E26 saves) + a `consume_token` token bucket (rate 25/s, burst 50, deterministic with a passed clock). `network_manager`: register now enforces the secret BEFORE binding the peer/loading (wrong secret → `auth_result` rejection, no load/overwrite; first claim persists `record.account_secret`); a read-through/write-through `_record_cache` (`_cached_load`/`_cached_save`) replaces every per-call `store.load_record`/`save_record` (skill-raise/equip/claim/CP-award/org-lookup no longer re-read JSON); a `_rate_ok` token-bucket throttle (using `Time.get_ticks_msec` + the pure model) guards all 7 reliable RPCs (fire/register/skill-raise/equip/claim/release/chat — NOT the unreliable movement). `net_world` gains `--secret` + an auth-denied handler. New `account_auth_smoke` (claim/match/mismatch/backward-compat + bucket refill/deny/cap). Full gate GREEN (53 GDScript smokes + 7 python + import + launch; persistence/net/combat_arena unregressed). **Two-process PASSED:** A claimed `e26vault` with secret `swordfish`; B with `guess` was denied `(bad_secret)` and could NOT load/overwrite; C with `swordfish` loaded; no `[ratelimit]` throttles on legit play. Not ledger-flagged. KNOWN follow-up: write-back/eviction policy for the cache (currently write-through, unbounded per session).
- 2026-06-25 E25 DONE (Wave E [HOT] #5) — chat / emote, the first social/RP channel on the wire. New pure `scripts/net/chat_model.gd` (static): `normalize(channel, text, speaker)` whitelists the channel (say/emote/ooc), strips control chars (code<32 + DEL) via `sanitize`, clamps to MAX_LENGTH=256, rejects empty (reasons bad_channel/empty); `format_line` renders per-channel ("Name: text" / "* Name text" / "[OOC] Name: text"). `network_manager`: `submit_chat(channel, text)` [any_peer, reliable] uses the player's display name as speaker, validates, and broadcasts `apply_chat(message)` to ALL peers; `chat_received` signal. `net_world`: a HUD chat panel (last 6 lines), `--chat <channel:text>` headless affordance, and a chat-received handler that logs `[chat] <formatted>`. New `chat_model_smoke` (channel whitelist, control-strip, length clamp, empty rejection, format). Full gate GREEN (52 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** ObiWan's `emote` round-tripped to BOTH peers (`* ObiWan …` in server + Yoda's + ObiWan's logs), and Yoda's bogus channel was rejected `(bad_channel)`. Not ledger-flagged. KNOWN follow-up: zone-scoped `say` + a GUI LineEdit input (broadcast-to-all + headless send suffice for now).
- 2026-06-25 E24 DONE (Wave E [HOT] #4) — player activity now feeds Director zone influence, closing the player→world loop (server-side only; `network_manager.gd`). On a combat target-disable, the shooter's faction axis (cached `_peer_axes` from `record.org`) accrues `DISABLE_INFLUENCE=5` (owner-tunable) into a server-side pending buffer via the E8 `PendingInfluence.add_pending`; just before each Director tick, `_fold_pending_influence` folds-and-clears the buffer into `zones.apply_influence_delta` (clamped 0-100) so player activity shifts faction influence, which then decays/re-derives normally. Reuses the E8 model (held as a `_pending_model` instance — its methods are instance, not static) + E13 nudges; no new smoke (pending_influence_smoke covers the model). Full gate GREEN (51 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** an autofire republic-axis player in the spaceport disabled the target 9× — republic influence climbed 55→60→64→68→69→77→86→90 and at the 70 threshold the **alert tier flipped high_alert→lockdown** (the per-peer snapshot carries the derived alert). The `+10` folds confirm fold-and-clear batches disables buffered between ticks. Not ledger-flagged. KNOWN follow-up: presence/other-action influence sources beyond target-disable.
- 2026-06-25 E23 DONE (Wave E [HOT] #3) — org claim/release command RPCs; wired the instantiated `Territory` into the RPC surface so the 60s resource tick stops being a no-op. `network_manager`: `submit_claim_node(node_id)` / `submit_release_claim(node_id)` [any_peer, reliable] validate via the E9 `OrgModel.can_claim_command` (valid member + rank≥3) + `TerritoryModel` (zone claimable + influence floor + one-claim-per-node), claim the node in the player's CURRENT zone, and reply `claim_result`. Org membership is threaded via a `build.org` test affordance (`record.org` persisted; real faction-join is a later feature) and per-org-per-zone territory influence is seeded server-side (`_territory_influence`; real accrual is later). A compact territory view (org treasury + claims in-zone) is folded into the per-peer snapshot; the resource tick is now overridable (`--resource-tick`) and logs treasuries. `net_world` gains `--faction/--faction-axis/--faction-rank/--territory-influence/--claim` + a claim-result handler. **Caught by the two-process check (not the pure smokes): JSON-reloaded `faction_rank` widens to float, tripping org_model's strict `typeof==TYPE_INT`** — fixed by coercing the loaded org's numeric fields to int in `_org_for_peer`. Full gate GREEN (51 GDScript smokes + 7 python + import + launch). **Two-process PASSED:** a rank-3 Hutt member CLAIMED a lawless node (tier foothold) and the org treasury accrued 150/tick (150→1950); a secured-zone claim was denied `(secured_zone)`, a rank-2 claim `(rank)`, and an already-claimed node `(node_unavailable)`. No new smoke (reuses org_model_smoke + territory_smoke). Not ledger-flagged. KNOWN follow-ups: real faction-join + real territory-influence accrual (FACTION_TERRITORY_DESIGN §1-§2); siege loop stays owner-gated.
- 2026-06-25 E22 DONE (Wave E [HOT] #2) — inventory / equipment-swap RPC (D3); completes the half-wired equip path (the combat read-path already built pools from `sheet.equipment`). New pure `scripts/rules/equipment_model.gd` (static): `can_equip`/`equip` validate slot + catalog membership + ownership against `sheet.inventory` (with a fallback that owns currently-equipped gear for pre-inventory saves); reasons bad_slot/unknown_item/not_owned; non-mutating. `chargen_model` sheets now carry a starter `inventory` (blaster_pistol, blast_vest, hold_out_blaster, blast_helmet) — additive, chargen_smoke stays green. `network_manager`: new `submit_equip(slot, item_key)` [any_peer, reliable] (mirrors submit_skill_raise: load record → `Equipment.equip` → write sheet.equipment → persist → `arena.set_player_sheet` → `equip_result` reply); catalogs hoisted to `_weapons_catalog`/`_armor_catalog`. `net_world` gains `--equip <slot:item>` + an equip-result handler. New `equip_smoke` (valid owned swap is non-mutating + changes the damage source; bad_slot/unknown_item/not_owned rejected; no-inventory fallback). Full gate GREEN (51 GDScript smokes + 7 python + import + launch). **Two-process check PASSED:** an unowned `blaster_rifle` was rejected `(not_owned)`; an owned `hold_out_blaster` swap was accepted (`damage pool now 3D+1`, was 4D) and SURVIVED reconnect (`[persist] … [weapon=hold_out_blaster]`). Not ledger-flagged. KNOWN follow-up: item acquisition (vendor/loot) to grow the inventory beyond the starter set.
- 2026-06-25 E21 DONE (Wave E [HOT] #1) — seeded multiple zones + per-peer snapshot routing in `network_manager.gd`/`net_world.gd` (the FIRST [HOT] slice; done solo on the main tree). New `data/zones_clone_wars.json` (4 zones: spaceport secured, port-fringe + market contested, dune-sea lawless). `start_server` now calls `_load_zones()` (data loop; graceful fallback to the single hardcoded zone if the file is absent/malformed) and the Director ticks ALL of them. Each peer gets a `current_zone_id` (`_peer_zones`, default on connect, settable via an optional `zone` key on the existing `register_account` build dict — RPC signature unchanged); `_build_snapshot(zone_id)` emits that player's zone summary; the 20 Hz broadcast became a per-peer `apply_snapshot.rpc_id` loop. Client gains `--zone <id>`. New `zones_smoke` (≥3 zones, unique ids, secured+contested+lawless present, real default, all tick deterministically, ≥1 claimable). Full gate GREEN (50 GDScript smokes + 7 python + import + launch). **Two-process check PASSED:** server logged `4 zone(s) seeded` + `peer … assigned zone tatooine.dune_sea (lawless)`; the dune-sea client received `zone=standard/lawless` snapshots + a `[news]` event — a contested/lawless zone is now available (precondition for territory claims E23 + ambient sim E27). Not ledger-flagged (infrastructure).
- 2026-06-25 E13+E14 DONE (Wave E world-sim batch 6) — two shared-file edits verified together by one full gate (49 smokes, no regression incl. net_smoke); committed separately-scoped. **E13** Director event mechanical effects + the event→influence causal loop in `zone_state.gd`: a bounded (-2..+2) owner-tunable `EVENT_EFFECTS` table (smuggling/vendor/spawn/perception) for all 12 event types, surfaced as `zone_summary["effects"]` (events were headline-only before); plus per-tick active-event influence nudges (crackdown/checkpoint→republic, cis_propaganda→cis, pirate/bounty/auction→hutt, +1/tick) capped at `EVENT_INFLUENCE_CAP = LOCKDOWN_REPUBLIC-1 = 69` so events build a FOOTHOLD but a true lockdown/underworld/surge stays player-driven and transient (a surge already ≥cap just decays). The cap is what keeps the existing `zone_state_smoke` green (the hutt-85 surge-decay scenario is above the cap → un-nudged) — verified, plus new deterministic nudge/cap/effects asserts. NOT ledger-flagged (implements WORLD_SIM_DESIGN, not a divergence). **E14** data-driven set-dressing (`lowpoly-scene-builder` authored): new `data/mos_eisley_props.json` (8 props referencing ONLY existing GLB models via a key→const map — barrels/crates/a speeder, placed clear of the Bay 94 range); `world_builder._place_data_props()` reads it at the end of `build_settlement` with a multi-layer guard (file-exists/null/type/unknown-key) → graceful no-op fallback to the hardcoded layout; shared builder so solo + net get it identically. `world_builder_smoke` extended (JSON parses + non-empty props + determinism preserved). NO asset-pipeline files touched. Full gate GREEN (49 GDScript smokes + 7 python + import + launch).
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
