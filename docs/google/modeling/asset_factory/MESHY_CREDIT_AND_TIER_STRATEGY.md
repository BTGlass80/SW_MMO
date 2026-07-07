# Meshy Credit and Tier Strategy

Date: 2026-07-04  
Scope: docs-only operating strategy for using Meshy Premium without losing blockcraft cohesion

## Current Read

The hybrid approach is correct, with one important caveat:

```text
High impact does not automatically mean Meshy.
High-entropy or hard-to-author means Meshy deserves a test.
```

Use the hand-rolled Blockbench/Godot lane for assets where cube grammar, exact editability, or repetition matters more than raw generated detail. Use Meshy where a prompt can save real exploration time or where our cube authoring is currently weakest.

## Tiering

### Hand-Rolled / Blockbench / Godot Default

Use this for:

- modular buildings and terrain kits;
- reusable walls, doorways, awnings, roofs, windows, counters, booths, crates, pipes, signs, and interior clutter;
- simple droids and repeatable NPC bodies;
- weapons where silhouette and carried pose must be exact;
- gameplay-critical room geometry;
- background filler that must stay cohesive across many tiles;
- anything Claude or the owner should be able to tweak block-by-block.

Why:

- cheapest;
- editable;
- coherent;
- easy to validate in Godot;
- easy to make style-consistent at scale.

### Godot Pixel-Extrude True Voxel Lane

Use this before Meshy when the asset can naturally start as a tiny 2D card:

- weapon pickups;
- datapads and inventory items;
- signs, decals, and faction badges;
- wall terminals and UI-like panels;
- isometric tactical ship tokens.

Current proof:

```text
PIXEL_EXTRUDE_GODOT_PASS.md
generated/godot_pixel_extrude_v0/REVIEW.md
```

Why:

- zero credits;
- true discrete cube grid;
- no Meshy melt/lowpoly softness;
- easy to create original project-owned source cards;
- same-color run merge reduces cube counts while keeping the silhouette.

Boundary:

This is not a full character/building solution yet. Use it for flat-ish props and tokens, or as a source-card-to-Blockbench silhouette contract.

### Godot Pixel-Hull Character Research Lane

Use this before Meshy when the question is "can flat source art become more 3D while staying deterministic?":

- low-detail NPCs;
- simple droids;
- social-scene background actors;
- body-plan exploration before Blockbench polish;
- future rigid-part animation contracts.

Current proof:

```text
PIXEL_HULL_CHARACTER_PASS.md
generated/godot_pixel_hull_character_v0/REVIEW.md
```

Why:

- zero credits;
- original project-owned front/side source cards;
- true voxel visual hull instead of continuous AI mesh;
- useful answer to the owner's "flat characters/equipment but more 3D" concern.

Boundary:

Whole-body hulls are research/background assets. Foreground characters need body-part cards or Blockbench.

### Vengi Bridge Lane

Use this when a pixel-card or voxel asset needs a local voxel-editor/converter bridge:

- PNG source card to `.vox`;
- manual cleanup in Vengi or another voxel editor;
- future format conversion experiments.

Current proof:

```text
VENGI_PIXEL_CARD_EVAL_PASS.md
generated/vengi_pixel_card_eval_v0/REVIEW.md
```

Why:

- free/local;
- installed at `C:\Program Files\vengi`;
- `.vox` output gives humans a voxel-editor handoff format.

Boundary:

Vengi is not yet the default runtime asset lane. The successful GLB path is flat textured mesh, while the image-volume and `.bbmodel` probes need further debugging.

### Meshy Salvage / Reference Lane

Do not use Meshy as a default foreground voxel asset source.

The foreground tests now show the same pattern repeatedly: Meshy can create recognizable low-poly or chunky analog forms, but those forms are not discrete cube-grid blockcraft. They look jarring beside the deterministic voxel/Blockbench lanes.

Rejected direct-runtime families:

- characters;
- droids;
- weapons and equipment;
- nearby vehicles and ships;
- buildings and modular terrain;
- Cantina furniture and foreground props.

Possible remaining uses:

- background plates;
- sky/horizon/far-settlement renders;
- space ambience: planets, moons, nebulae, far debris, distant station silhouettes;
- VFX reference for Godot-native sprites, shaders, particles, or billboards;
- rebuild-only reference for high-entropy shape language.

Why:

- it may still buy atmosphere and shape ideas cheaply;
- analog shapes are less jarring when pushed into distant/background layers;
- a rendered/posterized plate can be made stylistically subordinate to the voxel identity layer.

Boundary:

```text
Meshy output is not foreground runtime art.
It is background/reference material unless a focused A/B proves otherwise.
```

## Aesthetic Lockstep

Meshy and hand-rolled assets can coexist only if they share a narrow grammar:

- chunky cuboid macro-shapes;
- readable silhouettes at gameplay camera distance;
- exaggerated feature zones instead of realistic fine detail;
- low material count;
- no photoreal texture noise;
- consistent warm desert plaster, dark metal, cyan/amber status lights, and faction-color accents;
- panels and greebles that can be rebuilt as cubes if the direct GLB is rejected.

The immediate calibration loop is:

```text
same asset family
  -> hand-rolled Blockbench baseline
  -> Meshy lowpoly preview
  -> Meshy stricter lowpoly/voxel prompt
  -> Godot side-by-side proof
  -> keep direct, rebuild from reference, or reject
```

Do not compare Meshy screenshots in isolation. The provider thumbnail can look good while the imported Godot model feels like a different game.

If the problem is strict voxel geometry, do not spend Meshy credits first. Try:

```text
original pixel/SVG source card -> Godot pixel extrusion -> Godot capture
```

Meshy image-to-3D was tested with an original blockcraft droid source card. It preserved the rough silhouette for 5 credits, but softened the cube grammar and fused the source floor into the mesh. That confirms it is an AI mesh interpretation lane, not a voxel-grid solution.

## Lowpoly vs Standard

The owner is right that `model_type: "lowpoly"` sounds more appropriate for the target than `standard`.

Current interpretation:

- `lowpoly` is the style-first Meshy route.
- `standard` is not the current aesthetic default.
- `standard` may still be useful as a cheap/control probe or for later remesh/cleanup tests, but it should not replace lowpoly without an A/B win.

Important Meshy docs detail checked on 2026-07-04:

```text
When lowpoly is selected, ai_model, topology, target_polycount, and should_remesh are ignored.
```

That means lowpoly is not just "standard with fewer polygons." It is a separate generation path with fewer tunable knobs. The next fair style test should therefore change only the prompt while staying in lowpoly, not jump to standard.

## Meshy 5 Draft Variants

The owner found a useful Meshy 5 Legacy Workspace note:

```text
Model stage generates 4 draft variants for 10 credits.
Low Poly costs 20 credits.
Texture costs 10 credits.
```

That may be valuable, but for a different job than lowpoly.

Observed v2 API result on 2026-07-04:

```text
model_type: "standard", ai_model: "meshy-5"
-> consumed 5 credits
-> returned one GLB in model_urls.glb
-> no drafts or variants fields were present in the task object
```

So the four-draft behavior may be a legacy web/Creative Lab workflow or a different endpoint/mode. It is not what the current Text-to-3D v2 API returned in this test.

Use Meshy 5 draft variants for:

- silhouette exploration;
- picking a best composition before spending polish credits;
- finding greeble placement ideas;
- identifying which prompt words matter;
- feeding a rebuild/repair pass in Blockbench or Blender.

If a four-draft API path is later found, do not use those drafts as proof that the direct output is style-compatible. The likely workflow is:

```text
4 Meshy 5 drafts
  -> pick one silhouette
  -> write a grammar card
  -> rebuild in Blockbench, or repair/normalize in Blender if the GLB is unusually strong
  -> Godot proof beside the kept baseline
```

This is within Codex's wheelhouse if "fixing" means:

- normalize scale, origin, rotation, and materials;
- inspect GLB topology;
- delete obvious stray pieces;
- use Blender/glTF tooling for cleanup and validation;
- rebuild the useful silhouette as cubes in Blockbench.

It is less reliable if "fixing" means sculpting a messy generated model into polished production art by hand. That remains more of a human 3D artist task.

## Texture / Refine Reality

Meshy preview output is geometry-first and will look like clay. Godot can render polished textured games, but only when the imported models actually have useful materials/textures and the scene has tuned lighting and post-processing.

Observed refine test:

```text
meshy_cantina_service_terminal_meshy5_draft_v1
-> refine_v1
```

Cost:

```text
5 credits preview + 10 credits refine = 15 credits total
```

Result:

- GLB validated cleanly.
- Base-color texture imported into Godot.
- Provider thumbnail became much stronger.
- Godot material-preserving proof shows texture survives runtime import.
- Style is still softer than Blockbench/cubecraft, so this is a candidate texture/refine lane, not a replacement for authored identity modules.

Detailed pass:

```text
MESHY_TEXTURE_REFINE_PASS.md
```

## Free Retries and Refunds

