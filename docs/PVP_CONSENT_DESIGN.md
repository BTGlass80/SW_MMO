# PvP Consent & Target Eligibility (Zone + Duel + Bounty)

Status: DESIGN (docs + data shapes only â€” NO gameplay code). Author:
world-sim-designer. Companion to `docs/WORLD_SIM_DESIGN.md` Â§3 (security gradient),
`docs/FACTION_TERRITORY_DESIGN.md` Â§6 (the siege no-consent window), and the
`DIV-0016 / DIV-0017 / DIV-0006 / DIV-0018` combat/economy rulings already wired in
Wave F.

This doc specifies the **server-authoritative PvP consent stack** the owner ordered
for v1: three layers that compose into **one deterministic answer** to "may attacker
**A** fire on target **B** right now, and is it lethal?"

1. **Zone-based open PvP** â€” a lawful attack requires `effective_security == "lawless"`.
   Secured and contested are protected (no open PvP).
2. **Opt-in duels** â€” a `challenge â†’ accept` handshake makes exactly two players
   mutually attackable **regardless of zone** (even inside a secured newbie zone).
3. **Bounty-as-consent** â€” a credit-funded bounty on a player makes that target
   lawfully attackable by an eligible hunter **in contested + lawless zones** (beyond
   the lawless-only default), and is collected on the target's death.

> **Era / posture.** Clone Wars 20 BBY. Bounties are Hutt-cartel / Bounty Hunters'
> Guild framing (Guide_10); duels are cantina/arena sparring or matters of honor.
> No Imperial/Rebel framing. WEG R&E leads mechanics; SW_MUSH `Guide_11`/`Guide_10`
> and `security_zones_design_v1` are reference, not a port target.

> **âš  RECONCILIATION (2026-07-02, post-authoring) â€” Layer 1 is ALREADY SHIPPED.**
> While this design was being written, the main dev loop independently implemented and wired
> **Layer 1 (zone-based open PvP)** as **`scripts/rules/pvp_rules_model.gd`** under **DIV-0019**
> (`can_fire(shooter_zone, target_zone, shooter_tier, target_tier) â†’ {allowed, reason}`; lawless-only;
> player-vs-player targeting in `combat_arena`; kills routed through the DIV-0006 death loop + lawless
> full-loot corpse). Therefore:
> - **DIV-0019 is SPENT on the zone layer â€” do NOT reuse it.** Â§8 below is superseded: the **duel +
>   bounty consent extension needs its OWN new ledger row** (suggest **DIV-0021**; DIV-0020 is reserved
>   for siege â€” verify next-free at implementation).
> - **Remaining work = Layers 2 (duels) + 3 (bounties)** plus a thin **composition gate** that calls the
>   shipped `pvp_rules_model.can_fire` for the zone answer and layers duel/bounty/newbie precedence on top.
>   Do NOT create a second model that re-implements the zone check â€” **EXTEND/compose `pvp_rules_model`**
>   (fold the Â§1 `resolve()` into it, or wrap it).
> - **Player-vs-player targeting in `combat_arena` (Â§9 slice 4) is already done** by the loop; the HOT
>   slices reduce to duel targeting/KO-clamp, bounty escrow+collection, the composition gate, and snapshot fields.
> Everything else here (duel lifecycle, bounty ledger, the Â§10 truth table, anti-grief guards) stands as-is.

---

## 0. Where this sits in the existing code

| Concern | Existing owner | This design adds |
|---|---|---|
| Effective security tier of a node | `scripts/net/zone_state.gd::effective_security`, pure gate `scripts/net/security_gate.gd` | Consumes the tier; adds nothing to it |
| Lethal-vs-sparring clamp | `scripts/net/combat_arena.gd` (`set_player_lethal`, `SPARRING_MAX_SEVERITY=2`, DIV-0016/0017) | A **third clamp mode** (duel KO at incapacitated) + a **player-vs-player target** |
| Death consequence | `scripts/rules/death_penalty_model.gd` (DIV-0006), `network_manager._handle_player_death` | Reuses it verbatim; adds a `reason=="bounty"` collection hook |
| Credits | `scripts/rules/economy_model.gd` (DIV-0018) | Bounty escrow debit/credit uses the same plain-int wallet |
| Fire intent flow | `network_manager.submit_fire_intent` â†’ `combat_arena.submit_fire_intent` | A consent gate **before** the arena queues a PvP intent |

The current arena only ever points a player at an **NPC** target (`_player_target` â†’
a hostile creature or the shared training dummy). **Player-vs-player targeting does
not exist yet** â€” adding it is the headline engineering change this design gates.

---

## 1. The pure consent-resolution model (SPEC for `scripts/rules/pvp_consent_model.gd`)

> **DO NOT create this file as part of this design task.** This is the contract the
> `d6-rules-engineer` implements later. It is pure, static, socket-free, headlessly
> unit-testable, and **contains NO RNG** â€” PvP eligibility is a deterministic
> function of already-resolved state, exactly like `security_gate.gd`.

