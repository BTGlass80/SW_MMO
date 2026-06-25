# SESSION HANDOFF — start here in a clean session

**Purpose:** this is the single entry point for a *fresh* Claude Code session that is
taking over **unattended, all-day, parallelized** development of the SW_MMO prototype.
Read this top to bottom, then execute **§1 First actions**. You should not need to ask
the owner anything to begin — the work is queued and the guardrails are explicit.

Written 2026-06-25 after a full 5-reader codebase audit. Ground truth as of HEAD
`15aa6df` (M2.2). If git HEAD has moved, trust the code + `docs/UNATTENDED_BACKLOG.md`
Log over this file.

---

## 0. TL;DR — what this is and where it stands

- A standalone **Godot 4.6.3 / GDScript** prototype of a **Clone Wars-era (20 BBY Mos
  Eisley) Star Wars MMO**, grounded in **West End Games Star Wars D6 R&E**. Server-
  authoritative multiplayer; pure/presentation split; the **server owns all RNG/seeds/
  dice**. Charter + constraints live in `CLAUDE.md`.
- **Built & verified:** M1.1–M1.5 net core/persistence/nameplates → M2.0–M2.2 zone/
  security Director + world events → **Wave C** (chargen + dual-track CP) → **Wave D**
  (combat uses your sheet + equipped gear) → **Wave E (E1–E27) COMPLETE** — the full
  persistent player-driven loop: WEG wound ladder/recovery, derived stats, per-weapon
  range bands, off-by-default Force hook, security gate, pending-influence, org model,
  creature-spawn, vendor, reputation, Director event effects, data-driven set-dressing,
  test guards; then the [HOT] netcode — multiple zones with per-player snapshot routing,
  equipment-swap, org claim/release commands with treasury income, the player→influence
  causal loop, chat/emote, account-auth + rate-limit + record cache, and a Director-paced
  ambient NPC sim. Plus a review-driven **hardening** pass (2 `register_account` fixes) and a
  long **follow-up series F1–F22** (each gate-green + two-process verified) that grew the slice
  into a genuinely playable MMO. Highlights:
  - **Wound/medical loop (F7–F10, F17, F19):** natural self-recovery (DIV-0012) + First Aid by a
    medic (DIV-0013, reaches incapacitated/mortally) + a colour-coded own-condition HUD + other
    players' condition on their nameplates + "First-Aid the nearest WOUNDED ally" targeting.
  - **Multi-zone world (F11–F14):** in-session zone TRAVEL (DIV-0014, persisted) + zone-scoped
    player VISIBILITY (you only see same-zone players) + the org/territory HUD; all zone-scoped.
  - **Per-species movement speed (F15, DIV-0015):** wired the orphaned derived-stats model.
  - **Combat correctness (F18):** equipped-weapon SKILL drives the attack pool + melee `STR+ND`
    damage (wires derived-stats melee) — latent fix, melee is acquirable only once an economy exists.
  - **Social (F2, F20, F22):** zone say/emote + global ooc + ORG chat (cross-zone) + a **GUI chat
    LineEdit** with a `/say //ooc //org //emote` slash parser.
  - **Visibility (F9, F12, F16, F17):** condition/org HUDs + RENDERED ambient NPCs + wound nameplates.
  - **Robustness/guards (F4–F6, F10, F14, F21):** record-cache eviction on disconnect; FIVE [HOT]
    composition guards (claims/auth/First Aid/zone/chat) locked into the gate.
- **Green bar (current truth):** the **full** `tools/check_project.ps1` passes — **59
  GDScript smokes** + 7 python + import + launch (green at every commit). DIV-0001..0015.
- **STATUS: Wave E + the F1–F22 follow-ups are DONE; the prototype is a playable, populated,
  traversable multi-zone MMO** (chargen/progression → species-paced movement → combat (CP/FP) →
  full visible medical loop → equip → travel/presence → org claims+treasury → say/ooc/org chat w/
  GUI input → news → rendered NPCs), all gate-guarded. **The unblocked, non-owner-gated backlog is
  DRY** — the substantive remainders cluster behind the **economy/vendor** (unlocks melee +
  the orphaned creature_spawn/vendor/reputation models) and the parked owner forks (§5: siege,
  Force access, PvP-consent, death-penalty numbers, CP rates, LLM-Director, visual A1b/P1). A fresh
  session should **confirm green and HOLD for an owner steer**, not invent owner-gated scope. (Full
  history: `docs/NIGHTLY_HANDOFF.md` + the `UNATTENDED_BACKLOG.md` Log — F1–F22.)

