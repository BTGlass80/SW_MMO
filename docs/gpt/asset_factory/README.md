# GPT Asset Factory Prototype

Date: 2026-07-03  
Scope: docs-only prototype under `docs/gpt`; does not change live game scenes

## Purpose

This folder prototypes a modular graphics-creation pipeline for the MMO. The goal is to turn art direction into a repeatable asset process that can be run by Codex, Claude, or a human technical artist.

The key idea is to stop asking for "better graphics" and start asking for structured assets:

```text
asset spec -> generator lane -> normalized Godot artifact -> rendered contact sheet -> owner approval -> promotion into runtime
```

## Why This Matters

A Minecraft/Cubecraft-style project can be produced quickly with AI because the modeling problem is heavily constrained. A constrained style becomes a grammar:

- simple shapes;
- flat palette;
- fixed scale;
- repeated silhouettes;
- clear collision boxes;
- few materials;
- reusable parts.

That is why a solo developer can make something that looks coherent quickly. The trick is not that AI is secretly a great production modeler. The trick is that the art style makes modeling closer to code.

This factory explores that approach for a Clone Wars-inspired WEG MMO without using trademarked asset sources.

## What Is Included

- `STYLE_GRAMMAR.md`
  - Proposed chunky low-poly / space-opera frontier visual grammar.

- `PIPELINE_OPTIONS.md`
  - Free/cheap pipeline options, from Godot-only generation to Blender, Blockbench, Kenney/Quaternius, Meshy, and Tripo.

- `MESHY_PREMIUM_EVALUATION.md`
  - Meshy Premium/API evaluation lane.
  - Current rule: preview-first, no auto-refine, never write the API key into repo files.

- `MESHY_CREDIT_AND_TIER_STRATEGY.md`
  - Credit and lane strategy for Meshy Premium.
  - Current rule: use Meshy for high-entropy/hard-to-author assets, not automatically for every high-impact asset.
  - Captures the lowpoly-vs-Meshy-5-draft distinction and the owner's 300-credit onboarding opportunity.

- `MESHY_TEXTURE_REFINE_PASS.md`
  - First Meshy refine/texture test.
  - Shows why previews looked like clay, confirms refined textures import into Godot, and records the API free-retry limitation.

- `MESHY_SALVAGE_LANES.md`
  - Current post-test Meshy verdict.
  - Meshy is rejected as a default foreground voxel asset source; possible remaining use is background plates, space ambience, VFX reference, and rebuild-only reference.

- `PIXEL_VOXEL_PRODUCTION_STRATEGY.md`
  - Current tactical pivot after the Meshy/voxel tests.
  - Default stance: pixel/GDScript first for deterministic voxel grammar across props, actors, ships, vehicles, buildings, terrain, and rooms; Blockbench/manual cleanup for hero polish; Meshy in reserve for background/space/reference experiments.

- `PIXEL_EXTRUDE_GODOT_PASS.md`
  - First Godot-native test of Gemini's Option 3: 2D pixel source image -> strict cube-grid Godot model.
  - Candidate keep for true voxel props, wall panels, signs, pickups, and isometric tactical ship tokens.
  - Shows that same-color run merging preserves the source silhouette while reducing cube count sharply.

- `PIXEL_HULL_CHARACTER_PASS.md`
  - First deterministic more-3D humanoid test: front pixel card + side pixel card -> voxel visual hull.
  - Candidate research keep for low-detail NPCs, body-plan exploration, and future rigid-part animation contracts.

- `PIXEL_HULL_BODY_PARTS_PASS.md`
  - Follow-up deterministic actor test: front/side cards per body part -> separate voxel hull nodes -> neutral, rifle-ready, cover, and rotation proof.
  - Candidate keep for low-detail/background actors and animation request proofs; not a replacement for Blockbench hero rigs.

- `PIXEL_CANTINA_KIT_PASS.md`
  - Deterministic pixel/GDScript test for Cantina room kits.
  - Candidate keep for layout, collision, LOD, room-graph visualization, and cheap filler: a 48x32 semantic card merged from 966 pixels to 74 rectangles and 8 material-batched mesh nodes.

