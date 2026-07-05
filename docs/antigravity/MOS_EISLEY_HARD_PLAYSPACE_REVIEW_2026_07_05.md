# Mos Eisley Hard Playspace Review - 2026-07-05

Verdict: mild geometry improvement, still not release-worthy. The scene now has more authored pieces, but the playspace is still failing at the fundamentals: grounding, scale, occlusion, camera proof, and readable composition. Do not broaden features and do not expand the roadmap from this state.

Evidence reviewed:

- `captures/playtest/playtest_1_outside.png`
- `captures/playtest/playtest_2_inside_entrance.png`
- `captures/playtest/playtest_3_inside_bar.png`
- `captures/playtest/playtest_4_back_hallway.png`
- `scripts/world/landmark_builder.gd`
- `scripts/world/world_builder.gd`
- `data/mos_eisley_props.json`
- `data/mos_eisley_spaceport_row.json`
- `scripts/tests/visual_playtest_runner.gd`
- `scripts/tests/landmark_builder_smoke.gd`

## Main Diagnosis

Antigravity is adding visible objects, but the world still lacks a placement contract. Every authored object needs to answer the same questions:

- What surface is it standing on?
- What is its bottom point after scale/import?
- What is its collision footprint?
- Can a 1.7m player camera see it without clipping into it?
- Does it improve a route, silhouette, encounter, or landmark read?

Right now many objects are placed by raw origin and hope. That is why things float, sink, clip, or block the entire frame.

## Specific Failures And Fixes

### 1. Floating and sinking props across the playspace

Observed:

- Floating/suspended pieces are visible around the exterior and in the cantina.
- Imported models are placed with raw `inst.position = pos` and `inst.scale = Vector3.ONE * model_scale` in `WorldBuilder.place_model()`. There is no bounding-box normalization.
- `data/mos_eisley_props.json` mixes y-values as if some assets are base-origin and others center-origin: barrels at `y: 0.0`, crates at `y: 0.5` and `1.5`, ships at `y: 0.45`/`0.55`. Without measuring each imported scene's actual bottom, this will always drift.
- Generated building pieces are instantiated into hab blocks and towers without bottom/footprint validation. `desert_doorway.tscn`, `dome_cap.tscn`, `moisture_vaporator.tscn`, and `landing_pad_light.tscn` need the same treatment as GLBs.

Required fix:

- Add one placement helper for every imported visual scene: instantiate, compute recursive visual AABB, scale, then offset the instance so `global_bottom_y == target_floor_y`.
- Store per-model placement metadata in `data/runtime_asset_manifest.json` or a small `data/asset_placement_overrides.json`: `grounded`, `hover`, `bottom_offset`, `collision_radius`, `display_scale`, `yaw_offset`.
- Replace direct `place_model()` calls with `place_grounded_model(host, path, ground_pos, rot_deg, scale, placement_key)`.
- Only ships/speeders may hover, and they must declare `hover_height`. Everything else should fail validation if its bottom is more than about `0.05m` above or below its intended support.

Acceptance:

- Add a smoke that traverses default Mos Eisley and fails on non-hover meshes whose recursive visual bottom is outside `[-0.05, +0.05]` of their support plane.
- The smoke should whitelist intentional pits/floors/hovercraft by name or metadata, not by broad node type.

### 2. Exterior cantina still reads like a toy facade, not a street

Observed in `playtest_1_outside.png`:

- The silhouette is less catastrophic than before, but it still reads as a flat octagonal toy building.
- The entry is dominated by a centered block/pedestal that blocks the doorway read.
- Low walls and props form symmetrical lanes instead of an irregular Mos Eisley street.
- The huge glowing band over the entrance is louder than the building shape.
- NPC labels are visible and damage immersion.
- The ground is still a broad, undifferentiated tan plane.

Code causes:

- `LandmarkBuilder._build_plaza_floor()` still creates a large slab: `Vector3(45, 0.1, 35)`.
- `LandmarkBuilder._build_main_cantina()` uses a 12m-radius dome with simple octagonal wall segments; the low segment count is fine stylistically, but the facade needs surrounding mass and shadow.
- The entry prop/vestibule composition is centered in front of the door rather than building a readable route.

Required fix:

