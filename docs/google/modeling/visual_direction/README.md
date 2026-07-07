# GPT Visual Direction Packet

Date: 2026-07-03  
Scope: visual direction only; no runtime game files changed

## Why This Exists

The current prototype looks rough. That is normal, but it is also now becoming a blocker because the player-facing presentation does not communicate the strength of the backend systems.

This packet is meant to give Claude and the owner a concrete visual target to evaluate. It separates three different things that are easy to blur together:

1. Concept bitmaps: mood and art-direction reference.
2. Godot models/scenes: actual 3D objects, materials, lighting, cameras, and composition.
3. Gameplay projection: especially the corrected 2.5D space vision.

The bitmaps are not production assets. They are taste references. The `.tscn` files are also not production scenes. They are implementation-facing examples showing how Godot presentation can be composed from meshes, materials, lights, and cameras.

## Direct Answer: Bitmaps vs Godot Models

Rendered bitmaps and Godot modeling are very different skills.

A bitmap concept image is useful for:

- Mood.
- Palette.
- Lighting.
- Composition.
- Silhouette density.
- Showing whether a style feels right.
- Explaining "make it feel more like this."

A Godot model or scene is different. In Godot, the practical chain is usually:

```text
Blender / Blockbench / asset pack / AI 3D tool
  -> GLB or glTF model
  -> Godot import
  -> PackedScene / inherited scene
  -> materials, lights, collisions, scripts, LODs
  -> instanced into gameplay scenes
```

For this project, bitmaps should guide the eye. Godot scenes and GLB/glTF assets should ship the game.

## Included Artifacts

### Concept References

- `concepts/ground_spaceport_art_direction.png`
  - A visual target for the Mos Eisley-style ground MMO slice.
  - Shows how low-poly pieces can feel better with cohesive lighting, awnings, cargo, silhouettes, scale, and warm/cool color contrast.

- `concepts/isometric_space_art_direction.png`
  - A visual target for the corrected 2.5D space idea.
  - Flat x/y tactics, but rendered through an isometric camera with ship silhouettes, selection rings, parallax, glow, and a diamond-grid playfield.

### Projection Diagram

- `space_projection_comparison.svg`
  - Shows the difference between the earlier flat-overlay feeling and the desired isometric 2.5D space presentation.

### Godot Scene Examples

- `godot_scene_examples/ground_spaceport_visual_blockout.tscn`
  - A Godot-native reference scene made from primitive meshes and materials.
  - Demonstrates how a desert spaceport can be improved through scale, composition, domes, awnings, crates, light direction, and camera framing.

- `godot_scene_examples/isometric_space_visual_blockout.tscn`
  - A Godot-native reference scene for isometric 2.5D space.
  - Keeps gameplay implied as a flat x/z tactical plane while presenting ships with an orthographic isometric camera.

- `godot_scene_examples/ground_asset_kitbash_reference.tscn`
  - A Godot-native reference scene using existing project Kenney GLB assets.
  - Demonstrates the realistic free-asset path: coherent but still visibly toy-like until material/lighting/composition work improves it.

- `godot_scene_examples/isometric_space_asset_reference.tscn`
  - A Godot-native reference scene using existing project Kenney GLB ships and meteors.
  - Demonstrates the practical 2.5D space approach: GLB ships on a flat tactical plane with an orthographic isometric camera.

### Captures

- `captures/ground_spaceport_visual_blockout_godot.png`
- `captures/isometric_space_visual_blockout_godot.png`
- `captures/ground_asset_kitbash_reference_godot.png`
- `captures/isometric_space_asset_reference_godot.png`

These captures were rendered by Godot 4.6.3 using `render_reference_scenes.gd`. They are included so the owner can compare aspirational concept art against actual in-engine output.

See `EVALUATION_CONTACT_SHEET.md` for a side-by-side evaluation page.

These scenes live under `docs/gpt`, so they do not affect runtime unless intentionally copied or opened.

## Corrected 2.5D Space Vision

The intended 2.5D space mode should not be a flat top-down board placed over the ground UI.

The intended model is:

```text
Simulation:
  - 2D tactical state.
  - Positions are x/y or x/z.
  - No true 6DOF dogfighting.
  - Altitude is not a primary mechanic.

Presentation:
  - Orthographic isometric camera.
  - Ship models or sprites have visible top and side faces.
  - The playfield reads as a diamond/grid plane.
  - Selection rings, movement paths, sensor pings, threat arcs, and shadows/glow sell depth.
  - Parallax star layers and nebula planes make space feel alive.
```

