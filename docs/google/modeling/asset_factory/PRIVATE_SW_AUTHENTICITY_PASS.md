# Private SW Authenticity Pass

Date: 2026-07-03  
Scope: docs/gpt asset-pipeline prototype only  
Status: generated and visually inspected in Godot 4.6.3

## Intent

The owner clarified that this is a personal project for friends, not a commercial product, and asked to prioritize SW authenticity as much as possible. This pass responds to that by creating a separate private-fan review lane that pushes harder toward Clone Wars readability than the license-clean "almost space opera" lane.

This does not mean ripping official assets. The current artifacts are still generated from JSON specs into Godot primitive scenes. The authenticity comes from silhouettes, color language, faction roles, and WEG/Clone Wars gameplay function:

- clone infantry with bucket helmet, T/drop visor, white armor, blue field markings, backpack, and blaster;
- clone commander with pauldron, rangefinder, blue command cues, and sidearm;
- clone heavy trooper with launcher/backpack/heavy weapon silhouette;
- Jedi support pawn with robe/tunic/saber read;
- B1-style tan skinny droid and B2-style bulky heavy droid;
- rolling shield-droid-inspired threat silhouette;
- LAAT-like gunship token;
- desert outpost tactical slice;
- modular outpost gate/cover/terminal kit piece;
- 2.5D isometric space-skirmish slice.

## Review First

Generated review board:

`generated/private_clone_wars_blockcraft_v0/REVIEW.md`

Best quick captures:

- `generated/private_clone_wars_blockcraft_v0/captures/contact_sheet_characters.png`
- `generated/private_clone_wars_blockcraft_v0/captures/assets/fan_clone_wars_outpost_slice_01.png`
- `generated/private_clone_wars_blockcraft_v0/captures/assets/fan_clone_wars_space_skirmish_01.png`
- `generated/private_clone_wars_blockcraft_v0/captures/assets/fan_republic_gunship_token_01.png`

Focused spacecraft pass:

- `PRIVATE_SPACECRAFT_PASS.md`
- `generated/private_clone_wars_spacecraft_v0/REVIEW.md`

Source spec:

`specs/private_clone_wars_blockcraft_v0.json`

## My Read

This is the closest current artifact to "Star Wars Minecraft." It is not beautiful yet, but it has the right production shape: the models are cheap, coherent, Godot-native, and iteratable by changing structured specs.

The character contact sheet is the most important proof. The clones, clone heavy, B1, B2, rolling threat, and Jedi are all distinguishable from an isometric camera. That matters more than beauty at this stage because the art pipeline needs gameplay readability first.

The outpost slice is stronger after the second pass. It now looks like a small tactical diorama rather than a single wall hiding the action. It still needs a modular kit before it belongs in-game.

The space slice is directionally correct for the owner's intended 2.5D: flat tactical x/y movement, but rendered through an isometric camera so the board has depth. It needs better ship silhouettes, but this is the correct camera and interaction metaphor.

The focused spacecraft pass improves this with a dedicated isometric space contact sheet and a clearer combat tableau. Use that pass for future space-visual decisions rather than the older single space slice in this pack.

## What Worked

- Godot primitive scenes can be meaningful models, not just bitmap mockups.
- Blockcraft constraints make SW silhouettes authorable as data.
- Strong color identity helps: clone white/blue, tan B1, blue-gray B2, cyan tech, orange hostile targeting.
- Review captures are fast enough to support iteration while the owner is not present.
- Contact sheets let the owner judge style without opening Godot.
- The heavy clone and modular gate prove the pack can expand without immediately losing visual coherence.

## What Still Fails

- The models are toy-like, but not yet charming. The style needs one more level of authored proportions.
- B1 droids need more neck/head/backpack specificity.
- Gunships and starfighters need actual silhouette language, not just colored wing blocks.
- The outpost needs a full kit: wall variants, doors, ramps, consoles, crates, pipes, antennae, cover blocks.
- There is no animation or rigging grammar yet.
- There is no material-normalization pass for mixing Kenney/Quaternius/procedural content.

## Recommended Next Pass

Do not chase high-fidelity realism. Chase a cohesive blockcraft table.

1. Character grammar v1
   - Improve the 3 existing clone variants: rifleman, commander, heavy.
   - Improve the 3 existing CIS variants: B1, B2, rolling shield threat.
   - Build 2 hero/support silhouettes: Jedi field adept, medic/engineer.
   - Review them at final gameplay camera size.

2. Clone Wars desert kit v1
   - 6 wall chunks.
   - 3 doorway/arch pieces.
   - 3 roof/canopy pieces.
   - 4 terminals.
   - 6 cover props.
   - 3 landing-pad pieces.

3. 2.5D space kit v1
   - 3 Republic-friendly silhouettes.
   - 3 CIS/hostile silhouettes.
   - 2 freighters.
   - 3 asteroid/debris clusters.
   - laser streaks, target brackets, sensor pings.

4. Runtime camera test
   - Create a docs-only Godot review scene with the accepted generated `.tscn` assets.
   - Capture from the actual intended gameplay cameras.
   - Reject anything that only looks good in a bespoke review camera.

## Pipeline Advice

For this private lane, I would use three layers:

1. Procedural blockcraft for breadth
   - Best for dozens of tactical props, simple pawns, terrain, settlement modules, and space tokens.
   - Cheap and highly controllable.

2. Kenney/Quaternius kitbash for environment geometry
   - Use as raw CC0 geometry vocabulary, then normalize scale/materials.
   - Good for crates, barrels, rocks, buildings, landing pads, industrial clutter.
   - Do not let mixed asset packs define the style; run them through a shared material palette.

3. Human/API/Blender pass for hero silhouettes
   - Use only on high-value models: clone player body, B1/B2, gunship, signature starfighters, cantina/spaceport hero buildings.
   - The output should be simplified back into the blockcraft grammar, not imported as a random realistic mesh.

## Authenticity Guardrails

Because the project is private/friends, the art direction can be more direct in spirit. Still:

- do not import ripped official meshes, textures, logos, fonts, audio, or exact traced model files;
- keep generated/procedural sources editable and inspectable;
- separate this private-fan lane from any future public/license-clean lane;
- document whether an asset is "private-fan", "almost space opera", or "license-clean original."

For the public-safe/Palworld-style analysis, see `ALMOST_SPACE_OPERA_GUIDE.md`. For the private-fan target, this file is the stronger north star.

## Bottom Line

Yes: take the "Palworld approach" in the sense of strong genre readability, but for this project the better label is:

```text
Clone Wars blockcraft fan table
```

That phrase keeps the target honest. It should feel like a playable WEG Clone Wars tabletop/MMO toy set: instantly recognizable to friends, cheap to generate, easy to iterate, and simple enough that the art pipeline does not become the whole project.
