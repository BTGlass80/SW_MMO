# Latent Model Wiring â€” code-level execution plan

Companion to `docs/WAVE_G_BACKLOG.md` and the five shipped-but-latent pure models. This is the
*where/how* seam map (like `docs/design/WAVE_G1_EXECUTION_PLAN.md` was for G1): five pure models are
committed, smoke-green, and wired into `tools/check_project.ps1`, but **not one is called from the live
server**. This doc is the connective wiring plan a mainline engineer follows to bring each into LIVE
play cleanly, one verified slice at a time.

Author: world-sim-designer (DESIGN only â€” no gameplay GDScript here). Clone Wars era (20 BBY, Mos
Eisley). WEG D6 R&E leads; the divergence rows already exist (DIV-0023..DIV-0026 accepted as "pure
model + smoke green, wiring is a follow-up"), so wiring needs **no new ledger row** unless a seam
changes a model's contract â€” flagged inline where that risk exists.

## Ownership split (who executes which seam)
The wiring crosses two engineer domains. This designer plan maps the seams; the code is theirs:
- **godot-netcode-engineer** owns: all new `@rpc` handlers, the corpse registry + Director-tick
  despawn, the telemetry instance + routing, the harvest credit/inventory grant, the status-effect
  server tick, and enqueue sites in `network_manager._resolve_combat_window`.
- **d6-rules-engineer** owns: the two seams that touch the pure combat resolver â€” the armor broken-pool
  `pool_multiplier` in the soak build (`ground_combat_model` / `combat_arena`), and how a poison tick
  composes with the WEG wound ladder (`WoundLadder.escalate`). These carry the DIV-0024/0026 contracts.

## Live-path facts this plan is built on (verified by reading the tree)
- Combat resolves in ~5s action windows: `network_manager._physics_process` calls
  `_resolve_combat_window()` then `_tick_downed()` every `combat_window_seconds` (~L1983â€“1987). The
  action window **is** the round unit â€” poison "per-round" ticks map to per-window ticks.
- The creature-loot hook already fires on a hostile DISABLE inside `_resolve_combat_window` (~L2166â€“2177):
  it fetches `arena.hostile_target_spawn(tkey)`, rolls `EconomyModel.roll_loot(spawn, _server_rng.randi())`,
  grants credits via `_award_credits(shooter, loot_credits)`, then `arena.remove_hostile_target(tkey)`.
- `_handle_player_death` writes the corpse manifest to `record.world_hooks.corpse` with
  `decay_unix: 0.0` (a placeholder) and `full_loot: PvpRules.is_full_loot(tier)` (~L1599â€“1605). No
  loot-back RPC exists â€” `submit_loot_corpse` is genuinely new. The victim's dropped items are already
  removed from their sheet by `DeathPenalty.apply_death`.
- The player soak pool is Strength (`_pools_from_sheet` L153: `player_soak_pool = parse_pool(strength)`);
  the equipped `player_armor` profile + the per-combat `player_armor_quality_pips` are applied inside
  `ground_combat_model` at the soak build (L311â€“325 self-defense, L478â€“491 return-fire), which already
  degrades pips via `ArmorConditionModel.apply_degradation`. **This is where the broken-pool halving belongs.**
- Server owns all RNG (`_server_rng`) and the clock. `TelemetryLog` never touches `Time` itself â€”
  callers pass `ts`, so the server stamps it.
- Existing print sites to route telemetry from: death L1625, buy L1232, sell L1265, loot L2173,
  travel L851, window_resolve L2142.

---

## Seam 1 â€” Harvest (`harvest_model.gd`, DIV-0023): a disabled creature yields a sellable good

### Seam (file Â· function Â· anchor)
`network_manager._resolve_combat_window`, the creature-loot block `if tkey != "" and not looted.has(tkey):`
(~L2166â€“2177), immediately after the existing `_award_credits(shooter, loot_credits)` and before
`arena.remove_hostile_target(tkey)`. The `spawn` dict is already in hand (`arena.hostile_target_spawn(tkey)`).

### Concrete change
1. Gate on `HarvestModel.has_harvest(spawn, _creatures_data)` (most creatures return nothing â€” the
   model already short-circuits cheaply; no extra allocation on non-harvest kills).
2. Resolve the shooter's field-dress pool from their sheet: the model's governing skill is
   `HarvestModel.FIELD_DRESS_SKILL` (`"survival"`). Read `sheet.skills.survival` as an `"xD+y"` string
   (untrained â†’ `null` = 0D, which the model coerces). A tiny helper `_field_dress_pool(character_id)`
   mirrors the existing `_bargain_for(sheet)` pattern.
3. Call `HarvestModel.roll_harvest(D6Rules, spawn, _creatures_data, skill_pool, _server_rng.randi())`.
4. On `result.harvestable and result.quantity > 0`, convert the good to value (see THE GAP below),
   feed a quest event (`_feed_quest_event(shooter, {"type":"harvest","good":result.good,"resource":result.resource,"quantity":result.quantity})`
   for future harvest objectives), and telemetry-log it (Seam 5).

### THE GAP â€” a harvest good is NOT in the buy catalog and has no price
Harvest goods (`gornt_meat`, `krayt_dragon_pearl`, `acklay_chitin`, â€¦) live only in
`data/creatures_clone_wars.json` and carry **no `cost`**. `_buy_catalog` is weapons+armor only, so the
good is neither buyable nor sellable today. The model deliberately returns a *descriptor* and stops â€”
"pricing is deferred to the server." Two clean ways to give it value, both inside DIV-0018:

- **Option A â€” award credits at the point of harvest (mirror salvage).** Add
  `data/harvest_values_clone_wars.json` mapping `good` (or `resource` bucket) â†’ per-unit credit value;
  the server computes `value * quantity * tier_scalar` and grants it through the **existing**
  `_award_credits(shooter, credits)` â€” byte-for-byte the same path `roll_loot`'s `salvage_credits`
  already uses. Zero new persistence surface, zero catalog/inventory/sell changes. Partial/failure
  tiers already reduce `quantity`, so value scales automatically. Anti-arbitrage is a non-issue (the
  good is never buyable, so no buyâ†’sell loop). Lowest risk; ships in the same edit as the roll.
- **Option B â€” grant a carryable inventory good the vendor buys back.** Append `result.good` to
  `sheet.inventory` (like `EconomyModel.buy` does), price it from the same
  `harvest_values` table, and extend `submit_sell` to price non-catalog goods from that table (and to
  refuse re-buying them â€” they are never `vendor_stocked`, so `can_buy` already rejects them). Gives the
  good object-permanence for future crafting / quest turn-ins and feeds the **living-world
  `economy_pulse` / `scarcity_index`** (`docs/design/LIVING_WORLD_DESIGN.md` Â§2/Â§3.3: "selling floods,
  buying drains"). Larger surface: touches inventory persistence + the sell path + a new "resource"
  item class the sell UI must render.

**Recommendation:** ship **Option A first** (it reuses `_award_credits` verbatim and lands harvest in
one clean slice), and schedule **Option B** as the follow-up the living-world resource economy actually
wants. The credit *values* in the table are tunable content (DIV-0018 precedent, not a fork); but the
**shape** â€” instant credits vs a carryable resource good â€” changes what the resource economy can become,
so:

> **OPEN OWNER DECISION (harvest good â†’ value):** A) instant credits at harvest (recommended first cut,
> reuses the salvage path), or B) a carryable inventory resource good sold to vendors (feeds the
> living-world scarcity index, enables crafting/turn-ins later). Not deciding here â€” presenting Aâ†’B as
> the recommended sequence. Whichever is chosen, values live in a new `data/harvest_values_*.json`
> (tunable content, within DIV-0018).

