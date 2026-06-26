# SESSION HANDOFF — start here in a clean session

**Purpose:** this is the single entry point for a *fresh* Claude Code session that is
taking over **unattended, all-day, parallelized** development of the SW_MMO prototype.
Read this top to bottom, then execute **§1 First actions**. You should not need to ask
the owner anything to begin — the work is queued and the guardrails are explicit.

Written 2026-06-25 after a full 5-reader codebase audit; **reconciled through follow-up
F65** (Wave E + F1–F65 complete, RPC surface 21, 59 smokes, DIV-0001..0016). If git HEAD has
moved past the F65 commit, trust the code + `docs/UNATTENDED_BACKLOG.md` Log over this file.

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
  long **follow-up series F1–F65** (each gate-green + two-process verified) that grew the slice
  into a genuinely playable MMO and then hardened it. Highlights:
  - **Wound/medical loop (F7–F10, F17, F19):** natural self-recovery (DIV-0012) + First Aid by a
    medic (DIV-0013, reaches incapacitated/mortally) + a colour-coded own-condition HUD + other
    players' condition on their nameplates + "First-Aid the nearest WOUNDED ally" targeting.
  - **Multi-zone world (F11–F14):** in-session zone TRAVEL (DIV-0014, persisted) + zone-scoped
    player VISIBILITY (you only see same-zone players) + the org/territory HUD; all zone-scoped.
  - **Per-species movement speed (F15, DIV-0015):** wired the orphaned derived-stats model.
  - **Combat correctness (F18):** equipped-weapon SKILL drives the attack pool + melee `STR+ND`
    damage (wires derived-stats melee) — latent fix, melee is acquirable only once an economy exists.
  - **Social (F2, F20, F22, F25–F27):** zone say/emote + global ooc + ORG chat (cross-zone) + a **GUI chat
    LineEdit** with a `/say //ooc //org //emote` slash parser AND a game-command bar
    (`/raise /travel /heal /claim /release /who /help` via `chat_model.parse_command`).
  - **Character readouts (F23, F24):** in-combat CP/FP boost readout + a toggleable (V) character-sheet
    panel (attributes/skills/gear/wallet), pushed on register + skill-raise + equip + CP award (F30).
  - **Visibility (F9, F12, F16, F17, F29):** condition/org HUDs (org HUD shows OWN-org vs TOTAL zone
    claims) + RENDERED ambient NPCs + wound nameplates.
  - **Correctness-audit pass (F28–F32):** reset the First-Aid retry gate on full heal (F28); org
    own-vs-total claim count (F29); refresh the sheet on CP award (F30); **the WEG "out" state** — an
    incapacitated/mortally/dead character can neither act (F31, `combat_arena`) nor move (F32,
    `world_state.set_input`'s `can_act`), gated on `wound >= DISABLED_SEVERITY (3)`. F31/F32 are
    faithful-WEG but currently **LATENT** (nothing damages a player in live play yet — the wound loop
    becomes reachable only when the owner-gated PvP / hostile-NPC / death path lands).
  - **Robustness/guards (F4–F6, F10, F14, F21):** record-cache eviction on disconnect; FIVE [HOT]
    composition guards (claims/auth/First Aid/zone/chat) locked into the gate.
  - **Combat-depth + medical arc (F33–F54):** the owner-directed **non-lethal medical loop** (F44,
    DIV-0016 — the B1 remote returns real fire capped at Wounded(2), so the wound→recovery→First-Aid
    loop is reachable end-to-end) + a full WEG tactical layer — two-way return fire (F45), Perception
    initiative (F48), cover / active-dodge / full-dodge stances (F50–F52), and target/condition HUDs
    (F46/F47); plus faction legibility (rank authority + allegiance + online org count, F34–F37/F53)
    and chat/`/help`+keybinds UX (F39–F42/F54).
  - **WEG-fidelity + durability + hardening pass (F55–F65):** the **Force-Point DAMAGE-doubling fix**
    (F55 — FP doubled attack/dodge/soak but not damage) and the **armor pip-only "+2" parse fixes**
    (F60 + F64 — TWO parse sites: `d6_rules.parse_pool` read "+2" as 2D, and `armor_condition_model`
    then dropped a "+2" armor entirely; both now treat a no-"D" token as +N pips, restoring WEG soak);
    the **full restart-durable persistent world** — atomic character saves + crash recovery (F56),
    and a single `world_state.dat` carrying faction-influence/Director/pending (F58), org claims +
    treasuries (F59), and claim-gating territory-influence (F61); **auth hardening** — an
    un-registered peer is barred from entering the world (F57) AND from chat (F62); earn-loop gate
    coverage (F63, kills→claim threshold); and **combat-envelope zone-scoping** (F65 — combat was
    broadcast galaxy-wide; now same-zone only, like chat). All gate-green + two-process verified.
- **Green bar (current truth):** the **full** `tools/check_project.ps1` passes — **59
  GDScript smokes** + 7 python + import + launch (green at every commit). DIV-0001..0016.
- **STATUS: Wave E + the F1–F65 follow-ups are DONE; the prototype is a playable, populated,
  traversable multi-zone MMO** (chargen/progression → species-paced movement → combat (CP/FP/cover/
  dodge/initiative) → full visible non-lethal medical loop → equip → travel/presence → org
  claims+treasury, restart-durable → say/ooc/org chat + command bar w/ GUI input → character-sheet
  panel → news → rendered NPCs), all gate-guarded. **The unblocked, non-owner-gated backlog is DRY
  and the frontier has been EXHAUSTIVELY audited** — beyond the F33–F54 depth arc, the F55–F65 pass
  fixed two real WEG-fidelity combat bugs (the Force-Point damage doubling F55; the armor "+2"
  misparse at BOTH parse sites F60+F64), made the player-driven world fully restart-durable
  (F56/F58/F59/F61), hardened auth (F57/F62), and zone-scoped combat visibility (F65). The
  remaining non-gated frontier is verified exhausted across **two survey Workflows + an exhaustive
  space/presentation/core audit + direct RPC/RNG/data/broadcast audits** — every angle now clean or
  fixed. The substantive remainders cluster behind the **economy/vendor SPEND side** (unlocks melee
  + the orphaned creature_spawn/vendor/reputation models) and the parked owner forks (§5: siege,
  Force access, PvP-consent, **the LETHAL death/damage loop that lifts the DIV-0016 sparring cap and
  makes F31/F32 reachable**, death-penalty numbers, CP rates, the starting cp_wallet chargen-balance,
  LLM-Director, visual A1b/P1). A fresh session should **confirm green and HOLD for an owner steer**,
  not invent owner-gated scope. (Full history: `docs/NIGHTLY_HANDOFF.md` + the
  `UNATTENDED_BACKLOG.md` Log — F1–F65.)

---

## 1. First actions (do these now, in order)

1. **Orient:** read `CLAUDE.md`, this file, and `docs/UNATTENDED_BACKLOG.md` (the Wave E
   queue + Guardrails + the F1–F65 Log). Skim `docs/DIVERGENCE_LEDGER.md` (DIV-0001..0016).
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

### 5a. What each gate UNLOCKS (already built + tested — ROI map for the owner)

The non-owner-gated backlog is DRY; the loop has built the substrate ahead of the gates.
Each owner decision below makes a chunk of **already-built, already-gate-tested** work
**reachable in live play**. Highest leverage first. (This is a prioritization aid — the loop
does NOT pre-decide any of these.)

- **Player-damage path** — ✅ **PARTIALLY UNLOCKED (F44, owner-directed 2026-06-25).** The
  NON-LETHAL portion is now LIVE: the B1 training remote returns real fire capped at Wounded(2)
  (DIV-0016), so the whole wound/medical loop is reachable and verified end-to-end — `wound_ladder`
  (E2), natural recovery (E3/F7), First Aid (F8), condition HUD (F9), wound nameplates (F17), the
  "out" gates (F31/F32, untriggered by the cap). A player now spars, gets stunned/wounded, and
  recovers (self or medic). STILL GATED: the **LETHAL** path — real death (incapacitated/mortally/
  dead), **death-PENALTY numbers** (loot %, durability, insurance, respawn timer/location; DIV-0006
  shape decided, numbers gated), **PvP-consent**, and hostile-NPC lethality. Deciding those lifts
  the SPARRING_MAX_SEVERITY cap for real-stakes encounters and wires death/respawn.
- **Economy / vendor** (needs: prices, spawn rates, item values) — unlocks three modeled-and-
  smoked-but-orphaned systems: `vendor_model` (E11), `creature_spawn_model` (E10),
  `reputation_model` (E12); plus **melee** (F18 already makes melee pools/`STR+ND` damage correct,
  latent until weapons are acquirable) and inventory beyond the chargen kit.
- **Force / Jedi ACCESS policy** (rarity, how one becomes force-sensitive) — unlocks
  `force_skills_model` (E6 — the off-by-default data hook is already built; only the access
  economy is gated).
- **Siege durations / capture threshold** — unlocks the `siege_state` schema state machine on top
  of the live territory-claim substrate (claims + treasury income + rank authority: E9/E23/F29/F34,
  validated F38).
- **CP award-RATE tuning** (DIV-0007 dual-track mechanic already live) — only the numbers gate how
  fast progression/prestige accrue; the earning + spending paths work (C4/F30).
- **LLM Director flavor / visual A1b+P1** — additive polish on a working deterministic baseline.

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
  `persistence_store` (atomic `.tmp`→rename JSON per character + crash-recovery, F56; PLUS a single
  server-global `world_state.dat` carrying the restart-durable Director/territory state — faction
  influence + pending F58, org claims + treasuries F59, claim-gating territory-influence F61),
  `zone_state` (Director: influence/alert/security/events; `to_dict`/`apply_persisted` for the
  world record), `territory_model` (org claims/income + `to_dict`/`apply_persisted` + a `submit_claim_node`/
  `submit_release_claim` command layer wired into `network_manager`), plus the Wave E pure
  models `security_gate`, `pending_influence_model`, `org_model`, `chat_model`,
  `account_auth_model`, `ambient_sim_model`; `network_manager` + `net_world` (the two **HOT** files).
- **RPC surface (21, all in `network_manager.gd`):** client→server (`any_peer`, 10)
  `submit_input`, `submit_fire_intent`, `register_account`, `submit_skill_raise`,
  `submit_equip`, `submit_claim_node`, `submit_release_claim`, `submit_chat`,
  `submit_heal` (F8 First Aid), `submit_change_zone` (F11 travel); server→client
  (`authority`, 11) `apply_snapshot`, `apply_combat_envelope`, `apply_wallet`,
  `skill_raise_result`, `equip_result`, `claim_result`, `apply_chat`, `auth_result`,
  `heal_result`, `zone_result`, `apply_sheet` (F24 character-sheet panel, re-pushed on
  register/skill-raise/equip/CP-award). The per-peer snapshot also carries `you` (own
  wound + wound_penalty (F9/F46) + CP/FP boost (F23)), each player entry's `wound` (F17 nameplates) + `axis`
  (F36 faction allegiance on nameplates/`/who`), `npcs` (F16),
  `zone_list` (F11), and `territory` (F12, with `claims_in_zone` tagged by `org_id` (F29)
  + the viewer's `your_rank`/`rank_claim`/`rank_city` territory authority, F34). The server
  caches `_peer_ranks` alongside `_peer_orgs`/`_peer_axes` (F34).
  `submit_input` zeroes movement for an incapacitated player (F32). Headless client
  affordances now include `--autowalk`'s `[pos]` readout (F32 net-movement test).
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
  `FACTION_TERRITORY_DESIGN`, `PERSISTENCE_DESIGN`, `DIVERGENCE_LEDGER` — reconciled to the
  shipped state by **E1** (no longer stale; see §8).

---

## 8. Roadmap docs — reconciled (E1, done)

E1 reconciled the roadmap/reference docs to the shipped state, so they are CURRENT — do not
re-reconcile them:
- `MULTIPLAYER_FOUNDATION.md` — M1.1–M1.5 + M2.0–M2.2 + Waves C/D/E COMPLETE, with a
  backlog-dry / owner-gated-next status.
- `NIGHTLY_HANDOFF.md` — the full F1–F65 narrative; the old self-contradicted "loop STOPPED
  at Wave C" line was removed.
- `NEXT_DECISIONS.md` — archived early artifact (long resolved).
- `UNATTENDED_LOOP.md` + the backlog Guardrails — the stale "`--import` can fail" caveat was
  corrected (A0's colormap fix is live; the full `check_project.ps1` is the bar).

For the LIVE state trust §0 above + the `UNATTENDED_BACKLOG.md` Log (newest entries first).

---

*Owner: re-enter this loop any time by opening a session and saying:*
**"Read `docs/SESSION_HANDOFF.md` and start the unattended all-day dev loop as it
specifies. Don't ask me questions; keep going."**
