# Meshy Salvage Lanes

Date: 2026-07-04  
Scope: what Meshy is still useful for after foreground voxel tests failed the cohesion check

## Current Verdict

Meshy should not be a default source for foreground voxel assets.

The owner called the core issue correctly: if the game commits to a discrete voxel/blockcraft look, analog generated meshes are visually jarring beside hand-rolled cube geometry. The Meshy droid image-to-3D test is the cleanest evidence so far:

```text
project-generated voxel droid source image
  -> Meshy image-to-3D, meshy-5, no texture
  -> 5 credits
  -> clean GLB
  -> recognizable silhouette
  -> softened analog mesh
  -> source floor fused into generated geometry
```

Result:

```text
generated/meshy_image_droid_v0/godot_proof/REVIEW.md
```

This is a useful lesson, not a useful runtime character.

## Rejected Foreground Uses

Do not spend Meshy credits on direct runtime candidates for:

- player characters;
- clone/trooper NPCs;
- droids intended to stand near voxel actors;
- weapons and equipment;
- handheld props;
- voxel vehicles and ships;
- modular buildings;
- Cantina furniture and terrain modules.

These assets need discrete cube grammar, editable source, and consistent silhouette language. Use Blockbench, Godot pixel extrusion, body-part pixel hulls, or Godot terrain blockouts instead.

## Possible Salvage Uses

Meshy may still be useful where analog geometry does not sit directly beside the voxel identity layer.

### 1. Background Plates

Use Meshy or AI-generated 3D renders as source material for distant, non-interactive backgrounds:

- horizon silhouettes;
- far city/settlement massing;
- canyon skyline plates;
- starport backdrop shapes;
- derelict wrecks seen only as distant silhouettes.

Rule:

```text
Meshy render -> 2D plate/sprite/background card -> Godot camera proof
```

Do not import the Meshy mesh as a walkable or nearby object.

### 2. Space Backdrops

The best salvage lane may be isometric/2.5D space ambience:

- planets;
- moons;
- asteroids far below/behind the tactical plane;
- nebula plates;
- station silhouettes in the far background;
- debris fields rendered as distant parallax layers.

Concern:

Rounded planets or debris can still feel jarring if they are too realistic. Keep them painterly, posterized, or pixel-dithered before placing near voxel ships.

Recommended process:

```text
Meshy/AI source
  -> render from fixed isometric/background camera
  -> posterize/dither/color-limit
  -> place as parallax/background plate
  -> compare against voxel tactical ships
```

### 3. VFX and Atmosphere Reference

Meshy can provide shape or lighting ideas for:

- smoke plumes;
- shield shimmer reference;
- engine-glow volumes;
- hologram stand-ins;
- distant explosion silhouettes;
- atmospheric dust shapes.

The runtime result should still be Godot-native particles, sprites, shaders, or voxel-friendly billboards.

### 4. Reference Only

Meshy can remain a reference generator for high-entropy shape language:

- weird machinery silhouettes;
- greeble rhythm;
- junk-pile composition;
- alien statue composition.

The final asset should be rebuilt in Blockbench/Godot, not promoted directly.

## Spend Policy

Treat Meshy credits as research budget, not production budget.

Use credits only when the result answers one of these:

- Can Meshy make a useful background plate?
- Can Meshy create a space backdrop element that survives posterization?
- Can Meshy provide reference for a hard-to-imagine object that we then rebuild?
- Can Meshy generate a texture/atmosphere source for a non-foreground layer?

Avoid:

- repeating foreground character/prop/ship tests;
- refining a mesh whose geometry already fails;
- trying to prompt away the continuous-mesh problem.

## Next Best Test

If using Meshy again, run one cheap salvage test:

```text
space backdrop asteroid/planet/debris plate
  -> Meshy or image source
  -> render/posterize
  -> Godot isometric space proof beside kept voxel ship
  -> keep only if it feels like background atmosphere, not a mismatched asset
```

This tests the only lane that still has a plausible payoff without fighting the voxel premise.