### Reused pieces
`arena.hostile_target_spawn`, `_award_credits`, `_server_rng.randi()`, `_feed_quest_event`,
`_creatures_data`, `D6Rules`, `HarvestModel.has_harvest/roll_harvest`. New: one small value table + one
skill-pool helper.

### Edge cases / risks
- Most creatures have no harvest block â†’ `has_harvest` false â†’ no-op (verified against real data: only
  ~15 carry a block). Guard first so the hot loot path stays cheap.
- Gated goods (krayt difficulty 15) fail for untrained field-dressers â†’ `quantity 0` â†’ grant nothing.
  Correct and intended (the skill matters).
- Determinism: the harvest roll consumes `_server_rng` **after** `roll_loot` already did â€” order is
  fixed (loot first, then harvest), so seeded replays stay stable. Draw the harvest seed as its own
  `_server_rng.randi()` (do not reuse the loot seed) so the two are independent.
- Only the ONE credited shooter per `looted[tkey]` harvests (dedup already guards multi-shooter double
  credit) â€” a single kill yields one harvest.

### Smoke to add â€” `scripts/tests/harvest_wire_smoke.gd` (SceneTree)
Drive a headless server: seed a hostile with a known harvest block into the arena, resolve a window
that disables it with a shooter carrying a survival pool, assert the shooter's credits rose by the
expected table value Ã— quantity (Option A) or that `sheet.inventory` gained the good (Option B), and
that a non-harvest creature grants nothing beyond the existing loot credits. Wire into
`check_project.ps1` next to `Harvest model smoke:`.

