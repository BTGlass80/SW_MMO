extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_pixel_extrude_v0"
const SOURCE_DIR := OUT_ROOT + "/source_images"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const BLOCKBENCH_FRIENDLY_SHIP := "res://docs/gpt/asset_factory/generated/blockbench_ship_panel_v2/glb/micro_arc_interceptor_panel_v2.glb"

const PIXEL_CELL := 0.12

var _captures: Array[Dictionary] = []
var _source_paths := {
	"blaster": SOURCE_DIR + "/pixel_blaster_side_32x16.png",
	"ship": SOURCE_DIR + "/pixel_patrol_ship_top_32x32.png",
	"terminal": SOURCE_DIR + "/pixel_service_terminal_front_24x24.png",
}
var _stats: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	_generate_source_images()
	await _save_and_capture(
		"pixel_blaster_per_pixel_cubes",
		_build_blaster_scene(),
		"A 32x16 side-view pixel blaster extruded into one MeshInstance3D cube per non-transparent pixel. This tests the strictest version of Gemini's Option 3."
	)
	await _save_and_capture(
		"pixel_terminal_wall_module",
		_build_terminal_scene(),
		"A 24x24 front-view service terminal pixel image extruded into a chunky wall module. This is the zero-credit alternative to a Meshy terminal prompt."
	)
	await _save_and_capture(
		"pixel_ship_vs_blockbench_isometric",
		_build_ship_comparison_scene(),
		"Left: kept Blockbench microfighter baseline. Right: a 32x32 top-down pixel ship extruded into true grid cubes for isometric tactical space."
	)
	await _save_and_capture(
		"pixel_extrude_three_family_sheet",
		_build_three_family_scene(),
		"Contact sheet for the three tested pixel-to-cube families: weapon, wall prop, and tactical ship token."
	)
	await _save_and_capture(
		"pixel_blaster_pixel_vs_runmerge",
		_build_blaster_merge_comparison_scene(),
		"Same 32x16 blaster source image. Left: one MeshInstance3D cube per pixel. Right: contiguous same-color pixels merged into rectangular voxel bars."
	)
	await _save_and_capture(
		"pixel_ship_pixel_vs_runmerge",
		_build_ship_merge_comparison_scene(),
		"Same 32x32 top-down ship source image. Left: one cube per pixel. Right: same-color horizontal runs merged before extrusion."
	)
	_write_manifest()
	_write_review()
	print("Godot pixel-extrude proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SOURCE_DIR, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _generate_source_images() -> void:
	var blaster := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	blaster.fill(Color(0, 0, 0, 0))
	_draw_blaster(blaster)
	_save_image(blaster, _source_paths["blaster"])

	var ship := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	ship.fill(Color(0, 0, 0, 0))
	_draw_ship(ship)
	_save_image(ship, _source_paths["ship"])

	var terminal := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	terminal.fill(Color(0, 0, 0, 0))
	_draw_terminal(terminal)
	_save_image(terminal, _source_paths["terminal"])


func _draw_blaster(image: Image) -> void:
	var metal := Color("#5d6870")
	var dark := Color("#1f252b")
	var tan := Color("#a8743f")
	var light := Color("#aeb9bf")
	var cyan := Color("#27d7ff")
	_fill_rect(image, 5, 7, 18, 3, metal)
	_fill_rect(image, 21, 6, 5, 4, light)
	_fill_rect(image, 25, 7, 5, 2, dark)
	_fill_rect(image, 28, 6, 2, 4, dark)
	_fill_rect(image, 30, 7, 1, 2, cyan)
	_fill_rect(image, 3, 6, 4, 4, dark)
	_fill_rect(image, 1, 5, 3, 6, dark)
	_fill_rect(image, 11, 10, 3, 5, tan)
	_fill_rect(image, 14, 10, 3, 2, dark)
	_fill_rect(image, 8, 5, 5, 2, light)
	_fill_rect(image, 17, 5, 3, 2, dark)
	_fill_rect(image, 19, 4, 2, 2, cyan)


func _draw_ship(image: Image) -> void:
	var hull := Color("#d9dedf")
	var shade := Color("#727c80")
	var dark := Color("#262d33")
	var red := Color("#a95e4d")
	var cockpit := Color("#1f9ab0")
	var amber := Color("#c49340")
	var cyan := Color("#27d7ff")

	_fill_rect(image, 14, 3, 4, 22, hull)
	_fill_rect(image, 13, 6, 6, 7, hull)
	_fill_rect(image, 12, 13, 8, 8, shade)
	_fill_rect(image, 15, 1, 2, 4, lightened(hull, 0.18))
	_fill_rect(image, 11, 21, 4, 7, dark)
	_fill_rect(image, 17, 21, 4, 7, dark)
	_fill_rect(image, 11, 28, 4, 2, cyan)
	_fill_rect(image, 17, 28, 4, 2, cyan)

	_fill_rect(image, 5, 14, 8, 5, hull)
	_fill_rect(image, 19, 14, 8, 5, hull)
	_fill_rect(image, 2, 17, 5, 4, shade)
	_fill_rect(image, 25, 17, 5, 4, shade)
	_fill_rect(image, 3, 21, 2, 2, amber)
	_fill_rect(image, 27, 21, 2, 2, amber)

	_fill_rect(image, 14, 8, 4, 4, cockpit)
	_fill_rect(image, 9, 15, 4, 3, red)
	_fill_rect(image, 19, 15, 4, 3, red)
	_fill_rect(image, 15, 16, 2, 5, red)
	_fill_rect(image, 6, 20, 6, 1, dark)
	_fill_rect(image, 20, 20, 6, 1, dark)


func _draw_terminal(image: Image) -> void:
	var plaster := Color("#b68a53")
	var plaster_light := Color("#d8b36b")
	var metal := Color("#33383d")
	var metal_light := Color("#6b7377")
	var cyan := Color("#27d7ff")
	var red := Color("#a95e4d")
	_fill_rect(image, 3, 3, 18, 18, plaster)
	_fill_rect(image, 5, 5, 14, 14, plaster_light)
	_fill_rect(image, 7, 7, 10, 7, metal)
	_fill_rect(image, 8, 8, 8, 2, metal_light)
	_fill_rect(image, 8, 11, 8, 1, metal_light)
	_fill_rect(image, 10, 15, 4, 3, cyan)
	_fill_rect(image, 18, 7, 2, 9, metal)
	_fill_rect(image, 4, 8, 2, 8, metal)
	_fill_rect(image, 15, 16, 3, 2, red)
	_fill_rect(image, 1, 11, 3, 2, metal)
	_fill_rect(image, 20, 11, 3, 2, metal)


func _fill_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for px in range(x, x + width):
		for py in range(y, y + height):
			if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)


