# Meshy Premium Evaluation

Date: 2026-07-04  
Scope: docs-only evaluation lane for Meshy API output

## Owner Update

The owner subscribed to Meshy Premium and wants to see whether it changes the game for the SW_MMO_Prototype asset pipeline.

The key rule after the latest foreground tests:

```text
Meshy is not a default foreground voxel asset lane.
Use it only as salvage/reference/background research unless a future A/B proves otherwise.
```

Do not write API keys into repo files. Use:

```powershell
$env:MESHY_API_KEY = "<set locally, never commit>"
```

## Current API Notes

Checked against Meshy docs on 2026-07-04:

- Text to 3D v2 uses `POST /openapi/v2/text-to-3d`.
- Preview mode creates geometry first with `mode: "preview"`.
- Refine mode textures a succeeded preview with `mode: "refine"` and `preview_task_id`.
- Retrieve with `GET /openapi/v2/text-to-3d/:id`.
- Preview prompts have a 600 character maximum.
- `model_type: "lowpoly"` is available and generates cleaner low-poly meshes.
- When `lowpoly` is selected, `ai_model`, `topology`, `target_polycount`, and `should_remesh` are ignored. It is a separate Meshy generation path, not just `standard` with fewer polygons.
- `target_formats: ["glb"]` limits outputs.
- `alpha_thumbnail: true` asks for a transparent-background thumbnail.

Useful references:

- <https://docs.meshy.ai/en/api/text-to-3d>
- <https://docs.meshy.ai/en/api/quick-start>

## What Meshy Might Change

Meshy could still matter for:

- distant background plates;
- sky/horizon/far-settlement renders;
- space ambience such as planets, moons, nebulae, distant debris, and station silhouettes;
- VFX reference for Godot-native particles/sprites/shaders;
- rebuild-only reference for hard-to-imagine shape language.

Meshy probably should not replace:

- cheap repeatable blockcraft characters;
- simple droids;
- weapons where tiny silhouette control matters;
- modular building grammar;
- gameplay-critical room geometry;
- any asset that must be edited block-by-block by Claude or the owner.
- strict voxel props/tokens that can be produced from original pixel cards in Godot.
- any foreground asset that sits directly beside discrete voxel geometry.

## Hybrid Tiering

The current recommendation is not "Meshy for every high-impact asset." It is:

```text
Meshy for high-entropy/hard-to-author assets.
Blockbench/Godot for exact, modular, repeatable, and style-critical assets.
```

Read `MESHY_CREDIT_AND_TIER_STRATEGY.md` before spending credits.
Read `MESHY_SALVAGE_LANES.md` before attempting another Meshy foreground test.

The owner correctly challenged an immediate `standard` test. `lowpoly` is the better aesthetic default for the current blockcraft target. A cheaper `standard`/Meshy 5 pass is useful as an option-mining or budget-control probe, but it should not replace lowpoly without a focused A/B win.

Observed Meshy 5 v2 API behavior:

```text
standard + meshy-5 preview -> 5 credits -> one GLB
```

This did not expose the four draft variants described in the legacy workspace UI note. If a true four-draft API path exists, it has not been found in the current v2 Text-to-3D endpoint.

The first refine/texture test is documented in `MESHY_TEXTURE_REFINE_PASS.md`.

The first zero-credit true-voxel alternative is documented in `PIXEL_EXTRUDE_GODOT_PASS.md`. If the desired asset can start as a 16x/32x/48x pixel card, try Godot pixel extrusion before spending Meshy credits.

## New Evaluation Rule

Use Meshy in a gated lane:

```text
request/spec
  -> Meshy preview only
  -> download GLB + thumbnail
  -> validate GLB
  -> Godot camera proof
  -> keep/reject
  -> refine only if preview geometry wins
```

Do not call refine automatically. The refine step costs more and can make a bad shape look superficially better. Geometry must win first.

## Current Meshy Test Slice

The first conservative test is a Cantina-adjacent service terminal/utility prop:

```text
specs/meshy_eval_v0.json
```

Why this asset:

- It is useful if successful.
- It is not a protected official model.
- It can be compared against the existing Cantina clutter/interior module lane.
- It tests whether Meshy can produce better medium-detail sci-fi set dressing than our block boxes without breaking style.

Result:

```text
generated/meshy_eval_v0/REVIEW.md
```

The first preview consumed 20 credits, downloaded a clean GLB, and validated with no errors or warnings. The verdict is candidate lesson keep, not a direct runtime/model keep.

## How To Run

From the project root:

```powershell
$env:MESHY_API_KEY = "<set locally>"
python .\docs\gpt\asset_factory\adapters\meshy_text_to_3d.py `
  run-preview `
  --spec .\docs\gpt\asset_factory\specs\meshy_eval_v0.json `
  --asset-id meshy_cantina_service_terminal_v0 `
  --out-dir .\docs\gpt\asset_factory\generated\meshy_eval_v0
```

If Python HTTPS certificate validation fails on this Windows environment, use the PowerShell adapter, which uses Windows' native HTTPS stack:

```powershell
$env:MESHY_API_KEY = "<set locally>"
.\docs\gpt\asset_factory\adapters\meshy_text_to_3d.ps1 `
  -Command run-preview `
  -Spec .\docs\gpt\asset_factory\specs\meshy_eval_v0.json `
  -AssetId meshy_cantina_service_terminal_v0 `
  -OutDir .\docs\gpt\asset_factory\generated\meshy_eval_v0
```

Dry run without spending credits:

```powershell
python .\docs\gpt\asset_factory\adapters\meshy_text_to_3d.py `
  dry-run `
  --spec .\docs\gpt\asset_factory\specs\meshy_eval_v0.json `
  --asset-id meshy_cantina_service_terminal_v0 `
  --out-dir .\docs\gpt\asset_factory\generated\meshy_eval_v0
```

## Acceptance Gates

A Meshy preview is a candidate keep only if:

- downloaded GLB validates cleanly or has only explainable warnings;
- thumbnail is on target from first glance;
- Godot proof shows useful silhouette at the game camera;
- it is not too realistic or blobby beside Blockbench assets;
- it does not contain logos, readable text, or protected franchise shapes;
- it would save more time than rebuilding in Blockbench.

For the first test, the provider thumbnail was stronger than the Godot-tinted gameplay proof. Future Meshy reviews should always include:

```text
provider thumbnail
GLB validation
Godot camera proof
keep/rebuild/reject verdict
```

Do not trust any one view alone.

Reject if:

- shape is mushy;
- scale/origin are chaotic;
- it looks like a different game;
- topology is too costly to clean;
- the asset is less editable than an equivalent Blockbench pass;
- it requires refine before the geometry can be judged.

## Skill Recommendation

Do not split installed skills yet.

Keep one draft umbrella skill:

```text
sw-mmo-asset-factory
```

Use references inside it for modeling, animation, and Meshy/API generation. Split into separate installed skills only after a lane has stable scripts and validation that create enough load to justify a separate trigger.

Likely future split:

```text
sw-mmo-model-assets
sw-mmo-animate-assets
sw-mmo-api-assets
```

But splitting now would add overhead without improving results.

Meshy reinforces that recommendation: API use belongs as a referenced lane inside the umbrella draft skill for now. Split it out only if API generation gets enough scripts, queue traffic, and validation rules to justify `sw-mmo-api-assets`.