### Two-process verification
Server + one headless client; client disables a spawned harvestable hostile in a lawless zone; confirm
`[loot]` then a new `[harvest]` print, the credit/inventory delta on the client sheet, and no
`SCRIPT ERROR`.

---

## Seam 2 â€” Creature special attacks (`creature_special_attack_model.gd`, DIV-0024): poison + restraint

### Seam (file Â· function Â· anchor)
Two anchors in `network_manager`:
- **Enqueue:** `_resolve_combat_window` envelope loop (~L2156â€“2184), in the branch where a player
  shooter is fighting a hostile (`tkey != ""`) **and the hostile's return fire landed a hit this window**.
- **Apply:** a new `_tick_status()` called right beside `_tick_downed()` in `_physics_process`
  (~L1987), so a lone poisoned player with no queued intent still ticks (same reason `_tick_downed` is a
  separate call â€” `_resolve_combat_window` early-returns on zero intents).

### Detecting "the hostile landed a hit"
The envelope carries `state_delta.player_wound_severity`. Cleanest low-touch signal: snapshot the
shooter's `player_wound_severity` before `resolve_window` and compare after (a rise = the hostile's
return fire connected). Cleaner-but-touches-rules option: add a `player_took_hit` bool to the envelope
in `combat_event_envelope_model` (d6-rules-engineer). Recommend the prior-vs-post compare in the net
layer for v1 (no rules-layer change).

### Concrete change
1. On a landed hostile hit, look up the rider: `spawn = arena.hostile_target_spawn(tkey)` â†’
   `CreatureSpecialAttack.special_attack_for_spawn(_creatures_data, spawn)`. If empty, skip.
2. **Poison:** build `poison_schedule(poison_rider, D6Rules, _server_rng.randi())` and store it in a new
   server-only `_status_effects[peer] = {poison_queue:[ticks...], restraint:{...}, source_creature, killer}`.
   The schedule already honors `onset`/`rounds` in absolute round numbers; the server pops the next due
   tick each `_tick_status`.
3. **Restraint:** store `restraint_descriptor(...)` + a resolved `resolve_hold_damage_pool(D6Rules,
   restraint, creature_str_pool)`; mark the peer restrained until an opposed-break check succeeds.