---

## 1. First actions (do these now, in order)

1. **Orient:** read `CLAUDE.md`, this file, and `docs/UNATTENDED_BACKLOG.md` (the Wave E
   queue + Guardrails + the F1–F22 Log). Skim `docs/DIVERGENCE_LEDGER.md` (DIV-0001..0015).
2. **Confirm the baseline is green** before changing anything:
   ```powershell
   .\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"
   ```
   and `git log --oneline -5`. If RED on arrival, fix or report — do not build on red.
3. **Arm the loop** so it keeps going while you work. The previous driver cron was
   *session-only* and died with the prior session, so you must re-create it. Use
   **CronCreate** with the contract in **§2** (cron `6,16,26,36,46,56 * * * *` ≈ every
   10 min, idle-only, `recurring:true`, `durable:false`). Recurring crons auto-expire
   after 7 days — re-arm if this runs that long.
4. **Check the queue.** **Wave E (E1–E27) is COMPLETE** (see §0 + the backlog Log). If the
   owner has added a NEW wave/items to `docs/UNATTENDED_BACKLOG.md`, take the top unblocked
   batch and run it (the §3 playbook still applies: batch `[PAR]` pure-model+test slices via
   the Workflow tool, do `[HOT]` slices one at a time, two-process-verify net slices). If the
   backlog is still DRY of unblocked, non-owner-gated items, **do NOT invent scope** — go to 5.
5. **Keep going while there is unblocked, non-owner-gated work; otherwise HOLD.** Don't ask
   the owner questions. While the queue has unblocked items, ship one verified slice after
   another. When the queue is dry (the current state), confirm green and hold for an owner
   steer — do not fabricate owner-level decisions or churn on marginal additions. Park the
   §5 owner-gated forks BLOCKED; report a real, persistent blocker.

---

## 2. The loop contract (paste this as the CronCreate `prompt`)

> Unattended SW_MMO development tick — single driver for gameplay/netcode/rules/world-
> sim/tests/docs. Read `docs/SESSION_HANDOFF.md` (parallelization playbook + guardrails)
> and `docs/UNATTENDED_BACKLOG.md` (Wave E) before acting. Take the top unblocked,
> non-owner-gated item(s). **Parallelize when it makes sense:** batch 2–4 `[PAR]` pure-
> model+test slices via the **Workflow** tool (ultracode is on); do `[HOT]` slices
> (`network_manager.gd` / `net_world.gd`) **one at a time** on the main tree. Each slice:
> honor the pure/presentation split; the **server owns all RNG/seeds**; document any
> WEG/MUSH mechanic divergence in `docs/DIVERGENCE_LEDGER.md` **before** coding it; verify
> with the FULL gate `.\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"`
> GREEN **plus** a two-process headless check for net slices. On GREEN: scoped
> `git add <your changed paths>` (**NEVER** `-A`; **NEVER** touch `assets/`, `MMO_Assets/`,
> `tools/fetch_assets.py`, `tools/asset_sources.json`, `docs/ASSET_*.md` — a parallel
> session owns the asset pipeline) + commit; mark the item DONE (+hash) in
> `docs/UNATTENDED_BACKLOG.md`; append one-line notes to `docs/NIGHTLY_HANDOFF.md` + the
> backlog Log. On RED: fix, or `git checkout -- <your paths>` (only your files) and mark
> BLOCKED. `C:\SW_MUSH` is STRICTLY READ-ONLY. DO NOT ask the owner questions and DO NOT
> stop — keep developing. SKIP/park only genuinely owner-gated forks (siege/Drop-6D
> durations & capture threshold; Force/Jedi ACCESS & scarcity policy; PvP-consent
> specifics; LLM-Director-at-launch; death-PENALTY numbers; CP award-rate tuning; visual
> items A1b/P1). Do NOT create new cron jobs and do NOT call ScheduleWakeup — THIS cron is
> the driver. Keep replies terse; ship verified slices.

