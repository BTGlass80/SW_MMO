extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_pixel_hull_body_parts_v0"
const SOURCE_DIR := OUT_ROOT + "/source_images"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"

const CELL := 0.085

var _captures: Array[Dictionary] = []
var _source_paths: Dictionary = {}
var _stats: Dictionary = {}
var _part_defs := {
	"head": {"front": Vector2i(8, 8), "side": Vector2i(6, 8)},
	"torso": {"front": Vector2i(10, 12), "side": Vector2i(6, 12)},
	"upper_arm": {"front": Vector2i(3, 8), "side": Vector2i(3, 8)},
	"forearm": {"front": Vector2i(3, 7), "side": Vector2i(3, 7)},
	"leg": {"front": Vector2i(4, 10), "side": Vector2i(4, 10)},
	"backpack": {"front": Vector2i(5, 9), "side": Vector2i(3, 9)},
	"rifle": {"front": Vector2i(18, 5), "side": Vector2i(3, 5)},
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	_generate_source_cards()
	await _save_and_capture(
		"body_part_source_cards",
		_build_source_cards_scene(),
		"Original project-owned per-body-part pixel cards. Each body part has separate front and side silhouettes so it can become a rigid animation piece."
	)
	await _save_and_capture(
		"body_part_neutral_vs_ready",
		_build_neutral_vs_ready_scene(),
		"Same voxel parts, two poses. Left: neutral test assembly. Right: rifle-ready pose using rotations/translations on separate head, torso, arm, leg, backpack, and weapon nodes."
	)
	await _save_and_capture(
		"body_part_rotation_contact_sheet",
		_build_rotation_sheet_scene(),
		"Four yaw angles for the assembled body-part hull. This checks whether the split parts read as one 3D actor instead of a paper cutout."
	)
	await _save_and_capture(
		"body_part_cover_pose_ab",
		_build_cover_pose_scene(),
		"Rifle-ready versus simple cover-lean pose. This tests whether the deterministic hull pieces expose enough handles for MMO combat animation requests."
	)
	_write_manifest()
	_write_review()
	print("Godot body-part pixel-hull proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SOURCE_DIR, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _generate_source_cards() -> void:
	for part_name in _part_defs.keys():
		var def: Dictionary = _part_defs[part_name]
		var front_size: Vector2i = def["front"]
		var side_size: Vector2i = def["side"]
		var front := Image.create_empty(front_size.x, front_size.y, false, Image.FORMAT_RGBA8)
		var side := Image.create_empty(side_size.x, side_size.y, false, Image.FORMAT_RGBA8)
		front.fill(Color(0, 0, 0, 0))
		side.fill(Color(0, 0, 0, 0))
		_draw_part(part_name, front, side)
		var front_path := SOURCE_DIR + "/%s_front.png" % part_name
		var side_path := SOURCE_DIR + "/%s_side.png" % part_name
		_save_image(front, front_path)
		_save_image(side, side_path)
		_source_paths[part_name] = {"front": front_path, "side": side_path}


func _draw_part(part_name: String, front: Image, side: Image) -> void:
	var armor := Color("#e8ece5")
	var armor_shadow := Color("#aeb5b0")
	var dark := Color("#15191d")
	var visor := Color("#0f1d28")
	var blue := Color("#2aa7d7")
	var red := Color("#a95e4d")
	var tan := Color("#b68a53")

	match part_name:
		"head":
			_fill_rect(front, 2, 1, 4, 5, armor)
			_fill_rect(front, 1, 3, 6, 3, armor)
			_fill_rect(front, 2, 4, 4, 2, visor)
			_fill_rect(front, 3, 1, 2, 2, blue)
			_fill_rect(side, 1, 1, 4, 5, armor)
			_fill_rect(side, 0, 3, 6, 3, armor)
			_fill_rect(side, 0, 4, 4, 2, visor)
			_fill_rect(side, 4, 2, 1, 4, armor_shadow)
		"torso":
			_fill_rect(front, 2, 1, 6, 10, armor)
			_fill_rect(front, 1, 3, 8, 5, armor_shadow)
			_fill_rect(front, 4, 1, 2, 10, blue)
			_fill_rect(front, 2, 8, 2, 2, red)
			_fill_rect(front, 6, 8, 2, 2, red)
			_fill_rect(side, 1, 1, 4, 10, armor)
			_fill_rect(side, 3, 3, 3, 5, armor_shadow)
			_fill_rect(side, 2, 1, 1, 10, blue)
		"upper_arm":
			_fill_rect(front, 0, 0, 3, 8, armor)
			_fill_rect(front, 1, 2, 2, 4, armor_shadow)
			_fill_rect(side, 0, 0, 3, 8, armor)
			_fill_rect(side, 1, 2, 2, 4, armor_shadow)
		"forearm":
			_fill_rect(front, 0, 0, 3, 6, armor)
			_fill_rect(front, 0, 5, 3, 2, dark)
			_fill_rect(side, 0, 0, 3, 6, armor)
			_fill_rect(side, 0, 5, 3, 2, dark)
		"leg":
			_fill_rect(front, 0, 0, 4, 8, armor)
			_fill_rect(front, 0, 8, 4, 2, dark)
			_fill_rect(front, 2, 2, 2, 5, armor_shadow)
			_fill_rect(side, 0, 0, 4, 8, armor)
			_fill_rect(side, 0, 8, 4, 2, dark)
			_fill_rect(side, 2, 2, 2, 5, armor_shadow)
		"backpack":
			_fill_rect(front, 0, 1, 5, 7, dark)
			_fill_rect(front, 1, 2, 3, 2, armor_shadow)
			_fill_rect(front, 2, 5, 2, 2, tan)
			_fill_rect(side, 0, 1, 3, 7, dark)
			_fill_rect(side, 1, 2, 2, 2, armor_shadow)
			_fill_rect(side, 1, 5, 2, 2, tan)
		"rifle":
			_fill_rect(front, 1, 2, 13, 2, dark)
			_fill_rect(front, 13, 1, 4, 2, armor_shadow)
			_fill_rect(front, 4, 0, 3, 2, armor_shadow)
			_fill_rect(front, 7, 3, 3, 2, tan)
			_fill_rect(front, 17, 2, 1, 1, blue)
			_fill_rect(side, 0, 1, 3, 3, dark)
			_fill_rect(side, 1, 0, 2, 2, armor_shadow)
			_fill_rect(side, 1, 3, 2, 2, tan)


func _build_source_cards_scene() -> Node3D:
	var root := _base_scene("BodyPartPixelSourceCards", Color("#101720"))
	var order := ["head", "torso", "upper_arm", "forearm", "leg", "backpack", "rifle"]
	for i in range(order.size()):
		var part_name: String = order[i]
		var front := _load_part_image(part_name, "front")
		var side := _load_part_image(part_name, "side")
		var x := (float(i) - 3.0) * 0.78
		_extrude_card(root, front, "%s_front_card" % part_name, Vector3(x, 1.35, -0.12), CELL * 0.9, CELL * 0.28)
		_extrude_card(root, side, "%s_side_card" % part_name, Vector3(x, 0.45, -0.12), CELL * 0.9, CELL * 0.28)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(6.2, 0.08, 2.0), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.86, 0), 4.0)
	return root