4. **`_tick_status()`** each window, for each poisoned peer: take the next `total` from the queue and
   apply it as damage **through the same wound path a hit uses** â€” feed it to `WoundLadder.escalate(prior_level,
   tick_severity)` (G2), write back the peer's `player_wound_level` / `player_wound_severity` via
   `arena.set_player_combat`, then run the SAME classifier the window uses: if the new severity crosses
   `DISABLED_SEVERITY`, route through `_handle_player_downed` / `_handle_player_death` exactly as
   `_resolve_combat_window` does (sev 5 â†’ death, sev 3â€“4 â†’ downed). Credit the `source_creature`'s
   takedown only once (reuse the `credit_killer` discipline â€” the creature isn't a peer, so `killer_peer`
   stays 0, matching a bled-out death).

### Composition with G1 (downed tiering) and G2 (wound escalation)
- Poison ticks route through `WoundLadder.escalate` (G2) so venom **accumulates** up the ladder like any
  hit â€” it does not overwrite highest-hit-wins.
- Because poison damage can cross `DISABLED_SEVERITY`, a poison tick can put a player **downed**
  (G1 `_handle_player_downed`). If it reaches sev 5 it kills. This must reuse the G1 classifier, not a
  parallel one, or a poisoned player could be softlocked outside the downed/yield/bleed-out system.
- `0D` paralytic venom (`rock_wart`) yields `total 0` â€” it applies **no HP**; treat it as a status.
  Whether a 0D tick applies a real action/movement lock (paralysis) is a design call (below).

### Restraint composition
Restraint is an opposed-break descriptor, not damage. Applying it live means: while restrained, add
`dex_penalty` (e.g. `stalker_lizard` "2D") to the player's action pools and optionally block movement,
until an opposed brawling/STR break succeeds each round. The dex-penalty application lives in the arena
pool build (`combat_arena._pools_from_sheet` / the per-window pool assembly), keyed off
`_status_effects[peer].restraint` â€” a d6-rules-engineer + netcode seam. Recommend restraint be a
FAST-FOLLOW *after* poison lands, since poison reuses the existing damage/ladder path (lower risk) while
restraint introduces a new per-window pool modifier + break-check loop.

### Reused pieces
`arena.hostile_target_spawn`, `arena.set_player_combat`, `arena.player_state`, `WoundLadder.escalate`,
`_handle_player_downed`, `_handle_player_death`, `_server_rng`, `D6Rules`, the whole special-attack
model. New: the `_status_effects` dict + `_tick_status()` + its clear-on-death/respawn/disconnect hooks.

### Edge cases / risks
- **Highest coupling of the five** â€” it touches the live wound ladder, the G1/G2 classifier, and (for
  restraint) the arena pool build. Land it LAST.
- Clear `_status_effects[peer]` in `_handle_player_death` (respawn wipes lingering poison), on
  disconnect (`_on_peer_disconnected` alongside `_downed.erase`), and when the player leaves the zone.
  A lingering poison queue against an absent peer would tick into nothing or, worse, re-trigger death.
- Determinism: each `poison_tick` derives its own per-round seed off the server seed; store the SEEDED
  schedule at enqueue so a mid-fight save/restore doesn't re-roll it.
- Persistence: `_status_effects` is RAM-only (like `_downed`). But combat damage IS persisted via
  `apply_combat` â†’ `sheet.wound_state`, so a logout mid-poison leaves the player at their last applied
  wound (acceptable; the queue simply stops â€” do NOT try to persist the schedule in v1).
- **OPEN (design, not owner-fork):** does poison alone advance a player to the **death** tier (sev 5)
  autonomously, and does a 0D paralytic apply a real action-lock? Recommend v1: poison escalates through
  the ladder normally (can down and can kill, routed through G1's bounded bleed-out so it never
  softlocks); 0D paralytic applies a one-window action-skip status only if restraint lands in the same
  slice, else it is a no-op flavor tick. Flag to owner only if they want poison to be capped at downed
  (never auto-lethal) for retention.

### Smoke to add â€” `scripts/tests/special_attack_wire_smoke.gd` (SceneTree)
Headless server: enqueue a known poison schedule (e.g. `spor_crawler` 5DÃ—3) on a peer, run N
`_tick_status` windows with a seeded `_server_rng`, assert the peer's severity climbs each due round,
that a schedule that crosses `DISABLED_SEVERITY` routes into `_downed` (not an unhandled state), and that
death/respawn clears `_status_effects`. Restraint: assert a restrained peer carries the dex penalty until
a break succeeds. Wire next to `Creature special-attack model smoke:`.

