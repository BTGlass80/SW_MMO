# Territory Siege / Hostile-Takeover â€” Deliberate-Tempo State Machine (Drop 6D+)

Status: DESIGN (docs + data schema only â€” no gameplay code). Author:
world-sim-designer. Companion to `docs/FACTION_TERRITORY_DESIGN.md` (claims /
cities / the original single-window siege sketch), `docs/WORLD_SIM_DESIGN.md`
(Director / security gate), and `docs/PERSISTENCE_DESIGN.md` (storage). Schema:
`data/schemas/siege_state.schema.json`.

This document is the **authoritative, finalized** siege state-machine design. It
**supersedes and refines** the single-window siege sketch in
`FACTION_TERRITORY_DESIGN.md` Â§6 (which resolved by an `attacker_fraction`
point split across one continuous `active` window). The owner approved building
the siege at **DELIBERATE TEMPO**: a multi-phase machine spanning real-time
hours, with an explicit defender warning/mustering window, several discrete
scheduled assault windows, a **control meter** with a **high** capture threshold,
a per-org concurrency cap, and a post-siege node cooldown. Sieges are **rare,
planned, telegraphed** events â€” not drive-by ganks.

Era: 20 BBY Clone Wars. Factions: Republic, Separatist Alliance (CIS), Hutt
Cartel, Bounty Hunters' Guild, Independent (`org_model.gd::FACTION_AXES`). No
old-era (Imperial/Rebel/Alliance) framing anywhere.

---

## 1. Overview & how it sits on the existing substrate

A **siege** is the only mechanism by which one org (**attacker**) can take a
claimed territory node away from another org (**defender**) without their consent.
It reuses, and depends on, systems that already exist as pure server-authoritative
models:

| Substrate it plugs into | What the siege reads / writes | Where |
|---|---|---|
| **Territory claims** | The contested target is one `territory_claim`; on capture the claim's `org_id` transfers and the guard/income re-evaluate | `scripts/net/territory_model.gd`, `data/schemas/territory_claim.schema.json` |
| **Org membership & rank** | Only sufficient rank may declare / withdraw / negotiate / commit an ally | `scripts/net/org_model.gd` (rank gates) |
| **Org treasury** | A declaration escrows a war-chest; claim maintenance still charges during a siege (opportunity cost) | `territory_model.gd::org_credits` |
| **Territory influence (per org, per zone)** | The attacker must have *earned* a strong foothold in the zone to declare | `territory_model.gd::influence_tier` (floors 20 / 40 / 70) |
| **Director / security zone** | The target must be in a `contested` or `lawless` **base** tier; a secured zone (or a citizen-secured city core) can never be sieged | `scripts/net/zone_state.gd`, `data/schemas/security_zone.schema.json` |
| **Effective-security gate** | During an *active assault window only*, the two orgs' members are force-flagged for no-consent PvP at the contested node; the single combat gate honors this | `scripts/net/security_gate.gd` (WORLD_SIM_DESIGN Â§3.2) |
| **Director slow tick** | Phase advancement, control bleed, and hold-scoring run on the existing slow tick (~30 s dev), never the 20 Hz path | `zone_state.gd::director_tick` cadence |
| **Persistence** | The siege row survives a server restart exactly like territory state in `world_state.dat` | `docs/PERSISTENCE_DESIGN.md` Â§D |

**Two influence systems, kept separate (unchanged).** The siege gate uses
*org/territory* influence (`territory_model.gd`), **not** the Director's
*faction/zone* influence (`zone_state.gd`). They are different tables with
different purposes; do not conflate (Guide_11 Â§2 "Important").

> **Scale reconciliation (flag for the implementer).**
> `FACTION_TERRITORY_DESIGN.md` describes org influence on a 0â€“150 scale with
> "Foothold = 50". The **live code** (`territory_model.gd`) uses 0â€“100-ish tiers:
> claim floor **20**, **Dominant â‰¥ 40**, **Control â‰¥ 70**. This design anchors to
> the **live code**: the siege declaration gate defaults to **â‰¥ 40 (Dominant)** â€”
> stricter than the claim floor, because declaring war should require more than a
> toehold. The old siege stub defaulted `attacker_min_influence = 50`; that value
> came from the 0â€“150 doc scale and is **superseded** here. Reconcile the two
> scales (or pick one) at implementation time.

---

## 2. Actors, authority & declaration preconditions (server-validated)

To enter `declared`, **all** of the following must hold. Everything that could be
retuned by an admin is **snapshotted into `config`** at declaration so a live
siege is immune to a mid-flight retune.

