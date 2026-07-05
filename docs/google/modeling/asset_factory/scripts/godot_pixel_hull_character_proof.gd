extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_pixel_hull_character_v0"
const SOURCE_DIR := OUT_ROOT + "/source_images"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"

const CELL := 0.095
const DEPTH := 0.095

var _captures: Array[Dictionary] = []
var _source_paths := {
	"front": SOURCE_DIR + "/trooper_front_card_16x28.png",
	"side": SOURCE_DIR + "/trooper_side_card_10x28.png",
}
var _stats: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	_generate_source_cards()
	await _save_and_capture(
		"pixel_hull_source_cards",
		_build_source_card_scene(),
		"Original project-owned front and side pixel cards used as deterministic volume masks. No external art source."
	)
	await _save_and_capture(
		"pixel_hull_flat_vs_volume",
		_build_flat_vs_volume_scene(),
		"Same front card. Left: flat front extrusion. Right: front+side visual hull with z-run merged voxels."
	)
	await _save_and_capture(
		"pixel_hull_trooper_three_quarter",
		_build_three_quarter_scene(),
		"Three-quarter Godot camera proof for a deterministic front+side pixel-card humanoid volume."
	)
	await _save_and_capture(
		"pixel_hull_trooper_rotation_contact_sheet",
		_build_rotation_sheet_scene(),
		"Rotation contact sheet at 0, 90, 180, and 270 degree yaw. This checks whether the visual-hull character has real 3D volume or just a paper cutout."
	)
	_write_manifest()
	_write_review()
	print("Godot pixel-hull character proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SOURCE_DIR, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _generate_source_cards() -> void:
	var front := Image.create_empty(16, 28, false, Image.FORMAT_RGBA8)
	front.fill(Color(0, 0, 0, 0))
	_draw_front_card(front)
	_save_image(front, _source_paths["front"])

	var side := Image.create_empty(10, 28, false, Image.FORMAT_RGBA8)
	side.fill(Color(0, 0, 0, 0))
	_draw_side_card(side)
	_save_image(side, _source_paths["side"])


func _draw_front_card(image: Image) -> void:
	var armor := Color("#e8ece5")
	var armor_shadow := Color("#aeb5b0")
	var dark := Color("#15191d")
	var visor := Color("#0f1d28")
	var blue := Color("#2aa7d7")
	var tan := Color("#b68a53")

	_fill_rect(image, 5, 1, 6, 5, armor)
	_fill_rect(image, 4, 3, 8, 4, armor)
	_fill_rect(image, 5, 4, 6, 2, visor)
	_fill_rect(image, 7, 1, 2, 3, blue)
	_fill_rect(image, 6, 7, 4, 7, armor)
	_fill_rect(image, 5, 8, 6, 5, armor_shadow)
	_fill_rect(image, 7, 8, 2, 6, blue)
	_fill_rect(image, 3, 8, 2, 8, armor)
	_fill_rect(image, 11, 8, 2, 8, armor)
	_fill_rect(image, 2, 12, 2, 7, dark)
	_fill_rect(image, 12, 12, 2, 7, dark)
	_fill_rect(image, 6, 14, 2, 10, armor)
	_fill_rect(image, 8, 14, 2, 10, armor)
	_fill_rect(image, 5, 23, 3, 3, dark)
	_fill_rect(image, 8, 23, 3, 3, dark)
	_fill_rect(image, 13, 13, 2, 8, tan)
	_fill_rect(image, 14, 12, 1, 8, dark)


func _draw_side_card(image: Image) -> void:
	var armor := Color("#e8ece5")
	var armor_shadow := Color("#aeb5b0")
	var dark := Color("#15191d")
	var visor := Color("#0f1d28")
	var blue := Color("#2aa7d7")
	var tan := Color("#b68a53")

	_fill_rect(image, 3, 1, 4, 5, armor)
	_fill_rect(image, 2, 3, 6, 4, armor)
	_fill_rect(image, 2, 4, 5, 2, visor)
	_fill_rect(image, 6, 2, 2, 4, armor_shadow)
	_fill_rect(image, 4, 1, 1, 3, blue)
	_fill_rect(image, 3, 7, 4, 7, armor)
	_fill_rect(image, 5, 8, 3, 5, armor_shadow)
	_fill_rect(image, 1, 8, 3, 8, armor)
	_fill_rect(image, 0, 12, 2, 6, dark)
	_fill_rect(image, 7, 8, 2, 9, tan)
	_fill_rect(image, 8, 13, 1, 8, dark)
	_fill_rect(image, 3, 14, 2, 10, armor)
	_fill_rect(image, 5, 14, 2, 10, armor_shadow)
	_fill_rect(image, 2, 23, 3, 3, dark)
	_fill_rect(image, 5, 23, 3, 3, dark)


func _build_source_card_scene() -> Node3D:
	var root := _base_scene("PixelHullSourceCards")
	var front := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["front"]))
	var side := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["side"]))
	_extrude_front_card(root, front, "front_card_display", Vector3(-0.9, 1.25, 0), CELL * 1.6, CELL * 0.45)
	_extrude_front_card(root, side, "side_card_display", Vector3(0.9, 1.25, 0), CELL * 1.6, CELL * 0.45)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(3.6, 0.08, 2.0), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 1.18, 0), 3.0)
	return root


