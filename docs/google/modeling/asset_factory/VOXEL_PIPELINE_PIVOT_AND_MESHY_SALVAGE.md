# Voxel Pipeline Pivot and Meshy Salvage

Date: 2026-07-04  
Scope: current recommendation after Meshy, pixel-extrude, and pixel-hull tests

## Short Answer

The owner is not missing something obvious.

For this project, Meshy is probably not the core asset generator if the target remains "Star Wars Minecraft" rather than PS1/low-poly space opera.

The better pivot is:

```text
Core look:
  deterministic voxel/blockcraft geometry

Main tools:
  Godot pixel/card extrusion
  Blockbench
  Godot GridMap/review scenes

Supporting tools:
  Meshy for concept/reference/background/distant/non-grid work
  Vengi/voxel editors/converters for manual cleanup and .vox handoff
```

Do not pivot to PS1 unless the owner actually likes that aesthetic. It would make Meshy easier to use, but it would drift from the original hope.

## Why Meshy Is Fighting The Target

Observed local evidence:

- Meshy lowpoly text prompts produced clean GLBs but not true cube-grid models.
- Stricter "voxel/cuboid/Minecraft-like" wording made the result more cuboid but also bland.
- Meshy 5 preview was cheap and more interesting, but still soft/continuous and not cubecraft-authored.
- Meshy refine solved texture import, not voxel-grid geometry.
- The Meshy ship prompt became a ground-skiff/vehicle seed rather than a clean tactical starfighter.

This aligns with the general tool split:

```text
AI 3D mesh generation -> continuous triangle mesh
Minecraft/Blockbench/voxel art -> discrete grid/cuboid grammar
```

Meshy can imitate "blocky." It does not reliably obey "one cube belongs at this exact grid coordinate."

## What The New Proofs Show

### Pixel Extrude

Proof:

```text
PIXEL_EXTRUDE_GODOT_PASS.md
generated/godot_pixel_extrude_v0/REVIEW.md
```

Result:

```text
Candidate keep for strict voxel props and tactical tokens.
```

This method is deterministic:

```text
one source pixel or source pixel run -> one cube or rectangular voxel bar
```

It worked best for:

- wall terminal;
- tactical ship token;
- pickup-scale weapon silhouette.

Same-color run merge is probably the production default. It preserved the source silhouette while reducing object count:

| Source | Per-pixel cubes | Run-merged boxes |
| --- | ---: | ---: |
| 32x16 blaster | 146 | 32 |
| 32x32 ship | 322 | 94 |

### Pixel Hull Character

Proof:

```text
generated/godot_pixel_hull_character_v0/REVIEW.md
```

Result:

```text
Candidate research keep.
```

This method uses:

```text
front source card + side source card -> voxel visual hull
```

It proves the "flat card, but more 3D" idea. It is not good enough as final character production yet, because a whole-body hull lacks part boundaries for animation and clean proportions.

Best next version:

```text
front/side cards per body part
  -> head hull
  -> torso hull
  -> upper/lower arm hulls
  -> leg hulls
  -> backpack/weapon hulls
  -> animate as rigid voxel bones
```

That preserves deterministic geometry and gives us a path toward walk/shoot/take-cover animation without asking AI 3D to invent topology.

## Where Meshy Still Has Value

Meshy should not be thrown away. It should move to supporting roles.

### 1. Background And Matte Art

Use Meshy outputs for things players do not inspect closely:

- distant space hulks;
- far-off settlement silhouettes;
- skyline clutter;
- hangar background ships;
- asteroid/station props rendered into 2D cards;
- scene mood references.

Workflow:

```text
Meshy model or thumbnail
  -> render/screenshot
  -> downscale/dither/pixelate if needed
  -> use as distant billboard/background/reference only
```

Do not use this for foreground interactive assets unless it passes the same style proof.

### 2. Greeble And Shape Reference

Meshy is useful at inventing irregular sci-fi detail:

- pipes;
- engine clusters;
- junk piles;
- terminals;
- industrial panels;
- weird machinery.

Workflow:

```text
Meshy preview
  -> provider thumbnail + Godot proof
  -> extract silhouette/greeble lessons
  -> rebuild as Blockbench or pixel-extrude grammar
```

This spends credits on concept exploration, not final runtime geometry.

### 3. Texture Mood Reference

The refine test proved Meshy can generate textures that import into Godot.

Use it for:

- grime/color studies;
- desert plaster mood;
- metal wear pattern ideas;
- distant/non-grid props.

Do not use refine as a way to "fix" geometry that already failed.

### 4. Image-To-3D With Our Own Cards

Meshy Image to 3D supports `image_url` as a public URL or data URI, and supports `.jpg`, `.jpeg`, and `.png`. It can also use `texture_image_url` for texturing guidance. That means we can test our own blockcraft source cards without hosting files.

But this is still AI mesh generation:

```text
our source card -> Meshy continuous mesh
```

It is worth exactly one controlled test later:

```text
same original pixel/source card
  -> Godot pixel-extrude result
  -> Meshy image-to-3D result
  -> Godot side-by-side
```

If Meshy wins visually without losing style, keep the lane. If it melts the grid, reject it cleanly.

### 5. Bonus-Credit Tasks

