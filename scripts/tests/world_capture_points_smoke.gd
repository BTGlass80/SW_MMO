extends SceneTree

func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var builder = preload("res://scripts/world/world_builder.gd").new(1138)
	var landmark_builder = preload("res://scripts/world/landmark_builder.gd").new()
	
	builder.build_settlement(root)
	landmark_builder.build_cantina_plaza(root)
	
	var capture_points := 0
	var required_points := [
		"CapturePoint_Spawn_Range",
		"CapturePoint_Spaceport_Row_East",
		"CapturePoint_Spaceport_Row_West",
		"CapturePoint_Bay94_Entrance",
		"CapturePoint_Bay94_Pit",
		"CapturePoint_Customs_Front",
		"CapturePoint_Speeders_Front",
		"CapturePoint_Transport_Depot_Front",
		"CapturePoint_Control_Tower",
		"CapturePoint_Cantina_Exterior",
		"CapturePoint_Cantina_Entrance",
		"CapturePoint_Cantina_Bar",
		"CapturePoint_Cantina_Back_Room"
	]
	
	var found_points := []
	var stack := [root]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node.has_meta("capture_point") and node.get_meta("capture_point") == true:
			capture_points += 1
			found_points.append(node.name)
		for child in node.get_children():
			stack.push_back(child)
			
	var missing := []
	for req in required_points:
		if not req in found_points:
			missing.append(req)
			
	if missing.size() > 0:
		printerr("world_capture_points_smoke: FAIL - Missing capture points: ", missing)
		quit(1)
		return
		
	# Verify captures were generated
	var abs_dir = ProjectSettings.globalize_path("res://captures/playtest")
	var missing_files := []
	var stale_files := []
	var now = Time.get_unix_time_from_system()
	for req in required_points:
		# e.g., CapturePoint_Spawn_Range -> playtest_01_spawn_range.png (approximate match, just check all pngs in dir are fresh)
		pass
		
	var dir = DirAccess.open(abs_dir)
	var png_count = 0
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				png_count += 1
				var file_path = abs_dir + "/" + file_name
				var mtime = FileAccess.get_modified_time(file_path)
				# Require captures to be less than 60 minutes old
				if now - mtime > 3600:
					stale_files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if png_count < 13:
		printerr("world_capture_points_smoke: FAIL - Missing generated PNG captures. Found %d, expected 13+" % png_count)
		quit(1)
		return
		
	if stale_files.size() > 0:
		printerr("world_capture_points_smoke: FAIL - Stale captures found (older than 1hr). Please regenerate using visual_playtest_runner.gd: ", stale_files)
		quit(1)
		return
		
	print("world_capture_points_smoke: OK - Found %d capture points" % capture_points)
	quit(0)