1. **Target is a live claim** (`territory_claim`) or a **non-citizen-secured city
   expansion node** (city HQ cores are citizen-secured â†’ never siegeable; the
   citadel rule, `FACTION_TERRITORY_DESIGN` Â§7.3).
2. **Base security is `contested` or `lawless`** (`zone_state` base tier). Secured
   zones and citizen-secured rooms are immune.
3. **No active siege on the node and the node is not in cooldown** (one contest per
   node; `MAX_ACTIVE_SIEGES_PER_NODE = 1`).
4. **Attacker org influence in the zone â‰¥ `attacker_min_influence`** (default 40 /
   Dominant tier).
5. **Declaring character is attacker-org rank â‰¥ `rank_to_declare`** (default 4 â€”
   leadership; above the rank-3 claim gate, below the rank-5 city gate).
6. **Attacker treasury holds â‰¥ `declare_cost_credits`** (default 10 000). On a
   valid declaration the war-chest is **escrowed** out of the treasury into
   `war_chest_credits` on the siege record.
7. **Attacker is under its concurrency cap** â€”
   `MAX_CONCURRENT_ATTACKS_PER_ORG = 1` outgoing siege at a time (defenses are
   unbounded; you do not consent to being attacked).

Rank also gates the mid-siege actions:

| Action | Who | Rank gate | Effect |
|---|---|---|---|
| **Declare** | attacker | `rank_to_declare` (4) | opens `declared`, escrows war-chest |
| **Withdraw** | attacker | `rank_to_declare` (4) | â†’ `aborted` (pre-assault) or concede â†’ `resolution`/repelled (during) |
| **Concede / surrender node** | defender | `rank_to_negotiate` (4) | â†’ `resolution` â†’ captured (defender yields to avoid the fight) |
| **Negotiate settlement** | either | `rank_to_negotiate` (4) | data hook only â€” tribute/ceasefire is an RP/economy detail, not specified here |
| **Commit as ally** | intervening org | `ally_rank_to_commit` (4) | joins a side during `mustering` (Â§6) |

Clients never advance a phase or edit score; they issue **intents** the server
validates. The server owns all timers, all RNG (there is none required for
resolution â€” see Â§4), and all state transitions.

---

## 3. The phase state machine

Suggested spine, realized: **`declared â†’ mustering â†’ assault(1..N) â†’ resolution â†’
cooldown`**, with an inter-assault **`lull`** and three terminal archive states
(`captured` / `repelled` / `aborted`). "assault(1..N)" is the single `assault`
state **entered N times** (default N = `assault_count` = 3), tracked by
`schedule.current_assault_index`.

### 3.1 State diagram

```
      submit_siege_declare (all Â§2 preconditions pass; war-chest escrowed)
 (none) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶  DECLARED
                                                             â”‚  grace elapses (declaration_grace_hours, 1h)
   attacker withdraws OR influence < gate                    â”‚  still valid â†’ schedule N assault windows
   during DECLARED  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶  ABORTED (full refund)    â–¼
                                                          MUSTERING  â—€â”€â”€ allies may commit here only (Â§6)
                                                             â”‚  warning/prep window (mustering_hours, 24h)
   attacker withdraws (war-chest forfeit)                    â”‚  no forced PvP yet; defender rallies
   OR influence < gate  â”€â”€â”€â”€â”€â”€â”€â”€â–¶  ABORTED (no refund)       â”‚
                                                             â–¼  scheduled assault #1 start reached
                        â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶  ASSAULT (index i)  â”€â”€ pvp_consent ACTIVE at scope
                        â”‚                                    â”‚  window = assault_window_hours (2h)
                        â”‚  next assault start reached         â”‚  control meter accrues (Â§4/Â§5)
                        â”‚                                    â”‚
                        â”‚        assault window ENDS,        â”‚  early capture: control â‰¥ capture_threshold
                     LULL â—€â”€â”€â”€â”€ more assaults remain â”€â”€â”€â”€â”€â”€â”€â”€â”¤  held for capture_hold_seconds (15m) â†’ RESOLUTION
       (lull_hours, 6h; pvp OFF;   â”‚                          â”‚
        control bleeds toward 0)   â”‚  final assault ENDS  â”€â”€â”€â”€â”¤  OR defender concedes â†’ RESOLUTION
                        â”‚           â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶  RESOLUTION
   attacker concedes/withdraws â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â–¶ (single-tick tally)
                                                                                     â”‚
                                              control â‰¥ capture_threshold (75)?      â”‚
                                                   â”‚ yes                    â”‚ no
                                                   â–¼                        â–¼
                                            outcome=captured          outcome=repelled
                                       (claim â†’ attacker; guard        (defender keeps
                                        dismissed; income reband)       the claim)
                                                   â”‚                        â”‚
                                                   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                                              â–¼
                                                          COOLDOWN  (node locked; cooldown_hours, 168h/7d)
                                                              â”‚  deadline elapses â†’ archive
                                                              â–¼
                                               CAPTURED  /  REPELLED   (terminal archive; node released)
```

