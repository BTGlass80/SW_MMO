# Wave F — Fresh-Chat Handoff (2026-07-02)

**Start here to continue Wave F.** Also read `CLAUDE.md` (standing constraints),
`docs/UNLOCK_SYSTEMS_PLAN.md` (the full slice plan), and `docs/DIVERGENCE_LEDGER.md`
(DIV-0006/0011/0017/0018 are the Wave F rows).

## Where we are — WAVE F COMPLETE (2026-07-02)
The owner un-gated the big forks and **all FOUR owner-decided systems are now WIRED LIVE + two-process
verified**: WEG-anchored economy, lethal death/respawn + hostile-PvE creatures, SWG-Village Force unlock,
and zone-based PvP. Full slice status lives in `docs/UNLOCK_SYSTEMS_PLAN.md`.

- **Pure/rules foundation (S0–S5)** — committed green (see UNLOCK_SYSTEMS_PLAN).
- **HOT wiring — ALL DONE + verified:**
  - **S6** `f1e8660` — combat_arena per-player lethal flag + hostile targets (byte-identical sparring when off).
  - **S7–S10** `04d39c6` — economy: `_award_credits`/`apply_credits`, `submit_vendor_list`/`submit_buy`/`submit_sell`, client shop HUD, `economy_flow_smoke`. 2-proc: 1000→buy 750→250→sell +110→360.
  - **S11–S13** `e1631ad` — Director-tick hostile spawner (lawless+contested) + death/respawn (`_handle_player_death`) + creature loot + `submit_buy_insurance`; `death_flow_smoke`, `--force-hostile`. 2-proc: Merdeth kill→respawn, Crab loot, insurance.
  - **S16–S19** `0d695dc` — Force awakening wiring (signal feeds → Director advance → `apply_completion` flip + client notice); `force_flow_smoke`, `--force-awaken`. 2-proc: forced awaken → phase 5 + notice.
  - **DIV-0019 zone PvP** `7a7e63c`/`57c0b1a`/`5502624` — `pvp_rules_model` (lawless-only same-zone `can_fire`), `suppress_return_fire` flag, `resolve_window(seed, pvp_gate)`, submit+resolve gate, casualty/death routing (killer credited, full-loot corpse flag), `--fire-target`/`--fire-nearest`; `pvp_rules_model_smoke` + `pvp_flow_smoke`. 2-proc: kill/respawn in lawless dune_sea; `refused (protected_zone)` in the spaceport.
- **State:** master at `5502624`+ (a parallel session also commits design docs to master — scoped commits only).
  Gate GREEN: `.\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"`.

## What's next
Owner steer (2026-07-02): **land PvP, then PRESENTATION.** PvP landed. Two parallel worktree agents are
making the systems VISIBLE (creature meshes, shop panel, death overlay, toasts) and fixing SPACE
(can't-exit bug + isometric camera). Wave F BACKEND remainders / follow-ups (all tracked in the ledger):
positional inter-player PvP range; third-party corpse-loot RPC + decay; durability=0 'broken'/halved-pool
effect; the −1D post-death DEATH_DEBUFF live; server-global (offline) Force soft-cap tally; consensual
duels in protected zones (see the parallel session's `PVP_CONSENT_DESIGN`).

## Original plan (historical — the HOT wiring list, now all DONE)

## Owner decisions (build to these — all DECIDED)
1. **Death** = partial loss + insurance, **credits kept**. Numbers (tunable consts, live in the models):
   10% durability/death (3% insured), 50% of UNEQUIPPED inventory drops, insurance 500cr/3 charges,
   respawn at the nearest secured med bay as `wounded` + the existing −1D death debuff.
2. **Economy** = modest sink, **WEG-anchored** (catalog `cost` = list price, 1.0 markup, 40% sell buy-back,
   friendly/allied rep discounts), **1000 starting credits**.
3. **Force access** = the **SWG "Village"** earned unlock — a rare, hidden, multi-phase awakening questline
   that flips `sheet.force_sensitive`. **Rarity = rare by default** (soft cap ~8, ~2%/tick), **dials exposed**.
4. **PvP = ZONE-BASED** (NEW, 2026-07-02): **lawless zones are open-PvP**; secured/contested protected.
   This is NOT in the original S0–S19 list — it needs its own design pass + slices (a PvP target/consent
   model + player-vs-player fire-intent wiring gated to lawless). Distinct from creature lethality (below).
5. **Corpse = FULL-LOOT in lawless** (2026-07-02): other players can loot your dropped corpse in lawless
   (equipped gear + credits still kept). S12/S13 corpse handling must allow third-party looting in lawless.
6. **Creature lethality = lawless + contested** (2026-07-02): set `hostile_npc_model.is_lethal_zone` default
   to `["lawless","contested"]` when wiring (S6/S11). Note: PvP-open = lawless ONLY; creature-lethal = both.

**Still owner-gated (do NOT decide):** siege durations/threshold; LLM-Director-at-launch; CP award-rate;
visual A1b/P1.

## Next actions (resume the HOT wiring)
Per UNLOCK_SYSTEMS_PLAN.md, next is **S6** — a combat_arena lethal flag (skip the DIV-0016 sparring clamp
for hostile NPCs; sparring behavior byte-identical when off), then S7–S13 (shop RPCs → creature spawner →
death→respawn → loot+insurance), then S14–S19 (Force village). **Fold in the 2026-07-02 decisions as you go:**
- S4 `is_lethal_zone` default → `["lawless","contested"]` (+ update its smoke).
- S12/S13 corpse: lootable by others in lawless (full-loot); a new PvP sub-wave for zone-based player combat
  (design it like the earlier `unlock-systems-design` Workflow: pure target/consent model + tests, then HOT).
- Add a **DIV-0019 (zone-based PvP)** ledger row BEFORE coding PvP (divergence-first rule).

## Conventions / guardrails (unchanged)
- Pure models in `scripts/rules/*` + `scripts/net/*.gd`; HOT = `network_manager.gd`/`net_world.gd` (one at a time).
- Server owns ALL RNG/seeds. Divergence documented in `docs/DIVERGENCE_LEDGER.md` BEFORE coding.
- Verify: full gate GREEN **+ a two-process headless check** for net slices. On green: **scoped** `git add <paths>`
  (NEVER `-A`; NEVER touch `assets/`, `MMO_Assets/`, `tools/fetch_assets.py`, `tools/asset_sources.json`,
  `docs/ASSET_*.md` — a parallel session owns the asset pipeline). Commit + log in UNATTENDED_BACKLOG + NIGHTLY_HANDOFF.
- `C:\SW_MUSH` is STRICTLY READ-ONLY. `.uid` files are tracked — commit them with their `.gd`.
- Two-process pattern: `Start-Process` server (`res://scenes/net_world.tscn -- --server [flags]`), poll the log for
  "server listening", run clients, `Stop-Process` + a `Kill-NetWorld` (CIM query for `*net_world.tscn*--server*`).
  Test affordances on the client: `--account/--secret/--quickstart/--zone/--autofire/--travel/--claim/--faction*`;
  the server needs `--allow-test-org` for the build.org test affordance (F66).
