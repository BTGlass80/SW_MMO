# Cantina Blockbench Entrance Pass

Date: 2026-07-04  
Scope: docs-only conversion of kept Cantina entrance proof into editable model source

## Goal

Convert the kept Godot `cantina_entrance_detail_v1` proof into an editable Blockbench/GLB candidate without changing the entrance layout, gameplay role, or visual target.

## One Variable Changed

Previous kept baseline:

```text
generated/cantina_entrance_detail_v1/ITERATION_REVIEW.md
```

Changed variable:

```text
Godot procedural proof -> Blockbench .bbmodel + Blender GLB lane.
```

Kept fixed:

- elevated entrance threshold;
- no-droids sign and detector post;
- Minecraft-like cube density;
- sand/adobe palette;
- source boundary;
- private/friends SW-authentic blockcraft target.

## Spec

```text
docs/gpt/asset_factory/specs/blockbench_cantina_entrance_v1.json
```

## Known Adapter Limitation

The current simple Blockbench adapter does not preserve cube rotation. That means the diagonal sign slash from the Godot proof becomes a straight cuboid mark in this pass.

This is acceptable for lane testing, but the sign should become either a small texture panel or a manual Blockbench edit before runtime promotion.

## Evaluation

This pass should be judged on:

- whether the `.bbmodel` and `.glb` preserve the V1 entrance silhouette;
- whether the detail density survives Blender preview;
- whether GLB validation is clean;
- whether tool friction is acceptable for converting the rest of the Cantina kit.

## Result

Review:

```text
docs/gpt/asset_factory/generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md
```

Verdict: keep as the editable Cantina entrance baseline.

The Blender GLB preview preserves the V1 entrance threshold and the GLB validates cleanly. The next controlled pass should be Godot import/camera proof only, with no model changes.

## Godot Camera Proof

Review:

```text
docs/gpt/asset_factory/generated/godot_cantina_entrance_camera_v1/REVIEW.md
```

Verdict: keep as a Godot import/camera proof.

The first camera attempt showed the wrong side of the GLB, so the review script was corrected by rotating the imported holder 180 degrees. The model itself was not changed. The corrected capture preserves the controlled-threshold read in Godot.
