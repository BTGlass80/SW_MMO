# Pipeline Decision Log

Date: 2026-07-04  
Scope: docs-only lock/candidate/rejected decisions for the asset factory

## Purpose

This log prevents oscillation.

The owner is right that once a variable has been tested and consistently wins, we should stop re-litigating it every pass. But we should only "set it in stone" when the evidence supports it.

The rule is:

```text
Freeze the process where evidence is strong.
Keep experiments explicit where evidence is weak.
Challenge a freeze only with a focused A/B test.
```

## Decision States

Use these terms in future review docs.

| State | Meaning |
| --- | --- |
| Experimental | Useful question, not enough evidence yet |
| Candidate | Looks promising, needs another validation pass |
| Locked | Default until a focused A/B beats it |
| Superseded | Was useful, but a later baseline replaced it |
| Rejected | Worse than baseline or too risky/friction-heavy |

## Lock Criteria

A process choice can be locked when it satisfies most of these:

- produces an editable source artifact;
- survives conversion/export without tool drama;
- validates cleanly when GLB is involved;
- imports/renders in Godot from the intended camera;
- beats or preserves a named baseline in captures;
- reduces future decision noise;
- has a clear scope boundary;
- can be repeated by Claude/Codex from docs.

A lock is not a religion. It is a default. To change it, run a one-variable comparison and record the result.

## Locked Decisions

### L1: Reference Split

State: Locked  
Scope: All asset-family planning

Default:

```text
Game/source descriptions drive geometry and gameplay affordances.
Fan art/reference images drive mood, silhouette lessons, and style pressure.
Blockcraft grammar drives the final model.
```

Why locked:

- Prevents fan art from overriding playable MMO logic.
- Lets us still use visual references where they actually help.
- Keeps source boundaries clear for private/friends and public-safe lanes.

Challenge condition:

Only challenge for a non-playable prop where geometry has no gameplay meaning.

### L2: Blockbench for Foreground Identity Assets

State: Locked  
Scope: characters, droids, weapons, ships, small props, and terrain identity modules after blockout

Default:

```text
structured spec / SVG contract / reference grammar
  -> Blockbench .bbmodel
  -> Blender GLB
  -> glTF validation
  -> Godot camera proof when runtime-bound
```

Why locked:

- Characters became more recognizable in the blockcraft lane.
- The ship microfighter passes improved when they moved away from Godot-only JSON assumptions.
- The Cantina entrance survived Godot proof -> Blockbench source -> Blender GLB -> clean glTF validation -> Godot camera proof.
- `.bbmodel` gives a human-editable source, which Godot procedural scenes do not.

Current evidence:

- `generated/blockbench_cubecraft_v0/GLB_REVIEW.md`
- `generated/blockbench_ship_micro_v1/GLB_REVIEW.md`
- `generated/blockbench_ship_droid_v2/GLB_REVIEW.md`
- `generated/blockbench_ship_panel_v2/GLB_REVIEW.md`
- `generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md`
- `generated/godot_cantina_entrance_camera_v1/REVIEW.md`

Important boundary:

This does **not** mean Blockbench is best for everything. It means Blockbench is the default authoring source for assets whose identity matters.

Challenge condition:

Run a focused Blender-direct, Godot-only, or API-generated candidate against a kept Blockbench baseline. Keep it only if it improves visual result **and** preserves editability/validation.

### L3: Godot for Blockouts, Cameras, Tactical Overlays, and Runtime Proof

State: Locked  
Scope: terrain blockouts, review scenes, tactical/isometric overlays, camera proofs, runtime import checks

Default:

```text
Godot procedural/review scenes are the test bench.
They are not the final identity-model source unless the asset is purely procedural.
```

Why locked:

- Godot is fastest for testing camera readability, scale, approach paths, and terrain spacing.
- Godot is the target runtime, so imported GLBs must be checked there.
- Procedural Godot is excellent for sensor rings, movement ghosts, targeting, contact sheets, terrain blockouts, and review scenes.

