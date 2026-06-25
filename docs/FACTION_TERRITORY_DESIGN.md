# Faction Territory, Player Cities & the Siege Loop (Drop 6D)

Status: DESIGN (docs + data schemas only — no gameplay code). Author:
world-sim-designer. Companion to `docs/WORLD_SIM_DESIGN.md` (Director/security)
and `docs/PERSISTENCE_DESIGN.md` (storage).

This document specifies the **player-driven territorial layer** — the part of the
world players permanently reshape and fight over: claimable nodes, passive income,
guard NPCs, player cities, and the **org-vs-org hostile-takeover state machine**.
That state machine is the **headline PvP loop** and is the concrete realization of
the MUSH's planned-but-never-delivered **"Drop 6D"** (`Guide_11_Territory_Control`
§7: *"Contest state machine, 7-day timer, rival org no-consent PvP, hostile
takeover — Planned"*).

Grounded in `C:\SW_MUSH\docs\design\Guide_10_Organizations_Factions.md`,
`Guide_11_Territory_Control.md`, `Guide_12_Player_Cities.md`, and
`security_zones_design_v1.md` — adapted from MUSH-staff-driven commands into an
**automated server simulation** on this project's server-authoritative model
(server owns truth, 5 s WEG action windows, 20 Hz movement, clients send intents).

> **Two influence systems, kept separate.** *Director* faction influence
> (`faction_zone_state`, WORLD_SIM_DESIGN) drives the narrative/security overlay.
> *Org/territory* influence (below) gates claims and sieges. They are different
> tables with different purposes, bridged only by faction axis for narrative —
> exactly as the MUSH keeps them apart (Guide_11 §2 "Important"). Do not conflate.

---

## 1. Organizations (the actors)

Per `Guide_10`, recast Clone Wars. A character belongs to **one faction** and up
to **three guilds**. Factions are Director-managed and compete for zone influence;
guilds give a flat CP training discount and a profession community.

| Faction | Axis | Notes |
|---|---|---|
| **Galactic Republic** | republic | Legitimate authority (the MUSH "Imperial" mechanical slot, recast). |
| **Separatist Alliance (CIS)** | cis | Insurgent slot. |
| **Hutt Cartel** | hutt | Criminal underworld; smuggling, debt. |
| **Bounty Hunters' Guild** | independent | PvP override (bounty = consent), tracking. |
| **Independent** | independent | Default; no affiliation. |

Membership, rank, rep, stipends, and the 7-day switch cooldown persist on the
character (`player_persistence.schema.json::org`). Ranks gate territorial actions:
**claim/guard at rank 3+**, **found/expand a city at rank 5 (org leader)**.

---

## 2. Territory influence (gating claims and sieges)

Each org tracks an **influence score per zone**, 0–150 (Guide_11 §2). It is the
org's earned right to operate territorially in that zone. Authoritative state lives
in a per-(org,zone) territory-influence record (Persistence doc); the value also
appears as `influence_tier_at_claim` on each claim.

| Threshold | Score | Unlocks |
|---|---|---|
| **Presence** | 25+ | Org name shows in `look`/zone readout |
| **Foothold** | 50+ | May **claim** nodes; may **declare a siege**; may found a city |
| **Dominance** | 75+ | Security upgrade on claims + better passive income |
| **Control** | 100+ | Full zone branding |

**Earning** (Guide_11 §2; starting values, owner-tunable): member present in zone
hourly +1/member; kill NPC in zone +2; complete mission/bounty/smuggling in zone
+5; **PvP victory in zone +15**; invest 1,000 treasury credits +10 (rank 3+,
min 1,000 / max 10,000 per investment, blocked in secured zones).

**Decay:** if no org member is present in a zone for 48 h, influence decays −5/day;
active presence resets the timer. **You must maintain a real presence** — you
cannot invest once and walk away. Sustained absence ultimately lapses claims.

---

## 3. Claiming nodes (Drops 6A–6C, already proven in the MUSH)

Schema: `data/schemas/territory_claim.schema.json`. Authoritative per-node state.