func _build_neutral_vs_ready_scene() -> Node3D:
	var root := _base_scene("BodyPartNeutralVsReady", Color("#0b1017"))
	var neutral := _assemble_actor(root, "neutral_actor", Vector3(-0.9, 0, 0), "neutral")
	neutral.rotation_degrees = Vector3(0, -18, 0)
	var ready := _assemble_actor(root, "rifle_ready_actor", Vector3(0.9, 0, 0), "ready")
	ready.rotation_degrees = Vector3(0, -18, 0)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(3.6, 0.08, 2.2), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 1.0, 0), 3.35)
	return root


func _build_rotation_sheet_scene() -> Node3D:
	var root := _base_scene("BodyPartRotationContactSheet", Color("#0b1017"))
	var yaws := [0, 90, 180, 270]
	for i in range(yaws.size()):
		var offset := Vector3((float(i) - 1.5) * 1.25, 0, 0)
		var actor := _assemble_actor(root, "ready_actor_yaw_%s" % yaws[i], offset, "ready")
		actor.rotation_degrees = Vector3(0, yaws[i], 0)
		_add_floor(root, offset + Vector3(0, -0.06, 0), Vector3(1.0, 0.06, 1.0), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.95, 0), 5.2)
	return root


func _build_cover_pose_scene() -> Node3D:
	var root := _base_scene("BodyPartCoverPoseAB", Color("#0b1017"))
	var ready := _assemble_actor(root, "ready_actor", Vector3(-0.82, 0, 0), "ready")
	ready.rotation_degrees = Vector3(0, -22, 0)
	var cover := _assemble_actor(root, "cover_lean_actor", Vector3(0.82, 0, 0), "cover")
	cover.rotation_degrees = Vector3(0, -22, 0)
	_add_box(root, "low_cover_crate", Vector3(1.13, 0.36, -0.38), Vector3(0.55, 0.72, 0.42), Color("#6c4b35"))
	_add_box(root, "crate_panel", Vector3(1.13, 0.68, -0.60), Vector3(0.45, 0.1, 0.04), Color("#2aa7d7"))
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(3.5, 0.08, 2.2), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.94, 0), 3.35)
	return root


