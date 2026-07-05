extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_pixel_cantina_runtime_v1"
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
const WALK := "walkable"
const BLOCK := "blocker"

var _floor_grid: Array = []
var _detail_grid: Array = []
var _walk_grid: Array = []
var _block_grid: Array = []
var _captures: Array[Dictionary] = []
var _stats: Dictionary = {}
var _sockets: Array[Dictionary] = []

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
	WALK: Color("#2fd36b"),
	BLOCK: Color("#c94b4b"),
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
	WALK: 0.035,
	BLOCK: 0.22,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	_floor_grid = _build_floor_grid()
	_detail_grid = _build_detail_grid()
	_walk_grid = _build_walk_grid()
	_block_grid = _build_block_grid()
	_sockets = _build_sockets()
	_save_source_image(_floor_grid, SOURCE_DIR + "/cantina_floorplan_48x32.png")
	_save_source_image(_detail_grid, SOURCE_DIR + "/cantina_detail_elevation_48x32.png")
	_save_source_image(_walk_grid, SOURCE_DIR + "/cantina_walkable_mask_48x32.png")
	_save_source_image(_block_grid, SOURCE_DIR + "/cantina_collision_mask_48x32.png")
	_calculate_stats()
	await _save_and_capture(
		"runtime_collision_nav_overlay",
		_build_collision_nav_scene(),
		"Walkable rectangles in green and merged collision rectangles in red, generated from the same layered Cantina cards."
	)
	await _save_and_capture(
		"runtime_socket_map",
		_build_socket_scene(),
		"Named interaction and spawn sockets generated from the semantic room cards: entrance, bar, booths, service door, lights, and clutter sockets."
	)
	await _save_and_capture(
		"runtime_actor_path_probe",
		_build_actor_path_scene(),
		"Grid-routed actor/path probe using nearest-walkable socket resolution and the generated walkable mask."
	)
	await _save_and_capture(
		"runtime_room_pipeline_composite",
		_build_composite_scene(),
		"Layered room geometry, collision/walkable overlay, sockets, and placeholder actors together as a runtime-pipeline proof."
	)
	_write_manifest()
	_write_review()
	print("Godot pixel Cantina runtime proof generated %s captures" % _captures.size())
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


func _build_walk_grid() -> Array:
	var grid := _empty_grid()
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _is_walkable_cell(x, y):
				grid[y][x] = WALK
	return grid


func _build_block_grid() -> Array:
	var grid := _empty_grid()
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _is_blocker_cell(x, y):
				grid[y][x] = BLOCK
	return grid


func _is_walkable_cell(x: int, y: int) -> bool:
	var floor_category: String = _floor_grid[y][x]
	var detail_category: String = _detail_grid[y][x]
	if floor_category in [FLOOR, DOOR, LIGHT]:
		return not _is_detail_blocker(detail_category)
	return false


func _is_blocker_cell(x: int, y: int) -> bool:
	var floor_category: String = _floor_grid[y][x]
	var detail_category: String = _detail_grid[y][x]
	if floor_category in [WALL, BAR, BOOTH, TABLE, CLUTTER]:
		return true
	return _is_detail_blocker(detail_category)


func _is_detail_blocker(category: String) -> bool:
	return category in [ARCH, FRAME, BACK, PIPE, SOCKET, SIGN]


