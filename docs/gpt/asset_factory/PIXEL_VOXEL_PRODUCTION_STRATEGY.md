# Deterministic Pixel Voxel Production Strategy

Date: 2026-07-04  
Scope: docs-only default strategy for the voxel/blockcraft asset factory

## Current Read

The owner is probably right to make the deterministic pixel/GDScript lane the center of gravity.

The Meshy tests exposed the core mismatch: Meshy can make appealing continuous meshes, but continuous analog geometry fights a strict voxel game. The best recent proofs came from project-generated pixel source cards because they preserve the thing the art direction actually needs:

```text
discrete source card -> deterministic cube grammar -> Godot proof -> runtime-adjacent data
```

This is now the default question for most model families:

```text
Can this be expressed first as one or more original pixel/semantic cards?
```

If yes, start there before spending Meshy credits or hand-authoring full models.

## Honest Pushback

Do not interpret this as "never use Blockbench" or "pixel cards solve final art."

The better tactical position is:

```text
Pixel/GDScript first for deterministic voxel grammar.
Blockbench/manual cleanup for hero editability and final foreground polish.
Meshy only in reserve for background/space/reference experiments.
```

The tactical error would be trying to force Meshy to become a foreground voxel generator after repeated evidence says it softens the cube grammar. The opposite tactical error would be refusing Blockbench when an asset needs human-editable joints, clean hero proportions, or final authored detail.

## Default Asset Routes

### Characters And NPCs

Default:

```text
role/description
  -> front/side pixel cards
  -> body-part voxel hulls
  -> pose/rotation contact sheet
  -> Blockbench rebuild or cleanup if foreground
```

Use for:

- background patrons;
- guards;
- simple droids;
- pose contracts;
- animation-planning proxies;
- quick "does this silhouette read?" tests.

Do not assume this solves hero clone-trooper combat rigs yet. The body-part lane is a strong proof for rigid-pose/background actors, but foreground combat still needs a rig contract, animation clips, and Godot import validation.

### Equipment, Weapons, Signs, And Props

Default:

```text
16x/32x/48x original pixel card
  -> Godot pixel extrusion
  -> same-color run merge
  -> item/wall/in-hand camera proof
```

Use this before Blockbench for flat-ish, readable objects:

- blasters and pickup weapons;
- datapads;
- wall terminals;
- badges;
- signs;
- inventory props;
- warning plates;
- small crates and panels.

If the result is too flat, keep the pixel card as the contract and rebuild the object in Blockbench.

### Ships And Vehicles

Default first pass:

```text
top/side/isometric pixel cards
  -> run-merged voxel token or multi-card hull
  -> Godot isometric tactical proof
```

Use for tactical readability, token-scale ships, speeders, and silhouettes.

Escalate to Blockbench when the asset needs:

- cockpit depth;
- readable engines from multiple angles;
- rotation;
- close-up hangar/cockpit shots;
- a hero vehicle identity layer.

Meshy remains a poor direct fit for ships if the result will sit beside voxel ships. It may still help as a reference generator or distant background source.

### Buildings, Rooms, And Terrain

Default:

```text
room graph / gameplay description
  -> semantic floorplan pixel card
  -> detail/elevation pixel card
  -> greedy rectangle merge
  -> material-batched Godot geometry
  -> collision mask / walk mask / sockets
  -> Blockbench identity modules layered in
```

Use for:

- Cantina rooms;
- frontier interiors;
- settlement chunks;
- corridors;
- cover layouts;
- building LOD;
- procedural filler beneath authored landmark pieces.

The pixel lane should own structure and runtime affordances. Blockbench should own recognizably authored hero modules: entrance facades, bar fronts, booth bays, special signs, unique machines, and story props.

### Space Backgrounds, VFX, And Atmosphere

Meshy is still worth holding in reserve here.

Valid Meshy salvage tests:

```text
Meshy/AI source
  -> fixed camera render
  -> posterize / dither / color-limit
  -> 2D background plate
  -> Godot proof behind voxel ships
```

Possible uses:

- distant planets;
- asteroid field plates;
- nebula ambience;
- wreck silhouettes;
- far station forms;
- VFX reference for smoke, shields, engine glow, holograms.

Do not import Meshy meshes as nearby ships, props, characters, or buildings unless a focused A/B beats the current voxel lane.

## Current Proof Stack

Strongest current evidence:

```text
PIXEL_EXTRUDE_GODOT_PASS.md
generated/godot_pixel_extrude_v0/REVIEW.md

PIXEL_HULL_BODY_PARTS_PASS.md
generated/godot_pixel_hull_body_parts_v0/REVIEW.md

PIXEL_CANTINA_LAYERED_KIT_PASS.md
generated/godot_pixel_cantina_layered_kit_v1/REVIEW.md

PIXEL_CANTINA_RUNTIME_PASS.md
generated/godot_pixel_cantina_runtime_v1/REVIEW.md

PIXEL_ROOM_RUNTIME_ADAPTER_PASS.md
generated/godot_pixel_room_runtime_adapter_v0/REVIEW.md
```

Together, these prove:

- pixel cards can become strict voxel props;
- front/side cards can become more-than-flat actor hulls;
- body-part cards can become poseable deterministic actors;
- room cards can become efficient batched geometry;
- the same room cards can emit collision, walk masks, sockets, and path probes.
- external JSON room specs can now carry explicit runtime socket roles: seat, stand, spawn, use, inspect, cover, transition, prop, and light.

That combination is stronger than "nice art." It is an asset production grammar.

## Request Rule For Claude

For a new asset request, Claude should now answer these first:

```text
1. What source card(s) should define the asset?
2. Is this a prop extrusion, body-part hull, ship/vehicle token, or room semantic kit?
3. What camera must prove it?
4. What baseline should it beat?
5. What runtime affordances should come out with it, including any seat/stand/use/cover/transition sockets?
```

Only after those answers should the request escalate to Blockbench, Meshy, Blender, or manual polish.

## Next One-Variable Tests

Highest-value next tests:

1. Convert one non-Cantina asset family with this lane: a blaster pickup, ship token, or simple droid.
2. Run the same room-card runtime pipeline on a second SW_MUSH Cantina room.
3. Convert one room spec into a gameplay-clean preview that hides debug overlays but preserves sockets/collision metadata.
4. Add validation errors for duplicate socket ids, row length mismatches, unknown symbols, and unreachable path probes.
5. Test a Meshy space-background plate behind voxel ships, with posterization, only if credits are being used.
