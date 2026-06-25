# World Simulator Backbone — Director AI, Security Zones, Ambient Life

Status: DESIGN (docs + data schemas only — no gameplay code). Owner priority #3
(player-driven & persistent world), built on the M1 server-authoritative
foundation. Author: world-sim-designer.

This document specifies the **persistent, player-driven world-simulator
backbone**: the Director AI as a restart-surviving server simulation, the
security-zone gradient it shifts, and the ambient NPC life it drives. Territory
control, player cities, and the org-vs-org siege loop are the headline PvP layer
and have their own doc: `docs/FACTION_TERRITORY_DESIGN.md`. What persists and how
it is stored is `docs/PERSISTENCE_DESIGN.md`.

It adapts the MUSH's **staff/Claude-driven** Director (codename "Parsec";
`C:\SW_MUSH\docs\design\Guide_26_Director_AI.md`, `director_ai_design_v1.md`,
`ambient_npc_life_design_v1.md`, `security_zones_design_v1.md`) into an
**automated, server-authoritative SERVER simulation** that fits this project's
model: the server owns `WorldState` truth, resolves combat in ~5 s WEG action
windows, ticks movement at 20 Hz, and broadcasts snapshots; clients send intents
(`docs/MULTIPLAYER_FOUNDATION.md`, `scripts/net/world_state.gd`).

## 0. Design principles (carried from canon, recast for a server sim)

1. **The sim sets the stage; players perform on it.** The Director never narrates
   a player's actions, never forces a scene. It changes *conditions* — influence,
   alert level, security, events, ambience — and players choose how to engage.
   (Guide_26 §1; `director_ai_design_v1` §1.)
2. **Causality over randomness.** A crackdown that fires *because players spent
   hours fighting Republic patrols* is storytelling; one that fires on a dice roll
   is wallpaper. Player actions feed influence; influence drives the world.
3. **Server owns all truth and RNG.** Same invariant as combat: the dedicated
   server owns the sim state and every seed/timer; clients only observe outputs
   (news, alert tags, ambient text, security badges) and submit intents that the
   server validates. No client ever computes influence, security, or event firing.
4. **Deterministic core, optional LLM spice.** Every gameplay-affecting decision
   (influence math, alert thresholds, security overlay, event selection, NPC
   movement) is **pure deterministic Python/GDScript on the tick**. The LLM
   (Anthropic Claude) is an *optional* flavor layer (dynamic ambient lines, RP
   evaluation) that **degrades gracefully to fully-authored content when absent**.
   The world never stalls on an API.
5. **Slow tick, separate from movement.** The world sim runs on a **slow tick**
   (seconds-to-minutes), wholly distinct from the 20 Hz movement tick. See §4.
6. **Restart-survival is mandatory.** All sim truth persists (per
   `docs/PERSISTENCE_DESIGN.md`); a server restart resumes the same galaxy.

---

## 1. System map (what the backbone is)

| System | Purpose | Authoritative state | Schema |
|---|---|---|---|
| **Director — faction influence** | Track per-zone faction power; the substrate everything derives from | per-zone influence scores (0–100, not zero-sum) | `data/schemas/faction_zone_state.schema.json` |
| **Director — alert levels** | Derive a player-visible zone posture from influence | derived field on faction-zone state | same |
| **Director — world events** | Fire bounded, opportunity-creating events from influence + timers | active-event list per zone + world-event instances | same + world-events store (Persistence doc) |
| **Director — ambient life & text** | Make rooms feel alive; observable NPC churn + atmospheric lines | ambient pools per zone; NPC ambient state | same + `npc_ambient_state` (Persistence doc) |
| **Security zones** | The safe-zone ↔ consensual-PvP gradient, shifted by influence/events | base tier per zone + transient overlay | `data/schemas/security_zone.schema.json` |
| **Director — RP evaluator** *(optional)* | Reward narrative-rich play with CP trickle | append-only CP-grant log | Persistence doc |

Territory/cities/sieges (`FACTION_TERRITORY_DESIGN.md`) sit *beside* this and
read from it (a siege reads zone security; influence bridges to org axes), but use
a **separate** influence table — exactly as the MUSH keeps `zone_influence`
(Director) distinct from `territory_influence` (orgs). Conflating them is a known
trap (Guide_11 §2 "Important").

