extends RefCounted
## Procedural low-poly builder for a signature Mos Eisley landmark: a cantina plaza —
## a domed adobe cantina building with a simple bar + booth interior, flanked by
## smaller domed storage huts, a low perimeter wall, market stalls, and moisture
## vaporators, so the cluster reads as a real corner of a district rather than one
## isolated prop. Same blocky BoxMesh/StandardMaterial3D art language as
## scripts/world/world_builder.gd, scripts/world/monster_builder.gd, and
## scripts/world/npc_builder.gd — low-poly primitives only (boxes, plus low-segment
## cylinders/hemispheres for the dome roofs), no textures, no external assets.
##
## Pure construction: build_cantina_plaza() creates a fresh root Node3D, parents it
## under the given host at the given origin, and returns the root. No gameplay state,
## no input, no autoloads, no RNG owned here (any RNG use is seeded and local to a
## single call, so the same seed always produces the same layout — deterministic
## across every client). Headlessly unit-testable and safe to add into either the
## solo world (scripts/world/main.gd) or the networked world (scripts/net/net_world.gd).
##
## Modular helpers (reused to build the district, not just decorate one building):
##   _add_domed_hut()         - a cylindrical adobe drum capped with a low-poly dome.
##   _add_archway()            - a doorway frame (two jambs + a lintel).
##   _add_moisture_vaporator() - a slim desert-tech greeble prop.
##   _add_market_stall()       - a vendor stall (counter + awning).
##   _add_low_wall()           - a short plaza perimeter wall segment.

const DOME_RADIAL_SEGMENTS := 8
const DOME_RINGS := 4

# Desert adobe / cantina palette — consistent with world_builder's dusty tans/ochres.
const COL_ADOBE := Color(0.62, 0.50, 0.36)
const COL_ADOBE_DARK := Color(0.47, 0.38, 0.27)
const COL_DOME := Color(0.56, 0.45, 0.33)
const COL_TRIM := Color(0.30, 0.26, 0.20)
const COL_DOORWAY := Color(0.10, 0.08, 0.06)
const COL_AWNING := Color(0.55, 0.20, 0.16)
const COL_WOOD := Color(0.36, 0.25, 0.16)
const COL_METAL := Color(0.34, 0.35, 0.36)
const COL_GLOW := Color(0.85, 0.63, 0.22)
const COL_PLAZA_FLOOR := Color(0.58, 0.49, 0.36)

# --- entry point ---
## Build the cantina plaza landmark and parent it under `host` at local `origin`.
## Returns the new root Node3D (already added as a child of `host`). Deterministic:
## the same origin/seed always produces the identical cluster.
func build_cantina_plaza(host: Node3D, origin: Vector3 = Vector3.ZERO, seed_value: int = 1138) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var root := Node3D.new()
	root.name = "MosEisleyCantinaPlaza"
	root.position = origin
	host.add_child(root)

	_build_plaza_floor(root, rng)
	_build_main_cantina(root, rng)
	_build_interior(root, rng)
	_add_mood_lighting(root)
	_build_flanking_huts(root, rng)
	_build_perimeter(root, rng)
	_build_stalls_and_greebles(root, rng)
	
	# Off-axis No Droids sign by the door
	_add_label(root, Vector3(4.5, 2.5, 13.0), "[NO DROIDS]")
	var sign_light := OmniLight3D.new()
	sign_light.position = Vector3(4.5, 2.5, 13.5)
	sign_light.light_color = Color(1.0, 0.2, 0.2)
	sign_light.light_energy = 0.8
	sign_light.omni_range = 5.0
	root.add_child(sign_light)

	return root

