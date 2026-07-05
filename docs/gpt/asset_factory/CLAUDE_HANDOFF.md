# Claude Handoff: Asset Factory

## What To Review First

1. `README.md`
2. `ASSET_REQUEST_PLAYBOOK.md`
3. `REFERENCE_BASE_COMPARISON.md`
4. `PIPELINE_DECISION_LOG.md`
5. `STYLE_GRAMMAR.md`
6. `specs/mos_eisley_chunky_v0.json`
7. `generated/REVIEW.md` after the factory has been run
8. `BLOCKCRAFT_DIRECTION.md`
9. `ALMOST_SPACE_OPERA_GUIDE.md`
10. `specs/blockcraft_space_opera_v0.json`
11. `generated/blockcraft_space_opera_v0/REVIEW.md`
12. `PRIVATE_SW_AUTHENTICITY_PASS.md`
13. `specs/private_clone_wars_blockcraft_v0.json`
14. `generated/private_clone_wars_blockcraft_v0/REVIEW.md`
15. `PRIVATE_SPACECRAFT_PASS.md`
16. `specs/private_clone_wars_spacecraft_v0.json`
17. `generated/private_clone_wars_spacecraft_v0/REVIEW.md`
18. `BLOCKBENCH_CUBECRAFT_PIPELINE.md`
19. `specs/blockbench_cubecraft_v0.json`
20. `generated/blockbench_cubecraft_v0/REVIEW.md`
21. `generated/blockbench_cubecraft_v0/GLB_REVIEW.md`
22. `SHIP_MICROFIGHTER_PASS.md`
23. `specs/blockbench_ship_micro_v1.json`
24. `generated/blockbench_ship_micro_v1/GLB_REVIEW.md`
25. `specs/blockbench_ship_droid_v2.json`
26. `generated/blockbench_ship_droid_v2/GLB_REVIEW.md`
27. `specs/blockbench_ship_panel_v2.json`
28. `generated/blockbench_ship_panel_v2/GLB_REVIEW.md`
29. `generated/godot_phase0_camera_v0/REVIEW.md`
30. `MODEL_RESTYLE_BACKLOG.md`
31. `REFERENCE_IMAGE_WORKFLOW.md`
32. `TERRAIN_CANTINA_REFERENCE_PASS.md`
33. `generated/cantina_terrain_reference_v0/REVIEW.md`
34. `CANTINA_TERRAIN_KIT_PASS.md`
35. `generated/cantina_terrain_kit_v0/REVIEW.md`
36. `generated/cantina_entrance_detail_v1/ITERATION_REVIEW.md`
37. `CANTINA_BLOCKBENCH_ENTRANCE_PASS.md`
38. `generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md`
39. `generated/godot_cantina_entrance_camera_v1/REVIEW.md`
40. `CANTINA_MOOD_AB_PASS.md`
41. `generated/cantina_mood_ab_v1/REVIEW.md`
42. `CANTINA_SIGN_TEXTURE_PASS.md`
43. `generated/blockbench_cantina_sign_texture_v1/GLB_REVIEW.md`
44. `generated/godot_cantina_sign_texture_v1/REVIEW.md`
45. `CANTINA_EXTERIOR_CLUTTER_KIT_PASS.md`
46. `generated/blockbench_cantina_exterior_clutter_v1/GLB_REVIEW.md`
47. `generated/godot_cantina_exterior_clutter_kit_v1/REVIEW.md`
48. `CANTINA_BAR_BOOTH_BAY_PASS.md`
49. `generated/blockbench_cantina_bar_booth_bay_v1/GLB_REVIEW.md`
50. `generated/godot_cantina_bar_booth_bay_v1/REVIEW.md`
51. `ANIMATION_REQUEST_PROTOCOL.md`
52. `CANTINA_SEATED_SOCIAL_ANIMATION_PASS.md`
53. `generated/godot_cantina_seated_social_anim_v0/REVIEW.md`
54. `MESHY_PREMIUM_EVALUATION.md`
55. `MESHY_CREDIT_AND_TIER_STRATEGY.md`
56. `MESHY_TEXTURE_REFINE_PASS.md`
57. `MESHY_SALVAGE_LANES.md`
58. `PIXEL_VOXEL_PRODUCTION_STRATEGY.md`
59. `PIXEL_EXTRUDE_GODOT_PASS.md`
60. `generated/meshy_eval_v0/REVIEW.md`
61. `generated/meshy_ship_eval_v0/REVIEW.md`
62. `generated/meshy_image_droid_v0/godot_proof/REVIEW.md`
63. `generated/godot_pixel_extrude_v0/REVIEW.md`
64. `PIXEL_HULL_CHARACTER_PASS.md`
65. `generated/godot_pixel_hull_character_v0/REVIEW.md`
66. `PIXEL_HULL_BODY_PARTS_PASS.md`
67. `generated/godot_pixel_hull_body_parts_v0/REVIEW.md`
68. `PIXEL_CANTINA_KIT_PASS.md`
69. `generated/godot_pixel_cantina_kit_v0/REVIEW.md`
70. `PIXEL_CANTINA_LAYERED_KIT_PASS.md`
71. `generated/godot_pixel_cantina_layered_kit_v1/REVIEW.md`
72. `PIXEL_CANTINA_RUNTIME_PASS.md`
73. `generated/godot_pixel_cantina_runtime_v1/REVIEW.md`
74. `PIXEL_ROOM_RUNTIME_ADAPTER_PASS.md`
75. `generated/godot_pixel_room_runtime_adapter_v0/REVIEW.md`
76. `VENGI_PIXEL_CARD_EVAL_PASS.md`
77. `generated/vengi_pixel_card_eval_v0/REVIEW.md`
78. `requests/README.md`
79. `requests/REQUEST_TEMPLATE.md`
80. `requests/ANIMATION_REQUEST_TEMPLATE.md`
81. `requests/FEEDBACK_TEMPLATE.md`
82. `codex_skill_draft/SKILL.md`