### 3.2 State table (dwell, entry/exit, who triggers)

| State | Meaning | Dwell (default) | Entry action | Exit trigger(s) | pvp_consent |
|---|---|---|---|---|---|
| `declared` | War declared; **cheap-withdraw grace**; defender formally notified (news + comlink) | `declaration_grace_hours` = 1h | escrow war-chest; snapshot `config`; back-pointer on claim | grace deadline â†’ `mustering`; attacker withdraw / influence < gate â†’ `aborted` (full refund) | off |
| `mustering` | **Warning / preparation** window. Defender rallies; both sides stage; **allies may commit** (Â§6). No forced PvP | `mustering_hours` = 24h | schedule `assault_count` assault windows at fixed offsets; announce schedule to both orgs | first assault `start_unix` â†’ `assault`; attacker withdraw / influence < gate â†’ `aborted` (war-chest forfeit) | off |
| `assault` | **Assault window** i of N. Forced rival-org no-consent PvP at scope nodes; control meter accrues | `assault_window_hours` = 2h | activate `pvp_consent` for the two orgs at `scope_node_ids` | window end + more remain â†’ `lull`; window end + last â†’ `resolution`; early capture â†’ `resolution`; defender concede â†’ `resolution` | **on** |
| `lull` | **Inter-assault regroup**. PvP off; control **bleeds** toward the defender (0) | `lull_hours` = 6h | deactivate `pvp_consent`; advance `current_assault_index` | next assault `start_unix` â†’ `assault`; attacker concede/withdraw â†’ `resolution` (repelled path) | off |
| `resolution` | **Single-tick tally.** Read control meter; decide capture vs repel; apply effects | 1 tick | read `control_meter.value`; write `outcome.result` | always â†’ `cooldown` | off |
| `cooldown` | **Node lockout.** Outcome recorded; node cannot be re-contested | `cooldown_hours` = 168h (7d) | apply capture/repel effects; set `outcome.lockout_until_unix`; emit news headline | deadline â†’ archive as `captured`/`repelled` | off |
| `captured` | Terminal archive â€” attacker took the node | â€” | â€” | â€” | off |
| `repelled` | Terminal archive â€” defender held | â€” | â€” | â€” | off |
| `aborted` | Terminal â€” declaration cancelled before/at withdrawal; node gets a short `abort_cooldown_hours` (24h) lockout | â€” | (no capture) refund per phase | â€” | off |

**All timed transitions are driven by the slow tick** comparing
`phase_deadline_unix` (and each scheduled `assault_window.start_unix`) to
wall-clock. **No client advances a phase.** On each slow tick the server
re-derives every transient flag (notably `pvp_consent.active`) from `state` and
trusts no client report.

### 3.3 Assault scheduling (why it feels "planned")

At the `declared â†’ mustering` transition the server computes a fixed schedule of
`assault_count` windows so **both orgs know exactly when the fights are** â€” the
core of "deliberate, planned, telegraphed". Default schedule (offsets measured
from mustering end = first assault start):

```
assault #1 start = mustering_end
assault #1 end   = start + assault_window_hours
lull             = lull_hours
assault #2 start = assault #1 end + lull_hours
... (repeat for assault_count windows)
```

With defaults (1h grace, 24h mustering, 3Ã— 2h assaults, 6h lulls) a full siege
spans **â‰ˆ 43 h wall-clock** from declaration to resolution, of which **only 6 h is
forced-PvP contest** (3 Ã— 2 h), all at pre-announced times, followed by a **7-day
node cooldown**. That is the deliberate-tempo shape: rare, telegraphed, plannable
across time zones, expensive to run. *(All offsets are `config` values; a smaller
prototype population can compress mustering/lull dramatically â€” see Â§8.)*

