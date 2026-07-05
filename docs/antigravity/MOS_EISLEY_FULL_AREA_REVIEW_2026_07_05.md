# Mos Eisley Full-Area Review - 2026-07-05

Verdict: not fixed. The latest pass is a partial improvement around the cantina, but it does not prove the whole Mos Eisley playspace is release-worthy. The current evidence is still mostly four cantina captures, and the broader Spaceport Row/Bay 94/customs/speeders/depot area remains under-reviewed and under-tested. Collision also still looks suspect.

## What Actually Improved

- Fresh captures were generated at 5:00 PM, so this pass is not relying on stale files.
- `visual_playtest_runner.gd` now clears old captures, returns failure on null/save errors, and has a basic flat-image check.
- `LandmarkBuilder` now adds capture points instead of relying on hard-coded camera guesses.
- The worst full-tan entrance capture is gone.
- Cantina table jitter now uses the seeded local RNG instead of global `randf_range()`.
- `WorldBuilder.place_model()` attempts recursive visual AABB grounding for imported models.
- Release-visible `LandmarkBuilder` labels are now hidden unless `--debug-world-labels` is present.

Those are real steps. They are not enough.

## Full-Area Coverage Is Still Missing

The visual runner only captures:

- Cantina exterior
- Cantina entrance
- Cantina bar
- Cantina alcove/back hallway

It does not capture or validate:

- player spawn
- Spaceport Row street read
- Docking Bay 94 entrance
- Docking Bay 94 pit/range
- Spaceport Customs Office
- Spaceport Speeders
- Transport Depot
- Control Tower
- Docking Bay 86
- Docking Bay 87
- wildlife edge spaces
- route from spawn to cantina
- route from spawn to Bay 94
- route from Spaceport Row into each room marker

Do not claim the playspace is fixed while only proving the cantina cluster. The request was the whole area.

Required fix: add full-area capture points and route probes in `WorldBuilder`, not only in `LandmarkBuilder`.

Minimum capture set:

- `playtest_01_spawn_range.png`
- `playtest_02_spaceport_row_east.png`
- `playtest_03_spaceport_row_west.png`
- `playtest_04_bay94_entrance.png`
- `playtest_05_bay94_pit.png`
- `playtest_06_customs_front.png`
- `playtest_07_speeders_front.png`
- `playtest_08_transport_depot_front.png`
- `playtest_09_control_tower.png`
- `playtest_10_cantina_exterior.png`
- `playtest_11_cantina_entrance.png`
- `playtest_12_cantina_bar.png`
- `playtest_13_cantina_back_room.png`

Each capture point should have expected-visible landmark metadata and fail if the resulting image is dominated by a wall, floor, sky, or one flat color family.

## Current Captures Still Show Problems

### Cantina exterior

`playtest_1_outside.png` is better than the earlier giant flat plaza, but still not good:

- A large centered block still dominates and obstructs the entrance read.
- The facade remains toy-like and symmetrical.
- The left and right flanking structures are present, but the street composition still reads as objects arranged around a door, not as a believable Mos Eisley street corner.
- Ground treatment remains broad tan patches with limited contact detail.

Fix: move the large centered foreground block out of the doorway composition. Put clutter to the sides, make the threshold readable, and build an actual approach route.

### Cantina entrance

`playtest_2_inside_entrance.png` is no longer pure wall, but it still shows an awkward blocker corridor:

- The player view is hemmed in by giant flat slabs.
- The NPC is awkwardly placed in the passage.
- The route into the room is visible only as a narrow sliver.
- The ceiling/dome geometry creates heavy triangular occlusion.

Fix: open the entrance route. Keep the reveal wall, but make it a navigable side screen, not the main subject of the shot.

### Cantina bar

`playtest_3_inside_bar.png` is the strongest shot, but still has release-blocking issues:

- Foreground bar slabs fill too much of the lower frame.
- The dome/wall shell leaks sky and has hard clipping seams.
- The interior still reads as ring-spawned furniture around a central block, not an authored social floor plan.

Fix: plan the interior paths first, then place furniture. Add wall/ceiling cleanup and reduce the foreground counter mass.

### Back hallway

`playtest_4_back_hallway.png` is still a failure:

- It is a tan tube ending in a box.
- It proves geometry exists, but not that the back area is interesting, readable, or comfortably playable.
- The private booth at the end blocks the composition rather than inviting the player forward.

Fix: widen the hall or offset the destination, add side detail, door frames, alcove depth, and a visible reason to enter. The capture needs at least 3m of readable route depth and a destination that is not a flat rectangle.

