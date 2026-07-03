# Overnight Queue — sole-driver max-parallelization loop (armed 2026-07-02 night)

Owner steer (2026-07-02): I am the **sole overnight driver** (the parallel F-audit session is
stopping). Work **all four focus areas**; use judgment, document divergences in
`docs/DIVERGENCE_LEDGER.md` first, only stop for a *genuinely new* owner-level fork.
Self-imposed guardrail: **local/deterministic only — no paid/external/LLM-in-the-loop APIs** overnight.

## Per-tick contract (what each cron fire does)
1. Read this file + `CLAUDE.md` + `docs/SESSION_HANDOFF.md` §3 playbook/§4 guardrails.
2. Take the top 1–3 unblocked items (prefer independent ones; spread across areas over the night).
3. **Parallelize:** spin up a **Workflow** that fans out the `[PAR]` parts (new files: presentation
   modules, content JSON, pure models, tests, design) each in its own **worktree**; integrate the
   green ones serially on main. Do `[HOT]` wiring (`network_manager.gd`/`net_world.gd`/`combat_arena.gd`)
   **one file at a time on main** — never two HOT slices at once.
4. **Verify:** full gate GREEN (`.\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"`)
   + a **two-process** check for net slices + a **runtime-load** check for `net_world.gd`
   (the gate does NOT catch its warning-as-error; launch a `--no-register` client and grep for SCRIPT ERROR).
5. On GREEN: **scoped** `git add <your paths>` (NEVER `-A`; NEVER touch `assets/`, `MMO_Assets/`,
   `tools/fetch_assets.py`, `tools/asset_sources.json`, `docs/ASSET_*.md`) + commit (message via `-F` file
   to avoid quote-parsing). Mark the item DONE (+hash) here. On RED: `git checkout -- <your paths>`, mark BLOCKED.
6. Keep replies terse. Don't create new crons / don't ScheduleWakeup — THIS cron is the driver.
6b. **Stay active until your slice(s) COMMIT** — don't end the turn with uncommitted background work
    (the idle-only cron would start an OVERLAPPING tick). Wait on your Workflow/agents (Monitor or a
    foreground gate) before finishing. If a tick overlaps anyway, scoped commits + a fresh gate make it safe.
7. **NEVER HOLD / never idle** (owner 2026-07-02): if every item below is DONE/BLOCKED, REPLENISH the
   queue — append new valuable slices (deeper presentation, more content, the next system, harder tests,
   real polish) across the four areas and keep shipping verified slices. Always leave the queue with
   unblocked work for the next tick. Quality bar stays: gate-green + verified + scoped commit.

## A. Presentation / playable feel  [PAR-heavy: new client modules + minimal net_world hooks]
- [ ] A1  Inventory/equipment panel (I key): list `sheet.inventory`, equip via click (`Net.send_equip`), show equipped.
- [ ] A2  Character panel polish (V): attributes/skills/Force/credits layout + `/raise` affordance surfaced.
- [ ] A3  Nameplate health bar + faction color + distance fade.
- [ ] A4  Zone-entry banner + security-tier screen tint (secured/contested/lawless danger cue).
- [ ] A5  Crosshair + camera shake on hit + a simple hit/kill marker (SFX are silent placeholders — no audio files).
- [ ] A6  First-login onboarding overlay: controls + the core loop (spar dummy→CP→shop→travel→lawless danger→death).
- [ ] A7  Minimap / zone HUD (positions of same-zone players + NPCs from the snapshot).

## B. New backend + Wave F follow-ups  [PAR models/tests, then HOT serial]
- [ ] B1  Positional inter-player PvP range (real distance between players, not nominal PVP_DISTANCE).
- [ ] B2  Third-party corpse-loot RPC (loot a dropped corpse in lawless) + a Director-tick decay by tier.
- [ ] B3  Durability=0 "broken" -> halved pools until repaired + a repair vendor action (credit sink).
- [ ] B4  Post-death -1D DEATH_DEBUFF live (round-keyed, recovery_model.death_debuff_dice) in the arena.
- [ ] B5  Server-global (offline) Force soft-cap tally persisted in world_state (not just connected).
- [ ] B6  Siege state machine per `docs/SIEGE_DESIGN.md` — pure `siege_state` model + smoke, then HOT.
- [ ] B7  PvP-consent (challenge/accept + bounty) per `docs/PVP_CONSENT_DESIGN.md` — pure model + smoke, then HOT (protected-zone opt-in).
- [ ] B8  Ammo/repair recurring sink; ammo count on the sheet + a reload/buy path.

## C. Content & world depth  [PAR-heavy: mush-content-porter -> data/ JSON]
- [ ] C1  Port more Clone Wars NPCs/vendors/creatures from read-only C:\SW_MUSH into `data/` (source_policy noted).
- [~] C2  Missions/quests: pure `quest_model.gd` + `data/quests_clone_wars.json` (4 starter quests) + smoke DONE (first tick); the notice-board RPC + event feeds remain a HOT follow-up.
- [ ] C3  More data-driven zones + `mos_eisley_props`-style set-dressing.
- [ ] C4  Per-zone / per-faction vendor stock variety.
- [ ] C5  Named NPCs + dialogue stubs (data + a talk RPC, text-only).

## D. Hardening & tests  [PAR-heavy]
- [ ] D1  Adversarial-review Workflow over economy/death/Force/PvP; fix confirmed findings.
- [ ] D2  Coverage: corpse manifest, insurance edge cases, casualty dedup, the new RPCs' composition (flow smokes).
- [ ] D3  Fix the pre-existing `!is_inside_tree()` warning (set global_position AFTER add_child) in net_world.gd `_build_camera`/`_spawn_npc`/`_spawn_avatar`.
- [ ] D4  Fix the bridge bottom action-row overlap (space panel fixed Y-offsets) the space agent flagged.
- [ ] D5  Tune the isometric camera framing (`space_tactical_view3d.gd` WORLD_SCALE/fov/distance) — conservative defaults, no eyeball.

## Log (newest first)
- Tick 1 (inline kickoff): C2 pure `quest_model.gd` + quests data + smoke + DIV-0020 ledger row. Gate green.
- (armed) Wave F complete + presentation + space landed this session (see WAVE_F_HANDOFF + git log).