- Stop presenting the cantina as an isolated object in a plaza. Build a tight street corner.
- Replace the centered entry block with side clutter: moisture pipe, low crate stack, wall stains, shallow steps, chipped threshold, and off-axis sign.
- Break symmetry. Put one adjacent structure close to the left front, one set back on the right, and create an alley edge.
- Reduce the floor slab's visual dominance. Use smaller overlapping ground patches, dusty curb strips, and darker contact shadows under walls/props.
- Gate or hide all NPC/name labels for visual captures unless explicitly testing debug labels.

Acceptance:

- Exterior capture must show a navigable entrance, at least one alley/side-building relationship, and no centered prop blocking the door.
- At player height, the frame should have foreground, midground, and background. Not just a dome on a flat plane.

### 3. Entrance capture is completely invalid

Observed in `playtest_2_inside_entrance.png`:

- The screenshot is a full tan wall. It proves the camera is inside or directly behind occluding geometry.
- This is a blocker because it means the visual runner can produce "completed successfully" while one of the core shots is unusable.

Code causes:

- `visual_playtest_runner.gd` places the camera at `Vector3(65.0, 2.2, 10.5)` and looks at `Vector3(65.0, 1.8, 5.0)`.
- `LandmarkBuilder._build_interior()` places a solid vestibule reveal wall at `Vector3(0, 2.0, 9.0)` with size `Vector3(6.0, 4.0, 0.5)`, directly in the entrance sightline.
- The capture runner does not assert that the image contains meaningful visible geometry or that the camera is not inside/against collision.

Required fix:

- Move the reveal wall off-axis and make it an L-shaped screen, not a full-frame blocker. It should guide the player around a corner, not occlude the entire room.
- Add a short threshold corridor with side walls, floor variation, and a visible route around the reveal.
- Add a camera probe before every capture: raycast/sphere-check the camera location and fail if it overlaps collision or if a near-plane wall fills the image.
- Add an image sanity check: fail any capture whose center 70 percent is nearly one flat color.

Acceptance:

- Entrance capture must show a door threshold, route into the cantina, one interior landmark, and at least one side wall. A flat tan frame is automatic failure.

### 4. Interior bar is readable but still badly composed

Observed in `playtest_3_inside_bar.png`:

- The center bar finally reads as a bar, but the camera is partly occluded by oversized counter slabs.
- NPC labels still float over patrons.
- The roof/dome edge produces hard visual clipping bands and outside sky leaks.
- The bandstand/instruments look like stacked blocks rather than a stage.
- Booths and tables are placed by ring math, not by playable path or sightline.

Code causes:

- Bar segments in `_build_interior()` are big rectangular blocks around the camera path.
- Booths are placed around a 10m radius ring and tables around a 5.5m radius ring, with global random jitter.
- `_build_interior()` still uses global `randf_range()` for table position and rotation, despite the builder claiming deterministic seeded RNG.
- The dome/wall assembly is purely additive, so the interior shell does not control ceiling/wall openings cleanly.

Required fix:

- Create an explicit interior floor plan before adding props: entrance zone, service bar, patron route loop, booths, stage, back corridor.
- Reserve a 1.4m minimum clear walking path from entrance to bar to booths to exit.
- Lower and thin the counter top near camera-facing edges; avoid foreground slabs filling the lower third of the frame.
- Replace ring-spawned booths with authored booth alcoves against walls, each with a back wall, bench, table, and readable opening.
- Remove global RNG. Pass the seeded RNG into `_build_interior()` and use it for all jitter.
- Hide name labels in release captures, or make visual captures explicitly use a no-label mode.

Acceptance:

- Add a test that samples named camera points inside the cantina and fails if a collision/body intersects the camera sphere.
- Add a deterministic smoke that compares transforms of named `TableGrp`, `Booth`, `Bandstand`, and bar nodes, not just mesh counts.

### 5. Back hallway/right alcove capture is also invalid

Observed in `playtest_4_back_hallway.png`:

- The shot is mostly wall slabs and clipping. It does not demonstrate a hallway, an alcove, or a playable route.
- The right edge shows a partial object, but the frame is dominated by near-plane geometry.

Code causes:

- The capture runner calls this "right alcove" but aims at `Vector3(65.0 + 14.0, 2.0, -5.0)` from `Vector3(65.0 + 8.0, 2.2, -3.0)`, which is apparently too close to the hut/wall/booth mass.
- There is no authored back hallway. There are flanking huts and perimeter pieces, but the interior does not have a coherent corridor/alcove route.