> **OPEN OWNER DECISION (tunable): assault start-time authorship.** Default =
> **auto-scheduled** at fixed offsets (above). Option = let the declaring
> attacker *propose* the assault start times within bounds (e.g. within the next
> 72 h, â‰¥ `lull_hours` apart) so both orgs pick a mutually-live slot. Recommend
> auto-schedule for v1 (simplest, deterministic); expose proposed slots later.

---

## 4. Capture / victory math (deterministic, server-authoritative)

The contest is decided by a single scalar **control meter**, `control_meter.value`,
an integer in **`[control_min, control_max]` = [0, 100]**, server-owned. **There is
no RNG in siege resolution** â€” control moves only from *already-resolved* combat
outcomes and deterministic presence counts, so a siege is fully reproducible and
headlessly testable.

### 4.1 The control meter

- **Starts at `control_start` = 0** (the defender fully holds their node).
- **During an `assault` window**, resolved scoring events (Â§5) add/subtract from
  `value`, **clamped to [0, 100]** on every application. Attacker events push it
  **up**; defender events push it **down**.
- **Outside assault windows** (`mustering`, `lull`, `cooldown`) `value` **bleeds
  toward the defender rest point (0)** at `control_bleed_per_hour` = 10/hour,
  clamped at 0. A lead is **perishable**: the attacker cannot bank a big first
  assault and coast through the lulls; they must press every scheduled window.
  Bleed is applied on the slow tick as `value -= bleed_per_hour * hours_elapsed`.

### 4.2 The two capture conditions (HIGH threshold)

The attacker captures the node if **either** holds:

1. **Early capture (hold-for-duration).** During any `assault` window, `value`
   stays **â‰¥ `capture_threshold`** (default **75**) **continuously for
   `capture_hold_seconds`** (default 900 s = 15 min). Continuity is tracked by
   `control_meter.hold_since_unix`: set when `value` first reaches the threshold,
   cleared the instant `value` drops below it; when `now - hold_since_unix â‰¥
   capture_hold_seconds` the siege short-circuits to `resolution` with a capture.
2. **Final tally.** If no early capture fires, at `resolution` (immediately after
   the **final** assault window ends) the server reads `value`. **`value â‰¥
   capture_threshold` â‡’ captured; otherwise â‡’ repelled.**

A threshold of **75** (not 50) means the attacker must **clearly dominate**, not
merely draw â€” the defender holds on anything short of decisive control. This is
the "HIGH capture threshold / hard to flip a node" the owner asked for.

### 4.3 Provenance

`score.attacker_points` / `score.defender_points` remain as **cumulative audit
totals** (never clamped, never bled) that drive the "who fought" record and any
future CP reward (Â§13). The **`control_meter`** is the separate, clamped, bleeding
**victory state**. Each `score.contributions[]` row logs both its raw `points`
(audit) and its `control_delta` (what it did to the meter) for a full replayable
history and the post-siege news feed.

---

## 5. Scoring events â†’ control deltas

Every event is a **resolved server outcome**, never raw client input. Combat that
produces `pvp_kill` resolves through the existing action-window system; the siege
consumes the resolved envelope. All deltas are `config`-tunable (Â§8). During an
`assault` window only:

| `kind` | Side | `control_delta` (default) | Audit `points` | Notes |
|---|---|---|---|---|
| `pvp_kill` | killer's side | Â±`control_per_pvp_kill` = 8 | 6 | Attacker kill +8, defender kill âˆ’8. **Depends on PvP unlock â€” see Â§13.** |
| `guard_defeated` | attacker | +`control_per_guard_defeated` = 12 | 10 | Breaking the defender's stationed guard NPC (PvE â€” works today) |
| `control_hold_tick` | side with more living in-scope members this slow tick | Â±`control_per_hold_tick` = 2 | 2 | Holding ground over time; deterministic from server presence count |
| `objective` | either | Â±`control_per_objective` = 15 | 12 | Optional node objective (raise a banner, hold a console) |
| `sabotage` | attacker | +`control_per_sabotage` = 6 | 5 | Optional pre-/in-window disruption of node defenses |

**Control-hold tick** each slow tick during an assault: count living members of
each org present at any `scope_node_ids`; whichever side has strictly more gains
`control_per_hold_tick` toward its direction (attacker up, defender down); a tie
does nothing. This makes *showing up and holding the room* matter even with few
kills, and lets a siege still resolve entirely on PvE + presence while player-vs-
player PvP remains owner-gated (Â§13).

---

## 6. Third-party intervention

Deliberate-tempo default: **`intervention_mode` = `mustering_only`.** Other orgs
may join a side, but **only by committing during the `mustering` warning window** â€”
so the full set of combatants is **locked before the first assault** and no
surprise army swings a live fight. Rules:

- An intervening org commits to **attacker** or **defender** side via an
  `ally_rank_to_commit`-gated (default 4) leadership intent, during `mustering`
  only.
- **Cap `max_allies_per_side` = 1** intervening org per side (2 total). Keeps
  sieges legible and prevents a whole-server dogpile.
- An intervenor needs **`ally_min_influence` = 20** (claim-floor presence) in the
  zone â€” it must have some standing there, not teleport in from nowhere.
- On commit, the ally's members gain the same `pvp_consent` no-consent flag at
  `scope_node_ids` during assault windows and score for their side normally.
- Allies **cannot declare, withdraw, concede, or negotiate** â€” those remain the
  principals' rank-gated rights. An ally can **stop participating** (its members
  simply leave scope) but the commitment record persists for audit.
- On capture, the node transfers to the **attacker principal only** (allies gain
  reputation/relationship, not the claim â€” spoils-sharing is an economy/RP hook,
  not specified here).

**Tunable alternatives** (`config.intervention_mode`): `none` (strictly the two
principals â€” the conservative v1 fallback if the owner wants the simplest thing)
or `open` (allies may commit any time before the final assault â€” more chaotic,
higher-tempo; **not** recommended for deliberate tempo). Default stays
`mustering_only`.

> **OPEN OWNER DECISION (flagged).** Third-party intervention interacts with the
> owner-gated **PvP-consent** decision (DIV-0019, reserved): forced ally-vs-ally
> PvP is only meaningful once no-consent PvP exists. Until then, allies contribute
> only through PvE scoring (guard, hold ticks, objectives, sabotage). The default
> `mustering_only` + 1-per-side is a recommendation, not a settled owner call.

---

## 7. Anti-grief, concurrency & cooldown (guardrails)

- **Telegraph.** The 1 h grace + 24 h mustering guarantee the defender is warned
  and can rally long before any forced PvP; the assault schedule is announced.
- **Node cooldown.** `cooldown_hours` = 168 h (7 days) after any resolved siege
  before the same node can be contested again; an `aborted` siege still triggers a
  shorter `abort_cooldown_hours` = 24 h lockout (so you cannot spam
  declare/abort).
- **Per-org attack cap.** `max_concurrent_attacks_per_org` = 1 â€” an org runs at
  most one outgoing siege at a time. (Defenses are unbounded; being attacked is
  not consensual.)
- **Influence gate.** The attacker must have earned **Dominant** influence (â‰¥ 40)
  in the zone â€” no drive-by sieges.
- **Economic weight.** A 10 000 cr war-chest is escrowed and **forfeit** if the
  attacker presses past the grace window, and claim maintenance keeps charging
  during the siege â€” a besieger who over-extends can lose ground elsewhere.
- **Scoped, timed consent.** Forced PvP is limited to the two (or four, with
  allies) orgs, at the contested node + declared adjacency, only during an active
  assault window. Everything else keeps normal security-zone consent.
- **Citadel immunity.** Citizen-secured city cores can never be sieged
  (`FACTION_TERRITORY_DESIGN` Â§7.3); only contestable outer/expansion nodes can.

---

## 8. DEFAULTS â€” the tunable-constants table (deliberate tempo)

Every value below is a **named `config` field**, snapshotted at declaration, owner-
retunable. Numbers are concrete deliberate-tempo starting points, **not** flagged
owner rulings. The pure model (Â§12) should expose each as a named constant with
these defaults; a compressed "prototype" profile is given for small-population dev.