- `PIXEL_CANTINA_LAYERED_KIT_PASS.md`
  - Follow-up layered semantic pixel room-kit test.
  - Candidate keep: floorplan card + detail/elevation card adds arches, frames, booth backs, lamps, pipes, sockets, raised strips, and sign hooks while staying efficient: 1,107 source pixels -> 101 rectangles -> 16 material-batched mesh nodes.

- `PIXEL_CANTINA_RUNTIME_PASS.md`
  - Runtime utility proof for the layered semantic Cantina cards.
  - Candidate keep: same cards now emit walk masks, collision masks, merged collision shapes, named sockets, socket-to-walk-cell resolution, and grid-routed actor probes.

- `PIXEL_ROOM_RUNTIME_ADAPTER_PASS.md`
  - Reusable external-card adapter proof for semantic pixel room cards.
  - Candidate keep: the same Cantina runtime outputs now come from `specs/pixel_room_cantina_runtime_adapter_v0.json` instead of hard-coded GDScript room data.
  - Follow-up keep: the same spec now carries explicit socket roles/facing/actions for seats, standing/spawn anchors, use/inspect prompts, cover anchors, transitions, props, and lights.

- `VENGI_PIXEL_CARD_EVAL_PASS.md`
  - First local Vengi 0.5.0 evaluation after the owner installed it.
  - Candidate bridge keep: PNG source cards can become `.vox` or flat GLB, but Godot run-merged extrusion still wins for true in-engine voxel props.

- `CLAUDE_HANDOFF.md`
  - Practical review notes for Claude.

- `ASSET_REQUEST_PLAYBOOK.md`
  - Operating manual for Claude/Codex asset requests.
  - Defines when to use descriptions, SVG contracts, fan-art/reference lessons, Blockbench, Blender, Godot, Kenney filler, and GLB validation.
  - Current best answer to "what should Codex do when Claude asks for an asset?"

- `REFERENCE_BASE_COMPARISON.md`
  - Direct answer to whether current work is game-based or fan-art based.
  - Locks the hybrid reference split: game/descriptions for playable geometry, fan art/reference boards for mood and silhouette lessons, blockcraft grammar for final models.

- `PIPELINE_DECISION_LOG.md`
  - Lock/candidate/rejected decisions for the asset factory.
  - Current answer to "set the method in stone": Blockbench is locked for foreground identity assets after blockout; Godot is locked for blockouts, camera proofs, terrain tests, and tactical overlays.

- `ANIMATION_REQUEST_PROTOCOL.md`
  - Protocol for Claude/Codex animation requests.
  - Splits scene interactions from character action clips so Cantina social poses do not get confused with full clone-trooper locomotion/combat rigs.

- `generated/REVIEW.md`
  - Visual review index for the latest generated contact sheets and individual thumbnails.

- `PRIVATE_SW_AUTHENTICITY_PASS.md`
  - Private/friends Clone Wars blockcraft lane after owner clarified that SW authenticity is the priority.

- `PRIVATE_SPACECRAFT_PASS.md`
  - Private/friends isometric 2.5D spacecraft lane for the owner's "flat x/y, isometric view" space vision.

- `BLOCKBENCH_CUBECRAFT_PIPELINE.md`
  - Tested alternate pipeline: JSON spec -> Blockbench `.bbmodel` -> Blender `.glb` export -> glTF validation.
  - Current best route for "Star Wars Minecraft" character/small-prop production.

- `SHIP_MICROFIGHTER_PASS.md`
  - Focused ship-only Blockbench/Blender pass after the owner questioned whether Godot JSON was actually better for ships.
  - Current recommendation: Blockbench/Blender for ship silhouettes, Godot procedural for tactical overlays.

- `MODEL_RESTYLE_BACKLOG.md`
  - Production map for restyling characters, ships, buildings, weapons, props, creatures, and tactical UI in the new blockcraft direction.
  - Includes the Kenney cohesion rule: use Kenney as normalized filler clay, not as the identity layer.

