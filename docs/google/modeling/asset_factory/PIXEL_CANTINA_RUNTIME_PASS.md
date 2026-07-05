# Pixel Cantina Runtime Pass

Date: 2026-07-04  
Scope: docs-only runtime utility proof for semantic pixel room cards

## Purpose

This pass tests whether the layered Cantina pixel-card lane can produce runtime-adjacent data, not just visuals.

The one-variable change from `PIXEL_CANTINA_LAYERED_KIT_PASS.md`:

```text
same floor/detail semantic cards
  -> add walkable mask
  -> add collision mask
  -> add named sockets
  -> resolve sockets to nearby walk cells
  -> render grid-routed path probes
```

## Generated Proof

Review:

```text
generated/godot_pixel_cantina_runtime_v1/REVIEW.md
```

Script:

```text
scripts/godot_pixel_cantina_runtime_proof.gd
```

Manifest:

```text
generated/godot_pixel_cantina_runtime_v1/pixel_cantina_runtime_manifest.json
```

Source masks:

```text
generated/godot_pixel_cantina_runtime_v1/source_images/cantina_floorplan_48x32.png
generated/godot_pixel_cantina_runtime_v1/source_images/cantina_detail_elevation_48x32.png
generated/godot_pixel_cantina_runtime_v1/source_images/cantina_walkable_mask_48x32.png
generated/godot_pixel_cantina_runtime_v1/source_images/cantina_collision_mask_48x32.png
```

Captures:

```text
generated/godot_pixel_cantina_runtime_v1/captures/runtime_collision_nav_overlay.png
generated/godot_pixel_cantina_runtime_v1/captures/runtime_socket_map.png
generated/godot_pixel_cantina_runtime_v1/captures/runtime_actor_path_probe.png
generated/godot_pixel_cantina_runtime_v1/captures/runtime_room_pipeline_composite.png
```

## Runtime Result

Candidate keep.

Key stats:

| Metric | Value |
| --- | ---: |
| Grid size | 48x32 |
| Walkable pixels | 439 |
| Walkable rectangles | 40 |
| Blocker pixels | 527 |
| Collision rectangles/shapes | 38 |
| Socket count | 12 |
| Non-walkable raw sockets | 8 |
| Sockets resolved to walk cells | 8 |
| Actor probe route cells | 10 |
| Composite probe route cells | 25 |
| Walk mask reduction vs pixels | 90.9% |
| Collision reduction vs pixels | 92.8% |

The important result is not the exact pathing algorithm. It is that the same semantic cards now produce:

- visible room geometry;
- source PNG masks;
- merged visual rectangles;
- merged `CollisionShape3D` boxes;
- a walkable mask;
- named semantic sockets;
- resolved walk targets for blocked/table/wall sockets;
- grid-routed actor probes.

That makes this lane credible as a room-production adapter instead of a toy renderer.

## What Worked

- The collision mask merged from 527 blocked pixels to 38 shapes.
- The walk mask merged from 439 pixels to 40 rectangles.
- Raw semantic sockets can stay on tables, signs, walls, or clutter while path targets resolve to nearby walk cells.
- The path probe is now grid-routed over the walk mask instead of drawn as free-angle lines.
- The output is deterministic and cheap: one source card change can regenerate visuals, masks, sockets, and review captures.

## What Still Needs Work

- The generator is still hard-coded. It should read external source PNG/JSON cards next.
- The BFS path probe is proof logic, not final navigation.
- Socket types need a richer schema: seat, stand, use, inspect, spawn, transition, prop, light, cover.
- The collision mask is still coarse; some furniture needs separate interaction/collision layers.
- Debug captures are useful but visually noisy; future reviews should include a clean gameplay preview and a debug overlay.

## Production Role

Use this for room/building/terrain structure:

```text
designer/SW_MUSH room notes
  -> semantic floorplan card
  -> semantic detail/elevation card
  -> runtime masks and sockets
  -> Godot proof
  -> optional Blockbench hero modules placed on sockets
```

This should become the default path for Cantina rooms and similar interiors until a better voxel-native method beats it.

## Next Improvement

Promote the proof into a reusable adapter:

```text
external cards + socket JSON
  -> generated Godot scene
  -> generated collision/walk masks
  -> generated socket manifest
  -> review captures
```

Then run the adapter on a second SW_MUSH Cantina room to prove repeatability.

