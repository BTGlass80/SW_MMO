# SW MMO Prototype

Standalone Godot prototype for a Clone Wars-era, WEG Star Wars D6-grounded successor/spinoff to `C:\SW_MUSH`.

`C:\SW_MUSH` is treated as read-only reference material. This project should not import, mutate, or require the live text-game code at runtime unless a future explicit migration step copies curated data into this folder.

## Current Slice

- Godot 4.6.x target.
- Generated 3D Mos Eisley-style settlement scene with blocky, Minecraft-styled forms.
- Player controller for walking and looking around the settlement.
- `D6Rules` autoload containing the initial WEG-style dice pool and Wild Die resolver.
- First tactical prototype: live-pressure blaster range, cover, target-specific moving target patterns, target inspection with current/next live behavior explanation, in-world live remote-state badges, in-world hit-location feedback, persistent body-part damage tinting and scorch/impact marks, staggered remote-fire cadence, coordinated remote fire-team holds, peeking/tucked remote behavior, near-miss pinning, flanking/repositioning holds, reload/weapon-cycle holds, covering-fire holds, morale hesitation, wounded-remote fallback, hit suppression, damage, and soak against B1-style training targets.
- Live range telemetry shows model-derived remote-pressure countdown, armed/next/suppressed/pinned/covered/fallback/coordinating/flanking/reloading/hesitating/covering return-fire source counts, cover, defense, CP/FP queues, wound state, automatic-volley count, and the latest combat audit summary with compact pressure and hit-location/armor coverage hints from the recorded envelope.
- WEG armor with hit-location/partial-coverage soak, torso-only training blast vest coverage, persistent armor-quality degradation, scale, CP, FP, action-window scaffolding, packet-driven combat resolution, server-style combat event envelopes with range-pressure snapshots, and capped local combat audit logs covered by smoke tests.
- Prototype character sheet data/model/overlay: attributes, skill bonuses over attributes, gear lookup, CP, FP, wound state, armor coverage, and live armor-quality pips.
- 2.5D space mode with opaque modal presentation, paused ground controls/pressure/HUD/character-sheet overlay/target motion, cursor control, a model-formatted bridge-mode status line with current maneuver difficulty and named hazard preview, state-aware bridge action buttons with compact maneuver difficulty/hazard-count cues that refresh after piloting maneuvers, a model-formatted bridge crew/station strip with commander station, banked-assist requested-alias and station-round visibility, and crew-wound visibility, D6 crew-wound penalties on station actions including ship-aware sensor sweeps/contact identification with wound callouts in action readouts, clickable/selectable contacts, clickable approach hazards, logged target/hazard selection, a live traffic clock with manual traffic stepping, live tactical telemetry with known/hidden contact counts, latest automatic hostile-fire summaries, model-formatted contact labels, selected-contact detail readout with range-aware lock state, WEG scale posture, defensive posture, hull/shield soak posture, weapon posture, crew wound posture, systems posture, model-formatted bridge cue with action hotkeys, movement posture, hostile-fire readiness, counterfire posture, destroyed-weapon-aware and custom data-preserving field-repair options/routing with visible data-driven difficulty labels and yard-only-aware automatic targeting, and targeting-penalty preview, capped recent-action log, sensor sweep, contact identification, communications hail, traffic tick, gunnery action, confidence-modified hidden-target gunnery, gunnery targeting, lock-disruption, counterfire, automatic hostile-fire, ship-condition, shield-reroute, station-assist action, damage-control action with WEG difficulty-name callouts and yard-only field-repair wording, astrogation plot action, maneuver action, assist-replacement, maneuver-hazard, maneuver-collision, crew-wound, and break-lock readouts that report tracks, newly revealed contacts, current known/hidden totals, consumed sensor assists, movement, movement blocks, range holds, authoritative current weapon-solution pressure, data-driven successful-hail lock delays and failed-hail lock pressure with ready-lock callouts, ready hostile-fire opportunities, automatic hostile shots, resulting player ship condition, spent/cleared hostile locks, return-fire results, condition countdown changes, and hazard details, banked crew-assist target and station-round visibility with preserved requested target aliases, consumed assist callouts with requested-alias context across player station actions, replacement-aware station assist banking with requested-alias replacement text, helm/fire-control/shield/sensor/communications/engineering/navigation-family station-assist aliases for evasive/weapon-solution/deflector/identification/targeting/hailing/field-repair/route-plot support, commander tactical-coordination assists routed through sensor targeting, and preserved requested assist targets in station audit text, persistent hull-severity status, system-damage flags, deduplicated field-repair counts that exclude yard-only systems, and crew-wound counts, deterministic sensors with persistent revealed contacts, per-sweep new-contact callouts, margin-based track confidence, selected-contact identification profiles, and selected-contact comms dispositions with lock-delay/pressure context, confidence-annotated gunnery targeting context, combined track/weapon-solution engagement summaries in action and status readouts plus confidence-aware lock fallback telemetry, server-style tactical accounting ticks, moving and player-tracking contacts with destroyed/drives-disabled/control-locked movement-block reasons, hostile engagement ranges, live hostile fire from ready weapon-solution clocks, blocked-fire stale-lock cleanup for disabled/destroyed hostiles and destroyed player ships, same-tick destroyed-player fire blocking, consumed-lock telemetry cleanup, weapon-solution-gated counterfire with spent-lock telemetry, evasive and gunnery lock disruption, visible approach hazards with clickable difficulty/collision detail and current-maneuver crossing/avoidance preview, seeded gunnery, scale, heading-derived shield arcs, shield rerouting, rotating crew-station assists, piloting maneuvers, navigator astrogation plotting, data-driven approach hazards, failed-maneuver collision damage, starship damage/system/passenger/crew-wound results, player-prioritized damage control with formatted before/after condition changes, data-driven per-system repair difficulty overrides demonstrated on visible traffic, repair time/cost quotes, readable deduplicated condition summaries, and ship condition persistence that affects later exchanges.
- Bay 94 range includes static B1 remotes, a sine-sweeping B1 remote, peeking/tucked covered B1 remotes with near-miss pinning, coordinated fire-team holds, flanking/repositioning windows, reload/weapon-cycle holds, covering-fire holds, morale hesitation for wounded/stunned remotes, wounded-remotes fallback timers, and an inert patrol-pattern walker-scale armor target for cross-scale combat checks; only armed remotes contribute live return fire, automatic pressure uses per-remote cadence/phase/pinning/peek/fallback/coordination/flanking/reload/covering/morale metadata, live state badges show each target's current model-derived behavior state above the target, target inspection explains the current and next live behavior state, successful hits can briefly suppress active remotes, and close misses can briefly pin configured remotes.
- Mos Eisley Spaceport Row / Docking Bay 94 source-mapping note in `docs/MOS_EISLEY_SLICE.md`.
- Combat behavior source trace in `docs/COMBAT_SOURCE_TRACE.md`.
- Real-time WEG D6 MMO translation note in `docs/REALTIME_D6_TRANSLATION.md`.
- First 2.5D space tactical overlay note in `docs/SPACE_SLICE.md`.
- Unattended durable-loop tooling note in `docs/UNATTENDED_LOOP.md`.
- Current continuation notes in `docs/NIGHTLY_HANDOFF.md`.
- Design docs for phased development, fidelity policy, architecture, and source references.