---

## 2. The Director AI as a persistent server simulation

### 2.1 Authoritative state owned

One `faction_zone_state` record per ground zone (and per relevant space zone),
schema `data/schemas/faction_zone_state.schema.json`. It owns:

- **`influence`** — `{republic, cis, hutt, independent}`, each 0–100, **not
  zero-sum**. The Clone Wars recast of the MUSH axes: Republic = legitimate
  authority (the MUSH's "Imperial" mechanical slot), CIS = the insurgent slot,
  Hutt = criminal underworld, Independent = non-aligned. Both eras drive the same
  engine; only labels differ (Guide_26 §2). **No old-era labels** appear anywhere.
- **`alert_level`** — derived (§2.3), one of six.
- **`security_base` / `security_overlay`** — base from the security-zone registry;
  overlay derived each recompute (§3).
- **`active_events`** — events currently shaping the zone (§2.4).
- **`ambient`** — static pool key + optional dynamic pool (§2.6).
- **`tick`, `last_recompute_unix`** — provenance for decay and admin display.

### 2.2 Influence change drivers (how players affect it)

Influence moves from four sources (Guide_26 §2/§4; `director_ai_design_v1` §3.2):

| Driver | Effect (starting values — owner-tunable) |
|---|---|
| **Player actions in zone** | Faction-mission complete: that faction +2. Kill enemy-faction NPC: their faction −3, opposing +1. Smuggling delivery: Hutt +2, Republic −1. Sell contraband: Hutt +1. PvP win in lawless/contested: winner's side shifts. |
| **NPC activity** | Faction-aligned NPC presence reinforces that faction; absence allows decay. |
| **Player presence** | Each hour as a faction member in a zone: small presence influence to that faction. |
| **Org treasury investment** | `faction invest` converts treasury credits to influence (territory-side; bridged to the Director axis for narrative). |
| **World events** | An active event nudges its zone's influence (a crackdown raises Republic; a pirate surge raises Hutt). |
| **Decay** | Influence trends toward a per-zone baseline when nothing reinforces it (prevents permanent lock-in). |

Deltas are **small by design**: one player cannot flip a zone in a session, but a
week of coordinated play by a handful of players produces a visible shift. To
survive a crash *between a player action and the next recompute*, deltas are
written first to the acting character's `world_hooks.pending_zone_influence`
(`player_persistence.schema.json`) and folded into the zone record at the next
recompute, then cleared. This is the player→world feedback loop made durable.

### 2.3 Alert levels (derived, no LLM, every recompute)

Derived locally from `influence` by threshold — pure, cheap, no API
(Guide_26 §2; `director_ai_design_v1` §3.3). Clone Wars recast:

| Alert level | Trigger (Republic = authority axis) | Player-facing effect |
|---|---|---|
| **Lockdown** | Republic ≥ 70 | Clone patrols everywhere; higher docking fees; smuggling pay +risk premium; extra patrol spawns |
| **High Alert** | Republic 50–69 | Normal patrols, occasional checkpoints |
| **Standard** | Republic 30–49 (default) | Normal operations |
| **Lax** | Republic < 30 | Reduced patrols; lower fees; criminal NPC density up |
| **Underworld** | Hutt ≥ 70 | Black-market access; Hutt job board; bounties on troublemakers |
| **Unrest** | CIS ≥ 40 | CIS-sympathizer activity; propaganda ambient text |

Alert level feeds NPC spawn weights, encounter frequency, economy multipliers, and
the news. Players see the **tag**, never the numbers (Guide_26 §2).

### 2.4 World events (bounded menu, the Director SELECTS not INVENTS)

Twelve fixed event types (Guide_26 §3; `director_ai_design_v1` §5.1), Clone Wars
recast. The Director **picks a type and affected zones from this fixed menu**; the
engine knows how to run each. The Director never invents mechanics — the
bounded-context principle that keeps an automated (and optionally LLM-assisted)
director safe.

| Type (enum) | Effect | Default duration |
|---|---|---|
| `republic_crackdown` | Patrols up; smuggling pay +50%; patrol aggro radius doubled; security overlay upgrades contested→secured | 30–60 min |
| `republic_checkpoint` | Contraband scans at a port | 15–30 min |
| `bounty_surge` | Bounty board pays ×2 | 30 min |
| `merchant_arrival` | Temp vendor; rare/discounted goods | 20 min |
| `sandstorm` | Outdoor Perception −1D; hazards up | 10–20 min |
| `cantina_brawl` | Brawler NPCs; perform/sabacc payouts up | ~5 min |
| `distress_signal` | Rescue opportunity in space | 15 min |
| `pirate_surge` | 3× pirate spawn in deep space | 60–120 min |
| `hutt_auction` | Rare items, Hutt-rep gated | 30 min |
| `krayt_sighting` | High-tier wildlife (group content) | 45 min |
| `cis_propaganda` | CIS ambient lines; +CIS influence/tick in zone | 30 min |
| `trade_boom` | Vendor sell prices +25% in zone | 60 min |

**Lifecycle:** trigger (from influence + timer roll, or the optional LLM pick) →
activate (announce via news; sometimes a comlink line) → apply effects → run for
duration → expire (announce; reset effects) → log to the news/director log.

**Constraints** (prevent chaos; `director_ai_design_v1` §5.3, owner-tunable):
≤2 concurrent Director-spawned events globally; ≥15 min between Director events;
same type cannot repeat within 2 h; **events create opportunities, never block
progress** (fines, not jail; pressure, not coercion — Guide_26 §3).

**Events are opportunities, not obligations.** A pirate surge doesn't force
combat; it makes pirate encounters likelier *if* you transit deep space. The sim
pressures choices without removing agency.

### 2.5 Era progression milestones (server-wide story turns)

The Director tracks **average influence across all zones** and fires **one-time**
milestone events at thresholds (Guide_26 §4), Clone Wars recast — e.g. *Republic
Grip* (Republic avg ≥ 70 → "The Republic tightens its hold on Mos Eisley"),
*Martial Law* (≥ 85 → a server-wide crackdown for hours), *Underworld Rising*
(Hutt avg ≥ 70), *Hutt Takeover* (≥ 85), *Separatist Whispers* (CIS avg ≥ 35),
*Separatist Uprising* (CIS avg ≥ 50), *Republic Retreat* (Republic avg < 30).
These are server-state events that move the metagame — they fire once and stay
narratively significant. Persisted as a small `world_milestones` log
(Persistence doc) so they don't re-fire across restarts.

### 2.6 Ambient NPC life & atmospheric text (the world breathes)

Adapts `ambient_npc_life_design_v1` and Guide_26 §5. Three layers, **deterministic
sim decides, optional LLM only decorates**:

- **Layer 1 — State (DB):** per-NPC ambient state (`npc_ambient_state`,
  Persistence doc): current goal, room, destination, move timers, relationships.
  Opt-in via an NPC config flag; absent ⇒ NPC is unchanged (live-safety default).
- **Layer 2 — Sim (pure, on the slow tick):** goal selection (`work`,
  `socialize`, `patrol`, `rest`, `trade`) on a day/night schedule; ground
  movement between connected rooms (mirrors the existing space-traffic timer
  model); NPC↔NPC interaction when co-located goals are compatible. **NPCs are
  scenery to the sim** — it never targets a specific player (v1 safety boundary).
  Departure/arrival/activity lines are templated strings, not LLM.
- **Layer 3 — Flavor (optional LLM, lowest priority):** when enabled, generates a
  *line* for an interaction the sim already decided. Fully preemptible; if absent,
  NPCs still move and act silently. **Layer 2 decides; Layer 3 only decorates.**

**Atmospheric text** fires in occupied rooms every 2–5 min. Two pools: a **static**
authored pool (always present; the floor) and an **optional dynamic** pool the
Director refreshes each cycle from current zone state. When the dynamic pool is
non-empty, draw 70% static / 30% dynamic; empty ⇒ 100% static. Dynamic lines are
validated (≤120 chars, no player names/commands/anachronisms/old-era framing)
before entering the pool; failures are silently dropped. Stored transiently in the
zone's `ambient.dynamic_pool` (`faction_zone_state` schema).

---

## 3. Security zones — the safe-zone ↔ consensual-PvP gradient

Adapts `security_zones_design_v1` (EVE-style high/low/null), Clone Wars recast
(Republic authority, never Imperial). Schema:
`data/schemas/security_zone.schema.json`.

### 3.1 The three tiers

| Tier | PvE | PvP | Feel |
|---|---|---|---|
| **Secured** | NPCs don't initiate; `attack` blocked (except server-scripted encounters) | Blocked | Safe. Markets, cantina, civic core, spaceport. New players learn here un-ganked. |
| **Contested** | Full PvE; NPCs aggro | **Consent only** — `challenge`/`accept`, a standing PvP flag, an active bounty (the bounty *is* the consent for a guild hunter), or a territory contest | Back alleys, port fringes. Danger is real; griefing is blocked. |
| **Lawless** | Full PvE; aggressive AI | **Unrestricted** — `attack` works with no consent | Deep desert, undercity, spice mines. Highest risk/reward; org territory lives here. |

A **one-time-per-session lawless-entry warning** (acknowledged flag persisted on
the character) prevents new players wandering into danger. Space mirrors ground:
dock = secured, orbit/lane = contested, deep space = lawless; the `fire` gate is
the same gate as ground `attack`.

### 3.2 Effective security (server-authoritative, single gate)

Every combat initiation — player `attack`, NPC aggro, space `fire`, a siege's
no-consent window — routes through **one** server function,
`get_effective_security(node, zone, character)`. Invariant: **no combat ever
skips it.** It resolves in order:

1. **Room faction override** (`faction_overrides` in the security-zone record): a
   Republic garrison interior is effectively lawless for a CIS/hostile-standing
   character even though its zone is secured.
2. **City citizen upgrade** (Guide_12; see `FACTION_TERRITORY_DESIGN`): inside a
   player city, a citizen's tier is upgraded one step (contested→secured,
   lawless→contested). The most-permissive last word for citizens — a hostile
   downgrade can never make a citizen less safe than their own city allows.
