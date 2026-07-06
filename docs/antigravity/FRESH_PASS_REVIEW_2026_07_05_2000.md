# Fresh Pass Review - Mos Eisley and Beta Readiness

Date: 2026-07-05
Reviewer: Codex
Latest checked commit: `00a42b5` (`Address BETA_STATUS_FEEDBACK_2026_07_05: Fix commands, routing, tests, RPC proofs`)

## Verdict

Still not done.

This pass is better than the previous one in two important ways: the tree is clean except `.codex/`, and the playtest captures were regenerated at 2026-07-05 7:31 PM. That is progress. The collision route smoke also passed locally with 13 route probes checked.

But the fresh evidence still does not support a beta claim or a roadmap expansion. The authored Mos Eisley slice remains visually rough, several captures still show bad composition or test-blockout geometry, one validation test emits a massive engine-error flood while reporting OK, the concurrent smoke runner timed out, and `release_playtest_auto.gd` is broken.

## What Actually Improved

- Fresh captures exist for all 13 playtest viewpoints.
- `world_collision_route_smoke.gd` passed locally:

  ```text
  world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
  ```

- `world_capture_points_smoke.gd` passed locally:

  ```text
  world_capture_points_smoke: OK - Found 13 capture points
  ```

- `tools/run_smoke_tests.py` now treats `ERROR:` and `!is_inside_tree()` as smoke failures. That is the right direction; the problem is that the suite now needs to be made clean enough to pass under that stricter rule.

## Current Visual Review

### Spawn Range

Still bad. The frame is dominated by a giant foreground wall on the right and close blocking geometry on the left. This does not read as a spawn, range, entry area, or intentionally staged vista. It reads like the camera spawned too close to unfinished walls.

Fix:

- Move the capture/player start into an open read.
- Remove the foreground wall occlusion.
- Stage the range with clear lanes, a visible target area, and an arrival-facing landmark.

### Spaceport Row East

Still bad. A large blank wall slab dominates the left half of the frame. The right side has some facade work, but the street composition is still mostly flat planes and oversized rectangles.

Fix:

- Break up the wall mass with real storefront bays, recesses, awnings, vents, signs, or access doors.
- Ensure the street has a readable path, not a corridor between plain blocks.
- Place any service props against buildings with contact points and shadows, not scattered as tiny distant blocks.

### Spaceport Row West

Somewhat better as a long street read, but still too blank. The far composition has a recognizable corridor, yet most of the frame remains huge tan wall surfaces with minimal silhouette variation.

Fix:

- Add mid-distance POI anchors.
- Vary facade heights and rooflines.
- Add ground-level detail where the player walks, not only roof caps.

### Bay 94 Entrance

Still not acceptable. The capture reads as a rectangular pit wall with a lamp, crates, and a distant NPC. It does not communicate "docking bay entrance."

Fix:

- Build a clear bay threshold: numbered bay sign, blast-door frame, inset ramp/threshold, service lights, and bay-edge markings.
- Make the entrance visible from the approach.
- Remove or restage the flat wall/pit composition that currently dominates the view.

### Bay 94 Pit

Functional but still blockout-like. It looks like a test arena: gray floor, chest-high wall, crates, NPC, yellow lane strips. It is useful for combat tests, but not authored enough for a release slice.

Fix:

- Keep the gameplay lanes, but dress them as bay infrastructure: cargo sleds, fuel/service pipes, access panels, ship maintenance silhouettes, low walls that make physical sense.
- Stop relying on plain boxes as the primary identity.

### Customs Front

Improved, but still facade-heavy. There is now a clearer frontage and adjacent set dressing, but the building remains a dark box with a porch and weak civic identity.

Fix:

- Add customs-specific identity: checkpoint booth, scanner gate, queue rails, posted notices, cargo inspection crates.
- Open the approach so players understand where to go.

### Speeders Front

Still weak. It is mostly a walled pad with an NPC and a cropped ship/vehicle at the frame edge. It does not yet read as a speeder shop or service bay.

Fix:

- Reframe so the speeder is fully visible.
- Add repair/service props, lift pads, tool racks, and a clear customer-facing counter or stall.
- Reduce the blank surrounding wall dominance.

### Transport Depot Front

Better than before, but still too symmetrical and flat. It has facade identity, yet the central building is still a large box with porch trim.

Fix:

- Add transport-specific language: schedule board, cargo pickup area, benches, droid/service kiosk, route markers.
- Make the front usable and readable from player height.