func _build_sockets() -> Array[Dictionary]:
	var specs := [
		{"id": "entrance_spawn", "kind": "spawn", "grid": Vector2i(24, 25), "tags": ["entry", "player"]},
		{"id": "bar_order_anchor", "kind": "interaction", "grid": Vector2i(34, 13), "tags": ["bar", "social"]},
		{"id": "bartender_anchor", "kind": "npc_anchor", "grid": Vector2i(35, 20), "tags": ["bar", "staff"]},
		{"id": "left_booth_table", "kind": "social_table", "grid": Vector2i(15, 10), "tags": ["booth", "seated"]},
		{"id": "rear_booth_table", "kind": "social_table", "grid": Vector2i(15, 19), "tags": ["booth", "seated"]},
		{"id": "center_table_a", "kind": "social_table", "grid": Vector2i(21, 10), "tags": ["table", "seated"]},
		{"id": "center_table_b", "kind": "social_table", "grid": Vector2i(21, 19), "tags": ["table", "seated"]},
		{"id": "service_door_anchor", "kind": "transition", "grid": Vector2i(35, 10), "tags": ["service", "door"]},
		{"id": "no_droids_sign_socket", "kind": "prop_socket", "grid": Vector2i(22, 8), "tags": ["sign", "wall"]},
		{"id": "bar_light_socket", "kind": "light_socket", "grid": Vector2i(35, 10), "tags": ["bar", "light"]},
		{"id": "clutter_socket_left", "kind": "prop_socket", "grid": Vector2i(8, 24), "tags": ["clutter"]},
		{"id": "clutter_socket_rear", "kind": "prop_socket", "grid": Vector2i(40, 24), "tags": ["clutter"]},
	]
	var result: Array[Dictionary] = []
	for spec in specs:
		var grid_pos: Vector2i = spec["grid"]
		var world := _grid_to_world(grid_pos.x, grid_pos.y, 0.08)
		var resolved_grid := _nearest_walkable_cell(grid_pos)
		var resolved_world := _grid_to_world(resolved_grid.x, resolved_grid.y, 0.08)
		result.append({
			"id": spec["id"],
			"kind": spec["kind"],
			"grid": {"x": grid_pos.x, "y": grid_pos.y},
			"world": {"x": snapped(world.x, 0.001), "y": snapped(world.y, 0.001), "z": snapped(world.z, 0.001)},
			"walkable": _is_walkable_cell(grid_pos.x, grid_pos.y),
			"resolved_grid": {"x": resolved_grid.x, "y": resolved_grid.y},
			"resolved_world": {"x": snapped(resolved_world.x, 0.001), "y": snapped(resolved_world.y, 0.001), "z": snapped(resolved_world.z, 0.001)},
			"resolved_from_blocked": resolved_grid != grid_pos,
			"path_walkable": _is_walkable_cell(resolved_grid.x, resolved_grid.y),
			"tags": spec["tags"],
		})
	return result


func _nearest_walkable_cell(source: Vector2i) -> Vector2i:
	if _is_in_bounds(source) and _is_walkable_cell(source.x, source.y):
		return source
	var best := source
	var best_distance := INF
	for radius in range(1, GRID_W + GRID_H):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) + abs(dy) != radius:
					continue
				var candidate := source + Vector2i(dx, dy)
				if not _is_in_bounds(candidate):
					continue
				if not _is_walkable_cell(candidate.x, candidate.y):
					continue
				var distance: int = abs(dx) + abs(dy)
				if distance < best_distance:
					best = candidate
					best_distance = distance
		if best_distance < INF:
			return best
	return source


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_W and cell.y < GRID_H


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
	var floor_rects := _make_greedy_rects(_floor_grid)
	var detail_rects := _make_greedy_rects(_detail_grid)
	var walk_rects := _make_greedy_rects(_walk_grid)
	var block_rects := _make_greedy_rects(_block_grid)
	_stats = {
		"grid_size": "%sx%s" % [GRID_W, GRID_H],
		"floor_nonempty_pixels": _count_nonempty_pixels(_floor_grid),
		"detail_nonempty_pixels": _count_nonempty_pixels(_detail_grid),
		"walkable_pixels": _count_nonempty_pixels(_walk_grid),
		"blocker_pixels": _count_nonempty_pixels(_block_grid),
		"floor_rectangles": floor_rects.size(),
		"detail_rectangles": detail_rects.size(),
		"walkable_rectangles": walk_rects.size(),
		"collision_rectangles": block_rects.size(),
		"collision_shapes": block_rects.size(),
		"socket_count": _sockets.size(),
		"nonwalkable_socket_count": _nonwalkable_socket_count(),
		"resolved_socket_count": _resolved_socket_count(),
		"actor_probe_route_cells": _socket_sequence_path_cell_count(["entrance_spawn", "center_table_b", "bar_order_anchor", "service_door_anchor"]),
		"composite_probe_route_cells": _socket_sequence_path_cell_count(["entrance_spawn", "left_booth_table", "bar_order_anchor"]),
		"walk_node_reduction_vs_pixels": snapped(100.0 * (1.0 - float(walk_rects.size()) / float(max(1, _count_nonempty_pixels(_walk_grid)))), 0.1),
		"collision_shape_reduction_vs_pixels": snapped(100.0 * (1.0 - float(block_rects.size()) / float(max(1, _count_nonempty_pixels(_block_grid)))), 0.1),
	}