# --- composite pieces ---
func _build_plaza_floor(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Scaled down to match the new player-scale footprint (24x24m main dome)
	# Smaller overlapping patches instead of one huge slab
	_add_box_to_world(root, Vector3(0, -0.05, 12.0), Vector3(18, 0.1, 15), COL_PLAZA_FLOOR)
	_add_box_to_world(root, Vector3(-10, -0.05, 5.0), Vector3(16, 0.1, 24), COL_PLAZA_FLOOR.darkened(0.02))
	_add_box_to_world(root, Vector3(12, -0.05, 8.0), Vector3(14, 0.1, 16), COL_PLAZA_FLOOR.lightened(0.02))
	
	# Darker contact shadows under the main dome
	_add_box_to_world(root, Vector3(0, -0.04, 0), Vector3(25, 0.1, 25), COL_PLAZA_FLOOR.darkened(0.1))

func _build_main_cantina(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Use modular domed hut piece (radius 12m) instead of custom CSG mega-dome
	var radius := 12.0
	_add_domed_hut(root, Vector3(0, 0, 0), radius, 5.0, 4.0, COL_ADOBE, COL_DOME, "Main", true)
	
	# Build a proper open archway over the cutout
	_add_archway_open(root, Vector3(0, 0, 11.8), 5.0, 4.5, 2.5, COL_TRIM)
	# Off-axis chipped threshold steps
	_add_box(root, Vector3(-1.0, 0.1, 13.5), Vector3(4.0, 0.2, 1.5), COL_ADOBE_DARK)
	_add_box(root, Vector3(0.5, 0.2, 12.8), Vector3(3.0, 0.2, 1.0), COL_ADOBE_DARK)
	
	# Subtle awning/glow above instead of massive billboard
	_add_box(root, Vector3(0, 4.8, 12.5), Vector3(5.5, 0.2, 1.5), COL_TRIM.darkened(0.2))
	_add_box(root, Vector3(0, 4.7, 12.5), Vector3(4.5, 0.1, 0.8), COL_GLOW)


func _build_interior(root: Node3D, rng: RandomNumberGenerator) -> void:
	var interior := Node3D.new()
	interior.name = "CantinaInterior"
	root.add_child(interior)

	# Vestibule reveal wall to break line-of-sight from the entrance
	# Pushed further back and right to open the route
	_add_box(interior, Vector3(2.5, 2.0, 7.5), Vector3(3.0, 4.0, 0.5), COL_ADOBE) # Main blocker
	_add_box(interior, Vector3(4.0, 2.0, 9.0), Vector3(0.5, 4.0, 3.5), COL_ADOBE) # Side return
	
	# Small threshold walls to guide player around the reveal
	_add_box(interior, Vector3(-3.5, 2.0, 10.0), Vector3(0.5, 4.0, 4.0), COL_ADOBE)
	
	# Modular square bar counter (lowered for player scale)
	# Front, Back, Left, Right segments
	_add_box(interior, Vector3(0, 0.4, 3.5), Vector3(7.0, 0.8, 1.0), COL_ADOBE_DARK)
	_add_box(interior, Vector3(0, 0.4, -3.5), Vector3(7.0, 0.8, 1.0), COL_ADOBE_DARK)
	_add_box(interior, Vector3(-3.5, 0.4, 0), Vector3(1.0, 0.8, 6.0), COL_ADOBE_DARK)
	_add_box(interior, Vector3(3.5, 0.4, 0), Vector3(1.0, 0.8, 6.0), COL_ADOBE_DARK)
	
	# Bar tops
	_add_box(interior, Vector3(0, 0.85, 3.5), Vector3(7.4, 0.15, 1.4), COL_WOOD)
	_add_box(interior, Vector3(0, 0.85, -3.5), Vector3(7.4, 0.15, 1.4), COL_WOOD)
	_add_box(interior, Vector3(-3.5, 0.85, 0), Vector3(1.4, 0.15, 6.4), COL_WOOD)
	_add_box(interior, Vector3(3.5, 0.85, 0), Vector3(1.4, 0.15, 6.4), COL_WOOD)
	
	# Bartender floor (raised slightly)
	_add_box(interior, Vector3(0, 0.1, 0), Vector3(5.2, 0.2, 5.2), COL_PLAZA_FLOOR)
	
	# Drink dispensers and shelves in center of bar
	_add_box(interior, Vector3(0, 1.5, 0), Vector3(1.2, 3.0, 1.2), COL_METAL)
	_add_box(interior, Vector3(0, 1.6, 0), Vector3(1.6, 0.1, 1.6), COL_METAL.darkened(0.2)) # Shelf 1
	_add_box(interior, Vector3(0, 2.2, 0), Vector3(1.4, 0.1, 1.4), COL_METAL.darkened(0.2)) # Shelf 2
	
	# Glowing bottles on shelves
	var colors = [Color(0.2, 0.8, 1.0), Color(1.0, 0.4, 0.2), Color(0.9, 0.8, 0.2), Color(0.2, 1.0, 0.4)]
	for i in range(12):
		var ang := i * (PI * 2.0 / 12.0)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var color = colors[i % colors.size()]
		# Lower shelf bottles
		_add_box(interior, Vector3(0, 1.8, 0) + dir * 0.7, Vector3(0.15, 0.35, 0.15), color, true)
		# Upper shelf bottles
		if i % 2 == 0:
			_add_box(interior, Vector3(0, 2.4, 0) + dir * 0.6, Vector3(0.12, 0.28, 0.12), colors[(i+1) % colors.size()], true)
	
	for i in range(4):
		var ang := i * PI / 2.0
		var dir := Vector3(cos(ang), 0, sin(ang))
		_add_box(interior, Vector3(0, 2.0, 0) + dir * 0.65, Vector3(0.4, 0.2, 0.4), COL_METAL.lightened(0.2))
		_add_box(interior, Vector3(0, 2.15, 0) + dir * 0.65, Vector3(0.05, 0.3, 0.05), COL_METAL.lightened(0.5)) # Tap handle

	# Booths around the perimeter
	var num_booths := 8
	var cantina_radius := 10.0
	for i in range(num_booths):
		var ang := i * (PI * 2.0 / num_booths)
		# Skip the entrance and back hallways
		if abs(ang - PI/2.0) < 0.6 or abs(ang - 3.0*PI/2.0) < 0.6:
			continue
		var dir := Vector3(cos(ang), 0, sin(ang))
		var booth_pos := dir * cantina_radius
		var booth_rot := -rad_to_deg(ang) - 90.0
		_add_booth(interior, booth_pos, booth_rot, str(i))

	# Hologram emitter in the center of the bar
	var holo := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 0.1
	holo.mesh = cyl
	holo.position = Vector3(0.0, 3.05, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.7, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.7, 1.0)
	mat.emission_energy_multiplier = 3.0
	holo.material_override = mat
	interior.add_child(holo)

	# Projection light beam (semi-transparent cyan cylinder)
	var beam := MeshInstance3D.new()
	var beam_cyl := CylinderMesh.new()
	beam_cyl.top_radius = 0.5
	beam_cyl.bottom_radius = 0.1
	beam_cyl.height = 1.6
	beam.mesh = beam_cyl
	beam.position = Vector3(0.0, 3.85, 0.0)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.1, 0.7, 1.0, 0.2)
	beam_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = beam_mat
	interior.add_child(beam)

	# Inner ring of freestanding tables and chairs
	var num_tables := 4
	var table_radius := 5.5
	for i in range(num_tables):
		var ang := i * (PI * 2.0 / num_tables)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var pos := dir * table_radius
		# Slight jitter for a natural feel
		pos.x += rng.randf_range(-1.5, 1.5)
		pos.z += rng.randf_range(-1.5, 1.5)
		_add_table_and_chairs(interior, pos, rng.randf_range(0, 360.0), str(i))
		
	# Add a bandstand stage on the right side
	_add_bandstand(interior, Vector3(-8.0, 0.0, 0.0), 90.0)

	# Add back hallway/alcove geometry
	_add_back_hallway(interior, Vector3(0.0, 0.0, -11.0), 0.0)
	
	# Route probes for the cantina
	_add_route_probe(root, Vector3(0, 1.2, 19.0), "CantinaExterior")
	_add_route_probe(root, Vector3(0, 1.2, 11.5), "CantinaEntrance")
	_add_route_probe(root, Vector3(0, 1.2, 4.5), "CantinaBar")
	_add_route_probe(root, Vector3(0, 1.2, -6.0), "CantinaBackRoom")
	
	# Add Capture Points for the visual runner
	_add_capture_point(root, Vector3(0, 1.8, 20.0), Vector3(0, 1.8, 12.0), "Cantina Exterior")
	_add_capture_point(root, Vector3(-1.0, 1.8, 14.5), Vector3(1.0, 1.8, 8.0), "Cantina Entrance")
	_add_capture_point(root, Vector3(0, 1.8, 6.0), Vector3(0, 1.8, 0.0), "Cantina Bar")
	_add_capture_point(root, Vector3(0, 1.8, -4.0), Vector3(0, 1.8, -10.0), "Cantina Back Room")

func _add_mood_lighting(root: Node3D) -> void:
	var interior_sun := DirectionalLight3D.new()
	interior_sun.name = "CantinaInteriorSun"
	interior_sun.rotation_degrees = Vector3(-45, -45, 0)
	interior_sun.light_color = Color(0.9, 0.8, 0.6)
	interior_sun.light_energy = 0.5
	interior_sun.shadow_enabled = true
	root.add_child(interior_sun)
	
	var bar_light := OmniLight3D.new()
	bar_light.name = "CantinaBarLight"
	bar_light.position = Vector3(0, 5.0, 0)
	bar_light.light_color = Color(1.0, 0.7, 0.4)
	bar_light.light_energy = 1.5
	bar_light.omni_range = 15.0
	bar_light.shadow_enabled = true
	root.add_child(bar_light)
	
	var ambient_fill := OmniLight3D.new()
	ambient_fill.name = "CantinaAmbientFill"
	ambient_fill.position = Vector3(0, 8.0, 10.0)
	ambient_fill.light_color = Color(0.4, 0.5, 0.6)
	ambient_fill.light_energy = 0.3
	ambient_fill.omni_range = 30.0
	root.add_child(ambient_fill)


func _build_flanking_huts(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Asymmetrical structures
	# Left structure brought close to front to create a tight alley entrance
	_add_domed_hut(root, Vector3(-12.0, 0, 8.0), 4.5, 4.0, 2.5, COL_ADOBE_DARK, COL_DOME.darkened(0.08), "LeftFront")
	# Left back structure
	_add_domed_hut(root, Vector3(-14.0, 0, -4.0), 3.5, 3.5, 2.0, COL_ADOBE, COL_DOME.darkened(0.08), "LeftBack")
	
	# Right structure pushed back and wider
	_add_domed_hut(root, Vector3(16.0, 0, -2.0), 5.0, 3.8, 2.2, COL_ADOBE_DARK, COL_DOME.darkened(0.08), "Right")

func _build_perimeter(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Low-wall plaza boundary scaled to match the tighter footprint
	_add_low_wall(root, Vector3(-16.0, 0, 16.0), 12.0, 1.4, 0.0, "WestAlley")
	_add_low_wall(root, Vector3(18.0, 0, 8.0), 14.0, 1.4, 0.0, "East")
	_add_low_wall(root, Vector3(-8.0, 0, 18.0), 8.0, 1.4, 90.0, "SouthWest")
	_add_low_wall(root, Vector3(10.0, 0, 16.0), 10.0, 1.4, 90.0, "SouthEast")

func _build_stalls_and_greebles(root: Node3D, rng: RandomNumberGenerator) -> void:
	# Off-axis entry clutter
	_add_moisture_vaporator(root, Vector3(-4.0, 0, 15.0), 1.2, "EntryA")
	_add_crate_pile(root, Vector3(5.0, 0, 14.0))
	
	# Stalls tucked into corners
	_add_market_stall(root, Vector3(-9.0, 0, 14.0), 90.0, "AlleyVendor")
	_add_market_stall(root, Vector3(14.0, 0, 10.0), -45.0, "SideVendor")
	_add_moisture_vaporator(root, Vector3(16.0, 0, 14.0), 1.6, "SideVap")



# --- reusable pieces ---

## A cylindrical adobe drum capped with a low-poly hemisphere dome. Reused for the
## main cantina hall (large) and the flanking storage huts (small).
func _add_domed_hut(parent: Node3D, pos: Vector3, radius: float, wall_height: float, dome_height: float, wall_color: Color, dome_color: Color, tag: String = "", hollow: bool = false) -> Node3D:
	var hut := Node3D.new()
	hut.name = "DomedHut_%s" % tag if tag != "" else "DomedHut"
	hut.position = pos
	parent.add_child(hut)

	# 8-sided modular wall
	var num_sides := 8
	# Math: side length of a circumscribed octagon is 2 * R * tan(PI/8)
	var side_length := 2.0 * radius * tan(PI / num_sides)
	for i in range(num_sides):
		var ang := i * (PI * 2.0 / num_sides)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var wall_pos := dir * radius
		var wall_rot := -rad_to_deg(ang) + 90.0
		
		# Leave the front (+Z) and back (-Z) faces open for doorways if hollow
		if hollow and (i == 2 or i == 6):
			var door_w := 5.0
			var side_w := (side_length - door_w) * 0.5
			var local_rot_rad := deg_to_rad(wall_rot)
			# Left stub
			var left_box = _add_box(hut, wall_pos + Vector3(-door_w * 0.5 - side_w * 0.5, 0, 0).rotated(Vector3.UP, local_rot_rad), Vector3(side_w, wall_height, 1.5), wall_color)
			left_box.rotation_degrees.y = wall_rot
			# Right stub
			var right_box = _add_box(hut, wall_pos + Vector3(door_w * 0.5 + side_w * 0.5, 0, 0).rotated(Vector3.UP, local_rot_rad), Vector3(side_w, wall_height, 1.5), wall_color)
			right_box.rotation_degrees.y = wall_rot
			# Top header above door
			var head_box = _add_box(hut, wall_pos + Vector3(0, wall_height - 0.5, 0).rotated(Vector3.UP, local_rot_rad), Vector3(door_w, 1.0, 1.5), wall_color)
			head_box.rotation_degrees.y = wall_rot
			continue
			
		var box = _add_box(hut, wall_pos + Vector3(0, wall_height * 0.5, 0), Vector3(side_length + 0.5, wall_height, 1.5), wall_color)
		box.rotation_degrees.y = wall_rot

	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius * 1.02
	sm.height = dome_height * 2.0
	sm.is_hemisphere = true
	sm.radial_segments = DOME_RADIAL_SEGMENTS
	sm.rings = DOME_RINGS
	dome.mesh = sm
	dome.position = Vector3(0, wall_height, 0)
	var mat := _material(dome_color, 0.85)
	if hollow:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome.material_override = mat
	hut.add_child(dome)
	
	return hut


## A doorway frame without a solid block in the middle
func _add_archway_open(parent: Node3D, local_pos: Vector3, opening_width: float, opening_height: float, jamb_depth: float, color: Color) -> void:
	var jamb_w := 0.4
	var jamb_x := opening_width * 0.5 + jamb_w * 0.5
	_add_box(parent, local_pos + Vector3(-jamb_x, opening_height * 0.5, 0), Vector3(jamb_w, opening_height, jamb_depth), color)
	_add_box(parent, local_pos + Vector3(jamb_x, opening_height * 0.5, 0), Vector3(jamb_w, opening_height, jamb_depth), color)
	_add_box(parent, local_pos + Vector3(0, opening_height + 0.15, 0), Vector3(opening_width + jamb_w * 2, 0.3, jamb_depth), color)

## A slim desert moisture-vaporator greeble: a footed pole with a collar and a small
## intake dish, purely decorative set-dressing for the plaza.
func _add_moisture_vaporator(parent: Node3D, local_pos: Vector3, height_scale: float = 1.0, tag: String = "") -> void:
	var vap := Node3D.new()
	vap.name = "MoistureVaporator_%s" % tag if tag != "" else "MoistureVaporator"
	vap.position = local_pos
	parent.add_child(vap)

	var pole_h := 1.8 * height_scale
	_add_box(vap, Vector3(0, 0.1, 0), Vector3(0.7, 0.2, 0.7), COL_METAL.darkened(0.1))
	_add_box(vap, Vector3(0, pole_h * 0.5, 0), Vector3(0.28, pole_h, 0.28), COL_METAL)
	_add_box(vap, Vector3(0, pole_h * 0.72, 0), Vector3(0.5, 0.16, 0.5), COL_METAL.lightened(0.08))
	_add_box(vap, Vector3(0, pole_h + 0.22, 0), Vector3(0.62, 0.44, 0.62), COL_METAL.darkened(0.05))
	_add_box(vap, Vector3(0, pole_h + 0.5, 0), Vector3(0.16, 0.16, 0.16), Color(0.20, 0.42, 0.44))

## A vendor stall: a wooden counter plus a canted cloth awning. `rot_deg` orients the
## whole stall (counter facing direction) about the local Y axis.
func _add_market_stall(parent: Node3D, local_pos: Vector3, rot_deg: float, tag: String = "") -> void:
	var stall := Node3D.new()
	stall.name = "MarketStall_%s" % tag if tag != "" else "MarketStall"
	stall.position = local_pos
	stall.rotation_degrees.y = rot_deg
	parent.add_child(stall)

	_add_box(stall, Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 0.8), COL_WOOD)
	_add_box(stall, Vector3(-1.0, 1.55, 0), Vector3(0.14, 2.1, 0.14), COL_WOOD.darkened(0.15))
	_add_box(stall, Vector3(1.0, 1.55, 0), Vector3(0.14, 2.1, 0.14), COL_WOOD.darkened(0.15))
	_add_box(stall, Vector3(0, 2.25, -0.15), Vector3(2.7, 0.12, 1.4), COL_AWNING)
	# A little wares crate on the counter.
	_add_box(stall, Vector3(0.6, 1.15, 0), Vector3(0.4, 0.3, 0.4), COL_WOOD.lightened(0.1))

## A short plaza perimeter wall segment, centered at `local_pos`, running `length`
## along local X before rotation, rotated `rot_deg` about Y.
func _add_low_wall(parent: Node3D, local_pos: Vector3, length: float, height: float, rot_deg: float, tag: String = "") -> void:
	var wall := Node3D.new()
	wall.name = "LowWall_%s" % tag if tag != "" else "LowWall"
	wall.position = local_pos
	wall.rotation_degrees.y = rot_deg
	parent.add_child(wall)

	_add_box(wall, Vector3(0, height * 0.5, 0), Vector3(length, height, 0.5), COL_ADOBE_DARK)
	_add_box(wall, Vector3(0, height + 0.06, 0), Vector3(length + 0.2, 0.12, 0.6), COL_ADOBE.lightened(0.05))

func _add_booth(parent: Node3D, local_pos: Vector3, rot_deg: float, tag: String = "") -> void:
	var booth := Node3D.new()
	booth.name = "Booth_%s" % tag if tag != "" else "Booth"
	booth.position = local_pos
	booth.rotation_degrees.y = rot_deg
	parent.add_child(booth)

	# Wrap-around stepped booth seating
	_add_box(booth, Vector3(0, 0.25, 1.0), Vector3(2.4, 0.5, 0.6), COL_TRIM)
	_add_box(booth, Vector3(0, 0.25, -1.0), Vector3(2.4, 0.5, 0.6), COL_TRIM)
	_add_box(booth, Vector3(-1.0, 0.25, 0), Vector3(0.6, 0.5, 1.4), COL_TRIM)
	
	# Stepped backs
	_add_box(booth, Vector3(0, 0.55, 1.2), Vector3(2.6, 0.7, 0.2), COL_TRIM.darkened(0.1))
	_add_box(booth, Vector3(0, 0.55, -1.2), Vector3(2.6, 0.7, 0.2), COL_TRIM.darkened(0.1))
	_add_box(booth, Vector3(-1.2, 0.55, 0), Vector3(0.2, 0.7, 2.2), COL_TRIM.darkened(0.1))
	
	_add_box(booth, Vector3(0, 0.85, 1.3), Vector3(2.8, 0.4, 0.2), COL_TRIM.darkened(0.2))
	_add_box(booth, Vector3(0, 0.85, -1.3), Vector3(2.8, 0.4, 0.2), COL_TRIM.darkened(0.2))
	_add_box(booth, Vector3(-1.3, 0.85, 0), Vector3(0.2, 0.4, 2.4), COL_TRIM.darkened(0.2))
	
	# Table
	_add_box(booth, Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.0), COL_METAL.darkened(0.1))
	_add_box(booth, Vector3(0, 0.82, 0), Vector3(1.3, 0.05, 1.1), COL_WOOD)
	
	# Small table lamp
	_add_box(booth, Vector3(0.3, 0.9, 0), Vector3(0.1, 0.2, 0.1), Color(1.0, 0.8, 0.5), true)
	
	# Optional privacy arch over booth
	_add_archway_open(booth, Vector3(-0.5, 0.0, 0.0), 3.0, 2.2, 0.2, COL_ADOBE_DARK)

func _add_bandstand(parent: Node3D, local_pos: Vector3, rot_deg: float) -> void:
	var stage := Node3D.new()
	stage.name = "Bandstand"
	stage.position = local_pos
	stage.rotation_degrees.y = rot_deg
	parent.add_child(stage)
	
	# Raised curved stage platform
	var stage_mesh_inst := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = 4.0
	cm.top_radius = 4.0
	cm.height = 0.6
	cm.radial_segments = 16
	stage_mesh_inst.mesh = cm
	stage_mesh_inst.position = Vector3(0, 0.3, 0)
	stage_mesh_inst.material_override = _material(COL_WOOD.darkened(0.1), 0.8)
	stage.add_child(stage_mesh_inst)
	
	# Add static collision for the stage
	var stage_col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 4.0
	cs.height = 0.6
	stage_col.shape = cs
	stage_col.position = Vector3(0, 0.3, 0)
	var sb := StaticBody3D.new()
	sb.add_child(stage_col)
	stage.add_child(sb)
	
	# Instruments/Stands
	_add_box(stage, Vector3(-1.5, 0.9, -1.0), Vector3(0.6, 1.2, 0.6), COL_METAL)
	_add_box(stage, Vector3(1.5, 0.9, -1.0), Vector3(0.5, 1.1, 0.5), COL_METAL.lightened(0.2))
	_add_box(stage, Vector3(0.0, 0.8, 1.0), Vector3(0.4, 1.0, 0.4), COL_METAL.darkened(0.2))
	
	# Stage lighting
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 4.0, 3.0)
	spot.rotation_degrees = Vector3(-45, 0, 0)
	spot.light_color = Color(0.8, 0.2, 0.9)
	spot.light_energy = 2.0
	spot.spot_range = 8.0
	spot.spot_angle = 35.0
	stage.add_child(spot)

