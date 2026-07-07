# Living Mos Eisley â€” The Persistent-World Composition Loop

Status: **DESIGN (docs + data schemas only â€” no gameplay code).** Author:
world-sim-designer. Clone Wars era (20 BBY, Mos Eisley). WEG D6 R&E leads
mechanics; the SW_MUSH ("Parsec") design guides are READ-ONLY inspiration, cited
per section, never a 1:1 port.

Companion to (and dependent on) the existing backbone designs â€” this doc does not
re-litigate them, it **binds them together**:

- `docs/WORLD_SIM_DESIGN.md` â€” the Director/influence/alert/security backbone.
- `docs/FACTION_TERRITORY_DESIGN.md` â€” claims, cities, the Drop-6D siege machine.
- `docs/PERSISTENCE_DESIGN.md` â€” what survives restart and the SQLite/Postgres path.

And to the systems that are **already live and working** in the prototype (per
`docs/NIGHTLY_HANDOFF.md` / `docs/MULTIPLAYER_FOUNDATION.md`): server-authoritative
WEG action-window combat, the per-zone security/alert Director (`zone_state.gd`),
faction influence + territory claims (`territory_model.gd`), the credit economy +
reactive vendor pricing (`vendor_model.gd`), named NPCs with dialogue, hostile
creature spawns (`creature_spawn_model.gd`), the death/insurance loop, Force
awakening, and â€” as of 2026-07-03 â€” the live quest system (`quest_model.gd`,
`data/quests_clone_wars.json`) and creature harvesting.

---

## 0. The gap this doc closes

Every ingredient of a living world already exists as an isolated system. What is
missing is the **connective tissue**: the systems do not yet *read each other's
state* or *write back into a shared world model over time*. Today:

- The Director fires world events, but an event is a **headline only** â€” it changes
  no spawns, no prices, no quests, no dialogue (M2.2: "carries a Clone Wars
  headline, lasts `EVENT_DURATION` slow ticks").
- Killing hostiles awards CP and (via F1) some territory influence, but **does not
  calm the zone** â€” the spawn population and threat do not respond.
- The quest board is a **static list** â€” it does not shift with zone security,
  alert, or faction state.
- Vendor pricing already multiplies by a Director event (E11), but **stock and the
  event-to-price mapping are not data-driven**, and nothing else reacts.
- NPCs speak **fixed lines** regardless of whether the district is in lockdown or
  overrun by the Hutts.

This document specifies the two seams that make these compose â€” a **read seam** (the
Zone Situation blackboard) and a **write seam** (the World Pulse intake) â€” plus the
reactive-content bindings (quests, vendors, dialogue, spawns) and the world-event
**effect engine** that drives them all. The design goal is a single, legible
sentence made true: **what players do to a zone changes what that zone is, and what
a zone is changes what it offers players.**

Grounding: Guide_26 (Director AI) Â§1 "the system that makes the world feel alive",
Â§2 influenceâ†’alert, Â§3 world events, Â§4 the player-feedback loop; Guide_04 (Security
Zones) Â§7 dynamic overlays; Guide_24 (Encounters & Hazards) Â§1 the emergent danger
layer; Guide_06 (Economy) Â§2 mission board, Â§7 sinks; Guide_10/Â§5, Guide_11 Director
integration; Guide_20 (Scenes/Plots) Â§for how events surface into news/RP.

---

## 1. The composition model â€” one closed loop, two seams

The whole living world is one closed causal loop. Player actions write **deltas**
into authoritative truth (the write seam); the Director slow tick recomputes truth
and derives a read-only **blackboard** of facts (the read seam); reactive content
systems read the blackboard to decide what to offer; players engage the offers,
producing more actions. Nothing skips the loop.

```
      â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
      â”‚  PLAYERS act on offers                                            â”‚
      â”‚  (combat kills, quest claim/progress, harvest, buy/sell,          â”‚
      â”‚   claim/siege, presence)                                          â”‚
      â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                      â”‚  WRITE SEAM  (Â§1.2 World Pulse + durable pending-influence)
                      â–¼
      â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
      â”‚  AUTHORITATIVE TRUTH  (server-owned, persisted; the existing docs) â”‚
      â”‚  faction_zone_state.influence Â· territory claims/sieges Â·         â”‚
      â”‚  live spawn census Â· economy ledger Â· quest board cursor Â·        â”‚
      â”‚  world_event_instances                                            â”‚
      â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                      â”‚  Director SLOW TICK recomputes (Â§2), then DERIVES:
                      â–¼
      â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
      â”‚  ZONE SITUATION BLACKBOARD  (Â§1.1, derived, READ-ONLY, cached)    â”‚
      â”‚  alert Â· security_effective Â· dominant_faction + trend Â·          â”‚
      â”‚  controlling_org Â· threat_level Â· scarcity_index Â·                â”‚
      â”‚  active_event_tags Â· quest_offer_tags Â· ambient_mood              â”‚
      â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                      â”‚  READ SEAM  (reactive systems read; NEVER write)
        â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¼â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
        â–¼             â–¼             â–¼               â–¼                 â–¼
    SPAWNS(Â§3.1)  QUESTS(Â§3.2)  VENDORS(Â§3.3)  DIALOGUE(Â§3.4)   AMBIENT/NEWS
    census+table  board filter  price+stock    line selection   (Director)
        â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                      â”‚  these are the OFFERS players see
                      â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–º (back to PLAYERS act)
```

**Why two named seams and not just "systems calling systems".** If each reactive
system read raw influence/claim/event tables directly, every content system would
re-implement the derivation (what counts as "underworld"? which org "controls" a
zone?) and they would drift. The blackboard is the **single derivation**: one place
computes the facts, everyone reads them, they can never disagree. Symmetrically, the
Pulse is the **single intake**: combat, quests, and the economy do not each poke
influence tables directly â€” they append typed events to one accumulator the Director
folds deterministically. This is the same discipline the MUSH keeps by routing ALL
influence through one entry point (`adjust_territory_influence`, Guide_11 Â§2
"Architecture invariant") and ALL combat through one security gate
(`get_effective_security`, Guide_04 Â§2 "Key architecture invariant").

### 1.1 The read seam â€” the Zone Situation blackboard

One derived, read-only record per active zone, recomputed every slow tick from
authoritative truth. It is a **cache**: fully re-derivable, so it may be persisted
for hot reads and telemetry but never treated as a source of truth (same status as
`alert_level` / `security_overlay` today, which `PERSISTENCE_DESIGN` Â§1.B marks
"cache; re-derivable"). All reactive content reads this and only this.

Proposed shape (`data/schemas/zone_situation.schema.json`):

```jsonc
{
  "schema_version": 1,
  "zone_id": "tatooine.mos_eisley.port_fringe",   // matches zones_clone_wars.json
  "tick": 20456,                                    // Director slow-tick index
  "derived_at_unix": 1751600000.0,

  // --- mirrored/derived from faction_zone_state (WORLD_SIM_DESIGN Â§2.3) ---
  "alert_level": "underworld",                      // enum, already derived today
  "security_effective": "lawless",                  // from security_gate.gd (base+overlay)
  "dominant_faction": "hutt",                        // argmax(influence)
  "faction_trend": {                                 // sign of influence delta vs last Faction Turn
    "republic": "falling", "cis": "flat", "hutt": "rising", "independent": "flat"
  },

  // --- from territory layer (FACTION_TERRITORY_DESIGN Â§2) ---
  "controlling_org": "org_hutt_kajidic_a",          // org at Dominance(75+) in zone, else null
  "controlling_org_axis": "hutt",                    // that org's faction axis, else null
  "active_siege_here": false,

  // --- from the live spawn census (Â§3.1) ---
  "threat_level": 3,                                 // 0..5, derived: live vs target hostiles
  "hostile_census": {"live": 11, "target": 8, "recent_kills": 6},

  // --- from the economy pulse (Â§3.3) ---
  "scarcity_index": 0.2,                             // -1 glut .. +1 shortage

  // --- from active world events (Â§4) ---
  "active_event_ids": ["evt_00c1"],
  "active_event_tags": ["underworld", "bounty_surge", "smuggling_favored"],

  // --- rolled up for content filters ---
  "quest_offer_tags": ["hutt", "combat", "lawless"], // union of what this situation unlocks
  "ambient_mood": "tense_underworld",                // static ambient pool selector key
  "extra": {}
}
```

`faction_trend`, `threat_level`, `scarcity_index`, and `active_event_tags` are the
**new** facts this doc introduces; the rest already exist inside `zone_state.gd` and
`security_gate.gd` and are merely surfaced here in one object.

### 1.2 The write seam â€” the World Pulse intake

Player actions do not mutate influence, census, or scarcity directly. They append
typed events to a per-zone **World Pulse** accumulator, which the Director folds on
its tick and then clears. This mirrors the durable playerâ†’world loop already
designed (`pending_influence_model.gd`, E8): a character writes influence deltas to
their own persisted `world_hooks.pending_zone_influence` (crash-safe), and the
non-influence signals (kills for the census, credits for scarcity) go to the
transient zone Pulse.

Proposed shape (`data/schemas/world_pulse.schema.json`) â€” transient, re-derivable:

```jsonc
{
  "schema_version": 1,
  "zone_id": "tatooine.dune_sea",
  "window_open_tick": 20450,

  // folded into faction_zone_state.influence; each entry sources a durable
  // world_hooks.pending_zone_influence row on the acting character (crash-safe)
  "influence_deltas": {"hutt": -3, "republic": 1, "cis": 0, "independent": 0},

  // feed the spawn census (Â§3.1): recent_kills, and faction-tagged culls
  "hostile_kills": [
    {"target_key": "canyon_womp_rat", "faction_tag": "wild", "count": 4}
  ],
  "harvest_events": [{"resource": "womp_hide", "count": 4}],  // from tonight's harvesting

  // feed scarcity_index (Â§3.3): buying drains, selling floods
  "economy_pulse": {"credits_spent": 1200, "credits_earned": 400, "contraband_sold": 1},

  // feed quest reactivity / news
  "quest_completions": ["q_womp_cull"],
  "extra": {}
}
```

**Who writes what** (the intake contract for the netcode/rules engineers):

| Live system | Writes to Pulse | Sourced from |
|---|---|---|
| Action-window combat (kill/disable) | `hostile_kills`, `influence_deltas` | resolved envelope (server owns seed) |
| Quest claim | `quest_completions`, `influence_deltas` | `quest_model` reward hook |
| Harvesting | `harvest_events`, `economy_pulse` (resource value) | harvest resolution |
| Vendor buy/sell | `economy_pulse` | `vendor_model` transaction |
| Territory claim / siege score | `influence_deltas` (bridged to Director axis) | `territory_model` / siege machine |
| Presence (hourly) | small `influence_deltas` for faction members | slow tick, not a player action |

**Deltas are small by design** (WORLD_SIM_DESIGN Â§2.2): one player cannot flip a
zone in a session; a handful of players over a week can. The exact plasticity is an
OWNER DECISION (Â§7.1).

### 1.3 The shared-state ownership contract

To keep authority unambiguous (server owns all truth; clients observe â€” the
project invariant), each piece of world state has exactly one owner that WRITES it;
everyone else READS the blackboard.

| State | Owner (writer) | Reactive readers | Persisted? |
|---|---|---|---|
| `faction_zone_state.influence` | Director slow tick (folds Pulse) | (via blackboard) | Yes |
| `alert_level`, `security_overlay` | Director (derive) | all | cache |
| Zone Situation blackboard | Director (derive, end of tick) | spawns, quests, vendors, dialogue | cache |
| World Pulse | player-action hooks (append), Director (fold+clear) | Director only | No (transient) |
| Live spawn census | spawn system (Â§3.1) | blackboard `threat_level` | Yes (count) |
| Territory claims / sieges | `territory_model` / siege machine | blackboard `controlling_org` | Yes |
| `world_event_instances` | Director event engine (Â§4) | blackboard `active_event_*` | Yes |
| Quest board cursor / offer set | quest board (Â§3.2) | clients (offers) | Yes (cursor) |
| Vendor restock timers | vendor system (Â§3.3) | clients (stock/price) | Yes (timers) |

---

## 2. The world-tick loop (cadence composition)

Everything reactive runs on the **existing slow Director tick** â€” never the 20 Hz
movement tick (WORLD_SIM_DESIGN Â§4). The slow tick is owner-configurable (~30 s in
dev via `--director-tick`, up to the MUSH's 30-min Faction Turn in production). This
doc adds no new clock; it slots new work into named sub-cadences and keeps every
tick's work **bounded** (process N zones/NPCs per tick, never all at once).

| Sub-cadence | Work added by this doc | Cost |
|---|---|---|
| **Every slow tick** | Fold World Pulse â†’ influence + census; derive alert/security (exists); **advance world-event state machine (Â§4)**; **re-derive Zone Situation blackboard**; recompute vendor price multipliers + quest offer set (both pure filters over the blackboard) | cheap, pure |
| **Every Faction Turn** (N slow ticks, ~30 min real) | Full influence recompute + decay-toward-baseline (exists); **world-event trigger roll (Â§4)**; **spawn population rebalance/regrow (Â§3.1)**; **vendor restock (Â§3.3)**; refresh ambient/dialogue variant pools | moderate |
| **Hourly** | Presence influence (exists) | light |
| **Daily** | Influence decay floor (exists); territory yields (exists); **full quest-board rotation (Â§3.2)** | light |

Ordering **within** a slow tick matters and is fixed:

1. **Fold** the World Pulse (write seam) into authoritative truth.
2. **Advance** authoritative sub-systems: event state machine, census regrow, siege
   timers.
3. **Derive** the caches: alert â†’ security overlay â†’ **blackboard** (read seam),
   in that dependency order.
4. **Recompute** the cheap reactive projections that clients read (quest offer set,
   vendor price map) from the fresh blackboard.
5. **Broadcast** the per-zone posture in the snapshot (clients render tags/offers;
   they never derive).

The player never sees the tick â€” they see its *results*: a news line, a shifted
alert badge, thinner spawns, a changed board, a new vendor price (Guide_26 Â§6 "The
Faction Turn is silent for players").

---

## 3. Reactive content â€” making the systems talk

Each reactive system is a **pure projection**: `f(authored_content, zone_situation)
â†’ what the player sees`. The authored content is the immutable seed in `data/`; the
blackboard is the live situation; the output is transient and recomputed each tick.
This keeps the seed roster stable while the *presentation* of it breathes.

### 3.1 Spawns & the "clear a zone to calm it" loop

This is the most visceral reactivity and the prompt's headline example. It closes
the loop between combat (live) and the world (static). Grounding: Guide_24 Â§1
(emergent danger), Guide_26 Â§2 (alert drives spawn rates), Guide_11 Â§2 (kill NPC in
zone â†’ influence).

**The census.** Each zone tracks a live hostile population against a target derived
from its `threat_level`. Killing hostiles decrements the live count and (if the
hostile is faction-tagged) writes an influence delta. When the live count stays
below target across Faction Turns, `threat_level` falls â†’ the alert calms, fewer/
weaker hostiles spawn, ambient text softens. Player absence lets the population
regrow toward target and threat climbs again. **A zone you clear stays calmer until
the world refills it.**

Two distinct effects of a kill, deliberately separated:

- **Pacification (always):** live census âˆ’1; `recent_kills` +1. Lowers derived
  `threat_level`, which lowers the spawn target and calms the alert-adjacent feel.
- **Geopolitics (only faction-tagged kills):** killing `underworld_thug`
  (`faction_tag: hutt`) writes Hutt âˆ’N to the Pulse; killing a Republic patrol
  writes Republic âˆ’N. Wild creatures (`faction_tag: wild`) pacify but do **not**
  shift faction influence. *Whether pacifying wildlife should also nudge the
  "independent/order" axis is an OWNER DECISION â€” Â§7.4.*

Proposed static shape (`data/schemas/spawn_table.schema.json`), one per zone,
consuming the real `creatures_clone_wars.json` ids:

```jsonc
{
  "schema_version": 1,
  "zone_id": "tatooine.dune_sea",
  "base_target_population": 8,
  "target_by_threat_level": {"0": 2, "1": 4, "2": 6, "3": 8, "4": 11, "5": 15},
  "regrow_per_faction_turn": 2,          // how fast an abandoned zone refills
  "recent_kill_decay_per_turn": 2,       // how fast "recently cleared" fades
  "entries": [
    { "creature_key": "canyon_womp_rat", "faction_tag": "wild", "pack": true,
      "weight_by_alert": {"lax": 4, "standard": 3, "underworld": 5, "lockdown": 2} },
    { "creature_key": "underworld_thug", "faction_tag": "hutt",
      "weight_by_alert": {"underworld": 5, "lax": 3, "standard": 1, "lockdown": 0} },
    { "creature_key": "krayt_dragon", "faction_tag": "wild", "weight": 1,
      "requires_event_tag": "krayt_sighting" }   // only during a krayt_sighting event
  ],
  "extra": {}
}
```

`threat_level` derivation (pure, tunable): `clamp(round(5 * live / target), 0, 5)`,
biased down by `recent_kills`. The spawn selector already exists
(`creature_spawn_model.gd` "zone-posture bias: dangerousâ†’hostile, calmâ†’non-hostile");
this table makes its inputs data-driven and adds the census feedback.

Worked example (the prompt's): players spend an evening in the Dune Sea culling
`underworld_thug`s. Census drops 11â†’4; `recent_kills` spikes; `threat_level` 3â†’1;
Hutt influence ticks down via the Pulse. Next Faction Turn: fewer thug spawns, the
alert eases toward `lax`, the Hutt vendor's contraband thins (Â§3.3), and Greeshk's
"Fringe Cleanup" quest stops appearing (its `require_faction_min.hutt` no longer
holds â€” Â§3.2). Two days later, nobody has been out there; the population regrows,
threat climbs, the quest returns. The desert *reacted*.

### 3.2 Quests reactive to zone security / alert / faction

Grounding: Guide_06 Â§2 (the board refreshes; jobs scale to context), Guide_04 Â§9
(lawless-only higher-paying jobs), Guide_26 Â§3 (`bounty_surge` doubles bounty pay).

The live quest system (`quest_model.gd`) supports objective kinds `disable`
(optional `target_key`), `reach_zone`, and `earn_credits`. This doc adds an
**optional, additive** `availability` block and a `reward_dynamic` block to each
authored quest. **Absent `availability` â‡’ always offered** (backward-compatible: all
12 current quests keep working untouched). Present â‡’ the board only offers the quest
when the zone situation matches.

Additive fields on each entry in `data/quests_clone_wars.json`:

```jsonc
{
  "id": "q_fringe_muscle",
  "name": "Fringe Cleanup",
  "objective": {"kind": "disable", "target_key": "underworld_thug", "count": 3},
  "reward": {"credits": 260, "cp": 3},
  "giver": "hutt_enforcer_greeshk",

  "availability": {                            // OPTIONAL; absent = always on board
    "offer_zones": ["tatooine.mos_eisley.port_fringe"],
    "require_alert": ["underworld", "lax", "standard"],
    "require_faction_min": {"hutt": 40},        // Hutt must hold the fringe
    "require_event_tags": [],                   // must ALL be active
    "forbid_event_tags": ["republic_crackdown"],// suppressed during a crackdown
    "require_controlling_org_axis": null,       // e.g. "hutt" to gate behind territory
    "require_security": ["contested", "lawless"]
  },
  "reward_dynamic": {                           // OPTIONAL; applied at claim time
    "credit_multiplier_by_event_tag": {"bounty_surge": 2.0},
    "cp_bonus_if_security": {"lawless": 1}       // Guide_04 Â§9 lawless incentive
  }
}
```

The **board offer set** is a pure filter over authored quests Ã— the blackboard,
recomputed each slow tick and rotated daily (Guide_06 Â§2 refresh cadence). Proposed
derived shape the client reads (`data/schemas/quest_offer.schema.json`):

```jsonc
{
  "zone_id": "tatooine.mos_eisley.port_fringe",
  "tick": 20456,
  "offers": [
    { "quest_id": "q_fringe_muscle", "giver": "hutt_enforcer_greeshk",
      "effective_reward": {"credits": 260, "cp": 4},  // cp+1 lawless bonus applied
      "reason_tags": ["hutt", "combat"] }
  ],
  "extra": {}
}
```

This is how **faction influence shifts available quests** and **territory control
gates content**: a `require_controlling_org_axis: "hutt"` quest simply is not on the
board until a Hutt org reaches Dominance in the zone; a `require_security:
["lawless"]` job only appears where the frontier is genuinely lawless. Whether
gating should be **hard** (locked out) or **soft** (always offered, flavored/paid
differently) is an OWNER DECISION â€” Â§7.3.

### 3.3 Vendor stock & price reactive to zone state

Grounding: Guide_06 Â§7 sinks + Â§8 Bargain, Guide_26 Â§3 (`trade_boom` +25%,
`merchant_arrival` new goods, `hutt_auction` rare goods), Guide_04 Â§9 (black-market
vendors in lawless zones). The economy already has `vendor_stock_by_zone.json`
(per-zone item lists) and `vendor_model.gd` (which already multiplies price by a
Director event â€” E11). This doc makes the **eventâ†’price/stock mapping data-driven**
and adds scarcity.

Proposed static shape (`data/schemas/vendor_dynamics.schema.json`), layered over the
existing per-zone base list:

```jsonc
{
  "schema_version": 1,
  "zone_id": "tatooine.mos_eisley.port_fringe",
  "base_item_keys_ref": "vendor_stock_by_zone.json",   // the existing seed list
  "price_modifiers": {
    "by_alert": {"lockdown": 1.15, "high_alert": 1.05, "standard": 1.0, "lax": 0.95, "underworld": 0.9},
    "by_event_tag": {"trade_boom": 1.25, "merchant_arrival": 0.85, "supply_shortage": 1.4},
    "scarcity_coefficient": 0.3            // final Ã—= 1 + coefficient * scarcity_index
  },
  "stock_modifiers": {
    "add_on_event_tag": {"merchant_arrival": ["heavy_blaster_pistol_dl6h"]},
    "remove_on_event_tag": {"republic_crackdown": ["heavy_blaster_pistol", "vibroblade"]},
    "contraband_when": {                    // gray/black-market gating (OWNER â€” Â§7.5)
      "require_alert": ["underworld"], "require_controlling_org_axis": "hutt",
      "item_keys": []                       // left EMPTY pending the owner call
    },
    "restock_faction_turns": 4
  },
  "price_clamp": {"min_mult": 0.7, "max_mult": 1.6},   // anti-exploit bound (Â§7.2)
  "extra": {}
}
```

`scarcity_index` (blackboard) rises when players drain a zone's supply (heavy buying
in the Pulse) and during `supply_shortage`; it falls on a glut (mass selling). It is
**bounded** and feeds only price, never availability of essentials â€” the economy
audit's warning that static multipliers become "a solved game" (Guide_06 Â§1/Â§5) is
answered by the `price_clamp` and by scarcity being a small, mean-reverting nudge,
not a runaway. The final price stays: `base Ã— alert Ã— event Ã— (1 + 0.3Â·scarcity) Ã—
bargain`, clamped. The **hard price bound is an OWNER DECISION** (Â§7.2), and any
event that *removes* legal stock (a crackdown confiscating heavy blasters) is the
credit-sink/pressure the audit says the economy needs.

This is how **faction influence and events shift vendor prices and stock**: a
`republic_crackdown` strips the heaviest gear off the shelves and nudges prices up; a
Hutt-dominant `underworld` alert quietly lowers prices and (if the owner allows)
opens a gray-market row; a `trade_boom` spikes sell value for a window.

### 3.4 NPC dialogue reactive to zone state

Grounding: Guide_26 Â§5 (ambient text scoped by zone character), Guide_10 Â§5 (Director
issues faction NPC flavor), the existing `dialogue_lines` on every NPC in
`npcs_clone_wars.json`. This doc adds an **optional situational overlay** on top of
each NPC's authored base lines. Absent â‡’ the NPC speaks its base lines (fully
backward-compatible).

Proposed static shape (`data/schemas/npc_dialogue_variants.schema.json`):

```jsonc
{
  "schema_version": 1,
  "npc_id": "ct2207_stamp",                    // real id in npcs_clone_wars.json
  "base_lines_ref": "npcs_clone_wars.json",    // fallback = authored dialogue_lines
  "situational_lines": [
    { "when": {"alert": ["lockdown", "high_alert"]},
      "lines": ["Lockdown's on. Full manifest scan today, citizen â€” no exceptions."] },
    { "when": {"active_event_tags": ["republic_crackdown"]},
      "lines": ["Crackdown orders came down from orbit. Keep your hands where I can see them."] },
    { "when": {"dominant_faction": ["hutt"], "alert": ["underworld"]},
      "lines": ["I log the manifests. The Hutts run the rest. You didn't hear that from me."] },
    { "when": {"active_siege_here": true},
      "lines": ["Whole district's a shooting gallery. I'm calling this posting a loss."] }
  ],
  "selection": "most_specific_match_then_random",  // #matched-keys wins; ties â†’ seeded random
  "extra": {}
}
```

The selector (pure) scores each `situational_lines` block by how many of its `when`
keys the blackboard satisfies, picks the most specific match, and falls back to the
NPC's authored `dialogue_lines`. Now Stamp the customs clone *talks about* the
lockdown he's enforcing; Greeshk the Hutt enforcer gloats when the Hutts are
ascendant and goes quiet under a crackdown. **The world's mood reaches the mouths of
its people** â€” the cheapest immersion win per unit of work in the whole design.

---

## 4. World events â€” the effect engine (data + state machine)

Today an event is a headline. This section turns each event into a **data-defined
bundle of effects** the reactive systems in Â§3 already know how to interpret, plus a
**state machine** for its lifecycle. This is where "raids, shortages, bounties,
faction pushes" become emergent goals rather than flavor text.

Grounding: Guide_26 Â§3 (the 12-event menu, lifecycle, "opportunities not
obligations", concurrency constraints), Â§4 (era milestones), WORLD_SIM_DESIGN Â§2.4
(the fixed menu recast Clone Wars, "the Director SELECTS not INVENTS").

### 4.1 Event definitions (the menu, as data)

The 12 event types already enumerated in `faction_zone_state.schema.json`
(`republic_crackdown`, `republic_checkpoint`, `bounty_surge`, `merchant_arrival`,
`sandstorm`, `cantina_brawl`, `distress_signal`, `pirate_surge`, `hutt_auction`,
`krayt_sighting`, `cis_propaganda`, `trade_boom`) get a **definition** carrying their
trigger conditions and â€” the new part â€” their **effects payload**. The Director still
only ever SELECTS a definition from this authored menu (the safety principle); it
never invents effects.

Proposed static shape (`data/schemas/world_event_definition.schema.json`):

```jsonc
{
  "schema_version": 1,
  "key": "republic_crackdown",
  "display_name": "Republic Crackdown",
  "category": "faction_push",                  // faction_push | raid | bounty | shortage | boom | hazard | social
  "scope": "zone",                             // zone | multi_zone | global(milestone)
  "trigger": {
    "dominant_faction": "republic",
    "min_influence": {"republic": 50},
    "base_chance_per_faction_turn": 0.15,
    "cooldown_faction_turns": 8,               // same type can't repeat within N (Guide_26 Â§3)
    "min_gap_minutes": 15
  },
  "duration_faction_turns": {"min": 2, "max": 4},
  "telegraph": true,                            // brief ANNOUNCED phase before ACTIVE (Â§4.2)
  "effects": {                                  // â† interpreted by Â§3 systems, all optional
    "influence_per_turn": {"republic": 2, "hutt": -1},
    "security_overlay": "upgrade_one_tier",     // feeds security_gate.gd (contestedâ†’secured)
    "spawn_multiplier": {"republic": 2.0, "hutt": 0.5},
    "vendor_price_mult": 1.05,
    "vendor_stock_remove": ["heavy_blaster_pistol", "vibroblade"],
    "quest_unlock_tags": ["republic", "checkpoint"],
    "quest_forbid_tags": ["smuggling"],
    "dialogue_tag": "republic_crackdown",
    "ambient_tag": "clone_patrols",
    "scarcity_delta": 0.1
  },
  "headline_pool": ["Clone troopers flood the district; checkpoints go up on every lane."],
  "comlink_announce": true,
  "extra": {}
}
```

The prompt's four "shapes" map onto this cleanly (and the menu is **data-extensible**
â€” new definitions are content, not code):

| Requested shape | Definition(s) | Emergent goal it creates |
|---|---|---|
| **Faction push** | `republic_crackdown`, `cis_propaganda`, `hutt_auction` | Fight for or against a rising faction; timed rep/influence swing |
| **Raid** | `pirate_surge`, `krayt_sighting`, plus additive `faction_raid` | Group content: repel the surge to pacify the zone (Â§3.1 census spike) |
| **Bounty** | `bounty_surge` | Bounty pay Ã—2 window; hunt marked targets while it's hot |
| **Shortage** | additive `supply_shortage` | Scarcity spikes prices; a delivery/escort quest unlocks to relieve it |

`faction_raid` and `supply_shortage` are **additive definitions** beyond the MUSH's
12. They are authored data (menu entries), not LLM inventions, so they respect the
"Director selects from a fixed menu" safety rule â€” but because they extend a menu the
prototype currently treats as frozen (12 hardcoded types in `zone_state.gd`), **they
need a `docs/DIVERGENCE_LEDGER.md` row before implementation** (this doc does not
edit that ledger; it flags the requirement). The far larger structural change â€” event
**effects becoming data** rather than the current headline-only behavior â€” is a pure
capability addition and does not diverge from WEG; it realizes Guide_26 Â§3's intended
"apply effects" step that the prototype stubbed.

### 4.2 Event instances (the live state machine)

One record per firing. The server owns it; it survives restart; the slow tick
advances it; all RNG/scoring are server-authoritative. Proposed shape
(`data/schemas/world_event_instance.schema.json`, formalizing the
`world_event_instances` table in PERSISTENCE_DESIGN Â§3.B):

```jsonc
{
  "schema_version": 1,
  "event_id": "evt_00c1",
  "definition_key": "republic_crackdown",
  "state": "active",                    // pending | announced | active | expiring | expired | cancelled
  "zones": ["tatooine.mos_eisley.port_fringe"],
  "seed": 837261,                       // server-owned; deterministic replay
  "started_at_tick": 20440,
  "expires_at_tick": 20560,
  "headline": "Clone troopers flood the district; checkpoints go up on every lane.",
  "effects_snapshot": { "...": "frozen copy of definition.effects at fire time" },
  "extra": {}
}
```

`effects_snapshot` freezes the definition's effects at fire time, so retuning a
definition never changes an in-flight event (same discipline as the siege machine's
`config` snapshot, FACTION_TERRITORY_DESIGN Â§6.2).

State machine (slow-tick driven; never client-driven):

```
   trigger roll passes at a Faction Turn AND preconditions hold
 (none) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶ ANNOUNCED  (telegraph=true)
     â”‚ telegraph=false                                    â”‚  next slow tick: news line + comlink;
     â”‚ (fire immediately)                                 â”‚  effects NOT yet applied
     â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                   â–¼
                                      â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶ ACTIVE  â—€â”€â”€ effects applied every tick
   admin cancel / precondition lost â”€â”€â–¶ CANCELLED           â”‚  (influence/spawn/vendor/quest/dialogue)
   (terminal; effects reset)                                â”‚  expires_at_tick reached
                                                            â–¼
                                                        EXPIRING  (one tick: reset overlays/effects,
                                                            â”‚        thin out event-spawned hostiles)
                                                            â–¼
                                                        EXPIRED   (archived to director_log / +news)
```

**Concurrency guards** (Guide_26 Â§3, WORLD_SIM_DESIGN Â§2.4, all owner-tunable):
â‰¤2 concurrent Director events globally; â‰¥15 min between Director events; same
`definition_key` respects its `cooldown_faction_turns`; **events create
opportunities, never block progress** (a crackdown fines and pressures; it never
jails or hard-walls). A `pirate_surge` does not force combat â€” it makes the deep
desert spawn census spike so that *if* you go out there, you find a fight worth the
`bounty_surge` that often rides with it.

### 4.3 Era milestones (server-wide story turns)

Unchanged from WORLD_SIM_DESIGN Â§2.5 and Guide_26 Â§4 â€” the Director tracks average
influence across all zones and fires one-time, persisted milestones (`republic_grip`,
`martial_law`, `underworld_rising`, `hutt_takeover`, `separatist_whispers`,
`separatist_uprising`, `republic_retreat`). In this composition, a milestone is just
a `scope: "global"` event definition whose effects apply to *every* zone's blackboard
at once (e.g. `martial_law` = a server-wide `republic_crackdown` for hours). They are
logged to `world_milestones` so they never re-fire across restarts.

---

## 5. Persistence â€” the seed + overlay pattern

The living world is **seed + overlay**. The shipped `data/*.json` files are the
immutable ground truth (zones, quests, vendors, NPCs, creatures, spawn tables, event
definitions, dialogue variants). The persistent world is a thin **overlay of drift
and history** on top. On restart: load seed â†’ apply overlay â†’ re-derive all caches.
This keeps the authored roster stable while letting the world diverge from it over
time, and it makes "what survives a restart" a short, auditable list.

| Layer | Examples | Lifetime | Storage |
|---|---|---|---|
| **Seed (immutable)** | zones, quest definitions, vendor base lists, NPC base lines, spawn tables, event definitions, dialogue variants | ships in repo | `data/*.json` (read-only at runtime) |
| **Overlay (durable drift/history)** | per-zone influence drift, `world_event_instances`, `world_milestones`, live spawn **count**, territory claims/sieges, quest-board rotation cursor, vendor restock timers, `world_hooks.pending_zone_influence` on characters | survives restart | SQLite tables (PERSISTENCE_DESIGN Â§3) |
| **Cache (re-derivable)** | `alert_level`, `security_overlay`, the **Zone Situation blackboard**, current quest offer set, current vendor price map, `threat_level`, `scarcity_index` | rebuilt on first tick after restart | in-memory (optionally cached) |
| **Transient (deliberately lost)** | World Pulse accumulator, PvP consent flags, dynamic LLM ambient pool, lawless-warning ack | reset on restart | none |

New overlay rows this doc requires beyond what PERSISTENCE_DESIGN already lists:

- **Live spawn census per zone** â€” a small `zone_spawn_census(zone_id, live_count,
  recent_kills, last_rebalance_unix)` row. It is durable so a zone you cleared before
  a restart is *still* cleared after it (the world does not silently refill on a
  reboot). `threat_level` is re-derived from it.
- **Quest-board cursor per zone** â€” which authored quests are currently on the board
  and their rotation timer, so a restart resumes the same board rather than
  re-rolling it.
- **Vendor restock timers per zone** â€” so a mid-cycle restart does not reset the
  economy's supply clock.

**Restart resume specifics** (extending PERSISTENCE_DESIGN Â§4): an event in `active`
with a future `expires_at_tick` keeps running; one whose expiry passed during
downtime advances to `expiringâ†’expired` on the first tick (its effects are cleanly
reset, not left stuck applied). The blackboard, price map, and offer set are all
**re-derived on the first post-restart tick** from the overlay â€” never restored from
a stale cache. The World Pulse is intentionally dropped (any un-folded deltas that
mattered were already mirrored to the acting characters' durable
`pending_zone_influence`, so nothing important is lost).

**Whether the galaxy ever resets to baseline** â€” a hard seasonal wipe of the overlay
back to the seed â€” is an OWNER DECISION (Â§7.6). The default is: it never does; drift
is permanent until decay slowly returns it to each zone's authored `baseline`
(already in `zones_clone_wars.json`).

---

## 6. Build order â€” most "alive" per unit of work

Ordered so each step is independently shippable, testable on the existing green gate,
and adds visible life. `[PURE]` = a new pure RefCounted model + smoke test (parallel-
safe, no netcode). `[HOT]` = wiring into `network_manager.gd` / `net_world.gd` /
`zone_state.gd` (serialize on hot files). Several steps **extend** existing live
models rather than greenfield â€” noted, because that lowers cost and raises priority.

**Step 1 â€” Zone Situation blackboard.** `[PURE]` derive the blackboard object
(Â§1.1) from the already-live `zone_state.gd` + `security_gate.gd` + `territory_model`
outputs. `[HOT]` compute it at the end of each slow tick and fold a compact posture
into the snapshot. *Nothing looks different yet, but this is the substrate everything
else reads.* Highest leverage, lowest risk.

**Step 2 â€” Reactive spawns + census (the "clear a zone calms it" loop).** `[PURE]`
`spawn_table` + census-derived `threat_level` (extends the existing
`creature_spawn_model.gd`). `[HOT]` decrement the census on every action-window
kill/disable, regrow on the Faction Turn, feed influence deltas through the Pulse.
*This is the single most visceral reactivity and it plugs straight into combat, which
already works.* Do it early.

**Step 3 â€” Event effects become data.** `[PURE]` `world_event_definition` +
`world_event_instance` state machine + a pure "effects interpreter" that turns an
active event into a set of modifiers (extends the existing 12-event `zone_state.gd`
logic). `[HOT]` advance the state machine on the tick; apply `security_overlay`,
`spawn_multiplier`, `influence_per_turn`. *Now events DO things* â€” a crackdown
actually changes the zone. Unlocks Steps 4â€“6 to react to events, not just alert.

**Step 4 â€” Reactive quest board.** `[PURE]` the availability filter + reward_dynamic
resolver over the blackboard (extends `quest_model.gd`; additive `availability` on
`quests_clone_wars.json`). `[HOT]` serve the filtered offer set + rotate daily. *Low
work (the quest system exists), high "the board changed" feel.*

**Step 5 â€” Reactive vendor stock/price.** `[PURE]` `vendor_dynamics` modifiers
(mostly extends `vendor_model.gd`, which already applies an event multiplier).
`[HOT]` apply stock add/remove + scarcity to the served stock. *Small delta over
what's live; makes prices and shelves breathe.*

**Step 6 â€” Reactive NPC dialogue.** `[PURE]` the situational-line selector over the
blackboard (additive `npc_dialogue_variants`). `[HOT]` serve the selected line on
`talk`. *Cheapest immersion win; do it whenever a spare slot appears.*

**Step 7 â€” The composed payoff: full faction-push / raid / shortage events.** No new
seams â€” just author the `faction_raid` and `supply_shortage` definitions (after their
ledger row, Â§4.1) and let Steps 1â€“6 light up together. A single `republic_crackdown`
now simultaneously: raises Republic influence, upgrades security, doubles clone-patrol
spawns, strips heavy blasters off shelves and nudges prices, suppresses smuggling
quests and unlocks checkpoint quests, changes Stamp's dialogue, and pushes a news
line. *That* is the living world, and it emerges from composition, not from one big
feature.

Milestones (Â§4.3) ride on Step 3 for free once global-scope events work; they are a
thin add whenever the owner wants the server-wide story turns switched on.

---

## 7. OPEN OWNER DECISIONS (flagged â€” NOT decided here)

Each is genuinely feel-defining, not an engineer-level call. Presented with WEG/MUSH
tradeoffs and a recommendation; **not settled**. Each is a data hook with no policy
baked in. Any resulting divergence from WEG or the MUSH gets a
`docs/DIVERGENCE_LEDGER.md` row before it is treated as settled (this doc flags the
requirement; it does not edit the ledger).

1. **World plasticity â€” how fast player action moves a zone.** The magnitudes on the
   Pulse's `influence_deltas` and the census regrow rate decide whether a session of
   play visibly bends a zone or whether it takes a coordinated week. *Options:* (a)
   MUSH-faithful slow â€” "steady but slow changeâ€¦ over hours" (Guide_26 Â§6), a zone
   needs sustained group effort to flip; (b) responsive â€” a busy evening noticeably
   calms/tilts a zone, better for a small prototype population. *Recommendation:* ship
   **(b)** for the prototype (a thin playerbase needs to *see* its impact), with the
   deltas behind a single config scalar so it can be tightened toward (a) as
   population grows.

2. **Reactive price bound.** How far may `alert Ã— event Ã— scarcity` move a price
   before Bargain? The economy audit warns static multipliers become "a solved game"
   (Guide_06 Â§1/Â§5). *Options:* tight clamp (Â±15%, cosmetic), medium (Â±40%, the
   default in Â§3.3), wide (Â±100%, real speculation but exploitable). *Recommendation:*
   **medium (0.7â€“1.6Ã—)** with essentials never removed from stock â€” meaningful without
   inviting the 120Ã— exploit the audit found.

3. **Quest/vendor gating â€” hard vs soft.** Should `require_controlling_org_axis` /
   `require_faction_min` / lawless-only content **lock out** non-qualifying players,
   or merely **reflavor/repay** always-available content? Hard gating makes territory
   control matter (Guide_04 Â§9, Guide_11 endgame); soft gating protects solo and
   Independent players from dead boards. *Recommendation:* **soft-gate the everyday
   board** (everyone always has jobs) and **hard-gate a minority of prestige/faction
   quests** behind influence/territory â€” so control unlocks *special* content without
   starving anyone.

4. **Does pacifying wildlife have geopolitical weight?** Faction-tagged kills shift
   influence; wild-creature kills currently only pacify (Â§3.1). *Options:* (a) wild
   kills are purely local threat reduction (recommended â€” keeps geopolitics about
   factions, not vermin); (b) wild kills also nudge an "order/independent" axis (makes
   the frontier feel governable by anyone who tames it). *Recommendation:* **(a)** for
   launch; revisit if players want frontier-taming to be a political act.

5. **Contraband / gray-market vendor rows.** Â§3.3's `contraband_when` is authored
   **empty** on purpose. Whether Hutt-dominant/underworld zones can *sell* restricted
   gear over the counter (vs. only via the smuggling loop, Guide_06 Â§4) is a direct
   lever on how criminal the underworld feels â€” and couples to the death/loot and PvP
   models. *Recommendation:* keep it empty at launch (contraband stays a smuggling-
   only reward), enable a small gray-market row later once the death-penalty model
   (below) makes carrying it risky.

6. **Overlay reset cadence.** Does the galaxy ever wipe back to seed (a seasonal
   reset), or is drift permanent (decay-only return to `baseline`)? *Options:*
   permanent (default; the MUSH's months-long "galactic narrative arc", Guide_26 Â§8);
   seasonal soft-reset (keeps late arrivals relevant, resets a lopsided map).
   *Recommendation:* **permanent** for the persistent-world promise; add a seasonal
   option only if one faction ever locks the map for good.

**Inherited, already-flagged owner decisions this loop touches but does not
re-decide** (see the cited docs): Force/Jedi scarcity & access, the death/loot
penalty model, and CP progression pace (WORLD_SIM_DESIGN Â§7, PERSISTENCE_DESIGN Â§5).
This composition treats Force-users as ordinary actors for influence/spawn/economy
purposes; the reactive `reward_dynamic.cp_bonus_*` hooks are on/off only and bake no
CP rate; and event effects never touch death/loot rules.

---

## 8. Grounding â€” MUSH guides drawn from

Read-only inspiration; recast to WEG D6 R&E, server-authoritative, Clone Wars era.

- **Guide_26 (Director AI)** â€” the whole compose-into-a-living-world thesis: Â§1 what
  the Director does, Â§2 influenceâ†’alert, Â§3 the 12-event menu + lifecycle +
  "opportunities not obligations" + concurrency constraints, Â§4 the player-feedback
  loop + era milestones, Â§5 ambient text, Â§6 the silent Faction Turn.
- **Guide_04 (Security Zones)** â€” Â§2/Â§7 dynamic security overlays from influence/
  events (the effective-security composition), Â§9 lawless incentives (quest/vendor
  reactivity to security).
- **Guide_24 (Encounters & Hazards)** â€” Â§1 the emergent danger layer, per-type
  cooldowns and zone caps (spawn pacing), the "world meets you halfway" goal that the
  Â§3.1 census realizes on the ground.
- **Guide_06 (Economy)** â€” Â§2 mission board refresh + context scaling, Â§3 bounty
  board (`bounty_surge`), Â§5/Â§7 the price-exploit warning and credit sinks (the
  Â§3.3 clamp answers it), Â§8 Bargain.
- **Guide_10 (Organizations & Factions)** & **Guide_11 (Territory Control)** â€” the
  actors whose influence and claims the blackboard reads; the single-entry-point and
  "keep the two influence tables separate" invariants this doc preserves.
- **Guide_20 (Scenes, Plots & Places)** â€” the RP layer that world events surface
  into (news headlines and player-run plots are how a `hutt_takeover` becomes a
  story, per Â§4/Â§5).

Companion project docs: `docs/WORLD_SIM_DESIGN.md`, `docs/FACTION_TERRITORY_DESIGN.md`,
`docs/PERSISTENCE_DESIGN.md`, `docs/WEG_FIDELITY.md`, `docs/MULTIPLAYER_FOUNDATION.md`.
Live data the schemas compose over: `data/zones_clone_wars.json`,
`data/quests_clone_wars.json`, `data/vendor_stock_by_zone.json`,
`data/npcs_clone_wars.json`, `data/creatures_clone_wars.json`, and the existing
`data/schemas/faction_zone_state.schema.json` (whose 12-event enum and influence
shape this design reuses verbatim).

---

## Proposed new schemas (to be authored as `data/schemas/*.json` by a future engineer)

Presented inline above; not created by this docs-only pass. All follow the project
convention (`schema_version`, `era`, `source_policy`/`source_note`, an `extra` blank,
JSON-Schema `$schema`/`$id`/`title`/`description`):

- `zone_situation.schema.json` â€” the derived read seam (Â§1.1).
- `world_pulse.schema.json` â€” the transient write seam (Â§1.2).
- `spawn_table.schema.json` â€” reactive spawns + census (Â§3.1).
- quest `availability` + `reward_dynamic` additive blocks + `quest_offer.schema.json`
  (Â§3.2).
- `vendor_dynamics.schema.json` â€” reactive stock/price (Â§3.3).
- `npc_dialogue_variants.schema.json` â€” reactive dialogue (Â§3.4).
- `world_event_definition.schema.json` + `world_event_instance.schema.json` â€” the
  event effect engine + state machine (Â§4).

Storage of all durable overlay state: `docs/PERSISTENCE_DESIGN.md` (this doc adds the
`zone_spawn_census`, quest-board cursor, and vendor restock-timer rows in Â§5).
