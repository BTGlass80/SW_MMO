extends SceneTree

const WEAPONS_SPEC_PATH := "res://docs/google/modeling/asset_factory/specs/weapons_catalog.json"
const BUILDINGS_SPEC_PATH := "res://docs/google/modeling/asset_factory/specs/buildings_catalog.json"

const OUTPUT_WEAPONS_DIR := "res://docs/google/modeling/asset_factory/generated/weapons"
const OUTPUT_BUILDINGS_DIR := "res://docs/google/modeling/asset_factory/generated/buildings"

var _stats: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Starting Phase 4 Voxel Asset Generator...")
	
	# Create directories
	DirAccess.make_dir_recursive_absolute(OUTPUT_WEAPONS_DIR)
	DirAccess.make_dir_recursive_absolute(OUTPUT_BUILDINGS_DIR)
	
	# Process Weapons
	_process_catalog(WEAPONS_SPEC_PATH, OUTPUT_WEAPONS_DIR, "weapon")
	
	# Process Buildings
	_process_catalog(BUILDINGS_SPEC_PATH, OUTPUT_BUILDINGS_DIR, "building")
	
	print("Voxel Asset Generation complete!")
	quit()

func _process_catalog(spec_path: String, output_dir: String, category: String) -> void:
	if not FileAccess.file_exists(spec_path):
		printerr("Spec file not found: ", spec_path)
		return
		
	var file := FileAccess.open(spec_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("Malformed JSON spec in: ", spec_path)
		return
		
	var catalog: Dictionary = parsed
	for asset_id in catalog:
		print("  Generating ", category, ": ", asset_id)
		var config: Dictionary = catalog[asset_id]
		var display_name: String = config.get("display_name", asset_id)
		var cell_size: float = float(config.get("cell_size", 0.08))
		var parts: Dictionary = config.get("parts", {})
		
		# Root node
		var root: Node3D
		if category == "building":
			root = StaticBody3D.new()
		else:
			root = Node3D.new()
		root.name = asset_id
		
		# Generate each part
		for part_name in parts:
			var dimensions: Array = parts[part_name].get("front", [8, 8])
			var side_dimensions: Array = parts[part_name].get("side", [8, 8])
			var fw: int = int(dimensions[0])
			var fh: int = int(dimensions[1])
			var sw: int = int(side_dimensions[0])
			
			var front_img := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
			var side_img := Image.create(sw, fh, false, Image.FORMAT_RGBA8)
			
			_draw_asset_cards(asset_id, part_name, front_img, side_img)
			
			var mesh_node := _visual_hull_z_runs(front_img, side_img, part_name, Vector3.ZERO, cell_size, asset_id)
			root.add_child(mesh_node)
			
		# Add collision shapes for buildings
		if category == "building":
			_generate_collision(root, cell_size)
			
		# Save scene
		var scene_path := "%s/%s.tscn" % [output_dir, asset_id]
		_save_scene(root, scene_path)
		print("    Saved scene to: ", scene_path)

func _draw_asset_cards(asset_id: String, part_name: String, front: Image, side: Image) -> void:
	var black := Color("#15191d")
	var dark_grey := Color("#45484f")
	var light_grey := Color("#8a9096")
	var silver := Color("#dcdcdc")
	var cyan := Color("#27d7ff")
	var red := Color("#ff3b30")
	var green := Color("#35d454")
	var yellow := Color("#ffd626")
	var brown := Color("#2b1c10")
	var tan := Color("#ab8b55")
	var adobe_cream := Color("#d3bfa7")
	var adobe_shadow := Color("#bfa68a")
	var concrete := Color("#4d4f53")
	
	match asset_id:
		"blaster_pistol":
			# Front (16x8)
			_fill_rect(front, 0, 3, 16, 2, dark_grey) # barrel
			_fill_rect(front, 12, 1, 4, 2, light_grey) # scope
			_fill_rect(front, 13, 2, 1, 1, cyan) # sight dot
			_fill_rect(front, 4, 5, 2, 3, brown) # grip
			_fill_rect(front, 8, 5, 1, 2, black) # trigger guard
			# Side (4x8)
			_fill_rect(side, 1, 3, 2, 2, dark_grey)
			_fill_rect(side, 1, 1, 2, 2, light_grey)
			_fill_rect(side, 1, 5, 2, 3, brown)
			
		"blaster_rifle":
			# Front (24x8)
			_fill_rect(front, 0, 3, 24, 2, dark_grey) # barrel
			_fill_rect(front, 8, 1, 8, 2, black) # scope
			_fill_rect(front, 18, 2, 6, 4, brown) # wooden stock
			_fill_rect(front, 10, 5, 2, 3, dark_grey) # grip
			# Side (4x8)
			_fill_rect(side, 1, 3, 2, 2, dark_grey)
			_fill_rect(side, 1, 1, 2, 2, black)
			_fill_rect(side, 1, 5, 2, 3, dark_grey)
			
		"bowcaster":
			# Front (24x10)
			_fill_rect(front, 0, 4, 24, 2, tan) # main stock frame
			_fill_rect(front, 4, 1, 2, 8, black) # crossbow bow limbs
			_fill_rect(front, 3, 0, 4, 1, silver) # end magnet spheres
			_fill_rect(front, 3, 9, 4, 1, silver)
			_fill_rect(front, 18, 3, 6, 4, tan) # wooden grip
			# Side (6x10)
			_fill_rect(side, 2, 4, 2, 2, tan)
			_fill_rect(side, 2, 1, 2, 8, black)
			
		"lightsaber":
			# Front (6x32)
			# Hilt (y = 24 to 31)
			_fill_rect(front, 1, 24, 4, 8, light_grey)
			_fill_rect(front, 1, 26, 4, 2, black) # grip ribs
			_fill_rect(front, 1, 30, 4, 1, black)
			# Glowing Blade (y = 0 to 23)
			_fill_rect(front, 2, 0, 2, 24, cyan) # Blue blade default
			# Side (6x32)
			_fill_rect(side, 1, 24, 4, 8, light_grey)
			_fill_rect(side, 1, 26, 4, 2, black)
			_fill_rect(side, 2, 0, 2, 24, cyan)
			
		"thermal_detonator":
			# Front (8x8)
			_fill_rect(front, 1, 1, 6, 6, dark_grey)
			_fill_rect(front, 2, 2, 4, 4, light_grey) # metal band
			_fill_rect(front, 3, 0, 2, 2, red) # activation button
			# Side (8x8)
			_fill_rect(side, 1, 1, 6, 6, dark_grey)
			_fill_rect(side, 2, 2, 4, 4, light_grey)
			_fill_rect(side, 3, 0, 2, 2, red)
			
		"desert_doorway":
			# Front (24x24) - thick archway doorway frame
			_fill_rect(front, 0, 0, 24, 24, adobe_cream)
			# Hollow out the archway center opening
			_fill_rect(front, 6, 6, 12, 18, Color(0, 0, 0, 0)) # arch portal
			_fill_rect(front, 7, 5, 10, 1, Color(0, 0, 0, 0)) # top curve
			# Add highlights
			_fill_rect(front, 0, 0, 24, 2, adobe_shadow)
			# Side (6x24)
			_fill_rect(side, 1, 0, 4, 24, adobe_cream)
			
		"moisture_vaporator":
			# Front (10x32)
			_fill_rect(front, 4, 0, 2, 32, light_grey) # central column
			_fill_rect(front, 2, 2, 6, 2, dark_grey) # ground base flange
			_fill_rect(front, 1, 12, 8, 2, dark_grey) # cooling rings
			_fill_rect(front, 1, 22, 8, 2, dark_grey)
			_fill_rect(front, 3, 30, 4, 2, cyan) # flashing status light
			# Side (10x32)
			_fill_rect(side, 4, 0, 2, 32, light_grey)
			_fill_rect(side, 1, 12, 8, 2, dark_grey)
			_fill_rect(side, 3, 30, 4, 2, cyan)
			
		"dome_cap":
			# Front (24x12)
			# Programmatic hemisphere curve
			for y in range(12):
				var r := float(12 - y)
				var half_w := int(sqrt(12.0 * 12.0 - r * r))
				_fill_rect(front, 12 - half_w, y, half_w * 2, 1, adobe_cream)
			# Side (24x12)
			for y in range(12):
				var r := float(12 - y)
				var half_w := int(sqrt(12.0 * 12.0 - r * r))
				_fill_rect(side, 12 - half_w, y, half_w * 2, 1, adobe_cream)
				
		"combat_barricade":
			# Front (16x12)
			_fill_rect(front, 0, 0, 16, 12, concrete)
			# Diagonal warning lines
			for i in range(12):
				_fill_rect(front, i, i, 2, 1, yellow)
				_fill_rect(front, i + 1, i, 1, 1, black)
			# Side (16x12)
			_fill_rect(side, 0, 0, 16, 12, concrete)
			
		"landing_pad_light":
			# Front (6x16)
			_fill_rect(front, 2, 4, 2, 12, black) # mounting column
			_fill_rect(front, 1, 0, 4, 4, yellow) # glowing beacon light head
			# Side (6x16)
			_fill_rect(side, 2, 4, 2, 12, black)
			_fill_rect(side, 1, 0, 4, 4, yellow)

func _visual_hull_z_runs(front: Image, side: Image, node_name: String, origin: Vector3, cell: float, asset_id: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	var count := 0
	var raw_voxels := 0
	var width := front.get_width()
	var height := front.get_height()
	var depth := side.get_width()
	for y in range(height):
		for x in range(width):
			var front_color := front.get_pixel(x, y)
			if front_color.a <= 0.05:
				continue
			var z := 0
			while z < depth:
				var side_color := side.get_pixel(z, y)
				if side_color.a <= 0.05:
					z += 1
					continue
				var run_start := z
				while z < depth and side.get_pixel(z, y).a > 0.05:
					z += 1
				var run_length := z - run_start
				raw_voxels += run_length
				var px := (float(x) - float(width - 1) / 2.0) * cell
				var py := (float(height - 1 - y) - float(height - 1) / 2.0) * cell
				var pz := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(depth - 1) / 2.0) * cell
				
				# Base color blending
				var color := front_color.lerp(side.get_pixel(run_start, y), 0.35)
				
				# Special emissive glows
				var is_emissive := false
				var em_color := color
				# Check lightsaber cyan blade, vaporator cyan light, thermal button red, beacon warning yellow
				if front_color == Color("#27d7ff") or front_color == Color("#ff3b30") or front_color == Color("#ffd626"):
					is_emissive = true
					em_color = front_color
				
				if not is_emissive:
					# Voxel coordinate deterministic hash noise (Minecraft textured variety)
					var hash_val: float = sin(float(x) * 12.9898 + float(y) * 78.233 + float(run_start) * 437.287) * 43758.5453
					var noise: float = (hash_val - floor(hash_val)) * 0.10 - 0.05
					
					# Ambient occlusion depth-shadow (darken inner voxels relative to card borders)
					var dist_to_x_edge: float = float(min(x, width - 1 - x))
					var dist_to_z_edge: float = float(min(run_start, depth - 1 - run_start))
					var min_edge: float = min(dist_to_x_edge, dist_to_z_edge)
					var depth_shadow: float = 1.0 - clamp(min_edge * 0.07, 0.0, 0.20)
					
					color.r = clamp(color.r * depth_shadow + noise, 0.0, 1.0)
					color.g = clamp(color.g * depth_shadow + noise, 0.0, 1.0)
					color.b = clamp(color.b * depth_shadow + noise, 0.0, 1.0)
				
				var box_mesh := _new_box("%s_x%s_y%s_z%s" % [node_name, x, y, run_start], Vector3(px, py, pz), Vector3(cell, cell, float(run_length) * cell), color, is_emissive, em_color)
				holder.add_child(box_mesh)
				count += 1
				
	return holder

func _generate_collision(body: StaticBody3D, cell: float) -> void:
	# Calculate bounds of all MeshInstances inside the body
	var aabb := AABB()
	var first := true
	for child in body.get_children():
		if child is Node3D:
			for subchild in child.get_children():
				if subchild is MeshInstance3D:
					var local_aabb: AABB = subchild.get_aabb()
					var global_pos: Vector3 = subchild.position
					var global_aabb := AABB(global_pos + local_aabb.position, local_aabb.size)
					if first:
						aabb = global_aabb
						first = false
					else:
						aabb = aabb.merge(global_aabb)
	
	if not first:
		# Add a Box CollisionShape matching the bounding box of the voxel structure
		var col_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = aabb.size
		col_shape.shape = box_shape
		col_shape.position = aabb.position + aabb.size * 0.5
		body.add_child(col_shape)
		print("    Generated bounding collision shape. Center: ", col_shape.position, " Size: ", box_shape.size)

func _new_box(node_name: String, pos: Vector3, size: Vector3, color: Color, is_emissive: bool, em_color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = node_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.position = pos
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	
	if is_emissive:
		mat.emission_enabled = true
		mat.emission = em_color
		mat.emission_energy_multiplier = 2.0
		mat.roughness = 0.1
		
	mesh_inst.material_override = mat
	return mesh_inst

func _fill_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for dy in range(h):
		for dx in range(w):
			var px := x + dx
			var py := y + dy
			if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
				image.set_pixel(px, py, color)

func _save_scene(root: Node3D, path: String) -> void:
	var scene := PackedScene.new()
	_set_owner_recursive(root, root)
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
		if err != OK:
			printerr("Failed to save PackedScene: ", err)
	else:
		printerr("Failed to pack scene: ", err)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
