# July 6 Stale Capture and Bay 94 Review

Date: 2026-07-06 07:01 EDT
Reviewer: Codex
Latest checked commit: `5527843 Address TEN_OH_SIX_VISUAL_PASS_REVIEW: Fix Bay 94 and Spaceport Row, update playtest captures`
Checked state: dirty working tree with local edits to `world_builder.gd`, `visual_playtest_runner.gd`, and several playtest captures

## Verdict

Not done.

The current work cannot be accepted as a completed map pass, and it is not a beta-roadmap expansion point. The validation suite is failing because the playtest captures are stale, and the visible capture set still shows a major Bay 94 regression.

Current smoke result:

```text
ERROR in world_capture_points_smoke.gd:
world_capture_points_smoke: FAIL - Stale captures found (older than 1hr). Please regenerate using visual_playtest_runner.gd:
["playtest_01_spawn_range.png", "playtest_02_spaceport_row_east.png", "playtest_03_spaceport_row_west.png", "playtest_04_bay94_entrance.png", "playtest_05_bay94_pit.png", "playtest_06_customs_front.png", "playtest_07_speeders_front.png", "playtest_08_transport_depot_front.png", "playtest_09_control_tower.png", "playtest_10_cantina_exterior.png", "playtest_11_cantina_entrance.png", "playtest_12_cantina_bar.png", "playtest_13_cantina_back_room.png"]
Failed 1 out of 143 tests.
```

The capture files are dated July 5, 2026 at 11:19 PM. As of this July 6, 2026 review, they are no longer accepted by the freshness gate.

Focused technical checks still pass:

```text
world_grounding_smoke: OK - Verified grounding metadata: 1 hover, 60 grounded models
world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
```

That means the pass is directionally better on grounding metadata and route probes, but the release claim is still blocked by stale visual evidence and visible art failures.

## What Improved

- Spaceport Row East and West are better than the worst earlier versions. The street reads more open and less like a solid blank-wall trap.
- The ground/collision focused smokes are passing.
- The added grounded count suggests recent props were registered more carefully than in previous passes.

Preserve those gains.

## Still Broken

### Bay 94 Entrance

This is the current highest-priority visual regression. The July 5 11:19 PM capture shows bright white panels/blocks across the bay wall and background, plus a loud red/yellow foreground cube stack. It reads as debug/test geometry, not docking-bay infrastructure.

Fix it before touching anything else:

- Remove or properly material every bright white block/panel visible in Bay 94.
- Replace the red/yellow cube stack with believable grounded service equipment.
- Use yellow only for stripes, caution trim, signs, or small hazard accents.
- Give Bay 94 a readable identity: bay number, bulkhead panels, pipes, conduits, landing-zone edge markings, fuel/service hookups, cargo sleds, and grounded crates.

### Bay 94 Pit

The pit capture has the same problem: white panel clusters, bright test colors, and a central arrangement that still reads like a prototype arena.

Fix:

- Rebuild cover and side detail as cargo/service infrastructure, not plain cubes.
- Remove visible white test panels from the wall and far side.
- Keep all props grounded and route-tested.
- Re-capture from the player route, not from a flattering angle.

### Spawn Range

Spawn still reads like a test range. It needs to become an authored Clone Wars-era Mos Eisley starter space.

Fix:

- Reduce abstract platform/block language.
- Add grounded local context: low walls, shade, dusty settlement detail, small service fixtures, props with purpose.
- Make sure the first view after spawn is not dominated by debug-looking panels or target-range composition.

### Non-Cantina POIs

Customs, Speeders, Transport Depot, and Control Tower still do not match the Cantina exterior's relative readability.

Fix each POI by giving it one strong, obvious subject:

- Customs: inspection booth, queue barrier, cargo scanner, stamped crates, official signage.
- Speeders: visible speeder silhouettes or parts, lift/service bay, tool racks, parts piles.
- Transport Depot: passenger/cargo loading zone, schedule/signage, depot awning, stacked cargo.
- Control Tower: keep the tower shape, but add base-level support, cables, access door, and nearby control props.

## Required Next Pass

Do not broaden features. Do not expand the beta roadmap. Do not claim completion from stale screenshots.

Antigravity should do this in order:

1. Fix Bay 94 Entrance and Bay 94 Pit until no white test panels or red/yellow cube stacks are visible.
2. Preserve the Spaceport Row improvements while adding only small street-level purpose.
3. Strengthen Spawn, Customs, Speeders, Transport Depot, and Control Tower identity without adding new systems.
4. Regenerate all 13 captures with `visual_playtest_runner.gd`.
5. Run the full gate with `.\tools\check_project.ps1 -GodotConsole "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe"`.
6. Report the exact smoke/gate output, not a summary claim.

## Beta Roadmap Call

No beta roadmap expansion yet.

A beta-facing roadmap should wait until the visual playtest evidence is fresh, the full gate is green, and the full Mos Eisley route no longer contains visible debug geometry, blockout props, or weak POI identity. This pass has useful movement, but it is still a gap-closure pass.
