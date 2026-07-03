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

	_build_plaza_floor(root)
	_build_main_cantina(root)
	_build_interior(root)
	_build_flanking_huts(root)
	_build_perimeter(root)
	_build_stalls_and_greebles(root, rng)
	_add_label(root, Vector3(0, 7.4, 0), "Mos Eisley Cantina")

	return root

# --- composite pieces ---
func _build_plaza_floor(root: Node3D) -> void:
	_add_box_to_world(root, Vector3(0, -0.05, 6.5), Vector3(16, 0.1, 11), COL_PLAZA_FLOOR)

func _build_main_cantina(root: Node3D) -> void:
	# Main hall: a wide adobe drum with a domed roof. Entrance faces +Z (toward the
	# plaza), so it lines up with the archway and the interior furniture below.
	_add_domed_hut(root, Vector3.ZERO, 5.0, 3.4, 2.8, COL_ADOBE, COL_DOME, "Main")
	_add_archway(root, Vector3(0, 0, 4.85), 1.9, 2.6, 0.7, COL_TRIM)
	# Signage band above the archway.
	_add_box(root, Vector3(0, 3.0, 4.9), Vector3(3.0, 0.5, 0.16), COL_GLOW)

func _build_interior(root: Node3D) -> void:
	# A simple bar + booths tucked inside the main hall's footprint, visible through
	# the archway. Interior floor is a touch darker than the plaza for mood.
	var interior := Node3D.new()
	interior.name = "CantinaInterior"
	root.add_child(interior)

	_add_box(interior, Vector3(0, -0.02, 0), Vector3(8.6, 0.06, 8.6), Color(0.22, 0.20, 0.17))

	# Bar counter against the back wall (-Z side, opposite the +Z entrance).
	_add_box(interior, Vector3(-1.6, 0.5, -3.4), Vector3(4.2, 1.0, 0.7), COL_WOOD)
	_add_box(interior, Vector3(-1.6, 1.02, -3.4), Vector3(4.3, 0.06, 0.75), COL_ADOBE_DARK)
	# Back-bar shelving.
	_add_box(interior, Vector3(-1.6, 1.3, -3.85), Vector3(3.6, 1.5, 0.18), COL_TRIM)
	for i in range(4):
		_add_box(interior, Vector3(-3.0 + i * 0.85, 1.05, -3.78), Vector3(0.22, 0.5, 0.2), Color(0.18, 0.42, 0.44).lightened(0.06 * i))

	# Booths: paired low-wall partitions with a bench + table, ringing the hall.
	var booth_spots := [
		{"pos": Vector3(3.2, 0, -1.6), "rot": -35.0},
		{"pos": Vector3(3.2, 0, 1.6), "rot": 35.0},
		{"pos": Vector3(-3.4, 0, 1.4), "rot": -150.0},
	]
	for i in range(booth_spots.size()):
		_add_booth(interior, booth_spots[i]["pos"], booth_spots[i]["rot"], str(i))

func _build_flanking_huts(root: Node3D) -> void:
	# Smaller domed adjoining chambers (storage / back rooms) so the cluster reads as
	# a small compound rather than a single freestanding building.
	_add_domed_hut(root, Vector3(-6.6, 0, -1.0), 2.2, 2.6, 1.6, COL_ADOBE_DARK, COL_DOME.darkened(0.08), "Left")
	_add_domed_hut(root, Vector3(6.6, 0, -1.0), 2.0, 2.4, 1.4, COL_ADOBE_DARK, COL_DOME.darkened(0.08), "Right")

func _build_perimeter(root: Node3D) -> void:
	# A partial low-wall plaza perimeter with a gap left open toward the entrance path.
	_add_low_wall(root, Vector3(-8.0, 0, 3.5), 5.6, 0.9, 0.0, "West")
	_add_low_wall(root, Vector3(8.0, 0, 3.5), 5.6, 0.9, 0.0, "East")
	_add_low_wall(root, Vector3(-6.0, 0, 11.5), 4.2, 0.9, 90.0, "SouthWest")
	_add_low_wall(root, Vector3(6.0, 0, 11.5), 4.2, 0.9, 90.0, "SouthEast")

