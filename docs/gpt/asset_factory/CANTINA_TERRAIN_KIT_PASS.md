# Cantina Terrain Kit Pass

Date: 2026-07-04  
Scope: docs-only Cantina terrain-kit iteration

## Goal

Move the Cantina work from diagram-only reference into a first generated blockcraft terrain kit that can be judged in Godot captures.

This pass keeps the source lane fixed:

```text
SW_MUSH/project descriptions -> our own spatial contract -> Godot terrain-kit proof
```

No fan-art geometry, copied facade, copied textures, or imported reference art is used.

## One Variable Changed

Previous baseline:

```text
generated/cantina_terrain_reference_v0/
```

That baseline was SVG/description planning only.

Changed variable:

```text
Add a Godot-generated terrain-kit/model proof while keeping the source material and style target fixed.
```

## Generated Spec

```text
docs/gpt/asset_factory/specs/cantina_terrain_kit_v0.json
```

The spec creates six docs-only assets:

- `cantina_entrance_threshold_01`
- `cantina_bar_booth_bay_01`
- `cantina_bandstand_corner_01`
- `cantina_back_hallway_service_01`
- `cantina_multiroom_slice_01`
- `cantina_exterior_plaza_slice_01`

## Evaluation Target

The captures should answer:

- Does the entrance read as elevated and socially controlled?
- Are the no-droids sign and detector visible as gameplay threshold elements?
- Does the main bar read as the social hub?
- Do the booths and bandstand make the interior feel like a Cantina, not a generic room?
- Does the back hallway imply restrooms/cellar/curtained office?
- Does the exterior plaza leave room for trouble outside while keeping the inside socially safe?

## Next Likely Pass

If V0 reads well in camera, the next pass should convert kept modules into editable Blockbench kit pieces:

- entrance threshold;
- bar counter;
- booth cluster;
- bandstand;
- back hallway/cellar kit;
- exterior plaza low wall/clutter kit.

If V0 does not read, fix only one variable:

- entrance silhouette;
- lighting/palette contrast;
- room layout spacing;
- booth curvature;
- exterior dome/facade massing.

## V1 Entrance Detail Excursion

Generated spec:

```text
docs/gpt/asset_factory/specs/cantina_entrance_detail_v1.json
```

Changed variable:

```text
Increase Minecraft-like cube granularity on the entrance threshold only.
```

Everything else stays fixed: source material, layout, gameplay role, color family, and Godot procedural lane.

The V1 entrance adds:

- segmented floor tiles and steps;
- smaller wall chips;
- split lintel/top blocks;
- side rails;
- richer scanner frame;
- clearer no-droids sign grammar;
- small utility/power detail.

Review:

```text
docs/gpt/asset_factory/generated/cantina_entrance_detail_v1/REVIEW.md
```

Iteration verdict:

```text
docs/gpt/asset_factory/generated/cantina_entrance_detail_v1/ITERATION_REVIEW.md
```

Keep V1 as the new entrance-detail baseline. The added block granularity improves the "Star Wars Minecraft" read without losing the no-droids threshold, detector, or elevated-entry gameplay role.
