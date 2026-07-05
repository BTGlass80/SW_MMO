extends SceneTree

const WorldBuilder := preload("res://scripts/world/world_builder.gd")
var _world: Node3D

func _init() -> void:
	print("Starting route debug...")
	
	_world = Node3D.new()
	var builder = WorldBuilder.new()
	builder.build_settlement(_world)
	get_root().add_child(_world)
	
	# Let physics frame tick once to update broadphase
	await process_frame
	await process_frame
	
	var space := _world.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	
	var probes = _world.find_children("RouteProbe*", "Marker3D", true, false)
	for p in probes:
		if p.name in ["RouteProbe_CantinaEntrance", "RouteProbe_Bay94Pit", "RouteProbe_Bay94Entrance"]:
			var t : Transform3D = p.global_transform
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = t
			
			var results = space.intersect_shape(q)
			
			if results.size() > 0:
				print("FAIL - ", p.name, " intersects ", results.size(), " bodies at ", p.global_position)
				for res in results:
					var coll = res["collider"] as Node
					if coll:
						print("   Collided with: ", coll.name, " parent: ", coll.get_parent().name)
						var coll_shape = coll.get_node("CollisionShape3D") as CollisionShape3D
						if coll_shape and coll_shape.shape is BoxShape3D:
							print("      Box Size: ", coll_shape.shape.size)
							print("      Box Global Pos: ", coll.global_position)
			else:
				print("OK - ", p.name)
				
	quit(0)