**Claim rules** (Guide_11 §3): rank 3+; standing in the node; node is in a
**contested or lawless** zone (secured cannot be claimed); ≤3 claims/zone, ≤10/org;
one-time treasury cost (default 5,000 cr); weekly maintenance (default 200 cr);
not player housing; an existing claim cannot be overridden **except via a siege
(Drop 6D, §6)**.

**What a claim grants:**
- **Security upgrade for owning members** — a lawless node is treated as
  *contested* for the org (PvP-consent protection on home turf). This is step 3 of
  the effective-security function (WORLD_SIM_DESIGN §3.2).
- **A visible claim tag** in the zone readout.
- **A guard NPC slot** (§4).
- **Passive resource income** (§5).

**Guard NPCs** (§4) and **resource nodes** (§5) follow; **maintenance lapse**: a
daily maintenance tick auto-unclaims a node whose org treasury can't cover it
(guard dismissed too).

---

## 4. Guard NPCs

Rank 3+ may station one aggressive guard NPC per claimed node (Guide_11 §4):
one-time cost (default 500 cr) + weekly upkeep (default 100 cr) on top of node
maintenance. Faction-flavored from a template keyed by org axis
(`territory_claim::guard.template_key`), Clone Wars recast:

| Org axis | Guard template (example) |
|---|---|
| republic | Clone trooper sentry, blaster rifle |
| cis | B2 super battle droid enforcer |
| hutt | Gamorrean enforcer, vibro-axe |
| independent / BHG | Sharp-eyed hunter, heavy blaster |

Guards attack hostile intruders in the node and are a scoring target during a
siege (defeating the guard moves the contest score — §6.5). Guards resolve combat
through the same server-authoritative action-window system as everything else.

---

## 5. Resource nodes (passive income)

Claimed nodes yield resources on the **daily resource tick** (part of the slow-tick
schedule, WORLD_SIM_DESIGN §4), scaled by `(security, influence_tier)` —
**lawless yields more than contested** (Guide_11 §5; higher risk, higher reward):

| Security | Tier | Daily yield (starting bands) |
|---|---|---|
| Contested | Foothold | 50–150 cr |
| Contested | Dominant | 100–300 cr + 1–2 metal |
| Contested | Control | 150–400 cr + 1–2 metal + 1 rare |
| Lawless | Foothold | 75–200 cr |
| Lawless | Dominant | 150–400 cr + 2–4 metal + 1–2 chemical |
| Lawless | Control | 250–600 cr + 2–4 metal + 2–4 chemical + 1–2 rare |

Credits to the org treasury; resources to org shared storage. Recorded in
`territory_claim::income.last_yield`. The server owns the yield RNG (seeded).

---

## 6. The siege / hostile-takeover state machine — **Drop 6D (headline PvP loop)**

This is the part the MUSH planned and never built. Schema:
`data/schemas/siege_state.schema.json`. One record per active contest. The server
owns it; it survives restart; the slow tick advances its timers; all RNG and
scoring are server-authoritative.

### 6.1 What a siege is

An org (**attacker**) formally contests a node currently claimed by another org
(**defender**), opening a bounded, telegraphed window of **forced rival-org PvP**
at the node. If the attacker holds enough of the contest at window close, the claim
**transfers**; otherwise the defender keeps it. A lockout then prevents immediate
re-contest. This is org-vs-org endgame: a small disciplined org can attack from a
safe base (its city/claims) and try to take a rival's turf — and must defend its
own.

### 6.2 Declaration preconditions (server-validated)

To enter `declared`, all must hold (snapshotted into `siege.config` so a live
siege is immune to admin retunes):

- Target node is a **territory claim** (or a city expansion node — §7.4) in a
  **contested or lawless** zone. **Secured zones and city-upgraded-to-secured
  citizen rooms can never be sieged** (the citadel rule, §7.3).
- Attacker org has **≥ Foothold (50) influence** in the zone
  (`config.attacker_min_influence`).
- No active siege on the node and the node is **not in lockout**.
- Attacker meets rank/standing to declare (rank 4+ leadership recommended).

