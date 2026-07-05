extends SubViewportContainer
## Isometric-style 3D backdrop for the space tactical overlay (DIV-0004: "Flat 2.5D
## plane with 3D ships/camera and zone graph overlay"). Presentation-only: it mirrors
## the contact/player-ship positions space_map_overlay.gd already tracks so ships read
## with real depth/parallax instead of flat 2D dots on a top-down plane. It owns no
## gameplay state and does not touch D6Rules/space_tactical_model — combat, sensors,
## and selection logic in space_map_overlay.gd are unchanged.

## World-unit scale applied to the tactical plane's data-space coordinates (which run
## roughly +/-320 x / +/-180 y per space_map_overlay's own clamp window) so the 3D
## scene stays a compact, easily framed size.
const WORLD_SCALE := 0.04
const PLANE_HALF_X := 320.0
const PLANE_HALF_Y := 180.0
const HULL_COLOR := Color(0.60, 0.86, 0.95)

var _viewport: SubViewport
var _camera: Camera3D
var _plane_root: Node3D
var _player_marker: Node3D
var _contact_markers: Dictionary = {} # contact_id -> Node3D
var _planet: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.handle_input_locally = false
	add_child(_viewport)
	_build_scene()

## Sizes the container to match the map rect in space_map_overlay; `stretch` (set in _ready)
## keeps the internal SubViewport's pixel size following the container automatically.
func configure(rect_size: Vector2) -> void:
	size = rect_size

## Local pixel position (within this container) that a data-space point projects to through the
## isometric camera. space_map_overlay uses this so its 2D click targets/labels/range-rings stay
## registered with the 3D ship model they represent instead of drifting apart under the angled
## camera. `stretch` keeps the internal SubViewport's pixel size equal to this container's size,
## so the camera's unprojected point maps 1:1 onto this control's local space.
func screen_position_for(data_position: Vector2) -> Vector2:
	if _camera == null:
		return size * 0.5
	return _camera.unproject_position(_space_to_world(data_position))

func _build_scene() -> void:
	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.30, 0.34, 0.42)
	environment.ambient_light_energy = 1.0
	env_node.environment = environment
	_viewport.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(0.92, 0.95, 1.0)
	_viewport.add_child(sun)

	# True Isometric Orthographic Camera: elevated and angled at 30° pitch, 45° yaw.
	# Orthogonal projection ensures true scale matching without perspective distortions.
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 22.0
	_viewport.add_child(_camera)
	_camera.look_at_from_position(Vector3(18.0, 14.69, 18.0), Vector3.ZERO, Vector3.UP)

	_plane_root = Node3D.new()
	_viewport.add_child(_plane_root)

	var plane_instance := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(PLANE_HALF_X * 2.0 * WORLD_SCALE, PLANE_HALF_Y * 2.0 * WORLD_SCALE)
	plane_instance.mesh = plane_mesh
	var plane_mat := StandardMaterial3D.new()
	plane_mat.albedo_color = Color(0.075, 0.095, 0.115)
	plane_mat.roughness = 0.95
	plane_instance.material_override = plane_mat
	_plane_root.add_child(plane_instance)

	_add_axis_bar(Vector3(PLANE_HALF_X * WORLD_SCALE * 2.0, 0.015, 0.03))
	_add_axis_bar(Vector3(0.03, 0.015, PLANE_HALF_Y * WORLD_SCALE * 2.0))

	_player_marker = _build_ship_marker_tscn("freighter", HULL_COLOR, 1.15)
	_plane_root.add_child(_player_marker)

	# Load and add Meshy planet background model if available
	var planet_path := "res://assets/3d/generated/gpt/meshy_space_planet_tatooine_v0/meshy_space_planet_tatooine_v0/model.glb"

	if ResourceLoader.exists(planet_path):
		var planet_scene := load(planet_path).instantiate() as Node3D
		planet_scene.position = Vector3(-12.0, -4.5, -9.0)
		planet_scene.scale = Vector3.ONE * 4.5
		planet_scene.rotation_degrees = Vector3(15, -45, 10)
		_plane_root.add_child(planet_scene)
		_planet = planet_scene

func set_system(system_name: String) -> void:
	if _planet == null:
		return
	if system_name == "Corellia":
		_planet.position = Vector3(-9.0, -3.5, -7.0)
		_planet.scale = Vector3.ONE * 5.0
		_planet.rotation_degrees = Vector3(45, 90, 0)
	elif system_name == "Nar Shaddaa":
		_planet.position = Vector3(-14.0, -5.5, -11.0)
		_planet.scale = Vector3.ONE * 3.5
		_planet.rotation_degrees = Vector3(-10, 180, 45)
	elif system_name == "Kessel":
		_planet.position = Vector3(-11.0, -6.0, -8.0)
		_planet.scale = Vector3.ONE * 4.0
		_planet.rotation_degrees = Vector3(90, 0, -30)
	else:
		_planet.position = Vector3(-12.0, -4.5, -9.0)
		_planet.scale = Vector3.ONE * 4.5
		_planet.rotation_degrees = Vector3(15, -45, 10)
