# Vengi Pixel-Card Evaluation Pass

Date: 2026-07-04  
Scope: docs-only evaluation of the locally installed Vengi tools

## Purpose

The owner installed Vengi. This pass checks whether it should join the asset pipeline now.

The narrow question:

```text
Can Vengi improve the deterministic pixel-card lane or replace part of the Blockbench/Blender/Godot route?
```

## Installed Tool Paths

Vengi is installed here:

```text
C:\Program Files\vengi
```

Useful binaries found:

```text
C:\Program Files\vengi\voxconvert\vengi-voxconvert.exe
C:\Program Files\vengi\voxedit\vengi-voxedit.exe
C:\Program Files\vengi\thumbnailer\vengi-thumbnailer.exe
C:\Program Files\vengi\palconvert\vengi-palconvert.exe
```

Vengi version:

```text
voxconvert 0.5.0.0
```

No PATH change is required for Codex. Use absolute executable paths in scripts and docs.

## Generated Proof

Review:

```text
generated/vengi_pixel_card_eval_v0/REVIEW.md
```

Script:

```text
scripts/godot_vengi_pixel_card_eval_proof.gd
```

Generated files:

```text
generated/vengi_pixel_card_eval_v0/pixel_service_terminal_vengi_plane.glb
generated/vengi_pixel_card_eval_v0/glb/pixel_patrol_ship_vengi_plane.glb
generated/vengi_pixel_card_eval_v0/vox/pixel_service_terminal_vengi_plane.vox
```

Captures:

```text
generated/vengi_pixel_card_eval_v0/captures/vengi_terminal_same_source_ab.png
generated/vengi_pixel_card_eval_v0/captures/vengi_ship_same_source_ab.png
```

## What Worked

Vengi successfully converted project-owned PNG source cards to:

- flat GLB;
- MagicaVoxel `.vox`.

The tested GLBs imported into Godot and validated with no errors. `gltf-transform validate` reported data-URI-in-GLB warnings, so these are proof artifacts, not promotion-ready runtime files.

Useful commands:

```powershell
& "C:\Program Files\vengi\voxconvert\vengi-voxconvert.exe" `
  --input docs\gpt\asset_factory\generated\godot_pixel_extrude_v0\source_images\pixel_service_terminal_front_24x24.png `
  --output docs\gpt\asset_factory\generated\vengi_pixel_card_eval_v0\vox\pixel_service_terminal_vengi_plane.vox `
  --force

& "C:\Program Files\vengi\voxconvert\vengi-voxconvert.exe" `
  --input docs\gpt\asset_factory\generated\godot_pixel_extrude_v0\source_images\pixel_patrol_ship_top_32x32.png `
  --output docs\gpt\asset_factory\generated\vengi_pixel_card_eval_v0\glb\pixel_patrol_ship_vengi_plane.glb `
  --force
```

## What Did Not Work Yet

These first probes hung and were stopped:

```text
PNG image-volume import -> GLB/VOX
.bbmodel -> GLB
PNG --json scene dump
```

That does not mean Vengi cannot do them. It means they are not verified enough to enter the default pipeline.

## Visual Verdict

Candidate bridge keep, not a replacement.

The Godot run-merged pixel extrusion still beats Vengi's successful PNG-to-GLB path for the target look. Vengi's working GLB path is a flat textured mesh. It does not give us the same readable cube bars, thickness, or in-engine control that the Godot extrusion script gives.

Vengi's immediate value is:

```text
project pixel card
  -> Vengi/MagicaVoxel .vox bridge
  -> optional manual voxel editing
  -> later export/validation
```

This is especially useful if the owner or a human artist wants to open a pixel-card asset in a voxel editor, tweak it by hand, and send it back.

## Recommended Role

Use Vengi as a converter/editor bridge:

- PNG source card to `.vox`;
- `.vox` manual cleanup in `vengi-voxedit`;
- format inspection and conversion tests;
- future image-volume A/B once the CLI invocation is debugged.

Do not use it yet as:

- the default Blockbench-to-GLB converter;
- the default pixel-card-to-runtime-GLB converter;
- proof that the Godot extrusion lane should be replaced.

## Next One-Variable Test

Pick one:

1. Debug one image-volume conversion command until it exits reliably.
2. Open `pixel_service_terminal_vengi_plane.vox` in `vengi-voxedit`, thicken/cleanup manually, export GLB, and compare against Godot run-merge.
3. Test Vengi as a converter for a simpler `.vox` file made by Vengi itself, then import to Godot.

Until one of those wins, keep Godot pixel extrusion as the deterministic default.