## The Main Ask

Evaluate whether this constrained asset grammar is a viable direction for the prototype.

This is not meant to replace all art. It is meant to answer:

> Can we automate a large amount of acceptable prototype geometry if we constrain the style hard enough?

The latest recommendation leans toward the blockcraft pack as the stronger direction if the owner wants "Star Wars Minecraft" energy. After the owner clarified this is a private project for friends and SW authenticity is the priority, review `PRIVATE_SW_AUTHENTICITY_PASS.md` and the `private_clone_wars_blockcraft_v0` outputs as the current strongest Godot-generated visual target.

The newer pixel/GDScript proofs are now the strongest first-pass target for strict voxel consistency. Review `PIXEL_VOXEL_PRODUCTION_STRATEGY.md` before extending characters, equipment, ships, vehicles, buildings, or room kits. Blockbench remains important, but its role is now hero cleanup/editability after a pixel/blockout proof rather than the first answer for every asset.

The Blockbench Cubecraft excursion still matters because it produces editable `.bbmodel` source files, Blender-converted `.glb` files, Blender previews, and clean glTF validation. Review `BLOCKBENCH_CUBECRAFT_PIPELINE.md` before promoting foreground hero characters or small props out of the pixel proof stage.

The ship microfighter pass remains useful evidence for authored ship silhouettes, but do not skip the newer pixel-token/multi-card question. Use pixel top/side/isometric cards first for tactical-scale ships or vehicles; escalate to Blockbench/Blender when cockpit/engine depth, rotation, or hero identity matters. Use Godot procedural generation for tactical overlays, sensors, movement ghosts, targeting, and review scenes.

The hostile droid v2 follow-up is a successful one-variable iteration. Use `micro_tri_droid_stalker_v2` as the hostile ship baseline instead of the v1 droid ship.

The friendly panel v2 follow-up is also a successful one-variable iteration. Use `micro_arc_interceptor_panel_v2` as the friendly ARC-style ship baseline instead of `micro_arc_interceptor_v1` before runtime camera testing.

Do not read "use Kenney" as "place raw Kenney everywhere." Kenney is filler clay for background massing and generic clutter. The identity layer should come from custom Blockbench silhouettes, palette, and added blockcraft caps/panels. A Kenney asset must be normalized and screenshot-tested beside a kept Blockbench baseline before becoming foreground art.

