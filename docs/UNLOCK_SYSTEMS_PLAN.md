# Wave F — Owner-Unlocked Systems (Death · Economy · Force)

On 2026-07-01 the owner resolved the long-gated forks (see `memory` / SESSION_HANDOFF §5).
This is the design-grounded, dependency-ordered build plan produced by the
`unlock-systems-design` Workflow (3 system designs + a sequencing pass). Build top-down;
each slice ends at a green `tools/check_project.ps1` (+ a two-process check for `[HOT]`
net slices) and a scoped commit. `[PAR]` = pure-model+test (batchable); `[HOT]` =
`network_manager.gd`/`net_world.gd`, ONE AT A TIME.

## Owner decisions (build to these; do NOT re-litigate)
- **Death/respawn** = partial loss + insurance, **credits kept** (DIV-0006 shape, now with numbers).
- **Economy** = **modest sink, WEG-anchored prices** (~1000 starting credits).
- **Force access** = the **SWG "Village" solution** — a rare, multi-phase, earned unlock questline.
- **Godot** = no real concern (4.6.3 verified healthy); keep building.
- STILL gated (do NOT decide): PvP-consent; siege durations/threshold; LLM-Director-at-launch;
  CP award-rate; visual A1b/P1.

## The critical-path insight
Nothing can kill a player today (combat_arena caps the shared `b1_training_silhouette` at
`SPARRING_MAX_SEVERITY=2`, DIV-0016) and `creature_spawn_model.roll_spawn` is never called.
So **both** lethal Death **and** creature loot-credits are blocked on the SAME missing piece:
**wiring hostile creatures into live combat as a PvE lethal source** — which is NON-gated
(PvP-consent stays gated; hostile PvE does not need it). That wiring (`hostile_npc_model` +
a combat_arena lethal flag + a Director-tick spawner) is the shared root.

## Concrete specs (tunable consts at the top of each model)

### Economy (DIV-0018)
- Each catalog `cost` in `weapons_clone_wars.json`/`armor_clone_wars.json` **IS** the WEG list
  price and the BUY anchor (blaster_pistol 500, hold_out 275, heavy_blaster 750/800, vibroblade
  250, blast_vest 300, blast_helmet 100, …). **No catalog rewrite.**
- `BUY_MARKUP=1.0`; final buy = `round(list × BUY_MARKUP × director_mult × (1−bargain) × (1−rep))`,
  floor 1, clamped never below 0.35 of list (`MAX_TOTAL_DISCOUNT=0.65`).
- `SELL_RATE=0.40` (buy-back at 40% of list — the 60% spread is the churn sink).
- `REP_DISCOUNT={friendly:0.05, allied:0.10}` (via `reputation_model.standing_tier`), stacks after bargain.
- `STARTING_CREDITS=1000` (chargen + default_record parity).
- Loot on a **disabled creature** (not the dummy): `LOOT_CREATURE=[15,45]`, `LOOT_CHARACTER=[40,90]`
  × pack_size; `SALVAGE_CHANCE=0.25` → `SALVAGE_BUNDLE=[20,60]` credits. v1 = credits/salvage only
  (no component-item drops — owner-tunable follow-up). Non-hostile (b1) disable = 0 credits (CP-only, unchanged).

### Death / respawn (DIV-0006 live + DIV-0017 lethal source)
- On the `dead` transition: **credits KEPT**; each equipped item loses `DURABILITY_LOSS_ON_DEATH=10`
  (of 0..100; at 0 = "broken" → halved pools until repaired); `DROP_FRACTION_UNEQUIPPED=0.5` of
  UNEQUIPPED inventory drops to a corpse manifest (equipped weapon+armor never drop).
- **Insurance**: `INSURANCE_PREMIUM=500` → `INSURANCE_CHARGES=3` covered deaths (`sheet.insurance.charges`).
  Covered death: no inventory drop + durability loss reduced to `DURABILITY_LOSS_INSURED=3`; consumes a charge.
- **Respawn**: relocate to nearest secured bind point (Mos Eisley spaceport med bay, `WorldState.SPAWN_POINT`);
  `RESPAWN_WOUND_STATE="wounded"` (sev 2) + the existing `recovery_model` post-death −1D `DEATH_DEBUFF`
  (6 rounds); brief `RESPAWN_TIMER_SECONDS=10` blackout.