- `REFERENCE_IMAGE_WORKFLOW.md`
  - Practical workflow for using online, LEGO-like, fan-art, and concept references as silhouette/grammar input without copying geometry, textures, logos, or exact protected designs.

- `TERRAIN_CANTINA_REFERENCE_PASS.md`
  - Terrain/worldbuilding workflow for comparing fan-art mood references against SW_MUSH multi-room descriptions/YAML.
  - Clarifies that SW_MUSH does not provide SVGs here; Codex/Claude should create internal SVG contracts from descriptions and room data.

- `CANTINA_TERRAIN_KIT_PASS.md`
  - First docs-only Godot terrain-kit pass for the Cantina after the SVG/reference pass.
  - Includes a focused V1 entrance-detail excursion that improves Minecraft-like granularity and is kept as the current entrance baseline.

- `CANTINA_BLOCKBENCH_ENTRANCE_PASS.md`
  - Converts the kept Cantina V1 entrance proof into editable Blockbench `.bbmodel` and Blender `.glb`.
  - Current editable baseline for Cantina entrance art.

- `CANTINA_MOOD_AB_PASS.md`
  - First lighting/material/clutter-only A/B for the kept Cantina entrance GLB.
  - Candidate keep: warmer exterior, darker doorway, grime, pipes, and clutter improve mood without changing entrance geometry.

- `CANTINA_SIGN_TEXTURE_PASS.md`
  - First texture/manual sign workflow test for the kept Cantina entrance.
  - Candidate keep: an original pixel-texture no-droids panel beats the cube-only sign and validates cleanly.

- `CANTINA_EXTERIOR_CLUTTER_KIT_PASS.md`
  - Converts the mood-pass exterior proof clutter into reusable Blockbench `.bbmodel` modules and clean GLBs.
  - Candidate keep: pipe cluster, utility box, crate/scrap stack, and dust berm survive Godot camera proof beside the kept entrance.

- `CANTINA_BAR_BOOTH_BAY_PASS.md`
  - Converts the main-bar/booth-bay proof into editable Blockbench `.bbmodel` and clean GLB form.
  - Candidate keep: segmented booth backs, bar panels, service taps, bartender/owner booth proxies, and Godot A/B proof improve the main-bar social read.

- `CANTINA_SEATED_SOCIAL_ANIMATION_PASS.md`
  - First docs-only animation request/proof pass.
  - Candidate protocol keep: a kept Cantina bar/booth GLB plus procedural seated actors, named anchors, keyframe captures, and a saved Godot `AnimationPlayer` proof scene.

- `generated/meshy_eval_v0/REVIEW.md`
  - First Meshy Premium preview test.
  - Candidate lesson keep: clean GLB and useful sci-fi shape language, but not cohesive enough for direct runtime use without cleanup or Blockbench rebuild.

- `requests/README.md`
  - Shared filesystem request queue for Claude/Codex asset work.
  - Claude can create focused request files in `requests/inbox/`; Codex can generate docs-only artifacts and answer in `requests/completed/` or `requests/rejected/`.

- `requests/FEEDBACK_TEMPLATE.md`
  - Shared feedback template for Claude/Codex/human notes after artifacts are tested.
  - Use `requests/feedback/inbox/` for "this worked," "this broke," "runtime needs changed," or "make this the baseline" feedback.

- `requests/ANIMATION_REQUEST_TEMPLATE.md`
  - Focused request template for scene-interaction, character-action, and vehicle/tactical animation asks.

- `codex_skill_draft/SKILL.md`
  - Draft, uninstalled Codex skill for this asset-factory process.
  - Keep it as a draft until the process survives several real Claude requests and owner review.

- `specs/mos_eisley_chunky_v0.json`
  - Example asset specs for a first test pack.

- `scripts/godot_asset_factory.gd`
  - Working Godot-native generator.
  - Reads the JSON spec.
  - Generates `.tscn` asset scenes.
  - Generates preview gallery scenes.
  - Renders PNG contact sheets.

