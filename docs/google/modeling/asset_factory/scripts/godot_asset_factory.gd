extends SceneTree

const DEFAULT_SPEC := "res://docs/gpt/asset_factory/specs/mos_eisley_chunky_v0.json"
const DEFAULT_OUT_ROOT := "res://docs/gpt/asset_factory/generated"
const CAPTURE_SIZE := Vector2i(1280, 720)

var _palette: Dictionary = {}
var _materials: Dictionary = {}
var _generated_assets: Array[Dictionary] = []
var _out_root := DEFAULT_OUT_ROOT
var _marker_style := "ring"

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var spec_path := _arg_value("--spec", DEFAULT_SPEC)
	var spec := _load_json(spec_path)
	if spec.is_empty():
		push_error("Asset factory spec could not be loaded: %s" % spec_path)
		quit(1)
		return

	_palette = spec.get("palette", {})
	_out_root = _output_root_for(spec)
	_marker_style = String(spec.get("marker_style", "ring"))
	_make_dirs()

	for asset in spec.get("assets", []):
		_generate_asset_scene(asset)

	await _generate_single_asset_reviews()
	await _generate_review_scene("all", _generated_assets)
	await _generate_review_scene("ground", _generated_assets.filter(func(a): return a.get("review_camera", "ground") == "ground"))
	await _generate_review_scene("space", _generated_assets.filter(func(a): return a.get("review_camera", "ground") == "space"))
	await _generate_review_scene("characters", _generated_assets.filter(func(a): return a.get("category", "") == "character_token"))
	await _generate_review_scene("scene_slices", _generated_assets.filter(func(a): return String(a.get("category", "")).contains("scene_slice")))
	_write_manifest(spec)
	_write_review_index(spec)

	print("Asset factory generated %s assets from %s" % [_generated_assets.size(), spec_path])
	quit()


