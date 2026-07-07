extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_pixel_cantina_layered_kit_v1"
const SOURCE_DIR := OUT_ROOT + "/source_images"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"

const GRID_W := 48
const GRID_H := 32
const CELL := 0.16

const EMPTY := "."
const FLOOR := "floor"
const WALL := "wall"
const DOOR := "door"
const BAR := "bar"
const BOOTH := "booth"
const TABLE := "table"
const CLUTTER := "clutter"
const LIGHT := "light"
const ARCH := "arch"
const FRAME := "frame"
const BACK := "booth_back"
const PIPE := "pipe"
const SOCKET := "socket"
const LAMP := "lamp"
const SIGN := "sign"
const RAISED := "raised"

var _floor_grid: Array = []
var _detail_grid: Array = []
var _captures: Array[Dictionary] = []
var _stats: Dictionary = {}

var _palette := {
	FLOOR: Color("#3a2b22"),
	WALL: Color("#a66c3a"),
	DOOR: Color("#15191d"),
	BAR: Color("#6c4b35"),
	BOOTH: Color("#4b2c26"),
	TABLE: Color("#2b2522"),
	CLUTTER: Color("#24303a"),
	LIGHT: Color("#27d7ff"),
	ARCH: Color("#d08a43"),
	FRAME: Color("#c18a54"),
	BACK: Color("#5b3028"),
	PIPE: Color("#202832"),
	SOCKET: Color("#7b5b3e"),
	LAMP: Color("#27d7ff"),
	SIGN: Color("#15191d"),
	RAISED: Color("#7b5a3d"),
}