### 1.1 Contract

```
# Result shape (EXACTLY these three keys, per owner spec):
#   { "allowed": bool, "reason": String, "lethal": bool }
#
# reason enum (also the audit/scoring tag):
#   "self" | "not_colocated" | "pve_target"     -> hard denies / wrong caller
#   "siege"                                       -> allow via siege no-consent scope (hook)
#   "duel"                                        -> allow via active mutual duel
#   "newbie_protected"                            -> deny, a party is under protection
#   "bounty"                                      -> allow via bounty-as-consent
#   "lawless_open"                                -> allow via zone open-PvP
#   "protected_zone"                              -> deny, secured/contested, no consent path

static func resolve(attacker: Dictionary, target: Dictionary, ctx: Dictionary) -> Dictionary
```

**The model is a PURE ARBITER over pre-resolved flags.** Stateful lookups
("is there an active duel between A and B?", "is A eligible to collect B's bounty?",
"is this node inside a siege scope?") are resolved by the server into simple booleans
BEFORE the call â€” mirroring how `security_gate.get_effective_security(base, ctx)`
takes a `ctx` of already-resolved flags. The duel ledger and bounty ledger (Â§4, Â§5)
own that state; this model only applies the deterministic precedence.

**Inputs** (the server assembles these; all keys optional with safe defaults):

```jsonc
// attacker
{ "id": 12, "is_player": true, "node_id": "tatooine.jundland_wastes",
  "newbie_protected": false }
// target
{ "id": 34, "is_player": true, "node_id": "tatooine.jundland_wastes",
  "newbie_protected": false }
// ctx â€” everything the pure model needs, pre-resolved
{
  "zone_tier": "lawless",          // effective_security of the SHARED node (zone_state)
  "duel_active": false,            // an ACTIVE duel binds exactly this A<->B pair (Â§4)
  "duel_lethal": false,           // this duel's opt-in lethal flag (default false)
  "bounty_eligible": false,       // A may lawfully collect on B here (Â§5 pre-resolved)
  "siege_forced": false,          // node+pair inside an active siege no-consent scope (hook)
  "config": {}                     // optional tunable overrides (tiers/flags)
}
```

`attacker.node_id` / `target.node_id` let the model enforce co-location itself; the
server passes both from `_peer_zones`. Liveness ("is the shooter incapacitated?") is
**NOT** this model's job â€” the arena already drops intents from downed shooters
(`combat_arena.submit_fire_intent` guards `player_wound_severity >= DISABLED_SEVERITY`).

### 1.2 Resolution ORDER (precedence â€” first matching rule returns)

The precedence is chosen so that (a) hard denies short-circuit, (b) **explicit mutual
consent (duel) outranks blanket safety guards**, (c) safety guards (newbie) outrank
one-sided consent (bounty) and zone-open, and (d) a bounty is tagged before generic
lawless-open so a hunter's kill credits the contract.

```
resolve(A, B, ctx):
  1. if not B.is_player                      -> { false, "pve_target",     false }   # wrong caller: route to the PvE lethal gate (DIV-0017)
  2. if A.id == B.id                          -> { false, "self",          false }
  3. if A.node_id != B.node_id                -> { false, "not_colocated", false }   # must share the same node/zone
  4. if ctx.siege_forced                      -> { true,  "siege",         true  }   # HOOK â€” owned by FACTION_TERRITORY_DESIGN Â§6, OFF here
  5. if ctx.duel_active                       -> { true,  "duel",  ctx.duel_lethal } # mutual opt-in overrides zone AND newbie guard
  6. if A.newbie_protected or B.newbie_protected
                                              -> { false, "newbie_protected", false }# blocks all NON-consensual paths below
  7. if ctx.bounty_eligible                   -> { true,  "bounty",        true  }   # license to kill (dead-or-alive); tunable
  8. if ctx.zone_tier == "lawless"            -> { true,  "lawless_open",  true  }
  9. otherwise                                -> { false, "protected_zone", false }  # secured/contested, no consent path
```

**Why this order:**

- **Siege (4) top** so a forced org-war window (a *different* owner-gated system)
  can never be undercut by a bounty or newbie flag. Off by default here; the flag is
  only ever `true` when `FACTION_TERRITORY_DESIGN` Â§6.4 sets it. Reserved seam, not
  built by this design.
- **Duel (5) above newbie (6)** so a newbie who *chose* to accept a friendly duel
  gets their bout, but is otherwise fully shielded. A duel is the only two-sided
  consent, so it is the safest thing to honor unconditionally.
- **Newbie (6) above bounty/lawless (7,8)** so no protected player can be bounty-hunted
  or lawless-ganked, and (symmetrically) a protected player cannot use their immunity
  to gank others via bounty/lawless (see Â§6.1).
