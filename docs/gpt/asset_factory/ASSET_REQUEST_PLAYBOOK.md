# Asset Request Playbook

Date: 2026-07-04  
Scope: docs-only operating manual for Claude, Codex, and a future asset-pipeline skill

## Purpose

This playbook defines how Claude should ask Codex for art-pipeline work, and how Codex should decide which source material and tools to use.

The current target is a private/friends Clone Wars and WEG Star Wars blockcraft MMO direction: readable "Star Wars Minecraft" silhouettes, exaggerated faction language, tactical isometric space, and modular frontier terrain. The public-safe lane should remain generic space opera. Neither lane should use ripped official meshes, textures, logos, audio, or copied fan-art geometry.

Core loop:

```text
request -> lane choice -> visual contract -> editable source -> preview -> validation -> keep/reject verdict
```

Current tactical update:

```text
Ask "can this start as original pixel/semantic source cards?" before spending Meshy credits or hand-authoring a full model.
```

The deterministic pixel/GDScript lane is now the preferred first proof for strict voxel grammar across props, equipment, low-detail actors, ships/tactical tokens, vehicles, buildings, rooms, terrain chunks, collision, sockets, and runtime masks. Escalate to Blockbench/manual cleanup when the result needs hero polish, multi-angle editability, rigging, or final foreground identity. Keep Meshy in reserve for background plates, space ambience, VFX/reference, or a focused A/B that does not fight the voxel premise.

The important distinction is:

- SVG/bitmap/JPEG concepts are review contracts and reference summaries.
- Blockbench, Blender, Godot, or another model tool must produce the actual model candidate.
- Reference images can teach shape language, but should not become source geometry or texture data.

Current locked reference split:

```text
Game/source descriptions drive geometry and gameplay affordances.
Fan art/reference images drive mood, silhouette lessons, and style pressure.
Blockcraft grammar drives the final model.
```

Read `REFERENCE_BASE_COMPARISON.md` when a request asks whether the source should be game data, fan art, or both. Read `PIPELINE_DECISION_LOG.md` before changing a tool lane that is already marked locked.

Read `ANIMATION_REQUEST_PROTOCOL.md` before accepting an animation request. Animation requests must say whether they are scene interactions, character action clips, vehicle/tactical motion, or a mix that should be split.

Read `MESHY_PREMIUM_EVALUATION.md` and `MESHY_CREDIT_AND_TIER_STRATEGY.md` before using Meshy. The API key must come from `MESHY_API_KEY`; never write it into docs or generated files.

## Request Intake

Claude should create one focused request in:

```text
docs/gpt/asset_factory/requests/inbox/
```

Use:

```text
REQ-YYYYMMDD-short-kebab-name.md
```

Codex should answer with:

```text
docs/gpt/asset_factory/generated/<request_id>/
docs/gpt/asset_factory/requests/completed/<request_id>_RESPONSE.md
```

If the request is unsafe, too broad, or worse than baseline after testing, answer in:

```text
docs/gpt/asset_factory/requests/rejected/<request_id>_RESPONSE.md
```

Runtime game files remain read-only until the owner explicitly approves promotion.

Claude can also provide feedback instead of a new asset request:

```text
docs/gpt/asset_factory/requests/feedback/inbox/
```

Use `requests/FEEDBACK_TEMPLATE.md` when an existing artifact has been tested and Claude needs to say "this worked," "this broke," "runtime import failed," "camera read is bad," "performance is too high," or "make this the new baseline." Feedback can trigger a follow-up request, but it should not be forced into the normal request template when no new generation is being requested yet.

## Lane Selector

Use this table before creating anything.