If onboarding bonus tasks are still available, use them only when they answer real questions:

- Image to 3D: test one original blockcraft source card.
- Remesh: test one promising but messy Meshy background/prop.
- Animation: only after we have a stable voxel body-part rig contract.
- Free retry: use manually in the web UI on a promising failed Meshy result, not via API.

## Other Tools To Consider

### Keep Blockbench

Blockbench remains the strongest known foreground identity tool. Its own site describes it as a low-poly model editor, explicitly supports cuboids for the Minecraft aesthetic, includes texture tools, and has an animation editor. It is also free/open source.

Use it for:

- hero characters;
- droids;
- weapons after a pixel-card silhouette is approved;
- ships when 3D form matters more than top-down token readability;
- animated rigid-part models.

### Add Godot GridMap For World Blocks

Godot `GridMap` is built for 3D tile-based maps, with grid cells referencing meshes from a `MeshLibrary`. That matches modular voxel buildings and terrain chunks.

Use it for:

- settlement wall/roof/floor kits;
- Cantina modular room blockouts;
- cover systems;
- interior dressing placement;
- runtime/editor placement tools.

This is not a modeling tool. It is a placement/runtime integration tool.

### Evaluate Goxel Or MagicaVoxel For Manual Voxel Art

Goxel is an open-source voxel editor and exports formats including glTF2, OBJ, MagicaVoxel, and Qubicle. It is worth testing if a human wants a direct voxel editor.

MagicaVoxel is also worth evaluating for human-authored voxel art and rendering, but it is less obviously scriptable for our current automated lane.

Use these only if they improve the workflow:

```text
artist/manual voxel polish
  -> export GLB/VOX/OBJ
  -> Godot proof
```

Do not add them just to add tools.

### Use Vengi As A Bridge, Not A Default Yet

Vengi is now installed locally:

```text
C:\Program Files\vengi
```

Useful binaries:

```text
C:\Program Files\vengi\voxconvert\vengi-voxconvert.exe
C:\Program Files\vengi\voxedit\vengi-voxedit.exe
```

Proof:

```text
VENGI_PIXEL_CARD_EVAL_PASS.md
generated/vengi_pixel_card_eval_v0/REVIEW.md
```

Current verdict:

```text
Candidate bridge keep.
```

Vengi can convert our project-owned PNG source cards to `.vox` and flat GLB. This is useful if a human wants to open the result in a voxel editor and clean it up manually.

It does not replace Godot pixel extrusion yet. In the first proof, Godot run-merged extrusion looked more like the intended cube-bar asset than Vengi's successful flat GLB path. The Vengi image-volume and `.bbmodel` conversion probes hung and were stopped, so those need a separate focused adapter/debug pass before becoming production routes.

### Pixel Editors

Aseprite is a strong paid pixel-art tool with animation, layers, sprite sheets, texture atlas support, and a CLI. LibreSprite is GPL and free.

For our purposes, a pixel editor is useful if the owner or Claude wants to author source cards manually:

```text
pixel card -> Godot extrusion -> capture
```

Codex can also generate the source cards programmatically, so a pixel editor is helpful but not required.

## Recommended Production Split

| Asset family | Default lane | Meshy role |
| --- | --- | --- |
| Pickup items | Pixel card -> run-merge Godot extrusion | Reference only |
| Signs/decals/terminals | Pixel card -> run-merge Godot extrusion | Texture/mood reference |
| Tactical ship tokens | Pixel top-card -> run-merge extrusion or Blockbench | Silhouette idea only |
| Foreground ships | Blockbench -> GLB -> Godot proof | Option-mining/greeble reference |
| Characters/NPCs | Blockbench rigid parts; pixel-hull research lane | Maybe reference/animation experiment later |
| Droids | Blockbench or pixel-hull if simple | Shape reference |
| Buildings/rooms | Godot GridMap/blockout + Blockbench identity modules | Background facade/mood reference |
| Space backgrounds | 2D matte/billboard, rendered scene, or generated bitmap | Strong candidate use |
| Organic creatures | Meshy or human concept -> rebuild/normalize | Strong candidate use |
| Manual voxel cleanup | Vengi `.vox` bridge after a project source card | Not needed |

## What To Do Next

Do not spend more Meshy credits immediately.

Run the deterministic voxel lane one step further:

1. Convert the pixel-extrude proof into a reusable request format.
2. Add a real requested item: blaster pickup or datapad pickup.
3. Add a body-part pixel-hull proof for a low-detail trooper:
   - head;
   - torso;
   - upper arms;
   - lower arms;
   - legs;
   - weapon;
   - backpack.
4. Compare that to the current Blockbench clone baseline.
5. Use Vengi only as a `.vox` handoff/manual cleanup bridge unless a focused volume-conversion test beats Godot extrusion.
6. Only then test one Meshy image-to-3D call using the same original source card.

## Current Position

Recommendation:

```text
Commit to voxel/blockcraft.
Do not pivot to PS1.
Treat Meshy as a supporting tool, not the core generator.
Scale the deterministic pixel/card/Blockbench/Godot lanes.
```

That is not wasting Meshy access. It is using Meshy where it is strongest and avoiding it where it fights the math.
