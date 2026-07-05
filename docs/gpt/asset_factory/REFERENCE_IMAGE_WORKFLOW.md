# Reference Image Workflow

Date: 2026-07-04  
Scope: docs-only workflow for using online, LEGO-like, fan-art, and concept references without copying assets

## Short Answer

Yes, reference images can improve results. They are especially useful for ships, weapons, buildings, and droids because those assets depend on silhouette and proportion more than surface realism.

But reference images should be used as a design study, not as source art.

The correct workflow is:

```text
reference set -> written silhouette grammar -> original blockcraft spec -> generated model -> rendered preview -> keep/reject
```

The wrong workflow is:

```text
reference image -> trace/copy geometry -> call it transformed
```

Fan art is not automatically safe to copy. It can still be copyrighted by the fan artist, and it can still depict protected franchise designs. For this private/friends project the authenticity target can be higher, but the pipeline should still avoid ripped official meshes, official textures, logos, audio, exact vehicle geometry, and one-to-one copied fan art.

## Why LEGO-Like Reference Helped

The LEGO / Microfighter lesson is that recognizable shapes survive simplification when the right features are exaggerated.

For small blockcraft assets, realism often makes the asset worse. The more useful question is:

```text
What are the 3 to 5 features that make this recognizable from a game camera?
```

Examples:

- A fighter may need an oversized cockpit, short wedge body, bright faction panels, twin engines, and chunky cannons.
- A droid may need a long neck, tiny torso, thin limbs, and a backpack.
- A clone may need a strong helmet brow, chest block, shoulder blocks, and a bold color stripe.
- A frontier building may need a rounded door, dome cap, pipe cluster, awning, and antenna.

That is the real "Cubecraft weekend" trick. The style reduces modeling into a repeatable grammar.

## The Palmon Treatment

Use this term as a practical rule:

```text
Study the familiar thing.
Extract the role and silhouette family.
Exaggerate different features.
Recompose it from original cube parts.
Rename it as an in-world archetype.
Review against the source only for vibe, not for geometry match.
```

For example:

- Do not copy a specific official starfighter.
- Do make an "agile Republic wedge interceptor" with a large cockpit block, two red-white wing panels, twin blue engines, and a toy-like cannon silhouette.

This can feel authentic in play because role, color, and silhouette language are doing the work, not exact copied geometry.

## Reference Board Rules

For each asset family, collect a small reference set:

- 2 to 4 broad franchise-adjacent references for role language;
- 2 to 4 LEGO/toy/blockcraft references for abstraction strategy;
- 1 to 3 public-domain or CC0 real-world references where useful;
- optional fan art only as broad mood input, not geometry source.

Then write a short grammar card before making any model.

Template:

```text
Asset family:
Gameplay role:
Camera:
Must-read features:
Avoid:
Palette:
Scale target:
Cube budget:
Reference lessons:
Original blockcraft recipe:
Acceptance test:
```

Do not place exact source measurements, traced outlines, copied decals, or exact named protected part lists in the grammar card.

## Example Grammar Cards

### Friendly Microfighter

Asset family: friendly space fighter  
Gameplay role: fast Republic-aligned player/allied tactical contact  
Camera: isometric 2.5D tactical space  
Must-read features: wedge nose, single cockpit, broad wing panels, twin blue engines, small cannons  
Avoid: exact official wing outline, official markings, exact cockpit shape  
Palette: off-white, dark gray, red accent, cyan/blue engine glow  
Scale target: 2.5 to 3.5 Godot units wide  
Cube budget: 25 to 45 cubes  
Reference lessons: toy-scale ships need oversized cockpit and panel color; engines must be visible from above  
Original blockcraft recipe: stubby wedge body, raised cockpit block, separate left/right panel wings, rear engine cubes, front cannon nubs  
Acceptance test: readable as a friendly fighter in a contact sheet next to hostile droid craft

### Hostile Droid Craft

Asset family: hostile droid ship  
Gameplay role: Separatist-aligned AI threat  
Camera: isometric tactical space  
Must-read features: central eye, forward prongs, tri-wing/forked silhouette, orange glow  
Avoid: exact tri-fighter profile, copied cockpit/eye design  
Palette: blue-gray metal, dark core, orange glow, small tan panels  
Scale target: slightly smaller than friendly fighter, wider threat profile  
Cube budget: 25 to 45 cubes  
Reference lessons: the hostile read improves when the eye is oversized and the wings point forward  
Original blockcraft recipe: flat central slab, raised eye cube, three angular prong clusters, small engine block  
Acceptance test: owner can identify "hostile droid ship" without a label

### Clone Rifleman