| Asset family | Strongest starting material | Visual contract | Model lane | Validation camera |
| --- | --- | --- | --- | --- |
| Clone/trooper characters | Gameplay role plus original front/side body-part pixel cards | Pixel pose/rotation sheet; SVG only if silhouette is unclear | Godot body-part hull proof first; Blockbench/rig cleanup if foreground | Godot ground third-person and inventory/icon crop |
| Droids | Role, silhouette notes, faction color language, front/side pixel cards | Pixel or SVG front/side body-plan sheet | Godot body-part hull or extrusion first; Blockbench if hero | Godot ground and tactical encounter crop |
| Weapons | Gameplay role, carried pose, readable barrel/stock shape | 16x/32x side-view pixel card or SVG strip | Godot pixel extrusion first; Blockbench if too flat or hero | In-hand crop and ground pickup crop |
| Ships | Role plus top/side/isometric pixel cards and reference-board lessons | Pixel top/isometric plan; SVG if scale/shape needs discussion | Godot run-merged token or multi-card hull first; Blockbench if hero/rotating | Godot isometric space proof |
| Vehicles | Role plus top/side pixel cards | Pixel top/side plan | Godot run-merged token or multi-card hull first; Blockbench if close-up/rideable | Godot ground/isometric proof |
| Buildings/landmarks | Room descriptions, YAML room graph, gameplay role | Semantic floorplan/detail cards; SVG elevation if useful | Godot pixel room/building kit first; Blockbench identity caps/modules | Godot ground/isometric terrain capture |
| Terrain chunks | Map topology, combat cover needs, traversal rules | SVG tile plan, room graph, or semantic pixel card | Godot procedural/pixel blockout first, then Blockbench kit pieces for identity | Godot chunk camera and pathing sketch |
| Room kits / Cantina LOD | SW_MUSH room graph, designer layout, gameplay affordances | Semantic pixel floorplan card plus detail/elevation card | Godot pixel merge/batch for layout/collision/navigation/sockets/LOD; Blockbench for hero modules | Godot isometric/social-room capture |
| Space UI/tactical overlays | Gameplay verbs and sensor/combat states | SVG/UI storyboard | Godot procedural | Godot isometric UI capture |
| Pixel-card props/tokens | Role plus a 16x/32x/48x original pixel source card | Pixel PNG or SVG rendered to PNG | Godot pixel-extrude cubes or run-merged voxel bars | Godot item/wall/isometric capture |
| Pixel-hull actors | Role plus original front/side pixel cards | Front/side cards, ideally per body part | Godot visual-hull proof, then Blockbench if foreground | Godot rotation/pose contact sheet |
| Creatures/hero aliens | Description plus body-plan reference lessons | SVG body-plan sheet | Blockbench if simple; API/human/Blender if hero quality is required | Godot ground close-up |
| Scene interaction animation | Scene/module baseline, anchors, actors, props | Key-pose storyboard if useful | Godot pose/AnimationPlayer proof first | Godot target scene capture |
| Character action animation | Baseline rig/model, gameplay state, sockets | Pose strip or rig contract | Shared rig -> Blender/glTF clips -> Godot import proof | Godot ground/combat camera |

## Locked Tool Defaults

Use these as defaults unless the request is explicitly a focused A/B test:

- Strict voxel assets should start with original pixel/semantic cards when feasible: pixel extrusion for flat props/tokens, body-part hulls for low-detail actors/droids, top/isometric cards for ship tokens, and semantic floor/detail cards for rooms/buildings.
- Foreground identity assets that outgrow the pixel proof use Blockbench `.bbmodel` as the cleanup/hero source, Blender `.glb` conversion, glTF validation, and Godot proof if runtime-bound.
- Godot is the test bench for terrain blockouts, review scenes, camera proofs, isometric tactical overlays, and procedural UI/game-state visualization.
- Pixel source cards may become actual cube geometry only when the source card is original project art, an owner sketch, or a project-generated SVG/bitmap. Use same-color run merge by default for production props.
- Pixel hulls may be used for low-detail actors and body-plan exploration. Treat whole-body hulls as research; use body-part hulls or Blockbench for animated foreground characters.
- Semantic pixel room/building cards may emit visual geometry, masks, collision shapes, navigation/walk targets, and interaction sockets. Treat this as the structural/runtime layer, not the final hero-art layer.
- Kenney/Quaternius assets are filler clay only. They can support background density after palette/style normalization, but should not become the recognizable identity layer.
- Fan art/reference images are mood and silhouette lessons only. They should be converted into written grammar cards, not traced or converted.

