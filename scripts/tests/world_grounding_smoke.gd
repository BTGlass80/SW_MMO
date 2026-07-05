extends SceneTree

func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var builder = preload("res://scripts/world/world_builder.gd").new(1138)
	var landmark_builder = preload("res://scripts/world/landmark_builder.gd").new()
	
	builder.build_settlement(root)
	landmark_builder.build_cantina_plaza(root)
	
	var hover_count := 0
	var grounded_count := 0
	
	var stack := [root]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node.has_meta("hover"):
			hover_count += 1
		elif node.has_meta("grounded"):
			grounded_count += 1
			# Compute bounds
			var min_y := 9999.0
			var mesh_stack := [node]
			while mesh_stack.size() > 0:
				var m = mesh_stack.pop_back()
				if m is MeshInstance3D and m.mesh != null:
					var aabb = m.mesh.get_aabb()
					var global_trans = m.global_transform
					for i in range(8):
						var vertex = global_trans * aabb.get_endpoint(i)
						if vertex.y < min_y:
							min_y = vertex.y
				for c in m.get_children():
					mesh_stack.push_back(c)
					
			if min_y != 9999.0 and min_y < -0.1:
				printerr("world_grounding_smoke: FAIL - %s sunk below ground, min_y: %f" % [node.name, min_y])
				quit(1)
				return
			
		for child in node.get_children():
			stack.push_back(child)
			
	if hover_count == 0 or grounded_count == 0:
		printerr("world_grounding_smoke: FAIL - Missing grounded/hover metas. Found %d hover, %d grounded" % [hover_count, grounded_count])
		quit(1)
		return
		
	print("world_grounding_smoke: OK - Verified grounding metadata: %d hover, %d grounded models" % [hover_count, grounded_count])
	quit(0)