- **Bounty (7) above lawless-open (8)** so that in a lawless zone a hunter's kill on a
  bountied target resolves with `reason=="bounty"` (the collection/scoring hook fires),
  while a non-hunter in the same zone still gets `lawless_open`.

### 1.3 Lethality is PATH-driven, not purely zone-driven

`lethal` comes from the matched rule, not from the zone alone:

| reason | lethal | Downstream clamp the arena applies |
|---|---|---|
| `duel` (default) | `false` | **Duel KO clamp**: real damage up to **incapacitated (sev 3)**, never mortally/dead; reaching it ends the duel (Â§4.4). Distinct from the DIV-0016 training cap of 2. |
| `duel` (lethal opt-in) | `true` | No clamp; full DIV-0006 death penalty applies (graded by zone â€” penalty-free in secured, contested/lawless drop). |
| `bounty` | `true` | No clamp; DIV-0006 death penalty (graded by the zone the kill happened in). Enables collection on death. |
| `lawless_open` | `true` | No clamp; DIV-0006 lawless full-loot corpse. |
| `siege` | `true` | No clamp (owner-gated; see FACTION_TERRITORY_DESIGN). |
| any deny | `false` | Intent rejected before the arena queues it. |

The output stays exactly `{allowed, reason, lethal}` as specified; the **`reason`
field is what the arena maps to the correct clamp**. The engineer wires `reason ==
"duel" && !lethal` â†’ duel KO clamp (sev 3), everything else with `lethal==false` â†’
the existing DIV-0016 sparring clamp (sev 2), `lethal==true` â†’ no clamp.

---

## 2. Layer 1 â€” Zone-based open PvP

**Rule:** a lawful *open* attack (no handshake, no contract) requires
`zone_state.effective_security(node) == "lawless"`. Secured and contested are
protected. This is the owner's zone-based baseline; it composes as rule **8**.

- **Source of truth:** `zone_state.gd` (server), already persisted (mutable influence
  survives restart via `to_dict`/`apply_persisted`; alert/security are re-derived,
  never trusted from disk). The consent model consumes the derived tier only.
- **Lethal + loot:** already decided. `lawless_open` kills are lethal; the corpse
  full-loot / durability / insurance model is `death_penalty_model.gd` (DIV-0006) â€”
  lawless = 50% of unequipped inventory drops to a 4h-decay corpse, equipped never
  drops, credits kept. **This design changes none of that**; it only routes a
  player-target intent through the consent gate first.
- **Contested is NOT open PvP.** This is the deliberate reading of the owner's
  "secured/contested protected" ruling and is consistent with `WORLD_SIM_DESIGN`
  Â§3.1 (contested = "consent only"). Open `attack` on a player in contested returns
  `protected_zone`. PvE in contested is still lethal (DIV-0017) â€” that is a separate
  gate and unchanged.
- **The loser of a safe-zone duel is NOT full-looted** â€” duels never route through
  `lawless_open`; see Â§4.4.

---

## 3. Effective-security is the tier this layer reads

The consent model reads **one** number: the node's effective security tier, produced
by the existing single gate (`WORLD_SIM_DESIGN` Â§3.2 / `security_gate.gd`). So all the
world-sim shaping already in place composes for free:

- A **citizen** inside their player city is upgraded (lawlessâ†’contested,
  contestedâ†’secured) â†’ their home rooms become no-open-PvP for them.
- An **owning-org member** in a claimed lawless node is treated as contested â†’ no
  open PvP on home turf.
- A **Hutt surge** (influence â‰¥ 80) downgrades a tier â†’ a normally-contested back
  alley can become lawless (open PvP switches on) until patrols return.
- A **`republic_crackdown`** upgrades contestedâ†’secured â†’ open PvP switches off for
  the event's duration.

The consent model does **not** re-implement any of this; it just calls
`effective_security(node)` and branches on the result. This keeps "the security map
is alive" (weeks of play reshape where open PvP is even possible) working for PvP
with zero new logic.

---

## 4. Layer 2 â€” Opt-in duels

A **duel** makes exactly two players (`A`, `B`) mutually attackable **regardless of
zone**, including secured newbie zones, because it is genuine two-sided consent.
Grounds `WORLD_SIM_DESIGN` Â§3.3 (`challenge`/`accept`, ~10 min, ends on leaving the
zone), extended per the owner to work in secured too.

### 4.1 State & lifecycle (the duel ledger)

**Source of truth:** an **in-memory** server ledger â€” *not persisted* (intentional;
`WORLD_SIM_DESIGN` Â§3.3 â€” no stale duel survives a restart). Keyed by an unordered
pair. Spec for a pure companion model the engineer may add (`duel_ledger` â€” pure,
testable, no RNG):