3. **Territory claim upgrade**: in a claimed lawless node, owning-org members are
   treated as contested (consent protection on home turf).
4. **Director overlay** (transient, from `faction_zone_state`): Hutt influence ≥ 80
   downgrades one tier (underworld surge — Republic patrols withdraw); an active
   `republic_crackdown` upgrades contested→secured. Overlay rules live in the
   security-zone record's `overlay_rules`.

The base tier (`security_base`) is **never overwritten** by the overlay — the sim
shifts the *effective* value only. The security map is therefore *alive*: weeks of
play that drive Republic influence down make a zone more dangerous; helping the
Republic lock an area down makes it safer.

### 3.3 PvP consent mechanics (contested zones)

Transient, in-memory, **not persisted** (intentional — no stale flag survives a
restart): `challenge <player>` → `accept`/`decline`; on accept both players are
mutually PvP-consented for ~10 min or until one leaves the zone. A bountied
player has reduced protection — a guild hunter with standing may engage in
contested zones without a challenge (the bounty is the consent). The **siege
no-consent window** (Drop 6D, `FACTION_TERRITORY_DESIGN`) is the one case where
contested-zone PvP is forced — but only between the two contesting orgs, only at
the contested node + adjacency, only for the contest window's duration.

---

## 4. Tick cadence — slow world sim vs. 20 Hz movement