- **Lethal gate**: hostile creatures deal REAL (uncapped) damage ONLY where `zones.effective_security=="lawless"`
  (`LETHAL_SECURITY_TIERS=["lawless"]`, tunable to add "contested"). Every starter Mos Eisley zone stays safe;
  death is confined to the Dune Sea + future lawless zones. Sparring behavior byte-identical when `_lethal=false`.

### Force — SWG Village unlock (DIV-0011 access decided)
- A hidden, multi-phase `force_awakening_model.gd` progress track on `sheet.force_unlock` (phase + signal flags),
  fed by deterministic in-play signals (CP spent, skill pips, zone/tense participation, disables, heals given,
  wound recoveries); a rare per-tick manifest chance (`MANIFEST_CHANCE_PER_TICK≈0.02`), a server-wide soft cap
  (`AWAKEN_SERVER_SOFT_CAP≈8`), a final phase-4 awaken roll; on COMPLETE flips `sheet.force_sensitive=true` and
  activates the existing `force_skills_model`. Faithful to Clone Wars scarcity (underground Force-sensitives, not the open Order).

## Ordered slices (S0–S19) — status
- **S0** ✅ DONE `304c015` — ledger rows + plan.
- **S1** ✅ DONE `1cfe6bc` — `economy_model.gd` + smoke.
- **S2** ✅ DONE `c48b16a` — starting-credits 1000 + schema drift close.
- **S3** ✅ DONE `502894e` — `death_penalty_model.gd` + smoke.
- **S4** ✅ DONE `5f6e853` (+ S4-fix `9972acd`: lethal tiers → lawless+contested) — `hostile_npc_model.gd` + smoke.
- **S5** ✅ DONE `4238003` — death schema (`item_durability`/`insurance`/`world_hooks.corpse`).
- **S6** ✅ DONE `f1e8660` — combat_arena per-player lethal flag + hostile targets (byte-identical sparring when off).
- **S7-S10** ✅ DONE `04d39c6` — economy: `_award_credits`/`apply_credits` + `submit_vendor_list`/`submit_buy`/`submit_sell` + client HUD + `economy_flow_smoke`. Two-process verified.
- **S11-S13** ✅ DONE (this slice) — Director-tick hostile spawner (`_advance_hostiles`, lawless+contested) + death/respawn (`_handle_player_death`) + loot on creature disable + `submit_buy_insurance`; `death_flow_smoke` + `--force-hostile` affordance. Two-process verified (death/loot/insurance).
- **S14** ✅ DONE `ca34285` — `force_awakening_model.gd` + smoke.
- **S15** ✅ DONE `2c4ebd8` — Force schema + chargen seed (`sheet.force_unlock`).
- **S16–S19** `[HOT]` Force wiring: signal feeds → Director-tick advancement → completion flip + subtle client notice. **← NEXT**
- **DIV-0019 PvP** (2026-07-02, NEW): pure `pvp_rules_model.gd` (lawless-only same-zone `can_fire`) + combat_arena `resolve_window(seed, pvp_gate)` + network_manager fire-target gating. Build spec ready.

## 2026-07-02 owner rulings (fold these into the wiring)
- **PvP = ZONE-BASED**: lawless = open PvP; secured/contested protected. NEW system beyond S0–S19 —
  add a PvP sub-wave (pure target/consent model + tests, then HOT fire-intent gating to lawless) and a
  **DIV-0019** ledger row before coding. Distinct from creature lethality: PvP-open = lawless ONLY.
- **Corpse = FULL-LOOT in lawless**: other players may loot a dropped corpse in lawless (equipped + credits kept).
  S12/S13 corpse handling allows third-party looting in lawless.
- **Creature lethality = lawless + contested**: `hostile_npc_model.is_lethal_zone` default → `["lawless","contested"]`.
- **Force rarity = rare by default, dials exposed** (soft cap ~8, ~2%/tick).

## Remaining residual knobs (safe-defaulted, NOT blockers)
- Do creature loots ever drop the ITEM, not just credits? (v1 credits+salvage only). Ammo/repair recurring sink? (flavor in v1).
- Force scarcity dials (manifest chance / soft cap / prereqs) — defaulted rare, tunable.

_Source: the `unlock-systems-design` Workflow (2026-07-01). Update slice statuses here as they ship (Fnn +hash)._
