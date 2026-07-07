# Blockcraft Space-Opera Direction

Date: 2026-07-03  
Status: tested in Godot through `specs/blockcraft_space_opera_v0.json` and the private-fan `specs/private_clone_wars_blockcraft_v0.json`

## Why This Direction Exists

The owner described the desired reachable target as "Star Wars Minecraft." My interpretation for production is:

```text
blocky readable MMO world
+ Clone Wars-era gameplay roles
+ desert frontier / military sci-fi color language
+ isometric tactical space
- copied franchise meshes, logos, or exact silhouettes
```

This is the strongest low-cost path I see because it turns model creation into a constrained construction problem. A model can be specified as boxes, colors, pivots, scale, and gameplay role. That is much easier for Codex/Claude to generate, test, and revise than freeform sculpted 3D.

For the "Palworld approach" version of this idea, see `ALMOST_SPACE_OPERA_GUIDE.md`. The design target is close genre recognition, not copied expression.

For the owner's private/friends SW-authenticity priority, see `PRIVATE_SW_AUTHENTICITY_PASS.md`. That lane pushes Clone Wars readability harder while keeping the assets procedural and clearly separated from the public-safe direction.

## Current Tested Artifact

Review board:

`generated/blockcraft_space_opera_v0/REVIEW.md`

Private-fan Clone Wars review board:

`generated/private_clone_wars_blockcraft_v0/REVIEW.md`

Most important capture:

`generated/blockcraft_space_opera_v0/captures/assets/blockcraft_frontier_micro_slice_01.png`

The micro-slice combines a settlement gate, market stall, utility prop, white armored pawn, tan droid pawn, hover cargo sled, and terrain base. It is not final art, but it is the first artifact that shows the intended production lane clearly.

The private-fan pack adds clone rifleman/commander, Jedi support, B1/B2 droids, a gunship token, a desert outpost slice, and an isometric space skirmish. It is currently the better "does this feel like Clone Wars at blockcraft scale?" test.

## What Worked

- The visual language is more coherent than the first chunky low-poly pass.
- Cuboids make asset specs easy to author and review.
- The ground pack starts to feel like a modular toy-box MMO set.
- The isometric space pack remains compatible with flat x/y tactical play while looking 3D.
- Godot can produce real `.tscn` model-prefabs and rendered review captures without Blender.

## What Did Not Work Yet

- Characters are the hardest part. The white armored pawn reads as a pawn, but it needs stronger helmet/shoulder/leg grammar.
- The tan droid pawn is readable but too thin at contact-sheet distance.
- Buildings need a larger modular kit: wall, arch, roof, door, terminal, pipe, vent, antenna, stairs.
- The review camera is useful for approval, but not yet a runtime camera test.
- There is no animation grammar yet.

## Recommended Style Rules

Use:

- Mostly cuboids.
- A 0.25 or 0.5 meter grid.
- Very small palette per biome/faction.
- Emissive cyan/orange only for tech affordances.
- Oversized readable heads, helmets, shoulders, weapons, and backpacks.
- Large silhouettes that survive a zoomed-out MMO camera.
- Isometric space as 3D block ships over a flat plane.

Avoid:

- Smooth hero proportions.
- Tiny greebles that disappear in camera.
- Too many cylinders and spheres.
- Realistic textures.
- Raw mixing of Kenney, Quaternius, AI meshes, and procedural assets without material normalization.

## Suggested Next Iterations

1. Character grammar pass
   - Build 3 friendly pawn variants.
   - Build 3 droid/hostile pawn variants.
   - Compare at contact-sheet and runtime camera distances.

2. Modular settlement kit
   - 4 wall chunks.
   - 3 doors.
   - 3 roof/canopy pieces.
   - 4 terminals.
   - 4 props: crate, barrel, generator, vaporator.

3. Terrain kit
   - 6 desert tiles.
   - 3 elevation/step tiles.
   - 3 road/worn-path tiles.
   - 3 cover tiles.

4. Space kit
   - 3 fighter silhouettes.
   - 3 freighter silhouettes.
   - 3 hazards.
   - 2 sensor/targeting markers.

5. Runtime visual test
   - Put accepted generated scenes into a temporary docs-only Godot review scene.
   - Capture from the actual intended gameplay camera.
   - Compare with current game visuals before promoting anything.

## Pipeline Recommendation

Default lane:

```text
spec -> Godot procedural block scene -> review capture -> owner picks -> promote only winners
```

Secondary lane:

```text
spec -> Blockbench/Blender cleanup -> GLB -> Godot import -> same review capture
```

Paid/API lane:

Use Meshy/Tripo only for hero silhouettes or inspiration. Do not use them as the default production pipeline unless a test proves the outputs can be made coherent and license-clean.

## My Current Read

If the owner would be ecstatic with a good "space-opera blockcraft MMO" look, this is the direction I would press on. It is not as visually rich as AI bitmap concepts, but it is much more likely to become an actual game art pipeline.
