# Cantina Sign Texture Pass

Date: 2026-07-04  
Scope: docs-only sign workflow test for the kept Cantina entrance model

## Goal

Answer the candidate question from `PIPELINE_DECISION_LOG.md`:

```text
Can a texture/manual Blockbench sign panel beat the cube-only no-droids sign without changing the kept entrance model?
```

This is a sign workflow test, not a general texture-style pivot.

## One Variable Changed

Previous kept baseline:

```text
generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md
generated/godot_cantina_entrance_camera_v1/REVIEW.md
```

Changed variable:

```text
No-droids sign only.
```

Kept fixed:

- entrance model geometry;
- threshold, detector, door, steps, wall massing;
- Blockbench/GLB lane;
- Godot camera proof lane;
- private/friends blockcraft target.

## What Changed

The candidate source copies the kept Blockbench entrance and removes only these cube sign glyphs:

- `sign_droid_body`
- `sign_droid_head`
- `sign_red_slash`

It adds one original pixel-texture sign panel:

```text
blockbench/textures/no_droids_sign_panel_v1.png
```

The pictogram is intentionally generic: a simple service-droid shape under a red prohibition mark. It does not trace official signage, logos, fan art, or protected iconography.

## Tooling Delta

The Blender `.bbmodel` adapter now supports a narrow `codex_texture_materials` plus `codex_plane` path for texture/decal planes.

This is useful for signs, decals, role markings, and tiny symbols where cube glyphs are unreadable.

It should **not** be read as permission to texture everything. The blockcraft model should still be mostly geometry and palette-driven.

## Generated Artifacts

Source candidate:

```text
generated/blockbench_cantina_sign_texture_v1/REVIEW.md
generated/blockbench_cantina_sign_texture_v1/blockbench/blockbench_cantina_sign_texture_v1.bbmodel
generated/blockbench_cantina_sign_texture_v1/blockbench/textures/no_droids_sign_panel_v1.png
```

GLB candidate:

```text
generated/blockbench_cantina_sign_texture_v1/GLB_REVIEW.md
generated/blockbench_cantina_sign_texture_v1/glb/blockbench_cantina_sign_texture_v1.glb
```

Godot proof:

```text
generated/godot_cantina_sign_texture_v1/REVIEW.md
```

## Validation

Command:

```powershell
gltf-transform validate docs\gpt\asset_factory\generated\blockbench_cantina_sign_texture_v1\glb\blockbench_cantina_sign_texture_v1.glb
```

Result:

```text
No errors found.
No warnings found.
No infos found.
No hints found.
```

## Verdict

Candidate keep.

The texture/manual sign panel is plainly stronger than the cube-only sign. The old cube sign communicates "panel with something on it"; the texture sign actually reads as a prohibition sign from the closeup and remains visible from the ground camera.

What improved:

- diagonal slash reads correctly;
- droid pictogram is more legible;
- sign still feels blockcraft/pixel-art rather than high-res pasted art;
- GLB validates cleanly;
- Godot imports and renders the texture.

What remains cautious:

- this should stay a tiny-sign/decal lane, not a full material-texturing lane;
- the sign may need a final owner-authenticity pass for exactly how "droid" the pictogram should look;
- do not copy official signage or a fan-art sign.

## Decision Log Update

`C2: Texture/Sign Workflow for Blockbench` should move from candidate to **candidate keep**.

Do not lock textures globally. Lock only this narrower idea:

```text
For tiny signs/decals where cube glyphs fail, an original pixel-texture plane is allowed after GLB validation and Godot camera proof.
```

## Next One-Variable Recommendation

Do either:

```text
Convert the mood-pass pipe/utility/clutter arrangement into a small Blockbench exterior-clutter kit.
```

or:

```text
Convert the bar/booth bay module into Blockbench/GLB using the locked identity lane.
```

Do not keep tweaking the entrance sign unless the owner wants a more specific droid pictogram.