var _heights := {
	FLOOR: 0.08,
	WALL: 1.05,
	DOOR: 0.16,
	BAR: 0.64,
	BOOTH: 0.46,
	TABLE: 0.34,
	CLUTTER: 0.38,
	LIGHT: 0.18,
	ARCH: 1.35,
	FRAME: 1.22,
	BACK: 0.86,
	PIPE: 0.22,
	SOCKET: 0.42,
	LAMP: 0.22,
	SIGN: 0.18,
	RAISED: 0.14,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	_floor_grid = _build_floor_grid()
	_detail_grid = _build_detail_grid()
	_save_source_image(_floor_grid, SOURCE_DIR + "/cantina_floorplan_48x32.png")
	_save_source_image(_detail_grid, SOURCE_DIR + "/cantina_detail_elevation_48x32.png")
	_calculate_stats()
	await _save_and_capture(
		"layered_cantina_source_cards",
		_build_source_cards_scene(),
		"Two original semantic pixel cards. Top: floorplan/layout. Bottom: elevation/detail hooks for arches, frames, booth backs, pipes, sockets, lamps, signs, and raised platforms."
	)
	await _save_and_capture(
		"layered_cantina_v0_vs_v1",
		_build_v0_vs_v1_scene(),
		"Left: floorplan-only merged room kit. Right: layered floorplan plus detail/elevation card. Same room, one added semantic layer."
	)
	await _save_and_capture(
		"layered_cantina_v1_isometric",
		_build_v1_isometric_scene(),
		"Layered material-batched Cantina v1 from the isometric review camera."
	)
	await _save_and_capture(
		"layered_cantina_v1_closeup",
		_build_v1_closeup_scene(),
		"Close review of the added arches, frames, booth backs, lamps, pipes, sockets, and raised floor detail."
	)
	_write_manifest()
	_write_review()
	print("Godot layered pixel Cantina kit proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SOURCE_DIR, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_floor_grid() -> Array:
	var grid := _empty_grid()
	_paint_rect(grid, 4, 4, 40, 24, FLOOR)
	_paint_rect(grid, 4, 4, 40, 2, WALL)
	_paint_rect(grid, 4, 26, 40, 2, WALL)
	_paint_rect(grid, 4, 4, 2, 24, WALL)
	_paint_rect(grid, 42, 4, 2, 24, WALL)
	_paint_rect(grid, 21, 26, 6, 3, DOOR)
	_paint_rect(grid, 22, 24, 4, 2, FLOOR)
	_paint_rect(grid, 35, 4, 8, 8, FLOOR)
	_paint_rect(grid, 35, 4, 8, 2, WALL)
	_paint_rect(grid, 41, 5, 2, 7, WALL)
	_paint_rect(grid, 34, 9, 4, 2, DOOR)
	_paint_rect(grid, 30, 11, 10, 2, BAR)
	_paint_rect(grid, 30, 13, 2, 9, BAR)
	_paint_rect(grid, 38, 13, 2, 9, BAR)
	_paint_rect(grid, 32, 21, 6, 2, BAR)
	_paint_rect(grid, 33, 14, 4, 6, TABLE)
	_paint_rect(grid, 31, 10, 2, 1, LIGHT)
	_paint_rect(grid, 36, 10, 2, 1, LIGHT)
	_paint_rect(grid, 34, 20, 2, 1, LIGHT)
	_paint_rect(grid, 8, 8, 5, 2, BOOTH)
	_paint_rect(grid, 8, 10, 2, 5, BOOTH)
	_paint_rect(grid, 8, 17, 5, 2, BOOTH)
	_paint_rect(grid, 8, 19, 2, 5, BOOTH)
	_paint_rect(grid, 14, 9, 3, 3, TABLE)
	_paint_rect(grid, 14, 18, 3, 3, TABLE)
	_paint_rect(grid, 20, 9, 4, 3, TABLE)
	_paint_rect(grid, 20, 18, 4, 3, TABLE)
	_paint_rect(grid, 18, 12, 2, 1, LIGHT)
	_paint_rect(grid, 25, 18, 2, 1, LIGHT)
	_paint_rect(grid, 6, 24, 5, 2, CLUTTER)
	_paint_rect(grid, 12, 25, 3, 1, CLUTTER)
	_paint_rect(grid, 39, 23, 3, 2, CLUTTER)
	_paint_rect(grid, 37, 7, 3, 2, CLUTTER)
	_paint_rect(grid, 5, 13, 1, 5, CLUTTER)
	_paint_rect(grid, 42, 16, 1, 5, CLUTTER)
	return grid


func _build_detail_grid() -> Array:
	var grid := _empty_grid()
	_paint_rect(grid, 20, 25, 8, 3, ARCH)
	_paint_rect(grid, 21, 24, 2, 2, FRAME)
	_paint_rect(grid, 26, 24, 2, 2, FRAME)
	_paint_rect(grid, 33, 8, 6, 3, FRAME)
	_paint_rect(grid, 34, 9, 4, 2, ARCH)
	_paint_rect(grid, 7, 7, 7, 1, BACK)
	_paint_rect(grid, 7, 16, 7, 1, BACK)
	_paint_rect(grid, 10, 10, 1, 5, BACK)
	_paint_rect(grid, 10, 19, 1, 5, BACK)
	_paint_rect(grid, 31, 10, 8, 1, LAMP)
	_paint_rect(grid, 31, 23, 8, 1, LAMP)
	_paint_rect(grid, 29, 14, 1, 8, PIPE)
	_paint_rect(grid, 40, 14, 1, 8, PIPE)
	_paint_rect(grid, 6, 12, 1, 7, PIPE)
	_paint_rect(grid, 41, 7, 2, 1, PIPE)
	_paint_rect(grid, 35, 6, 5, 1, SOCKET)
	_paint_rect(grid, 6, 23, 6, 1, SOCKET)
	_paint_rect(grid, 38, 24, 4, 1, SOCKET)
	_paint_rect(grid, 20, 8, 4, 1, SIGN)
	_paint_rect(grid, 13, 13, 5, 1, RAISED)
	_paint_rect(grid, 13, 22, 5, 1, RAISED)
	_paint_rect(grid, 31, 13, 8, 1, RAISED)
	return grid


func _empty_grid() -> Array:
	var grid := []
	for y in range(GRID_H):
		var row := []
		for x in range(GRID_W):
			row.append(EMPTY)
		grid.append(row)
	return grid


func _paint_rect(grid: Array, x: int, y: int, w: int, h: int, value: String) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < GRID_W and py < GRID_H:
				grid[py][px] = value


func _save_source_image(grid: Array, path: String) -> void:
	var image := Image.create_empty(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(GRID_H):
		for x in range(GRID_W):
			var category: String = grid[y][x]
			if category != EMPTY:
				image.set_pixel(x, y, _palette[category])
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save source image %s: %s" % [path, err])


func _calculate_stats() -> void:
	var floor_pixels := _count_nonempty_pixels(_floor_grid)
	var detail_pixels := _count_nonempty_pixels(_detail_grid)
	var floor_rects := _make_greedy_rects(_floor_grid)
	var detail_rects := _make_greedy_rects(_detail_grid)
	var combined_categories := _used_categories(_floor_grid)
	for category in _used_categories(_detail_grid):
		if not combined_categories.has(category):
			combined_categories.append(category)
	combined_categories.sort()
	var combined_rect_count := floor_rects.size() + detail_rects.size()
	var combined_pixel_count := floor_pixels + detail_pixels
	_stats = {
		"grid_size": "%sx%s" % [GRID_W, GRID_H],
		"floor_nonempty_pixels": floor_pixels,
		"detail_nonempty_pixels": detail_pixels,
		"combined_nonempty_pixels": combined_pixel_count,
		"floor_greedy_rectangles": floor_rects.size(),
		"detail_greedy_rectangles": detail_rects.size(),
		"combined_greedy_rectangles": combined_rect_count,
		"batched_mesh_nodes": combined_categories.size(),
		"used_categories": combined_categories,
		"per_pixel_nodes": combined_pixel_count,
		"batched_node_reduction_vs_per_pixel": snapped(100.0 * (1.0 - float(combined_categories.size()) / float(max(1, combined_pixel_count))), 0.1),
		"rect_reduction_vs_per_pixel": snapped(100.0 * (1.0 - float(combined_rect_count) / float(max(1, combined_pixel_count))), 0.1),
		"per_pixel_triangles_estimate": combined_pixel_count * 12,
		"batched_triangles_estimate": combined_rect_count * 12,
	}


func _count_nonempty_pixels(grid: Array) -> int:
	var count := 0
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid[y][x] != EMPTY:
				count += 1
	return count


func _used_categories(grid: Array) -> Array:
	var found := {}
	for y in range(GRID_H):
		for x in range(GRID_W):
			var category: String = grid[y][x]
			if category != EMPTY:
				found[category] = true
	var result := found.keys()
	result.sort()
	return result


func _make_row_runs(grid: Array) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for y in range(GRID_H):
		var x := 0
		while x < GRID_W:
			var category: String = grid[y][x]
			if category == EMPTY:
				x += 1
				continue
			var start := x
			while x < GRID_W and grid[y][x] == category:
				x += 1
			runs.append({"x": start, "y": y, "w": x - start, "h": 1, "category": category})
	return runs


func _make_greedy_rects(grid: Array) -> Array[Dictionary]:
	var used := []
	for y in range(GRID_H):
		var row := []
		for x in range(GRID_W):
			row.append(false)
		used.append(row)
	var rects: Array[Dictionary] = []
	for y in range(GRID_H):
		for x in range(GRID_W):
			var category: String = grid[y][x]
			if category == EMPTY or used[y][x]:
				continue
			var w := 1
			while x + w < GRID_W and not used[y][x + w] and grid[y][x + w] == category:
				w += 1
			var h := 1
			var can_grow := true
			while y + h < GRID_H and can_grow:
				for px in range(x, x + w):
					if used[y + h][px] or grid[y + h][px] != category:
						can_grow = false
						break
				if can_grow:
					h += 1
			for py in range(y, y + h):
				for px in range(x, x + w):
					used[py][px] = true
			rects.append({"x": x, "y": y, "w": w, "h": h, "category": category})
	return rects


func _build_source_cards_scene() -> Node3D:
	var root := _base_scene("LayeredCantinaSourceCards", Color("#101720"))
	_add_rect_boxes(root, _make_row_runs(_floor_grid), Vector3(0, 0, -1.75), CELL * 0.82, true)
	_add_rect_boxes(root, _make_row_runs(_detail_grid), Vector3(0, 0, 1.75), CELL * 0.82, true)
	_add_camera_light(root, Vector3(0, 0.1, 0), 8.6, Vector3(0, 1, -0.001))
	return root


func _build_v0_vs_v1_scene() -> Node3D:
	var root := _base_scene("LayeredCantinaV0VsV1", Color("#101720"))
	_add_batched_rect_meshes(root, _make_greedy_rects(_floor_grid), Vector3(-3.9, 0, 0), CELL * 0.74)
	_add_layered_batched_meshes(root, Vector3(3.9, 0, 0), CELL * 0.74)
	_add_camera_light(root, Vector3(0, 0.65, 0), 8.7, Vector3(0.9, 0.78, -1.0))
	return root


func _build_v1_isometric_scene() -> Node3D:
	var root := _base_scene("LayeredCantinaV1Isometric", Color("#0b1017"))
	_add_layered_batched_meshes(root, Vector3.ZERO, CELL)
	_add_camera_light(root, Vector3(0, 0.68, 0), 8.6, Vector3(0.9, 0.78, -1.0))
	return root


func _build_v1_closeup_scene() -> Node3D:
	var root := _base_scene("LayeredCantinaV1Closeup", Color("#0b1017"))
	_add_layered_batched_meshes(root, Vector3.ZERO, CELL)
	_add_camera_light(root, Vector3(1.15, 0.72, -0.05), 5.2, Vector3(0.9, 0.72, -1.0))
	return root


func _add_layered_batched_meshes(root: Node3D, origin: Vector3, cell: float) -> void:
	_add_batched_rect_meshes(root, _make_greedy_rects(_floor_grid), origin, cell)
	_add_batched_rect_meshes(root, _make_greedy_rects(_detail_grid), origin + Vector3(0, 0.02, 0), cell)


func _add_rect_boxes(root: Node3D, rects: Array[Dictionary], origin: Vector3, cell: float, flat_card: bool) -> void:
	var holder := Node3D.new()
	holder.name = "rect_box_holder"
	holder.position = origin
	root.add_child(holder)
	for rect in rects:
		var category: String = rect["category"]
		holder.add_child(_new_box("%s_%s_%s" % [category, rect["x"], rect["y"]], _rect_position(rect, category, cell, flat_card), _rect_size(rect, category, cell, flat_card), _palette[category]))


func _add_batched_rect_meshes(root: Node3D, rects: Array[Dictionary], origin: Vector3, cell: float) -> void:
	var by_category := {}
	for rect in rects:
		var category: String = rect["category"]
		if not by_category.has(category):
			by_category[category] = []
		by_category[category].append(rect)
	var holder := Node3D.new()
	holder.name = "material_batched_layer"
	holder.position = origin
	root.add_child(holder)
	for category in by_category.keys():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for rect in by_category[category]:
			_add_box_faces(st, _rect_position(rect, category, cell, false), _rect_size(rect, category, cell, false))
		var mesh := st.commit()
		var inst := MeshInstance3D.new()
		inst.name = "batch_%s" % category
		inst.mesh = mesh
		inst.material_override = _material(_palette[category])
		holder.add_child(inst)


func _rect_position(rect: Dictionary, category: String, cell: float, flat_card: bool) -> Vector3:
	var cx := (float(rect["x"]) + float(rect["w"]) / 2.0 - float(GRID_W) / 2.0) * cell
	var cz := (float(rect["y"]) + float(rect["h"]) / 2.0 - float(GRID_H) / 2.0) * cell
	var height := cell * 0.18 if flat_card else float(_heights[category])
	return Vector3(cx, height / 2.0, cz)


func _rect_size(rect: Dictionary, category: String, cell: float, flat_card: bool) -> Vector3:
	var height := cell * 0.18 if flat_card else float(_heights[category])
	return Vector3(float(rect["w"]) * cell, height, float(rect["h"]) * cell)


func _new_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	return inst


func _add_box_faces(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var hx := size.x / 2.0
	var hy := size.y / 2.0
	var hz := size.z / 2.0
	var p := [
		center + Vector3(-hx, -hy, -hz),
		center + Vector3(hx, -hy, -hz),
		center + Vector3(hx, hy, -hz),
		center + Vector3(-hx, hy, -hz),
		center + Vector3(-hx, -hy, hz),
		center + Vector3(hx, -hy, hz),
		center + Vector3(hx, hy, hz),
		center + Vector3(-hx, hy, hz),
	]
	_add_face(st, [p[0], p[1], p[2], p[3]], Vector3(0, 0, -1))
	_add_face(st, [p[5], p[4], p[7], p[6]], Vector3(0, 0, 1))
	_add_face(st, [p[4], p[0], p[3], p[7]], Vector3(-1, 0, 0))
	_add_face(st, [p[1], p[5], p[6], p[2]], Vector3(1, 0, 0))
	_add_face(st, [p[3], p[2], p[6], p[7]], Vector3(0, 1, 0))
	_add_face(st, [p[4], p[5], p[1], p[0]], Vector3(0, -1, 0))


func _add_face(st: SurfaceTool, quad: Array, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(quad[0])
	st.set_normal(normal)
	st.add_vertex(quad[1])
	st.set_normal(normal)
	st.add_vertex(quad[2])
	st.set_normal(normal)
	st.add_vertex(quad[0])
	st.set_normal(normal)
	st.add_vertex(quad[2])
	st.set_normal(normal)
	st.add_vertex(quad[3])


func _base_scene(name: String, background: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#29313b")
	env.ambient_light_energy = 0.86
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_camera_light(root: Node3D, target: Vector3, camera_size: float, camera_vector: Vector3) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "LayeredPixelCantinaSun"
	sun.rotation_degrees = Vector3(-36, -42, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.5
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := OmniLight3D.new()
	fill.name = "LayeredPixelCantinaFill"
	fill.position = target + Vector3(-2.5, 2.5, 2.5)
	fill.light_color = Color("#7fd7ff")
	fill.light_energy = 0.35
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
	mat.roughness = 0.9
	if color == Color("#27d7ff"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5
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
		"generator": "docs/gpt/asset_factory/scripts/godot_pixel_cantina_layered_kit_proof.gd",
		"floorplan_source": SOURCE_DIR + "/cantina_floorplan_48x32.png",
		"detail_source": SOURCE_DIR + "/cantina_detail_elevation_48x32.png",
		"stats": _stats,
		"captures": _captures,
	}
	var file := FileAccess.open(OUT_ROOT + "/pixel_cantina_layered_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Godot Layered Pixel Cantina Kit Proof v1")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_pixel_cantina_layered_kit_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test the next one-variable improvement after the pixel Cantina v0: add a second semantic detail/elevation card while keeping rectangle merge and material batching.")
	lines.append("")
	lines.append("## Source Cards")
	lines.append("")
	lines.append("- `source_images/cantina_floorplan_48x32.png`")
	lines.append("- `source_images/cantina_detail_elevation_48x32.png`")
	lines.append("")
	lines.append("![floorplan](source_images/cantina_floorplan_48x32.png)")
	lines.append("")
	lines.append("![detail](source_images/cantina_detail_elevation_48x32.png)")
	lines.append("")
	lines.append("## Efficiency Stats")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("| --- | ---: |")
	lines.append("| Grid size | `%s` |" % _stats["grid_size"])
	lines.append("| Floor non-empty pixels | %s |" % _stats["floor_nonempty_pixels"])
	lines.append("| Detail non-empty pixels | %s |" % _stats["detail_nonempty_pixels"])
	lines.append("| Combined non-empty pixels | %s |" % _stats["combined_nonempty_pixels"])
	lines.append("| Floor rectangles | %s |" % _stats["floor_greedy_rectangles"])
	lines.append("| Detail rectangles | %s |" % _stats["detail_greedy_rectangles"])
	lines.append("| Combined rectangles | %s |" % _stats["combined_greedy_rectangles"])
	lines.append("| Material-batched mesh nodes | %s |" % _stats["batched_mesh_nodes"])
	lines.append("| Rectangle reduction vs per-pixel | %s%% |" % _stats["rect_reduction_vs_per_pixel"])
	lines.append("| Node reduction vs per-pixel | %s%% |" % _stats["batched_node_reduction_vs_per_pixel"])
	lines.append("| Per-pixel triangle estimate | %s |" % _stats["per_pixel_triangles_estimate"])
	lines.append("| Batched triangle estimate | %s |" % _stats["batched_triangles_estimate"])
	lines.append("")
	lines.append("Used categories: `%s`" % ", ".join(_stats["used_categories"]))
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
	lines.append("Candidate keep. The second semantic card adds visible room identity hooks without breaking the compute model. It is still not a replacement for authored Blockbench hero modules, but it is now strong enough to be considered a scalable room-production backbone: floorplan/layout/collision/LOD from pixels, detail sockets/elevation from a second card, and hero props layered in as authored assets.")
	lines.append("")
	lines.append("Next improvement: generate collision/navigation shapes and named interaction sockets from the same cards, proving this lane is runtime-useful rather than only visual.")
	lines.append("")
	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