If a locked default feels wrong, run one variable against a named baseline and record the keep/reject result in `PIPELINE_DECISION_LOG.md` or the generated review doc.

## Source Material Rules

### In-game and SW_MUSH descriptions

Use descriptions when the asset is about gameplay, location logic, room identity, or WEG flavor. This is the best default for terrain, Cantina rooms, terminals, cover, doors, faction checkpoints, and most player-facing props.

Process:

```text
description/YAML -> nouns and verbs -> SVG contract -> kit/spec -> model lane
```

For the Cantina specifically, `C:\SW_MUSH` has multiple rooms and YAML topology, but no SVGs. The correct comparison is:

```text
fan-art mood lessons
vs.
our own SVGs made from SW_MUSH/project room descriptions
```

Do not claim SW_MUSH provides SVGs for this.

For the current kept Cantina entrance, the reference basis is game/SW_MUSH/project-description geometry first, not fan-art geometry. Fan art should be tested next only as a material/lighting/clutter mood pass while keeping the model fixed.

### Fan art, LEGO-like, and online references

Use references when silhouette family matters more than exact lore text, especially ships and hard hero shapes. The reference workflow is:

```text
reference board -> proportions and silhouette lessons -> original cube grammar -> new model
```

Allowed:

- broad silhouette families;
- proportion lessons;
- color-language notes;
- "what makes this readable at 64 px?" observations;
- multiple references averaged into an original blockcraft design.

Not allowed:

- tracing;
- texture sampling;
- direct conversion;
- copied logos, markings, or exact protected shapes;
- using fan art as a mesh or texture source.

The private lane can push Star Wars readability hard. It should still rebuild assets from original cube grammar.

### SVGs and bitmaps

SVGs are excellent for Codex because they can express silhouette, floorplan, color zones, and camera composition precisely. They are not final models.

Use SVG first when:

- a character needs front/side readability decisions;
- a weapon needs a compact silhouette;
- a terrain space needs a floorplan;
- a ship needs top/isometric proportions before modeling;
- Claude or the owner needs to choose between two directions before spending modeling time.

Skip SVG when:

- the model is a small one-variable tweak from a kept Blockbench baseline;
- the request is purely a Godot camera/import proof;
- a simple spec edit is faster and less ambiguous.

### Kenney and other free kits

Kenney assets are filler clay, not the identity layer.

Use Kenney for:

- background massing;
- generic crates, barrels, rocks, planks, tools, tents, dishes;
- early terrain scale checks;
- non-hero clutter after palette normalization.

Do not use raw Kenney for:

- hero ships;
- faction-signaling characters;
- iconic weapons;
- landmark identity;
- anything the owner needs to recognize as "Star Wars Minecraft."

If Kenney is used in a foreground scene, test it beside a kept Blockbench baseline and normalize material palette, bevel/chunk scale, and camera framing.

## Tool Roles

### Blockbench

Best current tool for editable blockcraft identity assets:

- characters;
- droids;
- weapons;
- small props;
- ship silhouettes;
- faction identity pieces;
- modular landmark caps.

This default is now locked for foreground identity assets after blockout. Do not switch back to Godot-only JSON for ships, characters, droids, weapons, or kept landmark modules unless running a documented A/B test.

Outputs to keep:

- `.bbmodel` source;
- palette texture;
- fast PNG preview;
- converted `.glb`;
- rendered GLB preview;
- validation notes.

### Blender

Use Blender as the conversion, preview, and cleanup stage:

- convert generated `.bbmodel` to `.glb`;
- render GLB previews;
- validate scale and orientation;
- later, run decimation/merge/UV cleanup if needed.

Do not hand-author large Blender scenes unless the request specifically calls for a Blender lane. The repeatable pipeline should keep Blockbench or specs as the source of truth.

### Godot

Use Godot for runtime-oriented proof:

- docs-only scene captures;
- camera scale checks;
- isometric space proof;
- terrain blockout;
- tactical overlays;
- comparing assets in the same lighting/camera as the game.

Godot procedural generation is still good for terrain and overlays. It should not be assumed better for ships or characters.

This default is locked for blockouts, tactical overlays, review scenes, and camera/import proofs. Godot remains essential even when Blockbench is the model source.

