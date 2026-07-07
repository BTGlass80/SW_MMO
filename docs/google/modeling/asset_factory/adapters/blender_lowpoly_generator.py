#!/usr/bin/env python3
"""Draft Blender adapter for the GPT Asset Factory.

Run with Blender, not normal Python:

  blender --background --python blender_lowpoly_generator.py -- \
    --spec ../specs/mos_eisley_chunky_v0.json \
    --out ../generated/blender_glb

This was not executed in the current session because Blender was not available in PATH.
It is included as a concrete next step for a free GLB-producing lane.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

try:
	import bpy
except Exception as exc:  # pragma: no cover - only available inside Blender
	raise SystemExit("This script must be run inside Blender: %s" % exc)


PALETTE = {
	"sand_plaster": (0.72, 0.55, 0.34, 1.0),
	"sun_bleached": (0.82, 0.70, 0.48, 1.0),
	"shadow_brown": (0.36, 0.27, 0.19, 1.0),
	"dark_metal": (0.19, 0.20, 0.23, 1.0),
	"teal_accent": (0.12, 0.52, 0.54, 1.0),
	"cyan_light": (0.14, 0.77, 1.0, 1.0),
	"awning_red": (0.75, 0.23, 0.13, 1.0),
	"dust_floor": (0.78, 0.58, 0.33, 1.0),
	"ship_white": (0.86, 0.91, 0.93, 1.0),
	"ship_dark": (0.20, 0.23, 0.26, 1.0),
	"enemy_orange": (1.0, 0.42, 0.18, 1.0),
	"player_blue": (0.24, 0.78, 1.0, 1.0),
	"neutral_rock": (0.48, 0.44, 0.42, 1.0),
}


def parse_args() -> argparse.Namespace:
	argv = sys.argv
	if "--" in argv:
		argv = argv[argv.index("--") + 1:]
	else:
		argv = []
	parser = argparse.ArgumentParser()
	parser.add_argument("--spec", required=True)
	parser.add_argument("--out", required=True)
	return parser.parse_args(argv)


def clear_scene() -> None:
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete()


def material(name: str):
	mat_name = "af_" + name
	if mat_name in bpy.data.materials:
		return bpy.data.materials[mat_name]
	mat = bpy.data.materials.new(mat_name)
	mat.use_nodes = True
	color = PALETTE.get(name, (0.8, 0.8, 0.8, 1.0))
	bsdf = mat.node_tree.nodes.get("Principled BSDF")
	if bsdf:
		bsdf.inputs["Base Color"].default_value = color
		bsdf.inputs["Roughness"].default_value = 0.88
	return mat


def add_box(part: dict) -> None:
	size = part.get("size", [1, 1, 1])
	pos = part.get("position", [0, 0, 0])
	rot = part.get("rotation_degrees", [0, 0, 0])
	bpy.ops.mesh.primitive_cube_add(size=1, location=pos, rotation=[math.radians(v) for v in rot])
	obj = bpy.context.object
	obj.name = part.get("name", "box")
	obj.dimensions = size
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	obj.data.materials.append(material(part.get("material", "sand_plaster")))


def add_cylinder(part: dict) -> None:
	radius = float(part.get("radius", 0.5))
	depth = float(part.get("height", 1.0))
	verts = int(part.get("segments", 12))
	pos = part.get("position", [0, 0, 0])
	rot = part.get("rotation_degrees", [0, 0, 0])
	bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=pos, rotation=[math.radians(v) for v in rot])
	obj = bpy.context.object
	obj.name = part.get("name", "cylinder")
	obj.data.materials.append(material(part.get("material", "sand_plaster")))


def add_uv_sphere(part: dict) -> None:
	radius = float(part.get("radius", 0.5))
	pos = part.get("position", [0, 0, 0])
	scale = part.get("scale", [1, 1, 1])
	bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=pos)
	obj = bpy.context.object
	obj.name = part.get("name", "sphere")
	obj.scale = scale
	obj.data.materials.append(material(part.get("material", "sand_plaster")))


def build_asset(asset: dict, out_dir: Path) -> None:
	clear_scene()
	for part in asset.get("parts", []):
		shape = part.get("shape", "box")
		if shape == "box":
			add_box(part)
		elif shape == "cylinder":
			add_cylinder(part)
		elif shape in ("sphere", "dome"):
			add_uv_sphere(part)
		else:
			print("Skipping unsupported shape:", shape)

	out_dir.mkdir(parents=True, exist_ok=True)
	out_path = out_dir / ("%s.glb" % asset["id"])
	bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB")
	print("Wrote", out_path)


def main() -> None:
	args = parse_args()
	spec = json.loads(Path(args.spec).read_text(encoding="utf-8"))
	out_dir = Path(args.out)
	for asset in spec.get("assets", []):
		build_asset(asset, out_dir)


if __name__ == "__main__":
	main()

