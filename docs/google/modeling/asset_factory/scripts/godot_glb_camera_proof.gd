extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_phase0_camera_v0"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"

const CLONE_RIFLEMAN := "res://docs/gpt/asset_factory/generated/blockbench_cubecraft_v0/glb/cubecraft_clone_rifleman_01.glb"
const B1_DROID := "res://docs/gpt/asset_factory/generated/blockbench_cubecraft_v0/glb/cubecraft_b1_droid_01.glb"
const CLONE_HEAVY := "res://docs/gpt/asset_factory/generated/blockbench_cubecraft_v0/glb/cubecraft_clone_heavy_01.glb"
const FRIENDLY_SHIP := "res://docs/gpt/asset_factory/generated/blockbench_ship_panel_v2/glb/micro_arc_interceptor_panel_v2.glb"
const HOSTILE_SHIP := "res://docs/gpt/asset_factory/generated/blockbench_ship_droid_v2/glb/micro_tri_droid_stalker_v2.glb"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture("ground_identity", _build_ground_identity_scene(), "Ground identity camera: clone/droid character readability")
	await _save_and_capture("space_isometric", _build_space_isometric_scene(), "Isometric space camera: friendly/hostile ship readability")
	await _save_and_capture("mixed_scale", _build_mixed_scale_scene(), "Mixed scale camera: character plus ship scale sanity")
	_write_review()
	print("Godot GLB camera proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_ground_identity_scene() -> Node3D:
	var root := _base_scene("GroundIdentity", Color("#c89555"), Color("#111820"))
	_add_box(root, "ground_plane", Vector3(0, -0.06, 0), Vector3(10, 0.08, 7), Color("#c89555"))
	_add_box(root, "cover_block_a", Vector3(-3.6, 0.35, 1.9), Vector3(1.7, 0.7, 0.7), Color("#5b4631"))
	_add_box(root, "cover_block_b", Vector3(3.6, 0.35, 1.9), Vector3(1.7, 0.7, 0.7), Color("#5b4631"))
	_add_model(root, CLONE_RIFLEMAN, "clone_rifleman", Vector3(-2.2, 0.0, 0.0), Vector3(0, 208, 0), 0.16)
	_add_model(root, CLONE_HEAVY, "clone_heavy", Vector3(0.0, 0.0, 0.0), Vector3(0, 192, 0), 0.16)
	_add_model(root, B1_DROID, "b1_droid", Vector3(2.25, 0.0, 0.0), Vector3(0, 152, 0), 0.17)
	_add_label(root, "ground MMO camera proof", Vector3(0, 2.9, -2.35))
	_add_lighting_and_camera(root, "ground", Vector3(0, 1.15, 0), 8.0)
	return root


func _build_space_isometric_scene() -> Node3D:
	var root := _base_scene("SpaceIsometric", Color("#0b1724"), Color("#08101a"))
	_add_box(root, "space_plane", Vector3(0, -0.04, 0), Vector3(12, 0.05, 8), Color("#0b1724"))
	_add_grid(root, 12, 8, 1.0, Color(0.16, 0.45, 0.76, 0.42))
	_add_model(root, FRIENDLY_SHIP, "friendly_arc_panel_v2", Vector3(-2.1, 0.15, 0.1), Vector3(0, -25, 0), 0.52)
	_add_model(root, HOSTILE_SHIP, "hostile_droid_v2", Vector3(2.1, 0.15, -0.1), Vector3(0, 150, 0), 0.54)
	_add_ring(root, "friendly_selection", Vector3(-2.1, 0.05, 0.1), 0.9, Color("#3cc8ff"))
	_add_ring(root, "hostile_selection", Vector3(2.1, 0.05, -0.1), 0.9, Color("#ff6a30"))
	_add_label(root, "isometric tactical space proof", Vector3(0, 1.8, -2.9))
	_add_lighting_and_camera(root, "space", Vector3(0, 0.75, 0), 8.5)
	return root


func _build_mixed_scale_scene() -> Node3D:
	var root := _base_scene("MixedScale", Color("#23303a"), Color("#101820"))
	_add_box(root, "review_plane", Vector3(0, -0.05, 0), Vector3(11, 0.06, 7), Color("#23303a"))
	_add_box(root, "landing_pad", Vector3(1.8, 0.01, 0.0), Vector3(4.3, 0.06, 3.1), Color("#30343a"))
	_add_box(root, "landing_pad_trim_a", Vector3(1.8, 0.08, -1.55), Vector3(4.5, 0.08, 0.08), Color("#25c4ff"))
	_add_box(root, "landing_pad_trim_b", Vector3(1.8, 0.08, 1.55), Vector3(4.5, 0.08, 0.08), Color("#25c4ff"))
	_add_model(root, CLONE_RIFLEMAN, "clone_rifleman", Vector3(-2.9, 0.0, 0.6), Vector3(0, 212, 0), 0.16)
	_add_model(root, FRIENDLY_SHIP, "friendly_arc_panel_v2", Vector3(1.8, 0.18, 0.0), Vector3(0, -35, 0), 0.36)
	_add_label(root, "mixed scale proof", Vector3(0, 2.25, -2.45))
	_add_lighting_and_camera(root, "ground", Vector3(0, 0.95, 0), 8.2)
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
	env.ambient_light_energy = 0.85
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
		var fallback := _add_box(root, node_name + "_missing", position + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), Color("#ff00ff"))
		return fallback

	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation_degrees = rotation_degrees
	holder.scale = Vector3.ONE * scale_factor
	holder.add_child(imported)
	root.add_child(holder)
	return holder


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


