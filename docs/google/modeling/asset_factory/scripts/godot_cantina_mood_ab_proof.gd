extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/cantina_mood_ab_v1"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const CANTINA_ENTRANCE_GLB := "res://docs/gpt/asset_factory/generated/blockbench_cantina_entrance_v1/glb/blockbench_cantina_entrance_v1.glb"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"cantina_mood_baseline_control",
		_build_baseline_scene("CantinaMoodBaselineControl", Vector3.ZERO),
		"Control capture: kept entrance GLB, clean prototype lighting, minimal context."
	)
	await _save_and_capture(
		"cantina_mood_warm_grime_pass",
		_build_mood_scene("CantinaMoodWarmGrimePass", Vector3.ZERO),
		"Mood capture: same entrance GLB, changed only lighting, exterior clutter, grime chips, and dim doorway context."
	)
	await _save_and_capture(
		"cantina_mood_side_by_side",
		_build_side_by_side_scene(),
		"Side-by-side A/B: one clean control and one mood pass. Camera perspective can flip screen order, so use the individual captures as the authoritative baseline/mood comparison."
	)
	_write_review()
	print("Godot Cantina mood A/B proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_baseline_scene(name: String, offset: Vector3) -> Node3D:
	var root := _base_scene(name, Color("#c89555"), Color("#8ea7b8"), 0.8)
	_add_baseline_context(root, offset)
	_add_model(root, CANTINA_ENTRANCE_GLB, "cantina_entrance_glb", offset + Vector3(0, 0, 0), Vector3(0, 180, 0), 1.0)
	_add_player_scale(root, offset + Vector3(-1.9, 0, -2.0), "player_scale_left")
	_add_player_scale(root, offset + Vector3(1.7, 0, -1.75), "droid_waiting_right", Color("#b99b63"), Color("#6d5a38"))
	_add_baseline_lighting_and_camera(root, offset + Vector3(0, 1.05, 0.05), 6.4)
	return root


func _build_mood_scene(name: String, offset: Vector3) -> Node3D:
	var root := _base_scene(name, Color("#a36a31"), Color("#6d8790"), 0.42)
	_add_mood_context(root, offset)
	_add_model(root, CANTINA_ENTRANCE_GLB, "cantina_entrance_glb", offset + Vector3(0, 0, 0), Vector3(0, 180, 0), 1.0)
	_add_doorway_shadow(root, offset)
	_add_clutter_and_grime(root, offset)
	_add_player_scale(root, offset + Vector3(-1.9, 0, -2.0), "player_scale_left", Color("#e2e6df"), Color("#aeb8bb"))
	_add_player_scale(root, offset + Vector3(1.75, 0, -1.72), "droid_waiting_right", Color("#b99b63"), Color("#6d5a38"))
	_add_mood_lighting_and_camera(root, offset + Vector3(0, 1.05, 0.05), 6.4)
	return root


func _build_side_by_side_scene() -> Node3D:
	var root := _base_scene("CantinaMoodSideBySide", Color("#a36a31"), Color("#778d95"), 0.5)
	_build_side_half(root, Vector3(-3.9, 0, 0), false)
	_build_side_half(root, Vector3(3.9, 0, 0), true)
	_add_side_by_side_lighting_and_camera(root)
	return root


func _build_side_half(root: Node3D, offset: Vector3, mood: bool) -> void:
	if mood:
		_add_mood_context(root, offset)
		_add_model(root, CANTINA_ENTRANCE_GLB, "mood_cantina_entrance_glb", offset, Vector3(0, 180, 0), 1.0)
		_add_doorway_shadow(root, offset)
		_add_clutter_and_grime(root, offset)
		_add_player_scale(root, offset + Vector3(-1.9, 0, -2.0), "mood_player_scale")
		_add_player_scale(root, offset + Vector3(1.75, 0, -1.72), "mood_droid_waiting", Color("#b99b63"), Color("#6d5a38"))
	else:
		_add_baseline_context(root, offset)
		_add_model(root, CANTINA_ENTRANCE_GLB, "baseline_cantina_entrance_glb", offset, Vector3(0, 180, 0), 1.0)
		_add_player_scale(root, offset + Vector3(-1.9, 0, -2.0), "baseline_player_scale")
		_add_player_scale(root, offset + Vector3(1.7, 0, -1.75), "baseline_droid_waiting", Color("#b99b63"), Color("#6d5a38"))


func _add_baseline_context(root: Node3D, offset: Vector3) -> void:
	_add_box(root, "dust_plane", offset + Vector3(0, -0.05, 0), Vector3(10, 0.08, 7), Color("#c89555"))


func _add_mood_context(root: Node3D, offset: Vector3) -> void:
	_add_box(root, "sunbaked_dust_plane", offset + Vector3(0, -0.055, 0), Vector3(10, 0.08, 7), Color("#b87938"))
	_add_box(root, "threshold_shadow_pool", offset + Vector3(0, 0.01, -0.45), Vector3(3.4, 0.03, 1.7), Color("#49301f"))
	_add_box(root, "left_dust_berm", offset + Vector3(-3.65, 0.12, -0.8), Vector3(1.8, 0.22, 0.75), Color("#9a6835"))
	_add_box(root, "right_dust_berm", offset + Vector3(3.4, 0.12, -0.45), Vector3(1.6, 0.22, 0.7), Color("#9a6835"))


func _add_doorway_shadow(root: Node3D, offset: Vector3) -> void:
	_add_box(root, "deep_cantina_interior_shadow", offset + Vector3(0, 1.15, 1.12), Vector3(2.15, 2.05, 0.1), Color("#161516"))
	_add_box(root, "warm_inner_door_glow", offset + Vector3(0, 1.1, 1.04), Vector3(1.34, 1.38, 0.06), Color("#d88637"))
	_add_box(root, "cool_scanner_glow_pad", offset + Vector3(1.42, 1.0, -0.56), Vector3(0.16, 0.62, 0.08), Color("#27d7ff"))


func _add_clutter_and_grime(root: Node3D, offset: Vector3) -> void:
	var rust := Color("#5c3d26")
	var dark := Color("#211915")
	var metal := Color("#555d62")
	var wire := Color("#2b3135")
	var sign_red := Color("#8f2e24")
	_add_box(root, "left_pipe_vertical_a", offset + Vector3(-2.68, 1.02, -0.52), Vector3(0.08, 1.5, 0.08), metal)
	_add_box(root, "left_pipe_vertical_b", offset + Vector3(-2.48, 0.85, -0.52), Vector3(0.07, 1.18, 0.07), metal)
	_add_box(root, "left_pipe_cross", offset + Vector3(-2.58, 1.58, -0.52), Vector3(0.48, 0.07, 0.07), metal)
	_add_box(root, "right_utility_box", offset + Vector3(2.62, 0.56, -0.64), Vector3(0.44, 0.54, 0.24), dark)
	_add_box(root, "right_utility_lamp", offset + Vector3(2.62, 0.88, -0.78), Vector3(0.22, 0.1, 0.06), Color("#ffb14a"))
	_add_box(root, "coil_wire_a", offset + Vector3(2.2, 0.92, -0.66), Vector3(0.72, 0.055, 0.055), wire)
	_add_box(root, "coil_wire_b", offset + Vector3(2.15, 0.76, -0.66), Vector3(0.58, 0.045, 0.045), wire)
	_add_box(root, "left_crate_low", offset + Vector3(-2.75, 0.26, -1.5), Vector3(0.56, 0.52, 0.48), Color("#7b5631"))
	_add_box(root, "left_crate_lid", offset + Vector3(-2.75, 0.55, -1.5), Vector3(0.62, 0.08, 0.54), Color("#a0713a"))
	_add_box(root, "right_scrap_block", offset + Vector3(2.92, 0.22, -1.35), Vector3(0.72, 0.42, 0.36), Color("#3e4448"))
	_add_box(root, "right_scrap_red_panel", offset + Vector3(2.92, 0.47, -1.54), Vector3(0.54, 0.08, 0.04), sign_red)
	_add_box(root, "wall_grime_left_low", offset + Vector3(-1.95, 0.68, -0.62), Vector3(0.5, 0.08, 0.045), rust)
	_add_box(root, "wall_grime_left_mid", offset + Vector3(-1.32, 1.34, -0.62), Vector3(0.44, 0.08, 0.045), rust)
	_add_box(root, "wall_grime_right_low", offset + Vector3(1.86, 0.72, -0.62), Vector3(0.46, 0.08, 0.045), rust)
	_add_box(root, "wall_grime_right_high", offset + Vector3(1.25, 1.62, -0.62), Vector3(0.54, 0.08, 0.045), rust)
	_add_box(root, "overdoor_soot_band", offset + Vector3(0, 2.03, -0.64), Vector3(2.05, 0.1, 0.05), Color("#36251b"))
	_add_box(root, "tiny_side_sign", offset + Vector3(-2.25, 1.32, -0.62), Vector3(0.3, 0.18, 0.05), sign_red)


func _base_scene(name: String, ambient: Color, background: Color, ambient_energy: float) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient.lightened(0.12)
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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


func _add_baseline_lighting_and_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
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

	_add_camera(root, target, camera_size)


func _add_mood_lighting_and_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "LowWarmExteriorSun"
	sun.rotation_degrees = Vector3(-28, -48, -8)
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 2.8
	sun.shadow_enabled = true
	root.add_child(sun)

	var doorway := OmniLight3D.new()
	doorway.name = "DoorwayAmberSpill"
	doorway.position = target + Vector3(0, 0.6, 0.82)
	doorway.light_color = Color("#ffad55")
	doorway.light_energy = 0.95
	doorway.omni_range = 4.2
	root.add_child(doorway)

	var scanner := OmniLight3D.new()
	scanner.name = "ScannerCoolPing"
	scanner.position = target + Vector3(1.35, 0.25, -0.55)
	scanner.light_color = Color("#27d7ff")
	scanner.light_energy = 0.32
	scanner.omni_range = 2.2
	root.add_child(scanner)

	_add_camera(root, target, camera_size)


func _add_side_by_side_lighting_and_camera(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SideBySideWarmSun"
	sun.rotation_degrees = Vector3(-36, -42, -8)
	sun.light_color = Color("#ffd5a0")
	sun.light_energy = 2.45
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "SideBySideSoftFill"
	fill.position = Vector3(0, 5, -3)
	fill.light_energy = 0.25
	fill.omni_range = 13.0
	root.add_child(fill)

	_add_camera(root, Vector3(0, 1.15, 0.0), 12.2)


func _add_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
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
	mat.roughness = 0.92
	if color == Color("#27d7ff") or color == Color("#ff7a2c") or color == Color("#ffb14a") or color == Color("#d88637"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.1
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
	lines.append("# Cantina Mood A/B v1")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_cantina_mood_ab_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test the candidate Cantina material/lighting/clutter mood pass without changing the kept entrance model.")
	lines.append("")
	lines.append("Source GLB:")
	lines.append("")
	lines.append("```text")
	lines.append(CANTINA_ENTRANCE_GLB)
	lines.append("```")
	lines.append("")
	lines.append("## Controlled Change")
	lines.append("")
	lines.append("Baseline:")
	lines.append("")
	lines.append("```text")
	lines.append("generated/godot_cantina_entrance_camera_v1/REVIEW.md")
	lines.append("```")
	lines.append("")
	lines.append("Changed variable:")
	lines.append("")
	lines.append("```text")
	lines.append("Lighting, material mood, exterior clutter, grime chips, and dim doorway context only.")
	lines.append("The imported entrance GLB is unchanged.")
	lines.append("```")
	lines.append("")
	lines.append("Kept fixed:")
	lines.append("")
	lines.append("- `blockbench_cantina_entrance_v1.glb` source model")
	lines.append("- entrance orientation")
	lines.append("- threshold/detector/sign gameplay read")
	lines.append("- camera family")
	lines.append("- private/friends blockcraft target")
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
	lines.append("## Initial Verdict")
	lines.append("")
	lines.append("Candidate keep.")
	lines.append("")
	lines.append("The mood pass improves the frontier-cantina read by adding warmer exterior light, a darker interior threshold, pipes, utility clutter, wall grime, and dust berms while preserving the same entrance GLB. The detector/sign/threshold still read from the camera.")
	lines.append("")
	lines.append("Caution: the extra clutter is still simple proof geometry. It should be converted into a small Blockbench exterior-clutter kit or normalized filler pass before runtime promotion.")
	lines.append("")
	lines.append("Visual-inspection note: the side-by-side camera perspective can make screen left/right ambiguous. Treat `cantina_mood_baseline_control` and `cantina_mood_warm_grime_pass` as the authoritative comparison captures.")
	lines.append("")
	lines.append("## Next One-Variable Recommendation")
	lines.append("")
	lines.append("Keep the mood lighting and clutter composition as a candidate baseline, then change only the no-droids sign workflow: cube-only sign versus texture/manual Blockbench sign panel.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