func _build_flat_vs_volume_scene() -> Node3D:
	var root := _base_scene("PixelHullFlatVsVolume")
	var front := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["front"]))
	var side := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["side"]))
	var flat := _extrude_front_card(root, front, "flat_front_extrude", Vector3(-0.85, 1.25, 0), CELL, CELL * 1.2)
	flat.rotation_degrees = Vector3(0, -18, 0)
	var volume := _visual_hull_z_runs(root, front, side, "front_side_visual_hull", Vector3(0.85, 0.04, 0), CELL)
	volume.rotation_degrees = Vector3(0, -22, 0)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(3.6, 0.08, 2.2), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 1.05, 0), 3.7)
	return root


func _build_three_quarter_scene() -> Node3D:
	var root := _base_scene("PixelHullTrooperThreeQuarter")
	var front := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["front"]))
	var side := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["side"]))
	var volume := _visual_hull_z_runs(root, front, side, "trooper_visual_hull", Vector3(0, 0.04, 0), CELL)
	volume.rotation_degrees = Vector3(0, -28, 0)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(2.4, 0.08, 2.2), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 1.05, 0), 2.8)
	return root


func _build_rotation_sheet_scene() -> Node3D:
	var root := _base_scene("PixelHullTrooperRotationContactSheet")
	var front := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["front"]))
	var side := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["side"]))
	var rotations := [0, 90, 180, 270]
	for i in range(rotations.size()):
		var offset := Vector3((float(i) - 1.5) * 1.45, 0.04, 0)
		var volume := _visual_hull_z_runs(root, front, side, "trooper_visual_hull_yaw_%s" % rotations[i], offset, CELL * 0.9)
		volume.rotation_degrees = Vector3(0, rotations[i], 0)
		_add_floor(root, offset + Vector3(0, -0.08, 0), Vector3(1.15, 0.06, 1.15), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.95, 0), 5.8)
	return root


func _extrude_front_card(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, depth: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	root.add_child(holder)
	var count := 0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		var x := 0
		while x < width:
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				x += 1
				continue
			var run_start := x
			var key := color.to_html(true)
			while x < width and image.get_pixel(x, y).a > 0.05 and image.get_pixel(x, y).to_html(true) == key:
				x += 1
			var run_length := x - run_start
			var px := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(width - 1) / 2.0) * cell
			var py := (float(height - 1 - y) - float(height - 1) / 2.0) * cell
			var cube := _new_box("%s_run_%s_%s" % [node_name, run_start, y], Vector3(px, py, 0), Vector3(float(run_length) * cell, cell, depth), color)
			holder.add_child(cube)
			count += 1
	_stats[node_name] = {
		"pixels": width * height,
		"boxes": count,
		"mode": "front_card_same_color_horizontal_runs"
	}
	return holder


func _visual_hull_z_runs(root: Node3D, front: Image, side: Image, node_name: String, origin: Vector3, cell: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	root.add_child(holder)
	var count := 0
	var raw_voxels := 0
	var width := front.get_width()
	var height := front.get_height()
	var depth := side.get_width()
	for y in range(height):
		for x in range(width):
			var front_color := front.get_pixel(x, y)
			if front_color.a <= 0.05:
				continue
			var z := 0
			while z < depth:
				var side_color := side.get_pixel(z, y)
				if side_color.a <= 0.05:
					z += 1
					continue
				var run_start := z
				while z < depth and side.get_pixel(z, y).a > 0.05:
					z += 1
				var run_length := z - run_start
				raw_voxels += run_length
				var px := (float(x) - float(width - 1) / 2.0) * cell
				var py := (float(height - 1 - y) + 0.5) * cell
				var pz := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(depth - 1) / 2.0) * cell
				var color := _blend_front_side(front_color, side.get_pixel(run_start, y))
				var cube := _new_box("%s_x%s_y%s_z%s" % [node_name, x, y, run_start], Vector3(px, py, pz), Vector3(cell, cell, float(run_length) * cell), color)
				holder.add_child(cube)
				count += 1
	_stats[node_name] = {
		"front_pixels": width * height,
		"side_pixels": depth * height,
		"raw_voxels": raw_voxels,
		"boxes": count,
		"mode": "front_side_visual_hull_z_runs"
	}
	return holder


func _blend_front_side(front_color: Color, side_color: Color) -> Color:
	if front_color == Color("#0f1d28") or front_color == Color("#15191d"):
		return front_color
	if side_color == Color("#15191d"):
		return side_color
	return front_color.lerp(side_color, 0.22)