func _assemble_actor(root: Node3D, node_name: String, origin: Vector3, pose: String) -> Node3D:
	var actor := Node3D.new()
	actor.name = node_name
	actor.position = origin
	root.add_child(actor)

	var torso := _make_part("torso", "torso", Vector3(0, 1.16, 0))
	var head := _make_part("head", "head", Vector3(0, 1.96, -0.01))
	var backpack := _make_part("backpack", "backpack", Vector3(0, 1.16, 0.29))
	var left_upper := _make_part("upper_arm", "left_upper_arm", Vector3(-0.48, 1.31, 0))
	var left_fore := _make_part("forearm", "left_forearm", Vector3(-0.50, 0.78, -0.02))
	var right_upper := _make_part("upper_arm", "right_upper_arm", Vector3(0.48, 1.31, 0))
	var right_fore := _make_part("forearm", "right_forearm", Vector3(0.50, 0.78, -0.02))
	var left_leg := _make_part("leg", "left_leg", Vector3(-0.17, 0.43, 0))
	var right_leg := _make_part("leg", "right_leg", Vector3(0.17, 0.43, 0))
	var rifle := _make_part("rifle", "rifle", Vector3(0.43, 1.13, -0.38))

	for part in [torso, head, backpack, left_upper, left_fore, right_upper, right_fore, left_leg, right_leg, rifle]:
		actor.add_child(part)

	match pose:
		"neutral":
			rifle.visible = false
			left_upper.rotation_degrees = Vector3(0, 0, -7)
			right_upper.rotation_degrees = Vector3(0, 0, 7)
			left_fore.rotation_degrees = Vector3(0, 0, -4)
			right_fore.rotation_degrees = Vector3(0, 0, 4)
		"ready":
			head.rotation_degrees = Vector3(0, -4, 0)
			left_upper.rotation_degrees = Vector3(-46, 0, -36)
			left_fore.position = Vector3(-0.28, 1.08, -0.25)
			left_fore.rotation_degrees = Vector3(-58, 0, 62)
			right_upper.rotation_degrees = Vector3(-54, 0, 42)
			right_fore.position = Vector3(0.35, 1.06, -0.27)
			right_fore.rotation_degrees = Vector3(-64, 0, -56)
			rifle.rotation_degrees = Vector3(0, 0, -4)
		"cover":
			torso.rotation_degrees = Vector3(0, 0, -8)
			head.rotation_degrees = Vector3(0, -10, -8)
			left_upper.rotation_degrees = Vector3(-55, 0, -52)
			left_fore.position = Vector3(-0.24, 1.07, -0.26)
			left_fore.rotation_degrees = Vector3(-65, 0, 68)
			right_upper.rotation_degrees = Vector3(-72, 0, 24)
			right_fore.position = Vector3(0.38, 1.09, -0.31)
			right_fore.rotation_degrees = Vector3(-72, 0, -50)
			left_leg.rotation_degrees = Vector3(0, 0, -4)
			right_leg.position += Vector3(0.07, 0, 0.06)
			rifle.position = Vector3(0.34, 1.18, -0.44)
			rifle.rotation_degrees = Vector3(0, 0, -8)

	return actor