func lightened(color: Color, amount: float) -> Color:
	return color.lightened(amount)


func _save_image(image: Image, path: String) -> void:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save source image %s: %s" % [path, err])
	else:
		print("Saved source image: %s" % ProjectSettings.globalize_path(path))


func _build_blaster_scene() -> Node3D:
	var root := _base_scene("PixelBlasterPerPixelCubes", Color("#101720"))
	var image := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["blaster"]))
	var holder := _extrude_front_image(root, image, "pixel_blaster", Vector3(0, 0.95, 0), PIXEL_CELL, PIXEL_CELL * 1.6)
	holder.rotation_degrees = Vector3(0, -22, 0)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(4.6, 0.08, 2.8), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.9, 0), 4.0, Vector3(0.9, 0.75, -0.9))
	return root


func _build_terminal_scene() -> Node3D:
	var root := _base_scene("PixelTerminalWallModule", Color("#2a1c16"))
	_add_box(root, "cantina_wall", Vector3(0, 1.08, 0.12), Vector3(3.2, 2.3, 0.16), Color("#9f6436"))
	_add_box(root, "dust_floor", Vector3(0, -0.04, -0.45), Vector3(3.8, 0.08, 2.4), Color("#2c211d"))
	var image := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["terminal"]))
	var holder := _extrude_front_image(root, image, "pixel_terminal", Vector3(0, 0.84, -0.08), PIXEL_CELL, PIXEL_CELL * 1.7)
	holder.rotation_degrees = Vector3(0, 0, 0)
	_add_camera_light(root, Vector3(0, 0.9, -0.2), 3.8, Vector3(0.9, 0.75, -0.9))
	return root