func _add_table_and_chairs(parent: Node3D, local_pos: Vector3, rot_deg: float, tag: String = "") -> void:
	var tbl := Node3D.new()
	tbl.name = "TableGrp_%s" % tag if tag != "" else "TableGrp"
	tbl.position = local_pos
	tbl.rotation_degrees.y = rot_deg
	parent.add_child(tbl)

	# Main round-ish table (using a box for low-poly style)
	_add_box(tbl, Vector3(0, 0.4, 0), Vector3(1.1, 0.8, 1.1), COL_METAL.darkened(0.1))
	# Tabletop
	_add_box(tbl, Vector3(0, 0.82, 0), Vector3(1.3, 0.06, 1.3), COL_WOOD.lightened(0.1))

	# 3 chairs around it
	for i in range(3):
		var ang := i * (PI * 2.0 / 3.0)
		var c_dir := Vector3(cos(ang), 0, sin(ang))
		var c_pos := c_dir * 1.0
		# seat
		_add_box(tbl, c_pos + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), COL_TRIM)
		# seat back
		_add_box(tbl, c_pos + Vector3(0, 0.65, 0) + c_dir * 0.2, Vector3(0.5, 0.5, 0.1), COL_TRIM.darkened(0.1))

func _add_back_hallway(parent: Node3D, local_pos: Vector3, rot_deg: float) -> void:
	var hall := Node3D.new()
	hall.name = "BackHallway"
	hall.position = local_pos
	hall.rotation_degrees.y = rot_deg
	parent.add_child(hall)

	# Floor strip, wider
	_add_box(hall, Vector3(0, 0.05, -3.5), Vector3(5.0, 0.1, 10.0), COL_PLAZA_FLOOR.darkened(0.1))
	
	# Side walls, pushed out
	_add_box(hall, Vector3(-2.6, 2.0, -3.5), Vector3(0.4, 4.0, 10.0), COL_ADOBE_DARK)
	_add_box(hall, Vector3(2.6, 2.0, -3.5), Vector3(0.4, 4.0, 10.0), COL_ADOBE_DARK)
	
	# Ceiling
	_add_box(hall, Vector3(0, 4.2, -3.5), Vector3(5.6, 0.4, 10.0), COL_ADOBE_DARK)
	
	# End destination: an offset booth and open door frame
	_add_box(hall, Vector3(1.0, 2.0, -9.5), Vector3(3.6, 4.0, 0.4), COL_ADOBE_DARK) # Back wall right
	_add_box(hall, Vector3(-2.0, 2.0, -9.5), Vector3(1.6, 4.0, 0.4), COL_ADOBE_DARK) # Back wall left
	_add_archway_open(hall, Vector3(-0.5, 0, -9.5), 1.4, 2.4, 0.2, COL_DOORWAY) # Doorway leading deeper
	
	# VIP Seating
	_add_booth(hall, Vector3(1.0, 0, -8.0), -15.0, "Private")
	_add_booth(hall, Vector3(-1.0, 0, -7.0), 15.0, "Private2")
	_add_table_and_chairs(hall, Vector3(0, 0, -5.0), 0.0, "HallTable")
	
	# Clutter
	_add_box(hall, Vector3(2.0, 0.4, -6.0), Vector3(0.6, 0.8, 0.6), COL_METAL.darkened(0.2)) # Barrel
	_add_box(hall, Vector3(-2.0, 0.3, -8.5), Vector3(0.8, 0.6, 0.8), COL_WOOD) # Crate
	
	# Archway at entrance, wider
	_add_archway_open(hall, Vector3(0, 0, 1.5), 4.8, 3.8, 0.4, COL_TRIM)
	
	# Dim lighting
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.5, -4.0)
	light.light_color = Color(0.9, 0.6, 0.4)
	light.light_energy = 0.5
	light.omni_range = 8.0
	hall.add_child(light)

