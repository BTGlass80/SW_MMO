extends SceneTree

func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var builder = preload("res://scripts/world/world_builder.gd").new(1138)
	var landmark_builder = preload("res://scripts/world/landmark_builder.gd").new()
	
	builder.build_settlement(root)
	landmark_builder.build_cantina_plaza(root)
	
	var inspect_volumes := 0
	
	var stack := [root]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is CollisionShape3D and node.has_meta("inspect_volume"):
			inspect_volumes += 1
		for child in node.get_children():
			stack.push_back(child)
			
	if inspect_volumes == 0:
		printerr("world_inspect_volume_smoke: FAIL - No inspect_volume metadata found")
		quit(1)
		return
		
	print("world_inspect_volume_smoke: OK - Found %d inspect volumes" % inspect_volumes)
	quit(0)
