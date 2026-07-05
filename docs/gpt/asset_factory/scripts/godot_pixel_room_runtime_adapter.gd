extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const SPEC_PATH := "res://docs/gpt/asset_factory/specs/pixel_room_cantina_runtime_adapter_v0.json"
const EMPTY := "empty"
const WALK := "walkable"
const BLOCK := "blocker"

var _spec: Dictionary = {}
var _out_root := ""
var _source_dir := ""
var _scene_dir := ""
var _capture_dir := ""
var _grid_w := 0
var _grid_h := 0
var _cell := 0.16
var _floor_grid: Array = []
var _detail_grid: Array = []
var _walk_grid: Array = []
var _block_grid: Array = []
var _sockets: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _stats: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_load_spec()
	_make_dirs()
	_floor_grid = _load_card_layer("floor")
	_detail_grid = _load_card_layer("detail")
	_walk_grid = _build_walk_grid()
	_block_grid = _build_block_grid()
	_sockets = _build_sockets()
	_calculate_stats()
	_save_source_image(_floor_grid, _source_dir + "/floor_card.png")
	_save_source_image(_detail_grid, _source_dir + "/detail_card.png")
	_save_source_image(_walk_grid, _source_dir + "/walkable_mask.png")
	_save_source_image(_block_grid, _source_dir + "/collision_mask.png")
	await _save_and_capture(
		"adapter_clean_room",
		_build_clean_room_scene(),
		"External JSON semantic cards rendered as deterministic voxel room geometry."
	)
	await _save_and_capture(
		"adapter_collision_nav_overlay",
		_build_collision_nav_scene(),
		"External JSON semantic cards emitted walkable rectangles, merged collision boxes, and debug overlays."
	)
	await _save_and_capture(
		"adapter_socket_path_probe",
		_build_socket_path_scene(),
		"Named sockets and grid-routed path probes resolved from the external socket/path JSON."
	)
	_write_manifest()
	_write_review()
	print("Pixel room runtime adapter generated %s captures from %s" % [_captures.size(), SPEC_PATH])
	quit()


