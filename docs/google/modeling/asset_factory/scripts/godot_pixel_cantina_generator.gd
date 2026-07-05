extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)

# Default configs
var GRID_W := 48
var GRID_H := 32
var CELL := 0.16
const EMPTY := "."

var _room_id := ""
var _display_name := ""
var _output_dir := ""
var _floorplan_path := ""
var _detail_path := ""
var _walkable_path := ""
var _collision_path := ""

var _palette_hex := {} # hex -> category
var _palette_colors := {} # category -> Color
var _heights := {} # category -> float
var _detail_blockers := []
var _raw_sockets_def := []
var _path_probes_def := []

var _floor_grid: Array = []
var _detail_grid: Array = []
var _walk_grid: Array = []
var _block_grid: Array = []
var _captures: Array[Dictionary] = []
var _stats: Dictionary = {}
var _sockets: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var spec_path := _parse_spec_path()
	if not _load_spec(spec_path):
		printerr("Failed to load spec JSON: %s" % spec_path)
		quit(1)
		return
		
	_make_dirs()
	_ensure_source_images()
	
	# Load grids from PNG
	_floor_grid = _load_grid_from_image(_floorplan_path)
	_detail_grid = _load_grid_from_image(_detail_path)
	
	# Compute masks
	_walk_grid = _build_walk_grid()
	_block_grid = _build_block_grid()
	_sockets = _build_sockets()
	
	# Save computed masks
	_save_mask_image(_walk_grid, _walkable_path, Color("#2fd36b"))
	_save_mask_image(_block_grid, _collision_path, Color("#c94b4b"))
	
	_calculate_stats()
	_save_collision_grid_json()

	
	# Build scenes and captures
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
	
	_write_manifest(spec_path)
	_write_review()
	
	print("Godot pixel Cantina generator completed: %s captures written to %s" % [_captures.size(), _output_dir])
	quit()


func _parse_spec_path() -> String:
	var user_args := OS.get_cmdline_user_args()
	var spec_path := ""
	for i in range(user_args.size()):
		if user_args[i] == "--spec" and i + 1 < user_args.size():
			spec_path = user_args[i + 1]
			break
	if spec_path == "":
		var args := OS.get_cmdline_args()
		for i in range(args.size()):
			if args[i] == "--spec" and i + 1 < args.size():
				spec_path = args[i + 1]
				break
	if spec_path == "":
		spec_path = "res://docs/google/modeling/asset_factory/specs/cantina_main_bar.json"
	return spec_path


