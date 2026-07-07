extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_cantina_bar_booth_bay_v1"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const BAR_BAY_GLB := "res://docs/gpt/asset_factory/generated/blockbench_cantina_bar_booth_bay_v1/glb/blockbench_cantina_bar_booth_bay_v1.glb"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"bar_booth_baseline_procedural_control",
		_build_baseline_scene("BarBoothBaselineProceduralControl", Vector3.ZERO),
		"Control capture: recreated Godot-procedural bar/booth proof from cantina_terrain_kit_v0."
	)
	await _save_and_capture(
		"bar_booth_blockbench_candidate",
		_build_candidate_scene("BarBoothBlockbenchCandidate", Vector3.ZERO),
		"Candidate capture: imported Blockbench/Blender GLB with denser booth, bar, bottle, patron, and owner-booth details."
	)
	await _save_and_capture(
		"bar_booth_ab_pair",
		_build_ab_scene(),
		"Left/control: old procedural bay. Right/candidate: imported editable Blockbench bar/booth bay GLB."
	)
	_write_review()
	print("Godot Cantina bar/booth bay proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_baseline_scene(name: String, offset: Vector3) -> Node3D:
	var root := _base_scene(name, Color("#6f4426"), Color("#6d8790"), 0.34)
	_add_baseline_bar_booth(root, offset)
	_add_player_scale(root, offset + Vector3(0, 0, -1.92), "baseline_player_scale")
	_add_mood_lighting_and_camera(root, offset + Vector3(0, 0.95, 0.28), 6.0)
	return root


func _build_candidate_scene(name: String, offset: Vector3) -> Node3D:
	var root := _base_scene(name, Color("#6f4426"), Color("#6d8790"), 0.34)
	_add_model(root, BAR_BAY_GLB, "blockbench_bar_booth_bay_glb", offset, Vector3(0, 180, 0), 1.0)
	_add_player_scale(root, offset + Vector3(0, 0, -1.92), "candidate_player_scale")
	_add_mood_lighting_and_camera(root, offset + Vector3(0, 0.95, 0.28), 6.0)
	return root


func _build_ab_scene() -> Node3D:
	var root := _base_scene("BarBoothABPair", Color("#6f4426"), Color("#738991"), 0.36)
	var left := Vector3(-3.9, 0, 0)
	var right := Vector3(3.9, 0, 0)
	_add_baseline_bar_booth(root, left)
	_add_player_scale(root, left + Vector3(0, 0, -1.92), "control_player")
	_add_model(root, BAR_BAY_GLB, "candidate_bar_booth_bay_glb", right, Vector3(0, 180, 0), 1.0)
	_add_player_scale(root, right + Vector3(0, 0, -1.92), "candidate_player")
	_add_side_by_side_lighting_and_camera(root)
	return root


func _add_baseline_bar_booth(root: Node3D, offset: Vector3) -> void:
	_add_box(root, "floor_plate", offset + Vector3(0, 0.04, 0), Vector3(5.8, 0.08, 4.1), Color("#2e2520"))
	_add_box(root, "back_wall", offset + Vector3(0, 1.05, 1.72), Vector3(5.65, 2.1, 0.38), Color("#b98245"))
	_add_box(root, "bar_counter", offset + Vector3(0, 0.62, 1.0), Vector3(4.35, 0.65, 0.52), Color("#6f4426"))
	_add_box(root, "bar_top", offset + Vector3(0, 0.98, 0.94), Vector3(4.55, 0.16, 0.68), Color("#dfba72"))
	_add_box(root, "bottle_a", offset + Vector3(-1.55, 1.3, 1.48), Vector3(0.16, 0.45, 0.16), Color("#27d7ff"))
	_add_box(root, "bottle_b", offset + Vector3(-1.15, 1.22, 1.48), Vector3(0.14, 0.32, 0.14), Color("#ff7a2c"))
	_add_box(root, "bottle_c", offset + Vector3(1.45, 1.25, 1.48), Vector3(0.16, 0.38, 0.16), Color("#d7a736"))
	_add_box(root, "left_booth_back", offset + Vector3(-2.18, 0.58, -0.52), Vector3(0.36, 0.8, 1.65), Color("#963a32"))
	_add_box(root, "left_booth_seat", offset + Vector3(-1.72, 0.32, -0.52), Vector3(0.72, 0.28, 1.5), Color("#432a24"))
	_add_box(root, "right_booth_back", offset + Vector3(2.18, 0.58, -0.52), Vector3(0.36, 0.8, 1.65), Color("#963a32"))
	_add_box(root, "right_booth_seat", offset + Vector3(1.72, 0.32, -0.52), Vector3(0.72, 0.28, 1.5), Color("#432a24"))
	_add_cylinder(root, "left_table", offset + Vector3(-1.25, 0.48, -0.68), 0.38, 0.18, Color("#6f4426"))
	_add_cylinder(root, "right_table", offset + Vector3(1.25, 0.48, -0.68), 0.38, 0.18, Color("#6f4426"))
	_add_box(root, "warm_wall_strip", offset + Vector3(0, 1.75, 1.5), Vector3(3.2, 0.08, 0.04), Color("#d7a736"))


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


func _add_player_scale(root: Node3D, position: Vector3, node_name: String) -> void:
	_add_box(root, node_name + "_body", position + Vector3(0, 0.64, 0), Vector3(0.36, 0.82, 0.26), Color("#e6eceb"))
	_add_box(root, node_name + "_head", position + Vector3(0, 1.22, 0), Vector3(0.34, 0.3, 0.32), Color("#aeb8bb"))
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


func _add_cylinder(root: Node3D, node_name: String, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	root.add_child(inst)
	return inst


func _add_mood_lighting_and_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "WarmInteriorSun"
	sun.rotation_degrees = Vector3(-32, -42, -8)
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 2.35
	sun.shadow_enabled = true
	root.add_child(sun)

	var bar_fill := OmniLight3D.new()
	bar_fill.name = "WarmBarFill"
	bar_fill.position = target + Vector3(0, 0.8, 1.2)
	bar_fill.light_color = Color("#ffb45a")
	bar_fill.light_energy = 0.85
	bar_fill.omni_range = 5.2
	root.add_child(bar_fill)

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
	fill.name = "SideBySideBarFill"
	fill.position = Vector3(0, 3, 2.2)
	fill.light_color = Color("#ffb45a")
	fill.light_energy = 0.75
	fill.omni_range = 12.0
	root.add_child(fill)

	_add_camera(root, Vector3(0, 0.95, 0.25), 12.0)


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
	if color == Color("#27d7ff") or color == Color("#ff7a2c") or color == Color("#d7a736"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.75
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
	lines.append("# Godot Cantina Bar Booth Bay v1")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_cantina_bar_booth_bay_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test whether the `cantina_bar_booth_bay_01` Godot-procedural proof can move into the locked editable Blockbench/GLB lane while improving main-bar and curved-booth readability.")
	lines.append("")
	lines.append("## Controlled Change")
	lines.append("")
	lines.append("Baseline: `generated/cantina_terrain_kit_v0/REVIEW.md` (`cantina_bar_booth_bay_01`).")
	lines.append("")
	lines.append("Changed variable: Godot proof geometry -> imported Blockbench/Blender GLB with finer bar, booth, bottle, patron, and owner-booth detail.")
	lines.append("")
	lines.append("Source constraints:")
	lines.append("")
	lines.append("- high-tech bar stretches along one wall")
	lines.append("- booths line curved walls")
	lines.append("- room is dense with smugglers, hunters, clones, and varied patrons")
	lines.append("- main bar sits between entrance and back hallway in the room graph")
	lines.append("")
	lines.append("Import note: the Godot proof rotates the imported holder 180 degrees so the review camera sees the playable side of the bar wall. The GLB source model itself is unchanged.")
	lines.append("")
	lines.append("## Source GLB")
	lines.append("")
	lines.append("`generated/blockbench_cantina_bar_booth_bay_v1/glb/blockbench_cantina_bar_booth_bay_v1.glb`")
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
	lines.append("Candidate keep.")
	lines.append("")
	lines.append("The Blockbench candidate is busier and more readable than the old proof: the bar has service taps and panel rhythm, the booths imply a curved perimeter through stepped backs, and the owner/bartender proxy details reinforce the social-hub purpose.")
	lines.append("")
	lines.append("Caution: this is an identity module, not a final room. It still needs a connected multi-room composition with entrance, bandstand, and back hallway before buildings can be considered close to runtime-ready.")
	lines.append("")
	lines.append("## Next One-Variable Recommendation")
	lines.append("")
	lines.append("Convert the back hallway service module into Blockbench/GLB, then run a multi-room interior composition proof using entrance + bar/booth + hallway.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
