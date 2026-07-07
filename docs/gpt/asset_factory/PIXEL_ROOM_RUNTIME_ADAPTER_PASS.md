# Pixel Room Runtime Adapter Pass

Date: 2026-07-04  
Scope: docs-only reusable adapter proof for semantic pixel room cards

## Purpose

This pass converts the Cantina runtime proof from a one-off hard-coded GDScript room into a reusable external-card adapter.

The one-variable change from `PIXEL_CANTINA_RUNTIME_PASS.md`:

```text
hard-coded floor/detail/socket/path data in GDScript
  -> external JSON semantic cards and socket/path definitions
```

The room, symbols, and core geometry are intentionally the same as the kept Cantina runtime proof. The follow-up schema pass adds explicit gameplay socket roles without changing the visual/collision cards.

## Generated Proof

Review:

```text
generated/godot_pixel_room_runtime_adapter_v0/REVIEW.md
```

Spec:

```text
specs/pixel_room_cantina_runtime_adapter_v0.json
```

Script:

```text
scripts/godot_pixel_room_runtime_adapter.gd
```

Manifest:

```text
generated/godot_pixel_room_runtime_adapter_v0/pixel_room_runtime_adapter_manifest.json
```

Source masks:

```text
generated/godot_pixel_room_runtime_adapter_v0/source_images/floor_card.png
generated/godot_pixel_room_runtime_adapter_v0/source_images/detail_card.png
generated/godot_pixel_room_runtime_adapter_v0/source_images/walkable_mask.png
generated/godot_pixel_room_runtime_adapter_v0/source_images/collision_mask.png
```

Captures:

```text
generated/godot_pixel_room_runtime_adapter_v0/captures/adapter_clean_room.png
generated/godot_pixel_room_runtime_adapter_v0/captures/adapter_collision_nav_overlay.png
generated/godot_pixel_room_runtime_adapter_v0/captures/adapter_socket_path_probe.png
```

## Runtime Result

Candidate adapter keep.

The adapter preserved the important geometry/collision baseline stats from `godot_pixel_cantina_runtime_v1`, while adding explicit socket-role data:

| Metric | Value |
| --- | ---: |
| Grid size | 48x32 |
| Floor non-empty pixels | 966 |
| Detail non-empty pixels | 141 |
| Walkable pixels | 439 |
| Walkable rectangles | 40 |
| Blocker pixels | 527 |
| Collision shapes | 38 |
| Socket count | 14 |
| Socket roles | cover:2, inspect:1, light:1, prop:2, seat:4, spawn:1, stand:1, transition:1, use:1 |
| Seat sockets | 4 |
| Stand/spawn sockets | 2 |
| Use/inspect sockets | 2 |
| Cover sockets | 2 |
| Sockets resolved to walk cells | 10 |
| Path probes | 3 |
| Path probe cells | 61 |
| Walk mask reduction vs pixels | 90.9% |
| Collision reduction vs pixels | 92.8% |

That parity is the win. It proves Claude/Codex can author room data and gameplay affordance roles as JSON cards instead of editing generator code.

## What The Spec Owns

The JSON spec owns:

- grid size and cell scale;
- symbol-to-category mapping;
- palette;
- category heights;
- floor/detail semantic cards;
- walkable floor categories;
- blocker floor/detail categories;
- socket role schema;
- sockets with `kind`, `role`, `facing`, optional `action`, tags, and raw object grid;
- path probes;
- camera framing.

The adapter owns:

- PNG source/mask output;
- greedy rectangle merging;
- material-batched voxel geometry;
- merged collision shapes;
- socket-to-walk-cell resolution;
- socket role counts and role-colored facing markers;
- grid-routed path probes;
- Godot scenes/captures;
- manifest/review output.

## Why This Matters

This is the first version of the room-pipeline shape Claude can actually request:

```text
Write a new room JSON spec.
Run the adapter.
Review masks/collision/sockets/captures.
Iterate the spec, not the tool.
```

That is the practical difference between a proof and a production lane.

The socket roles now make the spec useful for runtime tasks, not only art review:

```text
seat       -> sit/social anchors
stand      -> NPC/player staging
spawn      -> entry placement
use        -> bar, terminal, door, or prompt target
inspect    -> signs and readable props
cover      -> tactical cover affordance
transition -> room exits
prop/light -> dressing and lighting sockets
```

## What Still Needs Work

- Run the adapter on a second SW_MUSH Cantina room.
- Add explicit layer names beyond `floor` and `detail` if buildings need roof, ceiling, exterior, or facade layers.
- Add card validation errors for incorrect row length, unknown symbols, duplicate socket ids, and unreachable path probes.
- Add a clean gameplay preview alongside debug overlays.

## Next Improvement

Use the same adapter with a new spec for another SW_MUSH Cantina room:

```text
room description / YAML topology
  -> pixel_room_<room>_runtime_adapter_v1.json
  -> godot_pixel_room_runtime_adapter.gd
  -> compare stats and captures against this Cantina baseline
```

If that second room works, the semantic room-card lane can become the default production path for interiors/buildings.
