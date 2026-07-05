# Style Grammar: Chunky Space-Opera Frontier

## Core Bet

The fastest path to better visuals is not realism. It is a strict, repeatable style grammar that Codex/Claude can generate and review.

Target:

```text
Chunky low-poly Clone Wars frontier diorama.
Readable from MMO camera distance.
Simple enough to automate.
Specific enough to feel intentional.
```

## Visual Rules

### Shape Language

Ground:

- domes;
- squat cylinders;
- thick pipes;
- rectangular modular walls;
- stepped parapets;
- awnings;
- cargo blocks;
- vaporator towers;
- antenna masts;
- landing-pad slabs;
- cover barricades.

Space:

- chunky wedge ships;
- boxy freighters;
- broad wings;
- clear engine pods;
- rings and discs for sensors;
- asteroid clusters;
- isometric tactical grid;
- glow markers and selection rings.

### Palette

Use a tiny palette per zone.

Mos Eisley starter palette:

```text
sand_plaster     #b88d58
sun_bleached     #d2b37a
shadow_brown     #5b4631
dark_metal       #30343a
teal_accent      #1e8589
cyan_light       #25c4ff
awning_red       #bf3a20
dust_floor       #c89555
```

Space tactical palette:

```text
space_plane      #0b1724
grid_blue        #1765a8
player_blue      #3cc8ff
enemy_orange     #ff6a30
neutral_rock     #7a7170
nebula_violet    #684d9f
ship_white       #dbe8ed
ship_dark        #343a42
```

### Camera Rules

Ground MMO:

- elevated three-quarter camera for review renders;
- runtime may use third-person, but assets must read from above;
- cover silhouette must be clear;
- interactable clusters should be visible at 720p.

2.5D space:

- orthographic isometric camera;
- flat x/z tactical plane;
- never top-down flat;
- never cockpit;
- never true 6DOF promise unless the game actually supports it.

### Material Rules

Keep materials simple:

- flat albedo;
- high roughness;
- optional emission for lights;
- no noisy photoreal textures;
- no mixed-resolution texture chaos;
- no random downloaded PBR packs unless normalized.

### Scale Rules

Use grid-friendly sizes:

- small prop: 0.5 to 1.0 units;
- cover: 1.5 to 3.0 units wide;
- vendor stall: 3.0 to 5.0 units wide;
- starter building: 4.0 to 8.0 units wide;
- ship token: 1.5 to 4.0 units;
- tactical grid cell: 4.0 units in current review examples.

### Acceptance Checklist

An asset passes if:

- it reads clearly at 1280x720;
- it has fewer than 4 dominant colors;
- it has a clear gameplay role;
- it has a simple collision footprint;
- it matches the current house style;
- it does not rely on protected franchise geometry;
- it can be instanced many times cheaply;
- it has a generated preview capture.

## What To Avoid

- random style mixing;
- high-detail models next to toy-like models;
- realistic PBR textures on blocky assets;
- thin details that vanish at MMO camera distance;
- direct franchise silhouettes;
- "AI sludge" meshes with messy topology;
- unreviewed API output promoted directly into runtime.

