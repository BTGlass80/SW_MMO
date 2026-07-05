---
name: sw-mmo-asset-factory
description: Use when Codex needs to handle SW_MMO_Prototype docs/gpt asset-factory requests from Claude or the owner, choose a blockcraft asset creation lane for characters, droids, ships, weapons, terrain, buildings, Cantina rooms, or tactical space UI, generate docs-only SVG/Blockbench/Blender/Godot review artifacts, validate GLBs, and write keep/reject handoffs without modifying runtime game files.
---

# SW MMO Asset Factory

This is a draft skill for the SW_MMO_Prototype asset-factory process. Do not treat it as installed or final until the owner approves the pipeline.

## First Read

Open these project files before acting:

1. `docs/gpt/asset_factory/ASSET_REQUEST_PLAYBOOK.md`
2. `docs/gpt/asset_factory/REFERENCE_BASE_COMPARISON.md`
3. `docs/gpt/asset_factory/PIPELINE_DECISION_LOG.md`
4. `docs/gpt/asset_factory/requests/README.md`
5. `docs/gpt/asset_factory/requests/REQUEST_TEMPLATE.md`
6. `docs/gpt/asset_factory/requests/ANIMATION_REQUEST_TEMPLATE.md`
7. `docs/gpt/asset_factory/requests/FEEDBACK_TEMPLATE.md`

Then read only the reference doc for the requested family:

- Characters, droids, small props: `docs/gpt/asset_factory/BLOCKBENCH_CUBECRAFT_PIPELINE.md`
- Ships: `docs/gpt/asset_factory/SHIP_MICROFIGHTER_PASS.md`
- Reference images: `docs/gpt/asset_factory/REFERENCE_IMAGE_WORKFLOW.md`
- Terrain, buildings, Cantina: `docs/gpt/asset_factory/PIXEL_VOXEL_PRODUCTION_STRATEGY.md`, `docs/gpt/asset_factory/TERRAIN_CANTINA_REFERENCE_PASS.md`, `docs/gpt/asset_factory/CANTINA_BLOCKBENCH_ENTRANCE_PASS.md`, `docs/gpt/asset_factory/CANTINA_MOOD_AB_PASS.md`, `docs/gpt/asset_factory/CANTINA_SIGN_TEXTURE_PASS.md`, `docs/gpt/asset_factory/CANTINA_EXTERIOR_CLUTTER_KIT_PASS.md`, `docs/gpt/asset_factory/CANTINA_BAR_BOOTH_BAY_PASS.md`, `docs/gpt/asset_factory/PIXEL_CANTINA_KIT_PASS.md`, `docs/gpt/asset_factory/PIXEL_CANTINA_LAYERED_KIT_PASS.md`, `docs/gpt/asset_factory/PIXEL_CANTINA_RUNTIME_PASS.md`, `docs/gpt/asset_factory/PIXEL_ROOM_RUNTIME_ADAPTER_PASS.md`
- Animation: `docs/gpt/asset_factory/ANIMATION_REQUEST_PROTOCOL.md`, `docs/gpt/asset_factory/CANTINA_SEATED_SOCIAL_ANIMATION_PASS.md`
- Meshy/API generation: `docs/gpt/asset_factory/MESHY_PREMIUM_EVALUATION.md`, `docs/gpt/asset_factory/MESHY_CREDIT_AND_TIER_STRATEGY.md`, `docs/gpt/asset_factory/MESHY_TEXTURE_REFINE_PASS.md`, `docs/gpt/asset_factory/MESHY_SALVAGE_LANES.md`
- Pixel-card true voxel props/tokens: `docs/gpt/asset_factory/PIXEL_EXTRUDE_GODOT_PASS.md`
- Pixel-hull actors/body plans: `docs/gpt/asset_factory/PIXEL_HULL_CHARACTER_PASS.md`, `docs/gpt/asset_factory/PIXEL_HULL_BODY_PARTS_PASS.md`
- Vengi/local voxel bridge: `docs/gpt/asset_factory/VENGI_PIXEL_CARD_EVAL_PASS.md`
- Full restyle planning: `docs/gpt/asset_factory/MODEL_RESTYLE_BACKLOG.md`

## Boundaries

Treat runtime game files, source gameplay code, and `C:\SW_MUSH` as read-only unless the owner explicitly permits promotion or source edits. Work under `docs/gpt/asset_factory/`.

Keep private/friends Star Wars-authentic work separate from public/license-clean space-opera work. Do not use ripped official meshes, textures, logos, audio, or copied fan-art geometry. Use references only for silhouette and proportion lessons.

## Workflow

1. Read the request from `docs/gpt/asset_factory/requests/inbox/` or the user prompt.
2. Choose a lane using `ASSET_REQUEST_PLAYBOOK.md`.
3. Name the baseline and one variable to change.
4. Produce docs-only artifacts under `docs/gpt/asset_factory/generated/<request_id>/`.
5. Prefer editable sources: `.bbmodel`, structured JSON specs, SVG contracts, or Godot review scenes.
6. Render previews or captures.
7. Validate GLBs with `gltf-transform validate` when GLBs exist.
8. Compare against the baseline and write a keep/reject verdict.
9. Write a response file to `requests/completed/` or `requests/rejected/`.

If the file is feedback rather than a new request, read `requests/FEEDBACK_TEMPLATE.md`, inspect the related artifact, and either update docs, mark it reviewed/actioned, or convert it into a focused request.

## Lane Defaults

Use these defaults unless the request gives a better reason:

