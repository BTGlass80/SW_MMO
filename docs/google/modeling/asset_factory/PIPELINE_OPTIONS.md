# Pipeline Options

## Summary

The right pipeline is modular. No single tool should own all art creation.

Recommended stack:

```text
Spec grammar first.
Godot generator for cheap procedural assets.
Kenney/Quaternius for free CC0 kitbash.
Blockbench for Cubecraft source models.
Blender for automated GLB export and review renders.
Meshy/Tripo for selective draft generation.
Human technical artist for hero assets and cleanup.
```

## Option A: Godot Procedural Factory

Cost: free  
Automation: high  
Quality ceiling: low to medium  
Best for: blockouts, cover, props, simple buildings, tactical space markers

Pros:

- Runs now.
- No new tools.
- Produces Godot `.tscn` scenes directly.
- Easy to render contact sheets.
- Deterministic and reviewable.

Cons:

- Not standalone GLB.
- Limited mesh expressiveness.
- Can look toy-like without strong style discipline.

Use this for:

- early Mos Eisley prop grammar;
- cover objects;
- vendor stalls;
- simple buildings;
- isometric space tokens;
- sensor rings;
- encounter set dressing.

## Option B: Kenney/Quaternius Kitbash

Cost: free / CC0  
Automation: medium  
Quality ceiling: medium  
Best for: fast prototype improvement

Pros:

- Already partially integrated.
- License-clean.
- Godot-friendly GLB/glTF in many packs.
- Cohesive if one house style is chosen.

Cons:

- Kenney can look toy-like.
- Quaternius can clash with Kenney.
- Needs material/scale normalization.
- Does not solve distinctive Star Wars-like silhouettes by itself.
- Raw kit pieces can break cohesion when placed beside custom Blockbench characters/ships.

Use:

- Kenney as normalized filler and background massing first.
- Quaternius selectively for gaps: characters, creatures, mechs, some ships.

Rule:

Do not mix raw vendors casually. Normalize material palette and scale first.

Stronger rule after the Blockbench tests:

```text
Kenney is filler clay, not the identity layer.
```

Use Kenney for background buildings, crates, pipes, machinery, stalls, and set dressing. Do not use raw Kenney for hero characters, ships, weapons, or landmark pieces. If a Kenney building is important, wrap it in custom Blockbench identity pieces: rounded door caps, dome roofs, antenna masts, pipes, awnings, faction panels, and landing-pad trim. Review it in the same screenshot as a kept Blockbench character or ship; if the packs visibly clash, reject or restyle it.

## Option C: Blender Python Generator

Cost: free  
Automation: high  
Quality ceiling: medium  
Best for: actual reusable GLB model generation from specs

Pros:

- Can export real GLB files.
- Full control over mesh, origin, scale, names, materials.
- Good bridge between code and production assets.
- Can generate contact sheets using Godot after import.

Cons:

- More complex script environment.
- Needs conventions for pivots, materials, and collision.

Current status:

Blender 5.1.2 portable is installed under:

```text
C:\Users\btgla\AppData\Local\CodexTools\blender-5.1.2\blender-5.1.2-windows-x64\blender.exe
```

The direct Blender generator in `adapters/blender_lowpoly_generator.py` remains a draft. The tested Blender lane is now `adapters/blender_bbmodel_to_glb.py`, which converts generated Blockbench `.bbmodel` files into GLB candidates and renders review previews.

## Option D: Blockbench

Cost: free/open source  
Automation: medium to high when paired with the generator/Blender adapter  
Quality ceiling: medium  
Best for: Cubecraft/Minecraft-like models, simple creatures, simple animations

Pros:

- Easier than Blender for blocky assets.
- Friendly for non-modelers.
- glTF export works for Godot use cases.
- Good fit for constrained blocky art.

Cons:

- Complex rigs still need care.
- Another tool in the workflow.

Best use:

Use AI/Codex to generate `.bbmodel` source files from strict specs, then let a human/non-modeler edit winners in Blockbench. Batch-convert those sources through Blender for GLB export and validation.

Current tested path:

```text
specs/blockbench_cubecraft_v0.json
  -> scripts/blockbench_cubecraft_factory.mjs
  -> generated/blockbench_cubecraft_v0/blockbench/*.bbmodel
  -> adapters/blender_bbmodel_to_glb.py
  -> generated/blockbench_cubecraft_v0/glb/*.glb
  -> gltf-transform validate
```

See `BLOCKBENCH_CUBECRAFT_PIPELINE.md`.

## Option E: Meshy / Tripo / Similar APIs

Cost: paid credits now available for Meshy Premium testing  
Automation: high  
Quality ceiling: variable  
Best for: drafting unusual props, creatures, hero object exploration

Pros:

- Can generate GLB-like assets from text/image.
- Good for fast ideation.
- APIs can be integrated later.

Cons:

- Output quality varies.
- Topology may be messy.
- Style control is weaker than a strict grammar.
- Licensing/commercial/private-use terms must be reviewed.
- Generated models often need cleanup.

Best use:

Not for everything. Use for:

- creature drafts;
- hero props;
- unusual silhouettes;
- alternate ship concepts;
- inspiration that is then normalized manually.

Current Meshy status:

```text
generated/meshy_eval_v0/REVIEW.md
```

The first premium preview produced a clean GLB for a Cantina service-terminal prop at 20 credits. It is a candidate lesson keep: useful shape language, not cohesive enough as a direct blockcraft runtime asset.

Updated rule:

```text
preview first, no auto-refine
```

Refine only if preview geometry wins against a named baseline in thumbnail, validation, and Godot proof.

## Option F: Human Technical Artist

Cost: not free  
Automation: low  
Quality ceiling: high  
Best for: final polish, distinctive characters, creatures, rigs, animations

Pros:

- Solves the hard cases.
- Can normalize AI/free-asset output.
- Can build reusable style guides and kits.

Cons:

- Costs money.
- Needs direction and scope discipline.

Best use:

Hire only after the style grammar is chosen. A clear grammar makes a human artist much cheaper and more effective.

## Recommended Hybrid

Phase 1:

- Godot procedural factory.
- Kenney kitbash.
- Contact sheets after every generation.

Phase 2:

- Blockbench source generation plus Blender GLB export.
- Quaternius normalization.
- One polished Mos Eisley hero slice.

Phase 3:

- Meshy/Tripo API experiments for 10 high-value difficult assets.
- Human cleanup only for winners.

Phase 4:

- Promote accepted assets into `assets/3d/generated` or runtime scene folders with manifest provenance.

## Reference Links

Checked on 2026-07-03:

- Godot 3D scene import supports glTF/GLB workflows: <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html>
- Blender Python has GLTF/GLB export operators suitable for automation: <https://docs.blender.org/api/current/bpy.ops.export_scene.html>
- Blockbench documents glTF and other export formats: <https://www.blockbench.net/wiki/guides/export-formats/>
- Meshy exposes an API product for AI 3D generation: <https://www.meshy.ai/api>
- Meshy image-to-3D API documentation: <https://docs.meshy.ai/en/api/image-to-3d>
- Tripo publishes current pricing/free-tier information: <https://www.tripo3d.ai/pricing>
