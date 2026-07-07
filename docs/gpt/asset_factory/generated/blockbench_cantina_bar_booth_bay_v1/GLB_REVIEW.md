# Blockbench Cantina Bar Booth Bay v1 GLB Review

Generated: 2026-07-04  
Adapter: `docs/gpt/asset_factory/adapters/blender_bbmodel_to_glb.py`

## Controlled Change

Baseline:

```text
generated/cantina_terrain_kit_v0/REVIEW.md
```

Changed variable:

```text
cantina_bar_booth_bay_01 Godot proof -> editable Blockbench .bbmodel and Blender GLB.
```

Kept fixed:

- high-tech wall bar;
- booths lining curved walls;
- dim social-room mood;
- main-bar gameplay role;
- original blockcraft grammar;
- no copied official or fan-art assets.

## Blockbench Fast Preview

![Blockbench fast preview](previews/blockbench_cantina_bar_booth_bay_v1.png)

## Blender GLB Preview

![Blender GLB preview](glb/previews/blockbench_cantina_bar_booth_bay_v1.png)

## Validation

Command:

```powershell
gltf-transform validate docs\gpt\asset_factory\generated\blockbench_cantina_bar_booth_bay_v1\glb\blockbench_cantina_bar_booth_bay_v1.glb
```

Result:

```text
No errors found.
No warnings found.
No infos found.
No hints found.
```

## Godot Proof

```text
generated/godot_cantina_bar_booth_bay_v1/REVIEW.md
```

## Verdict

Candidate keep.

The model is denser and more readable than the older procedural proof while preserving the same room contract. Use it as the editable main-bar/booth-bay baseline before building the connected multi-room Cantina interior.
