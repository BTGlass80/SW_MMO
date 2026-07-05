# Mos Eisley Visual Rebuild Guidance - 2026-07-05

## Verdict

The authored Mos Eisley currently reads as a debug blockout, not a release-worthy Star Wars location. The issue is not one bad asset. It is a stack of art-direction, scale, composition, and test-boundary problems.

Current captures reviewed:

- `captures/playtest/playtest_1_outside.png`
- `captures/playtest/playtest_2_inside_entrance.png`
- `captures/playtest/playtest_3_inside_bar.png`
- `captures/playtest/playtest_4_back_hallway.png`

The scene looks bad because it is trying to be too many things at once: a tiny docking-row prototype, a giant CSG cantina, a dev asset gallery, a combat HUD testbed, and a generated-prop showcase. It needs to become one coherent first-person place.

## Highest-Priority Fixes

### 1. Remove Test Gallery Contamination

`scripts/world/main.gd` currently calls:

```gdscript
_builder.build_asset_library(self)
```

That should not run in the authored Mos Eisley play space. Move the asset library to its own scene or behind an explicit dev-only command-line flag. A production/private-alpha Mos Eisley should never contain `Voxel Exhibition Gallery`, wing labels, display pedestals, or generated asset showcase language.

Keep a separate `scenes/asset_gallery.tscn` or `--asset-gallery` mode if the generated assets still need review.

### 2. Rebuild Scale Around the Player

The cantina plaza is wildly oversized:

- plaza floor: `110m x 110m`,
- main dome radius: `29.5m`,
- giant label over the door,
- interior ceiling/CSG surfaces visually collapse into flat planes.

For a first-person MMO slice, the player needs readable 2m-to-8m detail, not a 59m diameter sand wedge. Resize the cantina into a believable local landmark:

- main cantina footprint: roughly 18m-24m wide, not 59m,
- entrance height: 2.6m-3.2m,
- interior ceiling: high enough to clear the camera, but not an empty aircraft hangar,
- side huts: 4m-7m, arranged as support structures, not massive siblings.

The correct goal is "recognizable Mos Eisley street corner," not "epic landmark."

### 3. Stop Using Floating Place Labels as Art

The current `Label3D` signs make the world feel like a greybox:

- `Spaceport Row`
- `Docking Bay 94`
- `Docking Bay 86`
- `Mos Eisley Cantina`
- `[NO DROIDS]`
- gallery wing labels

Replace most world labels with physical signage or HUD inspection text. A location can have a small in-world sign, but big billboard text should be reserved for debug mode.

Suggested rule:

- no default-visible `Label3D` for place names in release play,
- optional debug labels behind `--debug-world-labels`,
- diegetic signs should be meshes: hanging placards, painted wall panels, docking bay numbers, Aurebesh-ish striping, warning lamps.

### 4. Make the Exterior Street First

The current `build_settlement()` is a flat rectangular road with isolated boxes. Before expanding interiors, make one exterior route feel good:

- player starts at Bay 94,
- sees a narrow dusty street with silhouettes on both sides,
- can identify Customs, Speeders, Transport Depot, control tower, and cantina by shape,
- has cover/props/market clutter that guide walking paths,
- reaches the cantina as a visible destination.

Use the SW_MUSH room data as layout intent, not as literal labels. The visual build should turn rooms/exits into a walkable district with:

- street edges,
- door recesses,
- awnings,
- stairs/ramps into bays,
- pipes/cables,
- dust breaks,
- shade structures,
- vendor stalls,
- docking bay walls, not just pads on a plane.

### 5. Replace the Mega-CSG Cantina With Modular Pieces

The current CSG dome creates ugly clipping/flat-plane shots and is too hard to art-direct. Prefer modular primitive/mesh pieces:

- circular or octagonal wall segments,
- separate dome cap mesh,
- cutout doorway built from actual arch pieces,
- interior walls as visible surfaces, not subtraction artifacts,
- separate collision from visual mesh.

The smoke test should not require CSG. It should verify the presence of readable modules: entrance arch, bar, booths, stage, back alcove, exit path.

### 6. Fix Interior Composition

