# Model Restyle Backlog

Date: 2026-07-04  
Scope: docs-only planning for the blockcraft / "Star Wars Minecraft" art direction

## Purpose

This backlog turns the asset-factory experiments into a production map for restyling the actual game. It does not promote any generated asset into runtime. It tells Claude, Codex, or a human technical artist which model families should be made, which pipeline should make them, and what counts as "good enough" before moving on.

The current conclusion is not "generate everything from scratch." The better plan is:

```text
Kenney/CC0 kits: filler, world dressing, generic industrial props
Blockbench/Blender: recognizable characters, droids, ships, weapons, landmark silhouettes
Godot procedural: tactical overlays, sensor arcs, movement ghosts, review scenes, cheap blockouts
API/human help: only for hero creatures, animation, and hard organic shapes
```

The repo already has 1,051 curated Kenney `.glb` files under `assets/3d/kenney`. Those are a good base for cheap environment coverage, but they do not solve private/friends Clone Wars recognition by themselves. Recognition comes from exaggerated blockcraft silhouettes, color language, and repeated faction grammar.

## Kenney Cohesion Rule

Raw Kenney use can absolutely break cohesion if it is treated as final art beside custom Blockbench models.

Use Kenney as filler clay, not as the identity layer.

Allowed Kenney use:

- background world massing;
- crates, barrels, pipes, catwalks, generic industrial props;
- base pieces for hangars, stalls, workshops, and markets;
- temporary placeholders while custom silhouettes are still being proven.

Do not use raw Kenney for:

- hero characters;
- faction-defining ships;
- iconic weapons;
- landmark buildings;
- anything the player will judge as "the Star Wars Minecraft look."

Before a Kenney asset can sit next to a custom Blockbench asset, it needs a normalization pass:

- palette remap into the current zone palette;
- scale/origin/grid normalization;
- flat material/roughness consistency;
- optional blockcraft caps, panels, pipes, antennas, awnings, or faction markers;
- target-camera screenshot beside the custom baseline.

If a screenshot makes the world look like two unrelated asset packs, the Kenney piece fails even if the license is clean and the model imports correctly.

## Current Kept Baselines

These are the best docs-only examples so far:

- Character/small-prop lane:
  - `generated/blockbench_cubecraft_v0/GLB_REVIEW.md`
  - Best proof: `cubecraft_clone_rifleman_01.glb`
  - Verdict: Blockbench/Blender is better than Godot primitive JSON for characters.

- Friendly ship lane:
  - `generated/blockbench_ship_panel_v2/GLB_REVIEW.md`
  - Best proof: `micro_arc_interceptor_panel_v2.glb`
  - Verdict: keep panel v2 as the friendly ARC-style microfighter baseline.

- Hostile ship lane:
  - `generated/blockbench_ship_droid_v2/GLB_REVIEW.md`
  - Best proof: `micro_tri_droid_stalker_v2.glb`
  - Verdict: keep v2 as the hostile droid ship baseline.

- Space tactical overlay lane:
  - `generated/private_clone_wars_spacecraft_v0/REVIEW.md`
  - Verdict: Godot procedural is still best for rings, locks, range bands, movement ghosts, and review scenes.

## Production Principles

1. Start with a representative set, not the whole game.
   - One rifleman, one officer, one droid, one fighter, one hostile craft, one building kit, one weapon kit, one vendor/civilian kit.
   - If those do not look cohesive together, making 100 more only multiplies the wrong answer.

2. Use one variable per iteration.
   - Change silhouette, panel density, palette, camera, or scale. Not all at once.
   - Keep/reject decisions should be documented beside the generated previews.

3. Exaggerate features.
   - The LEGO / Microfighter lesson is correct: small assets need bigger cockpits, helmets, engines, muzzles, antennae, wings, and faction panels than "real" proportions.
   - At MMO camera distance, subtlety disappears.

4. Keep source editable.
   - `.bbmodel` is valuable because a non-modeler can adjust it in Blockbench.
   - GLB is runtime output, not the only source of truth.

5. Do not use raw reference images as assets.
   - Reference images are for silhouette grammar and proportion language only.
   - Rebuild as original cube grammar.

## Restyle Order

### Phase 0: Camera Proof

Before scaling asset creation, prove that the kept GLBs work in Godot from the intended game cameras.

Tasks:

- Import or instance docs-only copies of:
  - `micro_arc_interceptor_panel_v2.glb`
  - `micro_tri_droid_stalker_v2.glb`
  - `cubecraft_clone_rifleman_01.glb`