Two clocks, deliberately decoupled:

| Clock | Rate | Owns | Where |
|---|---|---|---|
| **Movement tick** | **20 Hz** (existing) | Position integration, input application, snapshot broadcast | `scripts/net/world_state.gd::tick()` + `NetworkManager` |
| **World-sim slow tick** | **owner-configurable; default 30 s** for prototype, up to the MUSH's 30 min for production | Influence recompute, alert-level derivation, security-overlay derivation, event trigger/expiry, ambient pool refresh, NPC ambient sim step, decay, milestone checks | a sibling pure model + scheduler entry (engineer-built) |

The slow tick **must not** run on the 20 Hz path. It is a separate scheduler entry
with its own interval and offset (mirrors the MUSH's tick-scheduler registry:
`director_tick`, `world_events_tick`, `ambient_npc_life_tick`). Recommended
sub-cadences within the slow tick:

- **Every slow tick:** alert-level + security-overlay derivation (cheap, pure),
  event-expiry checks, pending-influence fold-in.
- **Every N slow ticks (the "Faction Turn", default ~30 min real-time):** full
  influence recompute, event-trigger decision, ambient dynamic-pool refresh,
  milestone check. The MUSH's 30-min Faction Turn gives "steady but slow change" —
  the world drifts over hours, not seconds.