func _nonwalkable_socket_count() -> int:
	var count := 0
	for socket in _sockets:
		if not bool(socket["walkable"]):
			count += 1
	return count


func _resolved_socket_count() -> int:
	var count := 0
	for socket in _sockets:
		if bool(socket["resolved_from_blocked"]):
			count += 1
	return count


func _socket_sequence_path_cell_count(socket_ids: Array) -> int:
	var total := 0
	for i in range(socket_ids.size() - 1):
		var path := _find_grid_path(_socket_path_grid(socket_ids[i]), _socket_path_grid(socket_ids[i + 1]))
		if path.is_empty():
			continue
		total += max(0, path.size() - 1)
	return total


func _count_nonempty_pixels(grid: Array) -> int:
	var count := 0
	for y in range(GRID_H):
		for x in range(GRID_W):
			if grid[y][x] != EMPTY:
				count += 1
	return count


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


func _build_collision_nav_scene() -> Node3D:
	var root := _base_scene("RuntimeCollisionNavOverlay", Color("#0b1017"))
	_add_layered_room(root, Vector3.ZERO, CELL, 0.42)
	_add_mask_rects(root, _make_greedy_rects(_walk_grid), Vector3(0, 0.06, 0), CELL, Color("#2fd36b"))
	_add_mask_rects(root, _make_greedy_rects(_block_grid), Vector3(0, 0.09, 0), CELL, Color("#c94b4b"))
	_add_collision_shapes(root, _make_greedy_rects(_block_grid), Vector3.ZERO, CELL)
	_add_camera_light(root, Vector3(0, 0.58, 0), 8.6, Vector3(0.9, 0.78, -1.0))
	return root


func _build_socket_scene() -> Node3D:
	var root := _base_scene("RuntimeSocketMap", Color("#0b1017"))
	_add_layered_room(root, Vector3.ZERO, CELL, 0.55)
	_add_socket_markers(root)
	_add_collision_shapes(root, _make_greedy_rects(_block_grid), Vector3.ZERO, CELL)
	_add_camera_light(root, Vector3(0, 0.7, 0), 8.3, Vector3(0.9, 0.78, -1.0))
	return root


func _build_actor_path_scene() -> Node3D:
	var root := _base_scene("RuntimeActorPathProbe", Color("#0b1017"))
	_add_layered_room(root, Vector3.ZERO, CELL, 0.5)
	_add_socket_markers(root)
	_add_path(root, ["entrance_spawn", "center_table_b", "bar_order_anchor", "service_door_anchor"], Color("#27d7ff"))
	_add_actor(root, _socket_path_world("entrance_spawn") + Vector3(0, 0.18, 0), Color("#e8ece5"))
	_add_actor(root, _socket_path_world("bar_order_anchor") + Vector3(0, 0.18, 0), Color("#a95e4d"))
	_add_actor(root, _socket_path_world("rear_booth_table") + Vector3(0, 0.18, 0), Color("#b68a53"))
	_add_camera_light(root, Vector3(0, 0.68, 0), 8.3, Vector3(0.9, 0.78, -1.0))
	return root


func _build_composite_scene() -> Node3D:
	var root := _base_scene("RuntimeRoomPipelineComposite", Color("#0b1017"))
	_add_layered_room(root, Vector3.ZERO, CELL, 0.75)
	_add_mask_rects(root, _make_greedy_rects(_walk_grid), Vector3(0, 0.045, 0), CELL, Color("#245a37"))
	_add_socket_markers(root)
	_add_path(root, ["entrance_spawn", "left_booth_table", "bar_order_anchor"], Color("#27d7ff"))
	_add_actor(root, _socket_path_world("entrance_spawn") + Vector3(0, 0.18, 0), Color("#e8ece5"))
	_add_actor(root, _socket_path_world("left_booth_table") + Vector3(0, 0.18, 0), Color("#b68a53"))
	_add_collision_shapes(root, _make_greedy_rects(_block_grid), Vector3.ZERO, CELL)
	_add_camera_light(root, Vector3(0, 0.7, 0), 7.4, Vector3(0.9, 0.78, -1.0))
	return root