Challenge condition:

Only challenge if another tool produces faster and equally reliable runtime camera captures.

### L4: Kenney/Quaternius as Filler Clay Only

State: Locked  
Scope: free asset packs and generic world dressing

Default:

```text
Use free kits for background massing and generic clutter after palette/style normalization.
Do not use them as the identity layer.
```

Why locked:

- Raw kit assets risk breaking cohesion beside custom blockcraft pieces.
- Free kits are still useful for fast environmental density.
- The project needs custom silhouettes for anything the owner should recognize as "Star Wars Minecraft."

Challenge condition:

A kit asset can become foreground only if it is normalized and screenshot-tested beside kept Blockbench baselines.

### L5: Pixel/GDScript First For Strict Voxel Proofs

State: Locked  
Scope: first-pass proofing for props, equipment, low-detail actors, droids, tactical ships/vehicles, buildings, rooms, terrain chunks, collision, walk masks, sockets, and other strict voxel assets

Default:

```text
request
  -> original pixel/semantic source card(s)
  -> deterministic Godot voxel proof
  -> rendered captures and stats
  -> Blockbench/manual cleanup only when hero polish or editability is needed
```

Why locked:

- Meshy foreground tests produced continuous analog meshes that are jarring beside discrete voxel assets.
- Pixel extrusion produced true cube-grid props and tactical tokens with strong run-merge reductions.
- Body-part pixel hulls produced deterministic, poseable low-detail actor proofs.
- Layered Cantina semantic cards produced efficient room geometry.
- The runtime Cantina proof produced collision masks, walk masks, merged collision shapes, named sockets, socket-to-walk-cell resolution, and grid-routed actor probes from the same card grammar.

Important boundary:

This does **not** mean pixel cards are final art for every hero asset. It means they are the preferred first proof and source-of-truth grammar when strict voxel consistency matters. Foreground clone combat rigs, hero vehicles, landmark set pieces, and complex animated assets may still need Blockbench, Blender, or human cleanup after the pixel proof.

Current evidence:

```text
PIXEL_VOXEL_PRODUCTION_STRATEGY.md
generated/godot_pixel_extrude_v0/REVIEW.md
generated/godot_pixel_hull_body_parts_v0/REVIEW.md
generated/godot_pixel_cantina_layered_kit_v1/REVIEW.md
generated/godot_pixel_cantina_runtime_v1/REVIEW.md
```

Challenge condition:

Run a focused A/B against a named pixel baseline. The replacement must preserve strict voxel cohesion or clearly justify why a non-voxel layer is acceptable.

## Candidate Decisions

### C1: Cantina Material/Mood Pass

State: Candidate keep  
Scope: Cantina entrance/interior mood

Question:

Can fan-art/reference-board lessons improve the current Cantina without changing geometry?

Recommended test:

```text
Keep blockbench_cantina_entrance_v1 model fixed.
Change lighting/material grime/clutter only.
Render Godot before/after.
Keep only if detector/sign/threshold remain readable.
```

Result:

```text
generated/cantina_mood_ab_v1/REVIEW.md
```

The first mood A/B is a candidate keep. It improves the frontier-cantina read with warmer exterior light, darker doorway threshold, pipes, utility clutter, wall grime, and dust berms while preserving the same imported entrance GLB.

Do not lock the exact mood recipe yet. The direction is stronger. The clutter conversion question moved into C4.

### C2: Texture/Sign Workflow for Blockbench

State: Candidate keep  
Scope: signs, decals, tiny symbols, no-droids slash, role markings

Problem:

The current simple Blockbench adapter does not preserve rotated cubes. Some details are better as texture panels or manual Blockbench edits.

Recommended test:

```text
Take the kept Cantina entrance.
Change only the no-droids sign panel.
Compare cube-only sign vs texture/manual panel sign.
```

