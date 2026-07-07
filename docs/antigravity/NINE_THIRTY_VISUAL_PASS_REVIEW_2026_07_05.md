# 9:28 PM Visual Pass Review

Date: 2026-07-05
Reviewer: Codex
Latest checked commit: `00a42b5` (`Address BETA_STATUS_FEEDBACK_2026_07_05: Fix commands, routing, tests, RPC proofs`)

## Verdict

Better than the 9:01 PM regression pass. Still not visually accepted.

The technical gate remains green:

```text
world_grounding_smoke: OK - Verified grounding metadata: 1 hover, 35 grounded models
world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
world_capture_points_smoke: OK - Found 13 capture points
All 143 smoke tests completed successfully.
Wired GDScript smokes run: 143 | RPC surface (@rpc in network_manager.gd): 82
All checks passed.
```

The severe white-geometry/foreground-occluder regression from the 9:01 PM capture set is mostly corrected. That is good. However, the 9:28 PM captures still do not meet release presentation standards. The problem has shifted back from "obvious visual regression" to "the authored playspace is still not strong enough."

Do not expand the beta roadmap yet.

## What Improved

- The stark white occluders from Speeders, Transport/Customs-adjacent shots, and Control Tower are mostly gone.
- Bay 94 has more deliberate ground markings and prop placement.
- The scratch files previously seen at repo root remain cleaned up.
- Full validation remains stable after another map/build pass.

## Remaining Visual Blockers

### Spawn Range

This is better than the 9:01 view but still not a good spawn/readiness shot. It now shows more of the range, but the composition is still cluttered and awkward:

- `READY` text is visible in the upper-left, which makes the capture look like a test harness rather than an in-world view.
- The frame is dominated by gray floor, blocky crates, a wall to the right, and partial edge occlusion.
- The range reads as "test objects in a box," not a Star Wars MMO starting/combat area.

Fix:

- Remove debug/status text from release captures.
- Stage the spawn as an intentional first read: firing line, target lane, one clear exit path, and one strong Mos Eisley landmark.
- Reduce edge occlusion and random block clutter.

### Spaceport Row East

Still poor. The main subject is a giant blank tan wall and a vertical slab. The street is visible only as a side glimpse.

Fix:

- This capture needs a new angle or a real rebuild. Do not keep trying to decorate around the same wall-dominated composition.
- Move the capture point into the street axis, or cut openings/recesses into the wall so the player sees storefronts and alleys instead of a slab.

### Spaceport Row West

Slightly cleaner than before, but still weak. The central vertical slab and long blank right wall dominate the shot; the interesting parts are pushed to the edges.

Fix:

- Remove or relocate the central occluding slab from this view.
- Add street-level identity: doors, pipes, awnings, signage, alcoves, crates that are grounded and scaled intentionally.
- Make the view read as a route through a settlement, not a corridor beside wall chunks.

### Bay 94 Entrance

Improved. It now has a clearer threshold, darker bay face, red header, markings, and service-pad language. Still too boxy and sparse.

Fix:

- Add bay number/signage in the first read.
- Add side equipment and wall detail so the large dark door face does not become the whole POI.
- Reduce the visible test-arena feeling by adding docking-bay infrastructure.

### Bay 94 Pit

Improved but not done. The yellow markings and props are more deliberate; the encounter lane is readable. It still looks like a gray-floor test arena with an NPC centered in the shot.

Fix:

- Keep the lanes, but make the cover look like cargo/service infrastructure rather than generic boxes.
- Add ship-bay context: conduits, wall panels, gantry supports, cargo sleds, fuel coupling, bay number.

### Customs Front

More dressed but compositionally awkward. The central stacked vertical prop blocks the facade and becomes the main subject.

Fix:

- Move tall stacked props out of the capture center.
- Make the checkpoint identity clear: scanner arch, queue rails, inspection desk, posted notices, cargo check table.

### Speeders Front

The huge white occluder is gone, which is good. The area still does not fully sell "speeder shop/service bay." A large horizontal dark piece dominates the right side and the vehicle/frontage is not staged cleanly.

Fix:

- Reframe so the speeder and service frontage are the center of the view.
- Add tool racks, lift/supports, parts bins, and shop-facing signage or color accents.
- Avoid one long horizontal slab as the main visual.

### Transport Depot Front

Still not distinct enough from Customs/shops. It has facade dressing, but not enough transport identity.

Fix:

- Add route-board, benches, cargo pickup/dropoff, dispatcher window, and depot markers.
- Keep foreground props from blocking the facade.

### Control Tower

Better than the 9:01 version. The giant white cropped foreground object is gone. There is still a left wall/ground edge intrusion and the right-side building crop competes with the tower.

Fix:

- Keep the tower/NPC/ladders/service-prop idea.
- Clean the capture frame so the tower is the clear subject.
- Add base detail without edge occlusion.

### Cantina

Still the strongest authored area and still the correct quality reference. Interior captures remain readable but have the same rough ceiling/wall seam and sparse back-room issues noted before.

Fix:

- Use the Cantina exterior as the minimum standard for every named POI.
- Clean the interior seams and give the back room more purpose.

## Direction

Stop doing broad visual churn. The next pass should be three focused acceptance tasks:

1. Reframe or rebuild `Spaceport Row East` and `Spaceport Row West` so neither capture is dominated by blank walls or central slabs.
2. Re-stage `Spawn Range` as a deliberate first-read and remove debug/status text from the capture.
3. Push one non-cantina POI, preferably `Bay 94 Entrance`, to a true authored-landmark standard with signage, infrastructure, and grounded props.

After that:

1. Regenerate all 13 captures.
2. Run `tools/check_project.ps1`.
3. Compare only the changed views first. Do not broaden to new systems until those views are accepted.

## Beta Roadmap Call

Still no beta roadmap expansion.

The project has a healthy green gate now. The remaining blocker is not whether the tests run; it is whether Mos Eisley looks like a deliberately authored release slice. The 9:28 PM pass is movement in the right direction, but it is not there yet.
