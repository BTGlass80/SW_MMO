# Reference Base Comparison

Date: 2026-07-04  
Scope: docs-only decision memo for choosing game descriptions, fan art/reference images, SVG contracts, and model lanes

## Direct Answer

The current Cantina work is **game/SW_MUSH/project-description based for geometry**.

It is not fan-art based. The kept entrance sequence came from:

```text
SW_MUSH/project room descriptions
  -> our own spatial/SVG contract
  -> Godot terrain-kit proof
  -> finer entrance-detail proof
  -> Blockbench .bbmodel
  -> Blender GLB
  -> Godot camera proof
```

Fan art has not been used as a source image, mesh source, texture source, or geometry trace for the kept Cantina entrance baseline.

The pipeline I recommend now is a **hybrid reference split**:

```text
Game/descriptions drive playable geometry.
Fan art/reference boards drive mood and visual-style lessons.
Blockcraft grammar drives the actual model.
```

That gives us the benefit of references without letting a single pretty picture override the MMO room logic.

## Why Not Fan Art First?

Fan art is good at:

- exterior mood;
- lighting;
- texture density;
- color temperature;
- crowded frontier feeling;
- recognizable silhouette families;
- showing what people expect a place or vehicle to feel like.

Fan art is weak at:

- room adjacency;
- player navigation;
- combat/social affordances;
- what needs collision;
- what a WEG/MMO scene must support;
- avoiding copied protected shapes if used too literally.

For a playable MMO location, the geometry source needs to answer:

```text
Where can the player stand?
What is the social threshold?
What is the safe area?
Where are the NPCs?
Where are the exits?
What is readable from the gameplay camera?
```

SW_MUSH descriptions and project data answer those better than fan art.

## Comparison Matrix

| Reference base | Best use | Weakness | Current verdict |
| --- | --- | --- | --- |
| SW_MUSH/project descriptions | Geometry, room identity, gameplay affordances, social rules | Less precise on exterior art style | Primary source for terrain and buildings |
| SW_MUSH maps/YAML | Room graph, rough adjacency, navigation anchors | Too abstract for final art | Use as layout constraint, not final floorplan |
| Fan art / online images | Mood, lighting, clutter density, silhouette expectations | Risk of copying and poor gameplay layout | Use as visual-style lessons only |
| LEGO/toy/blockcraft refs | Exaggeration strategy, feature hierarchy, small-scale readability | Can make assets too toy-like if copied wholesale | Strong for ships, weapons, droids, helmets |
| Our own SVGs | Visual contracts between text and model generation | Not final art or model geometry | Use before expensive modeling when shape is unclear |
| Our own pixel source cards | True voxel pickups, signs, panels, and tactical tokens | Too flat for full humanoids/buildings unless layered | Use with Godot pixel extrusion when strict cube grid matters |
| Blockbench model source | Editable identity assets | Requires spec discipline and camera validation | Current kept identity-asset lane |
| Godot procedural scenes | Fast blockouts, terrain tests, camera proofs, overlays | Weak source of editable production models | Keep for blockout/review/runtime proof |

## Recommended Hybrid by Asset Family

### Cantina and Buildings

Use:

```text
SW_MUSH/project descriptions for geometry
fan-art/reference lessons for material mood
SVG contracts for floorplan/elevation
Godot for blockout and camera proof
Blockbench for kept identity modules
```

The current Cantina must preserve:

- elevated/no-droids entrance;
- detector post and controlled threshold;
- dim main bar;
- booth ring;
- bandstand/music identity;
- back hallway with restroom/cellar/office affordances;
- outside trouble versus inside social safety.

Fan art can push:

- sun-to-dark contrast;
- rough plaster;
- wall grime;
- crowded approach;
- pipe/sign/awning density;
- dust berms and street clutter.

It should not decide the room graph.

### Characters

Use:

```text
gameplay role / in-game description
  -> optional SVG front/side card
  -> Blockbench
  -> Blender GLB
  -> Godot ground proof
```

Characters have been stronger than ships because the cube grammar naturally matches humanoid readability. The reference emphasis should be **role and feature exaggeration**, not fan-art base images.

Examples:

- clone rifleman: helmet brow, visor band, chest block, shoulder blocks, weapon silhouette;
- commander: stripe, pauldron, backpack/radio, kama/skirt block;
- droid: long neck, small torso, thin limbs, backpack or sensor eye.

### Ships

Use:

```text
gameplay role
  -> reference-board silhouette lessons or SVG top/isometric plan
  -> Blockbench
  -> Blender GLB
  -> Godot isometric tactical proof
```

Ships benefit more from visual references than characters because their readability depends on a few precise silhouette proportions:

- nose language;
- wing count and sweep;
- cockpit placement;
- engine cluster rhythm;
- faction color zones;
- weapon nub placement;
- thumbnail read from the isometric camera.

This does **not** mean "copy a fan-art ship." It means write a grammar card, then rebuild as original cubes.

### Weapons

Use:

```text
gameplay role
  -> SVG silhouette strip
  -> Blockbench
  -> Blender GLB
  -> in-hand and pickup proof
```

Reference images help only after the gameplay role is named. The model needs exaggerated barrel, stock, muzzle, magazine, blade/emitter, and scope features.

### Terrain Chunks

Use:

```text
map topology / room descriptions / traversal needs
  -> SVG floorplan
  -> Godot blockout
  -> Blockbench identity kit pieces
  -> Godot camera proof
```

Godot is still the better first tool for terrain because terrain needs scale, spacing, camera, and pathing checks before it needs polished source models.

## The Current Cantina Reference Basis

Current kept baseline:

```text
generated/cantina_entrance_detail_v1/ITERATION_REVIEW.md
generated/blockbench_cantina_entrance_v1/GLB_REVIEW.md
generated/godot_cantina_entrance_camera_v1/REVIEW.md
```

Source basis:

```text
SW_MUSH/project descriptions -> derived contract -> generated proof
```

What it gets right:

- controlled threshold;
- detector/no-droids beat;
- elevated steps;
- small-block facade detail;
- editable Blockbench source;
- clean GLB validation;
- Godot camera/import proof.

What fan-art mood could still improve:

- lighting and grime;
- stronger dim interior contrast;
- less clean/toy-like material read;
- more crowded exterior approach;
- richer pipe/sign/clutter density;
- better wall age and texture rhythm.

Next best comparison pass:

```text
Keep the entrance model fixed.
Change only material/lighting/clutter mood using reference-board lessons.
Render before/after in Godot.
Keep only if the same geometry reads more like a lived-in spaceport cantina.
```

## How To Compare Game Geometry vs Fan-Art Mood

Use this method when Claude or Codex asks "which reference is driving this?"

1. Name the baseline asset.
2. Declare the geometry source.
3. Declare the mood/style source.
4. Declare the model grammar.
5. Change one variable only.
6. Render a side-by-side capture.
7. Keep, reject, or mark candidate.

Template:

```text
Asset:
Baseline:
Geometry source:
Mood/style source:
Model grammar:
Changed variable:
Expected improvement:
Generated preview:
Verdict:
Next one-variable test:
```

Example:

```text
Asset: Cantina entrance
Baseline: blockbench_cantina_entrance_v1
Geometry source: SW_MUSH/project descriptions
Mood/style source: Cantina fan-art/reference-board lessons, converted to written notes
Model grammar: blockcraft cubes, no copied geometry
Changed variable: lighting/material grime only
Expected improvement: same threshold, stronger desert-to-dim-cantina mood
Verdict: keep only if it improves camera read without hiding the detector/sign
```

## Source Boundary

Allowed:

- use fan art as a mood lesson;
- use multiple references and average the lessons;
- write original grammar cards;
- rebuild from cubes;
- keep links/provenance in docs only;
- make private/friends Star Wars readability strong through role, color, and silhouette.

Not allowed:

- trace fan art;
- sample fan-art textures;
- convert fan art to mesh;
- copy official or fan-made geometry;
- use logos or official markings;
- package reference images into runtime assets.

## Practical Rule

If the asset must be playable, start from the game.

If the asset must be recognizable, study references.

If the asset must be truly voxel and naturally fits a flat source card, use original project pixel/SVG art and Godot pixel extrusion.

If the asset must ship through this cheap pipeline, rebuild it in the blockcraft grammar and prove it in Godot.
