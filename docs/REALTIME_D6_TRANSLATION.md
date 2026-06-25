# Real-Time D6 Translation

The MMO should not freeze the shared world into literal tabletop turns. The working direction is:

**Real-time world, WEG D6 resolution under the hood.**

Players move, aim, take cover, fire, dodge, pilot, slice, and interact in real time. The server groups meaningful actions into short authoritative action windows so WEG-style pools, range difficulties, opposed rolls, cover, multi-action penalties, wounds, scale, Character Points, and Force Points can still resolve coherently.

## Ground Combat Direction

| Tabletop / MUSH Concept | Real-Time MMO Translation |
|---|---|
| Round | Short server action window, initially modeled as about 5 seconds. |
| Declaration | Actions inferred or queued during the window: shoot, aim, dodge, sprint, interact, reload, use cover. |
| Initiative | Used for contested timing, simultaneous events, NPC behavior, and close edge cases rather than freezing all players. |
| Multi-action penalty | Applied when a character performs multiple meaningful WEG actions inside the same window. |
| Aim | Maintained steady action that stacks up to the WEG/SW_MUSH cap and is consumed by a shot. |
| Normal dodge | Active defense that replaces incoming ranged difficulty and counts as another action in the current window. |
| Full dodge | Committed defensive stance that adds to incoming ranged difficulty and suppresses offensive actions while active. |
| Cover | Position-derived state. Cover adds rolled difficulty dice, and firing from strong cover exposes the shooter down to quarter cover per live SW_MUSH behavior. |
| Armor condition | Persistent equipment state. Hit-location-aware partial coverage can decide whether armor soak applies, and penetrating damage can chip armor quality pips for later soak rolls while WEG wound and damage bands stay authoritative. |
| Suppression | Real-time pressure relief from a successful hit. It delays an armed remote's next live-fire tick, but does not replace WEG damage, soak, or wound results. |
| Near-miss pinning | Real-time pressure relief from a close miss against configured NPCs/remotes. It briefly delays return fire without converting the miss into WEG damage. |
| Peeking / tucked NPC fire | Encounter pacing state for covered NPCs/remotes. Tucked ticks delay automatic fire, while exposed ticks can still resolve through the normal WEG attack, cover, damage, and soak path. |
| Coordinated NPC fire | Fire-team pacing state for armed NPCs/remotes. When several members of the same group become ready on one tick, the selected shooter resolves normally and lower-priority wingmates hold in a coordinating state. |
| Reload / weapon cycle | Encounter pacing state for armed NPCs/remotes. Reload ticks delay automatic fire, while the next ready tick still resolves through the normal WEG attack, damage, and soak path. |
| Morale hesitation | Encounter pacing state for wounded/stunned NPCs/remotes. Hesitation ticks delay automatic fire, while WEG wound penalties and later attacks still resolve through the normal rules path. |
| Wounded fallback | Encounter behavior triggered when an NPC/remote crosses a configured wound threshold. It briefly delays live return fire while WEG wound penalties and damage state remain the authoritative mechanics. |
| Character Points | Player-committed burst dice for important actions or soak. In MMO terms, this should feel like a scarce clutch resource, not a passive stat. |
| Force Points | Rare one-window commitment that doubles character skill/attribute pools. It should feel dramatic and mutually exclusive with CP spending. |
| Wounds/stuns | Persistent state modifiers affecting movement, action timing, accuracy, and future checks. |

The prototype currently applies player stun/wound severity as dice penalties to attack, dodge, and soak pools. It does not yet implement SW_MUSH's full per-stun timers, stun-KO wall-clock duration, or incapacitation gates.

## Prototype Rule

The Bay 94 blaster range is the first testbed for this translation. It is still simplified: one player, one selected target, one remote response per exchange. The code should move toward action-window language and server-authoritative state, but preserve the currently verified WEG/SW_MUSH mechanics as each piece is translated.

## Networking Implication

Combat resolution should eventually live on the server. Clients can predict animation, input feel, and HUD feedback, but the authoritative result should come from shared D6 state:

- character pools and wounds
- weapon and armor data
- range and cover
- declared or inferred actions
- temporary aim/dodge/CP/Force Point state
- deterministic combat event logs

This keeps the game playable like a real-time MMO while keeping WEG D6 as the rules engine rather than decorative flavor.

## Deterministic Exchange Seeds

Each combat action window should have a server-authored exchange seed. All D6 rolls inside that window use a single seeded random stream: attack, cover, dodge, damage, soak, and return fire. The resulting event log carries the seed so the server can audit, replay, and explain outcomes without depending on client-local randomness.

The current Bay 94 prototype already supports seeded exchange replay in `ground_combat_model.gd`. The playable range generates local seeds for now; a future multiplayer server should replace those with authoritative seeds attached to combat-event messages.

## Action Window Model

`scripts/rules/action_window_model.gd` is the first shared-world timing scaffold. It keeps WEG initiative/declaration/resolution structure without requiring every player in the world to stop for a global turn. `scripts/rules/range_action_window_model.gd` now adapts the live Bay 94 range inputs into player and remote declaration summaries, then assembles a ready-for-resolution action-window packet consumed by packet-driven ground combat resolution wrappers.

- Initiative rolls are deterministic from a server seed and use Perception-style pools.
- Declaration order is reverse initiative, preserving the tabletop information asymmetry.
- Resolution order is highest initiative first.
- Normal multi-action declarations produce a penalty count for the combat model to apply.
- Full dodge/full parry are exclusive declarations for the window.
- Dodge/full-dodge can be prepared once and reused against multiple incoming attacks in the same window.
- Character Points and Force Points are mutually exclusive within one declaration window.
- Live range action-window packets carry active participant IDs, unique player/remote declarations, readiness, errors, and the resolution-phase state for the current real-time exchange.
- Ground combat packet wrappers refuse invalid action-window packets before dice are rolled, preserving server authority over declaration validity.
- Resolved packet-driven combat results are wrapped in versioned event envelopes carrying the exchange seed, action-window summary, event list, event types, state deltas, and flags needed by future server logs or transport.
- A capped local combat audit log stores recent envelopes and exposes a compact latest-event summary until durable headless-server logging is introduced.

The current Bay 94 range still resolves a compact one-player/one-remote exchange, but future server combat should assemble those exchanges from this action-window state rather than inventing a separate MMO-only timing model.
