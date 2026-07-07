# Cantina Terrain Reference Pass

Date: 2026-07-04  
Scope: docs-only terrain/worldbuilding workflow for Chalmun's Cantina and cantina-district assets

## Short Answer

Fan art of the Cantina can help, but only if it is used as a visual study layer, not as a model source.

The better pipeline is a three-way comparison:

```text
fan art / mood reference
  -> shape mood, lighting, silhouette, terrain dressing

SW_MUSH multi-room descriptions + area geometry
  -> playable requirements, room graph, NPC/social affordances

our derived SVGs / blockcraft grammar
  -> neutral visual contracts for Blockbench/Godot generation
```

For terrain, this comparison is more valuable than fan art alone. A pretty Cantina exterior is not enough; it has to become a playable MMO social landmark with recognizable approach, doorway, bar, booths, back hallway, bouncer/no-droids threshold, and surrounding plaza terrain.

There are no SW_MUSH SVGs in the sources I found. The SVG lane here means **Codex/Claude-created SVGs based on SW_MUSH game descriptions and room data**, used as internal visual contracts.

## What We Found

Read-only SW_MUSH sources:

- `C:\SW_MUSH\data\worlds\clone_wars\planets\tatooine.yaml`
  - Multiple rooms define the Cantina play space:
    - `Chalmun's Cantina - Entrance`
    - `Chalmun's Cantina - Main Bar`
    - `Chalmun's Cantina - Back Hallway`
  - The room descriptions specify the elevated entrance, dim/cool transition, droid detector, no-droids sign, main bar, curved booths, bandstand, back hallway, restroom doors, cellar trapdoor, and curtained office.

- `C:\SW_MUSH\data\worlds\clone_wars\maps\chalmuns_cantina.yaml`
  - AreaGeometry for the interior:
    - 6x6 bounds;
    - entrance at roughly `[4,2]`;
    - main bar at `[4,4]`;
    - back hallway at `[2,4]`;
    - corridor path entrance -> main bar -> back hallway;
    - landmarks for main bar and back hallway.
  - This is marked as a test zone-map / draft, not a live runtime source.

- `C:\SW_MUSH\data\worlds\clone_wars\npcs_mos_eisley_population_p1.yaml`
  - Cantina social identity:
    - Wuher, Chalmun, cantina patrons, band/back hallway, bouncer/entrance.

Project-owned sources:

- `scripts/world/landmark_builder.gd`
  - Current live procedural cantina plaza:
    - domed adobe main hall;
    - archway;
    - simple bar + booths visible through the opening;
    - flanking huts;
    - perimeter walls;
    - market stalls;
    - moisture vaporators.
  - It is good as a procedural landmark, but it is still generic and not yet a high-quality blockcraft terrain kit.

- `data/npcs_clone_wars.json`
  - Carries Wuher, Chalmun, Djas Puhr, and other cantina-linked NPC identity into the Godot project.

- `data/quests_clone_wars.json`
  - Contains cantina doorstep trouble and Chalmun debt-collector hooks.

## What Fan Art Can Add

Fan art can be useful for:

- exterior massing;
- color mood;
- sense of crowded approach;
- sun-blasted street-to-dark-interior contrast;
- signs, pipes, door framing, awnings, and crowd density;
- how much of the building should feel half-buried, rough, and old;
- terrain dressing: dust berms, steps, low walls, vendor clutter, power boxes, antennas.

Fan art should not be used for:

- copying exact facade shape;
- copying textures;
- tracing silhouettes;
- copying signs/marks/logos;
- directly generating a mesh from one reference image;
- importing fan art into runtime.

The safest method is to use multiple references and convert them into a written grammar card before modeling.

## What SW_MUSH Adds That Fan Art Cannot

SW_MUSH gives the gameplay truth:

- There is an elevated entrance where arrivals are observed.
- The entrance has a no-droids/droid-detector threshold.
- Main bar is the social hub.
- Booths line curved walls.
- There is a bandstand/music identity.
- Back hallway is functionally important: restrooms, cellar/trapdoor, office/curtain, escape route.
- The cantina is a secured social/economic hub with house rules.
- The surrounding doorstep supports conflict hooks without making the inside a murder zone.

That means a terrain model should not be just a dome. It needs:

- a readable exterior entrance threshold;
- an interior/visible bar anchor;
- curved booth ring or booth clusters;
- a back-hallway silhouette or second exit;
- an exterior plaza/approach with enough space for NPCs and players;
- terrain/cover around the doorstep for cantina-adjacent trouble;
- a "safe inside / trouble outside" visual split.

## Derived SVG Contract

Generated artifact:

```text
docs/gpt/asset_factory/generated/cantina_terrain_reference_v0/cantina_source_comparison.svg
```

Review doc:

```text
docs/gpt/asset_factory/generated/cantina_terrain_reference_v0/REVIEW.md
```

