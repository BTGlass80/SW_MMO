# Pixel Cantina Kit Pass

Date: 2026-07-04  
Scope: docs-only deterministic pixel/GDScript room-kit proof for Cantina-style interiors

## Purpose

The owner asked whether the pixel-art/GDScript lane could work for the Cantina and whether it is actually efficient. This pass tests both.

The input is not a texture. It is a semantic top-down pixel card:

```text
48x32 source card
  -> tile classes: floor, wall, door, bar, booth, table, clutter, light
  -> per-pixel cubes for baseline
  -> greedy rectangle merge
  -> material-batched meshes
  -> Godot captures and stats
```

## Generated Proof

Review:

```text
generated/godot_pixel_cantina_kit_v0/REVIEW.md
```

Script:

```text
scripts/godot_pixel_cantina_kit_proof.gd
```

Manifest:

```text
generated/godot_pixel_cantina_kit_v0/pixel_cantina_manifest.json
```

Source card:

```text
generated/godot_pixel_cantina_kit_v0/source_images/cantina_floorplan_48x32.png
```

Captures:

```text
generated/godot_pixel_cantina_kit_v0/captures/pixel_cantina_source_card.png
generated/godot_pixel_cantina_kit_v0/captures/pixel_cantina_merge_ab.png
generated/godot_pixel_cantina_kit_v0/captures/pixel_cantina_batched_isometric.png
generated/godot_pixel_cantina_kit_v0/captures/pixel_cantina_room_read_closeup.png
```

## Efficiency Result

The compute result is the important part:

| Metric | Value |
| --- | ---: |
| Source grid | 48x32 |
| Non-empty source pixels | 966 |
| Per-pixel boxes/nodes | 966 |
| Same-row run boxes | 206 |
| Greedy rectangle boxes | 74 |
| Material-batched mesh nodes | 8 |
| Box reduction vs per-pixel | 92.3% |
| Node reduction vs per-pixel | 99.2% |
| Per-pixel triangle estimate | 11,592 |
| Batched triangle estimate | 888 |

That means this lane is not merely a controllable visual approach. For room kits, it can be computationally sensible if the source pixels are merged and batched.

## Visual Result

Candidate keep for:

- Cantina blockouts;
- room-graph visualization;
- collision/layout generation;
- minimap-derived room geometry;
- distant or interior LOD;
- cheap filler geometry under authored hero modules.

The current proof reads as a Cantina layout: entrance, main room, bar, booths, tables, clutter, and a back/service area. It is intentionally simpler than the kept Blockbench bar/booth bay.

## Best Use

Use this lane for the structural layer:

```text
SW_MUSH room graph / designer layout
  -> semantic pixel card
  -> merged/batched Godot geometry
  -> collision and LOD
  -> authored Blockbench identity modules on top
```

This is especially useful for a large MMO because many rooms need to exist before every room can be hand-authored.

## What It Does Not Replace

This should not replace:

- the kept Cantina entrance model;
- the kept bar/booth bay identity module;
- signs and pictograms;
- hero props;
- close-up social hub dressing;
- final lighting/material polish.

Blockbench remains the stronger foreground identity layer.

## Recommended Production Split

Use a layered approach:

```text
Pixel/GDScript:
  layout, walls, floors, collision, room LOD, generic massing

Blockbench:
  entrance, bar, booths, signs, hero furniture, recognizable props

Godot:
  batching, collision, camera proof, social/interaction anchors
```

## Next Improvement

The next one-variable improvement should add a second semantic card:

```text
floorplan card
  + wall/elevation/detail card
  -> stronger door frames
  -> arch/threshold identity
  -> booth backs and raised platforms
  -> clutter sockets
```

That would let the pixel lane produce more Cantina flavor without manually placing every module.

That improvement now exists:

```text
PIXEL_CANTINA_LAYERED_KIT_PASS.md
generated/godot_pixel_cantina_layered_kit_v1/REVIEW.md
```

Treat v1 as the stronger baseline for future room-kit experiments.
