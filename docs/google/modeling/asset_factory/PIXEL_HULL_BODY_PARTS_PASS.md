# Pixel Hull Body-Parts Pass

Date: 2026-07-04  
Scope: docs-only deterministic voxel actor proof for rigid-part animation

## Purpose

The previous pixel-hull character pass proved that a front pixel card plus a side pixel card can create real voxel volume. Its weakness was animation: the whole actor behaved like one fused statue.

This pass tests the next one-variable improvement:

```text
front/side cards per body part
  -> head hull
  -> torso hull
  -> upper-arm hulls
  -> forearm hulls
  -> leg hulls
  -> backpack hull
  -> rifle hull
  -> pose the pieces as rigid animation nodes
```

The goal is not a final clone trooper. The goal is to answer whether deterministic pixel-card geometry can become requestable for animation.

## Generated Proof

Review:

```text
generated/godot_pixel_hull_body_parts_v0/REVIEW.md
```

Script:

```text
scripts/godot_pixel_hull_body_parts_proof.gd
```

Manifest:

```text
generated/godot_pixel_hull_body_parts_v0/body_part_pixel_hull_manifest.json
```

Captures:

```text
generated/godot_pixel_hull_body_parts_v0/captures/body_part_source_cards.png
generated/godot_pixel_hull_body_parts_v0/captures/body_part_neutral_vs_ready.png
generated/godot_pixel_hull_body_parts_v0/captures/body_part_rotation_contact_sheet.png
generated/godot_pixel_hull_body_parts_v0/captures/body_part_cover_pose_ab.png
```

## Result

Candidate keep for the deterministic animation lane.

The proof is materially stronger than the fused whole-body hull because the actor is assembled from addressable nodes: head, torso, upper arms, forearms, legs, backpack, and rifle. The neutral, rifle-ready, and cover-lean captures show that the parts can be posed without changing the source art or involving Meshy.

## What It Solves

This gives Claude/Codex a cheap protocol for animation-facing questions:

- background troopers or guards;
- seated/standing social extras;
- low-detail droids with segmented limbs;
- tactical icon actors that need recognizable poses;
- fast pose tests before committing to Blockbench rig work.

It also keeps the owner in the loop with deterministic inputs: source cards are visible, geometry is generated from those cards, and every pose can be reproduced.

## What It Does Not Solve

This is still not a finished foreground combat rig.

Known limitations:

- shoulder, elbow, and weapon pivots are approximate;
- the pose system is rigid-part animation, not skeletal deformation;
- the trooper silhouette needs hand-authored polish;
- individual armor plates and sockets are not production-clean;
- close camera shots still want Blockbench or a human-polished model.

## Recommendation

Use this lane when the goal is:

```text
strict voxel control + quick actor pose proof + low-detail/background read
```

Use Blockbench when the goal is:

```text
foreground identity + clean sockets + reusable combat animation rig
```

The next useful check is not "more pixels." It is a different anatomy fit: try a segmented battle/service droid. Rigid body-part hulls should fit droids better than humanoids because droids naturally have hard joints and separated limbs.

## Request Shape

Claude can request this lane like:

```text
Create a body-part pixel-hull proof for <actor>.
Use original front/side cards for head, torso, limbs, gear, and carried prop.
Return source cards, neutral pose, action pose, rotation sheet, box counts, and a verdict on whether to promote to Blockbench.
```

Good requests:

```text
background clone sentry with rifle-ready pose
cantina security guard idle/turn pose
segmented service droid with tool arm
medical droid with carry tray
low-detail alien patron seated pose
```

Bad requests:

```text
final clone trooper locomotion/combat pack
named hero character
Jedi lightsaber dueling rig
large creature with organic motion
```

Those need a Blockbench rig, Blender/glTF animation pipeline, or human/API help.
