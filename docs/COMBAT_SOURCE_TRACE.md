# Combat Source Trace

SW_MUSH code and live data are authoritative for implemented behavior. Guides are secondary orientation.

## Live SW_MUSH Code Checked

- `C:\SW_MUSH\engine\combat.py`
- `C:\SW_MUSH\engine\character.py`

## Behaviors Mirrored In Prototype

| Behavior | SW_MUSH Code | Prototype |
|---|---|---|
| Aim stacks to +3D and is consumed by attack | `Combatant.aim_bonus`, `_resolve_aim`, attack pool addition in `_resolve_attack` | `ground_combat_model.gd`, `blaster_range.gd` |
| Cover levels map to +1D/+2D/+3D difficulty dice | `COVER_DICE`, `COVER_NAMES` | `d6_rules.gd::roll_cover_bonus` |
| Full cover blocks direct targeting | `_resolve_ranged_attack` full-cover check | `d6_rules.gd::roll_cover_bonus`, `resolve_ranged_attack` |
| Attacking from better-than-quarter cover degrades to quarter cover | `_resolve_ranged_attack`: `actor.cover_level = COVER_QUARTER` | `ground_combat_model.gd::resolve_exchange` |
| Normal dodge replaces ranged difficulty | `_resolve_ranged_attack` dodge branch | `d6_rules.gd::resolve_ranged_attack`, `ground_combat_model.gd::_resolve_return_fire` |
| Full dodge adds to ranged difficulty | `_resolve_ranged_attack` full-dodge branch | `d6_rules.gd::resolve_ranged_attack`, `ground_combat_model.gd::_resolve_return_fire` |
| One declared defense can apply across multiple incoming attacks | `Combatant.dodge_roll_cached`; defense cache is cleared when declarations change | `d6_rules.gd::prepare_ranged_defense` pre-rolls dodge/full-dodge once for reuse by `resolve_ranged_attack` |
| Full dodge/parry must be the only action | `validate_declaration` full-dodge restriction | `ground_combat_model.gd::_resolve_full_dodge_exchange` skips the player attack and resolves only incoming fire |
| Initiative/declaration/resolution phase structure | `Combat.roll_initiative`, `declare_action`, `resolve_round`; help topic combat sequence | `action_window_model.gd` provides deterministic Perception initiative, reverse initiative declaration order, initiative-order resolution state, full-defense validation, and CP/FP declaration conflict checks |
| Multi-action penalty removes 1D per extra action | `dice.apply_multi_action_penalty`; `_resolve_attack` applies it before aim | `d6_rules.gd::apply_multi_action_penalty`; normal dodge now penalizes both the player shot and dodge roll |
| Wound/stun penalties subtract dice from combat rolls | `Character.total_penalty_dice`; `dice.apply_wound_penalty`; combat applies it to attack, dodge, and soak pools | `d6_rules.gd::apply_wound_penalty`; player and target wound severity now penalize attack, dodge, and soak pools where applicable |
| Armor adds to soak by damage type and may penalize Dexterity skills | `Character.get_armor_protection`; `Character.get_armor_dex_penalty`; combat applies armor to attack/dodge/parry and soak | `d6_rules.gd::armor_protection_pool`, `apply_armor_dexterity_penalty`, `apply_armor_to_soak`; `ground_combat_model.gd` composes armor with attack, dodge, target soak, and player soak |
| Character Point dice explode on 6 and do not mishap on 1 | `dice.roll_cp_die`, `dice.roll_cp_dice`; attack CP in `_resolve_ranged_attack`; soak CP in damage resolution | `d6_rules.gd::roll_cp_die`, `roll_cp_dice`; queued attack CP and soak CP in `ground_combat_model.gd` |
| Force Points double skill and attribute pools; CP and FP cannot be combined in the same round | `dice.apply_force_point`; combat declaration validation blocks CP/FP mixing | `d6_rules.gd::apply_force_point`; queued FP doubles player attack, dodge, and soak pools for one action window and blocks queued CP |
| Cross-scale combat uses adjusted scale modifiers | `dice.Scale`; `data.help_topics` scale entry; `starships.py` cross-scale starfighter/capital handling | `d6_rules.gd::scale_difference`, `apply_scale_to_attack_pool`, `apply_scale_to_dodge_pool`, `apply_scale_to_damage_pool`, `apply_scale_to_soak_pool` |
| Wound thresholds by damage margin | `WoundLevel.from_damage_margin` | `d6_rules.gd::wound_for_damage_margin` |
| Stun mode caps severe damage at stunned/unconscious | `_apply_damage` stun-mode branch | `d6_rules.gd::resolve_damage(..., stun_mode=true)` |

