# 10:06 PM Visual Pass Review

Date: 2026-07-05
Reviewer: Codex
Latest checked commit: `00a42b5` (`Address BETA_STATUS_FEEDBACK_2026_07_05: Fix commands, routing, tests, RPC proofs`)

## Verdict

Another incremental improvement. Still not visual acceptance.

The technical gate remains green:

```text
world_grounding_smoke: OK - Verified grounding metadata: 1 hover, 35 grounded models
world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
world_capture_points_smoke: OK - Found 13 capture points
All 143 smoke tests completed successfully.
Wired GDScript smokes run: 143 | RPC surface (@rpc in network_manager.gd): 82
All checks passed.
```

The 10:06 PM capture set is better than 9:54 PM in the target area:

- `Spaceport Row East` is cleaner. The repeated totem-column problem is reduced and the shot now reads more like a route through town.
- `Spaceport Row West` is more open and less dominated by mirrored columns.
- The worst white-material and giant foreground occluder problems remain gone.

But this is not release-ready. The remaining blockers are now more specific and smaller: debug text, artificial color blocks, weak POI identity, and Bay 94 foreground noise.

## Remaining Blockers

### Debug / Status Text

`READY` text is still visible in `Spawn Range` and `Bay94 Pit`. A release capture cannot show debug/status text.

Fix:

- Hide debug/status labels for playtest capture generation.
- If this is target state, render it as an in-world sign or HUD element deliberately, not as floating red debug text.

### Spawn Range

Spawn is more coherent than the previous pass, but still looks like a test range made from boxes. It now has a readable lane, yet the player-facing first read is not polished enough.

Fix:

- Convert the central blocks into recognizable targets, cover, or training apparatus.
- Reduce random crate/block clutter.
- Add an exit/arrival landmark that points toward the town.

### Spaceport Row East

This is now meaningfully improved. Do not throw it away. The remaining issue is that the left wall is still too plain and the red accent on it reads more like a floating stripe than a physical sign.

Fix:

- Keep the street openness.
- Turn the red accent into a supported awning/sign/panel.
- Add small breaks to the long wall: door inset, vents, pipes, alcove, or a recessed vendor hatch.

### Spaceport Row West

Better, but still sparse. The street axis is cleaner, but it lacks enough low-level authored detail to feel like a real MMO place.

Fix:

- Add asymmetrical, grounded props with purpose.
- Avoid reintroducing repeated column/totem forms.
- Put detail near the player's eye line, not only rooflines and distant walls.

### Bay 94 Entrance

The bay face remains identifiable, but the foreground is getting noisy. The red/yellow block cluster near the lamp reads as loud test geometry, not docking-bay equipment.

Fix:

- Replace the bright block cluster with grounded service equipment.
- Keep warning colors, but use them as stripes, hazard paint, panel accents, or supported signage.
- Add bay-number identity and sidewall infrastructure.

### Bay 94 Pit

The pit is readable as combat space, but still not convincing as a docking bay. `READY` text is visible, and the central NPC/box arrangement still feels test-like.

Fix:

- Remove debug text.
- Recast cover as cargo sleds, power couplings, fuel tanks, wall panels, or gantry supports.
- Add one strong bay-context element visible from the combat lane.

### Customs / Speeders / Transport / Control Tower

These are mostly unchanged from the prior pass. They no longer have the worst regressions, but they are not yet at Cantina quality.

Fix:

- Customs: add scanner/inspection identity.
- Speeders: make the speeder/service bay the subject, not the long horizontal slab.
- Transport: add dispatcher/route-board/cargo pickup identity.
- Control Tower: clean the left foreground wall/edge intrusion and keep the tower as the subject.

## Direction

Do one more narrow acceptance pass. Do not broaden features.

1. Remove debug/status text from all captures.
2. Keep `Spaceport Row East`'s open composition and only add wall-break detail.
3. Do not reintroduce repeated totem columns.
4. Replace Bay 94's bright block cluster with real service/docking-bay props.
5. Push Spawn and Bay 94 Pit from "test range" toward "authored training/docking space."
6. Regenerate all 13 captures.
7. Rerun `tools/check_project.ps1`.

## Beta Roadmap Call

Still no beta roadmap expansion.

The visuals are improving in the right direction now, but beta should wait until the capture set passes without obvious debug text, test-block props, or major "this looks like blockout" caveats.