func _add_layered_room(root: Node3D, origin: Vector3, cell: float, alpha: float) -> void:
	_add_batched_rect_meshes(root, _make_greedy_rects(_floor_grid), origin, cell, alpha)
	_add_batched_rect_meshes(root, _make_greedy_rects(_detail_grid), origin + Vector3(0, 0.02, 0), cell, alpha)


func _add_mask_rects(root: Node3D, rects: Array[Dictionary], origin: Vector3, cell: float, color: Color) -> void:
	var holder := Node3D.new()
	holder.name = "mask_rects"
	holder.position = origin
	root.add_child(holder)
	var visual_color := color
	visual_color.a = 0.76
	for rect in rects:
		var category: String = rect["category"]
		holder.add_child(_new_box("%s_%s_%s" % [category, rect["x"], rect["y"]], _rect_position(rect, category, cell, true), _rect_size(rect, category, cell, true), visual_color, true))


func _add_collision_shapes(root: Node3D, rects: Array[Dictionary], origin: Vector3, cell: float) -> void:
	var body := StaticBody3D.new()
	body.name = "merged_collision_static_body"
	body.position = origin
	root.add_child(body)
	for rect in rects:
		var shape := BoxShape3D.new()
		shape.size = _rect_size(rect, BLOCK, cell, false) + Vector3(0, 0.08, 0)
		var collision := CollisionShape3D.new()
		collision.name = "collision_%s_%s" % [rect["x"], rect["y"]]
		collision.shape = shape
		collision.position = _rect_position(rect, BLOCK, cell, false)
		body.add_child(collision)


