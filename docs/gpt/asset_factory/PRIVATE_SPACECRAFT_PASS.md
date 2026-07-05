# Private Spacecraft Pass

Date: 2026-07-04  
Scope: docs/gpt asset-pipeline prototype only  
Status: generated and visually inspected in Godot 4.6.3

## Why This Pass Exists

The owner's intended "2.5D space" was flat tactical x/y play shown through an isometric camera, not a flat top-down UI panel. The previous all-in-one space slice was directionally useful, but it did not yet prove that the space layer could feel like a real Clone Wars-era blockcraft board.

This pass creates a focused spacecraft pack:

`specs/private_clone_wars_spacecraft_v0.json`

Generated review board:

`generated/private_clone_wars_spacecraft_v0/REVIEW.md`

## What It Contains

- Republic-friendly arrow fighter token.
- Republic-friendly broadwing fighter token.
- Clone patrol gunship / transport token.
- CIS-style droid tri-fighter token.
- CIS-style bomber/heavy drone token.
- Frontier light freighter token.
- Full isometric space combat tableau with friendlies, hostiles, freighter, asteroid cover, laser lanes, and target brackets.

All assets are generated as Godot `.tscn` scenes from primitive parts. They are not bitmap-only concepts.

## Best Captures

- `generated/private_clone_wars_spacecraft_v0/captures/contact_sheet_space.png`
- `generated/private_clone_wars_spacecraft_v0/captures/assets/fan_clone_wars_space_tableau_02.png`
- `generated/private_clone_wars_spacecraft_v0/captures/assets/fan_republic_arrow_fighter_token_01.png`
- `generated/private_clone_wars_spacecraft_v0/captures/assets/fan_droid_tri_fighter_token_01.png`
- `generated/private_clone_wars_spacecraft_v0/captures/assets/fan_frontier_light_freighter_token_01.png`

## My Read

This is a meaningful improvement over the first space slice.

The important win is not that the ships are beautiful. They are not. The win is that the board reads as a tactical space scene from an isometric camera while still being built from low-cost procedural Godot scenes.

The best current artifact is `fan_clone_wars_space_tableau_02.png`: it has faction contrast, flat tactical readability, cover/debris, laser lanes, target brackets, and multiple ship roles in one shot. That is much closer to the owner's 2.5D vision than the earlier flat overlay.

## What Worked

- Red/white/cyan makes friendly Republic-ish craft readable.
- Tan/dark/orange makes hostile droid craft readable.
- The freighter adds civilian/scoundrel context, which matters for WEG play.
- Laser lanes and brackets clarify that this is gameplay space, not just decorative ships.
- The review camera gives 3D depth without implying freeform 3D space movement.

## What Still Needs Work

- Several individual ships still read as "block toy plane" more than "space-opera craft."
- The patrol gunship is too rectangular; it needs stronger side-pod, nose, and wing silhouette.
- Droid craft need more spidery/aggressive profiles.
- Big ships are missing: corvette, frigate, carrier, bulk freighter.
- The board needs sensor/range rings, altitude-free lanes, and station-action markers.

## Recommended Next Pass

1. Add silhouette classes:
   - interceptor;
   - bomber;
   - gunship/transport;
   - corvette;
   - freighter;
   - droid swarm craft.

2. Add tactical overlays:
   - selected target;
   - sensor sweep;
   - shield arc;
   - weapon range band;
   - hyperspace vector;
   - hazard field.

3. Build a docs-only runtime-space mock:
   - one isometric camera;
   - 6-10 moving ship tokens on an x/y plane;
   - click/selection markers;
   - no ground UI underneath;
   - capture stills for owner review.

4. Promote no assets yet.
   - This is still a style proof, not runtime art.
   - Pick 2-3 winners and iterate them before promotion.

## Bottom Line

This pass answers one important question: yes, the space layer can be flat tactical x/y and still look like a 3D/isometric Clone Wars blockcraft board.

The next question is whether the ship silhouettes can become charming enough. That probably requires a hybrid path:

```text
procedural spec -> Godot capture -> pick winners -> Blender/Blockbench silhouette cleanup -> Godot import -> same capture rig
```

For bulk assets, keep using the spec-driven lane. For iconic ships, do a cleanup pass.