- Capture them from:
  - ground MMO camera distance;
  - isometric tactical space camera;
  - close owner-review camera.
- Compare Blender preview vs Godot runtime lighting.

Acceptance:

- The silhouette still reads at 1280x720.
- The ship does not flatten into a plate.
- The character helmet/weapon/faction read survives runtime lighting.
- Materials remain flat and cohesive.

Pipeline:

```text
Blockbench .bbmodel -> Blender GLB -> docs-only Godot review scene -> screenshot -> keep/reject
```

### Phase 1: Hero Grammar Pack

Create a small pack that covers the core fantasy of the game.

#### Characters

Use Blockbench/Blender.

Priority list:

- Clone rifleman baseline.
- Clone commander / squad leader.
- Clone heavy trooper.
- Clone scout / recon.
- Clone pilot / vehicle crew.
- Clone medic / engineer.
- Jedi support archetype.
- B1-style thin battle droid archetype.
- B2-style heavy battle droid archetype.
- Rolling shield droid archetype.
- Separatist officer / handler.
- Hutt-space mercenary.
- Moisture-farm civilian.
- Market vendor.

Acceptance:

- Helmet or head silhouette reads before detail.
- Weapon silhouette reads before detail.
- Faction color is obvious from 15 meters.
- Four or fewer dominant materials per model.
- Rigging can wait, but origin, scale, and stance must be consistent.

Notes:

- Characters currently look better than ships because humanoid blockcraft has a familiar grammar: head, torso, arms, legs, weapon.
- Keep that advantage by staying modular: shared clone helmet, shared torso, shared arm/leg proportions, role-specific backpack/pauldron/weapon.

#### Ships

Use Blockbench/Blender for models and Godot for tactical overlays.

Priority list:

- Friendly ARC-style microfighter baseline.
- Friendly V-wing / lancer-style interceptor.
- Friendly gunship token.
- Friendly transport / shuttle.
- Hostile droid tri-fighter archetype.
- Hostile bomber / bulkier droid craft.
- Hostile landing craft.
- Civilian freighter.
- Blockade runner / corvette.
- Bulk cargo hauler.
- Sensor buoy.
- Missile / torpedo / laser-bolt tokens.

Acceptance:

- Cockpit, engines, weapons, and faction panels are legible.
- Silhouette is distinct from every other ship in the same camera shot.
- Top/isometric read is prioritized over side profile.
- Ship remains toy-like, not a thin realistic scale model.

Notes:

- Do not assume the Godot JSON primitive lane is better for ships. Current evidence says Blockbench/Blender produces stronger ship silhouettes.
- Panel v2 proved that finer Minecraft-like detail helps when it is applied as small plate/panel blocks without changing the main silhouette.

#### Buildings

Use Kenney/CC0 kitbash plus Blockbench for distinctive landmark parts.

Priority list:

- Mos Eisley modular wall segment.
- Rounded desert doorway.
- Flat-roof building block.
- Dome cap.
- Awning kit.
- Landing pad kit.
- Hangar mouth.
- Cantina exterior.
- Med tent / field clinic.
- Barracks / militia post.
- Droid workshop.
- Vendor stall.
- Bounty terminal.
- Holo table / command table.
- Power generator.
- Moisture-tech tower, originalized.
- Security checkpoint gate.
- Lawless-zone barricade.

Acceptance:

- A player can identify building role from the street.
- Door/interaction points are visually obvious.
- Collision footprint is simple.
- Repeated pieces tile cleanly without looking like random kit fragments.

Notes:

- Existing Kenney industrial, factory, modular-building, survival, space-station, and mini-market kits can cover many filler pieces.
- The "SW feel" should come from desert massing, domes, pipes, awnings, antennae, landing pads, and droid/ship silhouettes rather than copied franchise shapes.
- The safest approach is to use Kenney for hidden structure and repeatable clutter, then add custom Blockbench "identity caps" such as rounded doors, roof domes, pipe clusters, antenna masts, awnings, faction signs, and landing-pad trim.

#### Weapons And Wearables

Use Blockbench for readable role silhouettes. Use Kenney blaster-kit only as generic kitbash input or filler.

Priority list:

- Starter blaster pistol.
- Clone carbine.
- Heavy repeating blaster.
- Droid rifle.
- Sniper/scout carbine.
- Rocket/ion launcher.
- Medic tool.
- Repair torch.
- Datapad.
- Binocular/sensor pack.
- Energy blade practice/special weapon archetype.
- Jetpack/backpack variants.
- Shoulder pauldron variants.