Result:

```text
generated/blockbench_cantina_sign_texture_v1/GLB_REVIEW.md
generated/godot_cantina_sign_texture_v1/REVIEW.md
```

The first sign texture pass is a candidate keep. It exported through the texture-aware Blender adapter, validates cleanly, and renders in Godot. The textured sign reads better than the cube-only sign in closeup and remains more recognizable from the ground camera.

Do not lock a broad texture workflow. The narrower decision is:

```text
Tiny signs/decals may use original pixel-texture planes when cube glyphs fail, but only after GLB validation and Godot camera proof.
```

### C3: Ship Reference-Board Grammar

State: Candidate  
Scope: ships and vehicles

Question:

Do ships improve more from reference-board silhouette lessons than from pure written specs?

Recommended test:

```text
Pick one kept ship baseline.
Write a reference grammar card.
Change only cockpit/wing/engine proportions in Blockbench.
Validate and Godot-camera test.
```

### C4: Cantina Exterior Clutter Kit

State: Candidate keep  
Scope: Cantina exterior density and reusable environment dressing

Question:

Can the `cantina_mood_ab_v1` proof-box clutter become reusable editable modules without losing the lived-in frontier read?

Result:

```text
generated/blockbench_cantina_exterior_clutter_v1/GLB_REVIEW.md
generated/godot_cantina_exterior_clutter_kit_v1/REVIEW.md
```

The first generated pipe cluster had a solid backplate and read like a slab from the Godot camera. That sub-iteration was rejected. The kept candidate changes only the pipe mount grammar to bracket strips and preserves the rest of the kit.

Verdict:

```text
Candidate keep. Use as a reusable authored clutter kit, not as automatic wallpaper.
```

The kit is a good compromise between raw proof boxes and over-polished hero art. It gives Claude editable `.bbmodel` modules and clean GLBs for pipe clusters, utility boxes, crate/scrap stacks, and dust berms.

### C5: Cantina Bar/Booth Bay Module

State: Candidate keep  
Scope: Cantina main-bar social hub and booth-ring identity

Question:

Can the `cantina_bar_booth_bay_01` Godot proof become an editable Blockbench/GLB module while improving the main-bar read?

Result:

```text
generated/blockbench_cantina_bar_booth_bay_v1/GLB_REVIEW.md
generated/godot_cantina_bar_booth_bay_v1/REVIEW.md
```

Verdict:

```text
Candidate keep. Use as the editable main-bar/booth-bay baseline before building the connected multi-room interior.
```

The candidate improves on the old proof with segmented booth backs, bar-front panels, service taps, bottle/service lights, bartender proxy, and owner-corner booth proxy. The Godot proof rotates the imported holder 180 degrees so the review camera sees the playable side; the GLB source model is unchanged.

### C6: Animation Request Protocol and Seated Social Proof

State: Candidate protocol keep  
Scope: animation request shape, scene-interaction proofing, and future rig-lane setup

Question:

Can Claude ask Codex for animations without collapsing scene interactions and full character combat locomotion into one vague request?

Result:

```text
ANIMATION_REQUEST_PROTOCOL.md
requests/ANIMATION_REQUEST_TEMPLATE.md
CANTINA_SEATED_SOCIAL_ANIMATION_PASS.md
generated/godot_cantina_seated_social_anim_v0/REVIEW.md
```

Verdict:

```text
Candidate protocol keep. The request shape is useful; the full animation production lane is not locked yet.
```

The proof keeps `blockbench_cantina_bar_booth_bay_v1.glb` fixed and changes only the social-interaction layer: named seated anchors, procedural placeholder actors, key poses, and a saved Godot `AnimationPlayer` proof scene. It proves the protocol for Cantina seating and similar environment-bound interactions.

Important boundary:

This does not prove clone-trooper locomotion/combat. The next one-variable test should be `shared_blockcraft_humanoid_rig_v0` with only `idle_rifle_loop` and `fire_rifle_once`, validated through Godot import and ground-camera captures.

### C7: Meshy Premium Preview-First Lane

State: Superseded by C11 / rejected for foreground default  
Scope: API-generated concept geometry and selective model drafting

Question:

Does Meshy Premium change the game enough to become a serious asset lane?

Result:

```text
MESHY_PREMIUM_EVALUATION.md
specs/meshy_eval_v0.json
adapters/meshy_text_to_3d.ps1
adapters/meshy_text_to_3d.py
generated/meshy_eval_v0/REVIEW.md
generated/meshy_eval_v0/godot_proof/REVIEW.md
```

Verdict:

```text
Lesson keep. Do not replace the Blockbench/Godot voxel identity lanes.
```

Evidence:

- One text-to-3D preview consumed 20 credits.
- Downloaded GLB validated with no errors or warnings.
- Provider thumbnail had richer sci-fi greeble language than the current utility-box module.
- Godot camera proof showed the result is not yet cohesive enough for direct blockcraft runtime use.

Policy:

```text
Meshy preview -> provider thumbnail + GLB validation + Godot proof -> keep/rebuild/reject -> refine only if geometry wins
```

Tiering rule:

```text
Meshy for high-entropy/hard-to-author assets.
Blockbench/Godot for exact, modular, repeatable, and style-critical assets.
```

The first preview used `model_type: "lowpoly"` and consumed the 20-credit preview bucket visible in the owner's pricing screen. Lowpoly remains the style-first Meshy default for blockcraft testing.

Updated evidence:

```text
meshy_cantina_service_terminal_voxel_lowpoly_v1 -> 20 credits, clean GLB, more cuboid but too bland; rejected as direct keep.
meshy_cantina_service_terminal_meshy5_draft_v1 -> 5 credits, one GLB, no observed drafts/variants fields; candidate option-mining keep.
meshy_cantina_service_terminal_meshy5_draft_v1_refine_v1 -> 10 credits, clean GLB, material imports into Godot; candidate texture/refine keep.
```

Meshy 5 draft variants may exist in the legacy web workflow because the visible pricing says its model stage generates four draft variants for 10 credits. The current Text-to-3D v2 API probe did not expose that behavior. Treat observed Meshy 5 API as a cheap single-seed option-mining lane until a true four-draft endpoint/mode is found.

Important boundary:

Never write Meshy API keys into repo files, generated docs, or automation prompts. Use `MESHY_API_KEY` from the environment.

### C11: Meshy Salvage / Background Lane

State: Candidate salvage keep  
Scope: background plates, space ambience, VFX reference, and rebuild-only reference

Question:

If Meshy fails the foreground voxel cohesion test, is it still useful somewhere away from the discrete cube identity layer?

Evidence:

```text
MESHY_SALVAGE_LANES.md
generated/meshy_image_droid_v0/godot_proof/REVIEW.md
```

The 5-credit Meshy image-to-3D droid preserved a rough blocky silhouette, validated cleanly, and imported into Godot. It also softened the cube grammar and fused the source presentation platform into the mesh. This confirms the owner's concern: analog Meshy shapes are jarring beside a voxel game.

Verdict:

```text
Reject Meshy for direct foreground characters, equipment, vehicles, modular buildings, and nearby props.
Keep Meshy only as a salvage/reference/background experiment lane.
```

Next valid Meshy test:

```text
space/backdrop plate -> posterize/dither/color-limit -> Godot isometric proof beside voxel ships
```

### C12: Pixel/GDScript Room Kit Lane

State: Candidate keep  
Scope: Cantina/room layouts, collision, LOD, room-graph visualization, and cheap interior massing

Question:

Does the deterministic pixel-card lane scale beyond props/characters into rooms, and is it efficient enough to matter?

Result:

