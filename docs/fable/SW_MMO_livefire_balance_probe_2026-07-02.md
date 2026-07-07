# SW_MMO â€” Live-Fire & Balance Probe Findings (Fable, 2026-07-02)

**What was run, on the review snapshot, with real Godot 4.6.3 (Linux headless):**
1. The full gate equivalent (reported previously: 72/72 smokes + 7/7 python, green).
2. A **real two-process session** â€” dedicated server + headless bot client (`--quickstart --zone tatooine.dune_sea --autofire`, server `--force-hostile hitcher_crab`). The whole Wave-F loop executed: connect â†’ chargen â†’ lawless assignment â†’ hostile spawn â†’ combat â†’ loot credits â†’ a live wound with `-1D` condition push. The multiplayer core runs unmodified cross-platform.
3. A **Monte Carlo probe through the live engine** (`tools/balance_probe.gd`, included) â€” ~57k action windows through the real `CombatArena â†’ ground_combat_model â†’ d6_rules` path (not a reimplementation), quickstart human (3D attack, 4D pistol, blast vest) vs four real hostiles, two tactical profiles, plus campaign sims under both the LIVE `maxi()` accumulation and the unwired `escalate()` model.

---

## A. Live-fire findings (things only a running server shows)

**A-1. Cross-zone dummy fallback + dummy-farming faucet.** Between a hostile's death and its next Director-tick respawn, the bot's fire intents fell through to the **shared training dummy** â€” server logged Dune Sea shots resolving against the spaceport's B1 silhouette, `training target disabled â€” respawned`, and the shooter collecting the disable rewards. Two distinct problems:
- The fallback target on hostile-death should be **no target / hold fire**, not the global dummy (a lawless-zone player is shooting an object in another zone).
- Dummy disables award `COMBAT_CP_REWARD` + zone influence + territory influence + a Force-awakening `disables` signal (`_resolve_combat_window`: `target_down = tkey=="" and dummy_disabled` takes the same reward branch as real kills). One shared, zero-risk, every-window-killable dummy is now an **infinite CP/influence faucet** competing with risk-priced content. Recommend: dummy disables pay reduced/zero influence and cap CP (or keep CP for onboarding but drop the influence/Force feeds), and make the fallback explicit-none.

**A-2. `reset_target()` zeroes `_window_index`.** Server logs show window numbering restarting after every dummy reset â€” the global window counter (stamped into every envelope) resets whenever anyone disables the dummy. Cosmetic today, but it corrupts any future envelope-ordering/replay tooling. Move `_window_index = 0` out of `reset_target()`.

---

## B. Data-quality: prose stat strings silently degrade (add a resolved-pool smoke)

Resolved hostile pools straight from `HostileNpc.attack_pools_from_creature` on live data:

| creature | listed atk | **resolved atk** | listed dmg | **resolved dmg** | soak |
|---|---|---|---|---|---|
| hitcher_crab | 1D | **3D** (fallback) | STR+1D | 2D âœ“ | 1D |
| glim_worm | 1D | **3D** (fallback) | "opposed (brawling vs â€¦)" | **0D** | 1D |
| tusken_warrior | 3D | 4D (skill lookup) | STR+1D | 4D âœ“ | 3D |
| acklay | 3D+1 | 6D | STR+2D | 7D âœ“ | 5D |
| merdeth | 1D | 8D | STR+2D | 10D âœ“ | 8D |

- **glim_worm is a zero-threat decoy**: its prose damage string resolves to **0D** â€” it can spawn as a "lethal hostile" that cannot ever deal damage. (`mip_swarm`'s "2D auto-damageâ€¦" and `spor_crawler`'s special text are the same rot class.)
- The **to-hit fallback masks missing skill wiring**: several creatures' listed attack values never reach the resolver (skill key absent/mismatched â†’ silent 3D default). Note merdeth/acklay resolving atk **above** their listed value â€” the resolver is reading a different skill entry than the display stat; whichever is intended, the data and resolver currently disagree silently.
- **Fix shape:** a `content_smoke` extension asserting, for every `hostile:true` creature, resolved `target_damage_pool` and `target_attack_pool` are â‰¥ 1D and (where a listed stat exists) match it. Turns this whole rot class into a gate failure. The probe's data-quality block is a ready template.

---

## C. The threat cliff (per-exchange numbers, green profile, quickstart human)

| creature | P(no damage)/window | P(taken out, sevâ‰¥3)/window | P(killed outright)/window | median time-to-out | windows per player kill | farm rate |
|---|---|---|---|---|---|---|
| hitcher_crab | 91.0% | **1.35%** | 0.05% | 38 windows (~3.2 min) | 2.4 | **~195 cr/min** |
| tusken_warrior | 60.5% | **13.3%** | 3.1% | **4 windows (~20 s)** | 4.7 | ~194 cr/min |
| acklay | 16.8% | **63.7%** | 34.9% | 1 window | 12.9 | ~37 cr/min |
| merdeth | 1.1% | **95.9%** | **82.5%** | 1 window | **400** (1 kill in batch) | ~1 cr/min |