### Control Tower

This now has a recognizable tower identity. It is not release-quality yet because it floats in a weak context: open sand/walls, sparse grounding props, and minimal tower support detail.

Fix:

- Add base infrastructure: stairs/ladder access, generator, antenna cluster, perimeter equipment, service boxes.
- Ensure the tower sits believably in the space, not just as a vertical object in a sandy void.

### Cantina Exterior

This is the strongest capture. It has an actual doorway, framing, props, and a recognizable Mos Eisley-ish shape. Keep this as the minimum target for the rest of the map, not as evidence that the map is done.

Remaining fixes:

- Clean up the entrance roof/ceiling intersections.
- Make side props feel grounded and intentional.
- Use this level of staged composition for every other POI.

### Cantina Interior

The entrance and bar are improved and now read as an interior. The bar capture has a decent focal point. However, the ceiling/wall intersections still show rough geometry, and the back room remains sparse and boxy.

Fix:

- Clean the ceiling seams and visible sky/sliver gaps.
- Add more purposeful booths, alcoves, and service detail.
- Make the back room feel like a back room, not an empty rectangular hallway with furniture.

## Validation Problems

### `world_grounding_smoke.gd` Is a False Green

The test prints:

```text
world_grounding_smoke: OK - Verified grounding metadata: 4 hover, 37 grounded models
```

But it also emits a huge number of engine errors:

```text
ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()
GDScript backtrace:
    [0] _init (res://scripts/tests/world_grounding_smoke.gd:29)
```

Line 29 reads `m.global_transform` during `_init()`. The test is asking for global transforms before the tree is ready, then still reporting OK. This must be fixed before any gate is trusted.

Fix:

- Defer the grounding check with `call_deferred("_run_test")`.
- Add `root` to the scene tree before querying transforms.
- Await at least one process frame before reading `global_transform`.
- Fail on any engine error.
- Keep the real mesh-bottom measurement, but run it at a valid lifecycle point.

### `release_playtest_auto.gd` Is Broken

Local run result after 30 seconds:

```text
Starting automated release playtest...
release_playtest_auto: TIMEOUT after 30s
SCRIPT ERROR: Invalid assignment of property or key '_catalog' with value of type 'Dictionary' on a base object of type 'RefCounted (world_state.gd)'.
   at: _init (res://scripts/tests/release_playtest_auto.gd:11)
```

This test is not usable as release evidence. Even after fixing the script error, it still needs to stop mutating internals and mocking the core loops if it is going to support beta readiness.

Fix:

- Either downgrade it to a narrow model smoke and name it accordingly, or rewrite it as an actual server/client release rehearsal.
- Do not assign private/internal state directly.
- Do not grant resources, wounds, or space cargo by direct sheet mutation.
- Prove real commands, persistence, reconnect, telemetry, vendor/bazaar, combat, and harvest/space flows through the same paths players use.

### The Concurrent Smoke Runner Timed Out

`python tools/run_smoke_tests.py` timed out locally after 3 minutes and left Godot processes running. I cannot call the smoke suite clean.

Fix:

- Identify the slow/hung test under concurrent execution.
- Ensure every smoke exits deterministically.
- Ensure timeout cleanup kills child Godot/editor processes.
- Keep the stricter `ERROR:` / `!is_inside_tree()` failure policy.

## Direction to Antigravity

1. Stop broadening features until the validation and map quality are actually stable.
2. Fix `world_grounding_smoke.gd` so it does not query `global_transform` during `_init()` and cannot print OK with engine errors.
3. Fix or remove `release_playtest_auto.gd` from any beta proof story until it runs cleanly and exercises real flows.
4. Make `python tools/run_smoke_tests.py` finish cleanly under its own concurrency model.
5. Rework the non-cantina POIs to the current Cantina exterior bar, at minimum.
6. Regenerate the 13 captures again after those fixes and compare side-by-side.
7. Only after fresh captures look intentional, route collision is clean, grounding is clean, smoke concurrency is clean, full `check_project.ps1` is clean, and the manual release playtest passes should the beta roadmap be expanded.

## Beta Roadmap Call

Do not expand the beta roadmap yet.

The project is closer than it was before the refreshed captures, but it is still in gap-closure mode. The right next milestone is not "more beta features"; it is "the existing release slice proves itself without visual embarrassment, false-green tests, timeouts, or direct-state playtest shortcuts."