Important capture note: `godot_glb_camera_proof.gd` currently needs a non-headless Godot run for screenshots.

### Pixel Extrusion in Godot

Use pixel extrusion when strict Minecraft-style grid geometry matters more than organic 3D modeling:

- weapon pickups;
- datapads and small inventory props;
- signs and decals with depth;
- wall terminals and UI-like panels;
- isometric tactical ship tokens;
- faction badges or small marker props.

Current proof:

```text
PIXEL_EXTRUDE_GODOT_PASS.md
generated/godot_pixel_extrude_v0/REVIEW.md
```

Default process:

```text
role/request
  -> 16x/32x/48x original pixel source card
  -> Godot pixel extrusion
  -> same-color run merge by default
  -> Godot capture beside baseline
```

Use per-pixel cubes only when the pixelated surface is the point. Use same-color run merging for most production props because it preserves the silhouette while reducing object count and producing cleaner rectangular voxel bars.

Do not use single-layer prop extrusion for full humanoids, large buildings, or terrain chunks. Those should use body-part hulls, semantic room/building cards, Blockbench cleanup, or Godot blockouts.

### Pixel Hulls in Godot

Use pixel hulls when the request needs deterministic voxel volume from flat source art:

- low-detail background NPCs;
- simple droids;
- body-plan exploration for characters;
- icon-scale actors for social or tactical scenes.

Current proof:

```text
PIXEL_HULL_CHARACTER_PASS.md
generated/godot_pixel_hull_character_v0/REVIEW.md
PIXEL_HULL_BODY_PARTS_PASS.md
generated/godot_pixel_hull_body_parts_v0/REVIEW.md
```

Default process:

```text
role/request
  -> original front card
  -> original side card
  -> Godot visual hull
  -> flat-vs-volume capture
  -> rotation contact sheet
```

Do not use a whole-body pixel hull as a final combat character. The next production-shaped version should split the source cards into body parts:

```text
head / torso / upper arms / lower arms / legs / weapon / backpack
```

Those parts can then become rigid animation pieces or Blockbench rebuild references.

The body-part proof has now been tested. Use it when a request needs quick deterministic pose evidence for low-detail/background actors. For foreground combat rigs, treat it as a proportion/pose contract and rebuild in Blockbench.

### Pixel Room Kits in Godot

Use semantic pixel room kits when a location needs cheap, deterministic structure before hero art:

- Cantina blockouts;
- room graph visualization;
- collision and navigation layout;
- distant/interior LOD;
- cheap filler walls/floors/furniture beneath authored identity modules.

Current proof:

```text
PIXEL_CANTINA_KIT_PASS.md
generated/godot_pixel_cantina_kit_v0/REVIEW.md
PIXEL_CANTINA_LAYERED_KIT_PASS.md
generated/godot_pixel_cantina_layered_kit_v1/REVIEW.md
PIXEL_CANTINA_RUNTIME_PASS.md
generated/godot_pixel_cantina_runtime_v1/REVIEW.md
```

Default process:

```text
room graph / layout request
  -> 32x/48x/64x semantic floorplan card
  -> optional detail/elevation card
  -> greedy rectangle merge
  -> material-batched Godot meshes
  -> Godot capture and efficiency stats
```

For production-shaped room requests, prefer the external-card adapter:

```text
room graph / layout request
  -> JSON spec with floor/detail cards, symbols, socket roles, sockets, and path probes
  -> godot_pixel_room_runtime_adapter.gd
  -> masks / collision / role-colored sockets / captures / manifest
```

Do not emit one MeshInstance per source pixel in production. The tested Cantina v0 card had 966 non-empty pixels, but merged to 74 rectangles and 8 material-batched mesh nodes. The v1 layered card had 1,107 combined non-empty pixels, but merged to 101 rectangles and 16 material-batched mesh nodes. Use Blockbench for hero modules placed on top of the generated room structure.

The runtime proof adds the production-shaped target: 439 walkable pixels merged to 40 walk rectangles, 527 blocker pixels merged to 38 collision shapes, named sockets, socket-to-walk-cell resolution, and grid-routed actor probes. Use this as the model for room requests that need gameplay affordances as well as visual massing.