From the owner's UI screenshot:

- Meshy-side technical failures should be automatically refunded.
- Cancelling while still waiting in queue should refund.
- Successful generations that disappoint are not refunded; the web UI offers plan free retries.

Important API boundary checked against Meshy's help center:

```text
The Meshy API does not currently support retry functionality for individual or studio teams.
```

So:

```text
Use free retries manually in the Meshy web app.
Assume API resubmits consume credits normally.
```

Reference:

```text
https://help.meshy.ai/en/articles/9992034-does-the-meshy-api-support-retry-for-generations
```

## Credit Notes From Owner Screenshots

Current balance shown:

```text
3,080 credits remaining
```

Potential onboarding bonus:

```text
300 credits
```

Likely useful cost assumptions from the visible API price panel:

| Task | Visible cost |
| --- | ---: |
| Text to 3D preview, Meshy 6 | 20 credits |
| Text to 3D preview, other models | 10 credits |
| Meshy 5 model stage, legacy workspace | UI note says 10 credits for 4 draft variants |
| Meshy 5 preview through v2 API, observed | 5 credits for one GLB |
| Text to 3D refine / texture generation | 10 credits |
| Image to 3D, Meshy 6, without texture | 20 credits |
| Image to 3D, Meshy 6, with texture | 30 credits |
| Image to 3D, other models, without texture | 5 credits |
| Image to 3D, other models, with texture | 15 credits |
| Text to 3D refine / observed texture pass | 10 credits |
| Retexture | 10 credits |
| Remesh | 5 credits |
| Auto-rigging | 5 credits |
| Animation | 3 credits |

The first API preview consumed:

```text
20 credits
```

Given the request body used `model_type: "lowpoly"`, and the price screen shows Meshy 6 previews at 20 credits, treat that first call as the more expensive preview bucket. It may still be the correct bucket if quality is better.

## Onboarding Bonus Plan

The bonus tasks are worth considering if they are paired with useful pipeline tests. Do not burn credits just to clear badges.

Potentially useful tasks:

| Onboarding task | Pipeline value | Suggested use |
| --- | --- | --- |
| Generate 3D from an AI image | Tests image-to-3D after a controlled concept card | Use on one style-card image for a hero prop or alien, not a random asset |
| Create a private-license model | Clarifies ownership/export mode | Do once on a kept candidate if the UI/API exposes the flag clearly |
| Queue 3 tasks at once | Tests batch discipline | Queue three tiny controlled prompt variants only after the prompt grammar is stable |
| Try Free Retry | Tests recovery workflow | Use only on a clearly bad generation that would otherwise be rejected |
| Remesh your model | Tests cleanup path | Use on one promising but messy GLB, not on rejected geometry |
| Add 3 animations | Tests rig/animation cost | Use only after the humanoid rig contract exists; otherwise the result will not answer the real question |

If the tasks can be completed for substantially less than 300 credits total, they are probably worth doing. Best target:

```text
Spend under 100-150 credits on bonus-clearing experiments that also answer real pipeline questions.
```

## Budget Guardrails

Use this rough allocation for the remaining credit pool:

| Lane | Suggested credits | Purpose |
| --- | ---: | --- |
| Style calibration | 100-200 | Lowpoly prompt variants, one image-to-3D test, one remesh test |
| Characters / aliens | 600-900 | Highest leverage if Meshy can produce usable body-plan references |
| Ships / vehicles | 500-800 | Worth testing, but promote only if Godot tactical camera reads well |
| Buildings / landmarks | 400-700 | Use for hero facades and irregular dressing, not full modular kits |
| Animation / rig experiments | 150-300 | Only after the rig request protocol is stable |
| Reserve | 1,000+ | Do not spend down before the style lock is proven |

## Current Recommendation

1. Keep Blockbench/Godot as the locked production lane.
2. Keep Meshy as a preview-first candidate lane.
3. Keep Godot pixel-extrude as the zero-credit true-voxel lane for pickups, signs, terminals, and tactical tokens.
4. Keep Godot pixel-hull as a zero-credit research lane for low-detail actors and body-plan exploration.
5. Keep Vengi as a free `.vox` bridge/manual-cleanup lane, not a Blender/Godot replacement yet.
6. Run the next Meshy test only when the asset is high-entropy or when image-to-3D with our own blockcraft source card answers a question pixel extrusion cannot.
7. Treat observed Meshy 5 v2 API as a cheap one-GLB option-mining lane; keep searching only if a true four-draft API path appears.
8. Use onboarding tasks only when they also test a pipeline question.