The Godot Phase 0 camera proof is now available at `generated/godot_phase0_camera_v0/REVIEW.md`. Treat it as a partial keep: the isometric space capture and mixed ship/player scale capture are promising, while the ground character capture proves import/scale but still needs stronger front-facing contrast/detail before runtime promotion.

If Claude wants Codex to generate or iterate assets later, use the shared queue in `requests/`. Create one focused request file in `requests/inbox/` from `requests/REQUEST_TEMPLATE.md`. Codex should answer with docs-only generated artifacts under `generated/<request_id>/` and a response file in `requests/completed/` or `requests/rejected/`.

If Claude tested an artifact and wants to provide feedback instead of asking for a new asset, use `requests/FEEDBACK_TEMPLATE.md` and put the file in `requests/feedback/inbox/`. Good feedback includes "this worked," "this broke," "runtime camera failed," "collision/socket data is wrong," "this is too heavy," or "make this the new baseline." Codex can then review/action it or convert it into a focused request.

Before choosing the lane, read `ASSET_REQUEST_PLAYBOOK.md`. It is the current source of truth for when to start from in-game/SW_MUSH descriptions, when to create pixel/semantic cards, when reference images are actually helpful, when Blockbench/Blender should clean up a pixel proof, when Godot should generate runtime masks/sockets, and when Kenney is acceptable as normalized filler.

Read `REFERENCE_BASE_COMPARISON.md` when evaluating whether an asset should be based on game descriptions, fan art, or both. The current answer is: game/SW_MUSH/project descriptions drive playable geometry; fan art/reference boards are visual-style and silhouette lessons; the final asset is rebuilt in original blockcraft grammar.

Read `PIPELINE_DECISION_LOG.md` before changing tool lanes. The current locked default is pixel/GDScript first for strict voxel proofs when original source cards can express the asset, with Blockbench/Blender/glTF/Godot proof retained for hero cleanup, foreground editability, rigs, and final multi-angle identity. This is deliberately not "pixel cards for final everything" or "Blockbench for everything."

The draft Codex skill lives at `codex_skill_draft/SKILL.md`. It is intentionally not installed yet. Use it as a preview of how Codex should onboard itself once the asset-request process is proven by several real request cycles.

For terrain, start with the Cantina reference pass. The owner clarified that SW_MUSH has multiple Cantina rooms but no SVGs; the intended comparison is fan-art mood study versus Codex/Claude-created SVG contracts based on the SW_MUSH descriptions and room data. Use `TERRAIN_CANTINA_REFERENCE_PASS.md` and `generated/cantina_terrain_reference_v0/REVIEW.md` before modeling the Cantina terrain kit.

The first generated Cantina terrain-kit proof is now available at `generated/cantina_terrain_kit_v0/REVIEW.md`. Treat it as a partial keep: the entrance, exterior plaza, and multi-room composition are useful, but the interior is too clean and toy-like. The focused V1 entrance-detail pass at `generated/cantina_entrance_detail_v1/ITERATION_REVIEW.md` is a keep and should become the new entrance baseline before a Blockbench conversion.

The Blockbench conversion is now available at `generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md`. Treat it as a keep and the current editable Cantina entrance baseline. It preserves the V1 threshold in `.bbmodel` and `.glb` form with clean glTF validation. Known limitation: the current adapter does not preserve rotated cubes, so the no-droids sign slash needs a texture/manual Blockbench pass later.

The Godot camera/import proof is now available at `generated/godot_cantina_entrance_camera_v1/REVIEW.md`. Treat it as a keep. The first camera attempt showed the wrong side of the GLB, so the review script now rotates the imported holder 180 degrees; the model itself was not changed. The corrected captures preserve the controlled-threshold read in Godot.

The Cantina mood A/B proof is now available at `generated/cantina_mood_ab_v1/REVIEW.md`. Treat it as a candidate keep. It keeps the entrance GLB fixed and changes only lighting/material mood, exterior clutter, grime chips, and dim doorway context. The warmer/darker pass feels closer to a lived-in frontier cantina, but the clutter is still proof geometry and should become a Blockbench exterior-clutter kit or normalized filler pass before runtime promotion.

