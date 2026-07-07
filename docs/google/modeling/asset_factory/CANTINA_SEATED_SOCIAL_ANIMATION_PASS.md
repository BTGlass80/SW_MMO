# Cantina Seated Social Animation Pass

Date: 2026-07-04  
Scope: docs-only animation protocol proof for the kept Cantina bar/booth module

## Purpose

This pass answers whether Claude can eventually ask Codex for animations such as:

- characters sitting together in the Cantina;
- a clone trooper walking, shooting, running, or taking cover;
- social and environment interactions with clear request fields.

The answer is yes, but animation needs two lanes:

```text
scene interaction animation
  -> anchors, poses, props, timing, Godot proof

character action animation
  -> shared rig, sockets, glTF clips, Godot import proof
```

This pass tests the first lane only.

## Baseline

Baseline scene/module:

```text
generated/godot_cantina_bar_booth_bay_v1/REVIEW.md
generated/blockbench_cantina_bar_booth_bay_v1/glb/blockbench_cantina_bar_booth_bay_v1.glb
```

The kept bar/booth GLB remains fixed.

## Controlled Change

Changed variable:

```text
static social props -> named seated anchors, procedural blockcraft actors, key poses, and a saved Godot AnimationPlayer proof scene
```

This does not change:

- runtime game files;
- source gameplay code;
- the bar/booth GLB;
- the Blockbench source baseline;
- the broader Cantina layout.

## Generated Artifacts

Protocol doc:

```text
ANIMATION_REQUEST_PROTOCOL.md
```

Animation request template:

```text
requests/ANIMATION_REQUEST_TEMPLATE.md
```

Godot proof:

```text
generated/godot_cantina_seated_social_anim_v0/REVIEW.md
```

Saved proof scene:

```text
generated/godot_cantina_seated_social_anim_v0/review_scenes/cantina_seated_social_animation_player.tscn
```

Generated captures:

```text
generated/godot_cantina_seated_social_anim_v0/captures/seated_social_contact_sheet.png
generated/godot_cantina_seated_social_anim_v0/captures/seated_idle_pair.png
generated/godot_cantina_seated_social_anim_v0/captures/lean_talk_keyframe.png
generated/godot_cantina_seated_social_anim_v0/captures/drink_loop_keyframe.png
generated/godot_cantina_seated_social_anim_v0/captures/turn_to_speaker_keyframe.png
```

## Clip Names Proved

The saved Godot proof scene includes:

```text
sit_idle_loop
lean_talk_loop
drink_loop
turn_to_speaker_loop
```

## Anchor Names Proved

The proof uses:

```text
seat_anchor_a
seat_anchor_b
table_anchor
look_target_a
look_target_b
```

These names are intentionally boring. Boring names are good when Claude, Codex, and Godot all need to agree about the same attachment points.

## What It Proves

This pass proves:

- Claude can ask for an animation as a focused request.
- Codex can answer with keyframe captures and a saved Godot proof scene.
- Scene interaction requests need anchors and clip names, not just "make it animate."
- The Cantina social animation problem is different from clone-trooper combat animation.

## What It Does Not Prove

This pass does not prove:

- a final skeletal rig;
- Blender-authored humanoid animation;
- GLB animation export/import;
- root motion;
- weapon sockets;
- cover alignment;
- runtime integration.

Those belong to the next animation lane.

## Verdict

Candidate protocol keep.

The second staging pass is better than the first because it moves the procedural actors into a clear foreground booth micro-set while preserving the kept bar/booth GLB as the scene context. The result is not production animation, but it is useful as the request/proof pattern.

## Next One-Variable Recommendation

Create:

```text
shared_blockcraft_humanoid_rig_v0
```

Then test only two clone rifleman clips:

```text
idle_rifle_loop
fire_rifle_once
```

Keep the rifleman body scale fixed. Validate that the GLB animation names import into Godot and capture them from the ground camera before adding walk, run, reload, or cover.
