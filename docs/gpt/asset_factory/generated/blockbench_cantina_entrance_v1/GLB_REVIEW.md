# Blockbench Cantina Entrance v1 GLB Review

Generated: 2026-07-04  
Adapter: `docs/gpt/asset_factory/adapters/blender_bbmodel_to_glb.py`

## Controlled Change

Only the tool lane changed from the kept Godot proof:

```text
Godot procedural entrance proof -> Blockbench .bbmodel -> Blender GLB
```

Kept fixed:

- elevated threshold layout;
- no-droids detector gameplay read;
- Minecraft-like small cube density;
- sand/adobe palette;
- private/friends SW-authentic blockcraft target.

## Baseline

![Godot V1 entrance](../cantina_entrance_detail_v1/captures/assets/cantina_entrance_threshold_detail_01.png)

## Blockbench Fast Preview

![Blockbench fast preview](previews/blockbench_cantina_entrance_v1.png)

The fast preview is useful for source sanity, but the camera is less helpful for judging the facade.

## Blender GLB Preview

![Blender GLB preview](glb/previews/blockbench_cantina_entrance_v1.png)

## Validation

Command:

```powershell
gltf-transform validate docs\gpt\asset_factory\generated\blockbench_cantina_entrance_v1\glb\blockbench_cantina_entrance_v1.glb
```

Result:

```text
No errors found.
No warnings found.
No infos found.
No hints found.
```

## Verdict

Keep as the editable Cantina entrance baseline.

The GLB preview preserves the V1 threshold read and the added small-block detail. This proves the terrain kit can move from Godot spatial proof into Blockbench/Blender without losing the core design.

## Known Limitation

The simple Blockbench adapter does not preserve rotated cubes. The no-droids slash is therefore a straight cuboid mark in this pass. Before runtime promotion, make the sign a texture panel or a manual Blockbench edit.

## Next One-Variable Recommendation

Run a Godot GLB camera/import proof for this exact GLB.

Do not change the model, palette, or layout in that pass. The next question is only:

```text
Does the kept Blockbench GLB survive the intended Godot ground camera?
```