The SVG is not copied from fan art and is not from SW_MUSH. It is a neutral visual contract we create from SW_MUSH room geometry/descriptions and project terrain needs.

## Recommended Terrain Pipeline

### Step 1: Source Extraction

Create a card with three columns:

| Input | Extract | Do not extract |
| --- | --- | --- |
| Fan art | mood, lighting, exterior density, terrain dressing | exact geometry, texture, signage |
| SW_MUSH room desc | affordances, room identity, gameplay thresholds | literal text wall as scene layout |
| SW_MUSH map YAML | adjacency, rough room relation, interior anchors | exact 1:1 floorplan as final building |

### Step 2: Description-Derived SVG Contract

Create one or more simple SVGs from the MUSH descriptions and room graph:

- exterior massing;
- approach direction;
- no-droids threshold;
- entrance -> bar -> back hallway path;
- booth ring;
- bandstand;
- exterior plaza and doorstep danger area.

This is for internal use. It should be a readable diagram, not a final art asset.

Recommended SVG set:

- `cantina_source_comparison.svg` â€” compares fan-art lessons vs MUSH room data vs blockcraft output.
- `cantina_room_graph.svg` â€” pure room graph: entrance -> main bar -> back hallway, plus implied cellar/restroom/office affordances.
- `cantina_exterior_contract.svg` â€” exterior facade/plaza/approach derived from descriptions, not fan art.

### Step 3: Blockbench Terrain Kit

Make a small kit, not one giant model:

- `cantina_entrance_threshold.bbmodel`
- `cantina_domed_wall_section.bbmodel`
- `cantina_bar_counter.bbmodel`
- `cantina_booth_cluster.bbmodel`
- `cantina_bandstand.bbmodel`
- `cantina_back_hallway_door.bbmodel`
- `cantina_plaza_low_wall.bbmodel`
- `cantina_dust_steps.bbmodel`
- `cantina_no_droids_sign.bbmodel`
- `cantina_power_box_or_detector.bbmodel`

### Step 4: Godot Review Scene

Build a docs-only terrain scene that uses the kit pieces:

- outside approach camera;
- overhead interior camera;
- ground MMO camera;
- NPC scale figures;
- ship/character baseline models for style comparison.

### Step 5: Keep/Reject

Accept only if:

- the entrance reads instantly;
- the interior route is understandable;
- the exterior feels like a social hub, not an isolated prop;
- the blockcraft style matches the kept clone/ship examples;
- Kenney filler, if used, disappears into background and does not become the identity layer.

## Fan-Art Comparison Method

When a Cantina fan-art reference is available, use this checklist:

```text
Reference:
Observed exterior lessons:
Observed terrain lessons:
Observed lighting/color lessons:
SW_MUSH requirements it supports:
SW_MUSH requirements it ignores:
What we deliberately change:
Risk of copying:
Verdict:
```

Example without using a specific image:

```text
Observed exterior lesson: the doorway needs a strong recessed threshold and surrounding wall mass.
SW_MUSH support: entrance room is elevated and socially important.
SW_MUSH gap: fan art may not show back hallway/cellar/office path.
Transform: make an original blockcraft doorway kit with a droid detector post and no-droids sign as readable gameplay threshold.
```

## Comparison: Fan Art vs SW_MUSH Descriptions vs Our SVGs

Fan art:

- best for mood;
- worst for gameplay layout;
- dangerous if copied too literally.

SW_MUSH descriptions:

- best for social/playable affordances;
- weak on exact exterior shape;
- should drive what must exist.

SW_MUSH map/YAML:

- best for room adjacency;
- too abstract for final 3D terrain;
- should drive navigation clarity.

Our derived SVGs:

- best bridge between text/data and model generation;
- not final art;
- should be revised after each Godot camera proof.

## One-Variable Iterations

1. Terrain shape only.
   - Build the exterior entrance/plaza blockout from the SVG.
   - No detailed interior yet.

2. Interior affordance only.
   - Add bar, booths, bandstand, back hallway markers.
   - Keep exterior shape fixed.

3. Fan-art mood only.
   - Change color/lighting/clutter density based on reference lessons.
   - Keep geometry fixed.

4. Kenney filler only.
   - Test normalized crates/pipes/stalls around the exterior.
   - Keep custom doorway/dome/identity pieces fixed.

5. Gameplay scale only.
   - Add NPC/player stand-ins and test camera readability.
   - Keep art fixed.

## My Recommendation

Use fan art for the Cantina, but make it subordinate to the SW_MUSH-derived play contract.

The correct goal is not "make a fan-art Cantina model." The goal is:

```text
Make a blockcraft social landmark where the player can read:
outside trouble -> elevated no-droids entrance -> dim main bar -> booth ring -> bandstand -> back hallway/cellar.
```

That is where terrain starts becoming gameplay instead of scenery.
