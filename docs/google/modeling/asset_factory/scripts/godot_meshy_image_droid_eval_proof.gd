extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/meshy_image_droid_v0/godot_proof"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const BASELINE_SCENE := "res://docs/gpt/asset_factory/generated/meshy_image_droid_v0/review_scenes/droid_baseline_dark_review.tscn"
const MESHY_GLB := "res://docs/gpt/asset_factory/generated/meshy_image_droid_v0/meshy_image_segmented_droid_meshy5_geometry_v0/model.glb"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"meshy_image_droid_baseline_ab",
		_build_ab_scene(),
		"Left: Meshy image-to-3D GLB generated from the source render. Right: deterministic source droid baseline. This layout exposes the Meshy platform-fusion issue clearly."
	)
	await _save_and_capture(
		"meshy_image_droid_rotation_contact_sheet",
		_build_rotation_sheet_scene(),
		"Meshy image-to-3D GLB at four yaw angles. Checks whether the generated model has usable back/side geometry and whether the source platform became unwanted mesh."
	)
	_write_review()
	print("Godot Meshy image droid eval proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_ab_scene() -> Node3D:
	var root := _base_scene("MeshyImageDroidBaselineAB", Color("#0b1017"))
	var left := Vector3(-1.0, 0, 0)
	var right := Vector3(1.0, 0, 0)
	var baseline := _extract_baseline_droid()
	baseline.name = "deterministic_droid_baseline"
	baseline.position = left
	baseline.rotation_degrees = Vector3(0, -28, 0)
	root.add_child(baseline)
	var meshy := _add_model(root, MESHY_GLB, "meshy_image_droid_glb", right + Vector3(0, 0.02, 0), Vector3(0, -28, 0), 1.2)
	_flatten_overbright(meshy)
	_add_floor(root, left + Vector3(0, -0.06, 0), Vector3(1.0, 0.06, 1.0), Color("#20252b"))
	_add_floor(root, right + Vector3(0, -0.06, 0), Vector3(1.0, 0.06, 1.0), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.86, 0), 3.0)
	return root


func _build_rotation_sheet_scene() -> Node3D:
	var root := _base_scene("MeshyImageDroidRotationSheet", Color("#0b1017"))
	var yaws := [0, 90, 180, 270]
	for i in range(yaws.size()):
		var offset := Vector3((float(i) - 1.5) * 1.18, 0.02, 0)
		var model := _add_model(root, MESHY_GLB, "meshy_image_droid_yaw_%s" % yaws[i], offset, Vector3(0, yaws[i], 0), 1.08)
		_flatten_overbright(model)
		_add_floor(root, offset + Vector3(0, -0.08, 0), Vector3(0.95, 0.06, 0.95), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.8, 0), 4.8)
	return root


func _extract_baseline_droid() -> Node3D:
	var packed: PackedScene = load(BASELINE_SCENE)
	if packed == null:
		push_error("Could not load baseline scene: %s" % BASELINE_SCENE)
		return Node3D.new()
	var scene := packed.instantiate()
	var droid := scene.find_child("segmented_droid_source", true, false) as Node3D
	if droid == null:
		push_error("Could not find segmented_droid_source in baseline scene")
		scene.queue_free()
		return Node3D.new()
	droid.get_parent().remove_child(droid)
	_clear_owner_recursive(droid)
	scene.queue_free()
	return droid


func _clear_owner_recursive(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owner_recursive(child)


func _add_model(root: Node3D, path: String, node_name: String, position: Vector3, rotation_degrees: Vector3, scale_factor: float) -> Node3D:
	var imported: Node = null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if err == OK:
		imported = document.generate_scene(state)
	if imported == null:
		push_error("Could not import GLB model: %s" % path)
		var missing := Node3D.new()
		missing.name = node_name + "_missing"
		root.add_child(missing)
		return missing
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation_degrees = rotation_degrees
	holder.scale = Vector3.ONE * scale_factor
	holder.add_child(imported)
	_bottom_center_import(imported)
	root.add_child(holder)
	return holder


func _bottom_center_import(imported: Node) -> void:
	var bounds := _collect_local_bounds(imported, Transform3D.IDENTITY)
	if bounds.size == Vector3.ZERO:
		return
	var center := bounds.position + bounds.size * 0.5
	var offset := Vector3(center.x, bounds.position.y, center.z)
	if imported is Node3D:
		(imported as Node3D).position -= offset


func _collect_local_bounds(node: Node, parent_transform: Transform3D) -> AABB:
	var local_transform := parent_transform
	if node is Node3D:
		local_transform = parent_transform * (node as Node3D).transform
	var found := false
	var bounds := AABB()
	if node is MeshInstance3D:
		var inst := node as MeshInstance3D
		if inst.mesh:
			bounds = _transform_aabb(local_transform, inst.get_aabb())
			found = true
	for child in node.get_children():
		var child_bounds := _collect_local_bounds(child, local_transform)
		if child_bounds.size == Vector3.ZERO:
			continue
		if found:
			bounds = bounds.merge(child_bounds)
		else:
			bounds = child_bounds
			found = true
	return bounds if found else AABB()


func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var corners := [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
	]
	var result := AABB(transform * corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		result = result.expand(transform * corners[i])
	return result


func _flatten_overbright(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#b7b8b2")
		mat.roughness = 0.92
		node.material_override = mat
	for child in node.get_children():
		_flatten_overbright(child)


func _base_scene(name: String, background: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#29313b")
	env.ambient_light_energy = 0.84
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_floor(root: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = "review_floor"
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	root.add_child(inst)


func _add_camera_light(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "MeshyImageDroidSun"
	sun.rotation_degrees = Vector3(-34, -42, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.7
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "MeshyImageDroidFill"
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
	var camera_vector := Vector3(0.88, 0.72, -1.0)
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
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
	lines.append("# Meshy Image Droid Godot Proof v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_meshy_image_droid_eval_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Import the 5-credit Meshy image-to-3D segmented droid probe into Godot and compare it against the deterministic source droid baseline.")
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
	lines.append("Candidate lesson keep, not a direct runtime keep. The image-to-3D result preserved the basic droid silhouette for only 5 credits, but it softened the cube grammar and absorbed the source presentation platform into the mesh. A tighter next test should use a cropped/transparent source with no floor and stronger silhouette separation.")
	lines.append("")
	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