func _build_stalls_and_greebles(root: Node3D, rng: RandomNumberGenerator) -> void:
	_add_market_stall(root, Vector3(-5.6, 0, 8.6), 20.0, "A")
	_add_market_stall(root, Vector3(5.4, 0, 8.8), -18.0, "B")
	_add_moisture_vaporator(root, Vector3(-7.6, 0, 6.4), 1.0 + rng.randf() * 0.15, "A")
	_add_moisture_vaporator(root, Vector3(7.4, 0, 6.0), 1.0 + rng.randf() * 0.15, "B")
	_add_crate_pile(root, Vector3(4.6, 0, 3.9))

# --- reusable pieces ---

## A cylindrical adobe drum capped with a low-poly hemisphere dome. Reused for the
## main cantina hall (large) and the flanking storage huts (small).
func _add_domed_hut(parent: Node3D, pos: Vector3, radius: float, wall_height: float, dome_height: float, wall_color: Color, dome_color: Color, tag: String = "") -> Node3D:
	var hut := Node3D.new()
	hut.name = "DomedHut_%s" % tag if tag != "" else "DomedHut"
	hut.position = pos
	parent.add_child(hut)

	var drum := StaticBody3D.new()
	drum.name = "HutWall"
	drum.position = Vector3(0, wall_height * 0.5, 0)
	hut.add_child(drum)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = wall_height
	collision.shape = shape
	drum.add_child(collision)

	var wall_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 1.03
	cyl.height = wall_height
	cyl.radial_segments = DOME_RADIAL_SEGMENTS
	wall_mesh.mesh = cyl
	wall_mesh.material_override = _material(wall_color, 0.95)
	drum.add_child(wall_mesh)

	var dome_mesh := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = radius * 0.98
	dome.height = dome_height
	dome.radial_segments = DOME_RADIAL_SEGMENTS
	dome.rings = DOME_RINGS
	dome.is_hemisphere = true
	dome_mesh.mesh = dome
	dome_mesh.position = Vector3(0, wall_height, 0)
	dome_mesh.material_override = _material(dome_color, 0.85)
	hut.add_child(dome_mesh)

	return hut

## A doorway frame: two jambs plus a lintel, forming an archway a player can walk
## through. `local_pos` is the archway's ground-level center, facing +Z by default.
func _add_archway(parent: Node3D, local_pos: Vector3, opening_width: float, opening_height: float, jamb_depth: float, color: Color) -> void:
	var jamb_w := 0.4
	var jamb_x := opening_width * 0.5 + jamb_w * 0.5
	_add_box(parent, local_pos + Vector3(-jamb_x, opening_height * 0.5, 0), Vector3(jamb_w, opening_height, jamb_depth), color)
	_add_box(parent, local_pos + Vector3(jamb_x, opening_height * 0.5, 0), Vector3(jamb_w, opening_height, jamb_depth), color)
	_add_box(parent, local_pos + Vector3(0, opening_height + 0.15, 0), Vector3(opening_width + jamb_w * 2, 0.3, jamb_depth), color)
	# Dark doorway recess so the opening reads as a passage, not a solid wall.
	_add_box(parent, local_pos + Vector3(0, opening_height * 0.5, 0.05), Vector3(opening_width - 0.1, opening_height - 0.1, 0.1), COL_DOORWAY)

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

	_add_box(booth, Vector3(0, 0.45, 0.8), Vector3(1.4, 0.9, 0.16), COL_TRIM)
	_add_box(booth, Vector3(0, 0.45, -0.8), Vector3(1.4, 0.9, 0.16), COL_TRIM)
	_add_box(booth, Vector3(0, 0.3, 0), Vector3(1.2, 0.5, 1.4), COL_WOOD)

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

func _add_box(parent: Node3D, local_pos: Vector3, size: Vector3, color: Color) -> void:
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
	mesh_instance.material_override = _material(color, 0.9)
	parent.add_child(mesh_instance)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_label(host: Node3D, pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.name = "Label_%s" % text.replace(" ", "_")
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.modulate = Color(0.09, 0.08, 0.06)
	host.add_child(label)