The adapter proof moves that same room data out of hard-coded GDScript and into `specs/pixel_room_cantina_runtime_adapter_v0.json`. The current spec includes explicit socket roles and optional facing/action fields. Use these roles when requesting rooms:

```text
seat       sit/social anchors
stand      NPC/player staging anchors
spawn      entry placement anchors
use        bar, terminal, door, or prompt target
inspect    signs and readable props
cover      tactical cover affordance
transition room exits
prop       dressing hook
light      lamp/fixture hook
```

For every room request, ask for the gameplay sockets as deliberately as the walls. A good room spec says where players can sit, stand, use, inspect, take cover, transition, and where props/lights should attach.

### Vengi

Vengi is installed locally at:

```text
C:\Program Files\vengi
```

Useful binaries:

```text
C:\Program Files\vengi\voxconvert\vengi-voxconvert.exe
C:\Program Files\vengi\voxedit\vengi-voxedit.exe
C:\Program Files\vengi\thumbnailer\vengi-thumbnailer.exe
C:\Program Files\vengi\palconvert\vengi-palconvert.exe
```

Current proof:

```text
VENGI_PIXEL_CARD_EVAL_PASS.md
generated/vengi_pixel_card_eval_v0/REVIEW.md
```

Use Vengi today as a bridge:

```text
project PNG source card -> .vox -> optional manual Vengi/MagicaVoxel-style cleanup -> later export/proof
```

Do not use Vengi today as the default replacement for Godot pixel extrusion or Blender conversion. PNG-to-flat-GLB and PNG-to-VOX worked; image-volume import and `.bbmodel` conversion hung in the first probe and need a focused adapter/debug pass.

### glTF Transform

Use `gltf-transform validate` on every kept GLB candidate. A model is not ready for promotion discussion without a validation note.

### Paid/API tools

Use only when a request cannot be solved by the grammar:

- hero creatures;
- complex helmets or faces;
- organic statues or landmark dressing;
- high-value hero ships;
- animation sources.

Any API lane must output editable or reviewable artifacts and should not become an uninspectable black box.

Meshy Premium is now available as an experiment lane. Use preview-first and no auto-refine. A Meshy result needs provider thumbnail review, GLB validation, and Godot camera proof before it can become a candidate.

Use Meshy for high-entropy assets, not merely high-impact assets. A hero building module that needs exact blockcraft editability may still be better hand-rolled; a weird alien, machinery cluster, or hard ship silhouette may deserve Meshy earlier.

## Current Commands

Run the Godot procedural factory:

```powershell
.\docs\gpt\asset_factory\scripts\run_godot_factory.ps1
```

Run a specific Godot spec:

```powershell
.\docs\gpt\asset_factory\scripts\run_godot_factory.ps1 -Spec "res://docs/gpt/asset_factory/specs/private_clone_wars_blockcraft_v0.json"
```

Generate Blockbench sources and fast previews:

```powershell
node .\docs\gpt\asset_factory\scripts\blockbench_cubecraft_factory.mjs .\docs\gpt\asset_factory\specs\blockbench_cubecraft_v0.json
```

Convert generated Blockbench models to GLB:

```powershell
.\docs\gpt\asset_factory\scripts\run_blockbench_to_glb.ps1 `
  -BbmodelDir "docs\gpt\asset_factory\generated\blockbench_cubecraft_v0\blockbench" `
  -OutDir "docs\gpt\asset_factory\generated\blockbench_cubecraft_v0\glb"
```

Validate a GLB:

```powershell
gltf-transform validate docs\gpt\asset_factory\generated\blockbench_cubecraft_v0\glb\cubecraft_clone_rifleman_01.glb
```

