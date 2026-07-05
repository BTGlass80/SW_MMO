# Cantina Bar Booth Bay Pass

Date: 2026-07-04  
Scope: docs-only Blockbench/GLB/Godot iteration for Chalmun's Cantina main bar and booth bay

## Goal

Move the `cantina_bar_booth_bay_01` Godot-procedural proof into the locked editable Blockbench lane while improving the main-bar social read.

The source constraints come from read-only SW_MUSH/project descriptions:

```text
dim main bar
high-tech bar along one wall
booths lining curved walls
bandstand/music identity nearby
dense patrons: smugglers, bounty hunters, clones, and varied beings
main bar connects entrance to back hallway
```

## One Variable Changed

Previous baseline:

```text
generated/cantina_terrain_kit_v0/REVIEW.md
```

Changed variable:

```text
Godot proof module -> editable Blockbench .bbmodel -> Blender GLB -> Godot import/camera proof.
```

Kept fixed:

- SW_MUSH/project descriptions drive geometry and affordances;
- fan art/reference mood does not define source geometry;
- blockcraft cube grammar;
- no copied official meshes, textures, logos, or fan-art geometry;
- main-bar role as a social hub between entrance and back hallway.

## Generated Sources

Spec:

```text
docs/gpt/asset_factory/specs/blockbench_cantina_bar_booth_bay_v1.json
```

Blockbench/GLB outputs:

```text
docs/gpt/asset_factory/generated/blockbench_cantina_bar_booth_bay_v1/
```

Godot proof:

```text
docs/gpt/asset_factory/generated/godot_cantina_bar_booth_bay_v1/REVIEW.md
```

## What Improved

Compared with the old Godot proof, the Blockbench candidate adds:

- segmented booth backs that imply a curved perimeter without relying on rotations;
- bar-front panel rhythm;
- service taps and colored bottle/service lights;
- a bartender proxy behind the counter;
- an owner-corner booth/Wookiee-scale proxy to reinforce the room's social power center;
- route markers for entrance/back-hallway composition tests.

## Validation

The GLB validates cleanly:

```text
blockbench_cantina_bar_booth_bay_v1.glb: no errors, warnings, infos, or hints.
```

## Godot Import Note

The Godot proof rotates the imported holder 180 degrees so the review camera sees the playable bar side. The GLB source is unchanged. This mirrors the earlier entrance camera correction and should be treated as a review-scene orientation concern, not a model edit.

## Verdict

Candidate keep.

The candidate is meaningfully stronger than the procedural baseline and should become the current editable main-bar/booth-bay module.

This does not make Cantina interiors "done." The next missing building pieces are the back hallway/service module, bandstand module, and a connected multi-room composition proof using entrance + bar/booth + hallway.

## Next One-Variable Recommendation

Convert the back hallway service module into Blockbench/GLB, then run a multi-room interior composition proof.
