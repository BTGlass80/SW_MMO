# Animation Request Protocol

Date: 2026-07-04  
Scope: docs-only protocol for requesting blockcraft animation work from Codex

## Purpose

This protocol answers the owner's question:

> If Claude asks for animations, can we work toward that and nail down the request protocol?

Yes, but the pipeline should split animation into two families immediately:

```text
scene interaction animation
  seat, talk, drink, inspect terminal, lean on bar, operate door

character action animation
  idle, walk, run, shoot, reload, take cover, get hit, emote
```

These are different problems. Scene interactions are mostly anchors, poses, timing, and props inside a known environment. Character actions need a shared rig, sockets, loop rules, root-motion policy, and runtime import validation.

The first implemented proof is intentionally a scene-interaction proof, not a final skeletal combat rig:

```text
generated/godot_cantina_seated_social_anim_v0/REVIEW.md
```

## Current Recommendation

Use this split until a better A/B test beats it:

| Animation family | Current lane | Why |
| --- | --- | --- |
| Seated/social/environment interactions | Godot pose and AnimationPlayer proof first, then promote useful actor/anchor conventions into Blockbench or Blender | Fastest way to validate seating, scale, timing, camera read, and environment anchors |
| Humanoid locomotion/combat | Shared blockcraft humanoid rig, then Blender/glTF animation clips, then Godot import proof | Needs reusable skeleton/clip names and stricter validation than pose proofs |
| Ship motion | Godot tactical animation proof first | Ships need x/y movement, sensor rings, facing arcs, and isometric camera validation more than bone rigs |
| Door/terminal/prop loops | Godot or Blockbench transform animation depending on whether the source is a prop GLB | Small transform loops should stay cheap and editable |

Do not lock a full animation-production lane yet. Lock only the request shape and validation requirements.

## Request Types

### `anim_scene_interaction`

Use for Cantina booths, bar conversations, shop counters, terminals, doors, seated NPCs, medbay beds, briefing tables, and cover-entry pose studies.

Strong request fields:

- target scene or module;
- anchors;
- participating actors;
- props;
- camera;
- key poses;
- clip names;
- whether the proof may use procedural placeholder actors;
- whether a final rigged GLB is requested or only a Godot proof.

Example:

```text
Create a Cantina seated-social interaction proof using the kept bar/booth bay.
Actors: two blockcraft humanoids seated across a booth table.
Clips: sit_idle_loop, lean_talk_loop, drink_loop, turn_to_speaker_loop.
Use procedural placeholder actors if needed. Do not modify the bar/booth GLB.
Show keyframe captures and save a Godot AnimationPlayer proof scene.
```

### `anim_character_action`

Use for clone troopers, droids, Jedi support, bounty hunters, medics, and other reusable character kits.

Strong request fields:

- baseline character model or rig;
- weapon or prop sockets;
- target gameplay state;
- clip list;
- loop/root-motion rule;
- contact constraints;
- camera proof;
- import validation expectations.

Example:

```text
Create a clone rifleman action set proof.
Baseline: cubecraft_clone_rifleman_01 scale and proportions.
Clips: idle_rifle_loop, walk_rifle_inplace_loop, run_rifle_inplace_loop, fire_rifle_once, take_cover_low_in, take_cover_low_idle, take_cover_low_out.
Use in-place loops for now. Weapon muzzle must stay readable from the ground camera.
Return editable rig source, GLB animation names, and Godot import captures.
```

### `anim_vehicle_tactical`

Use for isometric ships, droid walkers, speeders, gunships, and battlefield indicators.

Strong request fields:

- vehicle baseline;
- x/y plane behavior;
- facing arcs;
- thruster or weapon effect;
- tactical overlay;
- camera scale;
- looping versus one-shot behavior.

Example:

```text
Create an isometric ship movement proof for the friendly interceptor baseline.
Keep the ship GLB fixed. Change only Godot tactical motion: turn-in-place, thrust pulse, fire arc, and movement ghost.
Capture the isometric camera at small tactical scale.
```

## Naming Conventions

Use these default clip names unless a request has a better reason:

### Humanoid idle and locomotion

```text
idle_unarmed_loop
idle_rifle_loop
walk_unarmed_inplace_loop
walk_rifle_inplace_loop
run_unarmed_inplace_loop
run_rifle_inplace_loop
strafe_left_rifle_inplace_loop
strafe_right_rifle_inplace_loop
```

### Combat

```text
aim_rifle_loop
fire_rifle_once
reload_rifle_once
melee_swing_once
grenade_throw_once
hit_react_front_once
downed_once
```

### Cover

```text
take_cover_low_in
take_cover_low_idle
take_cover_low_fire_once
take_cover_low_out
take_cover_high_in
take_cover_high_idle
take_cover_high_fire_once
take_cover_high_out
```

### Social and environment interaction

```text
sit_down_once
sit_idle_loop
lean_talk_loop
drink_loop
turn_to_speaker_loop
operate_terminal_loop
bar_lean_idle_loop
door_scan_once
```

## Anchor and Socket Names

Use stable names so Claude, Codex, Godot, and a future runtime integration can talk about the same points:

```text
seat_anchor_a
seat_anchor_b
table_anchor
look_target_a
look_target_b
prop_socket_right_hand
prop_socket_left_hand
weapon_socket_primary
weapon_muzzle
cover_anchor_low
cover_anchor_high
terminal_anchor
door_interact_anchor
```

For scene interactions, anchors belong to the environment module or review scene. For combat actions, sockets belong to the character rig.

## Deliverable Standard

Every animation response should include:

- request id;
- animation family;
- baseline scene/model/rig;
- changed variable;
- clip names;
- anchor/socket names used;
- source files;
- review scene paths;
- captures or contact sheet;
- import/validation result;
- keep/reject verdict;
- next one-variable recommendation.

If a proof is only a pose/AnimationPlayer study, say that clearly. Do not present it as a final runtime animation pack.

## Quality Gates

### Scene interactions

A scene-interaction candidate needs:

- characters fit the environment scale;
- pelvis, feet, and hands line up with seats, tables, props, or terminals;
- poses read from the target camera;
- the environment baseline is not accidentally changed;
- anchors are named;
- keyframe captures are saved;
- a Godot proof scene is saved if feasible.

### Character action clips

A humanoid action candidate needs:

- shared rig or part naming;
- stable clip names;
- in-place versus root-motion policy stated;
- weapon sockets and muzzle direction checked;
- foot sliding reviewed for locomotion loops;
- cover height and muzzle clearance checked for cover clips;
- GLB animation names import into Godot when a GLB exists;
- ground-camera captures or a contact sheet.

### Vehicle tactical clips

A vehicle tactical candidate needs:

- isometric camera proof;
- facing and movement direction are readable;
- tactical indicators do not hide the model;
- x/y plane behavior matches the owner's 2.5D space vision;
- ship model source remains editable if the motion proof is only Godot-side.

## Current First Proof

The first proof is:

```text
generated/godot_cantina_seated_social_anim_v0/REVIEW.md
```

It keeps the `blockbench_cantina_bar_booth_bay_v1` GLB fixed and changes only:

```text
static social props -> named seated anchors and procedural actor key poses
```

This is useful because it tests the request protocol, key-pose captures, Godot scene saving, and booth-scale readability before spending time on a full rig.

## Next Animation Slice

If this first proof is acceptable, the next useful animation slice is not "animate everything." It is:

```text
shared blockcraft humanoid rig contract
  -> clone rifleman idle_rifle_loop and fire_rifle_once
  -> Godot import/camera proof
```

That would start the `anim_character_action` lane with one clone trooper and two clips before expanding to walk, run, reload, and cover.
