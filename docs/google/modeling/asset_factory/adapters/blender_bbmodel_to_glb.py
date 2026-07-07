"""Batch-convert Codex Blockbench .bbmodel cubes into GLB candidates.

Run with Blender in background mode:
  blender --background --python docs/gpt/asset_factory/adapters/blender_bbmodel_to_glb.py -- <bbmodel_dir> <out_dir>

This adapter intentionally handles the simple cube grammar emitted by
blockbench_cubecraft_factory.mjs. It is not a general Blockbench importer.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def args_after_double_dash() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def hex_to_rgba(value: str) -> tuple[float, float, float, float]:
    clean = str(value or "#d0d0d0").lstrip("#")
    if len(clean) == 3:
        clean = "".join(ch * 2 for ch in clean)
    if len(clean) != 6:
        clean = "d0d0d0"
    return (
        int(clean[0:2], 16) / 255.0,
        int(clean[2:4], 16) / 255.0,
        int(clean[4:6], 16) / 255.0,
        1.0,
    )


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
    bpy.context.scene.view_settings.view_transform = "Standard"
    bpy.context.scene.view_settings.look = "Medium High Contrast"
    bpy.context.scene.world.color = hex_to_rgba("#96acba")[:3]
    shading = bpy.context.scene.display.shading
    shading.color_type = "MATERIAL"
    shading.light = "STUDIO"
    shading.background_type = "VIEWPORT"
    shading.background_color = hex_to_rgba("#96acba")[:3]


def material_for(name: str, color_hex: str) -> bpy.types.Material:
    material = bpy.data.materials.new(name=f"codex_{name}")
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = hex_to_rgba(color_hex)
        bsdf.inputs["Roughness"].default_value = 0.82
        bsdf.inputs["Metallic"].default_value = 0.0
    material.diffuse_color = hex_to_rgba(color_hex)
    return material


def textured_material_for(name: str, texture_path: Path) -> bpy.types.Material:
    material = bpy.data.materials.new(name=f"codex_{name}")
    material.use_nodes = True
    material.use_backface_culling = False
    nodes = material.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        image = bpy.data.images.load(str(texture_path))
        tex_node = nodes.new("ShaderNodeTexImage")
        tex_node.image = image
        material.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.82
        bsdf.inputs["Metallic"].default_value = 0.0
    material.diffuse_color = (1.0, 1.0, 1.0, 1.0)
    return material


def bb_to_blender_point(point: list[float]) -> tuple[float, float, float]:
    # Blockbench/Godot are authored y-up. Blender is z-up.
    return (float(point[0]), float(point[2]), float(point[1]))


def add_cube(element: dict, materials: dict[str, bpy.types.Material]) -> None:
    src_from = [float(v) for v in element["from"]]
    src_to = [float(v) for v in element["to"]]
    center_bb = [(a + b) * 0.5 for a, b in zip(src_from, src_to)]
    size_bb = [max(0.001, abs(b - a)) for a, b in zip(src_from, src_to)]
    center = bb_to_blender_point(center_bb)
    dimensions = (size_bb[0], size_bb[2], size_bb[1])

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = element.get("name") or "cube"
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    while obj.data.uv_layers:
        obj.data.uv_layers.remove(obj.data.uv_layers[0])

    material_key = element.get("material_key", "default")
    material = materials.get(material_key)
    if material:
        obj.data.materials.append(material)


def add_plane(element: dict, materials: dict[str, bpy.types.Material]) -> None:
    src_from = [float(v) for v in element["from"]]
    src_to = [float(v) for v in element["to"]]
    x0, x1 = sorted([src_from[0], src_to[0]])
    y0, y1 = sorted([src_from[1], src_to[1]])
    z0, z1 = sorted([src_from[2], src_to[2]])
    plane = element.get("codex_plane") or {}
    axis = plane.get("axis", "z_min")
    z = z0 if axis == "z_min" else z1

    vertices = [
        bb_to_blender_point([x0, y0, z]),
        bb_to_blender_point([x1, y0, z]),
        bb_to_blender_point([x1, y1, z]),
        bb_to_blender_point([x0, y1, z]),
    ]
    mesh = bpy.data.meshes.new(element.get("name") or "plane")
    mesh.from_pydata(vertices, [], [(0, 1, 2, 3)])
    mesh.update()

    uv_layer = mesh.uv_layers.new(name="UVMap")
    uvs = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    for loop, uv in zip(mesh.polygons[0].loop_indices, uvs):
        uv_layer.data[loop].uv = uv

    obj = bpy.data.objects.new(element.get("name") or "plane", mesh)
    bpy.context.collection.objects.link(obj)

    material_key = element.get("material_key", "default")
    material = materials.get(material_key)
    if material:
        mesh.materials.append(material)


def scene_bounds() -> tuple[Vector, Vector]:
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    points = [
        obj.matrix_world @ Vector(corner)
        for obj in mesh_objects
        for corner in obj.bound_box
    ]
    if not points:
        return Vector((-1, -1, -1)), Vector((1, 1, 1))
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return minimum, maximum


def add_review_lighting_and_camera() -> None:
    minimum, maximum = scene_bounds()
    center = (minimum + maximum) * 0.5
    extents = maximum - minimum
    scale = max(8.0, extents.x, extents.y, extents.z * 1.25)
    direction = Vector((1.35, -1.75, 1.25)).normalized()

    bpy.ops.object.light_add(type="AREA", location=center + Vector((0, -6, scale * 1.7)))
    light = bpy.context.object
    light.name = "review_area_light"
    light.data.energy = 350
    light.data.size = 7

    camera_location = center + direction * scale * 2.2
    bpy.ops.object.camera_add(location=camera_location)
    camera = bpy.context.object
    camera.name = "review_isometric_camera"
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = scale * 1.75
    bpy.context.scene.camera = camera


def render_preview(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.resolution_x = 720
    bpy.context.scene.render.resolution_y = 520
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def select_meshes_only() -> None:
    bpy.ops.object.select_all(action="DESELECT")
    first = None
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.select_set(True)
            first = first or obj
    if first:
        bpy.context.view_layer.objects.active = first


def convert_one(bbmodel_path: Path, out_dir: Path) -> dict:
    model = json.loads(bbmodel_path.read_text(encoding="utf-8-sig"))
    reset_scene()

    palette = model.get("codex_palette") or {}
    materials = {
        key: material_for(key, color)
        for key, color in palette.items()
    }
    if "default" not in materials:
        materials["default"] = material_for("default", "#d0d0d0")

    texture_materials = model.get("codex_texture_materials") or {}
    for key, rel_path in texture_materials.items():
        texture_path = (bbmodel_path.parent / str(rel_path)).resolve()
        if texture_path.exists():
            materials[key] = textured_material_for(key, texture_path)
        else:
            print(f"WARNING: texture material {key} missing image {texture_path}")

    for element in model.get("elements", []):
        if element.get("codex_plane"):
            add_plane(element, materials)
        else:
            add_cube(element, materials)

    add_review_lighting_and_camera()
    preview_path = out_dir / "previews" / f"{bbmodel_path.stem}.png"
    render_preview(preview_path)

    out_path = out_dir / f"{bbmodel_path.stem}.glb"
    select_meshes_only()
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
    )

    return {
        "id": bbmodel_path.stem,
        "source_bbmodel": str(bbmodel_path).replace("\\", "/"),
        "glb_path": str(out_path).replace("\\", "/"),
        "blender_preview_path": str(preview_path).replace("\\", "/"),
        "element_count": len(model.get("elements", [])),
    }


def main() -> None:
    args = args_after_double_dash()
    if len(args) != 2:
        raise SystemExit(
            "Usage: blender --background --python blender_bbmodel_to_glb.py -- <bbmodel_dir> <out_dir>"
        )

    bbmodel_dir = Path(args[0]).resolve()
    out_dir = Path(args[1]).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    bbmodels = sorted(bbmodel_dir.glob("*.bbmodel"))
    if not bbmodels:
        raise SystemExit(f"No .bbmodel files found in {bbmodel_dir}")

    converted = [convert_one(path, out_dir) for path in bbmodels]
    manifest = {
        "adapter": "docs/gpt/asset_factory/adapters/blender_bbmodel_to_glb.py",
        "source_dir": str(bbmodel_dir).replace("\\", "/"),
        "output_dir": str(out_dir).replace("\\", "/"),
        "asset_count": len(converted),
        "assets": converted,
    }
    (out_dir / "glb_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Converted {len(converted)} Blockbench models to GLB in {out_dir}")


if __name__ == "__main__":
    main()