- The spawn table spans **free ATM â†’ 20-second death â†’ instant execution â†’ invulnerable wall**, and `roll_spawn` chooses among them by zone alert bias. A fresh player entering the Dune Sea is rolling dice on which economy they entered. This is the single biggest PT1 feel risk.
- **Recommendation:** add a `threat_tier` field per creature; band the spawn table by zone alert (calm lawless = tiers 1â€“2 only; escalation unlocks upper tiers), and treat merdeth-class as event/boss content, never ambient. Alternatively re-stat ambient lawless hostiles into a starter band â€” but the tier field is the durable fix and matches the MUSH's zone-escalation instincts.
- **Tactics barely save you up-tier.** The tactical profile (aim 2, cover 2, declared dodge) cuts out-chance ~45% vs the crab but only ~10â€“15% relative vs tusken/acklay/merdeth. Two WEG-native reasons: reaction dodge **replaces** the (already low, range-10) difficulty â€” a 3D dodge averages ~11 vs the base 10, occasionally *worse* â€” and cover 2D (~+7) is marginal against 6â€“8D attack pools. Survivability in this system comes from tier selection, not micro. Worth stating in the player guide, and it strengthens the threat-tier rec: the game offers no tactical escape hatch from an up-tier spawn.

---

## D. maxi() vs escalate() â€” P0-2, now with numbers

Campaign sims (300 each, real wound-penalty feedback each window):

| creature / profile | LIVE maxi: median windows-to-out | ESCALATE: median | terminal-state shift |
|---|---|---|---|
| hitcher_crab / green | 38 | **22** (âˆ’42%) | incap 197â†’**258**, dead 38â†’14 |
| hitcher_crab / tactical | 43 | **30** | similar |
| tusken_warrior | 4 | 3 | minor |
| acklay, merdeth | 1 | 1 | none |

Interpretation â€” this **reframes P0-2**:
- Against real monsters the single-hit regime dominates; wiring `escalate()` barely moves monster lethality.
- Attrition matters exactly where damage â‰ˆ soak and margins â‰¥ 16 are rare â€” i.e., **long low-tier fights and, crucially, near-peer PvP**. Under `maxi()`, two similar players in lawless can trade Wounded results forever and *neither can ever die* without a freak roll. **P0-2 is primarily a PvP-correctness prerequisite**, not a monster-tuning one.
- Terminal states connect to **P0-1**: under `escalate()` most outs arrive as **incapacitated-by-accumulation** (258/300 vs 197/300). If the tiered fork (P0-1 option A) were ever adopted, most PvE outcomes become "downed, medic-relevant" rather than "dead" â€” the two fixes should be designed as one seam, in that order (escalate first, then decide tiering with these distributions in hand).

---

## E. Economy probe

- **Risk and reward are anti-correlated at the top.** Loot keys on scale only (`character` [40,90] > `creature` [15,45]), so the trivial crab and the deadly acklay pay the **same per kill** (~40 cr), the tusken out-pays the acklay, and per-minute the crab (~195 cr/min, near-zero risk) strictly dominates everything. Fix: loot tier per creature (or band Ã— threat_tier), landing in the same drop as the spawn-table work.
- **Gear-up is very fast.** Heavy blaster (750) â‰ˆ 4 minutes of safe crab farming; with `STARTING_CREDITS = 1000` the vendor sink barely binds on a starter. Fine for a prototype; note it before PT1 economy impressions get taken as signal.
- **Insurance verdict:** expected uninsured death cost â‰ˆ 187 cr in dropped list value (50% of hold-out 275 + helmet 100) + 10% durability; premium = 500/3 charges â‰ˆ 167/death. Roughly break-even on the starter kit, clearly worth it with any accumulated inventory â€” a sane curve. At tusken-tier death rates (13%/window) it's mandatory, which is coherent *if* the player can tell tiers apart before engaging â€” another vote for visible threat tiers.
- Perf note: ~57k full arena windows resolved in well under the probe timeout; combat cost is a non-issue at any plausible peer count.

---

## F. Deliverable: `tools/balance_probe.gd`

Included alongside this doc. Drops into `tools/`; deterministic (seeded), touches no live files, runs the real arena path. Extend the `roster`/`profiles` consts to probe new content; the campaign harness already supports both accumulation models. **Do not wire it into the gate** (it's statistical and slow relative to smokes) â€” treat it as the on-demand tuning instrument, and re-run it as the acceptance step for the spawn-table / loot-tier / escalate() drops above. Note in-file: the `wounded_twice â†’ severity 2` projection is an explicit approximation because the current severity-int plumbing cannot express âˆ’2D (the P0-2 seam note, demonstrated).

**Queue additions (extends the Wave-G list):**
- **G10 [HOT]** hostile-death fallback â†’ no-target/hold-fire; dummy rewards de-fanged (influence/Force feed off; CP capped or spaceport-only); `_window_index` reset moved out of `reset_target()`.
- **G11 [PAR]** resolved-pool content smoke for all hostiles (Â§B); fix glim_worm/mip_swarm/spor_crawler stat strings to machine codes; reconcile listed-vs-resolved attack stats.
- **G12 [PAR]** `threat_tier` field + alert-banded spawn table + loot-by-tier (Â§C/Â§E), with `balance_probe` re-run as acceptance.