```text
PIXEL_CANTINA_KIT_PASS.md
generated/godot_pixel_cantina_kit_v0/REVIEW.md
scripts/godot_pixel_cantina_kit_proof.gd
PIXEL_CANTINA_LAYERED_KIT_PASS.md
generated/godot_pixel_cantina_layered_kit_v1/REVIEW.md
scripts/godot_pixel_cantina_layered_kit_proof.gd
PIXEL_CANTINA_RUNTIME_PASS.md
generated/godot_pixel_cantina_runtime_v1/REVIEW.md
scripts/godot_pixel_cantina_runtime_proof.gd
```

Verdict:

```text
Candidate keep for structural room generation, not foreground identity art.
```

Evidence:

- 48x32 semantic Cantina floorplan card.
- 966 non-empty source pixels.
- 206 same-row runs.
- 74 greedy rectangles.
- 8 material-batched mesh nodes.
- Estimated triangles reduced from 11,592 per-pixel to 888 batched.

Updated layered evidence:

- Added a second semantic detail/elevation card.
- Combined 1,107 non-empty pixels.
- Merged to 101 rectangles.
- Emitted 16 material-batched mesh nodes.
- Estimated triangles reduced from 13,284 per-pixel to 1,212 batched.
- Visual identity improved through arches, frames, booth backs, lamps, pipes, sockets, raised strips, and sign hooks.

Runtime evidence:

- Walkable pixels: 439 -> 40 walk rectangles.
- Blocker pixels: 527 -> 38 merged collision shapes.
- Named sockets: 12.
- Non-walkable semantic sockets: 8, all resolved to nearest walk cells for actor/path targets.
- Actor and composite path probes now route over the generated walk mask instead of drawing direct lines.

Boundary:

This should generate layout, collision, walk masks, room LOD, detail sockets, path targets, and cheap filler. It should not replace authored hero modules such as the kept entrance, bar/booth bay, signs, and recognizable Cantina set pieces.

### C8: Godot Pixel-Extrude True Voxel Lane

State: Candidate keep  
Scope: strict voxel props, pickup items, signs/decals with depth, wall panels, and isometric tactical tokens

Question:

Does Gemini's suggested 2D pixel image -> 3D Godot cubes workflow actually solve the Meshy blockcraft mismatch?

Result:

```text
PIXEL_EXTRUDE_GODOT_PASS.md
generated/godot_pixel_extrude_v0/REVIEW.md
scripts/godot_pixel_extrude_proof.gd
```

Verdict:

```text
Candidate keep. Use for strict voxel props/tokens where a flat source card is natural.
```

Evidence:

- Generates original 2D pixel cards in Godot.
- Spawns strict MeshInstance3D cube geometry from non-transparent pixels.
- Saves Godot `.tscn` review scenes and PNG captures.
- Same-color run merge reduced the blaster from 146 cubes to 32 and the ship token from 322 cubes to 94 while preserving the silhouette.
- The terminal and tactical ship token look closer to the desired cube-grid style than the Meshy text-to-3D experiments.

Boundary:

This is not a full replacement for Blockbench. It is strongest for flat-ish assets: pickups, signs, datapads, wall terminals, decals, badges, and tactical ship tokens. Full humanoids, large buildings, and terrain chunks need Blockbench, Godot blockouts, or a future layered multi-view version of this lane.

Source-image rule:

```text
Use original project pixel cards, owner sketches, or project-generated SVG/bitmap cards.
Do not extrude copied fan art or official images.
```

### C9: Godot Pixel-Hull Character Lane

State: Candidate research keep  
Scope: low-detail actors, simple droids, body-plan exploration, and future rigid-part animation contracts

Question:

Can the deterministic pixel-card lane become more genuinely 3D without giving up grid control?

Result:

