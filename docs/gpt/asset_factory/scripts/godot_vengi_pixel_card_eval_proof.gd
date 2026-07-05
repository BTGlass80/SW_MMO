extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/vengi_pixel_card_eval_v0"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const TERMINAL_SOURCE := "res://docs/gpt/asset_factory/generated/godot_pixel_extrude_v0/source_images/pixel_service_terminal_front_24x24.png"
const SHIP_SOURCE := "res://docs/gpt/asset_factory/generated/godot_pixel_extrude_v0/source_images/pixel_patrol_ship_top_32x32.png"
const TERMINAL_VENGI_GLB := OUT_ROOT + "/pixel_service_terminal_vengi_plane.glb"
const SHIP_VENGI_GLB := OUT_ROOT + "/glb/pixel_patrol_ship_vengi_plane.glb"
const CELL := 0.12

var _captures: Array[Dictionary] = []
var _stats: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"vengi_terminal_same_source_ab",
		_build_terminal_scene(),
		"Same 24x24 terminal source card. Left: Godot run-merged voxel bars. Right: Vengi PNG->GLB plane conversion."
	)
	await _save_and_capture(
		"vengi_ship_same_source_ab",
		_build_ship_scene(),
		"Same 32x32 tactical ship source card. Left: Godot run-merged height token. Right: Vengi PNG->GLB plane conversion."
	)
	_write_review()
	print("Godot Vengi pixel-card proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_terminal_scene() -> Node3D:
	var root := _base_scene("VengiTerminalSameSourceAB", Color("#191018"))
	var left := Vector3(-2.1, 0, 0)
	var right := Vector3(2.1, 0, 0)
	_add_wall_context(root, left)
	_add_wall_context(root, right)
	var image := Image.load_from_file(ProjectSettings.globalize_path(TERMINAL_SOURCE))
	_extrude_front_runs(root, image, "godot_terminal_runmerge", left + Vector3(0, 0.84, -0.08), CELL, CELL * 1.7)
	_add_model(root, TERMINAL_VENGI_GLB, "vengi_terminal_plane_glb", right + Vector3(0, 0.82, -0.08), Vector3(-12, -15, -0.5), CELL)
	_add_camera_light(root, Vector3(0, 0.9, -0.2), 6.5, Vector3(0.95, 0.76, -0.95))
	return root


func _build_ship_scene() -> Node3D:
	var root := _base_scene("VengiShipSameSourceAB", Color("#07111b"))
	var left := Vector3(-2.0, 0, 0)
	var right := Vector3(2.0, 0, 0)
	_add_space_tile(root, left, Vector2(3.2, 2.5))
	_add_space_tile(root, right, Vector2(3.2, 2.5))
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHIP_SOURCE))
	var godot_ship := _extrude_top_runs(root, image, "godot_ship_runmerge", left + Vector3(0, 0.04, 0), CELL * 0.8, CELL * 1.05)
	godot_ship.rotation_degrees = Vector3(0, -25, 0)
	var vengi_ship := _add_model(root, SHIP_VENGI_GLB, "vengi_ship_plane_glb", right + Vector3(0, 0.12, 0), Vector3(-16, -18.5, -0.5), CELL * 0.8)
	vengi_ship.rotation_degrees = Vector3(-90, -25, 0)
	_add_camera_light(root, Vector3(0, 0.45, 0), 6.4, Vector3(1.1, 0.9, 1.1))
	return root


func _extrude_front_runs(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, depth: float) -> Node3D:
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
	_stats[node_name] = count
	return holder


func _extrude_top_runs(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, height_scale: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	root.add_child(holder)
	var count := 0
	var width := image.get_width()
	var depth := image.get_height()
	for z in range(depth):
		var x := 0
		while x < width:
			var color := image.get_pixel(x, z)
			if color.a <= 0.05:
				x += 1
				continue
			var run_start := x
			var key := color.to_html(true)
			while x < width and image.get_pixel(x, z).a > 0.05 and image.get_pixel(x, z).to_html(true) == key:
				x += 1
			var run_length := x - run_start
			var px := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(width - 1) / 2.0) * cell
			var pz := (float(z) - float(depth - 1) / 2.0) * cell
			var brightness := (color.r + color.g + color.b) / 3.0
			var cube_height := height_scale * (0.55 + brightness * 0.75)
			holder.add_child(_new_box("%s_run_%s_%s" % [node_name, run_start, z], Vector3(px, cube_height / 2.0, pz), Vector3(float(run_length) * cell, cube_height, cell), color))
			count += 1
	_stats[node_name] = count
	return holder


