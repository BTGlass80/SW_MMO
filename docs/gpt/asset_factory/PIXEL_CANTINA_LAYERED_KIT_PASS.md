# Pixel Cantina Layered Kit Pass

Date: 2026-07-04  
Scope: docs-only layered semantic pixel/GDScript room-kit proof

## Purpose

This pass tests the next one-variable improvement after `PIXEL_CANTINA_KIT_PASS.md`:

```text
floorplan card
  + detail/elevation card
  -> merged rectangles
  -> material-batched Godot meshes
  -> richer room identity without hand-authoring every module
```

The goal is to see whether the pixel room-kit lane can move beyond blockout while staying deterministic and cheap.

## Generated Proof

Review:

```text
generated/godot_pixel_cantina_layered_kit_v1/REVIEW.md
```

Script:

```text
scripts/godot_pixel_cantina_layered_kit_proof.gd
```

Manifest:

```text
generated/godot_pixel_cantina_layered_kit_v1/pixel_cantina_layered_manifest.json
```

Source cards:

```text
generated/godot_pixel_cantina_layered_kit_v1/source_images/cantina_floorplan_48x32.png
generated/godot_pixel_cantina_layered_kit_v1/source_images/cantina_detail_elevation_48x32.png
```

Captures:

```text
generated/godot_pixel_cantina_layered_kit_v1/captures/layered_cantina_source_cards.png
generated/godot_pixel_cantina_layered_kit_v1/captures/layered_cantina_v0_vs_v1.png
generated/godot_pixel_cantina_layered_kit_v1/captures/layered_cantina_v1_isometric.png
generated/godot_pixel_cantina_layered_kit_v1/captures/layered_cantina_v1_closeup.png
```

## Efficiency Result

The second semantic card adds detail without destroying the compute model:

| Metric | Value |
| --- | ---: |
| Source grid | 48x32 |
| Floor non-empty pixels | 966 |
| Detail non-empty pixels | 141 |
| Combined non-empty pixels | 1,107 |
| Floor rectangles | 74 |
| Detail rectangles | 27 |
| Combined rectangles | 101 |
| Material-batched mesh nodes | 16 |
| Rectangle reduction vs per-pixel | 90.9% |
| Node reduction vs per-pixel | 98.6% |
| Per-pixel triangle estimate | 13,284 |
| Batched triangle estimate | 1,212 |

The v0 floorplan-only pass used 8 material-batched nodes. V1 uses 16 because the detail layer adds more semantic categories, but the cost is still very small for room-scale geometry.

## Visual Result

Candidate keep.

The second card adds visible identity hooks:

- entrance arch/frames;
- back-room/service doorway massing;
- booth backs;
- bar lamps;
- pipes;
- sockets;
- raised strips/platform accents;
- sign panel hooks.

It still reads as a generated room kit, not a finished hero environment. That is appropriate for the intended layer.

## Production Role

Use this as the scalable structural backbone:

```text
SW_MUSH room graph / designer room sketch
  -> floorplan semantic card
  -> detail/elevation semantic card
  -> merged/batched Godot room kit
  -> collision/navigation/interaction sockets
  -> Blockbench hero modules layered in
```

This is the strongest current answer to "how do we create a lot of rooms without hand-modeling everything?"

## What Still Needs Blockbench

Keep authored Blockbench assets for:

- the Cantina entrance;
- bar and booth hero modules;
- signs and readable pictograms;
- detailed clutter kits;
- unique social hubs;
- close-up story props.

The pixel lane can place sockets for those assets, but should not replace them.

## Follow-Up Runtime Proof

The next one-variable step has now been run:

```text
same floor/detail cards
  -> collision shapes
  -> walkable/navigation mask
  -> named interaction sockets
  -> Godot proof with placeholder actors
```

Review it here:

```text
PIXEL_CANTINA_RUNTIME_PASS.md
generated/godot_pixel_cantina_runtime_v1/REVIEW.md
```

That pass moves the lane from visual generator toward runtime room-production pipeline.