The Cantina sign texture proof is now available at `generated/godot_cantina_sign_texture_v1/REVIEW.md`. Treat it as a candidate keep. It changes only the no-droids sign workflow: cube glyphs are replaced by one original pixel-texture sign plane in a copied Blockbench model, then exported to GLB and validated cleanly. Do not generalize this into texture-everything; use the method only for tiny signs/decals/role markings where cube glyphs fail.

The Cantina exterior clutter kit proof is now available at `generated/godot_cantina_exterior_clutter_kit_v1/REVIEW.md`. Treat it as a candidate keep. It converts the mood-pass proof clutter into four reusable Blockbench/GLB modules: pipe cluster, utility box, crate/scrap stack, and dust berm. One visual iteration was applied during the slice: the pipe cluster's solid backplate was rejected as slabby and replaced with bracket strips. Do not stamp the whole kit everywhere; place modules sparingly per room/exterior chunk and re-capture beside the kept entrance.

The Cantina bar/booth bay proof is now available at `generated/godot_cantina_bar_booth_bay_v1/REVIEW.md`. Treat it as a candidate keep and the current editable main-bar/booth-bay module. It converts the older procedural proof into Blockbench/GLB form and improves the social hub read with segmented booth backs, bar-front panels, service taps, colored bottle/service lights, a bartender proxy, and an owner-corner booth/Wookiee-scale proxy. The Godot proof rotates the imported holder 180 degrees for review-camera orientation; the GLB source is unchanged.

The first animation request/proof pass is now available at `generated/godot_cantina_seated_social_anim_v0/REVIEW.md`. Treat it as a candidate protocol keep, not as a final animation pack. It keeps the bar/booth GLB fixed and adds procedural seated actors, named anchors, key-pose captures, and a saved Godot `AnimationPlayer` proof scene with `sit_idle_loop`, `lean_talk_loop`, `drink_loop`, and `turn_to_speaker_loop`. Use `ANIMATION_REQUEST_PROTOCOL.md` and `requests/ANIMATION_REQUEST_TEMPLATE.md` before asking for social, combat, or vehicle animation work.

The first Meshy Premium/API evaluation is now available at `generated/meshy_eval_v0/REVIEW.md`. Treat it as a candidate lesson keep, not a direct runtime keep. One `model_type: "lowpoly"` preview cost 20 credits, produced a clean GLB, and gave useful sci-fi service-terminal shape language. The provider thumbnail is stronger than the current Godot-tinted proof, so future Meshy work must be judged by thumbnail, GLB validation, and Godot proof together. Do not auto-refine; refine only if preview geometry wins. Never write the Meshy API key into repo files.

Read `MESHY_CREDIT_AND_TIER_STRATEGY.md` and `MESHY_SALVAGE_LANES.md` before spending credits. The current answer has narrowed: Meshy is rejected as a default foreground voxel asset lane. The 5-credit image-to-3D droid test preserved a rough silhouette but softened cube grammar and fused the source floor into the model, confirming the owner's concern that analog generated meshes will be jarring beside discrete voxel art. Use Meshy only as salvage/reference/background research unless a future A/B proves otherwise.

The Meshy ship silhouette probe is now available at `generated/meshy_ship_eval_v0/REVIEW.md`. Treat it as a candidate lesson keep only. The 5-credit Meshy 5 patrol-skiff prompt produced a chunky vehicle seed, but it reads more like a ground hover-skiff/utility speeder than a clean tactical starfighter. The kept Blockbench `micro_arc_interceptor_panel_v2` still wins as current cubecraft ship art.

The Meshy image-to-3D droid probe is now available at `generated/meshy_image_droid_v0/godot_proof/REVIEW.md`. Treat it as negative foreground evidence and a useful credit-cost datapoint: 5 credits, clean GLB with only an unused TEXCOORD warning, recognizable but softened shape, source floor fused into the mesh. Do not keep trying Meshy for characters, droids, gear, vehicles, or nearby props unless the owner explicitly asks for a focused A/B. The only plausible next Meshy lane is background/space ambience/VFX reference, preferably rendered/posterized as 2D plates and tested beside voxel ships.