Asset family: soldier character  
Gameplay role: starter combatant / player visual language prototype  
Camera: ground MMO camera plus owner closeup  
Must-read features: helmet brow, chest plate, shoulder pads, black visor, blaster held forward  
Avoid: exact official helmet mesh, logos, perfect armor copy  
Palette: white/off-white, dark undersuit, blue or red role accent, black visor  
Scale target: consistent humanoid blockcraft grid  
Cube budget: 35 to 70 cubes  
Reference lessons: helmet/visor silhouette matters more than torso detail  
Original blockcraft recipe: large helmet block with visor strip, compact torso, block arms/legs, oversized carbine  
Acceptance test: silhouette distinguishes clone from civilian and droid at gameplay distance

### Desert Frontier Doorway

Asset family: building kit piece  
Gameplay role: interactable settlement entrance  
Camera: ground MMO camera  
Must-read features: rounded doorway, thick wall, pipe cluster, awning/antenna, sand palette  
Avoid: exact Mos Eisley copied building shape  
Palette: sand plaster, sun-bleached tan, shadow brown, teal/red accents  
Scale target: player-height door with readable interaction frame  
Cube budget: 20 to 60 cubes plus optional cylinders  
Reference lessons: desert sci-fi reads through domes, pipes, sun-faded massing, and chunky thresholds  
Original blockcraft recipe: rectangular wall mass, arched/stepped doorway illusion, side pipe stack, small light panel  
Acceptance test: player sees "door/interior/shop" immediately from street distance

## How To Use Online References Safely

1. Use multiple references per asset.
   - This avoids copying one image too closely.

2. Convert images into words.
   - The generator/spec should consume words and proportions, not image pixels.

3. Close or ignore the exact image before writing the cube recipe.
   - This prevents accidental tracing.

4. Change at least two major axes.
   - Proportions, silhouette, panel layout, cockpit placement, color blocking, or role emphasis.

5. Use original names.
   - Prefer internal names like `friendly_wedge_interceptor`, `hostile_droid_stalker`, `desert_gate_shop`.

6. Keep a private reference ledger when links matter.
   - A ledger is for provenance and review, not for runtime packaging.

7. Review for silhouette distance.
   - If the model still looks like one exact protected asset in thumbnail form, it is too close.

## Reference Ledger Template

Use this only in docs, not runtime:

```text
Asset candidate:
Reference links:
Observed lessons:
What we deliberately changed:
Potential risk:
Reviewer verdict:
```

Example:

```text
Asset candidate: friendly_wedge_interceptor
Reference links: LEGO/toy microfighter pages, broad space-opera fighter mood board
Observed lessons: oversized cockpit, short body, visible engines, bold color panels
What we deliberately changed: wing layout, nose profile, panel placement, cockpit shape, no logos
Potential risk: may still read too close to a specific faction ship if wing shape tightens
Reviewer verdict: keep only if isometric thumbnail reads as archetype, not exact ship
```

## Where References Help Most

High value:

- ships;
- weapons;
- droids;
- helmets;
- building doorways;
- landmark props;
- creature body plans.

Medium value:

- crates;
- barrels;
- terminals;
- generic stalls;
- pipes;
- rocks.

Low value:

- tactical rings;
- movement ghosts;
- sensor cones;
- UI indicators.

For low-value overlay assets, Godot procedural shapes are faster and cleaner.

## Fan Art Policy For This Project

The owner has clarified that the target is a private/friends project and that Star Wars authenticity is a priority. That makes the private review lane useful, but it does not make fan art safe to copy.

Recommended rule:

```text
Fan art may influence mood and silhouette families.
Fan art may not be traced, copied, texture-sampled, or converted into a model.
```

If an image is especially strong, use it to write a grammar card, then generate an original model from that grammar. The model should survive review without needing to display or package the reference image.

## Suggested Next Reference Excursions

Run only one excursion at a time.

1. Friendly fighter reference board.
   - Goal: improve cockpit/wing/engine proportions.
   - Keep current `micro_arc_interceptor_panel_v2` as baseline.
   - Change only proportions in the next spec.

2. Droid infantry reference board.
   - Goal: make a thin hostile infantry body distinct from clone block bodies.
   - Change only body proportions, not palette.

3. Desert doorway reference board.
   - Goal: make buildings feel like frontier space opera without copying a known set.
   - Change only doorway/window/piping grammar.

4. Weapon exaggeration reference board.
   - Goal: make small weapons readable from gameplay camera.
   - Change only muzzle/scope/stock scale.

## Review Checklist

A reference-driven model passes only if:

- it has an original editable source file;
- it has a validated GLB or Godot review artifact;
- it has a rendered preview from the target camera;
- its silhouette is readable at thumbnail size;
- it does not include copied logos, markings, textures, or exact geometry;
- the review doc states what changed from the reference lesson;
- the owner can judge it from images without opening a modeling tool.

## Bottom Line

Using references is not naive. It is probably necessary for ships, weapons, and droids. The mistake would be feeding references directly into final assets or trusting an AI/API mesh as production output.

The best pipeline is still constrained and modular:

```text
reference lesson -> cube grammar -> Blockbench source -> Blender/Godot validation -> owner screenshot review
```

That is the path most likely to get close to "Star Wars Minecraft" without requiring the owner to become a modeler.