CronCreate args: `cron:"6,16,26,36,46,56 * * * *"`, `recurring:true`, `durable:false`.

---

## 3. Parallelization playbook

The repo has **two parallelism levers**; use both.

**(a) Within a slice (always):** use the **Workflow** tool to raise quality —
independent design alternatives, an author-then-adversarially-verify pass on the
implementation, parallel test authoring. Ultracode is on; lean into it.

**(b) Across slices (the throughput lever):**
- **`[PAR]` slices** (pure model + test, or docs/test-only) each create their **own new
  files**, so several can be implemented **concurrently**. The only files they share are
  `tools/check_project.ps1` (one `Invoke-GodotStep` line each) and occasionally
  `docs/DIVERGENCE_LEDGER.md` — small, append-only edits.
- **Recommended per-tick shape:** spin up a Workflow that implements **2–4 `[PAR]`
  slices**, each agent in its **own git worktree** (`isolation:'worktree'`) so file
  writes can't collide, each running the gate in its worktree. Then **integrate the green
  ones serially on main** (apply that slice's files, append its gate line + any ledger
  row, run the gate **once**, scoped-commit), and park any red one as BLOCKED with the
  error. Serial integration on main is what keeps the shared-file edits conflict-free.
- **`[HOT]` slices** edit `network_manager.gd` and/or `net_world.gd`. Do them **one at a
  time on the main tree** — never two `[HOT]` slices in parallel, and don't run a `[HOT]`
  slice in a worktree concurrently with a `[PAR]` batch that also lands on main.
- **`[PAR*]`** items edit a shared *rules* file (`d6_rules.gd`, `chargen_model.gd`,
  `zone_state.gd`): safe in parallel with other slices, but **not** with another slice
  editing that same file. Schedule them in different ticks.
- **When unsure, do one solid slice.** A green gate + a clean scoped commit beats raw
  parallelism. Reliability is the point; throughput is the bonus.

**Order of attack:** clear the `[PAR]` pure substrate first (E1–E20 ish) — it adds test
coverage and builds the pure models the `[HOT]` features consume (E8→E24, E9→E23,
E21→E23/E27) — then land the `[HOT]` features one per tick.

---

## 4. Guardrails (non-negotiable)

