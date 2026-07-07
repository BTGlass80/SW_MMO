extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_cantina_entrance_camera_v1"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const CANTINA_ENTRANCE_GLB := "res://docs/gpt/asset_factory/generated/blockbench_cantina_entrance_v1/glb/blockbench_cantina_entrance_v1.glb"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture("cantina_entrance_ground_camera", _build_ground_camera_scene(), "Godot ground camera proof for the kept Blockbench Cantina entrance GLB.")
	await _save_and_capture("cantina_entrance_plaza_context", _build_plaza_context_scene(), "Godot plaza-context proof with player scale, low walls, and exterior approach.")
	_write_review()
	print("Godot Cantina GLB camera proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_ground_camera_scene() -> Node3D:
	var root := _base_scene("CantinaEntranceGroundCamera", Color("#c89555"), Color("#8ea7b8"))
	_add_box(root, "dust_plane", Vector3(0, -0.05, 0), Vector3(10, 0.08, 7), Color("#c89555"))
	_add_model(root, CANTINA_ENTRANCE_GLB, "cantina_entrance_glb", Vector3(0, 0, 0), Vector3(0, 180, 0), 1.0)
	_add_player_scale(root, Vector3(-1.9, 0, -2.0), "player_scale_left")
	_add_player_scale(root, Vector3(1.7, 0, -1.75), "droid_waiting_right", Color("#b99b63"), Color("#6d5a38"))
	_add_lighting_and_camera(root, Vector3(0, 1.05, 0.05), 6.4)
	return root


func _build_plaza_context_scene() -> Node3D:
	var root := _base_scene("CantinaEntrancePlazaContext", Color("#c89555"), Color("#8ea7b8"))
	_add_box(root, "dust_plane", Vector3(0, -0.05, 0), Vector3(11, 0.08, 7.5), Color("#c89555"))
	_add_box(root, "left_low_wall", Vector3(-3.15, 0.32, -1.75), Vector3(2.0, 0.62, 0.35), Color("#b98245"))
	_add_box(root, "right_low_wall", Vector3(3.05, 0.32, -1.55), Vector3(1.85, 0.62, 0.35), Color("#b98245"))
	_add_box(root, "trouble_cover", Vector3(1.45, 0.34, -2.65), Vector3(1.45, 0.68, 0.42), Color("#171b20"))
	_add_box(root, "vaporator_pole", Vector3(-4.1, 0.9, 0.45), Vector3(0.1, 1.8, 0.1), Color("#68727a"))
	_add_box(root, "vaporator_cross_a", Vector3(-4.1, 1.35, 0.45), Vector3(0.7, 0.08, 0.08), Color("#a4afb3"))
	_add_box(root, "vaporator_cross_b", Vector3(-4.1, 0.78, 0.45), Vector3(0.52, 0.08, 0.08), Color("#a4afb3"))
	_add_model(root, CANTINA_ENTRANCE_GLB, "cantina_entrance_glb", Vector3(0, 0, 0.35), Vector3(0, 180, 0), 1.0)
	_add_player_scale(root, Vector3(-1.55, 0, -2.45), "player_scale_left")
	_add_player_scale(root, Vector3(2.15, 0, -2.2), "droid_waiting_right", Color("#b99b63"), Color("#6d5a38"))
	_add_lighting_and_camera(root, Vector3(0, 0.95, -0.15), 7.2)
	return root


func _base_scene(name: String, ambient: Color, background: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient.lightened(0.22)
	env.ambient_light_energy = 0.8
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


func _add_player_scale(root: Node3D, position: Vector3, node_name: String, body_color: Color = Color("#e6eceb"), head_color: Color = Color("#aeb8bb")) -> void:
	_add_box(root, node_name + "_body", position + Vector3(0, 0.64, 0), Vector3(0.36, 0.82, 0.26), body_color)
	_add_box(root, node_name + "_head", position + Vector3(0, 1.22, 0), Vector3(0.34, 0.3, 0.32), head_color)
	_add_box(root, node_name + "_visor", position + Vector3(0, 1.23, -0.18), Vector3(0.22, 0.06, 0.04), Color("#101419"))


func _add_box(root: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	root.add_child(inst)
	return inst


func _add_lighting_and_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "ReviewSun"
	sun.rotation_degrees = Vector3(-53, -34, -10)
	sun.light_energy = 2.25
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "SoftFill"
	fill.position = Vector3(-4, 5, -2)
	fill.light_energy = 0.45
	fill.omni_range = 12.0
	root.add_child(fill)

	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	var camera_vector := Vector3(1.0, 0.82, -1.0)
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	if color == Color("#27d7ff") or color == Color("#ff7a2c"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.15
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
	lines.append("# Godot Cantina Entrance GLB Camera Proof")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_cantina_glb_camera_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("This docs-only proof imports the kept Blockbench Cantina entrance GLB into Godot and captures it with ground/plaza cameras before any runtime promotion.")
	lines.append("")
	lines.append("Source GLB:")
	lines.append("")
	lines.append("```text")
	lines.append(CANTINA_ENTRANCE_GLB)
	lines.append("```")
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
	lines.append("Write the keep/reject verdict after inspecting the generated captures.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
