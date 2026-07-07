# Cantina Mood A/B Pass

Date: 2026-07-04  
Scope: docs-only lighting/material/clutter iteration for the kept Cantina entrance model

## Goal

Answer the next candidate question from `PIPELINE_DECISION_LOG.md`:

```text
Can fan-art/reference-board mood lessons improve the current Cantina entrance without changing the kept geometry?
```

This pass does not use fan art as source art. It applies the already-documented reference lessons in `REFERENCE_BASE_COMPARISON.md`:

- stronger sun-to-dark threshold;
- warmer exterior light;
- darker interior read;
- rougher wall/grime impression;
- richer pipes/utility clutter;
- dust berms and frontier approach density.

## One Variable Changed

Previous kept baseline:

```text
generated/godot_cantina_entrance_camera_v1/REVIEW.md
```

Changed variable:

```text
Lighting, material mood, exterior clutter, wall grime chips, and dim doorway context.
```

Kept fixed:

- `blockbench_cantina_entrance_v1.glb`;
- entrance orientation;
- Blockbench/GLB source model;
- threshold/detector/sign gameplay read;
- camera family;
- private/friends blockcraft target.

## Generator

```text
docs/gpt/asset_factory/scripts/godot_cantina_mood_ab_proof.gd
```

Run:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_cantina_mood_ab_proof.gd
```

## Generated Review

```text
docs/gpt/asset_factory/generated/cantina_mood_ab_v1/REVIEW.md
```

Generated captures:

- `captures/cantina_mood_baseline_control.png`
- `captures/cantina_mood_warm_grime_pass.png`
- `captures/cantina_mood_side_by_side.png`

## Verdict

Candidate keep.

The mood pass improves the frontier-cantina read. It makes the same entrance model feel less like a clean toy blockout and more like a sun-baked social threshold into a dim interior.

What improved:

- warmer exterior ground/light;
- stronger shadow pool at the entrance;
- amber doorway glow;
- cool detector/scanner accent;
- pipe cluster and utility-box silhouette;
- wall grime bands;
- foreground clutter and dust berms.

What still needs caution:

- the added clutter is proof geometry, not a finished kit;
- the no-droids sign still needs the separate texture/manual Blockbench pass;
- the mood pass is not enough for full Cantina interior identity;
- heavy shadows can hide small block detail if pushed further.

## Decision Log Update

`C1: Cantina Material/Mood Pass` should move from plain candidate to **candidate keep**.

Do not lock the exact mood recipe yet. The direction is better, but the palette and clutter kit still need one more focused pass.

## Next One-Variable Recommendation

Run the sign workflow test:

```text
baseline: blockbench_cantina_entrance_v1
changed variable: no-droids sign only
compare: cube-only sign vs texture/manual Blockbench sign panel
keep only if the sign reads better without copying protected iconography
```

Alternate next slice:

```text
Convert the mood-pass pipe/utility/clutter arrangement into a small Blockbench exterior-clutter kit.
```

