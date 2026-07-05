extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_cantina_sign_texture_v1"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const BASELINE_GLB := "res://docs/gpt/asset_factory/generated/blockbench_cantina_entrance_v1/glb/blockbench_cantina_entrance_v1.glb"
const CANDIDATE_GLB := "res://docs/gpt/asset_factory/generated/blockbench_cantina_sign_texture_v1/glb/blockbench_cantina_sign_texture_v1.glb"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"cube_sign_closeup",
		_build_closeup_scene("CubeSignCloseup", BASELINE_GLB),
		"Baseline closeup: cube-only no-droids sign from `blockbench_cantina_entrance_v1`."
	)
	await _save_and_capture(
		"texture_sign_closeup",
		_build_closeup_scene("TextureSignCloseup", CANDIDATE_GLB),
		"Candidate closeup: original pixel-texture no-droids sign panel, same entrance geometry."
	)
	await _save_and_capture(
		"texture_sign_ground_camera",
		_build_ground_scene("TextureSignGroundCamera", CANDIDATE_GLB),
		"Candidate ground camera: textured sign in the same entrance model family."
	)
	await _save_and_capture(
		"sign_workflow_ab_pair",
		_build_ab_pair_scene(),
		"A/B pair: cube-sign baseline and texture-sign candidate. Use the closeups for final sign readability judgment."
	)
	_write_review()
	print("Godot Cantina sign texture proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_closeup_scene(name: String, glb_path: String) -> Node3D:
	var root := _base_scene(name)
	_add_warm_context(root, Vector3.ZERO)
	_add_model(root, glb_path, "cantina_entrance_glb", Vector3.ZERO, Vector3(0, 180, 0), 1.0)
	_add_close_lighting(root, Vector3(-1.08, 1.54, -0.3))
	_add_camera(root, Vector3(-1.08, 1.54, -0.3), 2.05, Vector3(1.0, 0.42, -0.72), 7.0)
	return root


func _build_ground_scene(name: String, glb_path: String) -> Node3D:
	var root := _base_scene(name)
	_add_warm_context(root, Vector3.ZERO)
	_add_model(root, glb_path, "cantina_entrance_glb", Vector3.ZERO, Vector3(0, 180, 0), 1.0)
	_add_player_scale(root, Vector3(-1.9, 0, -2.0), "player_scale_left")
	_add_player_scale(root, Vector3(1.7, 0, -1.75), "droid_waiting_right", Color("#b99b63"), Color("#6d5a38"))
	_add_ground_lighting(root, Vector3(0, 1.05, 0.05))
	_add_camera(root, Vector3(0, 1.05, 0.05), 6.4, Vector3(1.0, 0.82, -1.0), 14.0)
	return root


func _build_ab_pair_scene() -> Node3D:
	var root := _base_scene("SignWorkflowABPair")
	_add_warm_context(root, Vector3(-3.2, 0, 0))
	_add_warm_context(root, Vector3(3.2, 0, 0))
	_add_model(root, BASELINE_GLB, "cube_sign_baseline_glb", Vector3(-3.2, 0, 0), Vector3(0, 180, 0), 1.0)
	_add_model(root, CANDIDATE_GLB, "texture_sign_candidate_glb", Vector3(3.2, 0, 0), Vector3(0, 180, 0), 1.0)
	_add_ground_lighting(root, Vector3(0, 1.05, 0.05))
	_add_camera(root, Vector3(0, 1.35, 0), 9.0, Vector3(1.0, 0.72, -1.0), 13.0)
	return root


func _base_scene(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#7f969c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a36a31")
	env.ambient_light_energy = 0.48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_warm_context(root: Node3D, offset: Vector3) -> void:
	_add_box(root, "sunbaked_dust_plane", offset + Vector3(0, -0.055, 0), Vector3(5.8, 0.08, 4.0), Color("#b87938"))
	_add_box(root, "threshold_shadow_pool", offset + Vector3(0, 0.01, -0.45), Vector3(3.4, 0.03, 1.7), Color("#49301f"))


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


func _add_close_lighting(root: Node3D, target: Vector3) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "CloseWarmSun"
	sun.rotation_degrees = Vector3(-26, -42, -8)
	sun.light_color = Color("#ffd29a")
	sun.light_energy = 2.6
	sun.shadow_enabled = true
	root.add_child(sun)

	var scanner := OmniLight3D.new()
	scanner.name = "ScannerCoolAccent"
	scanner.position = target + Vector3(0.2, 0.1, -0.5)
	scanner.light_color = Color("#27d7ff")
	scanner.light_energy = 0.22
	scanner.omni_range = 2.0
	root.add_child(scanner)


func _add_ground_lighting(root: Node3D, target: Vector3) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "WarmExteriorSun"
	sun.rotation_degrees = Vector3(-34, -48, -8)
	sun.light_color = Color("#ffd29a")
	sun.light_energy = 2.45
	sun.shadow_enabled = true
	root.add_child(sun)

	var doorway := OmniLight3D.new()
	doorway.name = "DoorwayAmber"
	doorway.position = target + Vector3(0, 0.6, 0.82)
	doorway.light_color = Color("#ffad55")
	doorway.light_energy = 0.55
	doorway.omni_range = 4.0
	root.add_child(doorway)


func _add_camera(root: Node3D, target: Vector3, camera_size: float, camera_vector: Vector3, distance: float) -> void:
	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	camera.position = target + camera_vector.normalized() * distance
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
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
	lines.append("# Godot Cantina Sign Texture Proof")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_cantina_sign_texture_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Compare the cube-only no-droids sign baseline against a texture/manual-style sign candidate in Godot.")
	lines.append("")
	lines.append("Baseline GLB:")
	lines.append("")
	lines.append("```text")
	lines.append(BASELINE_GLB)
	lines.append("```")
	lines.append("")
	lines.append("Candidate GLB:")
	lines.append("")
	lines.append("```text")
	lines.append(CANDIDATE_GLB)
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
	lines.append("Write the keep/reject verdict after inspecting the captures.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))

