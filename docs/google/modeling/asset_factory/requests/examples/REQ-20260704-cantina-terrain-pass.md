# Asset Request: Cantina Terrain Pass

## Request

Request id: `REQ-20260704-cantina-terrain-pass`

Owner priority: high

Requested by: Claude example

Date: 2026-07-04

## Asset Brief

Asset family: terrain / landmark building kit

Gameplay role: readable Mos Eisley cantina social hub and terrain anchor

Target camera: ground MMO camera, owner closeup, and overhead interior review

Desired pipeline lane: SW_MUSH description-derived SVG contracts -> Blockbench kit pieces -> Blender GLB -> docs-only Godot review scene

Baseline to compare against:

- `scripts/world/landmark_builder.gd` current procedural cantina plaza
- `generated/cantina_terrain_reference_v0/cantina_source_comparison.svg`

## Scope Control

What may change: terrain shape, entrance readability, kit-piece proportions, blockcraft facade and interior affordance pieces

What must stay fixed: SW_MUSH-derived multi-room playable contract: entrance -> main bar -> back hallway; implied cellar/restrooms/office affordances; no-droids threshold; social/secured interior; trouble outside

One-variable rule: first pass changes terrain/kit shape only, not final palette polish or NPC placement

Out of scope: runtime promotion, copied fan-art geometry, exact film-set layout, official textures/logos, quest logic changes

## Visual Direction

Private/friends authenticity target: strong Mos Eisley cantina read through desert dome massing, recessed threshold, dim interior, bar/booth/bandstand identity, and doorway house rules

Public/license-clean target, if different: generic desert spaceport cantina social hub

Must-read features:

- elevated/recessed entrance;
- no-droids sign/detector;
- main bar anchor;
- booth ring/clusters;
- bandstand;
- back hallway/cellar marker;
- exterior plaza and doorstep trouble zone.

Palette notes: sand/adobe, dark interior, red awning/sign accent, cyan/amber tech lights

Scale notes: large enough for several NPCs and players at the entrance; interior affordances must read from ground camera

Block/cube density: medium; more detailed than filler buildings, less detailed than hero character closeups

## References

Reference links or local docs:

- `TERRAIN_CANTINA_REFERENCE_PASS.md`
- `generated/cantina_terrain_reference_v0/REVIEW.md`
- `C:\SW_MUSH\data\worlds\clone_wars\planets\tatooine.yaml` rooms 12-14
- `C:\SW_MUSH\data\worlds\clone_wars\maps\chalmuns_cantina.yaml`

Observed lessons:

- fan art can provide exterior mood and clutter density;
- SW_MUSH provides the actual gameplay affordances;
- our SVGs should be created from descriptions/data as neutral visual contracts;
- the model should be a kit, not a monolith.

What must not be copied:

- exact fan-art facade;
- exact official film-set geometry;
- official signs/logos/textures;
- fan art pixels or traced silhouette.

Transformative changes required:

- original blockcraft massing;
- stylized modular kit pieces;
- visible gameplay thresholds based on SW_MUSH text/data.

## Requested Outputs

Expected output folder: `docs/gpt/asset_factory/generated/REQ-20260704-cantina-terrain-pass/`

Source format requested: `.bbmodel` kit pieces plus JSON/spec if generated

Runtime candidate requested: `.glb` kit pieces only after validation

Preview captures requested:

- exterior approach;
- overhead interior route;
- ground camera with character scale;
- optional fan-art-lesson comparison notes, no copied image packaging.

Validation requested: `gltf-transform validate` for GLBs; Godot review-scene run if feasible

## Acceptance Checklist

- [ ] Reads clearly from the target camera.
- [ ] Matches the current blockcraft style.
- [ ] Has an editable source file or spec.
- [ ] Has rendered review captures.
- [ ] Has GLB/Godot validation if applicable.
- [ ] Avoids ripped/copied official or fan assets.
- [ ] States keep/reject verdict.
- [ ] Recommends the next one-variable iteration.

## Notes For Codex

This request is about terrain and affordance readability, not final decoration. If the exterior looks good but the entrance/bar/back-hallway contract is unclear, mark partial or reject.