### 6.3 States and transitions

```
            declare (preconditions met)
   (none) ─────────────────────────────────▶  DECLARED
                                                  │  warning_hours elapse (default 24h)
                                                  │  defender is warned; window telegraphed
                                                  ▼
                                               ACTIVE  ◀───────────────┐
   attacker influence falls below gate            │                   │ (contest continues
   during DECLARED  ─────────────▶ ABORTED        │                   │  through the window)
   (terminal; no transfer)                        │  contest_window_hours elapse (default 48h)
                                                   │  OR attacker concedes / defender wipes attacker
                                                   ▼
                                               RESOLVING
                                       (server tallies score this tick)
                                                   │
                         attacker_fraction ≥ control_threshold (default 0.6)?
                              │ yes                          │ no
                              ▼                              ▼
                          CAPTURED                        REPELLED
                  (claim → attacker;              (defender keeps claim;
                   income/guard reset)             both into lockout)
                              │                              │
                              └──────────────┬───────────────┘
                                             ▼
                                          LOCKOUT  ──── lockout_hours elapse (default 168h / 7d) ───▶  (siege archived)
```

**State meanings** (`siege_state::state` enum):

- **`declared`** — the **defender-warning / telegraph** window. The contest is
  announced (news + comlink to the defender org); no forced PvP yet. This is the
  "planned-but-watched" telegraph that mirrors the MUSH's design philosophy that
  territorial moves are *visible* and play out over real time (Guide_12 §3's 24h
  city-expansion telegraph; rivals "know where you're pushing"). Default
  `warning_hours = 24`.
- **`active`** — the **contest window**: forced rival-org no-consent PvP is live at
  the node + declared adjacency (§6.4); scoring accrues (§6.5). Default
  `contest_window_hours = 48`. The MUSH's "7-day timer" is captured by the full
  declared→active→lockout span being multi-day and owner-tunable — concretized
  into named phases rather than one opaque countdown.
- **`resolving`** — a single-tick tally state: the server reads `score`, computes
  `attacker_fraction = attacker_points / (attacker_points + defender_points)`,
  compares to `config.control_threshold`, and routes to captured/repelled.
- **`lockout`** — post-resolution cooldown; the node cannot be re-contested until
  `lockout_hours` elapse (default 168 h / 7 days). Prevents perpetual griefing of
  one node.
- **`captured`** (terminal) — claim ownership transfers to the attacker; guard
  dismissed, income band re-evaluated for the new owner, news headline emitted.
- **`repelled`** (terminal) — defender keeps the claim; news emitted.
- **`aborted`** (terminal) — declaration cancelled before `active` (e.g. attacker
  influence dropped below the gate during the warning window). No transfer.

Transitions are driven by the **slow tick** comparing `phase_deadline_unix` to
wall-clock and by scoring events; never by a client. The server re-derives every
transient flag each tick and trusts no client report.

### 6.4 The rival-org no-consent PvP window (`active` only)

While `state == active`, `siege.pvp_consent.active = true` and members of the
attacker and defender orgs are **mutually flagged for no-consent PvP** at
`pvp_consent.scope_node_ids` (the claim node + declared adjacency) — **regardless
of the zone's normal consent rules**. This is the only mechanism that forces
contested-zone PvP, and it is tightly scoped: only the two contesting orgs, only at
the contested nodes, only for the window. Outside that scope/window, normal
security-zone consent (WORLD_SIM_DESIGN §3.3) applies. The effective-security
function (WORLD_SIM_DESIGN §3.2) consults the siege state to apply this; a
bystander third org is unaffected unless it joins (owner question §9).

### 6.5 Scoring (server-authoritative)

The contest is decided by accumulated `score` (`siege_state::score`), all
server-owned and audit-logged in `score.contributions`. Scoring events (point
values owner-tunable):

| Event (`kind`) | Side | Why it scores |
|---|---|---|
| `pvp_kill` | killer's side | Winning the forced PvP in scope |
| `guard_defeated` | attacker | Breaking the defender's stationed guard |
| `control_hold_tick` | side holding the node at a periodic check | Map presence / holding ground over time |
| `objective` | either | Optional node objectives (sabotage a console, raise a banner) |
| `sabotage` | attacker | Optional pre-window or in-window disruption |