- **Hourly:** presence influence.
- **Daily:** influence decay; territory resource yields (territory doc).

Per-tick work is **bounded** (process N NPCs/zones per tick, not all) so a large
world can't spike a tick. The slow tick is silent to players — they notice the
*results* (a news headline, a shifted alert tag, new ambient text), never the tick.

---

## 5. Optional LLM layer (Anthropic Claude) — grounded, bounded, graceful

Two optional Director features use an LLM, exactly as the MUSH specced — **off by
default**, behind a config flag, and **non-load-bearing**:

1. **Dynamic ambient text** — 3–5 atmospheric one-liners per Faction Turn,
   reflecting current zone state, validated before entering the pool (§2.6).
2. **RP evaluator** — reads recent scene poses and grants a small CP "trickle"
   (0–N ticks/eval) for narrative-rich play (Guide_26 §7). The CP-trickle
   *magnitude* interacts with the **CP-progression-pace owner decision** (§7) and
   must not be baked in.

**Model choice (current Anthropic facts, verified 2026-06):** this is a
**low-frequency, structured-JSON background** workload — a Faction-Turn digest in,
a small validated JSON object out, a few dozen calls/day. The cheapest current
model, **Claude Haiku 4.5** (`claude-haiku-4-5`, 200K context, $1/MTok input,
$5/MTok output), is the right fit and matches the MUSH's own pick. The static
system prompt is **prompt-cacheable** (a stable prefix → ~0.1× input cost on
cache hits), so a 24/7 Director runs in the low single-dollars/month range.
Request structured output and validate every field against known enums/ranges;
clamp deltas; reject and no-op on parse/validation failure. Use the official
Anthropic SDK; default model `claude-opus-4-8` for anything that genuinely needs
top-tier reasoning, but the Director's bounded JSON task does not — Haiku 4.5 is
the deliberate, cost-disciplined choice here.

**Hard guarantees (so the LLM never owns the world):**
- The slow **sim tick never blocks on an API call.** The LLM is invoked off the
  critical path; if a call is in flight at tick time, skip until next cycle.
- A **budget circuit breaker**: at a monthly spend threshold, all LLM calls no-op
  and the Director falls back to deterministic timer events + the static ambient
  pool. The world keeps running; only the spice goes quiet.
- The LLM **selects from fixed menus and adjusts bounded numbers** — it never
  invents event types or mechanics, never narrates a player's actions, never
  touches combat/dice/sheets (Guide_26 §8.3).

This keeps faithful to the canon's intent (a Claude-assisted director) while
honoring this project's "WEG R&E leads mechanics, server owns truth" invariants.

---

## 6. How it plugs into the existing server-authoritative model

- **Truth lives server-side, pure and testable.** Like `world_state.gd`, the
  world-sim models are pure (RefCounted / headlessly unit-testable): they take
  state in, produce state out, own no sockets. The engineers wire them to the
  scheduler and persistence. This doc + the schemas are the contract.
- **Clients observe, never compute.** Snapshots gain (incrementally) a per-zone
  posture summary: `alert_level`, `effective_security`, active-event headlines,
  ambient lines. Clients render an alert tag, a security badge, a news feed — they
  never derive any of it. New player intents are limited to existing verbs
  (`attack`, `challenge`/`accept`, faction/territory commands) that the server
  validates against effective security and sim state.
- **Combat ties in cleanly.** Action-window outcomes feed influence (kills) and
  siege score (PvP in a contest window). The server already owns the seed and the
  envelope; the sim consumes the resolved result, never the raw input.