- `scripts/run_godot_factory.ps1`
  - Convenience runner for Godot 4.6.3 on this machine.

- `adapters/blender_lowpoly_generator.py`
  - Draft Blender adapter for future GLB export.
  - Early direct-Blender generation sketch.

- `adapters/blender_bbmodel_to_glb.py`
  - Tested Blender adapter for converting generated Blockbench `.bbmodel` sources to `.glb`.

- `adapters/API_ADAPTER_CONTRACT.md`
  - Adapter contract for Meshy/Tripo or other paid/free API services.

## Working Lanes Today

The original locally testable lane is:

```text
JSON asset spec
  -> Godot procedural generator
  -> generated .tscn asset scenes
  -> generated preview gallery .tscn scenes
  -> PNG contact sheets rendered by Godot
```

This does not produce standalone GLB files. It produces Godot scenes that behave like reusable model prefabs. That is still useful because the current project is Godot-based and because it lets us test the asset grammar immediately.

For true GLB export, the next lane is Blender Python:

```text
JSON asset spec
  -> Blender Python generator
  -> GLB export
  -> Godot import
  -> contact sheet
```

That direct-Blender lane is no longer the only GLB route. The newly tested Blockbench lane is:

```text
JSON blockcraft spec
  -> generated Blockbench .bbmodel source
  -> generated fast PNG preview
  -> Blender headless conversion
  -> GLB file
  -> Blender-rendered GLB preview
  -> glTF validation
```

This lane is the current recommendation for character and small-prop work.

## First Run

From the project root:

```powershell
.\docs\gpt\asset_factory\scripts\run_godot_factory.ps1
```