func _fill_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for px in range(x, x + width):
		for py in range(y, y + height):
			if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)


func _save_image(image: Image, path: String) -> void:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save source image %s: %s" % [path, err])
	else:
		print("Saved source image: %s" % ProjectSettings.globalize_path(path))


func _base_scene(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b1017")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#29313b")
	env.ambient_light_energy = 0.82
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_floor(root: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	_add_box(root, "review_floor", position, size, color)


func _add_box(root: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var inst := _new_box(node_name, position, size, color)
	root.add_child(inst)
	return inst


func _new_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	return inst


func _add_camera_light(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "PixelHullSun"
	sun.rotation_degrees = Vector3(-36, -42, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.6
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "PixelHullFill"
	fill.position = target + Vector3(-2.5, 2.5, 2.5)
	fill.light_color = Color("#7fd7ff")
	fill.light_energy = 0.42
	fill.omni_range = 7.0
	root.add_child(fill)

	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	var camera_vector := Vector3(0.95, 0.78, -1.0)
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color == Color("#2aa7d7"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
	return mat


func _save_and_capture(name: String, scene: Node3D, description: String) -> void:
	var scene_path := SCENE_DIR + "/%s.tscn" % name
	var capture_path := CAPTURE_DIR + "/%s.png" % name
	_save_scene(scene, scene_path)
	await _capture_scene(scene, capture_path)
	_captures.append({
		"id": name,
		"description": description,
		"scene_path": scene_path,
		"capture_path": capture_path,
	})
	scene.queue_free()


func _save_scene(root: Node3D, path: String) -> void:
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("Failed to pack %s: %s" % [path, pack_err])
		return
	var save_err := ResourceSaver.save(packed, path)
	if save_err != OK:
		push_error("Failed to save %s: %s" % [path, save_err])
	else:
		print("Saved scene: %s" % ProjectSettings.globalize_path(path))


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


func _capture_scene(scene: Node3D, out_path: String) -> void:
	get_root().size = CAPTURE_SIZE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)
	get_root().add_child(scene)
	for i in range(8):
		await process_frame
	var image := get_root().get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		push_error("Failed to save capture %s: %s" % [out_path, err])
	else:
		print("Saved capture: %s" % ProjectSettings.globalize_path(out_path))
	get_root().remove_child(scene)


func _write_manifest() -> void:
	var manifest := {
		"generator": "docs/gpt/asset_factory/scripts/godot_pixel_hull_character_proof.gd",
		"source_images": _source_paths,
		"stats": _stats,
		"captures": _captures,
	}
	var file := FileAccess.open(OUT_ROOT + "/pixel_hull_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Godot Pixel Hull Character Proof v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_pixel_hull_character_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test a more-3D extension of the deterministic pixel-card lane: use an original front card and side card as silhouette masks, then fill the overlapping volume with voxel bars.")
	lines.append("")
	lines.append("This keeps geometric control while moving beyond a flat cutout.")
	lines.append("")
	lines.append("## Source Cards")
	lines.append("")
	lines.append("- `source_images/trooper_front_card_16x28.png`")
	lines.append("- `source_images/trooper_side_card_10x28.png`")
	lines.append("")
	lines.append("![front card](source_images/trooper_front_card_16x28.png)")
	lines.append("")
	lines.append("![side card](source_images/trooper_side_card_10x28.png)")
	lines.append("")
	lines.append("## Stats")
	lines.append("")
	lines.append("| Node | Mode | Boxes | Raw voxels |")
	lines.append("| --- | --- | ---: | ---: |")
	for key in _stats.keys():
		var stat: Dictionary = _stats[key]
		lines.append("| `%s` | `%s` | %s | %s |" % [key, stat.get("mode", ""), stat.get("boxes", 0), stat.get("raw_voxels", "")])
	lines.append("")
	lines.append("## Captures")
	lines.append("")
	for entry in _captures:
		var capture := String(entry["capture_path"]).replace(OUT_ROOT + "/", "")
		lines.append("### %s" % entry["id"])
		lines.append("")
		lines.append(entry["description"])
		lines.append("")
		lines.append("![%s](%s)" % [entry["id"], capture])
		lines.append("")
	lines.append("## Verdict")
	lines.append("")
	lines.append("Candidate research keep.")
	lines.append("")
	lines.append("The method is deterministic and more genuinely 3D than single-card extrusion. It is promising for low-detail NPCs, icon-scale actors, and AI/card-assisted body-plan exploration. It is not yet a replacement for Blockbench characters because limbs, gear, and animation sockets need stable part boundaries.")
	lines.append("")
	lines.append("Best next improvement: generate separate front/side cards per body part (head, torso, arm, leg, weapon, backpack), build each as its own voxel hull, and animate the parts as rigid cuboid bones.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