### Two-process verification
Server + client; client engages a poison-carrying hostile (e.g. `hitcher_crab`) in lawless; confirm the
poison ticks land over successive windows, the client HUD shows the deepening wound, and a lethal poison
routes through the downedâ†’bleed-out/yield path (never a softlock). No `SCRIPT ERROR`.

---

## Seam 3 â€” Corpse decay + third-party loot (`corpse_decay_model.gd`, DIV-0025)

### Seam (file Â· function Â· anchor)
Three anchors in `network_manager`:
- **Stamp the clock:** `_handle_player_death`, the corpse-manifest write (~L1602). `decay_unix` is
  `0.0` today â€” change it to the server clock `Time.get_unix_time_from_system()`.
- **Registry:** at the same write, index the corpse so the Director tick doesn't scan every record.
- **RPC + despawn:** a new `submit_loot_corpse` RPC, and a `_despawn_expired_corpses()` call added to
  the Director-tick block in `_physics_process` (~L1996â€“2001, beside `_advance_hostiles` / `_save_world_state`).

### Concrete change
1. **Clock stamp:** `world_hooks.corpse.decay_unix = Time.get_unix_time_from_system()`. The pure model
   deliberately does not read `decay_unix`; the server derives `elapsed_seconds = now - decay_unix` and
   passes it in. This keeps the model clockless and the server authoritative.
2. **Registry `_corpses`:** `character_id â†’ {zone_id, pos, decay_unix, security_tier}` written when a
   death produces a non-null manifest (skip when `corpse == null`). This lets both the despawn tick and
   the loot RPC find corpses (incl. corpses of players who have since logged off â€” their record still
   holds the manifest).
3. **`submit_loot_corpse(target_character_id)` (`@rpc("any_peer", "reliable")`):**
   - Rate-limit (`_rate_ok`), resolve the looter's `character_id`.
   - Load the target record; read `world_hooks.corpse`. Reject if the looter is not in the corpse's
     `zone_id` or not within a loot radius of `corpse.pos` (mirror the near-check other proximity code
     uses; server owns positions).
   - `elapsed = now - corpse.decay_unix`; `result = CorpseDecay.loot_for_third_party(manifest,
     tier, elapsed)`.
   - On `result.looted`: append `result.items` to the looter's `sheet.inventory` (same append shape as
     `EconomyModel.buy`), `_cached_save` the looter, then **null the victim's manifest**
     (`world_hooks.corpse = null`) and erase `_corpses[target]` so it cannot be double-looted; save the
     victim record. `result.credits` is always 0 (DIV-0006 credits kept) â€” never transfer credits.
   - Reply `loot_corpse_result.rpc_id(sender, {ok, items, reason})`; reasons come straight from the model
     (`no_corpse` / `protected` / `expired` / `looted`), so contested corpses correctly reject a third
     party (owner-retrieval is a separate follow-up, out of scope here).
4. **`_despawn_expired_corpses()`:** iterate `_corpses`; for each, if
   `CorpseDecay.is_expired(tier, now - decay_unix)`, null the manifest on that record + erase the index
   entry. Runs on the Director cadence (coarse is fine â€” the model's boundary is inclusive).

### Reused pieces
`CorpseDecay.loot_for_third_party/is_expired`, `_cached_load/_cached_save`, `_peer_zones`, `_rate_ok`,
the existing manifest shape (already exactly what the smoke asserts). New: `Time` at the one stamp site,
the `_corpses` index, two RPC endpoints (request + reply), and one Director-tick call.

### Edge cases / risks
- **Restart continuity:** `decay_unix` is wall-clock, so a corpse keeps aging across a server restart
  (good). Rebuild `_corpses` on boot by scanning persisted records for a non-null `world_hooks.corpse`
  (a one-time scan in the world-state restore path), OR accept that only the despawn tick lazily reaps
  offline corpses on next load. Recommend the boot scan for correctness.
- **Full-loot gate is already enforced by the model** via the manifest's own `full_loot` stamp (lawless
  only). The server does not re-derive it â€” pass tier and let the model agree with its own stamp.
