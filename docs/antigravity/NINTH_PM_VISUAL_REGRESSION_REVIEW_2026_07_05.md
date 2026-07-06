# 9:01 PM Visual Regression Review

Date: 2026-07-05
Reviewer: Codex
Latest checked commit: `00a42b5` (`Address BETA_STATUS_FEEDBACK_2026_07_05: Fix commands, routing, tests, RPC proofs`)

## Verdict

The gate is still green. The visual pass is not acceptable.

Validated locally:

```text
world_grounding_smoke: OK - Verified grounding metadata: 4 hover, 39 grounded models
world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
world_capture_points_smoke: OK - Found 13 capture points
All 143 smoke tests completed successfully.
Wired GDScript smokes run: 143 | RPC surface (@rpc in network_manager.gd): 82
All checks passed.
```

Also good: the previous root scratch files are gone.

But the 2026-07-05 9:01 PM capture set is not a release-quality improvement. It adds or exposes several visual regressions: large white/unmaterialed-looking pieces, new foreground occluders, and the same blank wall-slab compositions that have been called out repeatedly.

This should not be treated as beta progress. The next step should be a small targeted visual acceptance pass, not another broad geometry churn.

## New / Continuing Blockers

### 1. White Placeholder-Looking Geometry

Several screenshots now show bright white geometry that reads like missing materials or debug/placeholder meshes:

- `playtest_01_spawn_range.png`: white partial object at lower right and small white panels/signs in the yard.
- `playtest_03_spaceport_row_west.png`: large white object cropped at the right edge.
- `playtest_06_customs_front.png`: stacked light/white shapes in front of the main facade.
- `playtest_07_speeders_front.png`: huge white foreground occluders, including a rail/beam cutting diagonally through the frame and a white block mass on the right.
- `playtest_08_transport_depot_front.png`: white/light foreground blocks interrupt the facade composition.
- `playtest_09_control_tower.png`: giant white cropped object intrudes from the upper-right foreground.

Fix these first. Every visible white object needs to be one of:

- deliberately materialed and staged,
- moved out of the capture path,
- hidden from the authored view,
- or removed.

Do not leave bright white geometry in screenshots unless it is intentionally a painted, grounded, in-world asset.

### 2. Spawn Range Got Worse as a First Read

The spawn capture now looks like the camera is peeking over/through a large wall into an unfinished yard. The lower half is dominated by a massive tan slab, with partial clipped objects at the edges.

Fix:

- Move the spawn capture/player start to a clean human-height read.
- Do not let a wall fill the foreground.
- Show the actual range: firing line, targets, cover, and the route into the settlement.

### 3. Spaceport Row East/West Still Fail the Same Way

The Spaceport Row views remain dominated by unbroken wall slabs. This has not been solved by adding more props elsewhere.

Fix:

- Break the wall planes at player height.
- Add recessed entries, awnings, vents, cargo doors, service alcoves, banners/sign plates, piping, and height changes.
- Move the capture points if necessary so the view looks down an authored street rather than straight at blank walls.

### 4. Bay 94 Is More Identifiable, But Still Test-Arena-Like

Bay 94 entrance now has a darker door face and red header strip, which helps. The pit still reads like a gray-floor combat test box with crates and an NPC.

Fix:

- Keep the gameplay cover layout, but dress it as docking-bay infrastructure.
- Add grounded service assets: cargo sleds, fuel couplings, panel boxes, cable runs, gantry supports, floor markings, landing-bay numbering.
- Replace plain box stacks as the main identity.

### 5. Speeders Front Is a Visual Regression

The speeder area is now one of the worst captures because a white foreground rail/beam and white block mass dominate the shot. The actual service bay is hard to evaluate because the view is occluded.

Fix:

- Clear the foreground occluders.
- Reframe so the speeder is visible.
- Material the service-bay geometry with the same warm desert palette as the rest of the area.

### 6. Control Tower Has Identity, But Is Now Partially Obscured

The tower itself is one of the more successful non-cantina landmarks. The latest capture adds a giant cropped foreground object from the right, which hurts the read.

Fix:

- Remove the right-edge foreground intrusion.
- Preserve the tower/NPC/ladders/service-prop setup.
- Add base context without blocking the camera.

## What To Do Next

Do not do another large, all-map expansion. Do a contained acceptance pass:

1. Sweep all 13 capture views for white/unmaterialed-looking geometry and foreground occluders.
2. Fix only those blockers first.
3. Reframe Spawn, Spaceport Row East, Spaceport Row West, and Speeders Front.
4. Regenerate the 13 captures.
5. Compare the new captures side-by-side against this set before touching more systems.
6. Rerun `tools/check_project.ps1` after the visual fixes.

## Beta Roadmap Call

Still no beta roadmap expansion.

The technical foundation is now behaving well enough that the blocker is plain: the authored playspace does not yet meet release presentation standards. Get one clean visual capture set first, then revisit beta roadmap expansion.
