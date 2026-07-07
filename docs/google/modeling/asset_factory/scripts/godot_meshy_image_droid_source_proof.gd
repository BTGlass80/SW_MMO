extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/meshy_image_droid_v0"
const SOURCE_DIR := OUT_ROOT + "/source_reference"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const SCENE_DIR := OUT_ROOT + "/review_scenes"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"droid_source_three_quarter",
		_build_source_scene("DroidSourceThreeQuarter", Color("#f2f0e8"), true),
		"Deterministic blockcraft segmented service/battle droid source image for Meshy image-to-3D. This is original project-generated geometry, not external art."
	)
	_copy_capture_to_source_reference()
	await _save_and_capture(
		"droid_baseline_dark_review",
		_build_source_scene("DroidBaselineDarkReview", Color("#0b1017"), false),
		"Same deterministic droid under the darker asset-factory review lighting, used as the zero-credit baseline."
	)
	await _save_and_capture(
		"droid_pose_contact_sheet",
		_build_pose_sheet_scene(),
		"Rigid segmented droid pose sheet. This checks whether the hand-rolled lane is already sufficient for droids before spending Meshy credits."
	)
	_write_review()
	print("Godot Meshy image droid source proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SOURCE_DIR, CAPTURE_DIR, SCENE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _copy_capture_to_source_reference() -> void:
	var from_path := ProjectSettings.globalize_path(CAPTURE_DIR + "/droid_source_three_quarter.png")
	var to_path := ProjectSettings.globalize_path(SOURCE_DIR + "/blockcraft_segmented_droid_source.png")
	DirAccess.copy_absolute(from_path, to_path)


func _build_source_scene(name: String, background: Color, source_lighting: bool) -> Node3D:
	var root := _base_scene(name, background, source_lighting)
	var droid := _add_droid(root, "segmented_droid_source", Vector3.ZERO, "ready")
	droid.rotation_degrees = Vector3(0, -28, 0)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(2.3, 0.08, 2.0), Color("#d9c8a6") if source_lighting else Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.95, 0), 2.55, source_lighting)
	return root


func _build_pose_sheet_scene() -> Node3D:
	var root := _base_scene("DroidPoseContactSheet", Color("#0b1017"), false)
	var poses := ["idle", "ready", "scan", "cover"]
	for i in range(poses.size()):
		var offset := Vector3((float(i) - 1.5) * 1.18, 0, 0)
		var droid := _add_droid(root, "droid_%s" % poses[i], offset, poses[i])
		droid.rotation_degrees = Vector3(0, -24, 0)
		_add_floor(root, offset + Vector3(0, -0.06, 0), Vector3(0.95, 0.06, 0.95), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.82, 0), 4.6, false)
	return root


