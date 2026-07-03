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
   to avoid quote-parsing). **Then `git push origin master`** — a GitHub remote now exists
   (`https://github.com/BTGlass80/SW_MMO.git`); keep it in sync after every commit. Best-effort: a failed
   push is non-fatal (the commit stands; next tick retries). Mark the item DONE (+hash) here. On RED:
   `git checkout -- <your paths>`, mark BLOCKED.
6. Keep replies terse. Don't create new crons / don't ScheduleWakeup — THIS cron is the driver.
6b. **Stay active until your slice(s) COMMIT** — don't end the turn with uncommitted background work
    (the idle-only cron would start an OVERLAPPING tick). Wait on your Workflow/agents (Monitor or a
    foreground gate) before finishing. If a tick overlaps anyway, scoped commits + a fresh gate make it safe.
7. **NEVER HOLD / never idle** (owner 2026-07-02): if every item below is DONE/BLOCKED, REPLENISH the
   queue — append new valuable slices (deeper presentation, more content, the next system, harder tests,
   real polish) across the four areas and keep shipping verified slices. Always leave the queue with
   unblocked work for the next tick. Quality bar stays: gate-green + verified + scoped commit.

## G. Wave G — DRAINED through G13 (2026-07-03); delta follow-ups are the live queue
**G1–G5, G7, G10(=G13), G11, G12-mechanism, telemetry: DONE** — verified by the external delta review
(`docs/fable/SW_MMO_waveG_delta_review_2026-07-03.md`) and G13's live acceptance. The LIVE queue is
**`docs/WAVE_G_BACKLOG.md` § Delta follow-ups: G14–G18, then the owner-approved PT1 prep track** (G8
auth bundle, server watchdog, 20-bot soak, envelope replay). Work those BEFORE areas A–D. **Seam guard
stands (mandatory):** the smoke must assert **what actually ships**; after each `[HOT]` slice do a
doc↔model↔wire reconciliation before marking DONE. **Owner rulings 2026-07-03 (attended):** not-before-
live = models-OK/wiring-PARKED (siege/cities/server-space); push origin after each green commit;
PT1 prep cleared, PT1 date still owner-gated.

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
- [~] B6  Siege state machine per `docs/SIEGE_DESIGN.md` — pure `siege_state` model + smoke DONE (`650349a`,
      DIV-0021). **HOT wiring PARKED (owner 2026-07-03: not-before-live = models OK, wiring parked).**
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
- [x] D3  DONE (`fe7768f`, 2026-07-03): `!is_inside_tree()` fixed in `_spawn_npc`/`_build_camera` (105→0
      errors, live-verified); `_spawn_avatar` + FX spawners audited already-correct.
- [ ] D4  Fix the bridge bottom action-row overlap (space panel fixed Y-offsets) the space agent flagged.
- [ ] D5  Tune the isometric camera framing (`space_tactical_view3d.gd` WORLD_SCALE/fov/distance) — conservative defaults, no eyeball.

## Done this overnight (commits on master)
- **A** npc_builder mesh module (`ee45f3b`); named-NPC per-zone render, server+client (`7dbc3ed`, 2-proc); per-zone vendor stock live (`b3a4a7a`, 2-proc).
- **B** pure `pvp_consent_model` DIV-0022 (`5e694c5`); pure `siege_state_model` DIV-0021 (`650349a`). (HOT wiring of both = follow-up.)
- **C** pure `quest_model` DIV-0020 (`7746019`); 15 named NPCs + per-zone vendor data (`ef62f10`); +9 creatures 22→31 (`c0ae02d`); dialogue model (in flight).
- **D** hardening: 3 real bug fixes (pvp-consent double-duel; siege id-collision + open-window) + 8 edge smokes (`e906f46`).

## Highest-value NEXT (follow-ups)
- FIRST: `WAVE_G_BACKLOG.md` § Delta follow-ups (G14–G18), then the PT1 prep track (G8/watchdog/soak/replay).
- Wire NPC TALK (client interact → dialogue_model line). Wire quests live (notice-board RPC + event feeds + panel).
- ~~HOT-wire siege~~ **PARKED (owner 2026-07-03: wiring not-before-live)**; PvP-consent wiring (fire-intent
  gate + duel/bounty RPCs) is NOT parked — it stays queued.
- Render ambient/named NPC dialogue; durability-broken repair RPC (pairs with a faucet per G18); -1D death
  debuff; positional PvP range (see G9 design-first).

## Log (newest first)
- 2026-07-03 (Fable, tick 4): AMMO RECURRING SINK live `14ed176` (DIV-0029 — latent WEG ammo
  fields consumed server-side; auto-reload from 25cr vendor packs; dummy sparring free; 2 starter
  packs; two-process: 6-mag → 2 reloads → out_of_ammo refusal; sink 3–60 cr/min analytic, never
  negative vs t2 income) — the B8 sink finally pairs the faucet month. + MUSH sync-manifest tool
  `7429dfd` (50 sources baselined, drift = exit 1, weekly cadence formalized; re-port = later
  MERGE slice). Gate 120 smokes.
- 2026-07-03 (Fable, tick 3): the five Next-queue seam items SHIPPED — HOT batch `5c7da43`
  (server-side replay-inputs envelope log w/ byte-identical broadcast + live REPRODUCED replay;
  boss-quest `_cached_load`; unprovoked equal-severity escalation to wounded_twice; First-Aid-at-14
  flow smoke) + svaper loot_mult retune `f86979f` (probe-accepted: t4 spread 7.87x→1.77x, means
  monotone). Gate 118 smokes. Remaining unblocked: ammo sink (B8).
- 2026-07-03 (Fable, session 2 continued): FULL Wave-G delta queue + PT1 prep track SHIPPED. G14
  wounded_twice −2D live everywhere (adversarial verify forced the incoming-fire + heal/recovery seams;
  First Aid now treats live wounded_twice at difficulty 14) `bf27f1e`; G15 probe-accepted retier + one
  loot axis + a REAL quest-driven boss channel (verifier caught the phantom channel silently killing
  q_krayt_bounty/q_rancor_sighting) `107b7bc`; G16/G17/G18 `1983b34` (gate prints counts + not-before-live
  invariant — which caught siege_state_model misfiled in scripts/net on day one; faucets-and-sinks rule +
  telemetry_tally.py); G8 salted-hash auth + legacy migration + dev-transport banner `6d2834e`
  (two-process proven); envelope replay tool `0c21e98`; watchdog + soak probe `0a89544`; live soak
  acceptance PASS (20 bots, 0 errors, 20/20 connected). Next queue = WAVE_G_BACKLOG § Next queue.
- 2026-07-03 (Fable takes the wheel, attended→unattended): G13 LIVE acceptance PASS (lawless autofire bot:
  0 dummy hits post-travel, Acklay combat as positive control); D3 done — `!is_inside_tree()` spam fixed
  (`_spawn_npc`/`_build_camera` add_child-before-global_position; 105→0 errors live-verified); Wave G
  delta review landed + G13–G18 folded into WAVE_G_BACKLOG § Delta follow-ups; owner rulings recorded
  (siege models-OK/wiring-parked; PT1 prep track approved; push-per-green-commit); G14+G15 running as a
  worktree workflow with adversarial verify.
- Named-NPC render + per-zone vendor + npc_builder + hardening (3 bugfixes) + siege/pvp-consent/quest models + NPC/creature content — 11 verified commits.
- Tick 1 (inline kickoff): C2 pure `quest_model.gd` + quests data + smoke + DIV-0020 ledger row. Gate green.
- (armed) Wave F complete + presentation + space landed this session (see WAVE_F_HANDOFF + git log).