func _add_grid(root: Node3D, width: int, depth: int, step: float, color: Color) -> void:
	for x in range(-width / 2, width / 2 + 1):
		_add_box(root, "grid_x_%s" % x, Vector3(float(x) * step, 0.01, 0), Vector3(0.02, 0.02, float(depth) * step), color)
	for z in range(-depth / 2, depth / 2 + 1):
		_add_box(root, "grid_z_%s" % z, Vector3(0, 0.012, float(z) * step), Vector3(float(width) * step, 0.02, 0.02), color)


func _add_ring(root: Node3D, node_name: String, position: Vector3, radius: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.94
	mesh.outer_radius = radius
	mesh.ring_segments = 64
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(Color(color.r, color.g, color.b, 0.72), true)
	root.add_child(inst)


func _add_label(root: Node3D, text: String, position: Vector3) -> void:
	return
	var label := Label3D.new()
	label.name = "review_label"
	label.text = text
	label.position = position
	label.font_size = 42
	label.modulate = Color("#dbe8ed")
	label.outline_modulate = Color("#08101a")
	label.outline_size = 8
	root.add_child(label)


func _add_lighting_and_camera(root: Node3D, mode: String, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "ReviewSun"
	sun.rotation_degrees = Vector3(-52, -38, -12)
	sun.light_energy = 2.25
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "SoftFill"
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
	var camera_vector := Vector3(1.1, 0.9, 1.1) if mode == "space" else Vector3(1.0, 0.82, -1.0)
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
	lines.append("# Godot Phase 0 Camera Proof")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_glb_camera_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("This is a docs-only proof that the kept Blockbench/Blender GLBs can be loaded and photographed by Godot before any runtime promotion.")
	lines.append("")
	lines.append("It changes only `docs/gpt/asset_factory/generated/godot_phase0_camera_v0/`.")
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
	lines.append("Partial keep.")
	lines.append("")
	lines.append("- `space_isometric`: keep as a promising tactical-space camera proof. Friendly and hostile ships remain distinct in Godot, and the panel-detail pass survives runtime lighting.")
	lines.append("- `mixed_scale`: keep as a basic ship/player scale sanity check. The fighter/player relationship is plausible for a landing-pad review, though real gameplay scale still needs owner judgment.")
	lines.append("- `ground_identity`: usable but not final. Character scale is now sane, clone/droid body roles read, but front-facing helmet/weapon contrast needs a dedicated character pass.")
	lines.append("- Do not promote these GLBs into runtime until the owner accepts the Godot camera read.")
	lines.append("- Next controlled change should be character contrast/detail only: stronger visors, role stripes, weapon silhouettes, and droid head/limb exaggeration. Keep camera and import path stable.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