func _add_droid(root: Node3D, node_name: String, origin: Vector3, pose: String) -> Node3D:
	var droid := Node3D.new()
	droid.name = node_name
	droid.position = origin
	root.add_child(droid)

	var bone := Color("#d8ddd7")
	var bone_shadow := Color("#9ea7a5")
	var dark := Color("#15191d")
	var blue := Color("#2aa7d7")
	var amber := Color("#c49340")
	var red := Color("#a95e4d")

	var pelvis := _box("pelvis_block", Vector3(0, 0.82, 0), Vector3(0.42, 0.22, 0.28), bone_shadow)
	var chest := _box("ribbed_torso", Vector3(0, 1.18, 0), Vector3(0.52, 0.62, 0.34), bone)
	var chest_core := _box("cyan_core", Vector3(0, 1.19, -0.19), Vector3(0.16, 0.28, 0.045), blue)
	var head := _box("sensor_head", Vector3(0, 1.68, -0.03), Vector3(0.46, 0.28, 0.34), bone)
	var visor := _box("sensor_visor", Vector3(0, 1.68, -0.23), Vector3(0.32, 0.12, 0.05), dark)
	var crest := _box("head_crest", Vector3(0, 1.87, -0.03), Vector3(0.16, 0.1, 0.28), blue)
	var antenna := _box("short_antenna", Vector3(0.22, 1.97, -0.02), Vector3(0.055, 0.24, 0.055), amber)
	var pack := _box("rear_power_pack", Vector3(0, 1.15, 0.29), Vector3(0.36, 0.52, 0.16), dark)

	var left_upper := _box("left_upper_arm", Vector3(-0.43, 1.28, 0), Vector3(0.16, 0.5, 0.18), bone_shadow)
	var left_fore := _box("left_tool_forearm", Vector3(-0.55, 0.92, -0.08), Vector3(0.18, 0.42, 0.18), bone)
	var left_tool := _box("left_tool_claw", Vector3(-0.61, 0.62, -0.16), Vector3(0.2, 0.11, 0.28), dark)
	var right_upper := _box("right_upper_arm", Vector3(0.43, 1.28, 0), Vector3(0.16, 0.5, 0.18), bone_shadow)
	var right_fore := _box("right_rifle_forearm", Vector3(0.55, 0.92, -0.08), Vector3(0.18, 0.42, 0.18), bone)
	var carbine := _box("short_carbine", Vector3(0.69, 0.95, -0.33), Vector3(0.18, 0.12, 0.55), dark)
	var muzzle := _box("carbine_cyan_muzzle", Vector3(0.69, 0.95, -0.64), Vector3(0.08, 0.08, 0.08), blue)

	var left_thigh := _box("left_thigh", Vector3(-0.18, 0.48, 0), Vector3(0.16, 0.46, 0.16), bone_shadow)
	var right_thigh := _box("right_thigh", Vector3(0.18, 0.48, 0), Vector3(0.16, 0.46, 0.16), bone_shadow)
	var left_foot := _box("left_wide_foot", Vector3(-0.2, 0.14, -0.08), Vector3(0.32, 0.12, 0.42), dark)
	var right_foot := _box("right_wide_foot", Vector3(0.2, 0.14, -0.08), Vector3(0.32, 0.12, 0.42), dark)
	var rank_chip := _box("red_rank_chip", Vector3(-0.23, 1.03, -0.19), Vector3(0.12, 0.1, 0.05), red)

	for part in [pelvis, chest, chest_core, head, visor, crest, antenna, pack, left_upper, left_fore, left_tool, right_upper, right_fore, carbine, muzzle, left_thigh, right_thigh, left_foot, right_foot, rank_chip]:
		droid.add_child(part)

	match pose:
		"idle":
			left_upper.rotation_degrees = Vector3(0, 0, -8)
			right_upper.rotation_degrees = Vector3(0, 0, 8)
		"ready":
			left_upper.rotation_degrees = Vector3(-36, 0, -28)
			left_fore.position += Vector3(0.12, 0.18, -0.18)
			left_fore.rotation_degrees = Vector3(-42, 0, 48)
			left_tool.position += Vector3(0.16, 0.25, -0.22)
			right_upper.rotation_degrees = Vector3(-42, 0, 26)
			right_fore.position += Vector3(-0.06, 0.18, -0.21)
			right_fore.rotation_degrees = Vector3(-50, 0, -38)
			carbine.rotation_degrees = Vector3(-2, 0, 0)
		"scan":
			head.rotation_degrees = Vector3(0, -18, 0)
			left_upper.rotation_degrees = Vector3(-70, 0, -52)
			left_fore.position += Vector3(0.12, 0.25, -0.24)
			left_fore.rotation_degrees = Vector3(-64, 0, 58)
			left_tool.position += Vector3(0.18, 0.42, -0.32)
			left_tool.rotation_degrees = Vector3(0, 0, 10)
			right_upper.rotation_degrees = Vector3(-10, 0, 12)
		"cover":
			chest.rotation_degrees = Vector3(0, 0, -6)
			head.rotation_degrees = Vector3(0, -14, -6)
			left_thigh.rotation_degrees = Vector3(0, 0, -8)
			right_thigh.position += Vector3(0.06, 0, 0.06)
			right_upper.rotation_degrees = Vector3(-66, 0, 28)
			right_fore.position += Vector3(-0.09, 0.22, -0.28)
			right_fore.rotation_degrees = Vector3(-68, 0, -44)
			carbine.position += Vector3(-0.08, 0.2, -0.16)
			left_upper.rotation_degrees = Vector3(-45, 0, -45)

	return droid


func _box(node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	return inst


func _base_scene(name: String, background: Color, source_lighting: bool) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8d8d0") if source_lighting else Color("#29313b")
	env.ambient_light_energy = 0.92 if source_lighting else 0.82
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_floor(root: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	var inst := _box("review_floor", position, size, color)
	root.add_child(inst)


func _add_camera_light(root: Node3D, target: Vector3, camera_size: float, source_lighting: bool) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "DroidSourceSun"
	sun.rotation_degrees = Vector3(-34, -42, -8)
	sun.light_color = Color("#fff4d8") if source_lighting else Color("#ffe2aa")
	sun.light_energy = 2.9
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "DroidSourceFill"
	fill.position = target + Vector3(-2.5, 2.5, 2.5)
	fill.light_color = Color("#bfefff") if source_lighting else Color("#7fd7ff")
	fill.light_energy = 0.5
	fill.omni_range = 7.0
	root.add_child(fill)

	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	var camera_vector := Vector3(0.88, 0.72, -1.0)
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	if color == Color("#2aa7d7"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.45
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
	lines.append("# Meshy Image Droid Source Proof v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_meshy_image_droid_source_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Create an original, deterministic, blockcraft segmented droid source image before spending Meshy credits on image-to-3D. This lets the Meshy result be compared against an exact zero-credit baseline.")
	lines.append("")
	lines.append("## Meshy Source")
	lines.append("")
	lines.append("`source_reference/blockcraft_segmented_droid_source.png`")
	lines.append("")
	lines.append("![source](source_reference/blockcraft_segmented_droid_source.png)")
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
	lines.append("## Baseline Verdict")
	lines.append("")
	lines.append("The zero-credit droid is already serviceable as a background segmented NPC/proof actor. The Meshy question should therefore be narrow: can image-to-3D preserve or improve this blockcraft silhouette without melting the cube grammar?")
	lines.append("")
	var file := FileAccess.open(OUT_ROOT + "/SOURCE_REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/SOURCE_REVIEW.md"))