Required fix:

- Do not call it a hallway until there is a hallway. Build one explicitly.
- Add a back-room connector with floor strip, two side walls, ceiling/arch silhouette, and a clear destination: office, storage alcove, private booth, or kitchen/service area.
- Move camera points onto validated path nodes, not hard-coded guessed coordinates.
- Add visible route markers in debug only: `CapturePoint_Entrance`, `CapturePoint_Bar`, `CapturePoint_Alcove`, `CapturePoint_Exterior`.

Acceptance:

- The back-room capture must show a readable corridor/alcove with at least 3m of visible depth. Near-plane wall fill is automatic failure.

### 6. Spaceport Row still has placement and composition risks

Observed from code/data:

- Room data has useful structure, but the builder converts it into generic hab blocks and walled pads with hard-coded offsets.
- `_build_from_rooms()` ignores `scene_position.y` and uses `Vector3(x, 0.0, z)` for layout. That is okay only if y means inspection height, but this must be documented and consistently named.
- Hab block doorways and dome caps are attached by local guesses. They need asset placement metadata.
- Landing pad details are all block boxes; there is no pass ensuring ramps, doorframes, lights, and ships align with the floor.

Required fix:

- Treat `mos_eisley_spaceport_row.json` as layout data, then add a placement validation pass after build.
- Rename ambiguous position fields or document that `scene_position.y` is not a visual y-position.
- Add room-specific composition rules: customs office should face street, transport depot should have seating/terminal silhouettes, speeder shop should have repair clutter, bays should have ramps and sunken floors that are visibly navigable.
- For every room, add at least one validated capture/probe point with a title and expected visible landmark.

Acceptance:

- Add a `world_builder_grounding_smoke.gd` and a `world_builder_capture_points_smoke.gd`.
- A reviewer should be able to walk from spawn to Bay 94, customs, speeders, transport depot, and cantina without seeing floating props, debug labels, or wall-filled views.

## Test And Tooling Changes Required

1. Make `visual_playtest_runner.gd` fail on bad screenshots.
   - `_save_capture()` should return `bool`.
   - `_run()` should count failures and `quit(1)` if any capture fails.
   - Fail if the image is null, save fails, file size is too small, or the image is mostly one color.

2. Replace guessed camera coordinates with authored capture markers.
   - Add invisible `CapturePoint_*` nodes or metadata in the builder.
   - Each point has `position`, `look_at`, `min_visible_colors`, and `max_center_flatness`.

3. Add grounding validation.
   - Any imported model must declare `grounded` or `hover`.
   - Traverse recursive AABB after scaling.
   - Fail non-hover assets with bottoms outside tolerance.

4. Add camera collision validation.
   - Use a capsule/sphere approximating a player camera at every capture point.
   - Fail if inside collision or if the first raycast hit is less than a small threshold in front of the camera.

5. Add transform determinism validation.
   - Compare node names, global transforms, and material/color keys for meaningful landmark nodes across two builds with the same seed.
   - Mesh count alone is not determinism.

## Concrete Work Order

Do this in order:

1. Fix visual runner failure behavior and add flat-image detection.
2. Hide all release-visible NPC/location labels in visual captures.
3. Add grounded placement helper and convert `place_model()`, generated doorways, vaporators, dome caps, landing pad lights, and JSON props.
4. Rebuild the cantina entrance: remove the centered blocker, move the reveal wall off-axis, and add a clear threshold route.
5. Recompose the cantina exterior as a street corner, not a plaza object.
6. Rebuild interior layout around player paths: entrance, bar, booths, stage, back route.
7. Add actual back hallway/alcove geometry before capturing it.
8. Add grounding, camera, and transform-determinism smokes.
9. Produce fresh captures and review them before adding anything else.

## Stop Conditions

Antigravity should stop and ask for review before proceeding if any of these are true:

- A capture is mostly a wall, floor, or sky.
- Any default-play screenshot has floating labels.
- Any non-hover prop visibly floats or sinks.
- The camera clips into geometry.
- A new object is placed by raw y-origin without grounding metadata.
- A new test only counts nodes where the failure is visual placement, scale, or composition.

The bar for release-worthy Mos Eisley is not "more pieces exist." It is: the player can walk through a coherent, grounded, readable, Clone Wars-era Mos Eisley slice without debug scaffolding, floating assets, wall-filled cameras, or toy-scale plaza composition.
