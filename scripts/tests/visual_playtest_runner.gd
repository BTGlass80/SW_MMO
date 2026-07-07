extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const PLAYTEST_DIR := "res://captures/playtest"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Starting automated visual playtest on the Mos Eisley sandbox world...")
	
	# Create output folder and clear old captures
	var abs_dir = ProjectSettings.globalize_path(PLAYTEST_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var dir = DirAccess.open(abs_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	
	# Set window size
	get_root().size = CAPTURE_SIZE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)
		
	# Load solo sandbox world scene (which has NPCs)
	var world_scene_path := "res://scenes/main.tscn"
	if not ResourceLoader.exists(world_scene_path):
		printerr("World scene not found at res://scenes/main.tscn")
		quit(1)
		return
		
	var world_scene: Node = load(world_scene_path).instantiate()
	get_root().add_child(world_scene)
	
	# Wait for loading, world generation, and initial snapshot application to complete
	for i in range(40):
		await process_frame
		
	# Create our own camera for the playtest
	var camera := Camera3D.new()
	world_scene.add_child(camera)
	camera.current = true
	
	# Disable client input update so it doesn't overwrite camera coordinates (if net_world was loaded)
	world_scene.set_process(false)
	world_scene.set_physics_process(false)
	
	# Hide gameplay UI completely
	var _remove_canvas_layers = func(node: Node, _func) -> void:
		if node is CanvasLayer:
			node.visible = false
			node.queue_free()
			return
		if node is Control:
			node.visible = false
			node.queue_free()
			return
		if node.has_method("_update_range_state_badges"):
			node.set_process(false)
			node.set_physics_process(false)
		if node is Label3D:
			node.visible = false
			node.queue_free()
			return
		for child in node.get_children():
			_func.call(child, _func)
	_remove_canvas_layers.call(world_scene, _remove_canvas_layers)
	
	# Helper to position camera via CapturePoints
	var _snap_camera = func(title: String) -> Node3D:
		var stack = [world_scene]
		var target = "CapturePoint_%s" % title.replace(" ", "_")
		var point: Node3D = null
		while stack.size() > 0:
			var node = stack.pop_back()
			if node.name == target:
				point = node
				break
			for child in node.get_children():
				stack.push_back(child)
				
		if point == null:
			printerr("Could not find capture point: %s" % title)
			return null
			
		camera.global_position = point.global_position
		var look_at_local: Vector3 = point.get_meta("look_at_pos", Vector3.ZERO)
		var host = point.get_parent()
		var target_global = look_at_local
		if host and host.has_method("to_global"):
			target_global = host.to_global(look_at_local)
		camera.look_at(target_global, Vector3.UP)
		return point

	var captures = [
		{"point": "Spawn Range", "file": "playtest_01_spawn_range.png"},
		{"point": "Spaceport Row East", "file": "playtest_02_spaceport_row_east.png"},
		{"point": "Spaceport Row West", "file": "playtest_03_spaceport_row_west.png"},
		{"point": "Bay94 Entrance", "file": "playtest_04_bay94_entrance.png"},
		{"point": "Bay94 Pit", "file": "playtest_05_bay94_pit.png"},
		{"point": "Customs Front", "file": "playtest_06_customs_front.png"},
		{"point": "Speeders Front", "file": "playtest_07_speeders_front.png"},
		{"point": "Transport Depot Front", "file": "playtest_08_transport_depot_front.png"},
		{"point": "Control Tower", "file": "playtest_09_control_tower.png"},
		{"point": "Cantina Exterior", "file": "playtest_10_cantina_exterior.png"},
		{"point": "Cantina Entrance", "file": "playtest_11_cantina_entrance.png"},
		{"point": "Cantina Bar", "file": "playtest_12_cantina_bar.png"},
		{"point": "Cantina Back Room", "file": "playtest_13_cantina_back_room.png"}
	]

	for cap in captures:
		print("Positioning camera for %s..." % cap["point"])
		var point_node = _snap_camera.call(cap["point"])
		if not point_node: quit(1)
		for i in range(15):
			await process_frame
			await RenderingServer.frame_post_draw
		if not _save_capture(cap["file"], camera, point_node.get_parent()): quit(1)

	print("Automated visual playtest completed successfully.")
	quit(0)

func _analyze_image(image: Image) -> String:
	var w = image.get_width()
	var h = image.get_height()
	
	# Check center 50% for wall dominance
	var cx_start = int(w * 0.25); var cx_end = int(w * 0.75)
	var cy_start = int(h * 0.25); var cy_end = int(h * 0.75)
	var r_sum = 0.0; var g_sum = 0.0; var b_sum = 0.0
	var count = 0
	for y in range(cy_start, cy_end, 5):
		for x in range(cx_start, cx_end, 5):
			var col = image.get_pixel(x, y)
			r_sum += col.r; g_sum += col.g; b_sum += col.b
			count += 1
	var r_mean = r_sum / count; var g_mean = g_sum / count; var b_mean = b_sum / count
	var variance = 0.0
	for y in range(cy_start, cy_end, 5):
		for x in range(cx_start, cx_end, 5):
			var col = image.get_pixel(x, y)
			variance += (col.r - r_mean) ** 2 + (col.g - g_mean) ** 2 + (col.b - b_mean) ** 2
	if (variance / count) < 0.005:
		return "Image is near-wall dominant (center 50% is flat)"
		
	# Sky check removed.

	# Check bottom 30% for floor dominance
	var by_start = int(h * 0.7)
	r_sum = 0.0; g_sum = 0.0; b_sum = 0.0
	count = 0
	for y in range(by_start, h, 5):
		for x in range(0, w, 5):
			var col = image.get_pixel(x, y)
			r_sum += col.r; g_sum += col.g; b_sum += col.b
			count += 1
	r_mean = r_sum / count; g_mean = g_sum / count; b_mean = b_sum / count
	variance = 0.0
	for y in range(by_start, h, 5):
		for x in range(0, w, 5):
			var col = image.get_pixel(x, y)
			variance += (col.r - r_mean) ** 2 + (col.g - g_mean) ** 2 + (col.b - b_mean) ** 2
	if (variance / count) < 0.0001:
		return "Image is floor dominant (bottom 30% is flat)"
		
	return ""

func _save_capture(filename: String, camera: Camera3D, landmark_node: Node3D) -> bool:
	var path := PLAYTEST_DIR + "/" + filename
	var image: Image = get_root().get_texture().get_image()
	if image == null:
		printerr("Failed to grab viewport texture!")
		return false
		
	var err_msg = _analyze_image(image)
	if err_msg != "":
		printerr("Image %s failed visual checks: %s" % [filename, err_msg])
		return false
		
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		printerr("Failed to save playtest capture to %s: %s" % [path, err])
		return false
		
	# Verify file size and modification time
	var abs_path = ProjectSettings.globalize_path(path)
	var file_size = FileAccess.get_file_as_bytes(abs_path).size()
	if file_size == 0:
		printerr("Image %s has zero file size!" % filename)
		return false
		
	print("Saved visual playtest capture: %s" % abs_path)
	return true