Run the Godot GLB camera proof:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_glb_camera_proof.gd
```

Run the current Cantina exterior clutter kit proof:

```powershell
node .\docs\gpt\asset_factory\scripts\blockbench_cubecraft_factory.mjs .\docs\gpt\asset_factory\specs\blockbench_cantina_exterior_clutter_v1.json
.\docs\gpt\asset_factory\scripts\run_blockbench_to_glb.ps1 -BbmodelDir "docs\gpt\asset_factory\generated\blockbench_cantina_exterior_clutter_v1\blockbench" -OutDir "docs\gpt\asset_factory\generated\blockbench_cantina_exterior_clutter_v1\glb"
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_cantina_exterior_clutter_kit_proof.gd
```

Run the current Cantina bar/booth bay proof:

```powershell
node .\docs\gpt\asset_factory\scripts\blockbench_cubecraft_factory.mjs .\docs\gpt\asset_factory\specs\blockbench_cantina_bar_booth_bay_v1.json
.\docs\gpt\asset_factory\scripts\run_blockbench_to_glb.ps1 -BbmodelDir "docs\gpt\asset_factory\generated\blockbench_cantina_bar_booth_bay_v1\blockbench" -OutDir "docs\gpt\asset_factory\generated\blockbench_cantina_bar_booth_bay_v1\glb"
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_cantina_bar_booth_bay_proof.gd
```

Run the current Cantina seated-social animation proof:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_cantina_seated_social_animation_proof.gd
```

Run the current body-part pixel-hull actor proof:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_pixel_hull_body_parts_proof.gd
```

Run the current pixel Cantina room-kit proof:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_pixel_cantina_kit_proof.gd
```

Run the current layered pixel Cantina room-kit proof:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_pixel_cantina_layered_kit_proof.gd
```

Submit one Meshy preview with the Windows-native adapter:

```powershell
$env:MESHY_API_KEY = "<set locally>"
.\docs\gpt\asset_factory\adapters\meshy_text_to_3d.ps1 -Command run-preview `
  -Spec .\docs\gpt\asset_factory\specs\meshy_eval_v0.json `
  -AssetId meshy_cantina_service_terminal_v0 `
  -OutDir .\docs\gpt\asset_factory\generated\meshy_eval_v0
```

