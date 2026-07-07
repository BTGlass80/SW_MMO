# Pixel Extrude Godot Pass

Date: 2026-07-04  
Scope: docs-only test of 2D pixel image -> Godot cube model generation

## Purpose

Test Gemini's Option 3 in this project instead of just theorizing:

```text
2D pixel source image
  -> read non-transparent pixels in GDScript
  -> spawn strict grid cubes
  -> save Godot review scenes
  -> capture from the intended camera
```

This answers the core Meshy problem directly. Meshy lowpoly still creates continuous triangle meshes that can look chunky, but it does not guarantee Minecraft-style orthogonal cube grammar. Pixel extrusion does.

## Generated Proof

Review:

```text
generated/godot_pixel_extrude_v0/REVIEW.md
```

Script:

```text
scripts/godot_pixel_extrude_proof.gd
```

Source pixel cards:

```text
generated/godot_pixel_extrude_v0/source_images/pixel_blaster_side_32x16.png
generated/godot_pixel_extrude_v0/source_images/pixel_service_terminal_front_24x24.png
generated/godot_pixel_extrude_v0/source_images/pixel_patrol_ship_top_32x32.png
```

Godot review scenes:

```text
generated/godot_pixel_extrude_v0/review_scenes/
```

Captures:

```text
generated/godot_pixel_extrude_v0/captures/pixel_blaster_per_pixel_cubes.png
generated/godot_pixel_extrude_v0/captures/pixel_terminal_wall_module.png
generated/godot_pixel_extrude_v0/captures/pixel_ship_vs_blockbench_isometric.png
generated/godot_pixel_extrude_v0/captures/pixel_extrude_three_family_sheet.png
generated/godot_pixel_extrude_v0/captures/pixel_blaster_pixel_vs_runmerge.png
generated/godot_pixel_extrude_v0/captures/pixel_ship_pixel_vs_runmerge.png
```

## Result

Candidate lane keep for strict voxel props and tactical tokens.

Best current uses:

- weapon pickups and small carried props;
- signs, decals, datapads, terminals, and UI-like wall panels;
- isometric tactical ship tokens;
- inventory icons that can become tiny 3D pickups;
- source-card-to-Blockbench rebuild references.

The terminal and ship token are the strongest outputs. They read more like the desired blockcraft target than the current Meshy text-prompt results because the grid cannot melt.

The blaster is readable, but the per-pixel version feels a bit like a flat cutout. It needs either:

- better pixel source art;
- side/top layering;
- run-merge extrusion;
- or a Blockbench rebuild using the pixel card as a silhouette contract.

## Per-Pixel vs Run-Merge

Two emission modes were tested with the same source images.

| Source | Per-pixel cubes | Same-color run boxes | Reduction |
| --- | ---: | ---: | ---: |
| 32x16 blaster | 146 | 32 | 78% |
| 32x32 ship | 322 | 94 | 71% |

Per-pixel cubes are the strictest Minecraft interpretation. Same-color run boxes are probably the better production default for this project because they preserve the silhouette while creating cleaner Blockbench-like rectangular bars and reducing object count.

Default recommendation:

```text
Use run-merge extrusion for production props.
Use per-pixel extrusion only when the pixelated surface is the point.
```

## Relationship To Meshy

Pixel extrusion and Meshy image-to-3D are different tools.

```text
Pixel image -> Godot cubes
  = true grid, zero credits, very controllable, flatter source art burden.

Pixel image -> Meshy image-to-3D
  = still AI continuous mesh generation, may follow style better than text prompts, costs credits, not guaranteed grid-correct.
```

So yes, source images are useful. But for true Minecraft/blockcraft, the first place to use source images is this pixel-extrude lane, not Meshy.

Meshy image-to-3D should still be tested later with our own generated blockcraft cards, not copied fan art, if the goal is richer organic/hero shapes or if we want Meshy to interpret a style card.

## Source Image Rules

Allowed source images:

- Codex-generated pixel cards;
- SVG contracts rendered to PNG;
- owner-created sketches;
- licensed/private AI image outputs created for this project;
- simplified reference cards made from written grammar.

Avoid:

- direct fan-art image uploads;
- official stills or model sheets;
- copied logos or markings;
- texture sampling from protected sources.

For private/friends authenticity, the source card can push Star Wars readability through silhouette, color, and role language, but it should still be original project art.

## When Claude Should Request This Lane

Use this request shape:

```text
Create a 32x32 or 48x48 pixel source card for <asset>.
Use palette <palette>.
Use run-merge extrusion unless per-pixel texture is important.
Capture in Godot beside <baseline>.
Return source PNG, review scene, capture, cube counts, and keep/reject verdict.
```

Good examples:

```text
blaster pistol pickup
datapad pickup
service terminal wall panel
cantina sign/decal with depth
medical crate icon-to-prop
isometric patrol fighter token
droid faction badge marker
```

Bad examples:

```text
full clone trooper body
multi-room Cantina building
large terrain chunk
organic alien hero character
```

Those need Blockbench, Godot blockout, Meshy/human concepting, or a layered multi-view extension of this method.

## Next One-Variable Test

Use a real request, not a toy source:

```text
request -> 32x32 Codex/source-card image -> run-merge extrusion -> Godot capture -> compare to Blockbench baseline
```

Best next test:

```text
blaster pistol pickup or datapad pickup
```

Those are small enough to prove the pipeline and large enough to matter in the game.