- **Double-loot race:** two looters in the same window â€” the server is single-threaded per tick;
  null-the-manifest-then-save inside the RPC handler makes the second loot see `no_corpse`. Safe.
- Looting NEVER mutates the source (the model returns a defensive copy) â€” the server owns the null-out.
- Owner self-retrieval of a contested corpse (2h window) is intentionally out of scope; the model
  returns `protected` for a third party, which is the correct v1 answer.

### Smoke to add â€” `scripts/tests/corpse_loot_wire_smoke.gd` (SceneTree)
Headless server: stamp a lawless corpse manifest with `decay_unix = now`, call the loot handler as a
second character in-zone, assert the items landed in the looter's inventory and the victim manifest is
nulled + de-indexed; a contested corpse rejects (`protected`); an expired corpse rejects (`expired`) and
is reaped by `_despawn_expired_corpses`. Wire next to `Corpse decay model smoke:`.

### Two-process verification
Three clients (or two + a scripted second identity): A is killed by a hostile in lawless (drops a
corpse); B loots it and gains A's dropped items; confirm A cannot be re-looted; advance past the window
and confirm despawn. No `SCRIPT ERROR`.

---

## Seam 4 â€” Armor broken tier + repair sink (`armor_repair_model.gd`, DIV-0026)

Two independent halves â€” a **combat-side pool halving** (rules seam) and a **vendor repair RPC**
(netcode seam). They can ship separately.

### 4a. Broken-pool halving (d6-rules-engineer)
**Seam:** the soak build in `ground_combat_model` where `player_armor_quality_pips` is read and armor is
applied to the soak pool (L311â€“325 self-defense, L478â€“491 return-fire). This is the single place the pip
level already gates armor effectiveness.
**Concrete change:** after assembling the armored soak base, multiply the pool by
`ArmorRepair.pool_multiplier(player_armor_quality_pips)` (1.0 normal, 0.5 when the pip is at the
condition floor). The model owns the boolean + the exact factor; the resolver just applies it. Do it in
the pure resolver (not `combat_arena._pools_from_sheet`) because the *pip level* is per-combat state that
lives in `ground_combat`/arena `state`, not in the sheet at `_pools_from_sheet` time â€” pre-scaling in
`_pools_from_sheet` (L153) would not know the live pip. Note the DIV-0026 contract: broken = the
condition FLOOR (âˆ’6), not a separate durability=0 axis.
**Risk:** this changes live TTK when armor is broken â€” re-run `tools/balance_probe.gd` after. It also
composes with wound-penalty scaling already applied to soak; apply the multiplier to the *armored* base
before wound penalties so the two stack in the documented order.

### 4b. `submit_repair_armor` vendor RPC (godot-netcode-engineer)
**Seam:** new `@rpc("any_peer", "reliable") submit_repair_armor(item_key)` next to `submit_buy` /
`submit_sell` (~L1206â€“1269) â€” repair is the same vendor interaction class (a credit sink).
**Concrete change:**
1. Resolve the record + sheet; resolve the item's current pip level and its list `cost` from the
   catalog (`_buy_catalog[item_key].cost`).
2. `cost = ArmorRepair.repair_cost(current_pips, ArmorRepair.MAX_QUALITY_PIPS, list_cost)` â€” a full
   rebuild to the ceiling, priced off `EconomyModel.sell_price` (reuses the shipped economy dial;
   `buy_floor` already keeps rebuy strictly above sell so dump-and-rebuy never dominates repair).
3. If the player can afford it: `_award_credits(sender, -cost)` (the existing single credit-mutation
   point, floored at 0), then write back the pip via `ArmorRepair.restore(current_pips, MAX)` to the
   durable pip source, `_cached_save`, and `_push_sheet`.