func _arg_value(flag: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
	return fallback


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _make_dirs() -> void:
	for path in [
		_out_root,
		_out_root + "/scenes",
		_out_root + "/review_scenes",
		_out_root + "/captures",
		_out_root + "/captures/assets",
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _output_root_for(spec: Dictionary) -> String:
	var output_folder := String(spec.get("output_folder", "generated"))
	if output_folder.begins_with("res://"):
		return output_folder.rstrip("/")
	return "res://docs/gpt/asset_factory/%s" % output_folder.strip_edges().rstrip("/")


func _generate_asset_scene(asset: Dictionary) -> void:
	var root := Node3D.new()
	root.name = _safe_node_name(asset.get("id", "asset"))
	root.set_meta("asset_id", asset.get("id", ""))
	root.set_meta("display_name", asset.get("display_name", ""))
	root.set_meta("category", asset.get("category", ""))
	root.set_meta("gameplay_role", asset.get("gameplay_role", ""))
	root.set_meta("prompt", asset.get("prompt", ""))

	for part in asset.get("parts", []):
		var mesh_instance := _make_part(part)
		root.add_child(mesh_instance)

	var path := _out_root + "/scenes/%s.tscn" % asset.get("id", "asset")
	_save_scene(root, path)

	_generated_assets.append({
		"id": asset.get("id", ""),
		"display_name": asset.get("display_name", asset.get("id", "")),
		"category": asset.get("category", ""),
		"footprint": asset.get("footprint", []),
		"review_camera": asset.get("review_camera", "ground"),
		"scene_path": path,
		"gameplay_role": asset.get("gameplay_role", ""),
		"prompt": asset.get("prompt", ""),
	})
	root.queue_free()


func _make_part(part: Dictionary) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = _safe_node_name(part.get("name", "part"))
	inst.position = _vec3(part.get("position", [0, 0, 0]))
	inst.rotation_degrees = _vec3(part.get("rotation_degrees", [0, 0, 0]))

	var shape := String(part.get("shape", "box"))
	if shape == "box":
		var mesh := BoxMesh.new()
		mesh.size = _vec3(part.get("size", [1, 1, 1]))
		inst.mesh = mesh
	elif shape == "cylinder":
		var mesh := CylinderMesh.new()
		mesh.top_radius = float(part.get("radius", 0.5))
		mesh.bottom_radius = float(part.get("radius", 0.5))
		mesh.height = float(part.get("height", 1.0))
		mesh.radial_segments = int(part.get("segments", 12))
		inst.mesh = mesh
	elif shape == "sphere":
		var mesh := SphereMesh.new()
		mesh.radius = float(part.get("radius", 0.5))
		mesh.height = float(part.get("radius", 0.5)) * 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		inst.scale = _vec3(part.get("scale", [1, 1, 1]))
		inst.mesh = mesh
	elif shape == "dome":
		var mesh := SphereMesh.new()
		mesh.radius = float(part.get("radius", 1.0))
		mesh.height = float(part.get("radius", 1.0)) * 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		inst.scale = _vec3(part.get("scale", [1, 0.5, 1]))
		inst.mesh = mesh
	elif shape == "torus":
		var mesh := TorusMesh.new()
		mesh.inner_radius = float(part.get("inner_radius", 0.8))
		mesh.outer_radius = float(part.get("outer_radius", 0.9))
		mesh.ring_segments = 72
		inst.mesh = mesh
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		inst.mesh = mesh

	inst.material_override = _material(part.get("material", "sand_plaster"), bool(part.get("emissive", false)))
	return inst


func _material(key: String, emissive: bool = false) -> StandardMaterial3D:
	var mat_key := "%s:%s" % [key, emissive]
	if _materials.has(mat_key):
		return _materials[mat_key]

	var mat := StandardMaterial3D.new()
	var color := _color_for(key)
	mat.albedo_color = color
	mat.roughness = 0.86
	if key.contains("metal") or key.contains("ship_dark"):
		mat.metallic = 0.25
		mat.roughness = 0.62
	if emissive or key.contains("light") or key.contains("blue") or key.contains("orange"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	if key.contains("ring"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.5
	_materials[mat_key] = mat
	return mat


func _generate_single_asset_reviews() -> void:
	for i in range(_generated_assets.size()):
		var entry: Dictionary = _generated_assets[i]
		await _generate_single_asset_review(i, entry)


func _generate_single_asset_review(index: int, entry: Dictionary) -> void:
	var packed: PackedScene = load(entry["scene_path"])
	if packed == null:
		return

	var camera_type := String(entry.get("review_camera", "ground"))
	var root := Node3D.new()
	root.name = _safe_node_name("%s_review" % entry.get("id", "asset"))

	var plane_size := Vector3(8.5, 0.08, 7.0)
	var ground := _make_review_plane(camera_type, plane_size)
	root.add_child(ground)
	if camera_type == "space":
		_add_space_review_guides(root, plane_size)

	var item := packed.instantiate()
	item.name = _safe_node_name(entry.get("id", "asset"))
	if camera_type == "space":
		item.rotation_degrees.y = -35
	root.add_child(item)

	var marker := _make_marker(camera_type)
	marker.position = Vector3(0, 0.02, 0)
	root.add_child(marker)

	_add_lighting_and_camera(root, camera_type, plane_size, 0.85)

	var scene_path := _out_root + "/review_scenes/%s_review.tscn" % entry.get("id", "asset")
	var capture_path := _out_root + "/captures/assets/%s.png" % entry.get("id", "asset")
	_save_scene(root, scene_path)
	await _capture_scene(root, capture_path)

	entry["review_scene_path"] = scene_path
	entry["capture_path"] = capture_path
	_generated_assets[index] = entry
	root.queue_free()


func _generate_review_scene(name: String, assets: Array) -> void:
	if assets.is_empty():
		return

	var root := Node3D.new()
	root.name = _safe_node_name("AssetFactoryReview_%s" % name)

	var cols := _review_columns(name, assets.size())
	var rows := int(ceil(float(assets.size()) / float(cols)))
	var spacing := _review_spacing(name)
	var plane_size := Vector3(
		max(8.5, float(cols) * spacing.x + 4.2),
		0.08,
		max(7.0, float(rows) * spacing.z + 4.2)
	)

	var ground := _make_review_plane(name, plane_size)
	root.add_child(ground)
	if name == "space":
		_add_space_review_guides(root, plane_size)

	for i in range(assets.size()):
		var entry: Dictionary = assets[i]
		var packed: PackedScene = load(entry["scene_path"])
		if packed == null:
			continue
		var item := packed.instantiate()
		item.name = _safe_node_name(entry["id"])
		var col := i % cols
		var row := int(floor(float(i) / float(cols)))
		var x: float = float(col) - (float(cols) - 1.0) * 0.5
		var z: float = float(row) - (float(rows) - 1.0) * 0.5
		item.position = Vector3(x * spacing.x, 0, z * spacing.z)
		if name == "space" or entry.get("review_camera", "ground") == "space":
			item.rotation_degrees.y = -35
		root.add_child(item)

		var marker := _make_marker(entry.get("review_camera", "ground"))
		marker.position = item.position + Vector3(0, 0.02, 0)
		root.add_child(marker)

	_add_lighting_and_camera(root, name, plane_size, 1.0)

	var scene_path := _out_root + "/review_scenes/contact_sheet_%s.tscn" % name
	_save_scene(root, scene_path)
	await _capture_scene(root, _out_root + "/captures/contact_sheet_%s.png" % name)
	root.queue_free()


func _review_columns(name: String, asset_count: int) -> int:
	if name == "characters":
		return min(5, max(1, asset_count))
	if name == "scene_slices":
		return min(2, max(1, asset_count))
	if name == "ground":
		return min(2, max(1, asset_count))
	if name == "space":
		return min(3, max(1, asset_count))
	return min(4, max(1, asset_count))


func _review_spacing(name: String) -> Vector3:
	if name == "characters":
		return Vector3(3.4, 0.0, 3.3)
	if name == "scene_slices":
		return Vector3(9.0, 0.0, 7.0)
	if name == "ground":
		return Vector3(8.2, 0.0, 6.8)
	if name == "space":
		return Vector3(5.9, 0.0, 4.8)
	return Vector3(6.4, 0.0, 5.6)


func _make_review_plane(name: String, plane_size: Vector3) -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	ground.name = "ReviewPlane"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = plane_size
	ground.mesh = ground_mesh
	ground.position = Vector3(0, -0.08, 0)
	ground.material_override = _review_plane_material(name)
	return ground


func _add_space_review_guides(root: Node3D, plane_size: Vector3) -> void:
	var star_material := _material("cyan_light", true)
	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.07, 0.03, 0.07)
	for i in range(28):
		var star := MeshInstance3D.new()
		star.name = "ReviewStar_%02d" % i
		star.mesh = star_mesh
		star.material_override = star_material
		var x := fposmod(float(i * 37), plane_size.x * 10.0) / 10.0 - plane_size.x * 0.5
		var z := fposmod(float(i * 53 + 17), plane_size.z * 10.0) / 10.0 - plane_size.z * 0.5
		star.position = Vector3(x, 0.01, z)
		root.add_child(star)


func _make_marker(camera_type: String) -> Node3D:
	if _marker_style == "block_square":
		return _make_block_square_marker(camera_type)

	var marker := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.75 if camera_type == "space" else 2.0
	mesh.outer_radius = mesh.inner_radius + 0.07
	mesh.ring_segments = 72
	marker.mesh = mesh
	marker.material_override = _material("grid_blue" if camera_type == "space" else "teal_accent", true)
	return marker


func _make_block_square_marker(camera_type: String) -> Node3D:
	var root := Node3D.new()
	root.name = "BlockSelectionMarker"
	var half_size := 1.45 if camera_type == "space" else 1.7
	var thickness := 0.08
	var length := half_size * 2.0
	var material := _material("grid_blue" if camera_type == "space" else "teal_accent", true)
	var parts := [
		{"name": "front", "position": Vector3(0, 0, -half_size), "size": Vector3(length, thickness, thickness)},
		{"name": "back", "position": Vector3(0, 0, half_size), "size": Vector3(length, thickness, thickness)},
		{"name": "left", "position": Vector3(-half_size, 0, 0), "size": Vector3(thickness, thickness, length)},
		{"name": "right", "position": Vector3(half_size, 0, 0), "size": Vector3(thickness, thickness, length)}
	]
	for part in parts:
		var bar := MeshInstance3D.new()
		bar.name = String(part["name"])
		var mesh := BoxMesh.new()
		mesh.size = part["size"]
		bar.mesh = mesh
		bar.position = part["position"]
		bar.material_override = material
		root.add_child(bar)
	return root


func _review_plane_material(name: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if name == "space":
		mat.albedo_color = _color_for("space_plane")
		mat.emission_enabled = true
		mat.emission = _color_for("space_plane")
		mat.emission_energy_multiplier = 0.4
	else:
		mat.albedo_color = _color_for("dust_floor")
	mat.roughness = 0.95
	return mat


func _add_lighting_and_camera(root: Node3D, name: String, plane_size: Vector3, zoom: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "ReviewSun"
	sun.rotation_degrees = Vector3(-55, -35, -10)
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	root.add_child(sun)

	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 120.0
	camera.size = max(8.0, (plane_size.x + plane_size.z) * 0.56 * zoom)
	var target := Vector3(0, 0.85, 0)
	var distance := 22.0 if name == "space" else 20.0
	var camera_vector := Vector3(1.2, 1.05, 1.2) if name == "space" else Vector3(1.2, 1.05, -1.2)
	camera.position = target + camera_vector.normalized() * distance
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _capture_scene(scene: Node3D, out_path: String) -> void:
	get_root().size = CAPTURE_SIZE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)
	get_root().add_child(scene)
	for i in range(4):
		await process_frame
	var image := get_root().get_texture().get_image()
	var global_out := ProjectSettings.globalize_path(out_path)
	var err := image.save_png(global_out)
	if err != OK:
		push_error("Failed to save capture %s: %s" % [global_out, err])
	else:
		print("Saved capture: %s" % global_out)
	get_root().remove_child(scene)


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


func _write_manifest(spec: Dictionary) -> void:
	var manifest := {
		"generated_at_unix": Time.get_unix_time_from_system(),
		"schema": spec.get("schema", "gpt_asset_factory_v0"),
		"pack_id": spec.get("pack_id", ""),
		"display_name": spec.get("display_name", ""),
		"asset_count": _generated_assets.size(),
		"assets": _generated_assets,
		"captures": {
			"all": _out_root + "/captures/contact_sheet_all.png",
			"ground": _out_root + "/captures/contact_sheet_ground.png",
			"space": _out_root + "/captures/contact_sheet_space.png",
			"characters": _out_root + "/captures/contact_sheet_characters.png",
			"scene_slices": _out_root + "/captures/contact_sheet_scene_slices.png"
		}
	}
	var text := JSON.stringify(manifest, "\t")
	var path := _out_root + "/factory_manifest.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("Saved manifest: %s" % ProjectSettings.globalize_path(path))


func _write_review_index(spec: Dictionary) -> void:
	var lines: Array[String] = []
	lines.append("# %s Review Board" % spec.get("display_name", "Asset Factory"))
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_asset_factory.gd`")
	lines.append("Spec pack: `%s`" % spec.get("pack_id", ""))
	lines.append("")
	lines.append("## What This Is")
	lines.append("")
	lines.append("These images are captures from generated Godot `.tscn` scenes, not bitmap source art. The source scenes are in `scenes/`; the review camera scenes are in `review_scenes/`.")
	lines.append("")
	lines.append("Pipeline:")
	lines.append("")
	lines.append("```text")
	lines.append("JSON spec -> Godot procedural scene -> review scene -> PNG capture -> approve/reject/polish")
	lines.append("```")
	lines.append("")
	lines.append("## Contact Sheets")
	lines.append("")
	lines.append("![All assets](captures/contact_sheet_all.png)")
	lines.append("")
	lines.append("![Ground assets](captures/contact_sheet_ground.png)")
	lines.append("")
	lines.append("![Isometric space assets](captures/contact_sheet_space.png)")
	lines.append("")
	lines.append("![Character assets](captures/contact_sheet_characters.png)")
	lines.append("")
	lines.append("![Scene slice assets](captures/contact_sheet_scene_slices.png)")
	lines.append("")
	lines.append("## Individual Captures")
	lines.append("")
	lines.append("| Asset | Category | Gameplay Role | Capture |")
	lines.append("| --- | --- | --- | --- |")
	for entry in _generated_assets:
		var capture := String(entry.get("capture_path", "")).replace(_out_root + "/", "")
		lines.append("| %s | %s | %s | ![%s](%s) |" % [
			entry.get("display_name", entry.get("id", "")),
			entry.get("category", ""),
			entry.get("gameplay_role", ""),
			entry.get("display_name", entry.get("id", "")),
			capture
		])
	lines.append("")
	lines.append("## Review Tags")
	lines.append("")
	lines.append("- `accept-prototype`: good enough to test in gameplay.")
	lines.append("- `needs-style-pass`: useful silhouette but ugly detail/materials.")
	lines.append("- `needs-remodel`: concept is useful, geometry is not.")
	lines.append("- `api-candidate`: worth trying through a 3D generation provider.")
	lines.append("- `human-candidate`: too important or too hard for procedural generation.")
	lines.append("")

	var file := FileAccess.open(_out_root + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review index: %s" % ProjectSettings.globalize_path(_out_root + "/REVIEW.md"))


func _color_for(key: String) -> Color:
	var value := String(_palette.get(key, "#cccccc"))
	return Color.html(value)


func _vec3(values: Variant) -> Vector3:
	if typeof(values) != TYPE_ARRAY:
		return Vector3.ZERO
	return Vector3(
		float(values[0]) if values.size() > 0 else 0.0,
		float(values[1]) if values.size() > 1 else 0.0,
		float(values[2]) if values.size() > 2 else 0.0
	)


func _safe_node_name(value: String) -> String:
	var safe := ""
	for i in range(value.length()):
		var c := value.substr(i, 1)
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			safe += c
		elif c == "_" or c == "-":
			safe += "_"
	if safe.is_empty():
		return "Asset"
	return safe