```jsonc
// one duel record
{
  "a": 12, "b": 34,               // peer ids (the pair, unordered)
  "state": "active",              // offered | active | ended
  "lethal": false,                // opt-in lethal terms (default NON-lethal)
  "zone_id": "tatooine.mos_eisley.cantina",
  "offered_at_unix": 1740000000.0,
  "offer_ttl_unix": 1740000060.0, // OFFER auto-declines after OFFER_TTL (default 60 s)
  "started_at_unix": 0.0,
  "max_duration_unix": 0.0,       // optional hard cap (default 10 min from start; 0 = none)
  "result": null                  // on end: {"winner": 12, "outcome": "yield|ko|expire|abort|decline"}
}
```

Lifecycle:

```
        challenge(A -> B)                accept(B)
 (none) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶ OFFERED â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶ ACTIVE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
                             â”‚  decline(B)  /  OFFER_TTL elapses         â”‚
                             â–¼                                           â”‚ end triggers:
                           ENDED(decline|expire)                         â”‚  â€¢ yield(either) -> other wins
                                                                         â”‚  â€¢ KO: a party hits DUEL_YIELD_SEVERITY (Â§4.4)
 ACTIVE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶ â”‚  â€¢ max_duration elapses -> draw
   â€¢ either party leaves the zone / disconnects -> ENDED(abort, no win)  â”‚
                                                                         â–¼
                                                                   ENDED(yield|ko|expire|abort)
```

- **challenge(Aâ†’B):** requires A,B co-located (same zone) and neither already in an
  ACTIVE duel (one active duel per player). Creates `OFFERED`. Optional `lethal:true`
  in the offer (B sees the stakes before accepting).
- **accept(B):** `OFFERED â†’ ACTIVE`; both flagged mutually attackable (`duel_active`
  turns true for that pair in the consent model).
- **decline(B) / expire:** `OFFERED â†’ ENDED`; no flags set.
- **yield(either):** `ACTIVE â†’ ENDED(yield)`; opponent recorded as winner; combat stops.
- **KO conclude:** when a participant reaches `DUEL_YIELD_SEVERITY` (Â§4.4) the server
  ends the duel with the standing party as winner.
- **abort:** a participant leaves the zone or disconnects â†’ `ACTIVE â†’ ENDED(abort)`,
  no winner (matches Â§3.3 "until one leaves the zone"). The arena already clears a
  queued intent on zone-leave (`combat_arena.clear_intent`).

### 4.2 Evaluation cadence

- **`duel_active` lookup:** O(1) per fire-intent (pure, cheap).
- **KO conclude / abort:** evaluated at each **action-window resolution** (the arena
  already runs ~5 s windows and produces wound state) plus on the zone-leave /
  disconnect events the network layer already fires.
- **Offer TTL / max-duration:** swept on the **slow Director tick** (30 s) â€” a cheap
  pass over the small OFFERED/ACTIVE set. No 20 Hz work.

### 4.3 Zone independence & scoping