4. Reply `repair_result.rpc_id(sender, {ok, item_key, cost, credits, quality_pips})`; reasons:
   `unknown_item`, `not_broken`/`no_op` (cost 0 â†’ already at ceiling), `cannot_afford`, `unpriced`
   (list_cost â‰¤ 0 â†’ model returns cost 0).

**Persistence nuance to VERIFY before wiring:** where does `player_armor_quality_pips` durably live?
It appears in the arena combat-state persist list (`combat_arena` L204) and in `apply_combat`. Repair
must write to whatever the *pool build reads* (Seam 4a) so a repaired pip actually restores soak next
combat, and it must survive relogout. If the pip is currently only in transient combat state, wiring
repair also requires persisting it onto the sheet (a small schema addition â€” note it, and if it changes
the persisted sheet shape, add a DIV/schema note first).

### Reused pieces
`ArmorRepair.pool_multiplier/repair_cost/restore`, `EconomyModel.sell_price`, `_award_credits`,
`_cached_save`, `_push_sheet`, the vendor RPC scaffolding. New: one RPC pair + the pip write-back.

### Edge cases / risks
- Unpriced gear (contraband / faction-issued, `cost 0`) â†’ `repair_cost` returns 0 â†’ reject as
  `unpriced` (mirrors buy/sell). No free repairs.
- Partial repair (`target < MAX`) is supported by the model but v1 can expose only full-rebuild-to-MAX
  to keep the RPC one-shot; partial targets are a later UI nicety.
- The 4a halving and 4b repair are independent â€” 4b (a pure credit sink, no combat change) is the
  safest to ship first; 4a changes combat math and needs the balance re-probe.

### Smoke to add â€” `scripts/tests/repair_wire_smoke.gd` (SceneTree)
Headless server: set a character's armor pip to the floor; call the repair handler; assert credits
dropped by `repair_cost(floor, MAX, list)`, the pip restored to MAX, and the pool build now returns the
un-halved soak; assert an unpriced item rejects and an already-full item is a no-op (cost 0). Wire next
to `Armor repair model smoke:`.

### Two-process verification
Client degrades armor to broken in lawless combat (soak visibly halved), travels to a vendor, repairs;
confirm the credit debit, the restored pip on the sheet, and restored soak in the next exchange.

---

## Seam 5 â€” Structured telemetry (`telemetry_log.gd`): route six event types from live print sites

### Seam (file Â· function Â· anchor)
`network_manager`: instantiate one server-side `TelemetryLog` in the server-start path (`start_host` /
the `Mode.SERVER` branch of `_start`/`start_server`, near `_server_rng.randomize()` ~L206), then add one
`_telemetry.log_event(...)` beside each of the six existing `print(...)` sites. The server owns the
clock, so every event carries `ts = Time.get_unix_time_from_system()`.

### Concrete change (the six routes)
| Event | Print site | Suggested fields (beyond `ts`) |
|---|---|---|
| `death` | `_handle_player_death` L1625 | character_id, zone, security tier, killer, durability_loss, dropped_count, insured, credits_kept |
| `buy` | `submit_buy` L1232 | character_id, item_key, price, credits_after |
| `sell` | `submit_sell` L1265 | character_id, item_key, price, credits_after |
| `loot` | `_resolve_combat_window` L2173 | character_id, source_creature, credits, salvage_credits (+ harvest good/qty once Seam 1 lands) |
| `travel` | `submit_change_zone` L851 | character_id, from_zone, to_zone, security |
| `window_resolve` | `_resolve_combat_window` L2142 | window, shot_count, dummy_severity |

Add `_telemetry = TelemetryLog.new()` (default `user://telemetry/events.jsonl`). Guard every call so a
telemetry failure never breaks the server â€” the model already degrades to a safe `false` no-op on a bad
open, so no try/guard is needed beyond a null-check on `_telemetry`.