## Open In Godot

1. Install or extract Godot 4.6.3 or newer 4.6.x stable.
2. Open Godot's Project Manager.
3. Import this folder:
   `C:\Users\btgla\Documents\Codex\2026-06-14\i-d-like-you-to-create\outputs\SW_MMO_Prototype`
4. Run the project.

## Networked Mode (Multiplayer Foundation — M1)

The solo experience above is unchanged (`scenes/main.tscn` is still the project's
main scene). A separate server-authoritative networked world lives in
`scenes/net_world.tscn`. See `docs/MULTIPLAYER_FOUNDATION.md` for the architecture.

Run a dedicated headless server:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --headless --path . res://scenes/net_world.tscn -- --server
```

Run a client (default host 127.0.0.1, port 24555):

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64.exe" --path . res://scenes/net_world.tscn -- --connect 127.0.0.1
```

Everything after `--` is a user arg. The server owns all positions; clients send
input intents and render authoritative snapshots.

## CLI Checks

After `C:\Godot 4` is on PATH:

```powershell
godot-console --headless --path . --import --quit
godot-console --headless --path . --script res://scripts/tests/rules_smoke.gd
godot-console --headless --path . --script res://scripts/tests/ground_combat_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/armor_condition_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/action_window_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/range_action_window_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/combat_event_envelope_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/combat_event_log_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/range_controller_smoke.gd
godot-console --headless --path . --script res://scripts/tests/range_status_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/range_inspection_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/range_hit_feedback_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/range_state_badge_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/range_target_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/moving_target_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/modal_overlay_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/space_overlay_layout_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/space_overlay_mode_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/space_station_strip_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/space_contact_selection_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/space_action_log_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/space_tactical_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/space_overlay_live_clock_smoke.gd
godot-console --headless --path . --script res://scripts/tests/space_status_model_smoke.gd
godot-console --headless --path . --script res://scripts/tests/data_smoke.gd
.\tools\check_project.ps1
```