```text
PIXEL_HULL_CHARACTER_PASS.md
generated/godot_pixel_hull_character_v0/REVIEW.md
scripts/godot_pixel_hull_character_proof.gd
PIXEL_HULL_BODY_PARTS_PASS.md
generated/godot_pixel_hull_body_parts_v0/REVIEW.md
scripts/godot_pixel_hull_body_parts_proof.gd
```

Verdict:

```text
Candidate research keep. Use for low-detail/background actors and body-plan exploration, not final foreground combat characters.
```

Evidence:

- Original front and side pixel cards generated a voxel visual hull.
- The rotation contact sheet proves the result has real volume, not just a flat cutout.
- The whole-body hull generated 247 merged boxes from 1376 raw voxels.

Boundary:

The current whole-body hull lacks part boundaries, sockets, and clean animation control. The next test should change only the part contract:

```text
whole-body front/side cards
  -> body-part front/side cards
  -> rigid head/torso/arm/leg/weapon/backpack hulls
```

Updated evidence:

The body-part follow-up is a candidate keep for deterministic animation proofs. It creates separate head, torso, upper-arm, forearm, leg, backpack, and rifle hull nodes from original front/side cards, then renders neutral, rifle-ready, cover, and rotation captures. This solves requestable rigid poses for low-detail/background actors, but it still does not replace a Blockbench foreground combat rig.

### C10: Vengi Converter/Editor Bridge

State: Candidate bridge keep  
Scope: local voxel format conversion, `.vox` handoff, and possible future manual cleanup

Question:

Does the owner's local Vengi install change the voxel pipeline?

Result:

```text
VENGI_PIXEL_CARD_EVAL_PASS.md
generated/vengi_pixel_card_eval_v0/REVIEW.md
scripts/godot_vengi_pixel_card_eval_proof.gd
```

Verdict:

```text
Candidate bridge keep. Vengi is useful as a local `.vox`/manual-edit bridge, not as the new default model generator.
```

Evidence:

- Vengi 0.5.0 is installed at `C:\Program Files\vengi`.
- `vengi-voxconvert.exe` converted project PNG source cards to `.vox` and flat GLB.
- The flat GLBs validated with no errors and imported into Godot.
- Godot run-merged extrusion still beat Vengi's successful GLB path for true voxel props.

Boundary:

The first image-volume conversion and `.bbmodel` conversion probes hung and were stopped. Challenge this only with a focused one-variable Vengi adapter/debug pass.

## Not Locked Yet

- Exact Cantina palette and lighting recipe.
- How much grime/noise to use before blockcraft readability suffers.
- Final sign/decal workflow.
- Creature/organic hero workflow.
- Full skeletal character action animation pipeline.
- Blender/glTF animated rig export and Godot import validation.
- Whether Meshy can create useful posterized space/backdrop plates.
- Whether Meshy can contribute VFX reference without violating voxel cohesion.
- Exact Meshy refine policy if a salvage/background source is worth texturing.
- Whether any future Meshy foreground A/B can overcome the current cohesion rejection.
- Whether a real four-draft Meshy 5 API path exists outside the current v2 endpoint.
- Whether manual web UI free retry can improve a rejected but promising Meshy result without spending API credits.
- Whether Meshy image-to-3D can follow our own blockcraft source cards better than text prompts.
- Whether pixel-extrude run-merge should become locked for pickup-scale props after one real request.
- Whether pixel-hull body-part segmentation can become a character/droid production lane.
- Whether Vengi image-volume conversion can be made reliable enough to join the default pixel-card lane.
- Whether Vengi can eventually replace any Blender conversion tasks.
- Whether semantic pixel room kits should use a second elevation/detail card by default for every building/room family.
- Whether the pixel room-kit runtime proof repeats cleanly on a second SW_MUSH Cantina room.
- Full terrain-kit promotion structure.
- Whether runtime space should use 3D GLBs, sprites rendered from GLBs, or hybrid tokens.

## Superseded Decisions

### S1: Godot JSON as the Default Ship Lane

State: Superseded