| Constant (`config` key) | Default (deliberate) | Prototype/dev profile | Meaning |
|---|---|---|---|
| **Phase timers** | | | |
| `declaration_grace_hours` | 1 | 0.05 (3 min) | `declared` dwell; cheap-withdraw + first notification |
| `mustering_hours` | 24 | 0.25 (15 min) | warning/prep window before assault #1 |
| `assault_count` | 3 | 2 | number of scheduled assault windows (the N in assault(1..N)) |
| `assault_window_hours` | 2 | 0.1 (6 min) | duration of each assault window |
| `lull_hours` | 6 | 0.1 (6 min) | inter-assault regroup between windows |
| `cooldown_hours` | 168 (7 d) | 0.5 (30 min) | node lockout after a resolved siege |
| `abort_cooldown_hours` | 24 | 0.1 | node lockout after an aborted declaration |
| **Capture math** | | | |
| `control_min` / `control_max` | 0 / 100 | same | control-meter bounds |
| `control_start` | 0 | same | meter start (defender holds) |
| `capture_threshold` | 75 | 75 | HIGH control needed to capture (early or final) |
| `capture_hold_seconds` | 900 (15 min) | 60 | continuous time â‰¥ threshold in an assault for early capture |
| `control_bleed_per_hour` | 10 | 60 | meter decay toward 0 outside assault windows |
| **Scoring deltas** | | | |
| `control_per_pvp_kill` | 8 | 8 | control swing per resolved PvP kill (killer's side) |
| `control_per_guard_defeated` | 12 | 12 | attacker gain for breaking the stationed guard |
| `control_per_hold_tick` | 2 | 2 | per-slow-tick swing to the side holding more of scope |
| `control_per_objective` | 15 | 15 | either side, on an optional node objective |
| `control_per_sabotage` | 6 | 6 | attacker, on an optional sabotage action |
| **Gates & authority** | | | |
| `attacker_min_influence` | 40 (Dominant) | 40 | attacker org influence-in-zone floor to declare |
| `rank_to_declare` | 4 | 4 | attacker rank to declare / withdraw |
| `rank_to_negotiate` | 4 | 4 | rank to concede / negotiate (either principal) |
| `declare_cost_credits` | 10000 | 10000 | war-chest escrowed from attacker treasury at declaration |
| `attacker_min_treasury` | 10000 | 10000 | attacker treasury must hold â‰¥ this to declare (= cost) |
| `withdraw_refund_fraction_grace` | 1.0 | 1.0 | war-chest refund if withdrawing during the grace window (0.0 after) |
| **Concurrency & intervention** | | | |
| `max_active_sieges_per_node` | 1 | 1 | one contest per node |
| `max_concurrent_attacks_per_org` | 1 | 1 | outgoing sieges an org may run at once |
| `intervention_mode` | `mustering_only` | `mustering_only` | `none` \| `mustering_only` \| `open` |
| `max_allies_per_side` | 1 | 1 | third-party orgs allowed per side |
| `ally_min_influence` | 20 | 20 | intervenor's influence-in-zone floor |
| `ally_rank_to_commit` | 4 | 4 | intervenor leadership rank to commit |

Cadence: all phase/bleed/hold work runs on the **existing Director slow tick**
(`zone_state.director_tick`, ~30 s dev), **never** the 20 Hz movement path. Timers
are wall-clock (`phase_deadline_unix`, `assault_window.start/end_unix`) so a slow
tick can be any interval without changing outcomes.

---

## 9. Persistence & restart survival

A siege **must survive a server restart** exactly like the territory state in
`world_state.dat` (`territory_model.to_dict/apply_persisted`,
`zone_state.to_dict/apply_persisted`). The full siege record persists per
`data/schemas/siege_state.schema.json` (SQLite `sieges` table in
`PERSISTENCE_DESIGN.md` Â§D, or the JSON blob in `world_state.dat` for the
prototype). What persists vs. what is re-derived:

| Field group | Persist? | On restart |
|---|---|---|
| `state`, `phase_started_unix`, `phase_deadline_unix` | **Yes** | resume; if a deadline passed during downtime, advance on the first slow tick |
| `config` (snapshot) | **Yes** | trusted as-is (immune to admin retune) |
| `schedule` (assault windows, `current_assault_index`) | **Yes** | resume; windows whose start passed during downtime are handled by the catch-up rule below |
| `control_meter` (value, hold_since_unix, peak) | **Yes** | resume; **re-apply bleed** for the elapsed downtime if the machine was outside an assault |
| `score` (points + `contributions[]`) | **Yes** | audit log, append-only |
| `war_chest_credits`, `intervenors[]` | **Yes** | resume |
| `pvp_consent` (active + scope) | **No â€” re-derived** | recomputed from `state` on the first slow tick (only true while `state == assault`); never trusted from disk |
| `outcome` | **Yes** once terminal | resume |

**Restart catch-up rule (deterministic).** On the first slow tick after boot, for
each non-terminal siege the server compares wall-clock to `phase_deadline_unix`
and the schedule, and **advances through as many phase boundaries as elapsed**
during downtime (declaredâ†’musteringâ†’assaultâ†’lullâ†’â€¦â†’resolution), applying bleed for
non-assault spans. Because resolution has no RNG, a siege that *should* have
resolved during downtime resolves identically on catch-up â€” matching
`PERSISTENCE_DESIGN.md` Â§"Siege resume specifically". Transient PvP/consent flags
are never restored, only re-derived.

The `territory_claim.siege` back-pointer (`{siege_id, state, attacker_org_id}`) is
maintained alongside for cheap "is this node under siege?" claim reads and is
rebuilt from the siege rows on restore (like `territory_model._node_claims`).

> **Follow-up for the implementer (I cannot edit that file here).**
> `data/schemas/territory_claim.schema.json`'s `siege.state` back-pointer enum is
> currently `["declared","active","lockout","resolving"]`. Update it to the new
> non-terminal set `["declared","mustering","assault","lull","resolution",
> "cooldown"]` when this design is implemented, so the back-pointer matches the new
> state machine.

---

## 10. Integration points (for the netcode / rules engineers)

- **Effective-security gate.** During `state == assault`, the combat-initiation
  path (`security_gate.get_effective_security` / its caller) must treat an
  attacker-vs-defender (or ally-vs-opposing) initiation at a `scope_node_ids`
  member as **permitted no-consent PvP**, regardless of the zone tier â€” the one
  documented exception to consent (WORLD_SIM_DESIGN Â§3.3). Outside that
  window/scope, normal consent applies. `security_gate.gd` currently notes "PvP
  consent is out of scope (owner-gated)"; the siege window is the first concrete
  consumer and lands **with** the PvP unlock (Â§13).
- **Director slow tick.** Add a siege-advancement step to the slow tick alongside
  `zone_state.director_tick` / `territory_model.accrue_income`: for each live
  siege, advance phases, apply bleed, run control-hold scoring, check early
  capture, and resolve. Bounded per tick like the rest of the slow sim.
- **Territory model.** On capture, call the claim-transfer path (set
  `territory_claim.org_id` â† attacker, dismiss guard, re-evaluate
  `influence_tier_at_claim` and income band for the new owner). On declare, debit
  `org_credits[attacker] -= declare_cost_credits` into `war_chest_credits`; on
  abort-with-refund credit it back.
- **News feed.** Every terminal outcome emits a Director news headline
  (WORLD_SIM_DESIGN Â§2.4 / `director_log`), the "did you see what happened"
  social currency.

---

## 11. Divergence note â€” DIV-0020 (add to the ledger BEFORE implementation)

This is a **new mechanic** (hostile territorial takeover with forced, scoped,
timed PvP). Per the standing rule, a `docs/DIVERGENCE_LEDGER.md` row **must be
added before implementation**. **I do not edit the ledger** (it is owned by
another live session / deconflicted). **Reserve DIV-0020 for siege** (DIV-0018 is
the highest committed; DIV-0019 is reserved for PvP). **The implementer must
verify the next-free number at implementation time** and adjust if 0020 is taken.

Proposed row for the implementer to paste (verify the ID first):

> `| DIV-0020 | Territory siege / hostile takeover | R&E has no org-vs-org
> territory-capture rule (GM-adjudicated large-scale conflict) | SW_MUSH Guide_11
> Â§7 specced a "contest state machine, 7-day timer, rival-org no-consent PvP,
> hostile takeover" but never delivered it ("Planned") | Deliberate-tempo
> multi-phase machine (declaredâ†’musteringâ†’assault(1..N)â†’resolutionâ†’cooldown) on a
> control meter [0-100], HIGH capture threshold (75) held for a duration; declare
> gated by rank 4 + Dominant (40) zone influence + a 10k war-chest; 24h warning +
> N scheduled 2h assault windows + 7d node cooldown; per-org cap of 1 outgoing
> siege; capped mustering-only third-party intervention; server owns all
> timers/scoring, no RNG in resolution; persists in world_state.dat and resumes on
> restart | Realize the MUSH's planned-but-undelivered Drop 6D as the headline
> org-vs-org PvP loop, at the owner's deliberate tempo | Design complete
> (docs/SIEGE_DESIGN.md + data/schemas/siege_state.schema.json); wiring gated on
> the PvP-consent decision (DIV-0019) for the pvp_kill scoring source |`

Because the siege's forced-PvP assault window depends on no-consent PvP existing
(owner-gated, DIV-0019 reserved), that dependency is noted in the row's Status.
The **state machine, scheduling, control meter, treasury, capture, and PvE
scoring (guard/hold/objective/sabotage) are all buildable and testable now**; only
the `pvp_kill` scoring source waits on the PvP unlock.

---

## 12. Implementation slices (ordered â€” for the main dev loop)

Design is complete; the following are the build steps. **Order matters.**

1. **`[PAR]` Pure `scripts/rules/siege_state_model.gd` + smoke.** A RefCounted,
   socket-free, RNG-free state machine (the gameplay truth), headlessly unit-
   testable, mirroring the shape of `territory_model.gd` / `zone_state.gd`. It
   owns: declaration validation (rank / influence / treasury / concurrency /
   node-cooldown), `config` snapshot + defaults, phase advancement given a
   wall-clock `now` (declaredâ†’musteringâ†’assaultâ†’lullâ†’resolutionâ†’cooldownâ†’archive,
   including the restart catch-up rule), assault-window scheduling, control-meter
   update from scoring events + bleed + control-hold ticks, the two capture
   conditions, ally-commit validation, `pvp_consent` derivation from `state`, and
   `to_dict()` / `apply_persisted()` for restart survival. A companion
   `scripts/tests/siege_smoke.gd` (seed all RNG if any is added; none needed for
   resolution) drives a full siege through every phase, an early capture, a
   repel, an abort-with-refund, a restart-catch-up resume, and a mustering-only
   ally commit â€” wired into `tools/check_project.ps1`. **Depends on nothing new;
   build first.** *(This is engineer work â€” the pure-model + test slice â€” not part
   of this design deliverable.)*

2. **`[HOT]` `network_manager` declare/join/status RPCs + Director-tick hook.**
   After the pure model is green: server-validated intents
   (`submit_siege_declare`, `submit_siege_withdraw`, `submit_siege_concede`,
   `submit_siege_join` for allies, `submit_siege_status` read), each re-validating
   rank/influence/treasury server-side and never trusting the client; a
   phase-advancement call from the slow Director tick; the effective-security gate
   consulting `pvp_consent` during assault windows; siege status surfaced in the
   zone/claim summaries; and persistence into `world_state.dat` (+ the SQLite
   `sieges` table when it lands). **Depends on slice 1.** *(This touches
   `network_manager.gd`, owned by another session â€” sequence it after slice 1 and
   coordinate; described here as the wiring contract, not implemented in this
   design task.)*

---

## 13. Open owner decisions & dependencies (flagged â€” NOT decided here)

1. **PvP-consent unlock (DIV-0019, reserved).** The forced no-consent assault
   window and `pvp_kill` scoring depend on player-vs-player PvP existing.
   `security_gate.gd` still treats PvP consent as owner-gated. **The siege machine
   is designed to resolve on PvE scoring alone in the interim** (guard defeat,
   control-hold ticks, objectives, sabotage), lighting up `pvp_kill` when PvP
   unlocks. Not decided here.
2. **Death / loot penalty in the assault window (DIV-0006, decided 2026-07-01).**
   The siege assumes *some* stakes for dying in a forced-PvP window; the graded
   model (secured/contested soft, lawless harsh) is already owner-decided and the
   siege inherits it â€” no separate ruling needed, but the assault-window death
   severity (contested vs lawless base) is worth a confirming owner glance.
3. **CP rewards for siege participation (CP-pace decision).** The schema logs
   participation (`score.contributions[]` with `char_id` + `points`) so a reward
   can be computed later; **no CP rate is baked in.** Couples to the CP-progression
   owner decision (WORLD_SIM_DESIGN Â§7.3).
4. **Assault start-time authorship** (Â§3.3): auto-schedule vs attacker-proposed.
   Recommend auto for v1.
5. **Intervention default** (Â§6): `mustering_only` + 1-per-side recommended;
   `none` is the conservative fallback.
6. **Deliberate vs prototype timer profile** (Â§8): the 24 h/7 d deliberate profile
   vs the compressed dev profile for a small population. Recommend shipping the
   compressed profile in dev, the deliberate profile in production, via the same
   `config` knobs.

Any divergence these decisions create from WEG/MUSH gets its own
`docs/DIVERGENCE_LEDGER.md` row first.

---

## Schemas referenced

- `data/schemas/siege_state.schema.json` â€” **the finalized siege record** (this
  design's data contract).
- `data/schemas/territory_claim.schema.json` â€” the contested target; `siege`
  back-pointer enum needs the Â§9 follow-up update.
- `data/schemas/security_zone.schema.json` â€” the base tier a siege respects.
- `data/schemas/faction_zone_state.schema.json` â€” Director zone posture (separate
  influence table; read-only to the siege).

Design context: `docs/FACTION_TERRITORY_DESIGN.md`, `docs/WORLD_SIM_DESIGN.md`,
`docs/PERSISTENCE_DESIGN.md`, `docs/MULTIPLAYER_FOUNDATION.md`.