The Godot pixel-extrude proof is now available at `generated/godot_pixel_extrude_v0/REVIEW.md`. Treat it as a candidate keep for strict voxel props and tactical tokens. It proves a zero-credit lane where Codex/Godot reads original 2D pixel source cards and emits true cube-grid MeshInstance3D geometry. Same-color run merge reduced the blaster from 146 cubes to 32 and the ship token from 322 cubes to 94 while keeping the silhouette. Use it for pickups, signs, datapads, terminals, decals-with-depth, faction badges, and isometric ship tokens. Do not use single-layer prop extrusion for full humanoids, large buildings, or terrain chunks; use body-part hulls and semantic room/building cards for those.

The pixel-hull character proof is now available at `generated/godot_pixel_hull_character_v0/REVIEW.md`. Treat it as a candidate research keep for the owner's "flat but more 3D" question. It uses original front and side pixel cards to build a deterministic voxel visual hull. This is stronger than a paper-flat cutout and useful for low-detail NPCs, body-plan exploration, and future rigid-part animation experiments. Do not treat the whole-body hull as a final clone trooper or combat rig; the next useful slice is body-part-separated front/side cards.

The body-part pixel-hull proof is now available at `generated/godot_pixel_hull_body_parts_v0/REVIEW.md`. Treat it as a candidate keep for deterministic low-detail actor and animation-request proofs. It changes one variable from the whole-body hull: each body part has its own front/side cards and voxel hull node, allowing neutral, rifle-ready, cover, and rotation captures. This is promising for background guards, droids, social extras, and pose contracts. It still does not replace Blockbench for foreground clone-trooper combat rigs.

The pixel Cantina kit proof is now available at `generated/godot_pixel_cantina_kit_v0/REVIEW.md`. Treat it as a candidate keep for layout, collision, room LOD, room-graph visualization, and cheap filler geometry. The 48x32 semantic card had 966 non-empty pixels, merged to 74 rectangles, and emitted 8 material-batched mesh nodes. This answers the compute question: it is efficient if merged/batched, but it is not a replacement for authored Blockbench identity modules.

The layered pixel Cantina kit proof is now available at `generated/godot_pixel_cantina_layered_kit_v1/REVIEW.md`. Treat it as the stronger visual room-kit baseline. It adds a second semantic detail/elevation card for arches, frames, booth backs, lamps, pipes, sockets, raised strips, and sign hooks. The combined 1,107 non-empty pixels merged to 101 rectangles and 16 material-batched mesh nodes, so the identity gain did not break the compute model.

The pixel Cantina runtime proof is now available at `generated/godot_pixel_cantina_runtime_v1/REVIEW.md`. Treat it as the historical proof that semantic pixel room cards can do more than visuals. It emits walk masks, collision masks, 38 merged collision shapes, 12 named sockets, socket-to-walk-cell resolution, and grid-routed actor probes from the same card grammar. The reusable adapter supersedes it as the current request shape; the next best room step is a second SW_MUSH Cantina room spec to prove repeatability.

The reusable pixel room runtime adapter is now available at `generated/godot_pixel_room_runtime_adapter_v0/REVIEW.md`. Treat it as the current request shape for new room/building work: data lives in `specs/pixel_room_cantina_runtime_adapter_v0.json`, while `scripts/godot_pixel_room_runtime_adapter.gd` emits masks, collision, sockets, path probes, scenes, captures, manifest, and review. It preserves the Cantina runtime proof's geometry/collision stats and now carries explicit socket roles/facing/actions for seats, stand/spawn anchors, use/inspect prompts, cover anchors, transitions, props, and lights.

The Vengi local-tool evaluation is now available at `generated/vengi_pixel_card_eval_v0/REVIEW.md`. Vengi is installed at `C:\Program Files\vengi` and Codex should use absolute binary paths, especially `C:\Program Files\vengi\voxconvert\vengi-voxconvert.exe`. Treat Vengi as a candidate bridge keep only: PNG source cards converted successfully to `.vox` and flat GLB, but the successful GLB path did not beat Godot run-merged extrusion for true voxel props. Initial image-volume and `.bbmodel` conversion probes hung and were stopped, so do not replace Blender or Godot extrusion with Vengi yet.