func _load_spec() -> void:
	var file := FileAccess.open(SPEC_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing spec: %s" % SPEC_PATH)
		quit(1)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Spec is not a JSON object: %s" % SPEC_PATH)
		quit(1)
		return
	_spec = parsed
	_out_root = String(_spec["output_root"])
	_source_dir = _out_root + "/source_images"
	_scene_dir = _out_root + "/review_scenes"
	_capture_dir = _out_root + "/captures"
	var grid: Dictionary = _spec["grid"]
	_grid_w = int(grid["width"])
	_grid_h = int(grid["height"])
	_cell = float(grid["cell"])


func _make_dirs() -> void:
	for path in [_out_root, _source_dir, _scene_dir, _capture_dir]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _load_card_layer(layer_name: String) -> Array:
	var layers: Dictionary = _spec["layers"]
	var rows: Array = layers[layer_name]
	var symbols: Dictionary = _spec["symbols"]
	var grid := _empty_grid()
	for y in range(min(_grid_h, rows.size())):
		var row := String(rows[y])
		for x in range(min(_grid_w, row.length())):
			var symbol := row.substr(x, 1)
			grid[y][x] = String(symbols.get(symbol, EMPTY))
	return grid


func _empty_grid() -> Array:
	var grid := []
	for y in range(_grid_h):
		var row := []
		for x in range(_grid_w):
			row.append(EMPTY)
		grid.append(row)
	return grid


func _build_walk_grid() -> Array:
	var grid := _empty_grid()
	for y in range(_grid_h):
		for x in range(_grid_w):
			if _is_walkable_cell(x, y):
				grid[y][x] = WALK
	return grid


func _build_block_grid() -> Array:
	var grid := _empty_grid()
	for y in range(_grid_h):
		for x in range(_grid_w):
			if _is_blocker_cell(x, y):
				grid[y][x] = BLOCK
	return grid


func _is_walkable_cell(x: int, y: int) -> bool:
	var floor_category: String = _floor_grid[y][x]
	var detail_category: String = _detail_grid[y][x]
	var walkable_floor: Array = _spec["walkable_floor_categories"]
	if floor_category in walkable_floor:
		return not _is_detail_blocker(detail_category)
	return false


func _is_blocker_cell(x: int, y: int) -> bool:
	var floor_category: String = _floor_grid[y][x]
	var detail_category: String = _detail_grid[y][x]
	var blocker_floor: Array = _spec["blocker_floor_categories"]
	if floor_category in blocker_floor:
		return true
	return _is_detail_blocker(detail_category)


func _is_detail_blocker(category: String) -> bool:
	var blocker_detail: Array = _spec["blocker_detail_categories"]
	return category in blocker_detail


func _build_sockets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var specs: Array = _spec["sockets"]
	for spec in specs:
		var grid_array: Array = spec["grid"]
		var grid_pos := Vector2i(int(grid_array[0]), int(grid_array[1]))
		var kind := String(spec.get("kind", ""))
		var role := String(spec.get("role", kind))
		var world := _grid_to_world(grid_pos.x, grid_pos.y, 0.08)
		var resolved_grid := _nearest_walkable_cell(grid_pos)
		var resolved_world := _grid_to_world(resolved_grid.x, resolved_grid.y, 0.08)
		result.append({
			"id": String(spec["id"]),
			"kind": kind,
			"role": role,
			"facing": String(spec.get("facing", "")),
			"action": String(spec.get("action", "")),
			"grid": {"x": grid_pos.x, "y": grid_pos.y},
			"world": {"x": snapped(world.x, 0.001), "y": snapped(world.y, 0.001), "z": snapped(world.z, 0.001)},
			"walkable": _is_walkable_cell(grid_pos.x, grid_pos.y),
			"resolved_grid": {"x": resolved_grid.x, "y": resolved_grid.y},
			"resolved_world": {"x": snapped(resolved_world.x, 0.001), "y": snapped(resolved_world.y, 0.001), "z": snapped(resolved_world.z, 0.001)},
			"resolved_from_blocked": resolved_grid != grid_pos,
			"path_walkable": _is_walkable_cell(resolved_grid.x, resolved_grid.y),
			"tags": spec.get("tags", []),
		})
	return result


func _nearest_walkable_cell(source: Vector2i) -> Vector2i:
	if _is_in_bounds(source) and _is_walkable_cell(source.x, source.y):
		return source
	var best := source
	var best_distance := INF
	for radius in range(1, _grid_w + _grid_h):
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
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid_w and cell.y < _grid_h


func _calculate_stats() -> void:
	var floor_rects := _make_greedy_rects(_floor_grid)
	var detail_rects := _make_greedy_rects(_detail_grid)
	var walk_rects := _make_greedy_rects(_walk_grid)
	var block_rects := _make_greedy_rects(_block_grid)
	_stats = {
		"grid_size": "%sx%s" % [_grid_w, _grid_h],
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
		"socket_role_counts": _socket_role_counts(),
		"seat_socket_count": _socket_role_count("seat"),
		"stand_socket_count": _socket_role_count("stand") + _socket_role_count("spawn"),
		"use_socket_count": _socket_role_count("use") + _socket_role_count("inspect"),
		"cover_socket_count": _socket_role_count("cover"),
		"nonwalkable_socket_count": _nonwalkable_socket_count(),
		"resolved_socket_count": _resolved_socket_count(),
		"path_probe_count": _path_probe_count(),
		"path_probe_cells": _path_probe_cell_count(),
		"walk_node_reduction_vs_pixels": snapped(100.0 * (1.0 - float(walk_rects.size()) / float(max(1, _count_nonempty_pixels(_walk_grid)))), 0.1),
		"collision_shape_reduction_vs_pixels": snapped(100.0 * (1.0 - float(block_rects.size()) / float(max(1, _count_nonempty_pixels(_block_grid)))), 0.1),
	}


func _socket_role_counts() -> Dictionary:
	var counts := {}
	for socket in _sockets:
		var role := String(socket.get("role", socket.get("kind", "")))
		if role.is_empty():
			role = "unknown"
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


func _socket_role_count(role: String) -> int:
	var counts := _socket_role_counts()
	return int(counts.get(role, 0))


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


func _path_probe_count() -> int:
	var probes: Array = _spec.get("path_probes", [])
	return probes.size()


func _path_probe_cell_count() -> int:
	var total := 0
	var probes: Array = _spec.get("path_probes", [])
	for probe in probes:
		var socket_ids: Array = probe["sockets"]
		for i in range(socket_ids.size() - 1):
			var path := _find_grid_path(_socket_path_grid(String(socket_ids[i])), _socket_path_grid(String(socket_ids[i + 1])))
			total += max(0, path.size() - 1)
	return total


func _count_nonempty_pixels(grid: Array) -> int:
	var count := 0
	for y in range(_grid_h):
		for x in range(_grid_w):
			if grid[y][x] != EMPTY:
				count += 1
	return count


func _make_greedy_rects(grid: Array) -> Array[Dictionary]:
	var used := []
	for y in range(_grid_h):
		var row := []
		for x in range(_grid_w):
			row.append(false)
		used.append(row)
	var rects: Array[Dictionary] = []
	for y in range(_grid_h):
		for x in range(_grid_w):
			var category: String = grid[y][x]
			if category == EMPTY or used[y][x]:
				continue
			var w := 1
			while x + w < _grid_w and not used[y][x + w] and grid[y][x + w] == category:
				w += 1
			var h := 1
			var can_grow := true
			while y + h < _grid_h and can_grow:
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


func _save_source_image(grid: Array, path: String) -> void:
	var image := Image.create_empty(_grid_w, _grid_h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(_grid_h):
		for x in range(_grid_w):
			var category: String = grid[y][x]
			if category != EMPTY:
				image.set_pixel(x, y, _category_color(category))
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save source image %s: %s" % [path, err])


func _build_clean_room_scene() -> Node3D:
	var root := _base_scene("AdapterCleanRoom", Color("#0b1017"))
	_add_layered_room(root, 0.9)
	_add_camera_light(root, _camera_target(), _camera_size(), _camera_vector())
	return root


func _build_collision_nav_scene() -> Node3D:
	var root := _base_scene("AdapterCollisionNavOverlay", Color("#0b1017"))
	_add_layered_room(root, 0.45)
	_add_mask_rects(root, _make_greedy_rects(_walk_grid), Color("#2fd36b"), 0.06)
	_add_mask_rects(root, _make_greedy_rects(_block_grid), Color("#c94b4b"), 0.09)
	_add_collision_shapes(root, _make_greedy_rects(_block_grid))
	_add_camera_light(root, _camera_target(), _camera_size(), _camera_vector())
	return root


func _build_socket_path_scene() -> Node3D:
	var root := _base_scene("AdapterSocketPathProbe", Color("#0b1017"))
	_add_layered_room(root, 0.58)
	_add_socket_markers(root)
	_add_all_path_probes(root)
	_add_debug_actors(root)
	_add_camera_light(root, _camera_target(), _camera_size(), _camera_vector())
	return root


func _add_layered_room(root: Node3D, alpha: float) -> void:
	_add_batched_rect_meshes(root, _make_greedy_rects(_floor_grid), Vector3.ZERO, alpha)
	_add_batched_rect_meshes(root, _make_greedy_rects(_detail_grid), Vector3(0, 0.02, 0), alpha)


func _add_mask_rects(root: Node3D, rects: Array[Dictionary], color: Color, y_offset: float) -> void:
	var holder := Node3D.new()
	holder.name = "mask_rects"
	root.add_child(holder)
	var visual_color := color
	visual_color.a = 0.76
	for rect in rects:
		var category: String = rect["category"]
		holder.add_child(_new_box("%s_%s_%s" % [category, rect["x"], rect["y"]], _rect_position(rect, category, true) + Vector3(0, y_offset, 0), _rect_size(rect, category, true), visual_color, true))


func _add_collision_shapes(root: Node3D, rects: Array[Dictionary]) -> void:
	var body := StaticBody3D.new()
	body.name = "merged_collision_static_body"
	root.add_child(body)
	for rect in rects:
		var shape := BoxShape3D.new()
		shape.size = _rect_size(rect, BLOCK, false) + Vector3(0, 0.08, 0)
		var collision := CollisionShape3D.new()
		collision.name = "collision_%s_%s" % [rect["x"], rect["y"]]
		collision.shape = shape
		collision.position = _rect_position(rect, BLOCK, false)
		body.add_child(collision)


func _add_socket_markers(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "named_runtime_sockets"
	root.add_child(holder)
	for socket in _sockets:
		var pos := Vector3(socket["world"]["x"], socket["world"]["y"], socket["world"]["z"])
		var role := String(socket.get("role", socket.get("kind", "")))
		var color := _socket_role_color(role)
		holder.add_child(_new_box("socket_%s" % socket["id"], pos + Vector3(0, 0.28, 0), Vector3(0.18, 0.34, 0.18), color, false))
		holder.add_child(_new_box("socket_base_%s" % socket["id"], pos + Vector3(0, 0.08, 0), Vector3(0.28, 0.05, 0.28), color.darkened(0.25), false))
		var facing := _facing_vector(String(socket.get("facing", "")))
		if facing != Vector3.ZERO:
			var facing_size := Vector3(_cell * 0.24, 0.06, _cell * 0.7)
			if absf(facing.x) > absf(facing.z):
				facing_size = Vector3(_cell * 0.7, 0.06, _cell * 0.24)
			var facing_pos := pos + Vector3(0, 0.48, 0) + facing * (_cell * 0.48)
			holder.add_child(_new_box("socket_facing_%s" % socket["id"], facing_pos, facing_size, color.lightened(0.18), false))
		if bool(socket["resolved_from_blocked"]):
			var resolved := Vector3(socket["resolved_world"]["x"], socket["resolved_world"]["y"], socket["resolved_world"]["z"])
			holder.add_child(_new_box("socket_walk_resolved_%s" % socket["id"], resolved + Vector3(0, 0.11, 0), Vector3(0.22, 0.05, 0.22), Color("#2fd36b"), false))


func _socket_role_color(role: String) -> Color:
	match role:
		"spawn", "stand":
			return Color("#2fd36b")
		"seat":
			return Color("#d8b36b")
		"use", "inspect":
			return Color("#27d7ff")
		"cover":
			return Color("#c94b4b")
		"transition":
			return Color("#d08a43")
		"prop":
			return Color("#a95e4d")
		"light":
			return Color("#27d7ff")
	return _socket_color(role)


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


func _facing_vector(facing: String) -> Vector3:
	match facing:
		"north":
			return Vector3(0, 0, -1)
		"south":
			return Vector3(0, 0, 1)
		"east":
			return Vector3(1, 0, 0)
		"west":
			return Vector3(-1, 0, 0)
		"northeast":
			return Vector3(1, 0, -1).normalized()
		"northwest":
			return Vector3(-1, 0, -1).normalized()
		"southeast":
			return Vector3(1, 0, 1).normalized()
		"southwest":
			return Vector3(-1, 0, 1).normalized()
		"up":
			return Vector3(0, 1, 0)
		"down":
			return Vector3(0, -1, 0)
	return Vector3.ZERO


func _add_all_path_probes(root: Node3D) -> void:
	var probes: Array = _spec.get("path_probes", [])
	for probe in probes:
		_add_path(root, String(probe["id"]), probe["sockets"], Color("#27d7ff"))


func _add_path(root: Node3D, probe_id: String, socket_ids: Array, color: Color) -> void:
	var holder := Node3D.new()
	holder.name = "socket_path_%s" % probe_id
	root.add_child(holder)
	for i in range(socket_ids.size() - 1):
		var a_id := String(socket_ids[i])
		var b_id := String(socket_ids[i + 1])
		var path := _find_grid_path(_socket_path_grid(a_id), _socket_path_grid(b_id))
		if path.is_empty():
			continue
		for j in range(path.size()):
			var cell: Vector2i = path[j]
			var pos := _grid_to_world(cell.x, cell.y, 0.08) + Vector3(0, 0.18, 0)
			holder.add_child(_new_box("%s_%s_%02d" % [a_id, b_id, j], pos, Vector3(_cell * 0.62, 0.07, _cell * 0.62), color, false))


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
	var guard := _grid_w * _grid_h
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


func _add_debug_actors(root: Node3D) -> void:
	for id in ["entrance_spawn", "bar_order_anchor", "rear_booth_table", "cover_bar_corner"]:
		_add_actor(root, _socket_path_world(id) + Vector3(0, 0.18, 0), _socket_role_color(_socket_role(id)))


func _add_actor(root: Node3D, pos: Vector3, color: Color) -> void:
	var actor := Node3D.new()
	actor.name = "placeholder_actor"
	actor.position = pos
	root.add_child(actor)
	actor.add_child(_new_box("body", Vector3(0, 0.22, 0), Vector3(0.18, 0.36, 0.16), color, false))
	actor.add_child(_new_box("head", Vector3(0, 0.48, -0.01), Vector3(0.16, 0.14, 0.14), color.lightened(0.12), false))
	actor.add_child(_new_box("visor", Vector3(0, 0.49, -0.085), Vector3(0.12, 0.05, 0.025), Color("#15191d"), false))


func _socket_kind(id: String) -> String:
	for socket in _sockets:
		if socket["id"] == id:
			return String(socket["kind"])
	return ""


func _socket_role(id: String) -> String:
	for socket in _sockets:
		if socket["id"] == id:
			return String(socket.get("role", socket.get("kind", "")))
	return ""


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
	var wx := (float(x) + 0.5 - float(_grid_w) / 2.0) * _cell
	var wz := (float(y) + 0.5 - float(_grid_h) / 2.0) * _cell
	return Vector3(wx, height, wz)


func _add_batched_rect_meshes(root: Node3D, rects: Array[Dictionary], origin: Vector3, alpha: float) -> void:
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
			_add_box_faces(st, _rect_position(rect, category, false), _rect_size(rect, category, false))
		var mesh := st.commit()
		var inst := MeshInstance3D.new()
		inst.name = "batch_%s" % category
		inst.mesh = mesh
		var color := _category_color(String(category))
		color.a = alpha
		inst.material_override = _material(color, alpha < 1.0)
		holder.add_child(inst)


func _rect_position(rect: Dictionary, category: String, flat_card: bool) -> Vector3:
	var cx := (float(rect["x"]) + float(rect["w"]) / 2.0 - float(_grid_w) / 2.0) * _cell
	var cz := (float(rect["y"]) + float(rect["h"]) / 2.0 - float(_grid_h) / 2.0) * _cell
	var height := _cell * 0.18 if flat_card else _category_height(category)
	return Vector3(cx, height / 2.0, cz)


func _rect_size(rect: Dictionary, category: String, flat_card: bool) -> Vector3:
	var height := _cell * 0.18 if flat_card else _category_height(category)
	return Vector3(float(rect["w"]) * _cell, height, float(rect["h"]) * _cell)


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
	sun.name = "PixelRoomSun"
	sun.rotation_degrees = Vector3(-36, -42, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.5
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := OmniLight3D.new()
	fill.name = "PixelRoomFill"
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


func _camera_target() -> Vector3:
	var camera: Dictionary = _spec.get("camera", {})
	var target: Array = camera.get("target", [0, 0.68, 0])
	return Vector3(float(target[0]), float(target[1]), float(target[2]))


func _camera_vector() -> Vector3:
	var camera: Dictionary = _spec.get("camera", {})
	var vector: Array = camera.get("vector", [0.9, 0.78, -1.0])
	return Vector3(float(vector[0]), float(vector[1]), float(vector[2]))


func _camera_size() -> float:
	var camera: Dictionary = _spec.get("camera", {})
	return float(camera.get("size", 8.3))


func _category_color(category: String) -> Color:
	var palette: Dictionary = _spec["palette"]
	return Color(String(palette.get(category, "#ffffff")))


func _category_height(category: String) -> float:
	var heights: Dictionary = _spec["heights"]
	return float(heights.get(category, 0.12))


func _material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if color == Color("#27d7ff") or color == Color("#2fd36b"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
	return mat


func _save_and_capture(name: String, scene: Node3D, description: String) -> void:
	var scene_path := _scene_dir + "/%s.tscn" % name
	var capture_path := _capture_dir + "/%s.png" % name
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
	get_root().remove_child(scene)


func _write_manifest() -> void:
	var manifest := {
		"generator": "docs/gpt/asset_factory/scripts/godot_pixel_room_runtime_adapter.gd",
		"spec_path": SPEC_PATH,
		"source_images": {
			"floor": _source_dir + "/floor_card.png",
			"detail": _source_dir + "/detail_card.png",
			"walkable": _source_dir + "/walkable_mask.png",
			"collision": _source_dir + "/collision_mask.png"
		},
		"stats": _stats,
		"sockets": _sockets,
		"captures": _captures,
	}
	var file := FileAccess.open(_out_root + "/pixel_room_runtime_adapter_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Pixel Room Runtime Adapter v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Spec: `%s`" % SPEC_PATH)
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_pixel_room_runtime_adapter.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Prove that the Cantina runtime room pipeline can read external JSON semantic cards, explicit socket roles, and path definitions instead of hard-coded GDScript room data.")
	lines.append("")
	lines.append("## Runtime Stats")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("| --- | ---: |")
	lines.append("| Grid size | `%s` |" % _stats["grid_size"])
	lines.append("| Floor non-empty pixels | %s |" % _stats["floor_nonempty_pixels"])
	lines.append("| Detail non-empty pixels | %s |" % _stats["detail_nonempty_pixels"])
	lines.append("| Walkable pixels | %s |" % _stats["walkable_pixels"])
	lines.append("| Walkable rectangles | %s |" % _stats["walkable_rectangles"])
	lines.append("| Blocker pixels | %s |" % _stats["blocker_pixels"])
	lines.append("| Collision shapes | %s |" % _stats["collision_shapes"])
	lines.append("| Socket count | %s |" % _stats["socket_count"])
	lines.append("| Socket roles | `%s` |" % _format_role_counts(_stats["socket_role_counts"]))
	lines.append("| Seat sockets | %s |" % _stats["seat_socket_count"])
	lines.append("| Stand/spawn sockets | %s |" % _stats["stand_socket_count"])
	lines.append("| Use/inspect sockets | %s |" % _stats["use_socket_count"])
	lines.append("| Cover sockets | %s |" % _stats["cover_socket_count"])
	lines.append("| Sockets resolved to walk cells | %s |" % _stats["resolved_socket_count"])
	lines.append("| Path probes | %s |" % _stats["path_probe_count"])
	lines.append("| Path probe cells | %s |" % _stats["path_probe_cells"])
	lines.append("| Walk mask reduction vs pixels | %s%% |" % _stats["walk_node_reduction_vs_pixels"])
	lines.append("| Collision reduction vs pixels | %s%% |" % _stats["collision_shape_reduction_vs_pixels"])
	lines.append("")
	lines.append("## External Source Cards")
	lines.append("")
	lines.append("- `source_images/floor_card.png`")
	lines.append("- `source_images/detail_card.png`")
	lines.append("- `source_images/walkable_mask.png`")
	lines.append("- `source_images/collision_mask.png`")
	lines.append("")
	lines.append("## Named Sockets")
	lines.append("")
	lines.append("| Id | Kind | Role | Facing | Action | Raw grid | Walkable | Resolved path grid | Tags |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for socket in _sockets:
		lines.append("| `%s` | `%s` | `%s` | `%s` | `%s` | `%s,%s` | `%s` | `%s,%s` | `%s` |" % [
			socket["id"],
			socket["kind"],
			socket["role"],
			socket["facing"],
			socket["action"],
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
		var capture := String(entry["capture_path"]).replace(_out_root + "/", "")
		lines.append("### %s" % entry["id"])
		lines.append("")
		lines.append(entry["description"])
		lines.append("")
		lines.append("![%s](%s)" % [entry["id"], capture])
		lines.append("")
	lines.append("## Verdict")
	lines.append("")
	lines.append("Candidate adapter keep. This keeps the same deterministic voxel room geometry while moving gameplay affordance roles into the external JSON card spec: seats, stand/spawn anchors, use/inspect prompts, cover anchors, transitions, props, and lights.")
	lines.append("")
	lines.append("Next improvement: run this adapter on a second SW_MUSH Cantina room with a new JSON spec, then compare whether socket/collision stats, role counts, and camera captures stay predictable.")
	lines.append("")
	var file := FileAccess.open(_out_root + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


func _format_role_counts(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s:%s" % [key, counts[key]])
	return ", ".join(parts)