func _add_capture_point(host: Node3D, pos: Vector3, look_at_pos: Vector3, title: String) -> void:
	var point := Node3D.new()
	point.name = "CapturePoint_%s" % title.replace(" ", "_")
	point.position = pos
	point.set_meta("capture_point", true)
	point.set_meta("look_at_pos", look_at_pos)
	host.add_child(point)
	
	if OS.get_cmdline_args().has("--debug-world-labels"):
		var mesh_inst := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.2
		mesh.height = 0.4
		mesh_inst.mesh = mesh
		mesh_inst.material_override = _material(Color(1.0, 0.0, 1.0), 0.5)
		point.add_child(mesh_inst)
		_add_label(point, Vector3(0, 0.5, 0), "Capture: %s" % title)

func _add_route_probe(host: Node3D, pos: Vector3, title: String) -> void:
	var body := StaticBody3D.new()
	body.name = "RouteProbe_%s" % title.replace(" ", "_")
	body.position = pos
	body.collision_layer = 0
	body.collision_mask = 1 # test against world collision
	host.add_child(body)
	
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)
	body.add_child(collision)
	
	if OS.get_cmdline_args().has("--debug-world-labels"):
		var mesh_inst := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.4
		mesh.height = 1.8
		mesh_inst.mesh = mesh
		mesh_inst.position = Vector3(0, 0.9, 0)
		mesh_inst.material_override = _material(Color(1.0, 1.0, 0.0), 0.5)
		body.add_child(mesh_inst)
		_add_label(body, Vector3(0, 2.0, 0), "Route: %s" % title)