This is closer to an isometric tactics game than a flight sim.

In Godot terms, this can be implemented as:

```text
World state:
  Vector2 tactical_position

Presentation mapping:
  Node3D.position = Vector3(tactical_position.x, 0.0, tactical_position.y)

Camera:
  Camera3D
  projection = orthographic
  elevated 3/4 isometric angle
  fixed or softly panning

Ships:
  simple 3D meshes, GLBs, or sprite impostors
  rotated to face tactical heading
  anchored to the x/z plane

UI:
  selection rings on the plane
  movement path arcs on the plane
  sensor ranges as transparent discs/rings
  threat markers and range bands
```

The simulation can stay simple. The presentation should not look flat.

## Visual Diagnosis

The current issue is probably not "there are no assets." The project already contains a large free-asset archive. The issue is that assets need a coherent visual language.

The project has many Kenney-style assets. Kenney is useful because it is clean, CC0, and consistent. But raw Kenney assets can look toy-like if they are dropped into a scene without:

- strong lighting;
- a consistent palette;
- readable silhouettes;
- scale contrast;
- environmental composition;
- decals or color accents;
- props arranged into believable clusters;
- camera framing;
- terrain/material grounding.

The art problem is therefore partly technical art, not pure modeling.

After rendering the included Godot references, my honest read is:

- Primitive blockouts prove projection/composition but look poor.
- Existing Kenney GLBs give a more coherent prototype look, especially for space, but still read as toy-like without material and lighting work.
- The generated concept images are useful as art direction, not a realistic immediate Godot output target.
- The most plausible near-term quality jump is not "generate finished models"; it is "make a small, cohesive kitbashed hero slice and light it well."

## Recommended House Style

For the near term, do not chase realism.

Recommended target:

```text
Stylized low-poly space-opera frontier.
Kenney/Quaternius-compatible forms.
Simple geometry, strong silhouettes.
Warm desert lighting on ground.
Cool luminous tactical readability in space.
No recognizable protected franchise ships or characters in asset sources.
Star Wars feeling comes from composition, rules, names, locations, and arrangement.
```

The game can feel better quickly if it commits to a polished stylized look rather than mixing random free packs.

## Ground Visual Direction

The Mos Eisley ground MMO slice should feel like:

- harsh desert sun;
- soft blue shade;
- domed plaster buildings;
- rusty industrial piping;
- cargo clusters;
- awnings and cloth shade;
- landing pad markings;
- small NPC/vendor clusters;
- blaster cover that is readable from gameplay camera distance;
- cyan/blue sci-fi accent lights used sparingly;
- faction/security information through banners, lamps, patrols, signage, and zone color.

Key improvement areas:

1. Lighting
   - Use one strong directional sun.
   - Use ambient fill so shadows are readable.
   - Add warm/cool contrast.

2. Composition
   - Build plazas, alleys, gates, and landing pads, not scattered props.
   - Keep traversable paths visible.
   - Place props in clusters that imply function.

3. Silhouette
   - Use domes, antennas, awnings, moisture-vaporator shapes, crates, and pipes.
   - Avoid generic flat boxes unless they are dressed.

4. Gameplay readability
   - Cover objects should read as cover.
   - Vendors should look like vendors.
   - Danger exits should look dangerous.
   - Travel points should have strong landmarks.

## Space Visual Direction

The space layer should feel like an elegant tactical holomap made alive.

Use:

- orthographic isometric camera;
- diamond grid;
- layered starfields;
- nebula cards/planes;
- transparent sensor rings;
- selection rings;
- movement paths;
- projected threat arcs;
- simple ship meshes with strong top/side silhouettes;
- engine glows;
- tiny motion/parallax.

Avoid:

- flat top-down board feel;
- full 3D dogfight expectations;
- cockpit presentation;
- UI overlay that does not replace ground mode;
- keeping ground UI/camera active while in space;
- any mode where the player cannot tell whether they are physically in space.

The player object should be in one place. If they are in space, ground control should be gone.

## What I Would Do

If I were driving the visual pass, I would not start by hand-modeling everything.

I would do this:

1. Pick one house style.
   - Keep Kenney for environment blocking.
   - Use Quaternius only when it does not clash, or in visually distinct zones.

2. Build a small hero slice.
   - One polished spaceport plaza.
   - One landing bay.
   - One lawless exit.
   - One vendor cluster.
   - One combat-cover lane.