The current interior has a central block bar, huge empty floor, wall-plane domination, and unreadable nameplates. Rebuild it around camera-height sightlines:

- entry vestibule with a low ceiling and turn, then reveal the bar,
- central bar lower and wider, with a recognizable counter silhouette,
- booths around the perimeter with repeated warm lamps,
- bandstand tucked to one side,
- a few NPC anchor points, each with local light/prop context,
- no giant overhead label visible inside.

Every visual playtest capture should have a foreground, midground, and background. If a capture is mostly one flat wall or one tan polygon, it fails.

### 7. Treat Generated Assets as Ingredients, Not Decorations

The generated voxel actors/props can help, but right now they are dropped in as trophies. Curate them into the scene only where they support the Mos Eisley loop:

- moisture vaporators outside,
- landing lights in docking bays,
- barriers around range/combat areas,
- droids/officers/vendors at authored posts,
- weapons only in shops or on characters.

Do not place high-fidelity generated props next to crude primitive mega-geometry until their scale, palette, and silhouette match.

### 8. Reduce HUD Interference in Visual Captures

The automated visual playtest captures include the full gameplay HUD, which hides the scene and makes review harder. Add a capture-only mode:

- hide HUD panels,
- keep only a tiny crosshair or no UI,
- use fixed camera FOV,
- save before/after thumbnails.

The release review should inspect clean environment captures, plus one gameplay-HUD capture separately.

## Implementation Plan

### Pass A - Triage Cleanup

1. Remove `build_asset_library()` from normal `main.gd`.
2. Add `--debug-world-labels`; hide location `Label3D` by default.
3. Reduce or temporarily disable `build_cantina_plaza()` in `net_world.gd` and `main.gd` until scale is fixed.
4. Update visual captures to hide HUD.

Acceptance: screenshots no longer show gallery labels, giant floating place names, or HUD panels covering the focal subject.

### Pass B - Spaceport Row Rebuild

1. Make `mos_eisley_spaceport_row.json` drive room footprints and exits.
2. Replace flat pads with bay walls, ramps, doors, numbers, equipment clusters.
3. Add street-edge language: facades, shade cloths, cables, stairs, signs, vendor pockets.
4. Keep all gameplay collision simple and deterministic.

Acceptance: standing at Bay 94, the player can visually understand where to walk and what each nearby place is without billboard labels.

### Pass C - Cantina Rebuild

1. Scale the cantina down.
2. Replace the CSG mega-dome with modular dome/wall/arch pieces.
3. Rebuild the interior as a compact route: entry, reveal, bar, booths, stage, back alcove.
4. Place named NPCs intentionally instead of letting labels cluster.

Acceptance: four clean captures show recognizable exterior, entrance, bar, and alcove views with no flat-wall-dominant shots.

### Pass D - Visual Gate

Do not let smokes reward raw node count. Add simple visual/readability checks:

- capture files exist and are non-empty,
- HUD-hidden capture mode works,
- no release-mode `Label3D` with known debug/place text,
- asset gallery absent from normal world,
- landmark scale constants stay inside documented bounds.

Keep the existing deterministic-builder tests, but stop treating "many mesh instances" as proof of visual quality.

## Specific Code Targets

- `scripts/world/main.gd`: remove or flag `build_asset_library()`.
- `scripts/net/net_world.gd`: same world composition should use the cleaned authored settlement.
- `scripts/world/world_builder.gd`: split production settlement from debug/gallery helpers.
- `scripts/world/landmark_builder.gd`: replace mega-scale CSG cantina with player-scale modular construction.
- `scripts/tests/visual_playtest_runner.gd`: add no-HUD capture mode and better camera positions.
- `scripts/tests/world_builder_smoke.gd`: assert asset gallery is absent in normal play.
- `scripts/tests/landmark_builder_smoke.gd`: assert scale/readability constraints, not just mesh count.

## Tone Target

Aim for "dusty, compact, legible Clone Wars Mos Eisley street slice." It should feel like a functional MMO hub where players can move, trade, talk, and fight nearby. Avoid theme-park labels, giant empty plazas, showcase galleries, and monolithic tan geometry.
