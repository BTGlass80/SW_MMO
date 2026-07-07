extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/meshy_eval_v0/godot_proof"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const MESHY_GLB := "res://docs/gpt/asset_factory/generated/meshy_eval_v0/meshy_cantina_service_terminal_v0/model.glb"
const MESHY_VOXEL_GLB := "res://docs/gpt/asset_factory/generated/meshy_eval_v0/meshy_cantina_service_terminal_voxel_lowpoly_v1/model.glb"
const MESHY5_GLB := "res://docs/gpt/asset_factory/generated/meshy_eval_v0/meshy_cantina_service_terminal_meshy5_draft_v1/model.glb"
const MESHY5_REFINED_GLB := "res://docs/gpt/asset_factory/generated/meshy_eval_v0/meshy_cantina_service_terminal_meshy5_draft_v1_refine_v1/model.glb"
const BLOCKBENCH_UTILITY_GLB := "res://docs/gpt/asset_factory/generated/blockbench_cantina_exterior_clutter_v1/glb/cantina_utility_box_v1.glb"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"meshy_service_terminal_geometry",
		_build_meshy_scene("MeshyServiceTerminalGeometry", Vector3.ZERO, MESHY_GLB),
		"Meshy preview GLB in a simple Cantina wall context. Materials are a neutral preview tint; this evaluates geometry only."
	)
	await _save_and_capture(
		"meshy_voxel_lowpoly_geometry",
		_build_meshy_scene("MeshyVoxelLowpolyGeometry", Vector3.ZERO, MESHY_VOXEL_GLB),
		"Strict cuboid/voxel prompt GLB in the same Cantina wall context. Same lowpoly route, changed prompt only."
	)
	await _save_and_capture(
		"meshy5_draft_geometry",
		_build_meshy_scene("Meshy5DraftGeometry", Vector3.ZERO, MESHY5_GLB),
		"Meshy 5 standard preview in the same Cantina wall context. This tests the cheap draft/option-mining route rather than the lowpoly style route."
	)
	await _save_and_capture(
		"meshy5_refined_material_geometry",
		_build_meshy_scene("Meshy5RefinedMaterialGeometry", Vector3.ZERO, MESHY5_REFINED_GLB, false),
		"Meshy 5 refined GLB with imported materials preserved. This evaluates the texture/refine step rather than pure geometry."
	)
	await _save_and_capture(
		"meshy_rotation_contact_sheet",
		_build_rotation_contact_scene("MeshyRotationContactSheet", MESHY_GLB),
		"Orientation contact sheet: Meshy GLB at 0, 90, 180, and 270 degree yaw. This checks which face actually carries the generated detail."
	)
	await _save_and_capture(
		"meshy_voxel_rotation_contact_sheet",
		_build_rotation_contact_scene("MeshyVoxelRotationContactSheet", MESHY_VOXEL_GLB),
		"Orientation contact sheet for the stricter cuboid/voxel lowpoly prompt at 0, 90, 180, and 270 degree yaw."
	)
	await _save_and_capture(
		"meshy5_rotation_contact_sheet",
		_build_rotation_contact_scene("Meshy5RotationContactSheet", MESHY5_GLB),
		"Orientation contact sheet for the Meshy 5 draft-selection probe at 0, 90, 180, and 270 degree yaw."
	)
	await _save_and_capture(
		"meshy5_refined_rotation_contact_sheet",
		_build_rotation_contact_scene("Meshy5RefinedRotationContactSheet", MESHY5_REFINED_GLB, false),
		"Orientation contact sheet for the refined Meshy 5 textured GLB at 0, 90, 180, and 270 degree yaw with imported materials preserved."
	)
	await _save_and_capture(
		"meshy_lowpoly_prompt_ab",
		_build_lowpoly_prompt_ab_scene(),
		"Left: first lowpoly prompt. Right: stricter cuboid/voxel lowpoly prompt. This isolates prompt wording while keeping the Meshy lowpoly route."
	)
	await _save_and_capture(
		"meshy_vs_blockbench_utility_ab",
		_build_ab_scene(),
		"Left: existing Blockbench utility module. Right: Meshy preview service terminal. This tests whether Meshy adds useful medium-detail shape language."
	)
	await _save_and_capture(
		"meshy_three_way_blockbench_ab",
		_build_three_way_scene(),
		"Left: existing Blockbench utility module. Center: first Meshy lowpoly prompt. Right: strict voxel lowpoly prompt."
	)
	await _save_and_capture(
		"meshy_route_four_way_ab",
		_build_four_way_scene(),
		"Left to right: Blockbench utility, first lowpoly prompt, strict lowpoly/voxel prompt, and Meshy 5 draft probe."
	)
	await _save_and_capture(
		"meshy5_preview_vs_refined_material_ab",
		_build_meshy5_refine_ab_scene(),
		"Left: Meshy 5 preview material. Right: Meshy 5 refined material. This isolates the refine/texture value after choosing a geometry seed."
	)
	_write_review()
	print("Godot Meshy eval proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_meshy_scene(name: String, offset: Vector3, glb_path: String, apply_tint: bool = true) -> Node3D:
	var root := _base_scene(name, Color("#6f4426"), Color("#6d8790"), 0.38)
	_add_wall_context(root, offset)
	var holder := _add_model(root, glb_path, "meshy_service_terminal_glb", offset + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	if apply_tint:
		_tint_model(holder, Color("#b8a88f"), Color("#26313a"))
	_add_box(root, "cyan_scanner_hint", offset + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_mood_lighting_and_camera(root, offset + Vector3(0, 0.9, -0.15), 4.2)
	return root


func _build_rotation_contact_scene(name: String, glb_path: String, apply_tint: bool = true) -> Node3D:
	var root := _base_scene(name, Color("#6f4426"), Color("#738991"), 0.38)
	var rotations := [0, 90, 180, 270]
	for i in range(rotations.size()):
		var offset := Vector3((float(i) - 1.5) * 2.45, 0, 0)
		_add_box(root, "floor_%s" % i, offset + Vector3(0, -0.04, 0), Vector3(2.0, 0.08, 1.6), Color("#2e2520"))
		var holder := _add_model(root, glb_path, "meshy_yaw_%s" % rotations[i], offset + Vector3(0, 0.86, -0.1), Vector3(0, rotations[i], 0), 1.08)
		if apply_tint:
			_tint_model(holder, Color("#b8a88f"), Color("#26313a"))
		_add_floor_label_blocks(root, offset + Vector3(0, 0.08, -0.92), "%s" % rotations[i])
	_add_side_by_side_lighting_and_camera(root)
	return root


func _build_blockbench_scene(name: String, offset: Vector3) -> Node3D:
	var root := _base_scene(name, Color("#6f4426"), Color("#6d8790"), 0.38)
	_add_wall_context(root, offset)
	_add_model(root, BLOCKBENCH_UTILITY_GLB, "blockbench_utility_glb", offset + Vector3(0, 0.2, -0.36), Vector3.ZERO, 1.55)
	_add_mood_lighting_and_camera(root, offset + Vector3(0, 0.9, -0.15), 4.2)
	return root


func _build_ab_scene() -> Node3D:
	var root := _base_scene("MeshyVsBlockbenchUtilityAB", Color("#6f4426"), Color("#738991"), 0.38)
	var left := Vector3(-2.55, 0, 0)
	var right := Vector3(2.55, 0, 0)
	_add_wall_context(root, left)
	_add_wall_context(root, right)
	_add_model(root, BLOCKBENCH_UTILITY_GLB, "blockbench_utility_glb", left + Vector3(0, 0.2, -0.36), Vector3.ZERO, 1.55)
	var holder := _add_model(root, MESHY_GLB, "meshy_service_terminal_glb", right + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_tint_model(holder, Color("#b8a88f"), Color("#26313a"))
	_add_box(root, "candidate_cyan_scanner_hint", right + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_side_by_side_lighting_and_camera(root)
	return root


func _build_lowpoly_prompt_ab_scene() -> Node3D:
	var root := _base_scene("MeshyLowpolyPromptAB", Color("#6f4426"), Color("#738991"), 0.38)
	var left := Vector3(-2.55, 0, 0)
	var right := Vector3(2.55, 0, 0)
	_add_wall_context(root, left)
	_add_wall_context(root, right)
	var original := _add_model(root, MESHY_GLB, "meshy_original_lowpoly_glb", left + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_tint_model(original, Color("#b8a88f"), Color("#26313a"))
	var voxel := _add_model(root, MESHY_VOXEL_GLB, "meshy_voxel_lowpoly_glb", right + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_tint_model(voxel, Color("#b8a88f"), Color("#26313a"))
	_add_box(root, "original_scanner_hint", left + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_box(root, "voxel_scanner_hint", right + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_side_by_side_lighting_and_camera(root)
	return root


func _build_three_way_scene() -> Node3D:
	var root := _base_scene("MeshyThreeWayBlockbenchAB", Color("#6f4426"), Color("#738991"), 0.38)
	var left := Vector3(-5.1, 0, 0)
	var center := Vector3(0, 0, 0)
	var right := Vector3(5.1, 0, 0)
	_add_wall_context(root, left)
	_add_wall_context(root, center)
	_add_wall_context(root, right)
	_add_model(root, BLOCKBENCH_UTILITY_GLB, "blockbench_utility_glb", left + Vector3(0, 0.2, -0.36), Vector3.ZERO, 1.55)
	var original := _add_model(root, MESHY_GLB, "meshy_original_lowpoly_glb", center + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_tint_model(original, Color("#b8a88f"), Color("#26313a"))
	var voxel := _add_model(root, MESHY_VOXEL_GLB, "meshy_voxel_lowpoly_glb", right + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_tint_model(voxel, Color("#b8a88f"), Color("#26313a"))
	_add_box(root, "original_scanner_hint", center + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_box(root, "voxel_scanner_hint", right + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_wide_lighting_and_camera(root)
	return root


func _build_four_way_scene() -> Node3D:
	var root := _base_scene("MeshyRouteFourWayAB", Color("#6f4426"), Color("#738991"), 0.38)
	var offsets := [
		Vector3(-7.65, 0, 0),
		Vector3(-2.55, 0, 0),
		Vector3(2.55, 0, 0),
		Vector3(7.65, 0, 0),
	]
	for offset in offsets:
		_add_wall_context(root, offset)
	_add_model(root, BLOCKBENCH_UTILITY_GLB, "blockbench_utility_glb", offsets[0] + Vector3(0, 0.2, -0.36), Vector3.ZERO, 1.55)
	var original := _add_model(root, MESHY_GLB, "meshy_original_lowpoly_glb", offsets[1] + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_tint_model(original, Color("#b8a88f"), Color("#26313a"))
	var voxel := _add_model(root, MESHY_VOXEL_GLB, "meshy_voxel_lowpoly_glb", offsets[2] + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_tint_model(voxel, Color("#b8a88f"), Color("#26313a"))
	var meshy5 := _add_model(root, MESHY5_GLB, "meshy5_draft_glb", offsets[3] + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_tint_model(meshy5, Color("#b8a88f"), Color("#26313a"))
	_add_box(root, "original_scanner_hint", offsets[1] + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_box(root, "voxel_scanner_hint", offsets[2] + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_box(root, "meshy5_scanner_hint", offsets[3] + Vector3(0.72, 1.18, -0.68), Vector3(0.16, 0.16, 0.06), Color("#27d7ff"))
	_add_extra_wide_lighting_and_camera(root)
	return root


func _build_meshy5_refine_ab_scene() -> Node3D:
	var root := _base_scene("Meshy5PreviewVsRefinedMaterialAB", Color("#6f4426"), Color("#738991"), 0.38)
	var left := Vector3(-2.55, 0, 0)
	var right := Vector3(2.55, 0, 0)
	_add_wall_context(root, left)
	_add_wall_context(root, right)
	_add_model(root, MESHY5_GLB, "meshy5_preview_glb", left + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_add_model(root, MESHY5_REFINED_GLB, "meshy5_refined_glb", right + Vector3(0, 0.86, -0.34), Vector3.ZERO, 1.08)
	_add_side_by_side_lighting_and_camera(root)
	return root


func _add_wall_context(root: Node3D, offset: Vector3) -> void:
	_add_box(root, "dust_floor", offset + Vector3(0, -0.04, 0), Vector3(3.7, 0.08, 2.2), Color("#2e2520"))
	_add_box(root, "cantina_wall_panel", offset + Vector3(0, 1.08, 0.08), Vector3(2.65, 2.1, 0.18), Color("#a56d39"))
	_add_box(root, "lower_shadow_strip", offset + Vector3(0, 0.34, -0.03), Vector3(2.55, 0.18, 0.08), Color("#38231a"))
	_add_box(root, "top_plaster_cap", offset + Vector3(0, 2.16, 0.0), Vector3(2.8, 0.18, 0.25), Color("#dfba72"))
	_add_box(root, "floor_shadow", offset + Vector3(0, 0.02, -0.78), Vector3(2.8, 0.03, 0.8), Color("#171312"))


func _add_floor_label_blocks(root: Node3D, position: Vector3, label: String) -> void:
	for i in range(label.length()):
		_add_box(root, "label_%s_%s" % [label, i], position + Vector3(float(i) * 0.14 - 0.12, 0, 0), Vector3(0.09, 0.08, 0.09), Color("#27d7ff"))


func _base_scene(name: String, ambient: Color, background: Color, ambient_energy: float) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient.lightened(0.1)
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


func _tint_model(node: Node, base: Color, dark: Color) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = base
		mat.roughness = 0.95
		mesh_node.material_override = mat
	for child in node.get_children():
		_tint_model(child, base, dark)


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


func _add_mood_lighting_and_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "WarmReviewSun"
	sun.rotation_degrees = Vector3(-32, -42, -8)
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 2.35
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "SoftInteriorFill"
	fill.position = target + Vector3(0, 1.2, 1.2)
	fill.light_color = Color("#ffb45a")
	fill.light_energy = 0.6
	fill.omni_range = 5.2
	root.add_child(fill)

	_add_camera(root, target, camera_size)


func _add_side_by_side_lighting_and_camera(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SideBySideWarmSun"
	sun.rotation_degrees = Vector3(-34, -42, -8)
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 2.35
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "SideBySideFill"
	fill.position = Vector3(0, 2.8, 2.2)
	fill.light_color = Color("#ffb45a")
	fill.light_energy = 0.65
	fill.omni_range = 9.0
	root.add_child(fill)

	_add_camera(root, Vector3(0, 0.92, -0.12), 7.6)


func _add_wide_lighting_and_camera(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "WideWarmSun"
	sun.rotation_degrees = Vector3(-34, -42, -8)
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 2.35
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "WideFill"
	fill.position = Vector3(0, 3.0, 2.4)
	fill.light_color = Color("#ffb45a")
	fill.light_energy = 0.7
	fill.omni_range = 12.0
	root.add_child(fill)

	_add_camera(root, Vector3(0, 0.92, -0.12), 11.8)


func _add_extra_wide_lighting_and_camera(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "ExtraWideWarmSun"
	sun.rotation_degrees = Vector3(-34, -42, -8)
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 2.35
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "ExtraWideFill"
	fill.position = Vector3(0, 3.2, 2.7)
	fill.light_color = Color("#ffb45a")
	fill.light_energy = 0.75
	fill.omni_range = 16.0
	root.add_child(fill)

	_add_camera(root, Vector3(0, 0.92, -0.12), 16.2)


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
	mat.roughness = 0.9
	if color == Color("#27d7ff"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
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
	lines.append("# Godot Meshy Evaluation v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_meshy_eval_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test whether one Meshy text-to-3D preview changes the asset pipeline for Cantina set dressing.")
	lines.append("")
	lines.append("## Controlled Change")
	lines.append("")
	lines.append("Baseline: `blockbench_cantina_exterior_clutter_v1` utility module and `blockbench_cantina_bar_booth_bay_v1` interior style.")
	lines.append("")
	lines.append("Changed variable: manual Blockbench utility/clutter geometry -> one Meshy preview GLB, material-tinted in Godot for geometry evaluation.")
	lines.append("")
	lines.append("Import note: the orientation contact sheet shows the most useful generated detail at 0 and 270 degree yaw. The comparison scene uses 0 degree yaw and leaves the GLB source unchanged.")
	lines.append("")
	lines.append("## Source")
	lines.append("")
	lines.append("`generated/meshy_eval_v0/meshy_cantina_service_terminal_v0/model.glb`")
	lines.append("`generated/meshy_eval_v0/meshy_cantina_service_terminal_voxel_lowpoly_v1/model.glb`")
	lines.append("`generated/meshy_eval_v0/meshy_cantina_service_terminal_meshy5_draft_v1/model.glb`")
	lines.append("`generated/meshy_eval_v0/meshy_cantina_service_terminal_meshy5_draft_v1_refine_v1/model.glb`")
	lines.append("")
	lines.append("The two lowpoly previews consumed 20 Meshy credits each. The Meshy 5 preview consumed 5 credits through the API, and the refine consumed 10 credits. `gltf-transform validate` found no errors or warnings for the lowpoly GLBs, only a default matrix info; the Meshy 5 preview GLB has no errors or warnings and one unused TEXCOORD info; the refined GLB has no errors or warnings and one default matrix info.")
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
	lines.append("Candidate lesson keep, not a direct runtime keep yet.")
	lines.append("")
	lines.append("Meshy generated richer greeble shape language than our utility-box blocks with one prompt and clean GLB validation. It is not blockcraft-cohesive enough to replace authored modules directly, and the preview has no materials, but it is useful as a medium-detail reference or cleanup candidate.")
	lines.append("")
	lines.append("## Next One-Variable Recommendation")
	lines.append("")
	lines.append("Run one image/reference-guided or refine test only after deciding whether this geometry is worth spending more credits. If not, rebuild its best features in Blockbench: asymmetrical wall plate, cable bundle, vent stack, and inset service box.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