func _add_crate_pile(parent: Node3D, local_pos: Vector3) -> void:
	_add_box(parent, local_pos + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), COL_WOOD)
	_add_box(parent, local_pos + Vector3(0.6, 0.25, 0.5), Vector3(0.6, 0.5, 0.6), COL_WOOD.lightened(0.08))

# --- primitives (match world_builder.gd's helper shapes/collision idiom) ---
func _add_box_to_world(host: Node3D, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Block"
	body.position = pos
	host.add_child(body)
	_add_box(body, Vector3.ZERO, size, color)
	return body

func _add_box(parent: Node3D, local_pos: Vector3, size: Vector3, color: Color, transparent: bool = false) -> MeshInstance3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = local_pos
	parent.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.material_override = _material(color, 0.9, transparent)
	parent.add_child(mesh_instance)
	return mesh_instance

func _material(color: Color, roughness: float = 0.9, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	if transparent:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
		# We'll use additive blending for a glow effect
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(color.r, color.g, color.b, 0.8)
		
	return material

func _add_label(host: Node3D, pos: Vector3, text: String) -> void:

	var label := Label3D.new()
	label.name = "Label_%s" % text.replace(" ", "_")
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.modulate = Color(0.9, 0.9, 0.9)
	label.outline_render_priority = 1
	label.outline_size = 12
	label.outline_modulate = Color.BLACK
	label.visible = OS.get_cmdline_args().has("--debug-world-labels")
	host.add_child(label)