- Characters/droids/weapons: role -> original pixel card(s) -> Godot extrusion or body-part hull proof -> Blockbench `.bbmodel` cleanup only if foreground/hero -> Blender `.glb` -> glTF validation -> Godot proof.
- Ships/vehicles: role -> top/side/isometric pixel card(s) -> Godot token or multi-card hull proof -> Blockbench `.bbmodel` cleanup only if hero/rotating -> Blender `.glb` -> glTF validation -> Godot isometric proof.
- Terrain/buildings/Cantina: descriptions and YAML topology -> semantic floor/detail pixel cards or external JSON room spec -> Godot room/building kit -> collision/walk masks/socket roles where relevant -> Blockbench identity modules only where needed -> Godot capture.
- Room kits/Cantina LOD: room graph or layout -> semantic pixel floorplan card plus detail/elevation card -> greedy rectangle merge -> material-batched Godot meshes -> use for layout/collision/navigation/socket roles/LOD with Blockbench identity modules layered on top.
- Space UI and tactical overlays: gameplay verbs -> SVG storyboard if useful -> Godot procedural review scene.
- Pixel-card props/tokens: role -> original 16x/32x/48x pixel card -> Godot pixel extrusion -> same-color run merge by default -> Godot capture beside baseline.
- Pixel-hull actors/body plans: role -> original front/side pixel cards -> Godot visual hull -> rotation/pose contact sheet -> use whole-body hulls for body-plan research and body-part hulls for low-detail rigid animation proofs or Blockbench rebuild input.
- Scene interaction animation: scene baseline -> anchors/props/clip names -> Godot pose or `AnimationPlayer` proof -> keyframe captures.
- Character action animation: baseline character scale -> shared rig contract -> one or two Blender/glTF clips -> Godot import proof before expanding.
- Meshy/API model generation: salvage/background/reference request -> Meshy preview only -> thumbnail + GLB validation + Godot proof or posterized plate proof -> keep/rebuild/reject -> refine only if the result is useful outside the foreground voxel layer.
- Vengi bridge work: project PNG source card -> `vengi-voxconvert` to `.vox` -> optional manual `vengi-voxedit` cleanup -> export/validate/proof. Use absolute local paths under `C:\Program Files\vengi`; do not assume Vengi is on PATH.

Current locked process:

- Game/source descriptions drive playable geometry.
- Fan art/reference images drive mood and silhouette lessons only.
- Pixel/GDScript is the default first proof for strict voxel assets when original source cards can express the asset.
- Blockbench remains the cleanup/editable source for foreground identity assets after pixel/blockout proof.
- Godot remains the default for deterministic voxel generation, blockouts, tactical overlays, review scenes, runtime masks/sockets, and camera/import proofs.
- Tiny signs/decals may use original pixel-texture planes when cube glyphs fail, but only after GLB validation and Godot camera proof.
- Cantina exterior clutter now has a candidate reusable Blockbench/GLB kit; place modules sparingly and validate each room/exterior composition with a Godot capture.
- Cantina main-bar/booth bay now has a candidate editable Blockbench/GLB module; use it before composing a connected Cantina interior.
- Animation requests now have a candidate protocol. Split scene interactions from character action clips; do not treat the seated-social proof as evidence that full clone-trooper locomotion is solved.
- Meshy Premium is now rejected as a default foreground voxel lane. Never write API keys into repo files. Use `MESHY_API_KEY` from the environment only for focused salvage/background/reference tests. The 5-credit image-to-3D droid probe confirms Meshy can preserve a rough silhouette but softens cube grammar and fuses source context into analog mesh; do not spend credits on direct characters, gear, vehicles, nearby props, or modular buildings unless the owner explicitly asks for a focused A/B.
- Pixel extrusion is now a candidate true-voxel lane for pickups, signs, terminals, decals, badges, and isometric tactical tokens. Use original project source cards only. Same-color run merge is the default unless the pixelated surface itself is desired. Do not use this lane yet for full humanoids, large buildings, or terrain chunks.
- Pixel hulls are now a candidate lane for low-detail actors, body-plan exploration, and deterministic rigid-pose proofs. Whole-body hulls are research only; body-part hulls are better for background animation proofs; Blockbench remains the foreground combat-rig route.
- Pixel room kits are now a candidate lane for Cantina/layout/LOD generation. Do not emit one node per pixel in production; use greedy rectangle merge and material batching. The current stronger baseline is the layered Cantina v1: 1,107 combined source pixels -> 101 rectangles -> 16 material meshes.
- Pixel room runtime proof is a historical candidate keep. It emits walk masks, collision masks, 38 merged collision shapes, 12 named sockets, socket-to-walk-cell resolution, and grid-routed actor probes from the same semantic cards; use the external JSON adapter as the current request shape.
- Pixel room runtime adapter is now a candidate keep. For new room/building requests, prefer a JSON spec like `specs/pixel_room_cantina_runtime_adapter_v0.json` plus `scripts/godot_pixel_room_runtime_adapter.gd` over hard-coding room data in a bespoke script. The JSON should carry explicit socket roles/facing/actions for seats, stand/spawn anchors, use/inspect prompts, cover anchors, transitions, props, and lights.
- Vengi is now a candidate `.vox` bridge/manual-cleanup lane. PNG-to-VOX and PNG-to-flat-GLB worked; image-volume and `.bbmodel` conversion probes hung in the first test. Do not replace Godot extrusion or Blender conversion with Vengi unless a focused A/B beats the baseline.

## Response Standard

Every response should include:

- request id;
- baseline;
- changed variable;
- generated files;
- preview/capture paths;
- validation result;
- keep/reject verdict;
- next one-variable recommendation.

For animation requests, also include clip names, anchor/socket names, animation family, and whether the result is a pose proof, saved Godot `AnimationPlayer` scene, or validated animated GLB.

If an iteration is worse than the baseline, say so clearly and preserve or recommend the better baseline.
