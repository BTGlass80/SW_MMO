# Map And Beta Done Review - 2026-07-05

Verdict: no. Antigravity is not done with either the map or the road to beta.

There has been real progress since the last review: the capture set expanded from four cantina screenshots to thirteen full-area screenshots; new smoke tests exist for capture points, route collision, grounding, and inspect volumes; imported model placement now has a manifest concept; and `docs/RELEASE_PLAYTEST_SCRIPT.md` gives a useful manual validation path.

That is movement. It is not completion.

## Map Status

The map is no longer only a cantina proof, but the new full-area captures still show a blockout-level playspace.

Reviewed fresh captures from `captures/playtest/`, generated at 5:49 PM:

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

### Blocking Visual Issues

1. `playtest_01_spawn_range.png` fails as a spawn proof.

   The shot is dominated by close wall/near geometry. It does not establish a readable starting area, immediate route, or first-player orientation.

2. `playtest_02_spaceport_row_east.png` fails as a street proof.

   A giant rectangular wall blocks the left half of the frame. A roof/overhang floats or detaches visibly at upper right. The street has no convincing Mos Eisley identity beyond tan boxes and yellow edge strips.

3. `playtest_03_spaceport_row_west.png` is more readable, but still blockout.

   It shows an open route, but the buildings are blank slabs and there is a stranded capsule/object near the wall. It is not a finished playspace read.

4. `playtest_04_bay94_entrance.png` does not read as an entrance.

   It is mostly empty pit wall/floor, a lamp, and crates. It does not communicate a threshold, service flow, landing-bay identity, or route into gameplay.

5. `playtest_05_bay94_pit.png` is functionally understandable but still crude.

   It shows the range/training use case, but foreground cover blocks the lower frame and the whole area is still rectangular test geometry.

6. Customs, Speeders, and Transport Depot are still prop-front facades.

   The captures show doors and some props, but also floating/overhanging roof caps, flat boxes, and weak identity. They are not release-worthy POIs yet.

7. The cantina is improved but not done.

   The bar is the strongest visual now. The exterior, entrance, and back room still need composition, occlusion, ceiling/wall cleanup, and more believable pathing.

## Collision And Validation Status

Not done.

New smokes exist, but they are not strict enough and they are not clean.

Targeted smoke runs:

- `world_capture_points_smoke.gd` exited OK and found 13 capture points.
- `world_grounding_smoke.gd` exited OK and reported 4 hover / 33 grounded models.
- `world_inspect_volume_smoke.gd` exited OK and found 8 inspect volumes.
- `world_collision_route_smoke.gd` timed out during the parallel run.

However, the OK smokes spammed many Godot engine errors:

```text
ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()
```

The backtrace points into `scripts/world/world_builder.gd` `place_model()`, especially around imported model placement/grounding. A done claim cannot sit on tests that emit repeated engine errors and still pass.

### Specific Test Weaknesses

1. `world_capture_points_smoke.gd` only proves point names exist.

   It does not prove the capture sees the intended landmark, avoids walls, avoids clipped geometry, or produces a reviewable composition.

2. `visual_playtest_runner.gd` only rejects nearly flat images.

   This is too weak. A bad frame with one wall, one prop, and a strip of sky passes. Several current captures are bad but not mathematically flat.

3. `world_collision_route_smoke.gd` uses rough AABB checks and timed out in review.

   It needs to be deterministic, fast, and stricter. Route probes should be tested with a player capsule against blocking collision only.

4. Inspect volumes are now tagged, which is good, but the route/collision tests still need to prove that interact volumes cannot mask blocking-geometry failures.

5. `place_model()` still has construction-order problems.

   It reads global transforms while nodes are not reliably inside tree, producing engine errors. Fix construction order or compute local recursive AABBs without touching global transforms until the node is safely parented and processed.

## Road To Beta Status

Not done, and do not expand the beta roadmap yet.

The repo’s own current docs still say this is pre-beta/private alpha:

- `docs/KNOWN_ISSUES.md` calls the build a `pre-beta/private alpha release candidate`.
- `docs/RELEASE_PLAYTEST_SCRIPT.md` is a script to validate three core stories, not proof they passed.
- Prior Antigravity guidance already says beta requires repeatable player dependency loops, not only feature checkboxes.

The current beta-road issue is not lack of roadmap. It is lack of accepted evidence.

Before beta language, Antigravity needs to show:

1. Full gate completed cleanly.

   I attempted `tools/check_project.ps1` with the Godot 4.6.3 console binary. It did not finish inside a four-minute review window. That is not a pass.

2. Manual release playtest completed.

   Run `docs/RELEASE_PLAYTEST_SCRIPT.md` with two visible clients and record pass/fail notes. The script covers first-hour onboarding, player economy, space cargo, persistence/reconnect, and telemetry.

3. No script/runtime error spam in new world smokes.

   The `!is_inside_tree()` spam must be fixed or promoted to test failure. A clean smoke should be clean.

4. Map screenshots must pass human review.

   Current full-area captures are not release-worthy. A visual runner can help, but a bad screenshot that passes a variance threshold is still bad.

5. Collision route validation must be reliable.

   Route probes need a real player capsule check and must prove spawn, Spaceport Row, Bay 94, customs, speeders, depot, control tower, cantina exterior, cantina interior, and back room are walkable without stray blockers.

6. Beta loop evidence must be end-to-end.

   The bar is not "bazaar exists" or "space cargo exists." The bar is: two players can create characters, buy/equip, fight, harvest, craft an item instance, list it, buy it, use it, launch, salvage cargo, land, pay fees, persist/reconnect, and produce telemetry with known faucets/sinks.

## Direction To Antigravity

Do not declare done. Do not expand the beta roadmap.

Next work order:

1. Fix `WorldBuilder.place_model()` so it produces no `!is_inside_tree()` errors.
2. Make check_project finish cleanly and capture the full output.
3. Strengthen `world_collision_route_smoke.gd` so it runs fast and fails on player-capsule overlap with blocking collision.
4. Upgrade `visual_playtest_runner.gd` beyond flat-image checks:
   - reject near-wall-dominant images
   - reject sky/floor-dominant images
   - require expected landmark visibility by capture metadata
   - require current timestamp and nonzero file size for every image
5. Rework the weak map areas:
   - spawn/range first view
   - Spaceport Row east/west wall dominance and floating roof/cap issues
   - Bay 94 entrance identity
   - customs/speeders/depot facade detail and grounding
   - cantina exterior threshold and back room
6. Run the manual release playtest script with two visible clients.
7. Log every deviation either as a blocker or a known issue with a real workaround.

## Acceptance Bar

Antigravity can say the map is done when:

- all 13 screenshots are readable and reviewable
- no floating/stray geometry is visible
- no default-play debug labels or test scaffolds appear
- route probes pass with a player capsule
- inspect volumes are separate from blocking collision
- the full gate completes cleanly

Antigravity can say the road to beta is ready to expand when:

- the private alpha/release-candidate script passes end-to-end with two clients
- economy telemetry balances known faucets and sinks
- persistence/reconnect preserves the story outcomes
- no admin/test affordance is required for normal player flows
- remaining issues are documented and genuinely non-blocking

Until then, this is still hardening work.