func _build_ship_comparison_scene() -> Node3D:
	var root := _base_scene("PixelShipVsBlockbenchIsometric", Color("#07111b"))
	var left := Vector3(-2.25, 0, 0)
	var right := Vector3(2.25, 0, 0)
	_add_space_tile(root, left, Vector2(3.2, 2.4))
	_add_space_tile(root, right, Vector2(3.2, 2.4))
	_add_model(root, BLOCKBENCH_FRIENDLY_SHIP, "blockbench_ship", left + Vector3(0, 0.18, 0), Vector3(0, -25, 0), 0.52)
	var image := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["ship"]))
	var ship := _extrude_top_image(root, image, "pixel_ship_token", right + Vector3(0, 0.04, 0), PIXEL_CELL * 0.86, PIXEL_CELL * 1.15)
	ship.rotation_degrees = Vector3(0, -25, 0)
	_add_ring(root, "blockbench_selection", left + Vector3(0, 0.05, 0), 0.95, Color("#3cc8ff"))
	_add_ring(root, "pixel_selection", right + Vector3(0, 0.05, 0), 0.95, Color("#ffcc44"))
	_add_camera_light(root, Vector3(0, 0.45, 0), 7.2, Vector3(1.1, 0.9, 1.1))
	return root


func _build_three_family_scene() -> Node3D:
	var root := _base_scene("PixelExtrudeThreeFamilySheet", Color("#101720"))
	var blaster_image := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["blaster"]))
	var terminal_image := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["terminal"]))
	var ship_image := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["ship"]))

	var blaster := _extrude_front_image(root, blaster_image, "family_blaster", Vector3(-3.8, 0.9, 0), PIXEL_CELL * 0.92, PIXEL_CELL * 1.4)
	blaster.rotation_degrees = Vector3(0, -20, 0)
	_add_box(root, "terminal_wall_card", Vector3(0, 1.05, 0.14), Vector3(2.55, 2.15, 0.12), Color("#9f6436"))
	_extrude_front_image(root, terminal_image, "family_terminal", Vector3(0, 0.82, -0.02), PIXEL_CELL * 0.9, PIXEL_CELL * 1.35)
	var ship := _extrude_top_image(root, ship_image, "family_ship", Vector3(3.8, 0.08, 0), PIXEL_CELL * 0.78, PIXEL_CELL * 1.0)
	ship.rotation_degrees = Vector3(0, -25, 0)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(9.8, 0.08, 3.0), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.82, 0), 8.5, Vector3(1.0, 0.78, -1.0))
	return root


func _build_blaster_merge_comparison_scene() -> Node3D:
	var root := _base_scene("PixelBlasterPixelVsRunMerge", Color("#101720"))
	var image := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["blaster"]))
	var left := _extrude_front_image(root, image, "pixel_blaster_per_pixel_ab", Vector3(-1.8, 0.95, 0), PIXEL_CELL, PIXEL_CELL * 1.55)
	left.rotation_degrees = Vector3(0, -22, 0)
	var right := _extrude_front_image_runs(root, image, "pixel_blaster_runmerge_ab", Vector3(1.8, 0.95, 0), PIXEL_CELL, PIXEL_CELL * 1.55)
	right.rotation_degrees = Vector3(0, -22, 0)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(6.2, 0.08, 2.8), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.9, 0), 5.9, Vector3(0.9, 0.75, -0.9))
	return root


func _build_ship_merge_comparison_scene() -> Node3D:
	var root := _base_scene("PixelShipPixelVsRunMerge", Color("#07111b"))
	var image := Image.load_from_file(ProjectSettings.globalize_path(_source_paths["ship"]))
	var left_pos := Vector3(-1.8, 0, 0)
	var right_pos := Vector3(1.8, 0, 0)
	_add_space_tile(root, left_pos, Vector2(3.0, 2.4))
	_add_space_tile(root, right_pos, Vector2(3.0, 2.4))
	var left := _extrude_top_image(root, image, "pixel_ship_per_pixel_ab", left_pos + Vector3(0, 0.04, 0), PIXEL_CELL * 0.8, PIXEL_CELL * 1.05)
	left.rotation_degrees = Vector3(0, -25, 0)
	var right := _extrude_top_image_runs(root, image, "pixel_ship_runmerge_ab", right_pos + Vector3(0, 0.04, 0), PIXEL_CELL * 0.8, PIXEL_CELL * 1.05)
	right.rotation_degrees = Vector3(0, -25, 0)
	_add_ring(root, "pixel_selection", left_pos + Vector3(0, 0.05, 0), 0.95, Color("#3cc8ff"))
	_add_ring(root, "runmerge_selection", right_pos + Vector3(0, 0.05, 0), 0.95, Color("#ffcc44"))
	_add_camera_light(root, Vector3(0, 0.45, 0), 6.1, Vector3(1.1, 0.9, 1.1))
	return root