Combat that produces `pvp_kill` resolves through the existing action-window system;
the siege consumes the **resolved outcome**, never raw client input. At
`resolving`, `attacker_fraction ≥ control_threshold` (default 0.6) ⇒ capture. A
threshold above 0.5 means the attacker must *clearly* win, not merely tie — the
defender holds on a draw.

### 6.6 Outcome effects

- **Captured:** `territory_claim.org_id` ← attacker; guard dismissed; income band
  re-evaluated; `outcome.result = captured`; news headline; lockout begins.
- **Repelled:** claim unchanged; `outcome.result = repelled`; news; lockout begins.
- **Aborted:** no change; `outcome.result = aborted`.

Every outcome emits a **news headline** into the Director news feed
(WORLD_SIM_DESIGN §2.4) — the "did you see what happened last night?" social
currency the canon prizes. A capture is a server-visible event other players read
about and respond to.

### 6.7 Anti-grief & fairness guardrails

- **Telegraph:** the `declared` warning window guarantees the defender is warned
  and can rally before forced PvP starts.
- **Lockout:** prevents re-contesting the same node for `lockout_hours`.
- **Influence gate:** an attacker must have *earned* a foothold to declare — no
  drive-by sieges from an org with no presence.
- **Scoped consent:** forced PvP is limited to the two orgs at the contested nodes;
  the rest of the zone keeps normal rules.
- **City citadel immunity:** citizen-secured city rooms can't be sieged (§7.3).
- **Maintenance still applies:** a besieging attacker who lets their own claims
  lapse loses ground elsewhere — sieges have an opportunity cost.

---

## 7. Player cities (Guide_12)

Cities are the largest persistent player-owned structures — a *named place* an org
grows into. They sit atop territory and amplify it.

### 7.1 Founding & expansion (rank-5 org leader)

Prereqs (Guide_12 §2): rank-5 leader; a tier-5 HQ in a **contested or lawless**
zone (cities cannot be founded in secured zones — frontier/underworld governance
by design); **≥ 50 influence** in the zone; treasury holds the founding cost
(by HQ subtype — starting values 25k / 75k / 200k cr). Expansion claims adjacent
same-zone rooms, **one per 24 real-time hours** (the telegraph rate-limit), up to a
tier cap (5 / 10 / 20 rooms). The 24h cadence makes expansion a *visible political
act* rivals can watch — the same telegraph philosophy as the siege warning window.

### 7.2 Roles

Founder, Mayor, Citizen, Guest, Outsider, Banished
(`player_persistence::city_role.role`). Citizens are org members in good standing;
the city exists for them. Mayor governs (tax rate, MOTD, guests, banishment,
citizen-only rooms); Founder is sovereign (assign Mayor, set rate cap, dissolve).

### 7.3 The citizen security upgrade — the **citadel rule**

Inside a city room **as a citizen**, effective security is upgraded one step:
contested → **secured**, lawless → **contested** (Guide_12 §6). This is step 2 of
the effective-security function (WORLD_SIM_DESIGN §3.2) and is the **most-permissive
last word for citizens** — even a hostile Director downgrade can't make a citizen
less safe than their own city allows. Outsiders get the zone base. **A
citizen-secured room cannot be sieged** (§6.2) — the city is a citadel a small
disciplined org defends and projects power from. Outsiders who follow members in
are still in the underlying (lawless/contested) tier and remain attackable.

### 7.4 Cities and sieges

A city's **HQ City-Center rooms are permanent and citizen-secured → never
siegeable.** A city's **expansion rooms** in a still-contested/lawless tier
(non-citizen-secured) *can* be contested via the same Drop-6D machine (treated as
claim nodes), so a rival can chip at a city's outer footprint without being able to
storm its secured core. This gives cities a defensible heart and a contestable
frontier — the right strategic shape.

### 7.5 City economy & governance (data hooks)

