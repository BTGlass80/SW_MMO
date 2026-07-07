# Ship Microfighter Pass

Date: 2026-07-04  
Status: kept after generation, Blender conversion, image inspection, and representative glTF validation

## Why This Pass Exists

The owner correctly challenged two assumptions:

1. The earlier ship blocks were too chunky.
2. The Godot JSON pipeline may not be better for ships.

I agree with both points after this pass.

The current recommendation is:

```text
characters: Blockbench/Blender lane
ships: Blockbench/Blender or future voxel lane
space tactical UI: Godot procedural lane
concept/reference boards: SVG/bitmap/online references as visual contracts
```

Godot JSON is still valuable, but mainly for overlays, tactical markers, quick blockouts, and generated review scenes. Ship silhouettes need a ship-specific grammar.

## Reference Question

Would online image or LEGO-like reference be stronger?

Yes, if used carefully.

The reason LEGO-like references help is that LEGO Microfighters already solve a similar abstraction problem: they compress recognizable ships into small, toy-scale builds with exaggerated cockpit, engines, weapons, color panels, and a chunky playable silhouette. Official LEGO product language for Microfighters emphasizes miniature, quick-build ships with cockpit/play features; Brickipedia similarly describes Microfighters as small versions with exaggerated features and a pilot area.

That is almost exactly the kind of reference pressure this project needs. But it must be used as a "Palmon treatment":

```text
Look at the reference for silhouette family and abstraction strategy.
Do not trace the exact model.
Write an original cube grammar.
Generate original Blockbench source.
Validate and review it in Godot/Blender.
```

Useful reference links:

- LEGO Plo Koon's Jedi Starfighter Microfighter: <https://www.lego.com/en-us/product/plo-koons-jedi-starfighter-microfighter-75400>
- LEGO Boba Fett's Starship Microfighter: <https://www.lego.com/en-us/product/boba-fetts-starship-microfighter-75344>
- Brickipedia Microfighters overview: <https://brickipedia.fandom.com/wiki/Star_Wars/Microfighters>

## What Changed

New spec:

```text
docs/gpt/asset_factory/specs/blockbench_ship_micro_v1.json
```

New generated review root:

```text
docs/gpt/asset_factory/generated/blockbench_ship_micro_v1/
```

New review boards:

```text
docs/gpt/asset_factory/generated/blockbench_ship_micro_v1/REVIEW.md
docs/gpt/asset_factory/generated/blockbench_ship_micro_v1/GLB_REVIEW.md
```

Generated assets:

- `micro_arc_interceptor_v1`
- `micro_v_lancer_v1`
- `micro_tri_droid_stalker_v1`
- `micro_blockade_runner_v1`

The spec has 4 ships with 76 total cubes. Compared with the earlier space tableau, this pass increases detail through smaller cuboids, cockpit blocks, colored panels, weapon nubs, engine blocks, and clearer faction color language.

## Result

Contact sheet:

![Ship contact sheet](generated/blockbench_ship_micro_v1/previews/contact_sheet.png)

Representative GLB preview:

![Micro ARC Interceptor v1](generated/blockbench_ship_micro_v1/glb/previews/micro_arc_interceptor_v1.png)

## Validation

Representative validation command:

```powershell
gltf-transform validate docs\gpt\asset_factory\generated\blockbench_ship_micro_v1\glb\micro_arc_interceptor_v1.glb
```

Result:

```text
No errors found.
No warnings found.
No infos found.
No hints found.
```

## Honest Assessment

This pass is better than the previous ship tableau.

The friendly ships now read as ships, not abstract bars. The compact toy/microfighter proportions are much closer to the desired "Star Wars Minecraft" direction. The increased cube count helps, but the real improvement comes from better shape grammar: cockpit, engine glow, weapons, wing panels, red/white faction marks.

The hostile droid fighter is still weaker. It reads as a droid threat, but not yet with the same charm as the friendly ships. Its next pass should change only hostile silhouette language.

The freighter/corvette token is promising but needs actual tactical camera testing. It may still flatten into a plate depending on the runtime camera.

## Follow-Up Iteration: Hostile Droid v2

The recommended next one-variable pass was completed in:

```text
docs/gpt/asset_factory/specs/blockbench_ship_droid_v2.json
docs/gpt/asset_factory/generated/blockbench_ship_droid_v2/GLB_REVIEW.md
```

Result:

```text
Keep v2.
```

The v2 droid ship keeps the same pipeline but changes only hostile silhouette language. It uses a flatter center profile, bigger eye-forward read, more forward prongs, and smaller cuboids. It is a better hostile baseline than `micro_tri_droid_stalker_v1`.

## Follow-Up Iteration: Friendly Panel v2

The recommended texture/panel pass was completed in:

```text
docs/gpt/asset_factory/specs/blockbench_ship_panel_v2.json
docs/gpt/asset_factory/generated/blockbench_ship_panel_v2/GLB_REVIEW.md
```

Result:

```text
Keep v2.
```

The panel v2 ship keeps the same friendly ARC-style silhouette and adds only small surface/panel detail. It improves the authored craft read without turning the model into visual noise. Use `micro_arc_interceptor_panel_v2` as the friendly ARC-style baseline before runtime camera testing.

## Revert / Keep Decision

Keep.

No output from this pass is being promoted into runtime. It remains a docs-only review artifact. But as a pipeline direction, it is an improvement and should be continued.

The only mistake encountered in this broader pipeline session was Blender's first dark preview setup. That was fixed by switching the review renderer to Workbench/material-color mode. The generated GLBs remained valid.

## Next One-Variable Iterations

1. Hostile droid ship only
   - Keep friendly ships unchanged.
   - Increase hostile visual menace with a flatter tri-wing silhouette, larger central eye, and more asymmetric droid panels.
   - Status: completed as `blockbench_ship_droid_v2`; keep v2.

2. Texture-panel detail only
   - Keep the same ship geometry.
   - Add pixel/panel texture support so Minecraft-like detail comes from 16x16-ish surfaces, not only more cubes.
   - Status: completed as `blockbench_ship_panel_v2`; keep v2.

3. Runtime camera test only
   - Import current GLBs into a docs-only Godot review scene.
   - Capture them at the intended isometric tactical camera.
   - Compare with Blender review captures.

4. Online/LEGO-like reference board only
   - Build a small written/visual reference grammar.
   - Extract no geometry.
   - Translate into original cube recipes.

My pick for the next pass is hostile droid ship only, because the friendly ships are now plausibly on the right track and the weakest output should get the next controlled change.