3. Create a material/lighting kit.
   - Sand plaster.
   - Dark metal.
   - Teal/cyan sci-fi accent.
   - Red/orange awning cloth.
   - Dusty road/floor.

4. Build reusable scene chunks.
   - Dome building cluster.
   - Cargo stack.
   - Vendor stall.
   - Cover barricade.
   - Landing-pad edge.
   - Zone gate.

5. Make 2.5D space as its own complete visual mode.
   - Orthographic isometric camera.
   - Isometric grid.
   - Ships anchored to a 2D plane.
   - Selection and movement VFX.
   - No ground UI.

6. Only then look for custom models.
   - Custom models are expensive in time.
   - Bad custom models will look worse than coherent kitbashed assets.

## Where To Get Modeling Help

My recommendation:

- Use Codex/GPT for art direction, scene composition, procedural blockouts, Godot material setup, importer scripts, model-pipeline docs, style audits, and implementation examples.
- Use Claude for integrating the visual direction into the existing codebase if Claude is already the active development driver.
- Use a human Blender artist or technical artist when you need distinctive production-quality characters, ships, creatures, animations, or cleanup of generated models.
- Use Fable, image generators, or similar tools for visual mockups and style exploration, not as the final model source unless they export clean, game-ready GLB/glTF with licensing you trust.

Free/cheap modeling stack:

- Blender: best serious free 3D tool.
- Blockbench: easier low-poly modeling and animation tool.
- Kenney: excellent CC0 placeholder and stylized asset source.
- Quaternius: useful low-poly characters, creatures, mechs, and ships; style must be managed.
- Poly Pizza: useful for individual CC0/CC-BY models, but titles/licenses should be vetted.
- AI 3D tools: useful for rough placeholder GLBs, but usually need cleanup, retopology, material pass, and style normalization.

For this specific game, the most valuable outside help would be a technical artist comfortable with:

- Blender to Godot GLB workflow;
- low-poly kitbashing;
- material normalization;
- collision setup;
- LODs;
- simple animation;
- isometric camera presentation;
- making cheap assets feel intentional.

## Why Not Just Generate Bitmaps?

Bitmaps can be used for:

- splash art;
- loading screens;
- mood boards;
- UI backgrounds;
- concept targets;
- 2D sprites if the game chooses a sprite pipeline.

But for a 3D/2.5D Godot MMO, bitmaps alone are not enough. The game needs:

- meshes;
- materials;
- collision shapes;
- cameras;
- lights;
- animation;
- scale consistency;
- runtime instancing;
- interaction markers;
- performance budgets.

The better use of image generation is to decide what to build, then build it with Godot-friendly assets.

## Godot Import Notes

Godot's recommended model path is glTF/GLB. A `.glb` file packages mesh and textures compactly and imports into Godot as a scene. Godot can also import `.blend` through Blender's glTF exporter, but the cleanest project artifact for game assets is usually `.glb` or `.gltf`.

Practical rule:

```text
Source/edit in Blender or Blockbench.
Export GLB/glTF.
Import into Godot.
Create inherited/custom scene for materials, lights, collision, script hooks.
Instance that scene in runtime.
```

Do not make runtime gameplay depend directly on concept PNGs unless the chosen art direction is deliberately sprite-based.

## Claude Evaluation Checklist

Claude should evaluate visual changes against:

1. Does the scene communicate where the player is?
2. Does it communicate what can be interacted with?
3. Does it improve gameplay readability?
4. Does it preserve WEG/Clone Wars tone without requiring trademarked models?
5. Does it use one coherent asset style?
6. Does it avoid mixing raw Kenney and Quaternius assets in the same shot unless normalized?
7. Does the camera support combat, targeting, and navigation?
8. Does the player physically leave ground mode when entering space?
9. Does space read as isometric 2.5D, not flat top-down?
10. Does the scene run cheaply enough for an MMO client?

## Source References

- Godot stable docs recommend glTF/GLB for 3D import and explain that `.glb` can include mesh and textures compactly: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- Godot import docs recommend doing final lighting in Godot rather than relying entirely on imported 3D-scene lights: https://docs.godotengine.org/en/4.1/tutorials/assets_pipeline/importing_scenes.html
- Blender is the main free/open-source 3D creation suite: https://www.blender.org/
- Blockbench is free/open-source and suitable for low-poly modeling/animation: https://www.blockbench.net/
- Kenney states its asset-page game assets are CC0/public-domain licensed: https://kenney.nl/support