func _make_part(part_name: String, instance_name: String, position: Vector3) -> Node3D:
	var front := _load_part_image(part_name, "front")
	var side := _load_part_image(part_name, "side")
	var node := _visual_hull_z_runs(front, side, instance_name, Vector3.ZERO, CELL)
	node.position = position
	return node


func _load_part_image(part_name: String, side_name: String) -> Image:
	var path := String(_source_paths[part_name][side_name])
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _extrude_card(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, depth: float) -> Node3D:
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
			holder.add_child(_new_box("%s_run_%s_%s" % [node_name, run_start, y], Vector3(px, py, 0), Vector3(float(run_length) * cell, cell, depth), color))
			count += 1
	_stats[node_name] = {"boxes": count, "mode": "source_card_same_color_runs"}
	return holder


func _visual_hull_z_runs(front: Image, side: Image, node_name: String, origin: Vector3, cell: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
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
				var py := (float(height - 1 - y) - float(height - 1) / 2.0) * cell
				var pz := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(depth - 1) / 2.0) * cell
				var color := _blend_front_side(front_color, side.get_pixel(run_start, y))
				holder.add_child(_new_box("%s_x%s_y%s_z%s" % [node_name, x, y, run_start], Vector3(px, py, pz), Vector3(cell, cell, float(run_length) * cell), color))
				count += 1
	_stats[node_name] = {"boxes": count, "raw_voxels": raw_voxels, "mode": "body_part_front_side_visual_hull_z_runs"}
	return holder


func _blend_front_side(front_color: Color, side_color: Color) -> Color:
	if front_color == Color("#0f1d28") or front_color == Color("#15191d"):
		return front_color
	if side_color == Color("#15191d"):
		return side_color
	return front_color.lerp(side_color, 0.18)


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


func _base_scene(name: String, background: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#29313b")
	env.ambient_light_energy = 0.86
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
	sun.name = "BodyPartHullSun"
	sun.rotation_degrees = Vector3(-36, -42, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.7
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "BodyPartHullFill"
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
		"generator": "docs/gpt/asset_factory/scripts/godot_pixel_hull_body_parts_proof.gd",
		"source_images": _source_paths,
		"stats": _stats,
		"captures": _captures,
	}
	var file := FileAccess.open(OUT_ROOT + "/body_part_pixel_hull_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Godot Body-Part Pixel Hull Proof v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_pixel_hull_body_parts_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test the next step after the whole-body pixel hull: split a trooper-like blockcraft actor into deterministic voxel body parts so animation can rotate rigid pieces instead of bending one fused statue.")
	lines.append("")
	lines.append("Each part is built from original project-owned front and side pixel cards. The generator fills the front/side visual hull and z-run merges the result into rectangular voxel bars.")
	lines.append("")
	lines.append("## Source Card Families")
	lines.append("")
	for part_name in _part_defs.keys():
		lines.append("- `%s`: `source_images/%s_front.png`, `source_images/%s_side.png`" % [part_name, part_name, part_name])
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
	lines.append("## Stats")
	lines.append("")
	lines.append("| Node | Mode | Boxes | Raw voxels |")
	lines.append("| --- | --- | ---: | ---: |")
	for key in _stats.keys():
		var stat: Dictionary = _stats[key]
		lines.append("| `%s` | `%s` | %s | %s |" % [key, stat.get("mode", ""), stat.get("boxes", 0), stat.get("raw_voxels", "")])
	lines.append("")
	lines.append("## Verdict")
	lines.append("")
	lines.append("Candidate keep for the deterministic animation lane.")
	lines.append("")
	lines.append("This is materially better than the fused whole-body hull for animation because head, torso, arms, legs, backpack, and weapon are addressable nodes. It does not yet replace a Blockbench hero character: shoulder/elbow pivots are approximate, poses are rigid, and the silhouette still needs hand-authored polish. It does establish a cheap, repeatable protocol for background NPCs, low-detail troopers, droids with segmented limbs, and quick animation request proofs.")
	lines.append("")
	lines.append("Recommended next check: build the same body-part protocol for a non-humanoid droid, where rigid segmented limbs are a better natural fit than organic humanoid animation.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