func _load_spec(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var content := file.get_as_text()
	var json = JSON.parse_string(content)
	if not json:
		return false
		
	_room_id = json["room_id"]
	_display_name = json["display_name"]
	GRID_W = int(json.get("grid_width", 48))
	GRID_H = int(json.get("grid_height", 32))
	CELL = float(json.get("cell_size", 0.16))
	_output_dir = json["output_dir"]
	
	_floorplan_path = json["floorplan_image"]
	_detail_path = json["detail_image"]
	_walkable_path = _output_dir + "/source_images/cantina_walkable_mask_%sx%s.png" % [GRID_W, GRID_H]
	_collision_path = _output_dir + "/source_images/cantina_collision_mask_%sx%s.png" % [GRID_W, GRID_H]
	
	# Load palette
	var pal: Dictionary = json["palette"]
	_palette_hex = {}
	_palette_colors = {}
	for hex in pal.keys():
		var category = pal[hex]
		var clean_hex = hex.to_lower().replace("#", "")
		_palette_hex[clean_hex] = category
		_palette_colors[category] = Color("#" + clean_hex)
	
	# Fill default mask colors if missing
	_palette_colors["walkable"] = Color("#2fd36b")
	_palette_colors["blocker"] = Color("#c94b4b")
	
	# Load heights
	var h_dict: Dictionary = json["heights"]
	_heights = {}
	for cat in h_dict.keys():
		_heights[cat] = float(h_dict[cat])
	_heights["walkable"] = 0.035
	_heights["blocker"] = 0.22
		
	_detail_blockers = json.get("detail_blockers", [])
	_raw_sockets_def = json.get("sockets", [])
	_path_probes_def = json.get("path_probes", [])
	
	return true


func _make_dirs() -> void:
	for path in [_output_dir, _output_dir + "/source_images", _output_dir + "/review_scenes", _output_dir + "/captures"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _ensure_source_images() -> void:
	# If images do not exist on disk, we programmatically draw them based on the room_id
	var fp_exists := FileAccess.file_exists(_floorplan_path)
	var dt_exists := FileAccess.file_exists(_detail_path)
	
	if not fp_exists or not dt_exists:
		print("Generating default source PNGs for room_id: %s" % _room_id)
		var floor_grid := _empty_grid()
		var detail_grid := _empty_grid()
		
		if _room_id == "cantina_main_bar":
			_paint_main_bar_grids(floor_grid, detail_grid)
		elif _room_id == "cantina_back_hallway":
			_paint_back_hallway_grids(floor_grid, detail_grid)
			
		if not fp_exists:
			_save_grid_image(floor_grid, _floorplan_path)
		if not dt_exists:
			_save_grid_image(detail_grid, _detail_path)


func _paint_main_bar_grids(floor_grid: Array, detail_grid: Array) -> void:
	# Main circular floor of radius 36 cells (28.8 meters diameter!)
	_paint_circle(floor_grid, 48, 48, 36.0, "floor")
	# Outer wall drum
	_paint_ring(floor_grid, 48, 48, 36.0, 1.2, "wall")
	
	# Recess 6 circular seating alcoves (radius 7 cells) along the perimeter
	var angles := [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]
	for a in angles:
		var rad := deg_to_rad(a)
		var ax := int(round(48.0 + 36.0 * cos(rad)))
		var ay := int(round(48.0 + 36.0 * sin(rad)))
		
		# Skip the entrance and hallway transition openings
		if a == 90.0 or a == 270.0:
			continue
			
		_paint_circle(floor_grid, ax, ay, 7.0, "floor")
		_paint_circle(floor_grid, ax, ay, 6.5, "empty")
		_paint_ring(floor_grid, ax, ay, 7.0, 1.0, "wall")
		
		# Booth bench along the outer half of the alcove (away from the center)
		for y in range(ay - 7, ay + 8):
			for x in range(ax - 7, ax + 8):
				if x >= 0 and y >= 0 and x < GRID_W and y < GRID_H:
					var dist_to_alcove := sqrt(float((x - ax)*(x - ax) + (y - ay)*(y - ay)))
					var dist_to_center := sqrt(float((x - 48)*(x - 48) + (y - 48)*(y - 48)))
					if dist_to_alcove <= 6.5 and dist_to_alcove >= 4.5 and dist_to_center > 36.0:
						floor_grid[y][x] = "booth"
						detail_grid[y][x] = "booth_back"
						
		# Table in center of the alcove
		_paint_circle(floor_grid, ax, ay, 2.0, "table")
		detail_grid[ay][ax] = "lamp"
		
	# Grand Entrance Corridor facing +Z (bottom, y=90)
	_paint_rect(floor_grid, 43, 78, 10, 18, "floor")
	_paint_rect(floor_grid, 42, 78, 1, 18, "wall")
	_paint_rect(floor_grid, 53, 78, 1, 18, "wall")
	# Clean main circle wall cut-out at entrance hallway
	_paint_rect(floor_grid, 43, 76, 10, 2, "floor")
	
	# Entrance archway details
	_paint_rect(detail_grid, 43, 93, 10, 2, "arch")
	_paint_rect(detail_grid, 42, 92, 1, 2, "frame")
	_paint_rect(detail_grid, 53, 92, 1, 2, "frame")
	_paint_rect(detail_grid, 46, 82, 4, 1, "sign")

	# Service Door to Back Hallway (top, y=10)
	_paint_rect(floor_grid, 45, 8, 6, 4, "floor")
	_paint_rect(floor_grid, 45, 11, 6, 1, "floor")
	_paint_rect(floor_grid, 44, 8, 1, 4, "wall")
	_paint_rect(floor_grid, 51, 8, 1, 4, "wall")
	_paint_rect(detail_grid, 45, 10, 6, 2, "arch")

	
	# Central circular bar island counter
	_paint_ring(floor_grid, 48, 48, 12.0, 1.2, "bar")
	# Inner bar flooring for bartenders
	_paint_circle(floor_grid, 48, 48, 10.8, "floor")
	# Central tap/liquor storage pillar
	_paint_circle(floor_grid, 48, 48, 5.0, "clutter")
	_paint_ring(detail_grid, 48, 48, 5.0, 1.0, "pipe")
	# Overhead circular light ring above bar counter
	_paint_ring(detail_grid, 48, 48, 12.0, 1.0, "lamp")
	
	# Additional ambient floor lights in walkways
	_paint_circle(floor_grid, 30, 30, 1.0, "light")
	_paint_circle(floor_grid, 66, 30, 1.0, "light")
	_paint_circle(floor_grid, 30, 66, 1.0, "light")
	_paint_circle(floor_grid, 66, 66, 1.0, "light")


func _paint_back_hallway_grids(floor_grid: Array, detail_grid: Array) -> void:
	# Main spacious horizontal corridor
	_paint_rect(floor_grid, 10, 43, 76, 10, "floor")
	_paint_rect(floor_grid, 10, 42, 76, 1, "wall")
	_paint_rect(floor_grid, 10, 53, 76, 1, "wall")
	_paint_rect(floor_grid, 9, 42, 1, 12, "wall")
	_paint_rect(floor_grid, 86, 42, 1, 12, "wall")
	
	# Hallway transition door connecting to main bar
	_paint_rect(floor_grid, 45, 42, 6, 1, "floor")
	_paint_rect(detail_grid, 45, 42, 6, 1, "arch")

	# Three spacious Restrooms (each 10x8 cells) on the left side
	var restroom_xs := [14, 26, 38]
	for rx in restroom_xs:
		_paint_rect(floor_grid, rx, 30, 10, 12, "floor")
		_paint_rect(floor_grid, rx, 30, 10, 1, "wall")
		_paint_rect(floor_grid, rx, 31, 1, 11, "wall")
		_paint_rect(floor_grid, rx + 9, 31, 1, 11, "wall")
		# Entry door
		_paint_rect(floor_grid, rx + 4, 42, 2, 1, "floor")
		_paint_rect(detail_grid, rx + 4, 42, 2, 1, "frame")

	# Cellar Trapdoor in corridor floor
	_paint_rect(floor_grid, 22, 47, 3, 3, "clutter")
	_paint_rect(detail_grid, 22, 47, 3, 3, "socket")

	# Bartender's Office (bottom corridor room)
	_paint_rect(floor_grid, 34, 54, 12, 12, "floor")
	_paint_rect(floor_grid, 33, 54, 1, 12, "wall")
	_paint_rect(floor_grid, 46, 54, 1, 12, "wall")
	_paint_rect(floor_grid, 34, 65, 12, 1, "wall")
	# Office entry curtain door
	_paint_rect(floor_grid, 39, 53, 2, 1, "floor")
	_paint_rect(detail_grid, 39, 53, 2, 1, "arch")

	# Sabacc Parlor (east end) - spacious circular lounge of radius 16 cells
	_paint_circle(floor_grid, 70, 48, 16.0, "floor")
	_paint_ring(floor_grid, 70, 48, 16.0, 1.2, "wall")
	# Clear corridor wall overlap
	_paint_circle(floor_grid, 70, 48, 15.5, "empty")
	_paint_rect(floor_grid, 54, 43, 6, 10, "floor")
	
	# Raised platform in the center of the Sabacc room
	_paint_circle(floor_grid, 70, 48, 9.5, "raised")
	
	# Massive central circular Sabacc card table (radius 4 cells)
	_paint_circle(floor_grid, 70, 48, 4.0, "table")
	detail_grid[48][70] = "lamp"
	
	# Surround table with a circular bench
	_paint_ring(floor_grid, 70, 48, 7.0, 1.0, "booth")

	_paint_ring(detail_grid, 70, 48, 7.0, 1.0, "booth_back")
	
	# Ambient piping and lights in the Sabacc room
	_paint_ring(detail_grid, 70, 48, 14.0, 1.0, "pipe")
	_paint_circle(floor_grid, 60, 40, 1.0, "light")
	_paint_circle(floor_grid, 80, 40, 1.0, "light")



func _color_distance(c1: Color, c2: Color) -> float:
	var dr := c1.r - c2.r
	var dg := c1.g - c2.g
	var db := c1.b - c2.b
	var da := c1.a - c2.a
	return sqrt(dr*dr + dg*dg + db*db + da*da)


func _load_grid_from_image(path: String) -> Array:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var grid := _empty_grid()
	
	for y in range(GRID_H):
		for x in range(GRID_W):
			var color := img.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			var hex := color.to_html(false).to_lower()
			if _palette_hex.has(hex):
				grid[y][x] = _palette_hex[hex]
			else:
				# Fallback exact match comparison by Color distance if hex differs slightly
				var closest_cat := EMPTY
				var min_dist := INF
				for cat in _palette_colors.keys():
					var c: Color = _palette_colors[cat]
					var dist := _color_distance(color, c)
					if dist < min_dist and dist < 0.02:
						min_dist = dist
						closest_cat = cat
				grid[y][x] = closest_cat
	return grid


func _build_walk_grid() -> Array:
	var grid := _empty_grid()
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _is_walkable_cell(x, y):
				grid[y][x] = "walkable"
	return grid


func _build_block_grid() -> Array:
	var grid := _empty_grid()
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _is_blocker_cell(x, y):
				grid[y][x] = "blocker"
	return grid


func _is_walkable_cell(x: int, y: int) -> bool:
	var floor_category: String = _floor_grid[y][x]
	var detail_category: String = _detail_grid[y][x]
	if floor_category in ["floor", "door", "light"]:
		return not _is_detail_blocker(detail_category)
	return false


func _is_blocker_cell(x: int, y: int) -> bool:
	var floor_category: String = _floor_grid[y][x]
	var detail_category: String = _detail_grid[y][x]
	if floor_category in ["wall", "bar", "booth", "table", "clutter"]:
		return true
	return _is_detail_blocker(detail_category)


func _is_detail_blocker(category: String) -> bool:
	return category in _detail_blockers


func _build_sockets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec in _raw_sockets_def:
		var grid_arr: Array = spec["grid"]
		var grid_pos := Vector2i(grid_arr[0], grid_arr[1])
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
			"tags": spec.get("tags", []),
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


func _paint_circle(grid: Array, cx: int, cy: int, r: float, value: String) -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			var dx := float(x - cx)
			var dy := float(y - cy)
			if dx * dx + dy * dy <= r * r:
				grid[y][x] = value


func _paint_ring(grid: Array, cx: int, cy: int, r: float, thickness: float, value: String) -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			var dist := sqrt(float((x - cx) * (x - cx) + (y - cy) * (y - cy)))
			if abs(dist - r) <= thickness:
				grid[y][x] = value


func _save_grid_image(grid: Array, path: String) -> void:

	var image := Image.create_empty(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(GRID_H):
		for x in range(GRID_W):
			var category: String = grid[y][x]
			if category != EMPTY and _palette_colors.has(category):
				image.set_pixel(x, y, _palette_colors[category])
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save image %s: %s" % [path, err])


func _save_mask_image(grid: Array, path: String, color: Color) -> void:
	var image := Image.create_empty(GRID_W, GRID_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(GRID_H):
		for x in range(GRID_W):
			var category: String = grid[y][x]
			if category != EMPTY:
				image.set_pixel(x, y, color)
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save image %s: %s" % [path, err])


func _calculate_stats() -> void:
	var floor_rects := _make_greedy_rects(_floor_grid)
	var detail_rects := _make_greedy_rects(_detail_grid)
	var walk_rects := _make_greedy_rects(_walk_grid)
	var block_rects := _make_greedy_rects(_block_grid)
	
	var actor_probe_count := 0
	var composite_probe_count := 0
	if _path_probes_def.size() > 0:
		actor_probe_count = _socket_sequence_path_cell_count(_path_probes_def[0]["sockets"])
	if _path_probes_def.size() > 1:
		composite_probe_count = _socket_sequence_path_cell_count(_path_probes_def[1]["sockets"])
		
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
		"actor_probe_route_cells": actor_probe_count,
		"composite_probe_route_cells": composite_probe_count,
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
	_add_camera_light(root, Vector3(0, 0.58, 0), 8.6, Vector3(0.9, 0.78, -1.0))
	return root


func _build_socket_scene() -> Node3D:
	var root := _base_scene("RuntimeSocketMap", Color("#0b1017"))
	_add_layered_room(root, Vector3.ZERO, CELL, 0.55)
	_add_socket_markers(root)
	_add_camera_light(root, Vector3(0, 0.7, 0), 8.3, Vector3(0.9, 0.78, -1.0))
	return root


func _build_actor_path_scene() -> Node3D:
	var root := _base_scene("RuntimeActorPathProbe", Color("#0b1017"))
	_add_layered_room(root, Vector3.ZERO, CELL, 0.5)
	_add_socket_markers(root)
	
	for probe in _path_probes_def:
		_add_path(root, probe["sockets"], Color("#27d7ff"))
		
	# Spawn a few visual placeholder actors at target sockets
	if _sockets.size() > 0:
		_add_actor(root, _socket_path_world(_sockets[0]["id"]) + Vector3(0, 0.18, 0), Color("#e8ece5"))
	if _sockets.size() > 2:
		_add_actor(root, _socket_path_world(_sockets[2]["id"]) + Vector3(0, 0.18, 0), Color("#a95e4d"))
	if _sockets.size() > 4:
		_add_actor(root, _socket_path_world(_sockets[4]["id"]) + Vector3(0, 0.18, 0), Color("#b68a53"))
		
	_add_camera_light(root, Vector3(0, 0.68, 0), 8.3, Vector3(0.9, 0.78, -1.0))
	return root


func _build_composite_scene() -> Node3D:
	var root := _base_scene("RuntimeRoomPipelineComposite", Color("#0b1017"))
	_add_layered_room(root, Vector3.ZERO, CELL, 1.0)
	_add_mask_rects(root, _make_greedy_rects(_walk_grid), Vector3(0, 0.045, 0), CELL, Color("#245a37"))
	_add_socket_markers(root)
	
	if _path_probes_def.size() > 0:
		_add_path(root, _path_probes_def[0]["sockets"], Color("#27d7ff"))
		
	if _sockets.size() > 0:
		_add_actor(root, _socket_path_world(_sockets[0]["id"]) + Vector3(0, 0.18, 0), Color("#e8ece5"))
	if _sockets.size() > 1:
		_add_actor(root, _socket_path_world(_sockets[1]["id"]) + Vector3(0, 0.18, 0), Color("#b68a53"))
		
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
		shape.size = _rect_size(rect, "blocker", cell, false) + Vector3(0, 0.08, 0)
		var collision := CollisionShape3D.new()
		collision.name = "collision_%s_%s" % [rect["x"], rect["y"]]
		collision.shape = shape
		collision.position = _rect_position(rect, "blocker", cell, false)
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
	
	var decorator_categories := ["table", "bar", "light", "lamp", "clutter"]
	
	for category in by_category.keys():
		if category in decorator_categories:
			for rect in by_category[category]:
				_add_decorator_rect(holder, rect, category, cell)
			continue
			
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		# Define static body for category collisions
		var is_collidable: bool = category in ["wall", "arch", "frame", "booth_back", "booth", "pipe", "raised", "door"]
		var body: StaticBody3D = null

		if is_collidable:
			body = StaticBody3D.new()
			body.name = "collision_static_body_%s" % category
			holder.add_child(body)
			
		for rect in by_category[category]:
			var r_pos := _rect_position(rect, category, cell, false)
			var r_size := _rect_size(rect, category, cell, false)
			_add_box_faces(st, r_pos, r_size)
			
			if is_collidable and body != null:
				var collision := CollisionShape3D.new()
				collision.name = "collision_%s_%s" % [rect["x"], rect["y"]]
				var shape := BoxShape3D.new()
				shape.size = r_size
				collision.shape = shape
				collision.position = r_pos
				body.add_child(collision)
				
		var mesh := st.commit()
		var inst := MeshInstance3D.new()
		inst.name = "batch_%s" % category
		inst.mesh = mesh
		var color: Color = _palette_colors[category]
		color.a = alpha
		inst.material_override = _material(color, alpha < 1.0)
		holder.add_child(inst)


func _add_decorator_rect(holder: Node3D, rect: Dictionary, category: String, cell: float) -> void:
	var pos := _rect_position(rect, category, cell, false)
	var size := _rect_size(rect, category, cell, false)
	var name_prefix := "dec_%s_%s_%s" % [category, rect["x"], rect["y"]]
	
	# Create static body for this decorator item's collision
	var is_collidable: bool = category in ["table", "bar", "clutter"]
	var body: StaticBody3D = null

	if is_collidable:
		body = StaticBody3D.new()
		body.name = "static_body_%s_%s_%s" % [category, rect["x"], rect["y"]]
		holder.add_child(body)
		
		var collision := CollisionShape3D.new()
		collision.name = "collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.position = pos
		body.add_child(collision)
		
	var parent_node: Node = body if is_collidable else holder
	
	match category:
		"table":
			# Table leg
			var leg := _new_box(name_prefix + "_leg", pos + Vector3(0, -size.y * 0.15, 0), Vector3(cell * 0.35, size.y * 0.7, cell * 0.35), Color("#30343a"), false)
			parent_node.add_child(leg)
			# Table top
			var top := _new_box(name_prefix + "_top", pos + Vector3(0, size.y * 0.35, 0), Vector3(size.x, cell * 0.18, size.z), Color("#b68a53"), false)
			parent_node.add_child(top)
			# Small cup
			var cup := _new_box(name_prefix + "_cup", pos + Vector3(size.x * 0.24, size.y * 0.35 + cell * 0.14, size.z * 0.22), Vector3(cell * 0.16, cell * 0.22, cell * 0.16), Color("#27d7ff"), false)
			parent_node.add_child(cup)
		"bar":
			# Counter body
			var counter := _new_box(name_prefix + "_body", pos, size, Color("#6c4b35"), false)
			parent_node.add_child(counter)
			# Top trim slab
			var trim := _new_box(name_prefix + "_trim", pos + Vector3(0, size.y * 0.45, 0), Vector3(size.x + cell * 0.08, cell * 0.1, size.z + cell * 0.08), Color("#30343a"), false)
			parent_node.add_child(trim)
			# Dispenser/taps
			if rect["w"] >= 2 or rect["h"] >= 2:
				var tap := _new_box(name_prefix + "_tap", pos + Vector3(0, size.y * 0.65, 0), Vector3(cell * 0.2, cell * 0.35, cell * 0.2), Color("#aeb5b0"), false)
				parent_node.add_child(tap)
		"light", "lamp":
			# Ceiling fixture bracket
			var bracket := _new_box(name_prefix + "_bracket", pos + Vector3(0, size.y * 0.35, 0), Vector3(size.x, cell * 0.08, size.z), Color("#30343a"), false)
			parent_node.add_child(bracket)
			# Glowing neon tube
			var tube := _new_box(name_prefix + "_tube", pos + Vector3(0, -cell * 0.04, 0), Vector3(size.x * 0.88, cell * 0.14, size.z * 0.88), Color("#27d7ff"), false)
			parent_node.add_child(tube)
		"clutter":
			# Large crate
			var crate_a := _new_box(name_prefix + "_crate_a", pos + Vector3(-cell * 0.08, -size.y * 0.12, -cell * 0.08), Vector3(size.x * 0.72, size.y * 0.76, size.z * 0.72), Color("#30343a"), false)
			parent_node.add_child(crate_a)
			# Small wood crate stacked on top
			var crate_b := _new_box(name_prefix + "_crate_b", pos + Vector3(cell * 0.14, size.y * 0.24, cell * 0.14), Vector3(size.x * 0.52, size.y * 0.52, size.z * 0.52), Color("#b68a53"), false)
			parent_node.add_child(crate_b)
		_:
			# Fallback standard box
			var inst := _new_box(name_prefix + "_fallback", pos, size, _palette_colors[category], false)
			parent_node.add_child(inst)



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
	# Glowing lights
	if color == Color("#27d7ff") or color == Color("#2fd36b"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
	return mat


func _save_and_capture(name: String, scene: Node3D, description: String) -> void:
	var scene_path := _output_dir + "/review_scenes/%s.tscn" % name
	var capture_path := _output_dir + "/captures/%s.png" % name
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


func _write_manifest(spec_path: String) -> void:
	var manifest := {
		"generator": "docs/google/modeling/asset_factory/scripts/godot_pixel_cantina_generator.gd",
		"spec_path": spec_path,
		"room_id": _room_id,
		"display_name": _display_name,
		"source_images": {
			"floorplan": _floorplan_path,
			"detail": _detail_path,
			"walkable": _walkable_path,
			"collision": _collision_path
		},
		"stats": _stats,
		"sockets": _sockets,
		"captures": _captures,
	}
	var file := FileAccess.open(_output_dir + "/pixel_cantina_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# %s - Voxel Generation Review" % _display_name)
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/google/modeling/asset_factory/scripts/godot_pixel_cantina_generator.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Reusable pixel-to-GDScript generator pass for %s. Synthesizes geometry, masks, and named sockets." % _display_name)
	lines.append("")
	lines.append("## Source Images")
	lines.append("")
	lines.append("- Floorplan: `source_images/%s`" % _floorplan_path.get_file())
	lines.append("- Detail Layout: `source_images/%s`" % _detail_path.get_file())
	lines.append("- Walkable Mask: `source_images/%s`" % _walkable_path.get_file())
	lines.append("- Collision Mask: `source_images/%s`" % _collision_path.get_file())
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
	lines.append("| Path Route Cells | %s |" % _stats["actor_probe_route_cells"])
	lines.append("| Composite Route Cells | %s |" % _stats["composite_probe_route_cells"])
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
		var capture := String(entry["capture_path"]).replace(_output_dir + "/", "")
		lines.append("### %s" % entry["id"])
		lines.append("")
		lines.append(entry["description"])
		lines.append("")
		lines.append("![%s](%s)" % [entry["id"], capture])
		lines.append("")
	
	var file := FileAccess.open(_output_dir + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()


func _save_collision_grid_json() -> void:
	var path := _output_dir + "/collision_grid.json"
	# Build a flat list of 1s (blocked) and 0s (walkable)
	var flat_blockers: Array[int] = []
	for y in range(GRID_H):
		for x in range(GRID_W):
			if _block_grid[y][x] == "blocker":
				flat_blockers.append(1)
			else:
				flat_blockers.append(0)
				
	var data := {
		"room_id": _room_id,
		"grid_width": GRID_W,
		"grid_height": GRID_H,
		"cell_size": CELL,
		"blockers": flat_blockers
	}
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		print("Saved collision grid metadata JSON to: %s" % path)

