# Green Gate, Visual Not Ready

Date: 2026-07-05
Reviewer: Codex
Latest checked commit: `00a42b5` (`Address BETA_STATUS_FEEDBACK_2026_07_05: Fix commands, routing, tests, RPC proofs`)

## Verdict

The technical validation story improved a lot. The map is still not release-worthy.

This is the first pass where I can say the gate recovered:

```text
Python unit tests: OK
All 143 smoke tests completed successfully.
Wired GDScript smokes run: 143 | RPC surface (@rpc in network_manager.gd): 82
All checks passed.
```

The previous grounding false-green is also fixed in the targeted run:

```text
world_grounding_smoke: OK - Verified grounding metadata: 4 hover, 39 grounded models
```

Collision and capture-point checks also pass:

```text
world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
world_capture_points_smoke: OK - Found 13 capture points
```

That is real progress. Do not lose it. But a green gate is not a release-quality Mos Eisley. The fresh 2026-07-05 8:34 PM captures still show a playspace that reads like blockout plus first-pass dressing.

## Important Cleanup Before Handoff

The working tree currently has stray scratch files at the repo root:

- `patch_world_builder.py`
- `test_args.gd`
- `test_args.gd.uid`
- `test_names.gd`
- `test_names.gd.uid`
- `test_telemetry.gd`
- `test_telemetry.gd.uid`

Remove these or move any intentional test into `scripts/tests/` with a real name and gate wiring. Do not leave scratch files in the root.

`scripts/tests/release_playtest_auto.gd` was deleted. That is acceptable if the previous file was abandoned, but then beta proof must explicitly come from the live RPC smokes plus the manual release playtest, not from a missing "release auto" script.

## Visual Review of the 8:34 PM Captures

### Spawn Range

Still not acceptable. The capture is no longer the exact previous wall-closeup, but it remains a bad starting read: a huge vertical wall slices the frame, the view opens into an anonymous alley, and the range identity is weak.

Fix:

- Move the spawn/capture to a deliberately staged overlook into the range.
- Keep the range visible: target lanes, firing line, cover rhythm, and one clear landmark.
- Remove the central occluding slab from the first read.

### Spaceport Row East

Still one of the weakest shots. A blank wall slab occupies most of the left half. The right facade has detail, but the shot is fundamentally a wall canyon.

Fix:

- Break the left wall into storefronts, recessed service doors, shade cloth, vents, pipes, and height variation.
- Add a mid-street focal object so the path reads as a place, not a corridor.
- Ensure the capture does not use an unbroken wall as the main subject.

### Spaceport Row West

Still too blank. It has a long-street read, but the dominant impression is still broad tan planes, a white placeholder-looking shape, and distant tiny props.

Fix:

- Add midground silhouettes and facade breaks.
- Move detail to player eye level.
- Reframe or rebuild the white shape so it does not read like an untextured placeholder.

### Bay 94 Entrance

Improved, but not enough. The dark door face, red header strip, and threshold make it more legible as a bay entrance. It still reads like a rectangular test doorway sitting in a sparse pit.

Fix:

- Add the bay number/signage and docking-bay language where the player sees it immediately.
- Make the entrance threshold connect to the approach path.
- Add service conduits, warning stripes, inset panels, landing-bay grime, and side equipment.

### Bay 94 Pit

Still reads as a combat test arena. The lanes are useful, but the composition is dominated by an NPC, crates, gray floor, walls, and yellow markers.

Fix:

- Keep the combat lanes while dressing them as real bay infrastructure.
- Add believable cover: cargo sleds, power couplings, fueling stations, gantry supports, maintenance crates.
- Avoid plain box stacks as the main identity.

### Customs Front

Improved. This now has more facade specificity, but the front still needs stronger customs/checkpoint identity.

Fix:

- Add scanner arch, queue rails, inspection crate table, posted notices, and a clear checkpoint desk.
- Let this be a civic/security POI, not just another shaded building.

### Speeders Front

Improved but still weak. The service-bay hint is visible, but the vehicle is partially cropped and the walled pad dominates.

Fix:

- Reframe so the speeder is fully visible.
- Add lift/repair equipment, tools, and shop signage.
- Reduce the empty wall/pad feel.

### Transport Depot Front

Slightly better as a facade, but still too symmetric and blocky.

Fix:

- Add route-board identity, benches, cargo pickup/dropoff, ticket or dispatcher window, and transport signage.
- Make the area communicate travel/logistics without relying on labels.

### Control Tower

This is one of the better non-cantina reads now. The tower, droid/NPC, ladders, and service bits help. It still needs base context and grounding detail.

Fix:

- Add service generator, cable runs, antenna cluster, access ladder/stair detail, and perimeter equipment.
- Give the tower a reason to occupy that spot in the settlement.

### Cantina Exterior and Interior

Still the strongest authored area. The exterior is the current quality target for the rest of the map. The entrance/bar/back-room captures remain more readable than the street shots, but still show rough ceiling/wall intersections and sparse back-room staging.

Fix:

- Use the Cantina exterior as the minimum bar for every named POI.
- Clean up interior ceiling seams and back-room emptiness.

## Technical Status

The current technical status is much better than the prior pass:

- Full `tools/check_project.ps1` passed.
- `tools/run_smoke_tests.py` completed 143 smokes successfully.
- Grounding no longer emits the `!is_inside_tree()` flood in the targeted run.
- Collision route coverage is passing.
- Capture points exist and fresh captures were generated.

Remaining technical caveats:

- The runtime launch still prints the known Godot object-leak warning. If this is expected, document it; otherwise track it separately.
- The gate proves systems and smoke stability, not human visual quality.
- The manual release playtest still needs to be run and recorded as the beta proof artifact.

## Direction

1. Preserve the green gate. Do not broaden features until the map is visually credible.
2. Clean the scratch files from the repo root.
3. Rebuild the weak captures in this order:
   - Spawn Range
   - Spaceport Row East
   - Spaceport Row West
   - Bay 94 Entrance
   - Bay 94 Pit
   - Speeders Front
4. Use the Cantina exterior as the minimum quality target: staged foreground, readable landmark, purposeful props, and no giant blank wall as the main subject.
5. Regenerate all 13 captures after the visual pass.
6. Run `tools/check_project.ps1` again after the visual pass.
7. Run and record the manual release playtest.

## Beta Roadmap Call

Do not expand the beta roadmap yet.

The technical gate is finally in a much healthier place, which matters. But beta is not just "tests pass." For this project, beta requires the playable slice to stop looking like a blockout. The next milestone should be named something like "green-gate visual polish pass" or "Mos Eisley authored slice acceptance," not a broader beta feature wave.
