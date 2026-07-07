# Blockbench Cantina Sign Texture v1 Source Review

Generated: 2026-07-04T11:45:07.724Z
Generator: `docs/gpt/asset_factory/scripts/cantina_sign_texture_pass.mjs`

## Controlled Change

Baseline: `generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md`

Changed variable: no-droids sign workflow only.

The candidate removes only the cube pictogram/slash elements and adds one original pixel-texture sign panel. The entrance geometry, detector, wall, steps, palette, and scale stay unchanged.

## Source Files

- `blockbench/blockbench_cantina_sign_texture_v1.bbmodel`
- `blockbench/textures/no_droids_sign_panel_v1.png`

## Texture

![No droids sign texture](blockbench/textures/no_droids_sign_panel_v1.png)

## Source Boundary

The texture is an original blockcraft pictogram: a generic service-droid shape with a red prohibition mark. It does not trace official signage, logos, fan art, or exact protected iconography.

## Next

Convert to GLB with the texture-aware Blender adapter, validate, and run a Godot camera comparison against the cube-only sign baseline.

## Conversion Result

Converted with:

```powershell
.\docs\gpt\asset_factory\scripts\run_blockbench_to_glb.ps1 -BbmodelDir "docs\gpt\asset_factory\generated\blockbench_cantina_sign_texture_v1\blockbench" -OutDir "docs\gpt\asset_factory\generated\blockbench_cantina_sign_texture_v1\glb"
```

GLB review:

```text
generated/blockbench_cantina_sign_texture_v1/GLB_REVIEW.md
```

Godot proof:

```text
generated/godot_cantina_sign_texture_v1/REVIEW.md
```

Verdict: candidate keep.
