# Wave F — Fresh-Chat Handoff (2026-07-02)

**Start here to continue Wave F.** Also read `CLAUDE.md` (standing constraints),
`docs/UNLOCK_SYSTEMS_PLAN.md` (the full slice plan), and `docs/DIVERGENCE_LEDGER.md`
(DIV-0006/0011/0017/0018 are the Wave F rows).

## Where we are
The owner un-gated the big forks and Wave F is building three systems (death/respawn,
WEG-anchored economy, SWG-Village Force unlock) grounded in a design Workflow.

- **Pure/rules foundation is COMPLETE and committed** — slices **S0–S5** are green:
  - S0 `304c015` — ledger rows + the build plan
  - S1 `1cfe6bc` — `economy_model.gd` (buy/sell/loot pricing) + smoke
  - S2 `c48b16a` — 1000 starting credits + closed a sheet-schema drift (declared equipment/inventory/force_skills)
  - S3 `502894e` — `death_penalty_model.gd` (durability/drop/insurance/respawn) + smoke
  - S4 `5f6e853` — `hostile_npc_model.gd` (the lawless lethal source) + smoke
  - S5 `4238003` — death schema fields (item_durability/insurance/corpse) + hardened drift guard
- **State:** HEAD at the S5 commit, **tree clean, 66 smokes green.** Gate:
  `.\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"`
- **What's left = HOT netcode wiring (S6–S19)** in `network_manager.gd`/`net_world.gd`/`combat_arena.gd`,
  ONE FILE AT A TIME, each with a two-process headless check. See UNLOCK_SYSTEMS_PLAN.md for the ordered list.

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
