extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var builder = preload("res://scripts/world/world_builder.gd").new(1138)
	var landmark_builder = preload("res://scripts/world/landmark_builder.gd").new()
	
	builder.build_settlement(root)
	landmark_builder.build_cantina_plaza(root, Vector3(65, 0, 0))
	
	# Wait for physics frames to initialize collision
	await self.process_frame
	await self.physics_frame
	
	var space = root.get_world_3d().space
	var state = PhysicsServer3D.space_get_direct_state(space)
	
	var probes := []
	var inspect_rids := []
	
	var stack := [root]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node is StaticBody3D:
			if node.name.begins_with("RouteProbe_"):
				probes.append(node)
			else:
				# Exclude inspect volumes
				for child in node.get_children():
					if child is CollisionShape3D and child.has_meta("inspect_volume"):
						inspect_rids.append(node.get_rid())
						break
		for child in node.get_children():
			stack.push_back(child)
			
	var failed := false
	for probe in probes:
		var params = PhysicsShapeQueryParameters3D.new()
		var cap = CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		params.shape = cap
		# The player origin is at the feet, so move the capsule up by half its height
		params.transform = Transform3D(Basis(), probe.global_position + Vector3(0, 0.9, 0))
		params.exclude = inspect_rids
		
		var result = state.intersect_shape(params)
		if result.size() > 0:
			printerr("world_collision_route_smoke: FAIL - Probe %s intersects %d bodies" % [probe.name, result.size()])
			var printed_rids = {}
			for res in result:
				var collider = res.get("collider")
				var shape_idx = res.get("shape")
				var rid = res.get("collider_id")
				if collider and collider is Node and not printed_rids.has(str(rid) + "_" + str(shape_idx)):
					printed_rids[str(rid) + "_" + str(shape_idx)] = true
					printerr("  Collided with node: %s" % [collider.name])
					if collider is CollisionObject3D:
						var owner_id = collider.shape_find_owner(shape_idx)
						var shape_node = collider.shape_owner_get_owner(owner_id)
						if shape_node is CollisionShape3D:
							printerr("    Shape: %s, Pos: %s, Size: %s" % [shape_node.name, shape_node.global_position, shape_node.shape.size if "size" in shape_node.shape else "unknown"])
			failed = true
	
	if failed:
		quit(1)
		return
		
	print("world_collision_route_smoke: OK - Checked %d probes against blocking geometry" % [probes.size()])
	quit(0)