## Prototype MMO Translation Added

- `ground_combat_model.gd::resolve_exchange` accepts an optional exchange seed and uses one seeded RNG stream for the full action window.
- `ground_combat_model.gd::resolve_exchange_with_action_window` and `resolve_incoming_fire_window_with_action_window` validate assembled action-window packets before rolling, giving the server path an explicit packet-driven resolution entry point.
- `combat_event_envelope_model.gd` wraps packet-driven combat results in a versioned `combat.exchange.resolved` envelope with action-window summary, event types, state deltas, optional encounter-state snapshots, and result flags for future multiplayer transport/audit logs.
- `combat_event_log_model.gd` maintains a capped in-memory envelope audit log and summary so the range can expose latest seed/kind/round/event counts before durable server storage exists.
- `combat_event_log_model.gd` extracts compact ready/next/suppressed/pinned/covered/fallback/coordinating/flanking/reloading/hesitating range-pressure hints plus the latest hit-location/armor coverage result from the latest envelope for range HUD audit display.
- Bay 94 shot and incoming-fire envelopes now attach a `range_pressure` snapshot with current and next live remote-state summaries, giving future server logs the encounter-pressure context around each WEG action window.
- Combat exchanges emit structured event payloads for player attacks, full-dodge defense-only windows, target damage, remote return fire, disabled-target checks, and exchange completion.
- `ground_combat_model.gd::resolve_incoming_fire_window` resolves several incoming attacks against one prepared defense and spends queued soak CP only once.
- The playable Bay 94 range now derives trainee attack, dodge, soak, weapon, armor, CP, FP, and wound starting state from `character_sheet_model.gd` plus prototype character/gear data when available; the sheet overlay also exposes armor coverage and live armor-quality pips.
- `range_inspection_model.gd` formats range target inspection text for `E`, exposing profile name, scale, cover, wound state, soak pool, armor coverage/quality, armed/inert status, weapon pool, optional current/next live behavior state context, and source note from the same profile data used by combat resolution.
- `range_hit_feedback_model.gd` formats short-lived in-world target feedback from the resolved exchange packet, showing hit/miss/blocked state, WEG hit location, armor coverage/degradation, wound result, persistent body-part damage tint targets, and persistent scorch/impact marker specs without changing combat math.
- `range_state_badge_model.gd` formats the in-world live remote-state badges shown over Bay 94 targets and the short explanations used by range inspection, keeping READY/WAIT/TUCKED/COVER/HOLD/FLANK/RELOAD/HESITATE/FALLBACK/SUPPRESSED/PINNED/DOWN/INERT wording, colors, and meanings model-owned while the scene only renders or passes through the current state.
- `armor_condition_model.gd` owns deterministic hit-location helpers, partial-coverage armor application, and persistent armor-quality degradation. Ground combat applies coverage and quality pips to later armor soak, records hit location plus before/after quality in damage events, and leaves WEG wound/damage bands unchanged. The prototype training blast vest is explicitly torso-only data, so uncovered hits can bypass that soak through the existing WEG hit-location path; range telemetry now surfaces the latest covered/uncovered armor result from the combat event envelope.
- `range_target_model.gd` prevents inert range targets with no attack/damage pool, such as the walker-scale armor plate, from contributing return fire.
- `range_target_model.gd` also gates automatic live pressure with cadence/phase, smoke-tested near-miss pinning thresholds, peeking/tucked, flanking/repositioning holds, reload/weapon-cycle holds, covering-fire holds, morale hesitation, coordinated fire-team holds, and wounded-fallback metadata, preserving manual all-remote volleys for debug and WEG resolution checks.
- `range_target_model.gd` also honors per-target suppression ticks, allowing successful hits to delay upcoming live-fire ticks while preserving WEG D6 resolution.
- `range_target_model.gd` reports live remote states such as ready, waiting, pinned, covered, coordinating, flanking, reloading, covering, hesitating, fallback, suppressed, inert, and disabled, and summarizes mixed participant snapshots for telemetry/server accounting and the in-world state badges without embedding roll logic in the scene controller.
- Target profiles now carry their own weapon damage for return fire and incoming-fire windows instead of sharing the trainee weapon pool.
- `moving_target_model.gd` keeps live range target motion deterministic and metadata-driven, including sine sweeps and patrol/triangle movement patterns for different target types.
- `range_status_model.gd` exposes model-derived armed/next-scheduled/suppressed/pinned/covered/fallback/coordinating/flanking/reloading/hesitating/covering remote counts and the latest audit summary, including compact pressure and hit-location/armor hints from the last envelope, so staggered live pressure, coordinated fire-team holds, near-miss pinning, peeking/tucked behavior, flanking/repositioning, reload/weapon-cycle holds, covering-fire holds, morale hesitation, wounded fallback, hit suppression, partial armor coverage, and server-style event envelopes are legible without changing WEG attack resolution.
- `space_status_model.gd` formats selected-contact movement posture from movement events/profile data, making player-tracking, range-holding, closing, patrol, and blocked-movement contact behavior visible in the space side panel without changing WEG movement or gunnery resolution.
- `space_status_model.gd` formats selected-contact scale posture from contact scale data, keeping WEG cross-scale context visible without applying additional modifiers outside the existing scale helpers.
- `space_status_model.gd` formats selected-contact defensive posture from the contact defense pool and persistent controls, maneuverability, drives, and destruction condition fields, mirroring the target-defense inputs used by space gunnery without rolling or changing difficulty.
- `space_status_model.gd` formats selected-contact hull/shield soak posture from hull pools, shield pools/arcs, shield loss, and controls ionization, mirroring starship damage resistance inputs without rolling or changing soak.
- `space_status_model.gd` formats selected-contact weapon posture from gunnery pool, fire control, weapon damage, controls ionization, disabled weapons, and destruction condition fields, mirroring attacker inputs used by space gunnery without rolling or changing difficulty.
- `space_status_model.gd` formats selected-contact crew wound posture from persisted passenger/gunner damage packets, including stunned crew, so station-impacting WEG wound state is readable without changing crew penalty resolution.
- `space_status_model.gd` formats selected-contact systems posture from Move loss, hyperdrive disabled/calculation state, astrogation difficulty penalties, generator overload, structural damage, and destruction condition fields, mirroring persistent starship system state without rolling or changing repair.
- `space_status_model.gd` formats selected-contact bridge cues with action hotkeys from existing sensor, identification, communications, weapon-solution, targeting, repairable-condition, and destroyed-state fields, guiding the next useful bridge action without adding a new rules gate.
- `space_status_model.gd` formats selected-contact hostile-fire readiness from weapon-solution state and contact condition, making acquiring, partial, ready, armed, destroyed, and weapons-offline fire posture legible without changing WEG gunnery or counterfire resolution.
- `range_action_window_model.gd` translates real-time range input state into WEG-style player and remote declarations, assembles ready-for-resolution action-window state, and lets the range HUD include declaration summaries beside seeded exchanges.
- The Bay 94 range HUD displays the exchange seed so prototype combat results can be replayed during debugging.

## Not Yet Mirrored

- Integrating action-window initiative/declaration state into live multi-combatant range or server exchanges.
- Wiring multi-attacker incoming-fire windows into the playable range or server exchange loop.
- Richer moving vehicle/walker drills beyond the current sine and patrol-pattern range targets.
- Visual animation/state machines for peeking, flanking, reload, hesitation, fallback, and coordinated remote behavior.
- Full stun timers and unconscious duration.
- Actual character wound escalation semantics beyond max-severity target state.
- Multi-combatant server event queues beyond the current single target and single return-fire exchange.
- World-event ranged penalties such as sandstorm effects.

## Current Prototype Scope

The Bay 94 range drill is a controlled training simulator, not full combat. It exists to validate WEG D6 ranged attack, cover, aim, damage, soak, and return-fire presentation in a 3D Mos Eisley space before full server-authoritative combat is built.
