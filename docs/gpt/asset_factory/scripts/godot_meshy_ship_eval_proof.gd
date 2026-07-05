extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/meshy_ship_eval_v0"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"

const BLOCKBENCH_FRIENDLY_SHIP := "res://docs/gpt/asset_factory/generated/blockbench_ship_panel_v2/glb/micro_arc_interceptor_panel_v2.glb"
const MESHY_PATROL_SKIFF := "res://docs/gpt/asset_factory/generated/meshy_eval_v0/meshy_blockcraft_patrol_skiff_meshy5_v1/model.glb"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"meshy_patrol_skiff_rotation_contact_sheet",
		_build_rotation_contact_scene(),
		"Meshy 5 patrol-skiff vehicle seed at 0, 90, 180, and 270 degree yaw. This checks whether the generated silhouette has a useful tactical-facing angle."
	)
	await _save_and_capture(
		"meshy_ship_vs_blockbench_isometric",
		_build_isometric_comparison_scene(),
		"Left: kept Blockbench microfighter baseline. Right: Meshy 5 patrol-skiff seed. This tests whether Meshy helps ship/vehicle silhouette option mining."
	)
	await _save_and_capture(
		"meshy_ship_close_read",
		_build_close_read_scene(),
		"Close isometric read of the Meshy 5 patrol-skiff seed with neutral material tint and engine glow markers."
	)
	_write_review()
	print("Godot Meshy ship eval proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_rotation_contact_scene() -> Node3D:
	var root := _base_scene("MeshyPatrolSkiffRotationContactSheet", Color("#0b1724"), Color("#08101a"))
	var rotations := [0, 90, 180, 270]
	for i in range(rotations.size()):
		var offset := Vector3((float(i) - 1.5) * 2.9, 0, 0)
		_add_space_tile(root, offset, Vector2(2.4, 1.8))
		var holder := _add_model(root, MESHY_PATROL_SKIFF, "meshy_ship_yaw_%s" % rotations[i], offset + Vector3(0, 0.18, 0), Vector3(0, rotations[i], 0), 0.72)
		_tint_model(holder, Color("#beb6aa"))
		_add_engine_hint(root, offset + Vector3(0.65, 0.19, 0.52))
		_add_floor_label_blocks(root, offset + Vector3(0, 0.08, -1.0), "%s" % rotations[i])
	_add_space_lighting_and_camera(root, Vector3(0, 0.45, 0), 9.5)
	return root


func _build_isometric_comparison_scene() -> Node3D:
	var root := _base_scene("MeshyShipVsBlockbenchIsometric", Color("#0b1724"), Color("#08101a"))
	var left := Vector3(-2.35, 0, 0)
	var right := Vector3(2.35, 0, 0)
	_add_space_tile(root, left, Vector2(3.2, 2.3))
	_add_space_tile(root, right, Vector2(3.2, 2.3))
	_add_model(root, BLOCKBENCH_FRIENDLY_SHIP, "blockbench_microfighter_panel_v2", left + Vector3(0, 0.16, 0), Vector3(0, -25, 0), 0.52)
	var meshy := _add_model(root, MESHY_PATROL_SKIFF, "meshy_patrol_skiff", right + Vector3(0, 0.16, 0), Vector3(0, 45, 0), 0.72)
	_tint_model(meshy, Color("#beb6aa"))
	_add_ring(root, "blockbench_selection", left + Vector3(0, 0.05, 0), 0.95, Color("#3cc8ff"))
	_add_ring(root, "meshy_selection", right + Vector3(0, 0.05, 0), 0.95, Color("#ffcc44"))
	_add_engine_hint(root, right + Vector3(0.65, 0.19, 0.52))
	_add_space_lighting_and_camera(root, Vector3(0, 0.48, 0), 7.8)
	return root


func _build_close_read_scene() -> Node3D:
	var root := _base_scene("MeshyShipCloseRead", Color("#0b1724"), Color("#08101a"))
	_add_space_tile(root, Vector3.ZERO, Vector2(4.2, 3.1))
	var meshy := _add_model(root, MESHY_PATROL_SKIFF, "meshy_patrol_skiff", Vector3(0, 0.16, 0), Vector3(0, 45, 0), 0.92)
	_tint_model(meshy, Color("#beb6aa"))
	_add_ring(root, "meshy_selection", Vector3(0, 0.05, 0), 1.1, Color("#ffcc44"))
	_add_engine_hint(root, Vector3(0.85, 0.21, 0.66))
	_add_space_lighting_and_camera(root, Vector3(0, 0.52, 0), 5.2)
	return root


func _base_scene(name: String, ambient: Color, background: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient.lightened(0.25)
	env.ambient_light_energy = 0.82
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_model(root: Node3D, path: String, node_name: String, position: Vector3, rotation_degrees: Vector3, scale_factor: float) -> Node3D:
	var imported: Node = null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if err == OK:
		imported = document.generate_scene(state)

	if imported == null:
		push_error("Could not import GLB model: %s" % path)
		return _add_box(root, node_name + "_missing", position + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), Color("#ff00ff"))

	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation_degrees = rotation_degrees
	holder.scale = Vector3.ONE * scale_factor
	holder.add_child(imported)
	root.add_child(holder)
	return holder


func _tint_model(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.material_override = _material(color)
	for child in node.get_children():
		_tint_model(child, color)


func _add_space_tile(root: Node3D, center: Vector3, size: Vector2) -> void:
	_add_box(root, "space_tile", center + Vector3(0, -0.04, 0), Vector3(size.x, 0.05, size.y), Color("#0b1724"))
	_add_grid(root, center, int(size.x * 2.0), int(size.y * 2.0), 0.5, Color(0.16, 0.45, 0.76, 0.34))


func _add_grid(root: Node3D, center: Vector3, width: int, depth: int, step: float, color: Color) -> void:
	for x in range(-width / 2, width / 2 + 1):
		_add_box(root, "grid_x_%s" % x, center + Vector3(float(x) * step, 0.01, 0), Vector3(0.014, 0.02, float(depth) * step), color)
	for z in range(-depth / 2, depth / 2 + 1):
		_add_box(root, "grid_z_%s" % z, center + Vector3(0, 0.012, float(z) * step), Vector3(float(width) * step, 0.02, 0.014), color)


func _add_ring(root: Node3D, node_name: String, position: Vector3, radius: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.94
	mesh.outer_radius = radius
	mesh.ring_segments = 64
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(Color(color.r, color.g, color.b, 0.7), true)
	root.add_child(inst)


func _add_engine_hint(root: Node3D, position: Vector3) -> void:
	_add_box(root, "cyan_engine_hint_a", position, Vector3(0.16, 0.08, 0.08), Color("#25c4ff"), true)
	_add_box(root, "cyan_engine_hint_b", position + Vector3(0.0, 0.0, -0.18), Vector3(0.16, 0.08, 0.08), Color("#25c4ff"), true)


func _add_floor_label_blocks(root: Node3D, position: Vector3, label: String) -> void:
	for i in range(label.length()):
		_add_box(root, "label_%s_%s" % [label, i], position + Vector3(float(i) * 0.14 - 0.12, 0, 0), Vector3(0.09, 0.08, 0.09), Color("#25c4ff"), true)


func _add_box(root: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color, emissive)
	root.add_child(inst)
	return inst


func _add_space_lighting_and_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SpaceReviewSun"
	sun.rotation_degrees = Vector3(-50, -38, -12)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "SpaceReviewFill"
	fill.position = Vector3(-5, 5, 3)
	fill.light_energy = 0.55
	fill.omni_range = 12.0
	root.add_child(fill)

	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	var camera_vector := Vector3(1.1, 0.9, 1.1)
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = 1.2
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


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Meshy Ship Evaluation v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_meshy_ship_eval_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test whether the cheap Meshy 5 API preview lane helps the difficult ship/vehicle silhouette problem more than the service-terminal prop problem.")
	lines.append("")
	lines.append("## Sources")
	lines.append("")
	lines.append("- `generated/blockbench_ship_panel_v2/glb/micro_arc_interceptor_panel_v2.glb`")
	lines.append("- `generated/meshy_eval_v0/meshy_blockcraft_patrol_skiff_meshy5_v1/model.glb`")
	lines.append("")
	lines.append("The Meshy preview consumed 5 credits. `gltf-transform validate` found no errors or warnings, only one unused TEXCOORD info.")
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
	lines.append("Candidate lesson keep, not direct starfighter/runtime keep.")
	lines.append("")
	lines.append("The Meshy 5 seed produces a useful chunky cockpit/engine mass, but it reads more like a ground hover-skiff or utility speeder than a clean isometric starfighter. It is better as vehicle/prop silhouette inspiration than as direct tactical-space art.")
	lines.append("")
	lines.append("Next one-variable recommendation: either refine this only if the owner wants a ground-speeder/vehicle mood sample, or run a new Meshy 5 prompt explicitly asking for a flatter top-down tactical ship token with wing silhouette and no cabin/truck read.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))