An active duel binds **only** the Aâ†”B pair. In a lawless zone, third parties can
still `lawless_open` either duelist (the duel doesn't shield them from the world). In
a secured zone, the duel is the *only* thing that makes A and B attackable â€” everyone
else remains protected. This is why the duel check (rule 5) is pairwise and sits
above the zone default.

### 4.4 Non-lethal by default â€” the duel KO model (references DIV-0016)

Duels **default to NON-lethal**, even though they can occur in safe zones, so a
cantina challenge can never grief-kill. But the training cap (`SPARRING_MAX_SEVERITY
= 2`, DIV-0016) stops at *wounded*, which gives no clean "who won" â€” so a duel uses a
**KO clamp one step higher**:

- `DUEL_YIELD_SEVERITY = 3` (**incapacitated**) â€” the duel's non-lethal ceiling.
  Return fire is real up to incapacitated but **never** mortally-wounded/dead.
- First participant to reach incapacitated **loses**; the duel ends (`outcome: "ko"`),
  and the loser is **auto-stabilized to `wounded`** and recovers via the normal
  medical loop (natural recovery DIV-0012 / First Aid DIV-0013). **No DIV-0006 death
  penalty** â€” no loot drop, no durability loss, no forced respawn relocation.
- **The loser of a safe-zone duel is NOT full-looted.** (Guaranteed: a non-lethal
  duel never sets `lethal`, so `_handle_player_death` is never invoked.)

**Lethal duel (opt-in, tunable):** if both sides agreed `lethal:true` in the offer,
the KO clamp is lifted and the full DIV-0006 penalty applies â€” **graded by the zone
the duel happened in**: penalty-free in secured (a KO + respawn, no loot), contested
2h-corpse drop, lawless 4h full-loot. This lets two consenting players stage a real
death-match without opening the zone to anyone else. Marked **tunable**; default
duels are non-lethal.

> **Engineering note (arena):** the arena's current `_player_lethal` flag is binary
> (cap 2 vs uncapped). Duels need a **third mode** (cap 3, KO, auto-stabilize). The
> engineer implements this as a per-encounter cap severity keyed off `reason=="duel"
> && !duel_lethal`, or by extending the arena's clamp to accept a cap value. This is
> the one genuinely new clamp; capture it in DIV-0019.

---

## 5. Layer 3 â€” Bounty-as-consent

Placing a credit-funded bounty on a player makes that target lawfully attackable by
an eligible hunter **beyond the lawless default** â€” specifically in **contested +
lawless** zones (**not secured** â€” the civic core / newbie zones stay a hard
sanctuary). Grounds `Guide_10` (Bounty Hunters' Guild = the PvP-override org) and the
existing `player_persistence` note that `active_bounty` "reduces PvP protection in
contested zones; bounty IS the consent for a guild hunter."

### 5.1 State & source of truth (the bounty ledger)

Bounties **are persisted** (a standing world contract must survive a restart), unlike
duels. Authoritative state = a server-side **bounty ledger**, persisted like the
territory claim ledger (`territory_model.to_dict`/`apply_persisted`); the per-target
`world_hooks.active_bounty` boolean already in `player_persistence.schema.json` stays
as the cheap snapshot/lookup mirror.

```jsonc
// one bounty record â€” ONE active record per target, accumulating pot
{
  "target_character_id": "char_vask",
  "pot_credits": 1500,            // sum of all contributions (escrowed, held by the ledger)
  "contributors": [               // who funded it (for refund on expiry / anti-self-collect)
    {"placer_id": "char_dax", "amount": 1000, "placed_at_unix": 1740000000.0},
    {"placer_id": "char_ric", "amount":  500, "placed_at_unix": 1740000300.0}
  ],
  "min_tiers": ["contested", "lawless"],   // zones where the bounty grants attackability
  "hunters_guild_only": false,             // if true, only BHG members may collect
  "expires_at_unix": 1740604800.0,         // BOUNTY_TTL from the last placement (default 7 days)
  "posting_fee_paid": 150                  // non-refundable sink already taken (Â§5.5)
}
```

### 5.2 Who may place, and the cost (funded from credits â€” DIV-0018)

- **Who:** any player may place a bounty on any *other* player (open board framing).
  **No self-bounty** (`placer == target` or same account) â€” blocks the funnel-to-alt
  farm. Optional stricter mode (`hunters_guild_only`) gates *collection*, not placing.
- **Cost:** `MIN_BOUNTY` (default **250 cr**) enforces real stake; the placer sets any
  amount â‰¥ min. Placement **debits the placer's credits** and moves them into
  `pot_credits` escrow (uses the same plain-int wallet as `economy_model`; the ledger
  holds the escrow exactly as `territory_model.org_credits` holds a treasury).
- A small **`POSTING_FEE`** (default **10%**, min 25 cr) is skimmed to a sink on
  placement â€” even a bounty that later expires or is paid off cost something (anti
  drive-by-harassment).

### 5.3 Who may collect

- Default: **any player** who lands the lethal killing blow on the target via the
  `bounty` consent path â€” **except** the target, any contributor/placer, or the same
  account (prevents self-collection funnels).
- `hunters_guild_only:true` restricts collection to Bounty Hunters' Guild members
  (`org.faction_id == "org_bounty_hunters_guild"`), for a "licensed hunter" server.
- **Eligibility (`bounty_eligible` in ctx) is server-pre-resolved** as: target has an
  active bounty record AND `zone_tier âˆˆ record.min_tiers` AND attacker is not
  target/placer/same-account AND (guild gate satisfied if set). The pure consent model
  just reads the boolean.
- **Self-defense reciprocity:** once a hunter fires on a bountied target under the
  `bounty` path, the server opens a **transient mutual-combat flag** between those two
  (like a duel) so the target may lawfully fight back for the duration of the
  engagement, even in contested. Otherwise the target would be a sitting duck. The
  bounty grants the *hunter's* right; reciprocity grants the *target's* self-defense.

### 5.4 How a bounty clears

- **Collected (target's death):** the kill's `reason=="bounty"` collection hook fires
  inside `_handle_player_death` â€” the collector's sheet is credited `pot_credits`
  (minus the posting fee already taken), `active_bounty=false`, record removed. The
  death itself runs the normal DIV-0006 penalty **graded by the zone the kill happened
  in** (contested 2h-drop / lawless full-loot) â€” being hunted down has stakes.
- **Expired:** `BOUNTY_TTL` (default 7 days from the last placement) elapses on the
  slow tick â†’ escrow refunded to contributors pro-rata **minus the non-refundable
  posting fee**; record removed.
- **Paid off (target buys it out):** the target may **settle** their own bounty by
  paying `pot_credits Ã— PAYOFF_MULTIPLIER` (default **1.5Ã—**, a credit sink) â€” models
  buying your way out of Hutt debt / Guild contract. Escrow refunds to contributors;
  the settlement is a sink; record removed. Tunable; can be disabled for a
  harder-boiled server.

### 5.5 Stacking

- **One active record per target**, with an accumulating `pot_credits` and a
  `contributors` list. New placements add to the pot and **extend** the TTL to
  `now + BOUNTY_TTL` (a well-funded target stays hunted).
- `BOUNTY_MAX` (default **25,000 cr**) caps the pot so a single kill can't pay out an
  economy-breaking sum.

### 5.6 Anti-abuse guards (bounty)

- **No self-bounty** (placer â‰  target, different account) â€” kills the alt-funnel farm.
- **No self/placer/same-account collection** â€” the placer can't recover their own
  escrow by having the target killed by an alt.
- **Placement cooldown:** `BOUNTY_PLACE_COOLDOWN` (default **5 min** per placer) caps
  harassment spam; persisted per character like the faction-switch cooldown.
- **Minimum bounty + posting fee** make bounties cost real, non-refundable credits.
- **Secured excluded:** a bountied player is still safe in secured zones â€” the hunter
  must catch them in contested/lawless. Preserves new-player safety and the civic core.
- **Collection requires a real lethal kill** via the `bounty` path â€” you cannot
  "collect" via a non-lethal duel KO.

---

## 6. Anti-grief guards (cross-layer)

### 6.1 Newbie protection

A fresh anti-grief guard (no prior system). **Symmetric and one-way-clearable:**

- **Effect:** while protected, the character can be neither attacked via `bounty` nor
  `lawless_open`, **and** cannot initiate those paths against others (no immune
  ganking). It composes as rule **6**, *below* the duel rule â€” so a protected player
  may still opt into a friendly duel, but is otherwise shielded.
- **Default:** ON at chargen. Persisted as `world_hooks.newbie_protected` (new
  boolean, mirrors the existing `active_bounty` / `lawless_warning_ack_session`
  siblings). Snapshotted so clients can badge "protected."
- **Clears (one-way â€” cannot be re-enabled, so no gank-then-hide flip):** the FIRST
  time the player **acknowledges the lawless-entry warning** (they chose danger â€” the
  `lawless_warning_ack` flow already exists) OR a fixed early-play grace elapses,
  whichever first; plus a manual `/pvp on` opt-out. The grace threshold is
  **tunable** and deliberately **playtime/opt-in based, NOT CP-based**, so it does not
  touch the OPEN OWNER DECISION on CP pace (Â§7).
- **Scope note:** newbie protection here covers **PvP** only. Whether it also softens
  **hostile PvE** (DIV-0017) for new players is a separate, flagged sub-decision (Â§7).

### 6.2 No forced PvP in secured/contested except via consent

By construction: secured and contested return `protected_zone` unless an active
**duel** (mutual) or eligible **bounty** (target opted in by being bountied; contested
only) applies. The only *forced* (non-consensual) contested PvP anywhere in the design
is the **siege no-consent window** â€” an owner-gated system defined in
`FACTION_TERRITORY_DESIGN` Â§6, represented here as the off-by-default `siege_forced`
hook (rule 4). This design does not build it.

### 6.3 Guards already inherited for free

- **Downed shooters can't fire** â€” arena drops their intents (`>= DISABLED_SEVERITY`).
- **Zone-leave cancels a queued shot** â€” `combat_arena.clear_intent` on travel.
- **Rate limiting** â€” `network_manager._rate_ok` already throttles intent RPCs.
- **Server owns all dice/seed** â€” no client can fabricate a hit or a kill.

---

## 7. OPEN OWNER DECISIONS & defaulted sub-decisions (FLAGGED â€” not settled)

These are surfaced with a recommendation; none is baked as settled truth.

1. **Bounty lethality granularity.** Default: a bounty is a **license to kill**
   (`lethal:true`), collected on death, graded by zone penalty. *Alternative:*
   non-lethal "capture" bounties (KO + turn-in) â€” but then collection can't key on
   death and needs a separate turn-in flow. **Recommend** lethal-kill v1;
   capture-bounties as a later mode. Add to DIV-0019.
2. **Does a bounty reach secured zones?** Defaulted **NO** (safe-zone sanctuary;
   `min_tiers = [contested, lawless]`). The owner phrasing "beyond lawless" reads as
   "into contested," and letting hunters kill in the civic/newbie core would gut
   new-player safety. **Recommend** keep secured excluded.
3. **Duel default lethality & KO cap.** Defaulted **non-lethal, KO at incapacitated
   (sev 3), auto-stabilize, no death penalty**, with lethal-duel opt-in. The KO cap
   (3) diverges from the DIV-0016 training cap (2). **Recommend** as written; tunable
   down to 2 (first-to-wounded) for a gentler server.
4. **Open vs. guild-gated bounty collection.** Defaulted **open board** (anyone may
   collect, `hunters_guild_only:false`), with a guild-only switch. **Recommend** open
   for a small prototype population; flip to guild-only if hunting needs an identity.
5. **Newbie-protection trigger & PvE scope.** Defaulted **playtime/opt-in clear (NOT
   CP-based)**, PvP-only. Whether it also shields new players from hostile **PvE**
   (DIV-0017) is deferred â€” **recommend** yes, extend the same flag to the PvE lethal
   gate later. The exact grace threshold is **owner-tunable** and must stay decoupled
   from CP pace.
6. **CP / reward for PvP outcomes.** Whether a duel win, a bounty collection, or a
   lawless kill grants CP (and how much) couples to the **OPEN OWNER DECISION on CP
   progression pace** (DIV-0007) â€” **not decided here.** The `reason` tag on every
   resolved kill lets a reward be computed later without baking a rate.

---

## 8. Divergence â€” reserve a NEW row (suggest **DIV-0021**) for the duel + bounty consent extension

> **SUPERSEDED (2026-07-02):** DIV-0019 is now SPENT on the shipped **zone** layer
> (`pvp_rules_model.gd`, wired by the dev loop). The **duel + bounty consent extension**
> designed here needs its OWN row â€” suggest **DIV-0021** (DIV-0020 is reserved for siege;
> verify next-free at implementation). Add it to `docs/DIVERGENCE_LEDGER.md` **BEFORE**
> writing code. (This design must not edit the ledger â€” another session owns it.) Suggested content:

- **ID:** DIV-0021 (verify next-free)
- **Area:** PvP consent extension â€” opt-in duels + bounty-as-consent (layered on the DIV-0019 zone gate)
- **WEG Source:** R&E â€” PvP is GM-adjudicated; combat lethality at GM discretion; no
  formal consent/bounty rules (dice mechanics are era- and mode-agnostic).
- **SW_MUSH Behavior:** `security_zones_design_v1` three-tier consensual-PvP gradient;
  `Guide_10` bounties + Bounty Hunters' Guild; `Guide_11` siege forced-PvP window.
- **Prototype Behavior:** three composable consent layers resolved by a pure,
  server-authoritative `pvp_consent_model.resolve()` â†’ `{allowed, reason, lethal}` with
  the precedence in Â§1.2. **Open PvP requires `effective_security=="lawless"`;
  secured+contested are protected.** Duels (mutual opt-in) attackable in any zone,
  **default non-lethal with a KO clamp at incapacitated (sev 3), auto-stabilize, no
  death penalty** â€” a *new* clamp distinct from the DIV-0016 training cap (2);
  lethal-duel opt-in reuses DIV-0006. Bounties (credit-funded, DIV-0018 escrow) grant
  lethal attackability in **contested+lawless** (not secured), collected on death via
  the DIV-0006 path, with min-bounty / posting-fee / cooldown / no-self anti-abuse
  guards. Newbie protection (persisted, symmetric, one-way, PvP-only) shields new
  players from bounty + lawless PvP but not from an accepted duel.
- **Reason:** owner direction 2026-07-xx â€” zone-based PvP with an explicit three-layer
  consent stack; safe onboarding + consensual danger over open ganking.
- **Status:** Accepted (design); wiring pending.

---

## 9. Implementation slices (for the main dev loop)

Ordered. `[PAR]` = pure, parallelizable, independent of the netcode session that owns
`network_manager.gd` / `combat_arena.gd`. `[HOT]` = touches those hot-path files
(coordinate with their owning session; do **not** land concurrently with this design).

**Pure first (unblockable):**

1. `[PAR]` **`scripts/rules/pvp_consent_model.gd`** (Â§1) + `scripts/tests/
   pvp_consent_model_smoke.gd` â€” implement `resolve()` and assert the **entire Â§10
   truth table** (every zone Ã— duel Ã— bounty Ã— newbie cell) plus the hard-deny
   short-circuits. Wire into `tools/check_project.ps1`. **No RNG, seedless.**
2. `[PAR]` **duel ledger** (`scripts/rules/duel_ledger.gd`, Â§4.1) + smoke â€” offer/
   accept/decline/expire/yield/KO/abort transitions, one-active-duel invariant,
   pairwise `duel_active(a,b)` lookup. Pure, in-memory, no persistence.
3. `[PAR]` **bounty ledger** (`scripts/rules/bounty_ledger.gd`, Â§5.1) + smoke â€” place
   (escrow debit, min/fee/cooldown/no-self), collect, expire (pro-rata refund), pay
   off, stacking/cap, `bounty_eligible(attacker,target,tier)` pre-resolver.
   `to_dict`/`apply_persisted` like `territory_model`. Deterministic; seed only if a
   tie-break ever needs it (prefer none).

**Then hot-path wiring (netcode session, in order):**

4. `[HOT]` **Player-vs-player targeting in `combat_arena.gd`** â€” let `_player_target`
   point at another **player** (not just an NPC), resolve the exchange with the target
   player's own sheet pools on the target side, and add the **duel KO clamp** (Â§4.4)
   as the third clamp mode alongside the DIV-0016 sparring cap and the DIV-0017
   uncapped lethal path.
5. `[HOT]` **Fire-intent consent gate in `network_manager.submit_fire_intent`** â€” when
   the target is a **player**, assemble the `pvp_consent_model` inputs (zone tier from
   `zones.effective_security`, `duel_active`/`duel_lethal` from the duel ledger,
   `bounty_eligible` from the bounty ledger, `newbie_protected` from both sheets), call
   `resolve()`, reject on `!allowed` (surface `reason` to the shooter), and set the
   shooter's clamp mode from `reason`/`lethal` before queuing the intent. NPC targets
   keep the existing DIV-0017 PvE path untouched.
6. `[HOT]` **Duel RPCs** â€” `challenge(target)` / `accept` / `decline` / `yield`;
   server drives expire/KO/abort on window-resolution + the slow tick (Â§4.2); emit
   duel-state notices to both peers.
7. `[HOT]` **Bounty RPCs** â€” `place_bounty(target, amount)` / `pay_off_bounty` (escrow
   via the DIV-0018 wallet); collection hook inside `_handle_player_death` when the
   kill's `reason=="bounty"`; expiry/refund sweep on the slow tick; self-defense
   reciprocity flag (Â§5.3).
8. `[HOT]` **Snapshot fields** clients need â€” per the local player: `newbie_protected`,
   `active_bounty` (+ pot), current duel state/opponent; per other visible players: an
   **attackable-now** hint (the client can call the same pure `resolve()` against the
   broadcast tier/flags to render a red/green reticle, but the **server remains
   authoritative** â€” the client hint is cosmetic). Zone tier is already broadcast in
   `zone_summary`.

---

## 10. CONSENT TRUTH TABLE

Attacker **A** firing on target **B**, co-located, `A â‰  B`, both players. `duel` =
an **active** Aâ†”B duel (non-lethal terms unless noted). `bounty` = B has an active
bounty **and A is an eligible collector for this tier**. Output = `allowed / lethal /
reason`. Precedence from Â§1.2 (siege hook omitted â€” always off here).

| Zone (effective) | Duel Aâ†”B | Bounty (A eligible) | Result | reason |
|---|---|---|---|---|
| **secured** | none | none | **deny** | `protected_zone` |
| **secured** | none | eligible* | **deny** | `protected_zone` (bounty excludes secured) |
| **secured** | active | none | **allow / non-lethal** | `duel` |
| **secured** | active | eligible* | **allow / non-lethal** | `duel` (duel outranks bounty) |
| **contested** | none | none | **deny** | `protected_zone` |
| **contested** | none | eligible | **allow / lethal** | `bounty` |
| **contested** | active | none | **allow / non-lethal** | `duel` |
| **contested** | active | eligible | **allow / non-lethal** | `duel` (duel outranks bounty) |
| **lawless** | none | none | **allow / lethal** | `lawless_open` |
| **lawless** | none | eligible | **allow / lethal** | `bounty` (tagged for collection) |
| **lawless** | active | none | **allow / non-lethal** | `duel` (friendly bout in a dangerous zone) |
| **lawless** | active | eligible | **allow / non-lethal** | `duel` (duel outranks bounty + zone) |

\* In secured, `bounty` never becomes eligible (secured âˆ‰ `min_tiers`), so those rows
resolve on the next applicable rule.

**Newbie-protection overlay** (either A or B protected): every row **flips to `deny /
newbie_protected`** EXCEPT the `duel`-active rows, which stay `allow / non-lethal`
(rule 5 sits above rule 6). A duel-lethal opt-in flips the `duel` rows' lethal column
to `lethal` and, on death, applies the zone-graded DIV-0006 penalty (secured =
penalty-free KO+respawn).

---

## Referenced systems

- `scripts/net/zone_state.gd`, `scripts/net/security_gate.gd`,
  `data/schemas/security_zone.schema.json` â€” the tier this design reads.
- `scripts/net/combat_arena.gd` â€” the clamp modes (DIV-0016 sparring cap, DIV-0017
  lethal flag) this design extends with a duel KO clamp and a player target.
- `scripts/rules/death_penalty_model.gd` (DIV-0006) â€” reused verbatim for lethal PvP
  and bounty collection.
- `scripts/rules/economy_model.gd` (DIV-0018) â€” the wallet bounty escrow debits/credits.
- `docs/WORLD_SIM_DESIGN.md` Â§3 â€” the security gradient + the Â§3.3 consent seed this
  formalizes and extends.
- `docs/FACTION_TERRITORY_DESIGN.md` Â§6 â€” the siege no-consent window (the
  `siege_forced` hook, rule 4; owned there, not built here).
- `data/schemas/player_persistence.schema.json` â€” `world_hooks.active_bounty` (mirror)
  + the new `world_hooks.newbie_protected` boolean this design adds.