## Collision Audit Findings

I ran a temporary headless collision scan against `scenes/main.tscn`. It found 429 enabled `CollisionShape3D` nodes. Several hits are expected, such as inspect volumes, but there are concerning route and spawn overlaps.

Notable audit output:

- `Spawn` at `(-20, 1.2, -6)` intersects a range-cover/body collision at `(-20, 0.7, -6)` size `(4.5, 1.4, 0.6)`.
- `Customs` point intersects the `HabBlock` collision at `(-3.0, 1.5, 11.9)` size `(8.0, 3.0, 6.0)`.
- `Speeders` point intersects a hab block collision at `(9.0, 1.5, -19.4)` size `(8.0, 3.0, 6.0)`.
- `TransportDepot` point intersects a hab block collision at `(9.0, 1.5, 10.9)` size `(8.0, 3.0, 6.0)`.
- Large route-adjacent collisions were also reported for the control tower/hab block area.

Some hits on `Inspect_*` volumes are intentional interaction areas, but they are currently indistinguishable from blocking geometry in tests. That is a problem by itself.

Required fixes:

- Separate interact/inspect volumes from blocking collision using metadata, layers, or groups.
- Add a collision audit smoke that fails when player route probes intersect blocking collision.
- Do not count inspect trigger overlaps as blocker failures, but do require them to be explicitly tagged.
- Move the player spawn or range cover so the spawn probe is not inside geometry.
- For each room front, define a `RouteProbe_*` point and assert a player capsule can stand there.

Minimum route probes:

- `RouteProbe_Spawn`
- `RouteProbe_Bay94Entrance`
- `RouteProbe_Bay94Pit`
- `RouteProbe_CustomsFront`
- `RouteProbe_SpeedersFront`
- `RouteProbe_TransportDepotFront`
- `RouteProbe_ControlTowerFront`
- `RouteProbe_DockingBay86Front`
- `RouteProbe_DockingBay87Front`
- `RouteProbe_CantinaExterior`
- `RouteProbe_CantinaEntrance`
- `RouteProbe_CantinaBar`
- `RouteProbe_CantinaBackRoom`

Each should test a capsule roughly matching the player controller, not a point.

## Grounding Fix Is Not Yet Proven

`WorldBuilder.place_model()` now computes mesh AABBs and offsets non-hover imports. This is good direction, but still too loose:

- Hover detection is based on path strings such as `"craft"`, `"ship"`, and `"speeder"`.
- There is no per-asset placement metadata.
- There is no smoke proving non-hover imported props are within tolerance of their support plane.
- There is no visual/collision comparison proving a grounded visual does not sit above or below its blocking collision.

Required fix:

- Move hover/grounded policy into manifest data, not path heuristics.
- Add per-model `bottom_offset`, `hover_height`, `collision_radius`, and `visual_scale`.
- Add a grounding smoke that traverses default Mos Eisley and reports non-hover asset bottom deltas.

## Test Gaps

`world_builder_smoke.gd` still mostly checks:

- labels hidden
- inspectable count
- JSON parses
- node count determinism
- helper returns a body

That does not test release playability.

`landmark_builder_smoke.gd` now checks capture point existence, but it still does not prove:

- capture points are not inside collision
- route capsules fit
- imported props are grounded
- the back hallway has navigable depth
- Spaceport Row has any screenshot coverage

Required tests:

- `world_capture_points_smoke.gd`: all named full-area capture points exist and have `look_at_pos`/expected-visible metadata.
- `world_collision_route_smoke.gd`: player capsule fits at all route probes.
- `world_grounding_smoke.gd`: non-hover imported assets are grounded within tolerance.
- `world_visual_capture_smoke.gd`: visual runner captures full-area screenshots and fails on wall/floor/sky-dominant frames.
- `world_inspect_volume_smoke.gd`: inspect volumes are tagged separately from blocking collision.

## Direction For Antigravity

Stop saying "playspace fixed." Say "cantina evidence improved; full-area proof pending."

Next pass should be:

1. Add capture/probe points across the whole Spaceport Row area.
2. Add collision-layer or metadata separation for blocking geometry vs inspect triggers.
3. Move spawn or range cover so the player does not spawn inside collision.
4. Validate all room-front route probes with a player capsule.
5. Add full-area screenshots, not just cantina screenshots.
6. Fix the current cantina exterior doorway blocker and the bad back hallway composition.
7. Replace path-string hover detection with manifest-driven placement policy.

Release-worthy means the whole slice can be walked, read, and trusted. The latest pass is faster than it is thorough.