### Reused pieces
`TelemetryLog.new/log_event`, the six existing print sites (leave the prints â€” telemetry is additive),
`Time` for `ts`. New: one member + six one-line calls.

### Edge cases / risks
- **Safest and most independent of the five** â€” writes only under `user://`, never touches combat/
  economy state, and the writer degrades to a no-op on any I/O failure.
- Determinism: the writer is deterministic given identical fields; `ts` is the only nondeterministic
  field (wall clock) and is caller-supplied, so tools that need reproducibility can filter it.
- It is the **enabler** for tuning the other four (death rate, economy flow, TTK) â€” this is why it ships
  first.

### Smoke to add
Coverage already exists in `telemetry_log_smoke.gd` for the writer. Add a thin route-check in a server
flow smoke (or extend `economy_flow_smoke` / `death_flow_smoke`): after a buy/sell/death, assert the
server's `_telemetry.tail(n)` contains the matching typed event. No new gate entry strictly required,
but a `telemetry_wire_smoke.gd` keeps the routing pinned.

### Two-process verification
Run a normal two-process session (buy, sell, travel, a kill, a death); confirm `user://telemetry/events.jsonl`
contains one JSONL line per action with the right `type` and fields. No `SCRIPT ERROR`.

---

## Recommended BUILD ORDER (most value / least risk first)

1. **Telemetry (Seam 5)** â€” FIRST. Fully independent, `user://`-only, degrades safely, and it is the
   measurement instrument for everything after (you cannot tune harvest value, repair cost, or poison
   TTK without it). One member + six one-liners. Land alone.
2. **Armor repair RPC (Seam 4b)** â€” a clean credit sink that reuses the vendor scaffolding + shipped
   economy dial; no combat-math change. Independent. (Defer the 4a pool-halving to sit with the combat
   work in step 5's neighborhood so the balance re-probe runs once.)
3. **Harvest (Seam 1)** â€” reuses the live loot hook + `_award_credits` (Option A). Independent of the
   others; gated on the ONE owner decision (goodâ†’value). Ships in one edit once that is answered.
4. **Corpse loot (Seam 3)** â€” self-contained (new RPC + registry + despawn tick); needs only the live
   death path, which exists. Medium surface (a boot-scan for restart continuity) but no combat coupling.
5. **Special attacks (Seam 2) + armor pool-halving (Seam 4a)** â€” LAST, together. These are the only
   seams that touch the live combat resolver + the G1/G2 wound classifier; landing them adjacent means a
   single `balance_probe` re-run and one careful review. Highest risk; do not front-load.

**Independent vs coupled:**
- **Independent** (net/data only, no combat-resolver change): Telemetry (5), Repair RPC (4b), Harvest
  (1, Option A), Corpse loot (3).
- **Coupled to the combat resolver / wound ladder** (rules + netcode, needs the balance re-probe):
  Special attacks (2), Armor pool-halving (4a).

## OWNER DECISIONS flagged (not decided here)
1. **Harvest good â†’ value conversion (Seam 1):** instant credits (recommended first) vs a carryable
   inventory resource good the vendor buys back (feeds the living-world scarcity index; enables crafting/
   turn-ins). Presented Aâ†’B as a sequence; the values themselves are tunable content within DIV-0018.
2. **(Design flag, lighter) Poison lethality (Seam 2):** may poison alone drive a player to the death
   tier (routed through G1's bounded bleed-out, recommended) or should it cap at *downed* for retention?
   And should a 0D paralytic apply a real action/movement lock? Recommend the former (compose with the
   shipped ladder); flag to owner only if they want a poison-lethality cap.

Every other numeric (harvest table values, repair scalar, decay windows, poison schedules) is already
tunable content or fixed by an existing DIV row â€” no new owner fork.

## Status
NOT STARTED (plan only). All five models are shipped, smoke-green, and gate-wired; none is called from
the live server. Execute in the build order above; the two combat-coupled seams (2, 4a) belong to the
d6-rules-engineer + godot-netcode-engineer and should trigger a `tools/balance_probe.gd` re-run and the
seam-audit review.
