# Meshy Texture Refine Pass

Date: 2026-07-04  
Scope: first Meshy preview-to-refine texture test for the asset factory

## Purpose

Answer the owner's texture concern:

```text
Why do the Meshy/Godot tests look like untextured clay when Godot can render polished games?
```

Answer:

```text
Meshy preview is geometry only.
Meshy refine is the texture step.
The prior Godot proof also intentionally overrode materials to judge geometry.
```

Godot can render highly textured scenes, but it does not create that art by itself. It needs textured assets, materials, lighting, post-processing, and camera composition. The previous Meshy proof was not testing that final look.

Separate note after the pixel-extrude proof:

```text
If the desired result is true Minecraft-style cube geometry, Meshy refine is the wrong first fix.
Use an original pixel/source card and Godot pixel extrusion first.
Use Meshy refine when the Meshy preview geometry already wins and only needs texture.
```

## Source Candidate

Preview candidate:

```text
meshy_cantina_service_terminal_meshy5_draft_v1
```

Why this candidate:

- It cost only 5 API credits.
- It had the strongest silhouette seed of the tested Meshy variants.
- It was not blockcraft-cohesive enough as a direct keep, but it was good enough to test texture/refine value.

Refined output:

```text
generated/meshy_eval_v0/meshy_cantina_service_terminal_meshy5_draft_v1_refine_v1/
```

## Cost

Observed API costs:

| Step | Credits |
| --- | ---: |
| Meshy 5 preview via v2 API | 5 |
| Meshy 5 refine | 10 |
| Total | 15 |

This differs from the legacy workspace note that suggested 10 credits for 4 draft variants. The v2 API task object observed for this run returned one `model_urls.glb`, no `drafts`, and no `variants`.

## Validation

Preview GLB:

```text
No errors.
No warnings.
One info: UNUSED_OBJECT on TEXCOORD_0.
```

Refined GLB:

```text
No errors.
No warnings.
One info: NODE_MATRIX_DEFAULT on /nodes/0/matrix.
```

## Godot Proof

Updated proof script:

```text
scripts/godot_meshy_eval_proof.gd
```

New captures:

```text
generated/meshy_eval_v0/godot_proof/captures/meshy5_refined_material_geometry.png
generated/meshy_eval_v0/godot_proof/captures/meshy5_preview_vs_refined_material_ab.png
generated/meshy_eval_v0/godot_proof/captures/meshy5_refined_rotation_contact_sheet.png
```

The material-preserving Godot captures prove the refined texture imports and renders in Godot. The refined model is much stronger than preview clay in the provider thumbnail, and visibly textured in Godot.

## Verdict

Candidate texture/refine keep, not direct runtime keep.

The refine step solves the "untextured clay" problem for Meshy assets, but it does not solve the style-cohesion problem by itself. The result is stylized and useful, but still softer and less cube-authored than the Blockbench identity lane.

Best use:

```text
Meshy 5 preview/refine for high-entropy prop concepting and texture mood.
Then rebuild/normalize the winner into Blockbench if it needs to live beside cubecraft modules.
```

Direct runtime use is possible only for low-stakes background/hero dressing after:

- orientation is corrected;
- material import is verified in Godot;
- scale/origin are normalized;
- the asset is tested beside kept Blockbench modules;
- the owner accepts the softer style.

## Free Retry Note

The owner's UI screenshot says successful-but-disappointing generations should use plan free retries. However, Meshy's help center says the API does not currently support retry functionality for individual or studio teams; API users must submit a new request, which consumes credits normally.

Reference:

```text
https://help.meshy.ai/en/articles/9992034-does-the-meshy-api-support-retry-for-generations
```

Therefore:

```text
Use free retries manually in the Meshy web UI if needed.
Do not assume API scripts can trigger free retries.
```
