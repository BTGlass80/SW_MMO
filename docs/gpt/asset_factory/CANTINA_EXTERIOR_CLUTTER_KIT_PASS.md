# Cantina Exterior Clutter Kit Pass

Date: 2026-07-04  
Scope: docs-only Blockbench/GLB/Godot iteration for reusable Cantina exterior clutter

## Goal

Follow up on the `cantina_mood_ab_v1` caution:

```text
The mood pass works, but the clutter is still proof geometry.
```

This pass converts the successful mood-pass clutter language into reusable editable modules:

- pipe cluster;
- utility box;
- crate/scrap stack;
- dust berm.

## One Variable Changed

Previous baseline:

```text
generated/cantina_mood_ab_v1/REVIEW.md
```

Changed variable:

```text
Godot proof boxes for exterior clutter -> Blockbench .bbmodel modules -> Blender GLBs -> Godot import/camera proof.
```

Kept fixed:

- kept Cantina entrance GLB and orientation;
- no-droids sign workflow;
- camera family;
- warm exterior / dim doorway mood family;
- private/friends blockcraft target;
- source boundary: original cube grammar, no copied reference art or official assets.

## Generated Sources

Spec:

```text
docs/gpt/asset_factory/specs/blockbench_cantina_exterior_clutter_v1.json
```

Blockbench/GLB outputs:

```text
docs/gpt/asset_factory/generated/blockbench_cantina_exterior_clutter_v1/
```

Godot camera proof:

```text
docs/gpt/asset_factory/generated/godot_cantina_exterior_clutter_kit_v1/REVIEW.md
```

## Iteration Note

The first generated pipe cluster had a solid backplate and read like a large brown slab in the Godot camera. That was rejected during the same slice. The kept version changes only that variable: the slab became separated mounting strips and brackets, which reads more like utility infrastructure.

## Validation

All four GLBs validate cleanly with `gltf-transform validate`:

```text
cantina_crate_scrap_stack_v1.glb: no errors, warnings, infos, or hints.
cantina_dust_berm_v1.glb: no errors, warnings, infos, or hints.
cantina_pipe_cluster_v1.glb: no errors, warnings, infos, or hints.
cantina_utility_box_v1.glb: no errors, warnings, infos, or hints.
```

## Verdict

Candidate keep.

The imported kit preserves the lived-in Cantina mood while giving Claude reusable editable `.bbmodel` and `.glb` assets. This is better than leaving the mood pass as one-off proof boxes.

Do not stamp the whole kit everywhere. Use it as a small identity/filler boundary set: place one or two modules per exterior chunk, then screenshot-test beside the kept entrance.

## Next One-Variable Recommendation

Convert the bar/booth bay or back hallway module into Blockbench/GLB using the same locked lane.