When the owner or Claude asks about giving Meshy an image source, use this split:

```text
strict voxel target -> original pixel/SVG card -> Godot pixel extrusion
AI mesh/style interpretation -> Meshy image-to-3D with our own generated blockcraft card, then validation
```

Do not upload copied fan art or official images as source images.

## Important Boundaries

- Do not promote these generated docs assets into runtime without owner approval.
- Do not mix this with live gameplay code unless intentionally integrating.
- Keep generated asset sources generic, license-clean, and non-franchise-specific for public-safe packs.
- Keep private-fan packs separate and clearly labeled. Do not import ripped official meshes/textures/logos/audio.
- The generated Godot scenes are review artifacts first.

## If Continuing This Work

Best next implementation tasks:

1. Improve `godot_asset_factory.gd` material library.
2. Add labels to contact-sheet captures, or expand the generated Markdown index.
3. Add more asset specs:
   - lawless-zone gate;
   - bounty terminal;
   - medical tent;
   - faction checkpoint;
   - cantina exterior;
   - desert rock cluster;
   - landing pad kit;
   - isometric corvette;
   - isometric freighter;
   - sensor buoy.
4. Continue the private Clone Wars blockcraft pass:
   - clone heavy;
   - droideka-inspired threat;
   - modular desert wall/door/terminal kit;
   - clearer Republic/CIS isometric space silhouettes.
5. Continue the private spacecraft pass:
   - corvette;
   - frigate;
   - bulk freighter;
   - droid swarm craft;
   - sensor/range/shield overlay pieces.
6. Add a docs-only runtime-space mock with moving x/y ship tokens and no ground UI underneath.
7. Add a Blender adapter once Blender is installed.
8. Import one generated Blockbench `.glb` into a docs-only Godot review scene and capture it from the intended gameplay camera.
9. Import kept ship GLBs into a docs-only Godot tactical-camera review scene.
10. Add a promotion script that copies approved assets into runtime asset folders with manifest entries.
11. Consume focused asset requests from `requests/inbox/` and return response files with keep/reject verdicts.
12. Build a Cantina terrain kit from description-derived SVGs, not from copied fan art.
13. Once the process is stable, install or promote `codex_skill_draft/SKILL.md` as a real Codex skill.
14. Convert the bar/booth bay or back hallway module into Blockbench/GLB using the same lane, or run a material/lighting-only mood pass for the existing Cantina modules.
15. If asking for animation, split the request into scene interaction or character action. The next best action-animation slice is a shared blockcraft humanoid rig contract with only `idle_rifle_loop` and `fire_rifle_once` for the clone rifleman.
16. If using Meshy, prefer a salvage/background test, not a foreground asset test. Compare against a named Blockbench/Godot baseline and decide keep/rebuild/reject from thumbnail + validation + Godot proof.
17. For pickup-scale props, signs, terminals, and tactical ship tokens, consider the pixel-extrude lane before spending Meshy credits.
18. For low-detail humanoids, droids, or background patrons, consider a pixel-hull proof before spending Meshy credits or committing to a full Blockbench model.
19. For animation-facing low-detail actors, prefer the body-part pixel-hull proof over a fused whole-body hull.
20. For room-scale Cantina or terrain layout, consider the layered semantic pixel room kit before hand-authoring every wall/floor/filler module.
21. If using Vengi, start with PNG-to-VOX or a manual `vengi-voxedit` cleanup pass. Do not assume Vengi can currently replace Blender conversion.

## Evaluation Questions

Ask the owner:

- Is the chunky style acceptable if it makes asset production cheaper?
- Should ground be more Kenney-like, more Quaternius-like, or more custom?
- Is isometric space best as 3D models on a flat plane or rendered sprites?
- Which five hero assets deserve paid/human attention?

## My Recommendation

Use this as the default cheap art pipeline:

```text
spec -> Blockbench/Godot candidate -> rendered capture -> owner picks -> polish only winners
```

This keeps the owner in the loop through pictures, not through raw model files.