func _extrude_front_image(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, depth: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	root.add_child(holder)
	var count := 0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		for x in range(width):
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			var px := (float(x) - float(width - 1) / 2.0) * cell
			var py := (float(height - 1 - y) - float(height - 1) / 2.0) * cell
			var cube := _new_box("%s_px_%s_%s" % [node_name, x, y], Vector3(px, py, 0), Vector3(cell, cell, depth), color)
			holder.add_child(cube)
			count += 1
	_stats[node_name] = {
		"pixels": width * height,
		"cubes": count,
		"mode": "front_extrude_meshinstance_per_pixel"
	}
	return holder


func _extrude_front_image_runs(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, depth: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	root.add_child(holder)
	var count := 0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		var x := 0
		while x < width:
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				x += 1
				continue
			var run_start := x
			var key := color.to_html(true)
			while x < width and image.get_pixel(x, y).a > 0.05 and image.get_pixel(x, y).to_html(true) == key:
				x += 1
			var run_length := x - run_start
			var px := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(width - 1) / 2.0) * cell
			var py := (float(height - 1 - y) - float(height - 1) / 2.0) * cell
			var cube := _new_box("%s_run_%s_%s" % [node_name, run_start, y], Vector3(px, py, 0), Vector3(float(run_length) * cell, cell, depth), color)
			holder.add_child(cube)
			count += 1
	_stats[node_name] = {
		"pixels": width * height,
		"cubes": count,
		"mode": "front_extrude_same_color_horizontal_runs"
	}
	return holder


func _extrude_top_image(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, height_scale: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	root.add_child(holder)
	var count := 0
	var width := image.get_width()
	var depth := image.get_height()
	for z in range(depth):
		for x in range(width):
			var color := image.get_pixel(x, z)
			if color.a <= 0.05:
				continue
			var px := (float(x) - float(width - 1) / 2.0) * cell
			var pz := (float(z) - float(depth - 1) / 2.0) * cell
			var brightness := (color.r + color.g + color.b) / 3.0
			var cube_height := height_scale * (0.55 + brightness * 0.75)
			var cube := _new_box("%s_px_%s_%s" % [node_name, x, z], Vector3(px, cube_height / 2.0, pz), Vector3(cell, cube_height, cell), color)
			holder.add_child(cube)
			count += 1
	_stats[node_name] = {
		"pixels": width * depth,
		"cubes": count,
		"mode": "top_extrude_meshinstance_per_pixel"
	}
	return holder


func _extrude_top_image_runs(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, height_scale: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	root.add_child(holder)
	var count := 0
	var width := image.get_width()
	var depth := image.get_height()
	for z in range(depth):
		var x := 0
		while x < width:
			var color := image.get_pixel(x, z)
			if color.a <= 0.05:
				x += 1
				continue
			var run_start := x
			var key := color.to_html(true)
			while x < width and image.get_pixel(x, z).a > 0.05 and image.get_pixel(x, z).to_html(true) == key:
				x += 1
			var run_length := x - run_start
			var px := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(width - 1) / 2.0) * cell
			var pz := (float(z) - float(depth - 1) / 2.0) * cell
			var brightness := (color.r + color.g + color.b) / 3.0
			var cube_height := height_scale * (0.55 + brightness * 0.75)
			var cube := _new_box("%s_run_%s_%s" % [node_name, run_start, z], Vector3(px, cube_height / 2.0, pz), Vector3(float(run_length) * cell, cube_height, cell), color)
			holder.add_child(cube)
			count += 1
	_stats[node_name] = {
		"pixels": width * depth,
		"cubes": count,
		"mode": "top_extrude_same_color_horizontal_runs"
	}
	return holder


func _new_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	return inst


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


func _base_scene(name: String, ambient: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b1017")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient.lightened(0.32)
	env.ambient_light_energy = 0.72
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_floor(root: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	_add_box(root, "review_floor", position, size, color)


func _add_space_tile(root: Node3D, center: Vector3, size: Vector2) -> void:
	_add_box(root, "space_tile", center + Vector3(0, -0.04, 0), Vector3(size.x, 0.05, size.y), Color("#0b1724"))
	for x in range(-3, 4):
		_add_box(root, "grid_x_%s" % x, center + Vector3(float(x) * 0.5, 0.01, 0), Vector3(0.014, 0.02, size.y), Color(0.16, 0.45, 0.76, 0.34))
	for z in range(-2, 3):
		_add_box(root, "grid_z_%s" % z, center + Vector3(0, 0.012, float(z) * 0.5), Vector3(size.x, 0.02, 0.014), Color(0.16, 0.45, 0.76, 0.34))


func _add_ring(root: Node3D, node_name: String, position: Vector3, radius: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.94
	mesh.outer_radius = radius
	mesh.ring_segments = 64
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(Color(color.r, color.g, color.b, 0.7))
	root.add_child(inst)


func _add_box(root: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var inst := _new_box(node_name, position, size, color)
	root.add_child(inst)
	return inst


func _add_camera_light(root: Node3D, target: Vector3, camera_size: float, camera_vector: Vector3) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "PixelExtrudeSun"
	sun.rotation_degrees = Vector3(-38, -44, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "PixelExtrudeFill"
	fill.position = target + Vector3(-2.5, 2.8, 2.5)
	fill.light_color = Color("#7fd7ff")
	fill.light_energy = 0.45
	fill.omni_range = 8.0
	root.add_child(fill)

	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if color == Color("#27d7ff"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.0
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


func _write_manifest() -> void:
	var manifest := {
		"generator": "docs/gpt/asset_factory/scripts/godot_pixel_extrude_proof.gd",
		"source_images": _source_paths,
		"stats": _stats,
		"captures": _captures,
	}
	var file := FileAccess.open(OUT_ROOT + "/pixel_extrude_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Godot Pixel Extrude Proof v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_pixel_extrude_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test Gemini's Option 3 in the actual Godot review environment: use a 2D pixel image as source data and spawn one strict grid cube for every non-transparent pixel.")
	lines.append("")
	lines.append("This is deliberately not Meshy. It spends zero credits and produces true discrete voxel geometry.")
	lines.append("")
	lines.append("A second sub-test keeps the exact same source images and changes only the emission strategy: per-pixel cubes versus same-color horizontal run boxes. This tests whether the lane can stay visually voxel while reducing object count and feeling less papercut.")
	lines.append("")
	lines.append("## Source Images")
	lines.append("")
	lines.append("- `source_images/pixel_blaster_side_32x16.png`")
	lines.append("- `source_images/pixel_service_terminal_front_24x24.png`")
	lines.append("- `source_images/pixel_patrol_ship_top_32x32.png`")
	lines.append("")
	lines.append("![pixel blaster](source_images/pixel_blaster_side_32x16.png)")
	lines.append("")
	lines.append("![pixel terminal](source_images/pixel_service_terminal_front_24x24.png)")
	lines.append("")
	lines.append("![pixel ship](source_images/pixel_patrol_ship_top_32x32.png)")
	lines.append("")
	lines.append("## Cube Counts")
	lines.append("")
	lines.append("| Node | Mode | Source pixels | Cubes |")
	lines.append("| --- | --- | ---: | ---: |")
	for key in _stats.keys():
		var stat: Dictionary = _stats[key]
		lines.append("| `%s` | `%s` | %s | %s |" % [key, stat.get("mode", ""), stat.get("pixels", 0), stat.get("cubes", 0)])
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
	lines.append("Candidate lane keep for strict voxel props and tactical tokens.")
	lines.append("")
	lines.append("This does what Meshy lowpoly could not: it guarantees cube-grid geometry. The best uses are flat-ish assets where a pixel source is naturally meaningful: weapon pickups, signs, icons, datapads, wall terminals, decals with depth, and isometric ship tokens.")
	lines.append("")
	lines.append("The same-color run merge is the better production direction for most non-pixel-art source cards: it preserves the silhouette, reduces cube count sharply, and creates cleaner Blockbench-like bars. Keep per-pixel cubes when the pixel-grid look itself is the point.")
	lines.append("")
	lines.append("Do not treat it as a full character/building replacement yet. Humanoids need a front/side/body-part layer contract, and large buildings need modular wall/roof kits rather than thousands of one-pixel cubes.")
	lines.append("")
	lines.append("## Next One-Variable Recommendation")
	lines.append("")
	lines.append("Try one AI-generated or Codex-generated 32x32 source card for a real requested asset, then route it through run-merge extrusion and compare against a hand-authored Blockbench version. Do not use copied fan art as the source image.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
