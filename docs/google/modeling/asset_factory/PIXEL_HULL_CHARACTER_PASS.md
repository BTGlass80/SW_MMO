# Pixel Hull Character Pass

Date: 2026-07-04  
Scope: docs-only extension of the deterministic pixel-card lane toward more-3D humanoids

## Purpose

The owner asked whether the pixel-card method could keep the strict, deterministic control of "one pixel becomes one block" while avoiding paper-flat characters and equipment.

This pass tests that directly:

```text
front pixel card
  + side pixel card
  -> deterministic voxel visual hull
  -> Godot capture and rotation check
```

It is still zero-credit, project-owned source art. No Meshy, no fan-art upload, no official art conversion.

## Generated Proof

Review:

```text
generated/godot_pixel_hull_character_v0/REVIEW.md
```

Script:

```text
scripts/godot_pixel_hull_character_proof.gd
```

Source cards:

```text
generated/godot_pixel_hull_character_v0/source_images/trooper_front_card_16x28.png
generated/godot_pixel_hull_character_v0/source_images/trooper_side_card_10x28.png
```

Captures:

```text
generated/godot_pixel_hull_character_v0/captures/pixel_hull_source_cards.png
generated/godot_pixel_hull_character_v0/captures/pixel_hull_flat_vs_volume.png
generated/godot_pixel_hull_character_v0/captures/pixel_hull_trooper_three_quarter.png
generated/godot_pixel_hull_character_v0/captures/pixel_hull_trooper_rotation_contact_sheet.png
```

## Result

Candidate research keep.

The method creates real volume from a front/side contract instead of a single flat image. It is visibly more 3D than a paper cutout and still fully deterministic.

Current stats from the proof:

| Candidate | Mode | Boxes | Raw voxels |
| --- | --- | ---: | ---: |
| Flat front extrusion | same-color horizontal runs | 92 |  |
| Front+side visual hull | z-run merged visual hull | 247 | 1376 |

That is too dense to promote blindly, but small enough for prototyping and good enough to prove the idea.

## What It Solves

This lane answers a very specific problem:

```text
How do we keep strict voxel control while getting more than a flat sprite?
```

Best current uses:

- low-detail background NPCs;
- distant crowd actors;
- small droids with simple side profiles;
- icon-scale humanoids for tactical/social scenes;
- body-plan exploration before Blockbench cleanup.

It gives Codex/Claude a way to author recognizable blockcraft actors from controllable source cards.

## What It Does Not Solve Yet

This is not a replacement for Blockbench foreground characters.

The whole-body hull lacks:

- stable head/torso/limb boundaries;
- animation sockets;
- clean weapon grip points;
- separate armor plates and gear pieces;
- easy human editing per part.

If we tried to animate the current whole-body hull, it would behave like a chunky statue.

## Recommended Next Version

The next one-variable improvement should not be "more pixels." It should be part separation:

```text
front/side cards per body part
  -> head hull
  -> torso hull
  -> upper-arm hulls
  -> lower-arm hulls
  -> leg hulls
  -> weapon hull
  -> backpack hull
  -> rigid-part animation proof
```

That keeps deterministic geometry and creates usable animation boundaries. It also maps cleanly to Blockbench if a human or Claude later wants to polish the result.

This next version now exists:

```text
PIXEL_HULL_BODY_PARTS_PASS.md
generated/godot_pixel_hull_body_parts_v0/REVIEW.md
```

Treat it as a candidate keep for low-detail/background actor pose proofs and as a bridge into Blockbench for foreground rigs.

## Relationship To Blockbench

Use this lane as a bridge, not a replacement:

```text
pixel-hull proof
  -> choose proportions and feature zones
  -> rebuild/polish in Blockbench when foreground identity matters
```

For foreground clone troopers, commanders, Jedi, and named NPCs, Blockbench remains the stronger source format because it gives editable parts and socket discipline.

For background actors or quick social-scene placeholders, pixel hulls may be enough.

## Request Shape

Claude can ask for this lane like:

```text
Create a pixel-hull body-plan proof for <actor>.
Use original front and side pixel cards.
Keep the source resolution under 32 px tall unless there is a reason.
Return source cards, flat-vs-volume capture, rotation contact sheet, box counts, and whether it should be rebuilt in Blockbench.
```

Good requests:

```text
Cantina background alien patron
simple service droid
clone rifleman body-plan comparison
medical NPC silhouette
```

Bad requests:

```text
final clone trooper combat rig
named hero character with detailed face
large creature with complex anatomy
```

Those need a body-part hull, Blockbench, or a human/API concept lane.