Run the current Meshy preview proof after a Meshy model exists:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_meshy_eval_proof.gd
```

Run the current pixel-card extrusion proof:

```powershell
& "C:\Godot 4\Godot_v4.6.3-stable_win64_console.exe" --path . --script res://docs/gpt/asset_factory/scripts/godot_pixel_extrude_proof.gd
```

## Iteration Discipline

Change one variable at a time. A variable can be:

- cube granularity;
- palette contrast;
- silhouette width;
- panel detail density;
- camera angle;
- material normalization;
- reference source;
- tool lane.

For every pass, record:

- baseline;
- changed variable;
- expected improvement;
- generated files;
- capture paths;
- validation result;
- keep/reject verdict;
- next one-variable change.

If a pass is worse, do not rationalize it. Mark it rejected or superseded, and keep the better baseline.

## Asset-Family Guidance

### Characters

The current read is that characters outperform ships because the cube grammar matches humanoid readability well. Start with gameplay role and description, not fan art.

Recommended path:

```text
role/description -> optional SVG front/side card -> Blockbench -> Blender GLB -> Godot ground proof
```

Use bigger symbolic features than realism:

- helmet stripe;
- backpack/radio mast;
- pauldron;
- visor band;
- shoulder block color;
- weapon silhouette;
- faction color plates.

If the model feels like "big blocks," improve by adding small panel cubes on top of the macro body, not by abandoning the blockcraft style.

### Ships

Do not assume JSON-to-Godot is best for ships. The current suspicion is valid: ships need silhouette research before cube placement.

Recommended path:

```text
ship role -> reference-board lessons or SVG top/isometric plan -> Blockbench -> Blender GLB -> Godot isometric proof
```

Use reference images or LEGO-like builds as lessons only. Extract:

- nose language;
- wing count and sweep;
- cockpit placement;
- engine cluster rhythm;
- faction color zones;
- how readable the ship is at small tactical scale.

Then rebuild as an original microfighter grammar. Exaggerate profile and panel contrast.

For tactical space tokens, also consider the pixel-extrude lane:

```text
32x32 top-down pixel ship card -> run-merge extrusion -> Godot isometric proof
```

The first proof reads closer to true cube-grid style than Meshy text-to-3D, but it is flatter than a fully authored Blockbench microfighter.

If a ship token only needs icon-scale readability, use pixel-extrude/run-merge before Blockbench. If it needs cockpit/engine volume and rotation readability, use Blockbench.

### Terrain and Cantina

Terrain should start from gameplay space, not decorative props.

Recommended path:

```text
SW_MUSH/project room descriptions -> room graph -> SVG floorplan/elevation -> Godot blockout -> Blockbench identity kit -> Godot capture
```

For Chalmun's Cantina, preserve:

- elevated entrance transition;
- no-droids/droid detector beat;
- main bar wall;
- curved booth perimeter;
- bandstand;
- back hallway with restrooms/cellar/curtained office.

Fan art can help mood, density, arch shapes, and lighting expectations. The actual plan should come from the descriptions and room topology.

Current reusable exterior dressing candidate:

```text
generated/godot_cantina_exterior_clutter_kit_v1/REVIEW.md
```

Use the kit sparingly. It is stronger than raw proof boxes, but it should be placed per room or exterior chunk and re-captured rather than stamped everywhere.

Current editable main-bar/booth-bay candidate:

```text
generated/godot_cantina_bar_booth_bay_v1/REVIEW.md
```

Use this before creating a connected Cantina interior scene. It is a candidate identity module, not a full room layout.

For Cantina wall signs, terminals, menu panels, warning plates, and small decorative plaques, the pixel-extrude lane may now beat both Meshy and manual cube glyphs because it guarantees readable symbols and true grid geometry.

### Buildings

Use modular kits:

- wall bay;
- doorway;
- window slit;
- awning;
- roof cap;
- sign plate;
- interior divider;
- booth/bench/table;
- service counter;
- scatter clutter.

The identity layer should be custom. Kenney can fill the room only after custom pieces define the style.

### Weapons

Use SVG silhouettes early. Weapons need readability at tiny scale and in hand.

Recommended path:

```text
gameplay role -> SVG silhouette strip -> Blockbench -> Blender GLB -> in-hand and pickup preview
```

Prefer exaggerated barrels, stocks, magazines, blades, emitters, and color bands.

For pickup-scale weapons, consider a pixel-card extrusion first:

```text
32x16 side-view pixel card -> run-merge extrusion -> pickup/in-hand proof
```

If the result is too flat, use the pixel card as a silhouette contract for Blockbench.

### Droids

Droids can be very strong if their body plan is simple:

- stick-limbed infantry droid;
- heavier torso droid;
- rolling shield threat;
- probe/sensor droid;
- repair/service droid.

Use SVG front/side before Blockbench if the request involves a new body plan.

### Animation

Read `ANIMATION_REQUEST_PROTOCOL.md` before accepting animation work.

Use two lanes:

```text
scene interaction animation
  -> anchors / props / key poses / Godot proof

character action animation
  -> shared rig / sockets / Blender or glTF clips / Godot import proof