Or directly:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_asset_factory.gd
```

Expected outputs:

- `generated/scenes/*.tscn`
- `generated/review_scenes/*.tscn`
- `generated/captures/*.png`
- `generated/captures/assets/*.png`
- `generated/factory_manifest.json`

## Latest Tested Pass

Tested locally in Godot 4.6.3 on 2026-07-03.

The original chunky pack currently generates:

- 7 Godot `.tscn` asset scenes;
- 7 individual review scenes;
- 7 individual PNG review captures;
- 3 contact sheets: all, ground, and isometric space;
- 1 manifest with scene/capture paths.

Open `generated/REVIEW.md` for the visual review board.

The newer blockcraft pass is in `generated/blockcraft_space_opera_v0/` and currently generates:

- 11 Godot `.tscn` asset scenes;
- 11 individual review captures;
- contact sheets for all, ground, and isometric space;
- a generated `REVIEW.md`;
- a micro-slice capture intended to test the "space-opera Minecraft" direction.

Open `generated/blockcraft_space_opera_v0/REVIEW.md` first when judging that direction.

The private Clone Wars blockcraft pass is in `generated/private_clone_wars_blockcraft_v0/` and currently generates:

- 11 Godot `.tscn` asset scenes;
- 11 individual review captures;
- contact sheets for all, ground, space, characters, and scene slices;
- a generated `REVIEW.md`;
- a stronger private-fan Clone Wars read: clone rifleman/commander/heavy, Jedi support, B1/B2 droids, rolling shield threat, modular gate kit, outpost slice, gunship token, and isometric space skirmish.

Open `PRIVATE_SW_AUTHENTICITY_PASS.md`, then `generated/private_clone_wars_blockcraft_v0/REVIEW.md`, when judging the "Star Wars Minecraft" direction for this private project.

The private spacecraft pass is in `generated/private_clone_wars_spacecraft_v0/` and currently generates:

- 7 Godot `.tscn` asset scenes;
- 7 individual review captures;
- contact sheets for all, space, and scene slices;
- a generated `REVIEW.md`;
- a focused test of isometric 2.5D tactical space with friendly fighters, hostile droid craft, a freighter, and a combat tableau.

Open `PRIVATE_SPACECRAFT_PASS.md`, then `generated/private_clone_wars_spacecraft_v0/REVIEW.md`, when judging the space layer.

The Blockbench Cubecraft excursion is in `generated/blockbench_cubecraft_v0/` and currently generates:

- 5 editable Blockbench `.bbmodel` sources;
- 5 Blender-converted `.glb` files;
- 5 fast Node review previews;
- 5 Blender-rendered GLB previews;
- a generated `REVIEW.md`;
- a generated `GLB_REVIEW.md`;
- a clean `gltf-transform validate` pass for `cubecraft_clone_rifleman_01.glb`.

Open `BLOCKBENCH_CUBECRAFT_PIPELINE.md`, then `generated/blockbench_cubecraft_v0/REVIEW.md` and `generated/blockbench_cubecraft_v0/GLB_REVIEW.md`, when judging the Cubecraft/Blockbench route.

The ship microfighter pass is in `generated/blockbench_ship_micro_v1/` and currently generates:

- 4 editable Blockbench `.bbmodel` ship sources;
- 4 Blender-converted `.glb` ship files;
- 4 fast Node review previews;
- 4 Blender-rendered GLB previews;
- a generated `REVIEW.md`;
- a generated `GLB_REVIEW.md`;
- a clean `gltf-transform validate` pass for `micro_arc_interceptor_v1.glb`.

Open `SHIP_MICROFIGHTER_PASS.md`, then `generated/blockbench_ship_micro_v1/GLB_REVIEW.md`, when judging whether the ship lane improved.

The hostile droid v2 follow-up is in `generated/blockbench_ship_droid_v2/` and currently generates:

- 1 editable Blockbench `.bbmodel` source;
- 1 Blender-converted `.glb` file;
- fast and Blender-rendered previews;
- a generated `GLB_REVIEW.md`;
- a clean `gltf-transform validate` pass for `micro_tri_droid_stalker_v2.glb`.

Open `generated/blockbench_ship_droid_v2/GLB_REVIEW.md` when judging the one-variable hostile ship improvement. This should replace the v1 droid ship as the hostile baseline.

The friendly ship panel v2 follow-up is in `generated/blockbench_ship_panel_v2/` and currently generates:

- 1 editable Blockbench `.bbmodel` source;
- 1 Blender-converted `.glb` file;
- fast and Blender-rendered previews;
- a generated `GLB_REVIEW.md`;
- a clean `gltf-transform validate` pass for `micro_arc_interceptor_panel_v2.glb`.

Open `generated/blockbench_ship_panel_v2/GLB_REVIEW.md` when judging whether Minecraft-like panel detail improved the friendly ship. This should replace the v1 ARC-style ship as the friendly baseline before runtime camera testing.

The Godot Phase 0 camera proof is in `generated/godot_phase0_camera_v0/` and currently generates:

- 3 docs-only Godot review scenes;
- 3 Godot-rendered captures;
- a generated `REVIEW.md`;
- a direct GLTFDocument import path for the kept Blockbench/Blender GLBs.

Open `generated/godot_phase0_camera_v0/REVIEW.md` when judging whether the kept GLBs survive Godot camera/lighting. Current verdict: partial keep. Space and mixed-scale captures are promising; ground characters need a focused contrast/detail pass before runtime promotion.

The all-model planning docs are:

- `ASSET_REQUEST_PLAYBOOK.md`
- `REFERENCE_BASE_COMPARISON.md`
- `PIPELINE_DECISION_LOG.md`
- `MODEL_RESTYLE_BACKLOG.md`
- `REFERENCE_IMAGE_WORKFLOW.md`
- `TERRAIN_CANTINA_REFERENCE_PASS.md`
- `requests/README.md`

Open these before trying to restyle the full game. They define the recommended division of labor: deterministic pixel/GDScript first for strict voxel grammar, Blockbench/Blender for hero cleanup and foreground editability, normalized Kenney for filler, Godot procedural for overlays/review/runtime proofs, and Meshy/API/human help only for hard salvage/background/reference cases.

The current reference-basis ruling is:

```text
game/SW_MUSH/project descriptions -> geometry and play affordances
fan art/reference boards -> mood, silhouette, color, and density lessons
Blockbench/Godot blockcraft grammar -> original generated asset
```

The current pipeline ruling is:

```text
Pixel/GDScript is the preferred first question for strict voxel assets and runtime-adjacent room data.
Blockbench remains the default cleanup/editable source for hero identity assets after a pixel/blockout proof.
Godot remains the runtime test bench for generated voxel geometry, room masks, tactical overlays, review scenes, and camera/import proofs.
```

The current terrain reference artifact for the Cantina is:

```text
generated/cantina_terrain_reference_v0/REVIEW.md
```

It includes our own description-derived SVGs, including a source-comparison SVG and a multi-room graph SVG.

The first generated Cantina terrain-kit proof is:

```text
generated/cantina_terrain_kit_v0/REVIEW.md
```

The current kept entrance-detail baseline is:

```text
generated/cantina_entrance_detail_v1/ITERATION_REVIEW.md
```

The current editable Blockbench/GLB entrance baseline is:

```text
generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md
```

The current Godot camera/import proof for that entrance GLB is:

```text
generated/godot_cantina_entrance_camera_v1/REVIEW.md
```

The current Cantina mood A/B candidate is:

```text
generated/cantina_mood_ab_v1/REVIEW.md
```

The current no-droids sign workflow candidate is:

```text
generated/godot_cantina_sign_texture_v1/REVIEW.md
```

The current reusable Cantina exterior-clutter kit candidate is:

```text
generated/godot_cantina_exterior_clutter_kit_v1/REVIEW.md
```

The current editable Cantina main-bar/booth-bay candidate is:

```text
generated/godot_cantina_bar_booth_bay_v1/REVIEW.md
```

The current animation request/proof candidate is:

```text
generated/godot_cantina_seated_social_anim_v0/REVIEW.md
```

It proves the first scene-interaction lane: seated Cantina actors, named anchors, key poses, and a saved Godot `AnimationPlayer` proof scene. It does not yet prove a full Blender/glTF humanoid combat rig.

The current Meshy Premium/API candidate is:

```text
generated/meshy_eval_v0/REVIEW.md
```

It proves Meshy can quickly produce clean GLB concept geometry for a Cantina service terminal. Later voxel tests rejected Meshy as a direct foreground voxel source; hold it in reserve for space/background/VFX/reference ideas.

The current Meshy strategy doc is:

```text
MESHY_CREDIT_AND_TIER_STRATEGY.md
```

It records the latest owner question: Meshy 5 draft variants may be useful if four drafts cost 10 credits and Codex/Claude then pick the best silhouette to rebuild or repair. That is a different lane from `model_type: "lowpoly"`, which remains the style-first Meshy test for possible direct blockcraft fit.

Current empirical update: the v2 API Meshy 5 probe returned one GLB for 5 credits, not four variants. The first refine pass cost 10 credits and produced a textured GLB that imports into Godot. Review:

```text
MESHY_TEXTURE_REFINE_PASS.md
```

The current Godot pixel-extrusion candidate is:

```text
generated/godot_pixel_extrude_v0/REVIEW.md
```

It proves the zero-credit true-voxel lane: Codex/Godot can read 2D pixel source cards and emit strict MeshInstance3D cubes or merged voxel bars. Current best uses are pickups, signs, terminals, datapads, decals-with-depth, and isometric tactical ship tokens.

The current pixel-hull character research candidate is:

```text
generated/godot_pixel_hull_character_v0/REVIEW.md
```

It proves the "flat but more 3D" direction: original front/side pixel cards can generate a deterministic voxel visual hull. The body-part follow-up is now strong enough to make pixel cards the preferred first proof for low-detail actors, droids, pose contracts, and background animation planning. Full hero combat characters still need a rig/Blockbench cleanup path.

The current pixel Cantina runtime proof is:

```text
generated/godot_pixel_cantina_runtime_v1/REVIEW.md
```

It proves semantic pixel room cards can emit runtime-adjacent data: walk masks, collision masks, merged collision shapes, named sockets, socket-to-walk-cell resolution, and grid-routed actor probes.

The current reusable pixel room adapter proof is:

```text
generated/godot_pixel_room_runtime_adapter_v0/REVIEW.md
```

It preserves the Cantina runtime proof's key geometry/collision stats while moving floor/detail cards, socket role schema, sockets, path probes, palette, heights, and camera settings into `specs/pixel_room_cantina_runtime_adapter_v0.json`. The current spec includes explicit runtime affordance roles: `seat`, `stand`, `spawn`, `use`, `inspect`, `cover`, `transition`, `prop`, and `light`.

The current Vengi local-tool evaluation is:

```text
generated/vengi_pixel_card_eval_v0/REVIEW.md
```

It proves Vengi is installed and usable from absolute paths. PNG source cards can become `.vox` and flat GLB, but the successful Vengi GLB path did not beat Godot run-merge extrusion. Treat Vengi as a converter/manual-editor bridge until image-volume conversion or `.bbmodel` conversion is proven.

## Requesting Assets From Codex

Claude should use the shared queue:

```text
docs/gpt/asset_factory/requests/inbox/
```

Claude and Codex should read `ASSET_REQUEST_PLAYBOOK.md` before choosing a pipeline lane. That file is the current source of truth for deciding whether a request should start from in-game description, our own SVG contract, fan-art/reference lessons, Blockbench, Blender, Godot, Kenney filler, or an API/human lane.

Copy `requests/REQUEST_TEMPLATE.md`, fill one focused asset batch, and name it like:

```text
REQ-YYYYMMDD-short-kebab-name.md
```

Codex should respond with generated artifacts under `generated/<request_id>/` and a response file under `requests/completed/` or `requests/rejected/`.

Claude can also send feedback after testing an artifact:

```text
docs/gpt/asset_factory/requests/feedback/inbox/
```

Use `requests/FEEDBACK_TEMPLATE.md` for "this worked," "this is broken," "this is too expensive," "runtime needs changed," or "make this the baseline" notes. Feedback is appropriate when Claude is not asking for a brand-new asset, but reporting how an existing artifact behaved in context.

For animation requests, use:

```text
requests/ANIMATION_REQUEST_TEMPLATE.md
```

## Current Honest Assessment

This v0 is not production art. It is a proof that an asset grammar can generate repeatable Godot artifacts and review screenshots.

The key question for the owner is:

> Is a constrained chunky / blocky / low-poly direction acceptable if it gives us an automated path to coherent assets?

If yes, this path can scale. If no, we need more human/paid art help.

## Recommendation

Use these lanes in priority order:

1. Deterministic pixel/GDScript voxel lane
   - Free.
   - Best current match for the strict Minecraft/blockcraft target.
   - Start here for props, equipment, signs, tactical tokens, low-detail actors, ships/vehicles at token scale, buildings, rooms, terrain chunks, collision, sockets, and runtime masks.
   - Use semantic cards, front/side cards, top/isometric cards, greedy merging, and Godot proof captures.

2. Blockbench Cubecraft cleanup/hero lane
   - Free.
   - Locally tested through GLB export and validation.
   - Use after a pixel/blockout proof when an asset needs hero polish, clean editability, final foreground proportions, rig planning, or multi-angle identity.

3. Godot procedural/review lane
   - Free.
   - Fast.
   - Good for camera proofs, runtime masks, pathing sketches, tactical overlays, generated review scenes, and comparing assets in the target view.

4. Kenney/Quaternius kitbash lane
   - Free/CC0.
   - Good for immediate prototype improvement.
   - Requires material/style normalization.

5. Blender/API/human lane
   - Use only for high-value special assets.
   - Characters, creatures, hero ships, animations, and distinctive landmarks.
   - With Meshy, prefer salvage/background/reference tests unless a future A/B beats the voxel baseline.

6. Vengi bridge lane
   - Free/local.
   - Useful for `.vox` export and manual voxel-editor cleanup.
   - Not yet a replacement for Godot extrusion or Blender conversion.

The project should not rely on paid 3D generation for everything. It should reserve paid/API work for assets that cannot be built cleanly from the grammar.
