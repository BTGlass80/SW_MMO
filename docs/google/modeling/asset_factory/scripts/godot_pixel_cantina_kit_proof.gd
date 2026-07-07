extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_pixel_cantina_kit_v0"
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

var _grid: Array = []
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
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	_grid = _build_grid()
	_save_source_image()
	_calculate_stats()
	await _save_and_capture(
		"pixel_cantina_source_card",
		_build_source_card_scene(),
		"Original 48x32 top-down pixel source card for the Cantina kit. Each color is a semantic tile class, not a copied texture."
	)
	await _save_and_capture(
		"pixel_cantina_merge_ab",
		_build_merge_ab_scene(),
		"Left: one cube per non-empty pixel. Center: greedy rectangle merge. Right: same merged rectangles emitted as material-batched meshes."
	)
	await _save_and_capture(
		"pixel_cantina_batched_isometric",
		_build_batched_isometric_scene(),
		"Material-batched pixel Cantina kit from the gameplay/isometric review camera."
	)
	await _save_and_capture(
		"pixel_cantina_room_read_closeup",
		_build_closeup_scene(),
		"Close review of the bar, booths, entrance, back hallway, and clutter readability using batched geometry."
	)
	_write_manifest()
	_write_review()
	print("Godot pixel Cantina kit proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SOURCE_DIR, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_grid() -> Array:
	var grid := []
	for y in range(GRID_H):
		var row := []
		for x in range(GRID_W):
			row.append(EMPTY)
		grid.append(row)

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


func _paint_rect(grid: Array, x: int, y: int, w: int, h: int, value: String) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < GRID_W and py < GRID_H:
				grid[py][px] = value


func _save_source_image() -> void:
	var image := Image.create_empty(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(GRID_H):
		for x in range(GRID_W):
			var category: String = _grid[y][x]
			if category != EMPTY:
				image.set_pixel(x, y, _palette[category])
	var path := SOURCE_DIR + "/cantina_floorplan_48x32.png"
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save source image %s: %s" % [path, err])


func _calculate_stats() -> void:
	var nonempty := _count_nonempty_pixels(_grid)
	var row_runs := _make_row_runs(_grid)
	var rects := _make_greedy_rects(_grid)
	var categories := _used_categories(_grid)
	_stats = {
		"grid_size": "%sx%s" % [GRID_W, GRID_H],
		"nonempty_pixels": nonempty,
		"per_pixel_boxes": nonempty,
		"row_run_boxes": row_runs.size(),
		"greedy_rect_boxes": rects.size(),
		"batched_mesh_nodes": categories.size(),
		"used_categories": categories,
		"per_pixel_triangles_estimate": nonempty * 12,
		"row_run_triangles_estimate": row_runs.size() * 12,
		"greedy_rect_triangles_estimate": rects.size() * 12,
		"batched_triangles_estimate": rects.size() * 12,
		"box_reduction_vs_per_pixel": snapped(100.0 * (1.0 - float(rects.size()) / float(max(1, nonempty))), 0.1),
		"node_reduction_vs_per_pixel": snapped(100.0 * (1.0 - float(categories.size()) / float(max(1, nonempty))), 0.1),
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


func _build_source_card_scene() -> Node3D:
	var root := _base_scene("PixelCantinaSourceCard", Color("#101720"))
	var rects := _make_row_runs(_grid)
	_add_rect_boxes(root, rects, Vector3.ZERO, CELL * 0.95, true)
	_add_camera_light(root, Vector3(0, 0.12, 0), 8.3, Vector3(0, 1, -0.001))
	return root


func _build_merge_ab_scene() -> Node3D:
	var root := _base_scene("PixelCantinaMergeAB", Color("#101720"))
	var per_pixel := _make_per_pixel_rects(_grid)
	var rects := _make_greedy_rects(_grid)
	_add_rect_boxes(root, per_pixel, Vector3(-8.25, 0, 0), CELL * 0.68, false)
	_add_rect_boxes(root, rects, Vector3(0, 0, 0), CELL * 0.68, false)
	_add_batched_rect_meshes(root, rects, Vector3(8.25, 0, 0), CELL * 0.68)
	_add_camera_light(root, Vector3(0, 0.6, 0), 14.5, Vector3(0.9, 0.78, -1.0))
	return root


func _build_batched_isometric_scene() -> Node3D:
	var root := _base_scene("PixelCantinaBatchedIsometric", Color("#0b1017"))
	var rects := _make_greedy_rects(_grid)
	_add_batched_rect_meshes(root, rects, Vector3.ZERO, CELL)
	_add_camera_light(root, Vector3(0, 0.62, 0), 8.6, Vector3(0.9, 0.78, -1.0))
	return root


func _build_closeup_scene() -> Node3D:
	var root := _base_scene("PixelCantinaRoomReadCloseup", Color("#0b1017"))
	var rects := _make_greedy_rects(_grid)
	_add_batched_rect_meshes(root, rects, Vector3.ZERO, CELL)
	_add_camera_light(root, Vector3(1.25, 0.62, -0.15), 5.3, Vector3(0.9, 0.72, -1.0))
	return root


func _make_per_pixel_rects(grid: Array) -> Array[Dictionary]:
	var rects: Array[Dictionary] = []
	for y in range(GRID_H):
		for x in range(GRID_W):
			var category: String = grid[y][x]
			if category != EMPTY:
				rects.append({"x": x, "y": y, "w": 1, "h": 1, "category": category})
	return rects


func _add_rect_boxes(root: Node3D, rects: Array[Dictionary], origin: Vector3, cell: float, flat_card: bool) -> void:
	var holder := Node3D.new()
	holder.name = "rect_box_holder"
	holder.position = origin
	root.add_child(holder)
	for rect in rects:
		var category: String = rect["category"]
		var size := _rect_size(rect, category, cell, flat_card)
		var position := _rect_position(rect, category, cell, flat_card)
		holder.add_child(_new_box("%s_%s_%s" % [category, rect["x"], rect["y"]], position, size, _palette[category]))


func _add_batched_rect_meshes(root: Node3D, rects: Array[Dictionary], origin: Vector3, cell: float) -> void:
	var by_category := {}
	for rect in rects:
		var category: String = rect["category"]
		if not by_category.has(category):
			by_category[category] = []
		by_category[category].append(rect)

	var holder := Node3D.new()
	holder.name = "material_batched_cantina"
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
	sun.name = "PixelCantinaSun"
	sun.rotation_degrees = Vector3(-36, -42, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.5
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "PixelCantinaFill"
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
		"generator": "docs/gpt/asset_factory/scripts/godot_pixel_cantina_kit_proof.gd",
		"source_image": SOURCE_DIR + "/cantina_floorplan_48x32.png",
		"stats": _stats,
		"captures": _captures,
	}
	var file := FileAccess.open(OUT_ROOT + "/pixel_cantina_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Godot Pixel Cantina Kit Proof v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_pixel_cantina_kit_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Test whether the deterministic pixel-card lane works for a Cantina room kit, and whether it is compute-efficient enough to matter.")
	lines.append("")
	lines.append("This is a top-down semantic pixel card, not a texture. Each color means a tile class: floor, wall, door, bar, booth, table, clutter, or light.")
	lines.append("")
	lines.append("## Source Card")
	lines.append("")
	lines.append("`source_images/cantina_floorplan_48x32.png`")
	lines.append("")
	lines.append("![source](source_images/cantina_floorplan_48x32.png)")
	lines.append("")
	lines.append("## Efficiency Stats")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("| --- | ---: |")
	lines.append("| Grid size | `%s` |" % _stats["grid_size"])
	lines.append("| Non-empty source pixels | %s |" % _stats["nonempty_pixels"])
	lines.append("| Per-pixel boxes/nodes | %s |" % _stats["per_pixel_boxes"])
	lines.append("| Same-row run boxes | %s |" % _stats["row_run_boxes"])
	lines.append("| Greedy rectangle boxes | %s |" % _stats["greedy_rect_boxes"])
	lines.append("| Material-batched mesh nodes | %s |" % _stats["batched_mesh_nodes"])
	lines.append("| Box reduction vs per-pixel | %s%% |" % _stats["box_reduction_vs_per_pixel"])
	lines.append("| Node reduction vs per-pixel | %s%% |" % _stats["node_reduction_vs_per_pixel"])
	lines.append("| Per-pixel triangle estimate | %s |" % _stats["per_pixel_triangles_estimate"])
	lines.append("| Greedy rectangle triangle estimate | %s |" % _stats["greedy_rect_triangles_estimate"])
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
	lines.append("Candidate keep for Cantina blockouts, distant/interior LOD, minimap-derived geometry, and fast room-graph visualization.")
	lines.append("")
	lines.append("The batched version is much more compute-friendly than one cube per pixel because it turns a 48x32 semantic card into a small number of material meshes. It is not a replacement for authored Blockbench identity modules such as the kept entrance and bar/booth bay. The best production split is: pixel/GDScript for layout, collision, room LOD, and cheap filler; Blockbench for hero thresholds, signs, bars, booths, and recognizable set pieces.")
	lines.append("")
	lines.append("Next improvement: add a second card for wall elevation/detail so the pixel kit can generate stronger door frames, arches, booth backs, and Cantina clutter without hand placing every module.")
	lines.append("")
	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