```

The current scene-interaction candidate is:

```text
generated/godot_cantina_seated_social_anim_v0/REVIEW.md
```

Use it as the request/proof pattern for seated Cantina conversations, bar-lean loops, terminal interactions, and other environment-bound animation asks.

Do not use that proof as evidence that clone-trooper locomotion is solved. For a clone trooper, request a focused rig/clip slice first:

```text
shared_blockcraft_humanoid_rig_v0
idle_rifle_loop
fire_rifle_once
```

Then validate imported clip names and camera readability in Godot before expanding to walk, run, reload, or cover.

### Meshy and API-generated models

Meshy is now available for bounded testing, but it should not override the locked Blockbench identity lane by default.

Use Meshy for hard assets where a prompt may save real concept/modeling time:

- unusual machinery;
- creatures and organic aliens;
- hero props;
- hard vehicle silhouettes;
- style/mood references for later Blockbench rebuilds.

Do not use Meshy for simple blockcraft assets where a generated `.bbmodel` is already faster, cheaper, and more editable.

Current Meshy baseline:

```text
generated/meshy_eval_v0/REVIEW.md
```

Verdict:

```text
Candidate lesson keep. Clean GLB, useful shape language, not direct runtime keep.
```

Use preview-first:

```text
Meshy preview -> thumbnail + GLB validation + Godot proof -> keep/rebuild/reject -> refine only if geometry wins
```

For the current blockcraft target, `model_type: "lowpoly"` remains the style-first Meshy default. However, the strict lowpoly/voxel service-terminal test was too bland as a direct keep. The observed Meshy 5 v2 API path returned one GLB for 5 credits, not four variants, and is currently the better cost/value option-mining lane.

Current Meshy test artifacts:

```text
meshy_cantina_service_terminal_voxel_lowpoly_v1
meshy_cantina_service_terminal_meshy5_draft_v1
meshy_cantina_service_terminal_meshy5_draft_v1_refine_v1
```

Use Meshy refine only after a preview geometry seed is worth judging with texture. The first refine test proves textures import into Godot, but it does not make the asset automatically cubecraft-cohesive.

Do not assume API free retries exist. Meshy's help center says API retry is not currently supported for individual/studio teams; use manual web UI free retries if needed.

Meshy image-to-3D is not the same as pixel extrusion. Image-to-3D may help Meshy follow a blockcraft style card better than text prompts, but it still returns AI-generated continuous mesh geometry. If the target is true voxel, try pixel extrusion first.

When the user asks "why not give Meshy an image?", answer:

```text
We can, but first ask whether the desired output is strict voxel or AI mesh.
Strict voxel -> pixel-extrude the original source card in Godot.
AI mesh/style interpretation -> Meshy image-to-3D with our own generated blockcraft card, then validate beside baseline.
```

## Quality Gates

A kept asset needs:

- clear gameplay role;
- source boundary recorded;
- editable source, preferably `.bbmodel` or a structured spec;
- preview capture;
- GLB validation when GLB exists;
- Godot camera proof for assets headed toward runtime;
- keep/reject verdict against a named baseline;
- next improvement recommendation.

A kept animation proof also needs:

- animation family stated;
- stable clip names;
- named anchors or sockets;
- keyframe captures or contact sheet;
- saved Godot proof scene or validated animated GLB;
- explicit note if it is only a pose/interaction proof, not a final rig.

A rejected asset should still be useful. Record why it failed:

- too generic;
- too close to protected reference;
- unreadable at camera distance;
- bad scale;
- incohesive with kept assets;
- tool friction too high;
- worse than baseline.

## Claude Request Examples

Good character request:

```text
Create a clone commander blockcraft pass. Keep the rifleman body scale, change only helmet stripe, shoulder pauldron, kama/skirt block, and color contrast. Compare against cubecraft_clone_rifleman_01.
```

Good ship request:

```text
Create one friendly interceptor silhouette pass. Use broad LEGO-like/reference lessons for a pointed nose, side wings, bubble cockpit, and twin engine read, but rebuild as original cubes. Compare against micro_arc_interceptor_panel_v2 in Godot isometric camera.
```

Good terrain request:

```text
Create a Cantina entrance kit pass from the SW_MUSH room descriptions: elevated threshold, droid detector, no-droids sign, dim interior hint, transition stairs. Produce SVG contract first, then a Godot blockout or Blockbench kit.
```

Good animation request:

```text
Create a Cantina seated-social interaction proof using the kept bar/booth bay. Keep the GLB fixed. Use seat_anchor_a, seat_anchor_b, table_anchor, and the clips sit_idle_loop, lean_talk_loop, drink_loop, and turn_to_speaker_loop. Return keyframe captures and a saved Godot proof scene.
```

Bad request:

```text
Make all Star Wars models from fan art.
```

Reject or split this into focused, safe, one-variable requests.

## When To Build The Installed Skill

Do not install the skill until the process has survived several request cycles:

1. Claude submits at least one character request.
2. Claude submits at least one ship request.
3. Claude submits at least one terrain/building request.
4. Codex produces keep/reject responses with captures and validation.
5. The owner agrees the outputs are close enough to the "Star Wars Minecraft" target to scale.

Until then, keep the skill as a draft in:

```text
docs/gpt/asset_factory/codex_skill_draft/
```