---

## 7. OPEN OWNER DECISIONS (flagged — NOT decided here)

These are deferred owner calls. Each is represented in the schemas as a **data
hook** with no policy baked in. Present options + a recommendation; do not settle.

1. **Force / Jedi scarcity & access.** `player_persistence.sheet.force_sensitive`
   is a flag only. *Options:* (a) extreme scarcity — Force access by rare,
   gated unlock (most lore-faithful for 20 BBY, where Jedi are few and the public
   barely sees the Force); (b) a CP-gated path open to any character who invests
   heavily; (c) species/background-gated. *Recommendation:* lean (a) with a narrow
   (b) on-ramp, so the galaxy stays mostly mundane and Jedi feel special — but
   this is the owner's call. The world sim treats Force-users as ordinary actors
   for influence/security purposes regardless of the choice.
2. **Death / loot penalty model.** `sheet.wound_state` reaches `incapacitated` /
   `dead`; what *happens* there is undecided. *Options:* (a) soft — respawn at a
   safe node, no loot loss, short debuff (newbie-friendly); (b) graded by security
   tier — secured/contested soft, **lawless** harsh (no guaranteed body recovery,
   loot-drop risk), which `security_zones_design_v1` gestures at and which makes
   lawless risk meaningful; (c) full-loot lawless (hardcore). *Recommendation:*
   (b) — ties the penalty to the consent gradient the player opted into. Owner
   decides the exact lawless severity. The siege loop assumes *some* lawless
   stakes but does not require a specific model.
3. **CP progression pace.** `sheet.character_points` stores the value; no earn
   rate is baked. This couples to the optional RP-evaluator trickle (§5) and the
   lawless CP-bonus flag (`security_zone.lawless_incentives.cp_rate_bonus_flag`).
   *Options:* slow/medium/fast weekly caps. *Recommendation:* start medium with a
   weekly cap and a small lawless/RP bonus, then tune from telemetry. Owner sets
   the numbers; the sim only provides the on/off hooks.

Any divergence these decisions create from WEG or the MUSH gets a
`docs/DIVERGENCE_LEDGER.md` row before it is treated as settled.

---

## 8. Open questions for the owner

1. **Slow-tick cadence for launch.** 30 s (responsive, prototype-friendly) vs. the
   MUSH's 30-min Faction Turn (production-realistic, cheaper)? Recommend a
   config knob defaulting to ~60 s in dev, ~15–30 min in production.
2. **LLM Director on at launch?** It's optional and costs real dollars. Recommend
   shipping deterministic-only first (events on timers + influence, static
   ambient), then enabling Haiku 4.5 dynamic ambient + RP evaluator behind the
   budget breaker once the deterministic core is proven.
3. **Influence visibility.** Canon hides raw numbers from players (alert tag only).
   Keep hidden, or expose a coarse per-faction bar for the metagame? Recommend
   hidden numbers, visible alert tag + news, matching the MUSH.
4. **Number of live zones at launch.** The sim cost scales with zones × NPCs.
   Recommend starting with the 7 Mos Eisley zones + a couple of lawless frontier
   zones, widening with telemetry.
5. **Cross-zone ambient NPC travel.** v1 recommendation is intra-zone only
   (simpler, safer, still feels alive); confirm before scoping cross-zone routes.
6. **Decay baseline per zone.** What "resting" influence does each zone trend
   toward with no activity? Recommend a per-zone authored baseline (e.g. Mos
   Eisley spaceport rests Republic-leaning, the undercity rests Hutt-leaning).

---

## Schemas referenced

- `data/schemas/faction_zone_state.schema.json` — Director per-zone truth.
- `data/schemas/security_zone.schema.json` — security base + overlay rules.
- (`data/schemas/territory_claim.schema.json`, `siege_state.schema.json`,
  `player_persistence.schema.json` — used by the sibling docs.)

Storage of all of the above: `docs/PERSISTENCE_DESIGN.md`.
Territory, cities, and the siege state machine: `docs/FACTION_TERRITORY_DESIGN.md`.