Tax (0–10%, Mayor-set under a Founder rate cap) skims city-room commerce into the
treasury, invisible to the payer (Guide_12 §5). `+city home` gives citizens an
hourly teleport to the HQ entry (cooldown persisted on the character). Banishment
(default 30 days, persisted) is a real political tool. These persist per
`player_persistence::city_role` and a city record (Persistence doc); their detailed
rules are faithful to Guide_12 and are not re-litigated here.

---

## 8. Cadence summary (how this layer ticks)

All on the **slow-tick schedule** (WORLD_SIM_DESIGN §4), never the 20 Hz path:

| Cadence | Territory/siege work |
|---|---|
| Every slow tick | Siege phase-deadline checks + state transitions; siege no-consent flag re-derivation; control-hold scoring checks |
| Hourly | Org presence influence; `+city home` cooldown housekeeping |
| Daily | Influence decay; claim maintenance charge (lapse if unfunded); resource-node yields |
| On event | Siege declaration/resolution; claim/unclaim; guard station/dismiss; city found/expand/dissolve |

PvP-kill and guard-defeat scoring are event-driven off resolved action-window
outcomes, not polled.

---

## 9. OPEN OWNER DECISIONS (flagged — NOT decided here)

These deferred owner calls touch this layer. Represented as data hooks; not settled.

1. **Death / loot penalty in siege/lawless PvP.** The whole siege loop assumes
   *some* stakes for dying in a forced-PvP window, but the exact model
   (soft / security-graded / full-loot lawless) is the owner's death-penalty
   decision (WORLD_SIM_DESIGN §7.2). Recommendation there: security-graded, lawless
   harsh — which gives sieges weight without a separate ruling here.
2. **Force / Jedi in sieges.** Whether Force-users get any siege advantage depends
   on the Force-scarcity/access decision (WORLD_SIM_DESIGN §7.1). The siege machine
   treats all combatants uniformly; any Force tilt is downstream of that call.
3. **CP rewards for siege participation.** Whether winning a siege grants CP, and
   how much, couples to the CP-pace decision (WORLD_SIM_DESIGN §7.3). The siege
   schema logs participation (`score.contributions`) so a reward can be computed
   later, but bakes no rate.

Any divergence from WEG/MUSH these create gets a `docs/DIVERGENCE_LEDGER.md` row
first.

---

## 10. Open questions for the owner

1. **Third-party intervention in a siege.** Can a non-contesting org or a lone
   ally join the no-consent window (e.g. mercenaries hired by the defender)?
   Recommend v1 = strictly the two contesting orgs; revisit after launch.
2. **Siege phase durations for launch.** Defaults are 24h warning / 48h contest /
   7d lockout. Shorter for an active prototype population, longer for a sprawling
   server? Recommend config knobs; default short-ish in dev.
3. **Capture threshold.** `control_threshold` default 0.6 (attacker must clearly
   win). Higher (defender-favored) or 0.5 (coin-flip on a draw)? Recommend ≥ 0.55
   so defenders aren't dispossessed on a tie.
4. **Simultaneous sieges per org.** Cap how many sieges one org can run/defend at
   once (prevents zerg orgs blanketing the map). Recommend a small per-org cap.
5. **Number of claimable nodes per zone at launch.** Affects how much there is to
   fight over. Recommend modest (a handful per lawless zone) and widen with data.
6. **City expansion-room siegeability.** Confirm §7.4: non-citizen-secured city
   expansion rooms are siegeable while the HQ core is immune. Recommend yes — it's
   the defensible-heart/contestable-frontier shape.

---

## Schemas referenced

- `data/schemas/territory_claim.schema.json` — one claimed node.
- `data/schemas/siege_state.schema.json` — one Drop-6D contest (the state machine).
- `data/schemas/security_zone.schema.json` — the security gradient sieges respect.
- `data/schemas/player_persistence.schema.json` — org membership + city role.

Storage: `docs/PERSISTENCE_DESIGN.md`. Director/security backbone:
`docs/WORLD_SIM_DESIGN.md`.