func _add_model(root: Node3D, path: String, node_name: String, position: Vector3, import_offset: Vector3, scale_factor: float) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(ProjectSettings.globalize_path(path), state)
	var imported: Node = null
	if err == OK:
		imported = document.generate_scene(state)
	if imported == null:
		push_error("Could not import Vengi GLB: %s" % path)
		return _add_box(root, node_name + "_missing", position, Vector3(0.8, 0.8, 0.8), Color("#ff00ff"))

	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.scale = Vector3.ONE * scale_factor
	if imported is Node3D:
		(imported as Node3D).position = import_offset
	holder.add_child(imported)
	root.add_child(holder)
	return holder


func _add_wall_context(root: Node3D, offset: Vector3) -> void:
	_add_box(root, "cantina_wall", offset + Vector3(0, 1.08, 0.12), Vector3(3.0, 2.25, 0.16), Color("#9f6436"))
	_add_box(root, "dust_floor", offset + Vector3(0, -0.04, -0.45), Vector3(3.5, 0.08, 2.3), Color("#2c211d"))


func _add_space_tile(root: Node3D, center: Vector3, size: Vector2) -> void:
	_add_box(root, "space_tile", center + Vector3(0, -0.04, 0), Vector3(size.x, 0.05, size.y), Color("#0b1724"))
	for x in range(-3, 4):
		_add_box(root, "grid_x_%s" % x, center + Vector3(float(x) * 0.5, 0.01, 0), Vector3(0.014, 0.02, size.y), Color(0.16, 0.45, 0.76, 0.34))
	for z in range(-2, 3):
		_add_box(root, "grid_z_%s" % z, center + Vector3(0, 0.012, float(z) * 0.5), Vector3(size.x, 0.02, 0.014), Color(0.16, 0.45, 0.76, 0.34))


func _base_scene(name: String, ambient: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b1017")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient.lightened(0.32)
	env.ambient_light_energy = 0.72
	env_node.environment = env
	root.add_child(env_node)
	return root


func _new_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	return inst


func _add_box(root: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var inst := _new_box(node_name, position, size, color)
	root.add_child(inst)
	return inst


func _add_camera_light(root: Node3D, target: Vector3, camera_size: float, camera_vector: Vector3) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "VengiProofSun"
	sun.rotation_degrees = Vector3(-38, -44, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	root.add_child(sun)

	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	if pack_err == OK:
		var save_err := ResourceSaver.save(packed, path)
		if save_err != OK:
			push_error("Failed to save %s: %s" % [path, save_err])


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


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Vengi Pixel-Card Evaluation v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_vengi_pixel_card_eval_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Evaluate the installed Vengi 0.5.0 tools against the current deterministic pixel-card lane.")
	lines.append("")
	lines.append("## Local Tool Paths")
	lines.append("")
	lines.append("- `C:/Program Files/vengi/voxconvert/vengi-voxconvert.exe`")
	lines.append("- `C:/Program Files/vengi/voxedit/vengi-voxedit.exe`")
	lines.append("- `C:/Program Files/vengi/thumbnailer/vengi-thumbnailer.exe`")
	lines.append("- `C:/Program Files/vengi/palconvert/vengi-palconvert.exe`")
	lines.append("")
	lines.append("## Tested Commands")
	lines.append("")
	lines.append("PNG source cards converted successfully to flat GLB/VOX. Attempts to use image volume import and `.bbmodel` -> GLB hung in this first probe and were stopped.")
	lines.append("")
	lines.append("## Generated Files")
	lines.append("")
	lines.append("- `pixel_service_terminal_vengi_plane.glb`")
	lines.append("- `glb/pixel_patrol_ship_vengi_plane.glb`")
	lines.append("- `vox/pixel_service_terminal_vengi_plane.vox`")
	lines.append("")
	lines.append("`gltf-transform validate` found no errors for the tested Vengi GLBs. It reported data-URI-in-GLB warnings, so these are proof artifacts rather than promotion-ready runtime GLBs.")
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
	lines.append("Candidate bridge keep, not a replacement for Godot pixel extrusion or Blender conversion yet.")
	lines.append("")
	lines.append("Vengi is useful immediately as a local installed converter/editor bridge: project pixel cards can become `.vox` for manual voxel-editor work and can become simple flat GLBs. It did not beat the Godot run-merged extrusion for true in-engine voxel props because the successful GLB path is still a flat textured mesh, not cube bars.")
	lines.append("")
	lines.append("Best next Vengi slice: debug a single image-volume conversion command or use `vengi-voxedit` manually on the generated `.vox`, then export GLB and compare again.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
