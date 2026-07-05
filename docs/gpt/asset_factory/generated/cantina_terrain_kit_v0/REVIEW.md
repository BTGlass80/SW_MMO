# Cantina Terrain Kit V0 Review Board

Generated: 2026-07-04 02:14:24
Generator: `docs/gpt/asset_factory/scripts/godot_asset_factory.gd`
Spec pack: `cantina_terrain_kit_v0`

## What This Is

These images are captures from generated Godot `.tscn` scenes, not bitmap source art. The source scenes are in `scenes/`; the review camera scenes are in `review_scenes/`.

Pipeline:

```text
JSON spec -> Godot procedural scene -> review scene -> PNG capture -> approve/reject/polish
```

## Contact Sheets

![All assets](captures/contact_sheet_all.png)

![Ground assets](captures/contact_sheet_ground.png)

![Isometric space assets](captures/contact_sheet_space.png)

![Character assets](captures/contact_sheet_characters.png)

![Scene slice assets](captures/contact_sheet_scene_slices.png)

## Individual Captures

| Asset | Category | Gameplay Role | Capture |
| --- | --- | --- | --- |
| Cantina Entrance Threshold 01 | terrain_module | elevated no-droids entrance threshold | ![Cantina Entrance Threshold 01](captures/assets/cantina_entrance_threshold_01.png) |
| Cantina Bar Booth Bay 01 | terrain_module | main bar wall and curved booth-ring read | ![Cantina Bar Booth Bay 01](captures/assets/cantina_bar_booth_bay_01.png) |
| Cantina Bandstand Corner 01 | terrain_module | music/bandstand identity corner | ![Cantina Bandstand Corner 01](captures/assets/cantina_bandstand_corner_01.png) |
| Cantina Back Hallway Service 01 | terrain_module | back hallway with restrooms, cellar trapdoor, and curtained office | ![Cantina Back Hallway Service 01](captures/assets/cantina_back_hallway_service_01.png) |
| Cantina Multiroom Slice 01 | scene_slice | one-screen proof of outside -> entrance -> bar -> back hallway readability | ![Cantina Multiroom Slice 01](captures/assets/cantina_multiroom_slice_01.png) |
| Cantina Exterior Plaza Slice 01 | scene_slice | outside approach and social doorstep terrain | ![Cantina Exterior Plaza Slice 01](captures/assets/cantina_exterior_plaza_slice_01.png) |

## Review Tags

- `accept-prototype`: good enough to test in gameplay.
- `needs-style-pass`: useful silhouette but ugly detail/materials.
- `needs-remodel`: concept is useful, geometry is not.
- `api-candidate`: worth trying through a 3D generation provider.
- `human-candidate`: too important or too hard for procedural generation.
