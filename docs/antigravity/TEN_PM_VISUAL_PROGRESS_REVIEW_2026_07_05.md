# 9:54 PM Visual Progress Review

Date: 2026-07-05
Reviewer: Codex
Latest checked commit: `00a42b5` (`Address BETA_STATUS_FEEDBACK_2026_07_05: Fix commands, routing, tests, RPC proofs`)

## Verdict

Progress, but not visual acceptance.

The technical gate is still green:

```text
world_grounding_smoke: OK - Verified grounding metadata: 1 hover, 35 grounded models
world_collision_route_smoke: OK - Checked 13 probes against blocking geometry
world_capture_points_smoke: OK - Found 13 capture points
All 143 smoke tests completed successfully.
Wired GDScript smokes run: 143 | RPC surface (@rpc in network_manager.gd): 82
All checks passed.
```

The 9:54 PM capture set is a better direction than 9:28 PM in two specific ways:

- `Spaceport Row East` is finally more open and street-like instead of being a pure blank-wall shot.
- `Spawn Range` is more coherent as a range than the previous view, though it still has debug text and box clutter.

That said, this is still not release-quality. The map is no longer failing only because of wall slabs; it is now failing because the replacement motif looks artificial and repeated.

## Main New Issue: Repeated Totem Columns

The new stacked gray/brown column props appear in multiple capture views and become the main visual subject:

- `Spaceport Row East`
- `Spaceport Row West`
- `Customs Front`
- `Transport Depot Front`

They read like debug block stacks or collision markers, not Star Wars street set dressing. Because they repeat with the same silhouette and material bands, they make the area feel procedural rather than authored.

Fix:

- Keep at most one or two if they are intended as utility posts, and give them clear purpose.
- Vary silhouette, height, material, and placement.
- Convert some into actual in-world objects: moisture vaporators, scanner pylons, comms poles, market posts, cargo loaders, power boxes.
- Do not put one in the center of a capture unless it is the intended landmark.

## View-by-View Notes

### Spawn Range

Improved. The view now reads more like a firing range/combat lane. Still not accepted:

- `READY` debug/status text is visible.
- The area still relies heavily on block stacks and flat gray floor.
- The right-side wall and tower mass still crowd the frame.

Fix:

- Remove debug/status text from release captures.
- Make the central range objects read as targets, cover, or training equipment.
- Add one strong exit/arrival cue toward the settlement.

### Spaceport Row East

Meaningfully improved. This is the first east-row capture that reads like a street view rather than a wall face.

Remaining blockers:

- The long tan wall across the midground is still too plain.
- The repeated stacked columns on both sides look artificial.
- The red horizontal accent on the left reads like a floating UI stripe or placeholder more than signage.

Fix:

- Break the midground wall with doorways, niches, pipes, vents, shade frames, or small shop fronts.
- Replace repeated stacked columns with varied utility/street props.
- Make red accents become physical signs, awnings, or painted panels with supports.

### Spaceport Row West

Still weaker than East. The paired stacked columns dominate the foreground and make the street feel like a symmetrical test lane.

Fix:

- Remove the mirrored-column feel.
- Place asymmetrical foreground details with clear in-world jobs.
- Keep the street axis open.

### Bay 94 Entrance

Still improved from earlier passes. It has a recognizable threshold and stronger bay-face language.

Remaining blockers:

- It still leans on large flat walls and a generic dark door.
- The foreground crate/lamp cluster is blocking a clean read.

Fix:

- Add a bay number/signage, service conduits, side panels, and landing-bay wear.
- Shift foreground clutter so the entrance reads first.

### Bay 94 Pit

Readable as a combat space, still not a convincing docking bay.

Fix:

- Convert generic block stacks into cargo/service infrastructure.
- Add ship-bay context and less test-arena symmetry.

### Customs / Transport / Speeders / Control Tower

Mostly unchanged from the prior pass. The important correction is that the worst white occluders are gone. The remaining issue is identity:

- Customs needs checkpoint/scanner/inspection language.
- Speeders needs the speeder/service bay to be the subject, not wall/beam geometry.
- Transport needs route-board/dispatcher/cargo-pickup language.
- Control Tower needs a cleaner frame and base infrastructure.

### Cantina

Still the visual benchmark. Keep using it as the minimum quality standard for authored POIs.

## Direction

Do not restart the map. Do not broaden features. Do one focused polish pass:

1. Remove or redesign the repeated stacked-column props.
2. Remove debug/status text from capture views.
3. Keep the improved `Spaceport Row East` camera openness, but break up the long midground wall.
4. Re-stage `Spaceport Row West` so it is not a mirrored column corridor.
5. Push `Bay 94 Entrance` one step further with actual bay identity: number, signage, conduits, panels, and grounded service props.
6. Regenerate all 13 captures.
7. Rerun `tools/check_project.ps1`.

## Beta Roadmap Call

Still no beta roadmap expansion.

The project is now in a better place technically and incrementally improving visually, but beta should wait until a capture set is accepted without major caveats. The next milestone is still visual acceptance of the existing Mos Eisley slice, not feature expansion.