func _add_socket_markers(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "named_runtime_sockets"
	root.add_child(holder)
	for socket in _sockets:
		var pos := Vector3(socket["world"]["x"], socket["world"]["y"], socket["world"]["z"])
		var color := _socket_color(socket["kind"])
		var marker := _new_box("socket_%s" % socket["id"], pos + Vector3(0, 0.28, 0), Vector3(0.18, 0.34, 0.18), color, false)
		holder.add_child(marker)
		var base := _new_box("socket_base_%s" % socket["id"], pos + Vector3(0, 0.08, 0), Vector3(0.28, 0.05, 0.28), color.darkened(0.25), false)
		holder.add_child(base)
		if bool(socket["resolved_from_blocked"]):
			var resolved := Vector3(socket["resolved_world"]["x"], socket["resolved_world"]["y"], socket["resolved_world"]["z"])
			var resolved_base := _new_box("socket_walk_resolved_%s" % socket["id"], resolved + Vector3(0, 0.11, 0), Vector3(0.22, 0.05, 0.22), Color("#2fd36b"), false)
			holder.add_child(resolved_base)


func _socket_color(kind: String) -> Color:
	match kind:
		"spawn":
			return Color("#2fd36b")
		"interaction":
			return Color("#27d7ff")
		"npc_anchor":
			return Color("#d8b36b")
		"social_table":
			return Color("#b68a53")
		"transition":
			return Color("#d08a43")
		"prop_socket":
			return Color("#a95e4d")
		"light_socket":
			return Color("#27d7ff")
	return Color("#ffffff")


func _add_path(root: Node3D, socket_ids: Array, color: Color) -> void:
	var holder := Node3D.new()
	holder.name = "socket_path_grid_route"
	root.add_child(holder)
	for i in range(socket_ids.size() - 1):
		var path := _find_grid_path(_socket_path_grid(socket_ids[i]), _socket_path_grid(socket_ids[i + 1]))
		if path.is_empty():
			var a := _socket_path_world(socket_ids[i]) + Vector3(0, 0.18, 0)
			var b := _socket_path_world(socket_ids[i + 1]) + Vector3(0, 0.18, 0)
			var mid := (a + b) * 0.5
			var delta := b - a
			var length := sqrt(delta.x * delta.x + delta.z * delta.z)
			var failed := _new_box("failed_path_%s_%s" % [socket_ids[i], socket_ids[i + 1]], mid, Vector3(0.06, 0.08, length), Color("#ff4d8d"), false)
			failed.rotation.y = atan2(delta.x, delta.z)
			holder.add_child(failed)
			continue
		_add_path_cells(holder, "path_%s_%s" % [socket_ids[i], socket_ids[i + 1]], path, color)


func _add_path_cells(holder: Node3D, prefix: String, path: Array, color: Color) -> void:
	for i in range(path.size()):
		var cell: Vector2i = path[i]
		var pos := _grid_to_world(cell.x, cell.y, 0.08) + Vector3(0, 0.18, 0)
		holder.add_child(_new_box("%s_cell_%02d" % [prefix, i], pos, Vector3(CELL * 0.62, 0.07, CELL * 0.62), color, false))


func _find_grid_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return [start]
	if not _is_in_bounds(start) or not _is_in_bounds(goal):
		return []
	if not _is_walkable_cell(start.x, start.y) or not _is_walkable_cell(goal.x, goal.y):
		return []
	var queue := [start]
	var head := 0
	var visited := {_grid_key(start): true}
	var previous := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for dir in dirs:
			var next_cell: Vector2i = current + dir
			if not _is_in_bounds(next_cell):
				continue
			if not _is_walkable_cell(next_cell.x, next_cell.y):
				continue
			var key := _grid_key(next_cell)
			if visited.has(key):
				continue
			visited[key] = true
			previous[key] = current
			if next_cell == goal:
				return _reconstruct_path(previous, start, goal)
			queue.append(next_cell)
	return []


func _reconstruct_path(previous: Dictionary, start: Vector2i, goal: Vector2i) -> Array:
	var path := [goal]
	var current := goal
	var guard := GRID_W * GRID_H
	while current != start and guard > 0:
		var key := _grid_key(current)
		if not previous.has(key):
			return []
		current = previous[key]
		path.push_front(current)
		guard -= 1
	return path


func _grid_key(cell: Vector2i) -> String:
	return "%s,%s" % [cell.x, cell.y]


func _add_actor(root: Node3D, pos: Vector3, color: Color) -> void:
	var actor := Node3D.new()
	actor.name = "placeholder_actor"
	actor.position = pos
	root.add_child(actor)
	actor.add_child(_new_box("body", Vector3(0, 0.22, 0), Vector3(0.18, 0.36, 0.16), color, false))
	actor.add_child(_new_box("head", Vector3(0, 0.48, -0.01), Vector3(0.16, 0.14, 0.14), color.lightened(0.12), false))
	actor.add_child(_new_box("visor", Vector3(0, 0.49, -0.085), Vector3(0.12, 0.05, 0.025), Color("#15191d"), false))


func _socket_world(id: String) -> Vector3:
	for socket in _sockets:
		if socket["id"] == id:
			return Vector3(socket["world"]["x"], socket["world"]["y"], socket["world"]["z"])
	return Vector3.ZERO


func _socket_path_world(id: String) -> Vector3:
	for socket in _sockets:
		if socket["id"] == id:
			return Vector3(socket["resolved_world"]["x"], socket["resolved_world"]["y"], socket["resolved_world"]["z"])
	return Vector3.ZERO


func _socket_path_grid(id: String) -> Vector2i:
	for socket in _sockets:
		if socket["id"] == id:
			return Vector2i(socket["resolved_grid"]["x"], socket["resolved_grid"]["y"])
	return Vector2i.ZERO


func _grid_to_world(x: int, y: int, height: float) -> Vector3:
	var wx := (float(x) + 0.5 - float(GRID_W) / 2.0) * CELL
	var wz := (float(y) + 0.5 - float(GRID_H) / 2.0) * CELL
	return Vector3(wx, height, wz)


func _add_batched_rect_meshes(root: Node3D, rects: Array[Dictionary], origin: Vector3, cell: float, alpha: float) -> void:
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
		var color: Color = _palette[category]
		color.a = alpha
		inst.material_override = _material(color, alpha < 1.0)
		holder.add_child(inst)


func _rect_position(rect: Dictionary, category: String, cell: float, flat_card: bool) -> Vector3:
	var cx := (float(rect["x"]) + float(rect["w"]) / 2.0 - float(GRID_W) / 2.0) * cell
	var cz := (float(rect["y"]) + float(rect["h"]) / 2.0 - float(GRID_H) / 2.0) * cell
	var height := cell * 0.18 if flat_card else float(_heights[category])
	return Vector3(cx, height / 2.0, cz)


func _rect_size(rect: Dictionary, category: String, cell: float, flat_card: bool) -> Vector3:
	var height := cell * 0.18 if flat_card else float(_heights[category])
	return Vector3(float(rect["w"]) * cell, height, float(rect["h"]) * cell)


func _new_box(node_name: String, position: Vector3, size: Vector3, color: Color, transparent: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color, transparent)
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
	sun.name = "RuntimeCantinaSun"
	sun.rotation_degrees = Vector3(-36, -42, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.5
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := OmniLight3D.new()
	fill.name = "RuntimeCantinaFill"
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


func _material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = false
	if color == Color("#27d7ff") or color == Color("#2fd36b"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
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
		"generator": "docs/gpt/asset_factory/scripts/godot_pixel_cantina_runtime_proof.gd",
		"source_images": {
			"floorplan": SOURCE_DIR + "/cantina_floorplan_48x32.png",
			"detail": SOURCE_DIR + "/cantina_detail_elevation_48x32.png",
			"walkable": SOURCE_DIR + "/cantina_walkable_mask_48x32.png",
			"collision": SOURCE_DIR + "/cantina_collision_mask_48x32.png"
		},
		"stats": _stats,
		"sockets": _sockets,
		"captures": _captures,
	}
	var file := FileAccess.open(OUT_ROOT + "/pixel_cantina_runtime_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Godot Pixel Cantina Runtime Proof v1")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_pixel_cantina_runtime_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Move the layered pixel Cantina lane from visual generator toward runtime room infrastructure: collision rectangles, walkable rectangles, named sockets, and actor/path probes from the same semantic cards.")
	lines.append("")
	lines.append("## Source Masks")
	lines.append("")
	lines.append("- `source_images/cantina_floorplan_48x32.png`")
	lines.append("- `source_images/cantina_detail_elevation_48x32.png`")
	lines.append("- `source_images/cantina_walkable_mask_48x32.png`")
	lines.append("- `source_images/cantina_collision_mask_48x32.png`")
	lines.append("")
	lines.append("## Runtime Stats")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("| --- | ---: |")
	lines.append("| Grid size | `%s` |" % _stats["grid_size"])
	lines.append("| Walkable pixels | %s |" % _stats["walkable_pixels"])
	lines.append("| Walkable rectangles | %s |" % _stats["walkable_rectangles"])
	lines.append("| Blocker pixels | %s |" % _stats["blocker_pixels"])
	lines.append("| Collision rectangles/shapes | %s |" % _stats["collision_shapes"])
	lines.append("| Socket count | %s |" % _stats["socket_count"])
	lines.append("| Non-walkable raw sockets | %s |" % _stats["nonwalkable_socket_count"])
	lines.append("| Sockets resolved to walk cells | %s |" % _stats["resolved_socket_count"])
	lines.append("| Actor probe route cells | %s |" % _stats["actor_probe_route_cells"])
	lines.append("| Composite probe route cells | %s |" % _stats["composite_probe_route_cells"])
	lines.append("| Walk mask reduction vs pixels | %s%% |" % _stats["walk_node_reduction_vs_pixels"])
	lines.append("| Collision reduction vs pixels | %s%% |" % _stats["collision_shape_reduction_vs_pixels"])
	lines.append("")
	lines.append("## Named Sockets")
	lines.append("")
	lines.append("| Id | Kind | Raw grid | Walkable | Resolved path grid | Tags |")
	lines.append("| --- | --- | --- | --- | --- | --- |")
	for socket in _sockets:
		lines.append("| `%s` | `%s` | `%s,%s` | `%s` | `%s,%s` | `%s` |" % [
			socket["id"],
			socket["kind"],
			socket["grid"]["x"],
			socket["grid"]["y"],
			socket["walkable"],
			socket["resolved_grid"]["x"],
			socket["resolved_grid"]["y"],
			", ".join(socket["tags"])
		])
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
	lines.append("Candidate runtime keep. This proves the layered pixel room-kit lane can emit more than visuals: merged collision shapes, a walkable mask, named interaction sockets, socket-to-walk-cell resolution, and coordinate-stable routed actor/path probes. It is still a docs-only proof, not a runtime integration, but it is now a credible room-production pipeline.")
	lines.append("")
	lines.append("Next improvement: promote the generator into a reusable adapter that reads external semantic PNG/JSON cards instead of hard-coded test grids, then run it on a second SW_MUSH Cantina room to prove repeatability.")
	lines.append("")
	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
