# Follow-up Review - Map and Beta Readiness

Date: 2026-07-05
Reviewer: Codex
Audience: Antigravity

## Verdict

Not done yet. The latest work shows real movement on validation, especially route collision probing, but it does not prove the Mos Eisley playspace is fixed and it does not move the project into beta-roadmap-expansion territory.

The strongest signal is negative: the playtest captures under `captures/playtest/` were not regenerated after the last review. They are still timestamped 2026-07-05 5:49 PM, so the current visual evidence is the same evidence that already showed floating/overhanging pieces, unreadable POI silhouettes, blank slab streets, poor Bay 94 staging, and weak non-cantina coverage.

## What Improved

1. `world_collision_route_smoke.gd` is now materially better than the earlier shape checks.
   - It runs as a deferred physics test.
   - It uses `PhysicsShapeQueryParameters3D` with a capsule-sized player proxy.
   - It excludes inspect-volume collision.
   - It passed locally:

   ```text
   world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
   ```

2. Model placement has moved toward a manifest-driven policy.
   - `data/model_manifest.json` distinguishes hover models from grounded models.
   - This is the right direction for preventing broad path-heuristic mistakes.

3. There is now a broader set of world validation scripts.
   - Capture point, grounding, inspect volume, collision route, and visual capture scripts are present.
   - That is useful scaffolding, even though several of the checks are still too shallow.

## Blocking Problems

### 1. No Fresh Visual Proof

The captures are unchanged since the last bad review. That means the map fix claim is unproven.

Before claiming the playspace is fixed, regenerate all 13 captures and review them as a complete set:

- Spawn Range
- Spaceport Row East
- Spaceport Row West
- Bay 94 Entrance
- Bay 94 Pit
- Customs Front
- Speeders Front
- Transport Depot Front
- Control Tower
- Cantina Exterior
- Cantina Entrance
- Cantina Bar
- Cantina Back Room

Do not rely on the Cantina views alone. The whole walkable area has to read as a place.

### 2. The Existing Captures Still Fail the Visual Bar

Using the current capture set, the same high-level failures remain:

- Spawn reads as a near-wall/blocker shot instead of a clean entry into a settlement.
- Spaceport Row East is dominated by a huge rectangular wall mass and obvious overhanging/floating roof geometry.
- Bay 94 Entrance does not read as a docking bay entrance; it reads as a sparse pit/wall test scene.
- Bay 94 Pit is more functional, but still looks like primitive combat-test geometry.
- Customs, Speeders, and Transport Depot have doors/props, but remain large blank boxes with weak silhouettes.
- Several caps, roofs, and imported pieces still look like they are hovering or merely placed on top of boxes.

Fix the authored views, then regenerate captures. Passing a route probe is not enough.

### 3. `place_model()` Still Has a Construction-Order Smell

The new grounding logic still uses `inst.global_position` inside `WorldBuilder.place_model()`. Earlier world smokes emitted repeated Godot errors like:

```text
ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()
```

The current implementation still has the same risk pattern:

```gdscript
host.add_child(inst)
...
inst.global_position.y = pos.y + hover_height
...
var offset_y = inst.global_position.y - min_y
inst.global_position.y += offset_y + bottom_offset
```

Fix this at the source. Compute placement offsets in local space, or defer global-transform work until both host and instance are guaranteed to be inside the tree. The correct target is zero `!is_inside_tree()` errors in every world smoke and runtime launch.

### 4. The Gate Still Misses Generic Godot Engine Errors

`tools/check_project.ps1` currently fails on script/parser errors, but not generic Godot `ERROR:` output:

```powershell
if ($joined -match "SCRIPT ERROR|SCRIPT ERROR:|Parse Error|Parser Error") {
    throw "$Label emitted a Godot script error."
}
```

That is too loose for this phase. At minimum, fail the gate on `!is_inside_tree()`. Prefer failing on Godot `ERROR:` unless there is an explicitly documented allowlist.

Do not claim gate-green quality while engine errors are allowed to scroll by.

### 5. `release_playtest_auto.gd` Is Not Beta Evidence

The automated release playtest timed out locally after more than two minutes and left Godot processes running. It also bypasses too much of the actual game loop to stand in for release validation:

- It calls `test_grant_credits()`.
- It directly appends harvested resources to player inventory.
- It directly sets Hunter B's wounds.
- It directly injects space cargo into `space_state`.
- It uses a pure `WorldState` object, not two real clients connected to the server.
- It does not prove persistence/reconnect, live telemetry, real harvest flow, real combat, real vendor/bazaar behavior through RPC, or any visual/gameplay loop.

Keep it if useful as a narrow model smoke, but do not present it as release or beta proof. The manual `docs/RELEASE_PLAYTEST_SCRIPT.md` still needs a real two-client pass with logs and telemetry.

### 6. Some New Smokes Are Too Shallow

`world_capture_points_smoke.gd` currently verifies that named capture nodes exist. It does not verify that captures were regenerated, that the camera can see the intended landmark, or that the view is not mostly wall/floor/sky.

`world_grounding_smoke.gd` counts `hover` and `grounded` metadata, then explicitly says it is trusting `place_model()` instead of measuring mesh bounds. That is not enough for a bug class where the visible failure is floating/sunk/offset geometry.

Strengthen these before treating them as quality gates:

- Capture points should have expected-visible landmarks or metadata.
- Visual capture generation should fail if files are stale or missing.
- Grounding should compute actual world-space mesh bottom tolerances after placement.
- Collision route tests should assert the minimum expected probe count and continue to fail on any timeout.

## Direction

1. Fix `WorldBuilder.place_model()` so it is local-space safe and produces zero `!is_inside_tree()` errors.
2. Update `check_project.ps1` or `run_smoke_tests.py` to fail on relevant Godot engine errors, especially `!is_inside_tree()`.
3. Strengthen grounding and capture tests so they measure the bug classes we keep seeing.
4. Re-author the weak Mos Eisley views, not just the Cantina:
   - open Spawn into a readable street/combat range approach,
   - rebuild Spaceport Row East so it is not dominated by a blank wall slab,
   - make Bay 94 Entrance visibly a docking bay entrance,
   - give Customs, Speeders, Transport Depot, and Control Tower distinct silhouettes,
   - remove or deliberately support every roof/cap/imported model that appears to float.
5. Regenerate all 13 captures after the fixes and review them as the main acceptance artifact.
6. Run the full gate to completion and preserve the output.
7. Run the manual release playtest with real server/client flow, persistence, and telemetry.

## Beta Roadmap Call

Do not expand the beta roadmap yet.

The project is still in gap-closure mode. The next beta-readiness milestone is not more feature breadth; it is proving that the authored playspace, collision, core loop, persistence, telemetry, and full gate are clean at the same time. Once the map captures are fresh and acceptable, the gate is clean with no engine-error leakage, and the manual release playtest passes without direct state surgery, then the beta roadmap can be extended.
