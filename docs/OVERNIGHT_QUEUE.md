# Overnight Queue — sole-driver max-parallelization loop (armed 2026-07-02 night)

Owner steer (2026-07-02): I am the **sole overnight driver** (the parallel F-audit session is
stopping). Work **all four focus areas**; use judgment, document divergences in
`docs/DIVERGENCE_LEDGER.md` first, only stop for a *genuinely new* owner-level fork.
Self-imposed guardrail: **local/deterministic only — no paid/external/LLM-in-the-loop APIs** overnight.

## Per-tick contract (what each cron fire does)
1. Read this file + `CLAUDE.md` + `docs/SESSION_HANDOFF.md` §3 playbook/§4 guardrails.
2. Take the top 1–3 unblocked items. **Area G (Wave G) is TOP PRIORITY — drain it before areas A–D
   and before replenishing** (respect its declared order: G2 before G1; heed the seam guard). After G,
   prefer independent items spread across A–D.
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

## G. Wave G — TOP PRIORITY (external Fable review, owner-steered 2026-07-03)
**Work these BEFORE areas A–D and before any replenishment.** Full detail + files + verify in
`docs/WAVE_G_BACKLOG.md`; the review itself is in `docs/fable/`. These are post-Wave-F **seam** fixes:
Wave F shipped lethality + PvP, and three follow-ups became prerequisites. **Seam guard (mandatory):**
the smoke must assert **what actually ships** (G1 is a shipped green smoke asserting the OPPOSITE of the
wire — do not repeat that); after each `[HOT]` Wave-G slice do a doc↔model↔wire reconciliation before
marking DONE. Owner decisions are baked in below — do NOT re-open them.
- [ ] G2  `[HOT]` Wire `wound_ladder_model.escalate()` into the 3 live accumulation sites (resolve_exchange,
      _resolve_return_fire, PvP defender write-back). Cross the severity↔level seam via **level strings**,
      never raw ints (they diverge at 3). Re-seed affected smokes; update DIV-0008. **Land this FIRST** —
      it and G1 are one seam.
- [ ] G1  `[HOT]` **PvP death = TRUE TIERING (owner-decided fork A, 2026-07-03):** sev 5 = death; sev 3–4 =
      downed-in-field. Requires the **escape-hatch bundle** or a downed lawless player softlocks: (a) wire
      `recovery_model.death_roll` on the Director tick for mortally_wounded; (b) a **yield/respawn** command
      for a downed (sev 3) player with no medic. Then wire `is_kill`/`PVP_DEATH_SEVERITY` on the live path,
      fix the two `pvp_rules_model_smoke` asserts + DIV-0019 text to match. Depends on G2.
- [ ] G3  `[HOT]` PvP defenders can't dodge — build defender defense from declared stance + `player_dodge_pool`
      (wound/armor-penalized) into the `is_pvp` branch via `prepare_ranged_defense`; read cover from
      persistent state. Smoke: dodge raises attacker difficulty; full-dodge defender skips own attack.
- [ ] G10 `[HOT]` De-fang the dummy faucet: hostile-death fallback → no-target/hold-fire (not the global
      dummy); dummy disables pay reduced/zero influence + drop the Force feed; move `_window_index = 0` out
      of `reset_target()`.
- [ ] G11 `[PAR]` Resolved-pool content smoke for every `hostile:true` creature (resolved atk/dmg ≥ 1D and
      match listed); fix `glim_worm`(0D dmg!)/`mip_swarm`/`spor_crawler` prose stat strings to dice codes.
- [ ] G4  `[HOT]` Hostiles never initiate — add a Director/window-tick unprovoked-attack path via the
      already-built `ground_combat_model.resolve_incoming_fire_window` (lawless+contested). 2-proc: idle bot
      in dune_sea takes fire and can die.
- [ ] G5  `[PAR]` Economy floor guard: assert `MAX_TOTAL_DISCOUNT <= 1 - SELL_RATE - ε` + a catalog-wide smoke
      `buy_floor(list) > sell_price(list)` (buy→sell arbitrage is one dial-turn away today).
- [ ] G12 `[PAR]` `threat_tier` per creature + alert-banded spawn table (calm lawless = tiers 1–2; merdeth-class
      = event/boss, never ambient) + loot-by-tier (risk currently anti-correlates with reward). Re-run
      `tools/balance_probe.gd` as acceptance.
- [ ] G6  `[PAR]` Doc-rot batch: fix `_wound_penalty_dice` stale comment; make `check_project.ps1` PRINT smoke
      + RPC counts (docs say "see gate output", kills the 59/66/72 drift); rewrite README "Current Slice" as
      bullets; DIV-0011 `force_sensitive` storage-divergence sentence; 3 `d6_rules` house-rule ledger lines.
- [ ] G7  `[PAR]` Rename the "Ahsoka" fixture in `wire_roundtrip_smoke.gd`; add a chargen reserved/canonical-name
      filter (port the MUSH name-policy list).
- **Process (fold in as you go):** a **dead-symbol detector** in the gate (orphan public funcs/consts outside
  their own smoke — would have caught G1's `is_kill`); structured **JSONL telemetry** from the existing print
  sites (death/buy/sell/loot/travel/window-resolve) BEFORE any tuning; the weekly `mush-content-porter`
  re-extraction cadence (CLAUDE.md program posture).
- **Owner-gated (still PARK):** PT1 playtest scheduling; the auth/crypto bundle (before non-LAN playtest);
  the positional-truth spike (G9, design doc first) — see `docs/WAVE_G_BACKLOG.md` owner-forks.

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

## Done this overnight (commits on master)
- **A** npc_builder mesh module (`ee45f3b`); named-NPC per-zone render, server+client (`7dbc3ed`, 2-proc); per-zone vendor stock live (`b3a4a7a`, 2-proc).
- **B** pure `pvp_consent_model` DIV-0022 (`5e694c5`); pure `siege_state_model` DIV-0021 (`650349a`). (HOT wiring of both = follow-up.)
- **C** pure `quest_model` DIV-0020 (`7746019`); 15 named NPCs + per-zone vendor data (`ef62f10`); +9 creatures 22→31 (`c0ae02d`); dialogue model (in flight).
- **D** hardening: 3 real bug fixes (pvp-consent double-duel; siege id-collision + open-window) + 8 edge smokes (`e906f46`).

## Highest-value NEXT (follow-ups)
- Wire NPC TALK (client interact → dialogue_model line). Wire quests live (notice-board RPC + event feeds + panel).
- HOT-wire siege (declare/join RPCs + Director tick + effective-security gate) and PvP-consent (fire-intent gate + duel/bounty RPCs).
- Render ambient/named NPC dialogue; corpse-loot RPC; durability-broken; -1D death debuff; positional PvP range.

## Log (newest first)
- Named-NPC render + per-zone vendor + npc_builder + hardening (3 bugfixes) + siege/pvp-consent/quest models + NPC/creature content — 11 verified commits.
- Tick 1 (inline kickoff): C2 pure `quest_model.gd` + quests data + smoke + DIV-0020 ledger row. Gate green.
- (armed) Wave F complete + presentation + space landed this session (see WAVE_F_HANDOFF + git log).