Acceptance:

- Weapon can be recognized in hand at gameplay scale.
- Muzzle, stock/grip, magazine/cell, and scope are exaggerated.
- No direct copied official weapon geometry.

Notes:

- Weapons are excellent candidates for the "reference -> silhouette grammar -> original cube model" process.
- Because weapon detail is small, over-exaggeration is not optional.

#### Creatures

Use API/human selectively, then normalize into blockcraft. Blockbench can handle simple creatures, but organic charm is harder.

Priority list:

- Small desert pest.
- Medium pack predator.
- Large mount/pack animal.
- Armored desert beast.
- Cave/ambush creature.
- Arena-scale boss creature.

Acceptance:

- Reads by body plan first: small runner, big brute, flying hazard, burrower, mount.
- Does not look like a random low-poly animal dropped into the game.
- Uses the same palette discipline as the rest of the world.

Notes:

- This is one of the few places where Meshy/Tripo/human help may be worth it.
- Even then, final output should be simplified, recolored, and normalized into the chosen style.

### Phase 2: Zone Packs

Once the hero grammar pack works, make zone packs.

Mos Eisley / spaceport:

- market stalls;
- docking bay clutter;
- hangar tools;
- cargo stacks;
- customs checkpoint;
- cantina exterior props;
- droid vendors;
- local civilians.

Dune Sea / lawless:

- rock clusters;
- raider barricades;
- desert camps;
- wreckage;
- salvage piles;
- cave entrances;
- creature nests.

Faction conflict areas:

- Republic checkpoint kit;
- Separatist relay kit;
- Hutt checkpoint kit;
- bounty-hunter camp kit;
- deployable barricades;
- field generators.

Space:

- asteroid chunks;
- debris fields;
- sensor buoys;
- civilian freighters;
- hostile patrol craft;
- capital/corvette tokens;
- shield arcs and firing cones.

### Phase 3: Replace Runtime Visuals Carefully

Only after docs-only visual review should runtime promotion happen.

Promotion checklist:

- Source `.bbmodel` or generator spec kept.
- GLB validated.
- Godot import tested.
- Preview screenshot accepted by owner.
- License/provenance noted.
- Collision footprint decided.
- Scale and origin normalized.
- Runtime scene integration reviewed by Claude.

Suggested destination later, after owner approval:

```text
assets/3d/generated/blockcraft/
assets/3d/generated/blockcraft_private/
data/manifests/generated_asset_manifest.json
```

## Tool Lane By Asset Type

| Asset type | Primary lane | Secondary lane | Avoid |
| --- | --- | --- | --- |
| Clone/droid characters | Blockbench -> Blender -> GLB | human cleanup | Godot primitives as final |
| Ships | Blockbench -> Blender -> GLB | voxel/magica-style excursion, API concept | Godot JSON as default final |
| Buildings | Blockbench landmarks + normalized Kenney filler | Godot blockout | raw Kenney foreground landmarks |
| Weapons | Blockbench | Kenney kitbash reference | tiny realistic proportions |
| Props | Kenney/Blockbench | Godot procedural | over-modeling |
| Creatures | API/human -> normalized blockcraft | Blockbench simple creatures | raw AI mesh promoted directly |
| Space UI | Godot procedural | SVG concepts | baked UI into ship meshes |

## Immediate Next Iterations

1. Runtime camera test for kept GLBs.
   - Change only the camera/import context.
   - Keep geometry unchanged.
   - This answers whether current previews survive Godot.

2. Clone commander one-variable character pass.
   - Start from clone rifleman proportions.
   - Change only commander silhouette: pauldron, antenna/rangefinder-like original detail, color stripe.

3. Droid rifleman one-variable character pass.
   - Thin, tall, readable head/neck/backpack shape.
   - Distinct from clone body proportions.

4. Building doorway kit one-variable environment pass.
   - Use Kenney/Blockbench hybrid.
   - Test whether blockcraft buildings can still feel like Mos Eisley.

5. Weapon exaggeration pass.
   - One carbine, one pistol, one heavy weapon.
   - Use enlarged muzzle/scope/stock to prove weapons read in-hand.

## Main Risk

The main risk is not that we cannot make enough models. The main risk is that we make many models before the house style is proven in the real Godot camera. The current work should stay narrow until Phase 0 passes.

If Phase 0 passes, this pipeline can scale quickly because most models become variations on a cube grammar rather than fresh art problems.
