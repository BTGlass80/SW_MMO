# Chalmun's Cantina - Back Hallway & Sabacc Room - Voxel Generation Review

Generated: 2026-07-04 17:24:18
Generator: `docs/google/modeling/asset_factory/scripts/godot_pixel_cantina_generator.gd`

## Purpose

Reusable pixel-to-GDScript generator pass for Chalmun's Cantina - Back Hallway & Sabacc Room. Synthesizes geometry, masks, and named sockets.

## Source Images

- Floorplan: `source_images/cantina_floorplan_48x32.png`
- Detail Layout: `source_images/cantina_detail_elevation_48x32.png`
- Walkable Mask: `source_images/cantina_walkable_mask_48x32.png`
- Collision Mask: `source_images/cantina_collision_mask_48x32.png`

## Runtime Stats

| Metric | Value |
| --- | ---: |
| Grid size | `48x32` |
| Walkable pixels | 216 |
| Walkable rectangles | 18 |
| Blocker pixels | 207 |
| Collision rectangles/shapes | 35 |
| Socket count | 8 |
| Non-walkable raw sockets | 7 |
| Sockets resolved to walk cells | 7 |
| Path Route Cells | 4 |
| Composite Route Cells | 0 |
| Walk mask reduction vs pixels | 91.7% |
| Collision reduction vs pixels | 83.1% |

## Named Sockets

| Id | Kind | Raw grid | Walkable | Resolved path grid | Tags |
| --- | --- | --- | --- | --- | --- |
| `hallway_entry` | `spawn` | `5,11` | `true` | `5,11` | `entry, player` |
| `restroom_a` | `transition` | `11,9` | `false` | `11,8` | `restroom, door` |
| `restroom_b` | `transition` | `17,9` | `false` | `17,8` | `restroom, door` |
| `restroom_c` | `transition` | `23,9` | `false` | `23,8` | `restroom, door` |
| `cellar_trapdoor` | `interaction` | `8,11` | `false` | `8,10` | `cellar, floor` |
| `office_door` | `transition` | `30,13` | `false` | `30,12` | `office, door` |
| `sabacc_table` | `social_table` | `37,16` | `false` | `36,16` | `sabacc, seated` |
| `sabacc_light` | `light_socket` | `37,16` | `false` | `36,16` | `sabacc, light` |

## Captures

### runtime_collision_nav_overlay

Walkable rectangles in green and merged collision rectangles in red, generated from the same layered Cantina cards.

![runtime_collision_nav_overlay](captures/runtime_collision_nav_overlay.png)

### runtime_socket_map

Named interaction and spawn sockets generated from the semantic room cards: entrance, bar, booths, service door, lights, and clutter sockets.

![runtime_socket_map](captures/runtime_socket_map.png)

### runtime_actor_path_probe

Grid-routed actor/path probe using nearest-walkable socket resolution and the generated walkable mask.

![runtime_actor_path_probe](captures/runtime_actor_path_probe.png)

### runtime_room_pipeline_composite

Layered room geometry, collision/walkable overlay, sockets, and placeholder actors together as a runtime-pipeline proof.

![runtime_room_pipeline_composite](captures/runtime_room_pipeline_composite.png)