- **Asset pipeline is owned by a PARALLEL session.** NEVER stage, revert, or edit
  `assets/`, `MMO_Assets/`, `tools/fetch_assets.py`, `tools/asset_sources.json`,
  `docs/ASSET_PIPELINE.md`, `docs/ASSET_CATALOG.md`, `docs/asset_previews/`. Commit
  **only** your own changed files: `git add <paths>` — **never** `git add -A`. A RED slice
  reverts **only its own** files (`git checkout -- <your paths>`) — never a blanket
  `checkout -- .` / `reset --hard` / `clean` (that would destroy the asset session's work).
  The Log shows the asset session also appends entries — leave their lines alone; only add
  your own.
- **`C:\SW_MUSH` is STRICTLY READ-ONLY** reference. Never create/modify/delete under it;
  never open `sw_mush.db` read-write. Data flows one way: out.
- **Clone Wars era only.** GCW/Imperial/Rebel/stormtrooper framing is a bug unless
  deliberately recast. `content_smoke` enforces a forbidden-GCW-ship list — keep it green.
- **WEG R&E leads mechanics.** SW_MUSH is content/reference, not a 1:1 port.
- **Pure/presentation split.** Pure logic (RefCounted / SceneTree-testable; no nodes,
  input, sockets, rendering) in `scripts/rules/*` and `scripts/net/world_state.gd`;
  presentation/controllers in `scripts/world/*` and `scripts/net/{network_manager,net_world}.gd`.
- **Server owns ALL RNG/seeds/dice.** Tests seed every RNG; never `randomize()`.
- **Document divergence first.** Any WEG/MUSH/prototype mechanic divergence gets a
  `docs/DIVERGENCE_LEDGER.md` row **before** it is implemented (E2/E5/E6 are flagged).
- **Every new test is wired into `tools/check_project.ps1`** (one `Invoke-GodotStep`
  line) or it is invisible to the loop.

---

## 5. Owner-gated — PARK, never auto-build

If a slice would require deciding any of these, stop it and mark it
`BLOCKED: needs owner decision — <which>` in the backlog. Do **not** pick a number and proceed.

- **Siege / Drop-6D** phase durations, capture threshold, third-party intervention,
  per-org siege cap (the `siege_state.schema.json` state machine — design only).
- **Force / Jedi ACCESS & SCARCITY** policy (how one becomes force_sensitive, rarity,
  power economy). *The off-by-default Force-skill **data hook** (E6) is fine; the access
  policy is gated.*
- **PvP-consent** specifics (challenge/accept, bounty-as-consent).
- **LLM "Director flavor"** layer at launch (deterministic baseline already ships; an LLM
  in the tick is owner-gated — do not wire an API in).
- **Death-PENALTY numbers** (loot %, durability, insurance, respawn timers). The *shape*
  is decided (DIV-0006: partial loss + durability + insurance, credits kept); the numbers
  are gated. *Recovery/healing mechanics (E3) are not gated.*
- **CP award-rate tuning** (DIV-0007 dual-track mechanic is decided; the *rates* are gated).
- **Visual-check items** (need a human in the GUI): A1b building-model swaps + scale
  tuning, P1 client polish, and the still-open M1.2 two-client visual check.
- **Refactoring the hot autoload** (`network_manager.gd`) into extracted testable helpers
  is an architecture call — leave it unless the owner asks.

Decided & usable (NOT parked): **DIV-0006** death-penalty shape, **DIV-0007** dual-track CP.

---

## 6. Verification discipline

- **Full gate:** `.\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"`.
  It runs python unittests → import → 2s launch → all GDScript smokes, and FAILS on any
  non-zero exit or `SCRIPT ERROR | Parse Error | Parser Error` in output.
- **One smoke standalone:** `& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://scripts/tests/<name>.gd`
- **Test convention:** `extends SceneTree`; do work in `_init()`; collect into
  `var _failures: Array[String]`; print `"<name>: OK"` + `quit(0)` on pass, else
  `printerr(...)` + `quit(1)`. Seed all RNG. Mirror `scripts/tests/rules_smoke.gd` /
  `net_smoke.gd`. Then add the `Invoke-GodotStep` line to `check_project.ps1`.
- **Two-process headless check (net slices):** start the server in the background
  (`res://scenes/net_world.tscn -- --server [--combat-window 1] [--director-tick 0.5]`),
  poll its log for `server listening` (use `ping -n 2 127.0.0.1` to wait — `sleep` is
  blocked), run a client (`-- --client --host 127.0.0.1 --quit-after <n>` with
  `--account/--name/--species/--quickstart/--autofire/--autowalk/--raise-skill` as
  needed), grep the client log for the expected `[net]`/`[combat]`/`[news]` lines, then
  stop the server (`Get-CimInstance Win32_Process | ? { $_.CommandLine -like
  '*net_world.tscn*--server*' } | Stop-Process -Force`).
- **Scratch files** go under the session scratchpad, never the repo.

---

## 7. Architecture & key files (orientation map)

- **Autoloads** (`project.godot`): `D6Rules` = `scripts/rules/d6_rules.gd` (WEG dice
  core); `Net` = `scripts/net/network_manager.gd` (server-authoritative networking, idle in solo).
- **Pure rules** `scripts/rules/*`: `d6_rules` (pools/Wild Die/scale/soak/wound chart),
  `chargen_model`, `progression_model` (dual-track CP), `action_window_model`,
  `ground_combat_model`, `armor_condition_model`, `character_sheet_model`,
  `combat_event_envelope_model` / `combat_event_log_model`, the large `space_*` models, and the
  Wave-E + F-series rules models: `wound_ladder_model` (DIV-0008, wired in combat), `recovery_model`
  (DIV-0009; wired by F7 natural recovery + F8 First Aid), `derived_stats_model` (wired by F15
  species move + F18 melee damage), `equipment_model` (equip), `force_skills_model` (off-by-default
  hook, DIV-0011), and `reputation_model` / `creature_spawn_model` / `vendor_model` (modeled +
  smoked but **orphaned** — wiring needs the owner-gated economy).
- **Net layer** `scripts/net/*`: `world_state` (pure 20 Hz movement truth),
  `combat_arena` (pure ~5s WEG action-window resolution, server seed),
  `persistence_store` (JSON per character), `zone_state` (Director: influence/alert/
  security/events), `territory_model` (org claims/income + a `submit_claim_node`/
  `submit_release_claim` command layer wired into `network_manager`), plus the Wave E pure
  models `security_gate`, `pending_influence_model`, `org_model`, `chat_model`,
  `account_auth_model`, `ambient_sim_model`; `network_manager` + `net_world` (the two **HOT** files).
- **RPC surface (20, all in `network_manager.gd`):** client→server (`any_peer`)
  `submit_input`, `submit_fire_intent`, `register_account`, `submit_skill_raise`,
  `submit_equip`, `submit_claim_node`, `submit_release_claim`, `submit_chat`,
  `submit_heal` (F8 First Aid), `submit_change_zone` (F11 travel); server→client
  (`authority`) `apply_snapshot`, `apply_combat_envelope`, `apply_wallet`,
  `skill_raise_result`, `equip_result`, `claim_result`, `apply_chat`, `auth_result`,
  `heal_result`, `zone_result`. The per-peer snapshot also carries `you` (own wound), each
  player entry's `wound` (F17 nameplates), `npcs` (F16), `zone_list` (F11), and `territory` (F12).
- **Tick model:** 20 Hz movement (per-player speed from species, DIV-0015) + snapshot; ~5s
  combat window (`--combat-window`); ~30s Director tick (`--director-tick`) — folds influence,
  advances ambient NPCs, AND runs natural wound recovery (DIV-0012); 30s autosave; 60s territory
  resource tick (`--resource-tick`). Per-peer maps in `network_manager`:
  `_peer_characters`/`_peer_zones`/`_peer_orgs`/`_peer_axes`/`_peer_rpc_budget`/`_heal_treated`
  (F8 retry gate), a `_record_cache` (evicted on disconnect, F6), and the
  `_territory_influence`/`_pending_zone_influence`/`_ambient` state. ALL per-peer maps are
  cleaned on disconnect.
- **World geometry:** `scripts/world/world_builder.gd` (shared, deterministic seed 1138;
  solo `main.tscn` + `net_world.tscn` build the same Mos Eisley).
- **Data** `data/*.json`: species(9)/skills(76)/weapons(32)/armor(23) are consumed at
  runtime; `zones_clone_wars.json` + `mos_eisley_props.json` (Wave E) drive multi-zone
  routing + set-dressing. `creatures(22)` now have a pure consumer (`creature_spawn_model`
  + smoke) and `vendor_model`/`reputation_model` exist with smokes, but these three are
  **modeled, not yet wired into `net_world`** (no live spawns/shops/rep-on-action — that
  wiring needs owner economy/spawn-rate/value calls). `starships(6)`/`droids(3)` remain
  curated-but-latent (only `content_smoke` reads them). `data/schemas/*` define the full
  persistence/zone/territory/siege contracts, many fields still latent.
- **Design canon** `docs/`: `MULTIPLAYER_FOUNDATION`, `WORLD_SIM_DESIGN`,
  `FACTION_TERRITORY_DESIGN`, `PERSISTENCE_DESIGN`, `DIVERGENCE_LEDGER`. Some are stale
  vs the code — **E1** reconciles them (good first tick).

---

## 8. Known doc staleness (fix via E1)

`MULTIPLAYER_FOUNDATION.md` still says "M1.3 core complete, wiring next" (M1.3b/1.4/1.5
are done; M2.x + Waves C/D aren't reflected). `NIGHTLY_HANDOFF.md` has a self-contradicted
"loop STOPPED at Wave C" paragraph. `NEXT_DECISIONS.md` is a long-resolved early artifact.
`UNATTENDED_LOOP.md` + the backlog Guardrails still carry the stale "`--import` can fail"
caveat. None block development; E1 cleans them up.

---

*Owner: re-enter this loop any time by opening a session and saying:*
**"Read `docs/SESSION_HANDOFF.md` and start the unattended all-day dev loop as it
specifies. Don't ask me questions; keep going."**