## Controls

- `WASD`: move
- `Mouse`: look
- `Space`: jump
- `E`: inspect a location or range target
- `H`: toggle the character sheet overlay
- `M`: toggle the Mos Eisley approach space map
- `Esc` or `M` while the space map is open: close the space map and return to ground controls
- Left mouse click on a space contact: select the gunnery/damage-control target
- `Tab` or `.` while the space map is open: select the next space contact
- `,` while the space map is open: select the previous space contact
- `N`: open the space map and run a sensors sweep
- `I`: open the space map and identify the selected contact from the current sensor track
- `X`: open the space map and hail the selected contact over comms
- `T`: pause/resume the live space traffic clock
- `;`: open the space map and advance one manual space traffic accounting tick
- `B`: open the space map and resolve a seeded space-gunnery drill
- `J`: open the space map and resolve a seeded shield-reroute station action
- `K`: open the space map and resolve a seeded damage-control repair action
- `Y`: open the space map and resolve a seeded navigator astrogation-plot action
- `L`: open the space map and resolve a seeded piloting maneuver
- `U`: open the space map, then cycle and resolve a seeded crew-station assist for the next matching space action
- Left mouse click on a target: fire a WEG D6 blaster check
- Right mouse click: aim, stacking +1D per click to +3D for the next shot
- `C`: toggle half cover at the firing barricade
- `Q`: declare a normal dodge against the next remote shot
- `F`: declare a defense-only full dodge for the next live remote volley
- `V`: force an immediate multi-remote incoming-fire volley using the current cover/defense/CP/FP state
- `Z`: pause/resume live remote pressure
- `P`: queue one Character Point for the next blaster attack
- `O`: queue one Character Point for soak if the next remote shot hits
- `G`: queue one Force Point for the next action window
- `R`: reset the range drill
- `Esc`: release mouse
- Left mouse click elsewhere: recapture mouse

## Development Stance

The rule hierarchy is:

1. WEG Star Wars D6 Revised & Expanded rules are the mechanics source of truth.
2. Fun, readable MMO translation is the product goal when tabletop timing or text-game affordances do not map directly.
3. Clone Wars-era SW_MUSH code/data is a reference implementation and content source, not a one-to-one port target.
4. Remaining Galactic Civil War references are legacy contamination unless explicitly retranslated to Clone Wars.
5. New Godot/MMO systems are valid when they preserve or extend WEG D6 play better than a literal MUSH translation.

When SW_MUSH and WEG diverge, the divergence should be documented before implementation.
