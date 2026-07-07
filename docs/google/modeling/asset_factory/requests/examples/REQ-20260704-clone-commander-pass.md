# Asset Request: Clone Commander Pass

## Request

Request id: `REQ-20260704-clone-commander-pass`

Owner priority: high

Requested by: Claude example

Date: 2026-07-04

## Asset Brief

Asset family: character

Gameplay role: squad leader / officer silhouette for Republic-aligned players and NPCs

Target camera: ground MMO camera plus owner closeup

Desired pipeline lane: Blockbench `.bbmodel` -> Blender GLB -> Godot camera proof

Baseline to compare against: `generated/blockbench_cubecraft_v0/glb/cubecraft_clone_rifleman_01.glb`

## Scope Control

What may change: helmet detail, shoulder/pauldron shape, color stripe, antenna/rangefinder-like original detail, backpack

What must stay fixed: base humanoid proportions, blockcraft material style, current Godot camera proof setup

One-variable rule: change only commander readability over the rifleman baseline

Out of scope: animation, runtime promotion, official logos/decals, exact official helmet geometry

## Visual Direction

Private/friends authenticity target: recognizable Clone Wars commander energy through helmet/visor/color/role silhouette

Public/license-clean target, if different: generic armored space-opera squad leader

Must-read features: command stripe, stronger shoulder silhouette, obvious visor, larger weapon or command sidearm

Palette notes: off-white armor, black visor, red or blue command stripe, muted gray gear

Scale notes: same height as rifleman baseline

Block/cube density: slightly higher than rifleman only where it improves role read

## References

Reference links or local docs: use `REFERENCE_IMAGE_WORKFLOW.md`; optional toy/blockcraft references only for abstraction lessons

Observed lessons: command characters need exaggerated shoulder/helmet/stripe language

What must not be copied: exact official commander helmet, named character markings, logos, direct fan-art design

Transformative changes required: original pauldron/stripe layout and block geometry

## Requested Outputs

Expected output folder: `docs/gpt/asset_factory/generated/REQ-20260704-clone-commander-pass/`

Source format requested: `.bbmodel` plus JSON/spec if generated

Runtime candidate requested: `.glb`

Preview captures requested: Blender preview and Godot ground camera proof

Validation requested: `gltf-transform validate`

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

If the commander only reads in closeup, reject or mark partial. The gameplay camera read matters more than pretty detail.
