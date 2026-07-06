# 10:54 PM Visual Regression Review

Date: 2026-07-05
Reviewer: Codex
Latest checked state: clean worktree, 10:54 PM capture set

## Verdict

The repo is clean and the technical gate is still green. The latest visual pass regressed Bay 94 and still is not accepted.

Validation checked locally:

```text
world_grounding_smoke: OK - Verified grounding metadata: 1 hover, 47 grounded models
world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
world_capture_points_smoke: OK - Found 13 capture points
All 143 smoke tests completed successfully.
Wired GDScript smokes run: 143 | RPC surface (@rpc in network_manager.gd): 82
All checks passed.
```

The clean worktree is good. The extra grounded-prop count indicates the set dressing grew. But the new capture set did not clear the visual bar.

## What Improved

- Spaceport Row East still reads more like an actual street than the earlier blank-wall versions.
- Spaceport Row West is more open than the worst earlier versions.
- The repo is no longer littered with root scratch files.
- The full gate remains stable.

## What Regressed

### Bay 94 Entrance

This is the clearest regression. The bright white block/panel shapes are back in the background, and the foreground red/yellow block cluster is louder than before. The shot now reads less like docking-bay infrastructure and more like a debug/test composition.

Fix:

- Remove or material the white panel/block shapes.
- Replace the red/yellow cube stack with believable service equipment.
- Keep hazard color only as stripes, decals, supported signs, or panel accents.
- Add bay identity: bay number, wall panels, conduits, service pipes, cargo sleds, fuel coupling.

### Bay 94 Pit

The pit also regressed visually. It has visible white panel clusters, the red/yellow test colors are prominent, and the centered NPC/box layout still reads as a test arena.

Fix:

- Remove debug-looking white panels.
- Convert the bright blocks into grounded bay props.
- Rebuild cover as cargo/service infrastructure, not cubes.

## Remaining Blockers

### Debug / Status Text

The `READY` style debug/status text still appears in the capture set. This has been called out repeatedly and should be removed from capture output.

### Spawn Range

Spawn is more coherent than the worst versions, but still too much like a boxy test range. It needs to look like an intentionally authored starter/combat space, not just a place where targets and crates were placed.

### Spaceport Row

East and West are improved but still sparse. The long walls need street-level detail and purpose:

- recessed doors,
- awnings,
- pipes,
- vents,
- small market/service hatches,
- signs mounted with supports,
- grounded props that are not repeated block columns.

### Non-Cantina POIs

Customs, Speeders, Transport Depot, and Control Tower still trail the Cantina exterior. They need sharper identity before the map can be called release-worthy.

## Direction

Do not broaden. Do not add new systems. Do not churn the whole map.

Next pass should be only:

1. Remove debug/status text from captures.
2. Fix Bay 94 Entrance and Bay 94 Pit regressions.
3. Material or remove every white block/panel visible in the Bay 94 captures.
4. Replace red/yellow cube stacks with bay infrastructure.
5. Keep Spaceport Row's improved openness and add only small street-level detail.
6. Regenerate all 13 captures.
7. Rerun `tools/check_project.ps1`.

## Beta Roadmap Call

Still no beta roadmap expansion.

Technical validation is healthy, but visual acceptance is still blocked. The project should not move from gap closure to beta expansion until one capture set passes without debug text, white test panels, or blockout-looking Bay 94 props.