func _add_axis_bar(dims: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dims
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.32, 0.34, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat
	_plane_root.add_child(mesh_instance)

## Builds a small low-poly "ship": a hull box with a wedge nose, matching the boxy
## primitive style world_builder.gd uses for the rest of the low-poly art.
func _build_ship_marker(color: Color, scale_factor: float = 1.0) -> Node3D:
	var root := Node3D.new()

	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(0.55, 0.22, 0.85) * scale_factor
	hull.mesh = hull_mesh
	hull.position.y = 0.14 * scale_factor
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = color
	hull_mat.roughness = 0.5
	hull_mat.metallic = 0.2
	hull_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hull.material_override = hull_mat
	hull.name = "Hull"
	root.add_child(hull)

	var nose := MeshInstance3D.new()
	var nose_mesh := PrismMesh.new()
	nose_mesh.size = Vector3(0.42, 0.20, 0.4) * scale_factor
	nose.mesh = nose_mesh
	nose.rotation_degrees.x = -90.0
	nose.position = Vector3(0.0, 0.14 * scale_factor, -0.62 * scale_factor)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = color.lightened(0.12)
	nose_mat.roughness = 0.5
	nose_mat.metallic = 0.2
	nose_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nose.material_override = nose_mat
	nose.name = "Nose"
	root.add_child(nose)

	return root

func _build_ship_marker_tscn(kind: String, color: Color, scale_factor: float = 1.0) -> Node3D:
	var path := ""
	match kind:
		"freighter":
			path = "res://assets/3d/generated/google/scenes/iso_space_freighter_01.tscn"
		"patrol", "courier":
			path = "res://assets/3d/generated/google/scenes/iso_space_fighter_01.tscn"
		"unknown", "landing_beacon":
			path = "res://assets/3d/generated/google/scenes/iso_space_fighter_01.tscn"
		"asteroid":
			path = "res://assets/3d/generated/gpt/meshy_space_asteroid_ore_v0/meshy_space_asteroid_ore_v0/model.glb"
			if not ResourceLoader.exists(path):
				path = "res://assets/3d/generated/google/scenes/iso_space_asteroid_cluster_01.tscn"

		_:
			path = "res://assets/3d/generated/google/scenes/iso_space_fighter_01.tscn"

			
	if ResourceLoader.exists(path):
		var scene := load(path).instantiate() as Node3D
		scene.scale = Vector3.ONE * scale_factor
		
		var sel_ring = scene.find_child("selection_ring", true, false)
		if sel_ring != null:
			sel_ring.visible = false
			
		var hull = scene.find_child("hull", true, false)
		if hull != null and hull is MeshInstance3D and hull.material_override == null:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 0.5
			mat.metallic = 0.2
			hull.material_override = mat
			
		return scene
		
	return _build_ship_marker(color, scale_factor)

## Mirrors space_map_overlay's contact list/visibility onto the 3D plane. Positions use
## the same absolute data-space coordinates + clamp window as _space_to_map (this view
## is a background twin of that 2D projection, not an independent source of truth).
func sync_contacts(contacts: Array, revealed: Array, selected_id: String) -> void:
	if _plane_root == null:
		return
	var seen: Dictionary = {}
	for contact in contacts:
		if typeof(contact) != TYPE_DICTIONARY:
			continue
		var contact_id := String(contact.get("id", ""))
		if contact_id == "":
			continue
		seen[contact_id] = true
		var marker: Node3D = _contact_markers.get(contact_id)
		if marker == null:
			marker = _build_ship_marker_tscn(String(contact.get("kind", "")), _contact_color(String(contact.get("kind", ""))))
			_plane_root.add_child(marker)
			_contact_markers[contact_id] = marker
		var pos: Dictionary = contact.get("position", {})
		marker.position = _space_to_world(Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0))))
		marker.rotation.y = -deg_to_rad(float(contact.get("heading_degrees", 0.0)))
		var hidden := bool(contact.get("hidden_until_revealed", false)) and not revealed.has(contact_id)
		_style_marker(marker, contact_id == selected_id, hidden, String(contact.get("kind", "")))
	for contact_id in _contact_markers.keys():
		if not seen.has(contact_id):
			var stale: Node3D = _contact_markers[contact_id]
			stale.queue_free()
			_contact_markers.erase(contact_id)

func _style_marker(marker: Node3D, selected: bool, hidden: bool, kind: String) -> void:
	var sel_ring = marker.find_child("selection_ring", true, false)
	if sel_ring != null:
		sel_ring.visible = selected
		
	var hull := marker.find_child("hull", true, false) as MeshInstance3D
	var nose := marker.find_child("nose", true, false) as MeshInstance3D
	var color := Color(0.30, 0.30, 0.28) if hidden else _contact_color(kind)
	var alpha := 0.55 if hidden else 1.0
	if hull != null:
		if hull.material_override is StandardMaterial3D:
			hull.material_override.albedo_color = Color(color.r, color.g, color.b, alpha)
		else:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(color.r, color.g, color.b, alpha)
			hull.material_override = mat
	if nose != null:
		if nose.material_override is StandardMaterial3D:
			nose.material_override.albedo_color = Color(color.r, color.g, color.b, alpha).lightened(0.12)
		else:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(color.r, color.g, color.b, alpha).lightened(0.12)
			nose.material_override = mat
	marker.scale = Vector3.ONE * (1.3 if selected else 1.0)

func _contact_color(kind: String) -> Color:
	match kind:
		"landing_beacon":
			return Color(0.92, 0.72, 0.24)
		"freighter":
			return Color(0.34, 0.74, 0.86)
		"patrol":
			return Color(0.45, 0.66, 0.95)
		"courier":
			return Color(0.74, 0.52, 0.86)
		"unknown":
			return Color(0.92, 0.36, 0.34)
		"asteroid":
			return Color(0.85, 0.55, 0.35)
		_:
			return Color(0.82, 0.84, 0.78)

func _space_to_world(pos: Vector2) -> Vector3:
	var world_x := clampf(pos.x, -PLANE_HALF_X, PLANE_HALF_X) * WORLD_SCALE
	var world_z := clampf(-pos.y, -PLANE_HALF_Y, PLANE_HALF_Y) * WORLD_SCALE
	return Vector3(world_x, 0.0, world_z)