Reason:

The owner suspected "ship JSON sucks," and the later Blockbench ship passes proved that editable cube-source silhouettes are the stronger path for ships. Godot remains the tactical overlay/camera proof lane, not the default ship-authoring lane.

### S2: SVG/Bitmap as Possible Final Art Substitute

State: Superseded

Reason:

SVGs and bitmaps are excellent visual contracts, but they are not enough for runtime model production. The current model source should be `.bbmodel`, structured specs, Godot scenes for procedural items, or GLB outputs validated through Blender/Godot.

## Rejected Patterns

### R1: Copy One Fan-Art Image Into a Model

State: Rejected

Reason:

Too risky, too brittle, and does not solve gameplay layout. Use reference lessons, not copied geometry or texture.

### R2: Raw Free-Asset Kit as Foreground Style

State: Rejected by default

Reason:

Breaks cohesion. Free kit assets need normalization and should mostly fill background density.

### R3: Tool Count as Progress

State: Rejected

Reason:

More tools only help if they improve quality or validation. A new tool that produces worse captures or less editable source should be documented and dropped.

## Current Recommended Production Path

For most strict voxel assets:

```text
request
  -> original pixel/semantic source card(s)
  -> deterministic Godot voxel proof
  -> camera capture and efficiency/runtime stats
  -> keep/rebuild/reject
  -> Blockbench/Blender only if hero polish, rigging, or GLB promotion is needed
```

For foreground hero assets after pixel proof:

```text
kept pixel/blockout baseline
  -> Blockbench .bbmodel
  -> Blender GLB
  -> glTF validation
  -> Godot camera proof
  -> keep/reject
```

For terrain/world spaces:

```text
game descriptions / room graph
  -> semantic pixel floor/detail cards
  -> Godot room/building kit
  -> collision/walk masks and sockets when relevant
  -> Blockbench identity modules only where needed
  -> Godot scene proof
  -> keep/reject
```

For tactical overlays:

```text
gameplay verb / UI state
  -> SVG storyboard if useful
  -> Godot procedural proof
  -> runtime promotion only after owner approval
```

For scene interaction animation:

```text
scene/module baseline
  -> anchors and props
  -> key-pose storyboard if useful
  -> Godot pose/AnimationPlayer proof
  -> captures/contact sheet
  -> keep/reject
```

For character action animation:

```text
baseline character scale
  -> shared rig contract
  -> one or two clips
  -> Blender/glTF export
  -> Godot import/camera proof
  -> expand only after validation
```

For Meshy/API model generation:

```text
focused request
  -> provider-safe prompt/spec
  -> Meshy preview only
  -> provider thumbnail
  -> GLB download and validation
  -> Godot proof beside a named baseline
  -> keep/rebuild/reject
  -> refine only if preview geometry wins
```

For pixel-card true voxel props/tokens:

```text
focused request
  -> original 16x/32x/48x pixel source card
  -> Godot pixel extrusion
  -> same-color run merge by default
  -> Godot capture beside named baseline
  -> keep/rebuild/reject
```

For pixel-hull actors:

```text
focused request
  -> original front and side pixel cards
  -> Godot visual-hull proof
  -> rotation contact sheet
  -> use as background actor, body-plan reference, or Blockbench rebuild input
```

For Vengi bridge work:

```text
project source card
  -> vengi-voxconvert PNG-to-VOX
  -> optional manual vengi-voxedit cleanup
  -> export/validate/proof
```

## How Claude Should Use This

Before making or requesting an asset:

1. Read `ASSET_REQUEST_PLAYBOOK.md`.
2. Check this decision log for locked defaults.
3. Name the baseline.
4. Name the one variable being changed.
5. Use the locked lane unless the request is explicitly an A/B test.
6. Record whether the result is kept, candidate, superseded, or rejected.

This should keep the process from bouncing between tools unless the bounce is an intentional experiment.
