extends RefCounted
## Shared, deterministic builder for the low-poly Mos Eisley Spaceport Row / Bay 94
## settlement geometry. Used by BOTH the solo world (scripts/world/main.gd) and the
## networked world (scripts/net/net_world.gd) so there is exactly one source of
## geometry instead of two copies.
##
## Pure construction: given a host Node3D it builds child nodes into it. No gameplay
## state, no input, no combat. Seeded RNG (default 1138) keeps the layout identical
## across the server's clients.

const SPACEPORT_ROW_DATA_PATH := "res://data/mos_eisley_spaceport_row.json"
const PROPS_DATA_PATH := "res://data/mos_eisley_props.json"
const MODEL_MANIFEST_PATH := "res://data/model_manifest.json"

# Curated low-poly Kenney models (CC0). Note: some kits use "GLB format", others
# "GLTF format" in their path. Scales are first-pass estimates — worth a visual tune.
const SHIP_CARGO := "res://assets/3d/kenney/space-kit/Models/GLTF format/craft_cargoA.glb"
const SHIP_SPEEDER := "res://assets/3d/kenney/space-kit/Models/GLTF format/craft_speederA.glb"
const SHIP_MINER := "res://assets/3d/kenney/space-kit/Models/GLTF format/craft_miner.glb"
const CRATE_MODEL := "res://assets/3d/kenney/factory-kit/Models/GLB format/box-large.glb"
const BARREL_MODEL := "res://assets/3d/kenney/survival-kit/Models/GLB format/barrel.glb"
const CRATE_SCALE := 1.0
const BARREL_SCALE := 1.0

## Maps short model keys (used in mos_eisley_props.json) to the curated GLB path consts.
## Declared after the path consts it references to avoid any forward-reference issues.
## Add new keys here when new GLB consts are added above — keep in sync.
const MODEL_KEY_MAP := {
	"ship_cargo":    SHIP_CARGO,
	"ship_speeder":  SHIP_SPEEDER,
	"ship_miner":    SHIP_MINER,
	"crate":         CRATE_MODEL,
	"barrel":        BARREL_MODEL,
}

var _rng := RandomNumberGenerator.new()
var _rooms := {}
var _model_cache := {}
var _model_manifest := {}

func _init(seed_value: int = 1138) -> void:
	_rng.seed = seed_value
	_load_rooms()
	_load_model_manifest()

# --- composite builders ---
func build_lighting(host: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "TwinSunKey"
	sun.light_energy = 2.3
	sun.rotation_degrees = Vector3(-48, 32, 0)
	host.add_child(sun)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.58, 0.67, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.68, 0.58)
	env.ambient_light_energy = 0.55
	world.environment = env
	host.add_child(world)

func build_ground(host: Node3D) -> void:
	var ground := StaticBody3D.new()
	ground.name = "SettlementGround"
	host.add_child(ground)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 1, 200)
	collision.shape = shape
	collision.position.y = -0.55
	ground.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(200, 1, 200)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.55
	mesh_instance.material_override = make_material(Color(0.68, 0.57, 0.42), 0.95)
	ground.add_child(mesh_instance)

func build_settlement(host: Node3D) -> void:
	# Main street path - narrower dirt road
	add_box_to_world(host, Vector3(0, 0.02, 0), Vector3(70, 0.05, 12), Color(0.60, 0.50, 0.38))
	add_box_to_world(host, Vector3(0, 0.08, -6), Vector3(70, 0.1, 0.4), Color(0.5, 0.4, 0.2))
	add_box_to_world(host, Vector3(0, 0.08, 6), Vector3(70, 0.1, 0.4), Color(0.5, 0.4, 0.2))
	add_label(host, Vector3(3, 2.4, 0), "Spaceport Row")
	
	# Orienting structures for spawn view (west end)
	_add_hab_block(host, Vector3(-38, 0, -12), Vector3(8, 5, 12), Color(0.53, 0.47, 0.39).darkened(0.1))
	_add_hab_block(host, Vector3(-28, 0, 8), Vector3(6, 3, 6), Color(0.53, 0.47, 0.39))
	add_box_to_world(host, Vector3(-25, 2.5, -2.5), Vector3(2, 5, 2), Color(0.3, 0.3, 0.3)) # Sensor pylon

	_build_from_rooms(host)

	_add_tower(host, Vector3(-7, 0, -24), 8)
	add_label(host, Vector3(-7, 10.4, -24), "Control Tower")
	add_inspectable_marker(host, Vector3(-7, 4.5, -20.8), Vector3(4, 9, 1.2), _room_title("mos_eisley_control_tower", "Control Tower"), _room_inspection("mos_eisley_control_tower", "A tall observation module coordinates landings while trying to stay above the dust and noise."))

	# Parked low-poly craft
	_add_procedural_cargo_ship(host, Vector3(14, 0.45, -12), 40.0)
	_add_procedural_speeder(host, Vector3(6, 0.55, -8.5), -25.0)
	_add_procedural_miner(host, Vector3(4, 0.4, -19), 90.0)

	# A little life: barrels by Customs and the Transport Depot.
	for spot in [Vector3(-6.5, 0, 9.6), Vector3(-5.6, 0, 9.9), Vector3(12.5, 0, 8.4), Vector3(13.2, 0, 8.0)]:
		add_box_to_world(host, spot + Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6), Color(0.4, 0.45, 0.5))
		
	# Spaceport Row clutter: street-level utility and props
	add_box_to_world(host, Vector3(-18, 0.4, -5.5), Vector3(1.2, 0.8, 1.2), Color(0.4, 0.45, 0.5)) # Power box
	add_box_to_world(host, Vector3(-5, 0.6, 5.5), Vector3(0.6, 1.2, 0.6), Color(0.6, 0.3, 0.2)) # Comms relay
	add_box_to_world(host, Vector3(12, 0.3, -5.5), Vector3(2.0, 0.6, 1.0), Color(0.3, 0.3, 0.3)) # Cargo loader base
	add_box_to_world(host, Vector3(12, 1.0, -5.5), Vector3(1.0, 0.8, 1.0), Color(0.7, 0.6, 0.2)) # Cargo loader top
	
	# Add a couple of tall sensor/vaporator pylons along the street
	add_box_to_world(host, Vector3(-12, 1.5, -5.5), Vector3(0.5, 3.0, 0.5), Color(0.6, 0.6, 0.6)) # Scanner pylon
	add_box_to_world(host, Vector3(5, 1.8, 5.5), Vector3(0.3, 3.6, 0.3), Color(0.4, 0.4, 0.4)) # Vaporator core
	add_box_to_world(host, Vector3(5, 1.0, 5.5), Vector3(0.8, 0.2, 0.8), Color(0.5, 0.5, 0.5)) # Vaporator ring
	
	# Market/stall post near Customs
	add_box_to_world(host, Vector3(-8, 1.2, 6.5), Vector3(0.2, 2.4, 0.2), Color(0.3, 0.2, 0.1))
	add_box_to_world(host, Vector3(-8, 2.4, 7.5), Vector3(2.0, 0.1, 2.0), Color(0.6, 0.5, 0.4)) # Canvas shade

	_place_data_props(host)
	
	# Full-Area Probes
	add_route_probe(host, Vector3(-20, 1.2, -4.0), "Spawn")
	add_route_probe(host, Vector3(-25.5, 1.4, -8.0), "Bay94Entrance")
	add_route_probe(host, Vector3(-20.0, 0.2, -13.0), "Bay94Pit")
	add_route_probe(host, Vector3(-4.0, 1.2, 6.0), "CustomsFront")
	add_route_probe(host, Vector3(9.0, 1.2, -11.0), "SpeedersFront")
	add_route_probe(host, Vector3(9.0, 1.2, 3.0), "TransportDepotFront")
	add_route_probe(host, Vector3(-7.0, 1.2, -15.0), "ControlTowerFront")
	add_route_probe(host, Vector3(15.0, 1.2, -18.0), "DockingBay86Front")
	add_route_probe(host, Vector3(-20.0, 1.2, -22.0), "DockingBay87Front")

	# Full-Area Capture Points
	add_capture_point(host, Vector3(-16, 1.5, -8), Vector3(-20, 1.0, -25), "Spawn Range")
	add_capture_point(host, Vector3(-5, 1.8, 2), Vector3(15, 1.8, -2), "Spaceport Row East")
	add_capture_point(host, Vector3(5, 1.8, -2), Vector3(-20, 1.8, 2), "Spaceport Row West")
	add_capture_point(host, Vector3(-22, 1.8, -6), Vector3(-25, 1.8, -10), "Bay94 Entrance")
	add_capture_point(host, Vector3(-20, 1.8, -6), Vector3(-20, 0.5, -13), "Bay94 Pit")
	add_capture_point(host, Vector3(-3, 1.8, 2), Vector3(-3, 1.8, 8), "Customs Front")
	add_capture_point(host, Vector3(9, 1.8, -8), Vector3(9, 1.5, -16), "Speeders Front")
	add_capture_point(host, Vector3(9, 1.8, 2), Vector3(9, 1.8, 8), "Transport Depot Front")
	add_capture_point(host, Vector3(-7, 1.8, -8), Vector3(-7, 6.0, -24), "Control Tower")

func _add_bay_94_details(host: Node3D, center: Vector3) -> void:
	# Add entrance threshold and service flow area near the path
	add_box_to_world(host, center + Vector3(-5.5, 2.0, 3.0), Vector3(1.2, 4.0, 1.2), Color(0.35, 0.32, 0.25))
	add_box_to_world(host, center + Vector3(-5.5, 4.5, 5.0), Vector3(1.2, 1.0, 5.2), Color(0.35, 0.32, 0.25))
	add_box_to_world(host, center + Vector3(-5.5, 2.0, 7.0), Vector3(1.2, 4.0, 1.2), Color(0.35, 0.32, 0.25))
	add_box_to_world(host, center + Vector3(-5.5, 0.05, 5.0), Vector3(4.0, 0.1, 6.0), Color(0.25, 0.25, 0.25)) # Service pad
	
	# Blast-door frame and bay sign
	add_box_to_world(host, center + Vector3(-7.5, 2.5, 5.0), Vector3(1.0, 5.0, 6.0), Color(0.15, 0.15, 0.15)) # Insert ramp threshold
	
	# Bay 94 Signage
	add_box_to_world(host, center + Vector3(-6.9, 4.8, 5.0), Vector3(0.3, 1.4, 2.2), Color(0.7, 0.2, 0.1)) # Bay sign background
	add_label(host, center + Vector3(-6.7, 4.8, 5.0), "BAY 94")
	
	# Side equipment and wall detail (reduce blank door face)
	add_box_to_world(host, center + Vector3(-7.0, 1.5, 2.5), Vector3(0.5, 3.0, 1.0), Color(0.3, 0.3, 0.3)) # Door mechanism L
	add_box_to_world(host, center + Vector3(-7.0, 1.5, 7.5), Vector3(0.5, 3.0, 1.0), Color(0.3, 0.3, 0.3)) # Door mechanism R
	
	# Replace primitive block clusters with service equipment
	if ResourceLoader.exists(CRATE_MODEL):
		place_model(host, CRATE_MODEL, center + Vector3(-6.0, 0.5, 3.2), 15.0)
		place_model(host, CRATE_MODEL, center + Vector3(-6.0, 1.5, 3.2), -5.0)
	else:
		add_box_to_world(host, center + Vector3(-6.0, 0.5, 3.5), Vector3(1.0, 1.0, 1.5), Color(0.4, 0.45, 0.5)) # Equipment crate
		
	add_box_to_world(host, center + Vector3(-6.5, 1.2, 6.5), Vector3(0.4, 2.4, 0.4), Color(0.2, 0.2, 0.2)) # Pipe/conduit
	
	if ResourceLoader.exists(BARREL_MODEL):
		place_model(host, BARREL_MODEL, center + Vector3(-6.2, 0.4, 6.5), 0.0)
		place_model(host, BARREL_MODEL, center + Vector3(-5.8, 0.4, 6.9), 45.0)
	else:
		add_box_to_world(host, center + Vector3(-6.2, 0.3, 6.5), Vector3(0.8, 0.6, 0.8), Color(0.8, 0.7, 0.2)) # Generator unit
	
	# Pit details - Cover blocks dressed as docking-bay infrastructure
	add_box_to_world(host, center + Vector3(0, 0.8, 5.0), Vector3(3.0, 0.1, 0.4), Color(0.7, 0.6, 0.2)) # Warning strip
	
	# Fuel Cell cluster (Right)
	add_box_to_world(host, center + Vector3(4.2, 0.2, -2.9), Vector3(1.4, 0.4, 1.4), Color(0.2, 0.2, 0.2)) # Pallet
	if ResourceLoader.exists(BARREL_MODEL):
		place_model(host, BARREL_MODEL, center + Vector3(3.8, 0.4, -2.5), 15.0)
		place_model(host, BARREL_MODEL, center + Vector3(4.6, 0.4, -3.1), -10.0)
		place_model(host, BARREL_MODEL, center + Vector3(4.2, 0.4, -2.1), 45.0)
	else:
		add_box_to_world(host, center + Vector3(4.2, 0.6, -2.9), Vector3(1.1, 1.2, 1.1), Color(0.20, 0.21, 0.22))
	
	# Service Terminal / Gantry (Left)
	add_box_to_world(host, center + Vector3(-4.4, 0.2, -2.5), Vector3(1.2, 1.4, 1.0), Color(0.25, 0.28, 0.32)) # Terminal base
	add_box_to_world(host, center + Vector3(-4.4, 0.6, -1.9), Vector3(0.6, 0.4, 0.2), Color(0.1, 0.1, 0.1)) # Screen
	add_box_to_world(host, center + Vector3(-4.0, 1.0, -2.5), Vector3(0.2, 1.8, 0.2), Color(0.4, 0.4, 0.4)) # Antenna/Pipe

	# Cargo Stacks (Back Left and Back Right)
	if ResourceLoader.exists(CRATE_MODEL):
		place_model(host, CRATE_MODEL, center + Vector3(-2.8, 0.5, -4.2), 5.0)
		place_model(host, CRATE_MODEL, center + Vector3(-2.8, 1.5, -4.2), -3.0)
		place_model(host, CRATE_MODEL, center + Vector3(-1.6, 0.5, -4.4), 12.0)
		
		place_model(host, CRATE_MODEL, center + Vector3(2.7, 0.5, -4.0), -8.0)
		place_model(host, CRATE_MODEL, center + Vector3(2.7, 1.5, -4.0), 2.0)
	else:
		add_box_to_world(host, center + Vector3(-2.8, 0.6, -4.2), Vector3(1.5, 1.2, 1.0), Color(0.35, 0.25, 0.16))
		add_box_to_world(host, center + Vector3(2.7, 0.6, -4.0), Vector3(1.5, 1.2, 1.0), Color(0.35, 0.25, 0.16))
	
	# Floor markings (painted lines)
	add_box_to_world(host, center + Vector3(0, 0.05, 0), Vector3(12.0, 0.1, 0.4), Color(0.8, 0.7, 0.2)) # Outer ring limit
	add_box_to_world(host, center + Vector3(0, 0.05, -2.0), Vector3(0.4, 0.1, 4.0), Color(0.8, 0.7, 0.2)) # Center guide line
	
	# Number "94" painted on floor
	var paint_color = Color(0.8, 0.2, 0.1)
	add_box_to_world(host, center + Vector3(-1.0, 0.05, 1.0), Vector3(0.8, 0.1, 0.2), paint_color) # 9 top
	add_box_to_world(host, center + Vector3(-1.0, 0.05, 1.8), Vector3(0.8, 0.1, 0.2), paint_color) # 9 mid
	add_box_to_world(host, center + Vector3(-1.3, 0.05, 1.4), Vector3(0.2, 0.1, 0.8), paint_color) # 9 left
	add_box_to_world(host, center + Vector3(-0.7, 0.05, 1.8), Vector3(0.2, 0.1, 1.8), paint_color) # 9 right
	
	add_box_to_world(host, center + Vector3(0.5, 0.05, 1.3), Vector3(0.2, 0.1, 0.8), paint_color) # 4 left
	add_box_to_world(host, center + Vector3(1.0, 0.05, 1.6), Vector3(1.2, 0.1, 0.2), paint_color) # 4 mid
	add_box_to_world(host, center + Vector3(1.3, 0.05, 1.8), Vector3(0.2, 0.1, 1.8), paint_color) # 4 right
	
	# Extra bay dressing: Cargo sleds and fuel pipes
	add_box_to_world(host, center + Vector3(0, 0.2, -6.0), Vector3(3.0, 0.4, 1.5), Color(0.4, 0.4, 0.4)) # Cargo sled
	add_box_to_world(host, center + Vector3(2.0, 1.5, 6.0), Vector3(0.2, 3.0, 0.2), Color(0.8, 0.4, 0.2)) # Fuel pipe 1
	add_box_to_world(host, center + Vector3(2.5, 1.5, 6.0), Vector3(0.2, 3.0, 0.2), Color(0.2, 0.4, 0.8)) # Fuel pipe 2
func _place_data_props(host: Node3D) -> void:
	if not FileAccess.file_exists(PROPS_DATA_PATH):
		return
	var file := FileAccess.open(PROPS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var props_array: Variant = parsed.get("props", null)
	if typeof(props_array) != TYPE_ARRAY:
		return
	var props: Array = props_array
	for entry in props:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var model_key: String = String(entry.get("model", ""))
		if not MODEL_KEY_MAP.has(model_key):
			continue  # unknown key — skip gracefully
		var model_path: String = MODEL_KEY_MAP[model_key]
		var pos_dict: Variant = entry.get("pos", null)
		if typeof(pos_dict) != TYPE_DICTIONARY:
			continue
		var px: float = float(pos_dict.get("x", 0.0))
		var py: float = float(pos_dict.get("y", 0.0))
		var pz: float = float(pos_dict.get("z", 0.0))
		var rot: float = float(entry.get("rot_deg", 0.0))
		var scale_val: float = float(entry.get("scale", 1.0))
		place_model(host, model_path, Vector3(px, py, pz), rot, scale_val)

func _add_hab_block(host: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "HabBlock"
	body.position = pos
	host.add_child(body)
	
	# Main block (grounded)
	add_box(body, Vector3(0, size.y * 0.5, 0), size, color)
	
	# Add a smaller secondary block to make it stepped
	var secondary_size = size * 0.6
	secondary_size.y = size.y * 0.7
	var x_offset = (size.x - secondary_size.x) * 0.5 * (1.0 if _rng.randf() > 0.5 else -1.0)
	var z_offset = (size.z - secondary_size.z) * 0.5 * (1.0 if _rng.randf() > 0.5 else -1.0)
	add_box(body, Vector3(x_offset, size.y + secondary_size.y * 0.5, z_offset), secondary_size, color)
	
	# Wall recesses/variations to break up flat slabs
	add_box(body, Vector3(size.x * 0.3, size.y * 0.4, size.z * 0.5 + 0.1), Vector3(size.x * 0.15, size.y * 0.6, 0.3), color.darkened(0.2))
	add_box(body, Vector3(-size.x * 0.3, size.y * 0.4, size.z * 0.5 + 0.1), Vector3(size.x * 0.15, size.y * 0.6, 0.3), color.darkened(0.2))
	add_box(body, Vector3(size.x * 0.25, size.y * 0.4, -size.z * 0.5 - 0.1), Vector3(size.x * 0.2, size.y * 0.6, 0.3), color.darkened(0.2))
	add_box(body, Vector3(-size.x * 0.25, size.y * 0.4, -size.z * 0.5 - 0.1), Vector3(size.x * 0.2, size.y * 0.6, 0.3), color.darkened(0.2))
	
	# Add an entrance door recess in the middle front
	add_box(body, Vector3(0, 1.25, size.z * 0.5 + 0.1), Vector3(1.8, 2.5, 0.4), color.darkened(0.4))
	
	# Add a shade cloth / awning over the front entrance
	var awning_color := Color(0.65, 0.55, 0.45)
	if _rng.randf() > 0.5: awning_color = Color(0.7, 0.6, 0.4)
	add_box(body, Vector3(0, 2.8, size.z * 0.5 + 1.2), Vector3(4.0, 0.1, 2.4), awning_color)
	
	# Add some simple support beams for the awning
	add_box(body, Vector3(-1.8, 1.4, size.z * 0.5 + 2.3), Vector3(0.15, 2.8, 0.15), color.darkened(0.3))
	add_box(body, Vector3(1.8, 1.4, size.z * 0.5 + 2.3), Vector3(0.15, 2.8, 0.15), color.darkened(0.3))

	
	# Roof caps (correctly grounded to their blocks)
	add_box(body, Vector3(0, size.y + 0.1, 0), Vector3(size.x + 0.4, 0.2, size.z + 0.4), color.darkened(0.16))
	add_box(body, Vector3(x_offset, size.y + secondary_size.y + 0.1, z_offset), Vector3(secondary_size.x + 0.4, 0.2, secondary_size.z + 0.4), color.darkened(0.16))
	
	# Facade Details: Pillars and Awnings
	if size.x > 5:
		# Awning
		add_box(body, Vector3(0, size.y * 0.45, -size.z * 0.5 - 1.0), Vector3(size.x * 0.8, 0.2, 2.0), color.darkened(0.2))
		# Pillars
		add_box(body, Vector3(-size.x * 0.35, size.y * 0.225, -size.z * 0.5 - 1.8), Vector3(0.4, size.y * 0.45, 0.4), color.darkened(0.1))
		add_box(body, Vector3(size.x * 0.35, size.y * 0.225, -size.z * 0.5 - 1.8), Vector3(0.4, size.y * 0.45, 0.4), color.darkened(0.1))
	
	# Doorway
	var doorway_path := "res://assets/3d/generated/google/buildings/desert_doorway.tscn"
	if ResourceLoader.exists(doorway_path):
		var doorway = place_model(body, doorway_path, Vector3(size.x * 0.3, 0, -size.z * 0.5 - 0.1))
	else:
		add_box(body, Vector3(size.x * 0.3, 0.95, -size.z * 0.52), Vector3(1.5, 1.9, 0.18), Color(0.12, 0.11, 0.1))

	# Dome cap on secondary roof
	var dome_path := "res://assets/3d/generated/google/buildings/dome_cap.tscn"
	if ResourceLoader.exists(dome_path):
		var dome = place_model(body, dome_path, Vector3(x_offset, size.y + secondary_size.y, z_offset))
		if dome != null:
			dome.scale = Vector3(secondary_size.x * 0.4, 1.0, secondary_size.z * 0.4)

func _add_tower(host: Node3D, pos: Vector3, height: int) -> void:
	for y in range(height):
		add_box_to_world(host, pos + Vector3(0, y + 0.5, 0), Vector3(3.2, 1, 3.2), Color(0.46, 0.45, 0.40).lightened(y * 0.015))
	add_box_to_world(host, pos + Vector3(0, height + 0.45, 0), Vector3(5.2, 0.9, 5.2), Color(0.30, 0.32, 0.32))
	add_box_to_world(host, pos + Vector3(0, height + 1.6, 0), Vector3(1.2, 1.8, 1.2), Color(0.18, 0.28, 0.32))

	# Base infrastructure and perimeter
	add_box_to_world(host, pos + Vector3(-2, 1, 0), Vector3(1.5, 2, 2.5), Color(0.2, 0.2, 0.2)) # Main Generator
	add_box_to_world(host, pos + Vector3(-3.5, 0.5, 0), Vector3(3, 0.3, 3), Color(0.3, 0.3, 0.3)) # Base platform
	add_box_to_world(host, pos + Vector3(0, height + 3.0, 0), Vector3(0.2, 2.0, 0.2), Color(0.6, 0.6, 0.6)) # Antenna 1
	add_box_to_world(host, pos + Vector3(0.5, height + 2.5, 0.5), Vector3(0.1, 1.5, 0.1), Color(0.6, 0.6, 0.6)) # Antenna 2
	add_box_to_world(host, pos + Vector3(-0.5, height + 2.8, -0.5), Vector3(0.1, 1.8, 0.1), Color(0.5, 0.5, 0.5)) # Antenna 3
	
	# Cable runs from generator to tower
	add_box_to_world(host, pos + Vector3(-1.0, 0.2, 0), Vector3(2.0, 0.1, 0.2), Color(0.1, 0.1, 0.1))
	add_box_to_world(host, pos + Vector3(-1.0, 0.2, 0.4), Vector3(2.0, 0.1, 0.1), Color(0.1, 0.1, 0.1))
	
	# Perimeter bollards/equipment
	for x in [-4.5, 4.5]:
		for z in [-4.5, 4.5]:
			add_box_to_world(host, pos + Vector3(x, 0.5, z), Vector3(0.4, 1.0, 0.4), Color(0.4, 0.4, 0.4))
	
	# Ladders on the side of the tower
	for y in range(0, height, 2):
		add_box_to_world(host, pos + Vector3(1.7, y + 1.0, 0), Vector3(0.1, 2.0, 0.8), Color(0.3, 0.3, 0.3))


	# Add a moisture vaporator next to the tower
	var vaporator_path := "res://assets/3d/generated/google/buildings/moisture_vaporator.tscn"
	if ResourceLoader.exists(vaporator_path):
		place_model(host, vaporator_path, pos + Vector3(3.5, 0, 3.5))

func _build_from_rooms(host: Node3D) -> void:
	for slug in _rooms:
		var room: Dictionary = _rooms[slug]
		var style: String = room.get("style", "civic")
		var pos_dict: Dictionary = room.get("scene_position", {})
		if pos_dict.is_empty():
			continue
		var pos := Vector3(float(pos_dict.get("x", 0)), 0.0, float(pos_dict.get("z", 0)))
		var name: String = room.get("name", "Unknown Room")
		
		# Offset for visual centering based on the marker position
		var is_south := pos.z > 0
		var building_pos := pos
		if is_south:
			building_pos.z += 3.0
		else:
			building_pos.z -= 3.0
			
		if style == "dock":
			# Pit is usually further back
			building_pos = pos
			if slug == "docking_bay_94_entrance":
				continue # Handled by the pit
			elif slug == "docking_bay_94_pit":
				_add_landing_pad_walled(host, building_pos, name, "94")
				add_inspectable_marker(host, Vector3(-25.5, 1.3, -10.0), Vector3(1.2, 2.6, 7.0), _room_title("docking_bay_94_entrance", "Docking Bay 94"), _room_inspection("docking_bay_94_entrance", "Cracked steps drop into a scorched bay pit lined with loaders, fuel cells, and cargo cover."))
				_add_bay_94_details(host, building_pos)
			elif slug == "docking_bay_86":
				_add_landing_pad_walled(host, building_pos, name, "86")
				add_inspectable_marker(host, pos, Vector3(6, 2.4, 1.2), _room_title(slug, name), _room_inspection(slug, name))
			elif slug == "docking_bay_87":
				_add_landing_pad_walled(host, building_pos, name, "87")
				add_inspectable_marker(host, pos, Vector3(6, 2.4, 1.2), _room_title(slug, name), _room_inspection(slug, name))
		elif style == "civic" or style == "vendor":
			var b_size := Vector3(8, 3, 6)
			var b_color := Color(0.53, 0.47, 0.39)
			if slug == "mos_eisley_customs":
				b_size = Vector3(12, 4.5, 9)
				b_color = Color(0.6, 0.5, 0.4)
				_add_hab_block(host, building_pos, b_size, b_color)
				add_label(host, building_pos + Vector3(0, b_size.y + 0.7, 0), name)
				add_inspectable_marker(host, pos, Vector3(6, 3.2, 1.2), _room_title(slug, name), _room_inspection(slug, name))
				# Customs identity
				# Customs identity
				add_box_to_world(host, building_pos + Vector3(0, 1.0, 5), Vector3(3.0, 2.0, 1.5), Color(0.2, 0.25, 0.3)) # Checkpoint booth base
				add_box_to_world(host, building_pos + Vector3(0, 1.2, 5.8), Vector3(2.0, 1.0, 0.8), Color(0.1, 0.1, 0.1)) # Desk
				
				# Scanner gate
				add_box_to_world(host, building_pos + Vector3(-2.5, 1.5, 7), Vector3(0.4, 3.0, 0.4), Color(0.4, 0.4, 0.4)) # Scanner pillar L
				add_box_to_world(host, building_pos + Vector3(2.5, 1.5, 7), Vector3(0.4, 3.0, 0.4), Color(0.4, 0.4, 0.4)) # Scanner pillar R
				add_box_to_world(host, building_pos + Vector3(0, 3.0, 7), Vector3(5.4, 0.6, 0.6), Color(0.5, 0.5, 0.5)) # Scanner arch
				add_box_to_world(host, building_pos + Vector3(0, 1.5, 7), Vector3(4.6, 2.8, 0.1), Color(1.0, 0.2, 0.2, 0.3)) # Laser field
				
				# Queue rails
				add_box_to_world(host, building_pos + Vector3(-1, 0.5, 9.5), Vector3(0.1, 1.0, 4.0), Color(0.6, 0.6, 0.6)) 
				add_box_to_world(host, building_pos + Vector3(1, 0.5, 9.5), Vector3(0.1, 1.0, 4.0), Color(0.6, 0.6, 0.6))
				
				# Contraband / Inspection area
				add_box_to_world(host, building_pos + Vector3(3.5, 0.5, 6), Vector3(1.5, 1.0, 1.5), Color(0.8, 0.2, 0.2)) # Inspection crate
				add_box_to_world(host, building_pos + Vector3(-3.5, 0.5, 6), Vector3(1.0, 1.5, 1.0), Color(0.3, 0.3, 0.3)) # Guard stand
				
				# Posted Notices
				add_box_to_world(host, building_pos + Vector3(-1.5, 2.0, 4.6), Vector3(1.0, 1.2, 0.1), Color(0.9, 0.9, 0.8)) # Poster
				add_box_to_world(host, building_pos + Vector3(1.5, 1.8, 4.6), Vector3(0.8, 1.0, 0.1), Color(0.8, 0.3, 0.2)) # Warning poster
				continue
			elif slug == "mos_eisley_transport_depot":
				b_size = Vector3(10, 3.5, 12)
				b_color = Color(0.4, 0.35, 0.3)
				_add_hab_block(host, building_pos, b_size, b_color)
				add_label(host, building_pos + Vector3(0, b_size.y + 0.7, 0), name)
				add_inspectable_marker(host, pos, Vector3(6, 3.2, 1.2), _room_title(slug, name), _room_inspection(slug, name))
				# Depot identity - Ticket Window & Awning
				add_box_to_world(host, building_pos + Vector3(-2, 1.25, 6.1), Vector3(2.5, 1.5, 0.5), Color(0.2, 0.2, 0.2)) # Window
				add_box_to_world(host, building_pos + Vector3(-2, 2.5, 7.5), Vector3(4.0, 0.1, 3.0), Color(0.7, 0.3, 0.2)) # Awning
				add_box_to_world(host, building_pos + Vector3(-3.8, 1.25, 8.8), Vector3(0.1, 2.5, 0.1), Color(0.3, 0.3, 0.3)) # Pole
				add_box_to_world(host, building_pos + Vector3(-0.2, 1.25, 8.8), Vector3(0.1, 2.5, 0.1), Color(0.3, 0.3, 0.3)) # Pole
				
				# Asymmetric props
				add_box_to_world(host, building_pos + Vector3(3, 1.5, 6.2), Vector3(3.0, 2.0, 0.2), Color(0.1, 0.1, 0.1)) # Schedule board (right)
				add_box_to_world(host, building_pos + Vector3(3, 0.5, 8), Vector3(2.0, 0.5, 1.0), Color(0.3, 0.3, 0.3)) # Bench (right)
				add_box_to_world(host, building_pos + Vector3(2, 0.5, 9.5), Vector3(2.0, 0.5, 1.0), Color(0.3, 0.3, 0.3)) # Bench (angled)
				add_box_to_world(host, building_pos + Vector3(-4.5, 0.5, 9.5), Vector3(2.5, 1.0, 2.0), Color(0.4, 0.4, 0.4)) # Cargo pickup area
				add_box_to_world(host, building_pos + Vector3(-2, 1.0, 10), Vector3(1.0, 2.0, 1.0), Color(0.5, 0.6, 0.8)) # Droid kiosk
				add_box_to_world(host, building_pos + Vector3(4, 0.5, 9), Vector3(3.0, 1.0, 3.0), Color(0.4, 0.4, 0.4)) # Cargo pickup area
				continue
			elif "spaceport_row" in slug:
				b_size = Vector3(14, 2.5, 7)
				b_color = Color(0.5, 0.45, 0.38)
			elif slug == "mos_eisley_speeders":
				b_size = Vector3(9, 2.8, 8)
				_add_hab_block(host, building_pos, b_size, b_color)
				add_label(host, building_pos + Vector3(0, b_size.y + 0.7, 0), name)
				add_inspectable_marker(host, pos, Vector3(6, 3.2, 1.2), _room_title(slug, name), _room_inspection(slug, name))
				# Speeders identity
				add_box_to_world(host, building_pos + Vector3(-2, 0.2, 5), Vector3(3.0, 0.4, 4.0), Color(0.2, 0.2, 0.2)) # Lift pad
				add_box_to_world(host, building_pos + Vector3(3, 1.0, 4), Vector3(2.0, 2.0, 0.5), Color(0.7, 0.3, 0.1)) # Tool rack
				add_box_to_world(host, building_pos + Vector3(0, 0.8, 4), Vector3(3.0, 1.0, 1.0), Color(0.4, 0.4, 0.4)) # Service counter
				# Add Shop Signage
				add_box_to_world(host, building_pos + Vector3(0, 2.5, 4.2), Vector3(4.0, 0.8, 0.2), Color(0.8, 0.6, 0.1))
				continue
				
			_add_hab_block(host, building_pos, b_size, b_color)
			add_label(host, building_pos + Vector3(0, b_size.y + 0.7, 0), name)
			add_inspectable_marker(host, pos, Vector3(6, 3.2, 1.2), _room_title(slug, name), _room_inspection(slug, name))
			
			if slug == "mos_eisley_transport_depot":
				# Add multiple crates of different colors in the camera's view path to break up floor dominance
				add_box_to_world(host, Vector3(8, 0.5, 4), Vector3(1.0, 1.0, 1.0), Color(0.35, 0.3, 0.25))
				add_box_to_world(host, Vector3(10, 0.5, 4), Vector3(1.0, 1.0, 1.0), Color(0.2, 0.2, 0.2))
				add_box_to_world(host, Vector3(9, 0.3, 3), Vector3(0.6, 0.6, 0.6), Color(0.6, 0.2, 0.2))
			
			# Add vaporator or barricade nearby randomly
			if _rng.randf() > 0.5:
				var vap_path := "res://assets/3d/generated/google/buildings/moisture_vaporator.tscn"
				if ResourceLoader.exists(vap_path):
					place_model(host, vap_path, building_pos + Vector3((_rng.randf() - 0.5) * 10.0, 0, (_rng.randf() - 0.5) * 10.0))

func _add_landing_pad_walled(host: Node3D, pos: Vector3, label_text: String, bay_num: String = "") -> void:
	# Add walled perimeter with recessed pit feel
	var wall_color := Color(0.68, 0.57, 0.42)
	add_box_to_world(host, pos + Vector3(0, 1.5, -8), Vector3(16, 3.0, 1), wall_color) # Back wall
	add_box_to_world(host, pos + Vector3(-8, 1.5, 0), Vector3(1, 3.0, 16), wall_color) # Left wall
	add_box_to_world(host, pos + Vector3(8, 1.5, 0), Vector3(1, 3.0, 16), wall_color) # Right wall
	
	# Entryway arch & partial front walls
	add_box_to_world(host, pos + Vector3(-5.5, 1.5, 8), Vector3(6, 3.0, 1), wall_color)
	add_box_to_world(host, pos + Vector3(5.5, 1.5, 8), Vector3(6, 3.0, 1), wall_color)
	add_box_to_world(host, pos + Vector3(0, 3.5, 8), Vector3(6, 1.0, 1), wall_color) # Lintel
	
	# Wall support struts to break up flat surfaces
	for x in [-7.5, 7.5]:
		for z in [-7.5, 0.0, 7.5]:
			add_box_to_world(host, pos + Vector3(x, 1.5, z), Vector3(0.5, 3.2, 0.5), wall_color.darkened(0.1))
	for x in [-2.5, 2.5]:
		add_box_to_world(host, pos + Vector3(x, 1.5, -7.5), Vector3(0.5, 3.2, 0.5), wall_color.darkened(0.1))
	
	# A slightly recessed dark floor for the pad
	add_box_to_world(host, pos + Vector3(0, 0.05, 0), Vector3(15, 0.1, 15), Color(0.24, 0.25, 0.25))
	
	# Floor pit
	add_box_to_world(host, pos + Vector3(0, -0.2, 0), Vector3(14, 0.1, 14), Color(0.24, 0.22, 0.20))
	add_box_to_world(host, pos + Vector3(0, -0.15, 0), Vector3(10, 0.1, 10), Color(0.38, 0.39, 0.38))
	add_label(host, pos + Vector3(0, 4.0, 0), label_text)
	
	# Entry ramp/stairs
	var is_south = pos.z > 0
	var ramp_offset = Vector3(0, 0.0, 7) if not is_south else Vector3(0, 0.0, -7)
	add_box_to_world(host, pos + ramp_offset, Vector3(4, 0.5, 2), Color(0.3, 0.3, 0.3))
	
	# Add equipment clusters in the corners of the pit
	# Service terminal / fuel hookup
	add_box_to_world(host, pos + Vector3(-5.0, 0.8, -5.0), Vector3(1.2, 2.0, 1.0), Color(0.4, 0.45, 0.5))
	add_box_to_world(host, pos + Vector3(-5.0, 0.4, -4.0), Vector3(2.0, 0.2, 0.4), Color(0.2, 0.2, 0.2)) # Cables/pipes
	
	# Cargo sled
	add_box_to_world(host, pos + Vector3(5.0, -0.1, 4.0), Vector3(3.0, 0.2, 2.0), Color(0.5, 0.5, 0.5)) # Sled base
	add_box_to_world(host, pos + Vector3(5.0, 0.5, 4.0), Vector3(2.6, 1.0, 1.6), Color(0.35, 0.3, 0.25)) # Cargo block
	
	# Small power generator
	add_box_to_world(host, pos + Vector3(-4.0, 0.2, 5.0), Vector3(1.5, 0.8, 1.5), Color(0.6, 0.6, 0.2))
	add_box_to_world(host, pos + Vector3(-4.0, 0.8, 5.0), Vector3(0.5, 0.4, 0.5), Color(0.8, 0.2, 0.1)) # Warning light

	# Door frame
	var door_offset = Vector3(0, 1.5, 8) if not is_south else Vector3(0, 1.5, -8)
	add_box_to_world(host, pos + door_offset + Vector3(-2.5, 0, 0), Vector3(1, 3.0, 1), wall_color)
	add_box_to_world(host, pos + door_offset + Vector3(2.5, 0, 0), Vector3(1, 3.0, 1), wall_color)
	add_box_to_world(host, pos + door_offset + Vector3(0, 1.25, 0), Vector3(4, 0.5, 1), wall_color)

	# Wall breaks to break up the long plain front wall (Spaceport Row East left wall)
	var front_z = door_offset.z
	var front_z_dir = 1.0 if not is_south else -1.0
	
	# Supported red awning/sign panel (replaces the floating stripe)
	add_box_to_world(host, pos + Vector3(-4.0, 2.2, front_z + 0.6 * front_z_dir), Vector3(3.5, 0.2, 1.5), Color(0.7, 0.2, 0.2)) # Red awning
	add_box_to_world(host, pos + Vector3(-5.5, 1.1, front_z + 1.2 * front_z_dir), Vector3(0.1, 2.2, 0.1), Color(0.3, 0.3, 0.3)) # Support pole
	add_box_to_world(host, pos + Vector3(-2.5, 1.1, front_z + 1.2 * front_z_dir), Vector3(0.1, 2.2, 0.1), Color(0.3, 0.3, 0.3)) # Support pole
	
	# Recessed vendor hatch / alcove
	add_box_to_world(host, pos + Vector3(4.5, 0.5, front_z + 0.2 * front_z_dir), Vector3(1.5, 1.2, 0.8), Color(0.15, 0.15, 0.15)) # Alcove interior
	add_box_to_world(host, pos + Vector3(4.5, 0.3, front_z + 0.5 * front_z_dir), Vector3(1.5, 0.6, 0.4), Color(0.4, 0.4, 0.4)) # Vendor counter
	
	# Pipes and vents
	add_box_to_world(host, pos + Vector3(-6.5, 1.5, front_z + 0.3 * front_z_dir), Vector3(0.2, 3.0, 0.2), Color(0.3, 0.3, 0.3)) # Vertical pipe
	add_box_to_world(host, pos + Vector3(6.5, 2.5, front_z + 0.2 * front_z_dir), Vector3(1.2, 0.6, 0.4), Color(0.2, 0.25, 0.25)) # Wall vent

	var light_path := "res://assets/3d/generated/google/buildings/landing_pad_light.tscn"
	for offset in [Vector3(-4.8, -0.1, -4.8), Vector3(4.8, -0.1, -4.8), Vector3(-4.8, -0.1, 4.8), Vector3(4.8, -0.1, 4.8)]:
		if ResourceLoader.exists(light_path):
			place_model(host, light_path, pos + offset)
		else:
			add_box_to_world(host, pos + offset + Vector3(0, 0.25, 0), Vector3(1, 0.8, 1), Color(0.83, 0.64, 0.18))


func _add_crate_stack(host: Node3D, pos: Vector3, count: int) -> void:
	for i in range(count):
		var body := StaticBody3D.new()
		body.name = "Crate"
		body.position = pos + Vector3(0, 0.5 + i, 0)
		host.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.0, 1.0, 1.0)
		collision.shape = shape
		body.add_child(collision)
		var colors := [Color(0.36, 0.25, 0.16), Color(0.42, 0.46, 0.5), Color(0.24, 0.28, 0.31)]
		add_box(body, Vector3.ZERO, Vector3(1.0, 1.0, 1.0), colors[i % colors.size()])

# --- primitives (also reused by main.gd's range geometry) ---
func add_box_to_world(host: Node3D, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Block"
	body.position = pos
	host.add_child(body)
	add_box(body, Vector3.ZERO, size, color)
	return body

func add_box(parent: Node3D, local_pos: Vector3, size: Vector3, color: Color, part_name: String = "") -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = local_pos
	if part_name != "":
		collision.name = "DamagePart_%s_Collision" % part_name
	parent.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.material_override = make_material(color, 0.9)
	if part_name != "":
		mesh_instance.name = "DamagePart_%s" % part_name
		mesh_instance.set_meta("damage_part", part_name)
	parent.add_child(mesh_instance)

func _add_procedural_cargo_ship(host: Node3D, pos: Vector3, rot_deg: float) -> void:
	var ship := Node3D.new()
	ship.position = pos
	ship.rotation_degrees.y = rot_deg
	host.add_child(ship)
	add_box(ship, Vector3(0, 1.2, 0), Vector3(3.0, 1.2, 6.0), Color(0.4, 0.45, 0.5)) # Hull
	add_box(ship, Vector3(0, 2.0, 1.5), Vector3(2.0, 0.8, 1.5), Color(0.2, 0.25, 0.3)) # Cockpit
	add_box(ship, Vector3(-1.8, 1.0, -1.0), Vector3(0.8, 0.8, 4.0), Color(0.3, 0.35, 0.4)) # Engine L
	add_box(ship, Vector3(1.8, 1.0, -1.0), Vector3(0.8, 0.8, 4.0), Color(0.3, 0.35, 0.4)) # Engine R

func _add_procedural_speeder(host: Node3D, pos: Vector3, rot_deg: float) -> void:
	var ship := Node3D.new()
	ship.position = pos
	ship.rotation_degrees.y = rot_deg
	host.add_child(ship)
	add_box(ship, Vector3(0, 0.6, 0), Vector3(1.5, 0.4, 4.0), Color(0.6, 0.2, 0.2)) # Body
	add_box(ship, Vector3(0, 1.0, 0.5), Vector3(1.0, 0.4, 1.0), Color(0.1, 0.1, 0.1)) # Cockpit
	add_box(ship, Vector3(0, 0.6, 2.0), Vector3(0.5, 0.2, 1.5), Color(0.5, 0.5, 0.5)) # Nose

func _add_procedural_miner(host: Node3D, pos: Vector3, rot_deg: float) -> void:
	var ship := Node3D.new()
	ship.position = pos
	ship.rotation_degrees.y = rot_deg
	host.add_child(ship)
	add_box(ship, Vector3(0, 1.0, 0), Vector3(2.5, 1.5, 3.5), Color(0.7, 0.5, 0.2)) # Hull
	add_box(ship, Vector3(0, 1.5, -2.0), Vector3(1.5, 1.0, 1.5), Color(0.3, 0.3, 0.3)) # Cargo pod
	add_box(ship, Vector3(-1.5, 0.5, 1.0), Vector3(0.6, 0.6, 2.0), Color(0.2, 0.2, 0.2)) # Sponson L
	add_box(ship, Vector3(1.5, 0.5, 1.0), Vector3(0.6, 0.6, 2.0), Color(0.2, 0.2, 0.2)) # Sponson R

func make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

## Instance a curated GLB model (cached PackedScene). Returns null if it fails to
## load, so callers can fall back to procedural geometry.
func instance_model(model_path: String) -> Node3D:
	if not _model_cache.has(model_path):
		_model_cache[model_path] = load(model_path)
	var packed: Variant = _model_cache[model_path]
	if packed == null or not (packed is PackedScene):
		return null
	return (packed as PackedScene).instantiate()

func _load_model_manifest() -> void:
	if not FileAccess.file_exists(MODEL_MANIFEST_PATH):
		push_error("Missing model manifest: " + MODEL_MANIFEST_PATH)
		return
	var file := FileAccess.open(MODEL_MANIFEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("models"):
		_model_manifest = parsed.get("models", {})

## Place a low-poly model into the world. Automatically computes visual AABB to ground it
## flush against pos.y, unless it's a known hovercraft in the manifest.
func place_model(host: Node3D, model_path: String, pos: Vector3, rot_deg: float = 0.0, model_scale: float = 1.0) -> Node3D:
	var inst := instance_model(model_path)
	if inst == null:
		return null
	
	var manifest_data: Dictionary = _model_manifest.get(model_path, {})
	var is_hover: bool = manifest_data.get("hover", false)
	var hover_height: float = manifest_data.get("hover_height", 0.0)
	var bottom_offset: float = manifest_data.get("bottom_offset", 0.0)
	var manifest_scale: float = manifest_data.get("visual_scale", 1.0)
	
	# Allow explicit passed scale to override manifest scale if it's != 1.0
	var final_scale = model_scale if model_scale != 1.0 else manifest_scale
	
	inst.position = pos
	inst.rotation_degrees.y = rot_deg
	inst.scale = Vector3.ONE * final_scale
	host.add_child(inst)
	
	var min_y := 9999.0
	var found_mesh := false
	var stack: Array[Dictionary] = [{"node": inst, "trans": Transform3D()}]
	while stack.size() > 0:
		var item = stack.pop_back()
		var node = item["node"]
		var current_trans = item["trans"]
		if node is MeshInstance3D and node.mesh != null:
			var aabb = node.mesh.get_aabb()
			for i in range(8):
				var vertex = aabb.get_endpoint(i)
				var local_vertex = current_trans * vertex
				if local_vertex.y < min_y:
					min_y = local_vertex.y
			found_mesh = true
		for child in node.get_children():
			var next_trans = current_trans
			if child is Node3D:
				next_trans = current_trans * child.transform
			stack.push_back({"node": child, "trans": next_trans})
	
	if is_hover:
		inst.set_meta("hover", true)
		inst.position.y = pos.y + hover_height
	else:
		inst.set_meta("grounded", true)
		if found_mesh and min_y != 9999.0:
			inst.position.y = pos.y - min_y + bottom_offset
			
	return inst

func add_label(host: Node3D, pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	if not OS.get_cmdline_args().has("--debug-world-labels"):
		return
	var label := Label3D.new()
	label.text = text
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.position = pos
	host.add_child(label)

func add_inspectable_marker(host: Node3D, pos: Vector3, size: Vector3, title: String, description: String) -> void:
	var body := StaticBody3D.new()
	body.name = "Inspect_%s" % title.replace(" ", "_")
	body.position = pos
	body.set_meta("inspectable", true)
	body.set_meta("title", title)
	body.set_meta("description", description)
	host.add_child(body)

	var collision := CollisionShape3D.new()
	collision.set_meta("inspect_volume", true)
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func add_capture_point(host: Node3D, pos: Vector3, look_at_pos: Vector3, title: String) -> void:
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
		mesh_inst.material_override = make_material(Color(1.0, 0.0, 1.0), 0.5)
		point.add_child(mesh_inst)
		add_label(point, Vector3(0, 0.5, 0), "Capture: %s" % title, Color(1.0, 0.5, 1.0))

func add_route_probe(host: Node3D, pos: Vector3, title: String) -> void:
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
		mesh_inst.material_override = make_material(Color(1.0, 1.0, 0.0), 0.5)
		body.add_child(mesh_inst)
		add_label(body, Vector3(0, 2.0, 0), "Route: %s" % title, Color(1.0, 1.0, 0.0))
# --- spaceport room flavor data ---
func _load_rooms() -> void:
	if not FileAccess.file_exists(SPACEPORT_ROW_DATA_PATH):
		return
	var file := FileAccess.open(SPACEPORT_ROW_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for room in parsed.get("rooms", []):
		if typeof(room) == TYPE_DICTIONARY:
			_rooms[String(room.get("slug", ""))] = room

func _room_title(slug: String, fallback: String) -> String:
	var room: Dictionary = _rooms.get(slug, {})
	return String(room.get("name", fallback))

func _room_inspection(slug: String, fallback: String) -> String:
	var room: Dictionary = _rooms.get(slug, {})
	return String(room.get("inspect_text", fallback))


# --- Voxel Asset Library Showcase Room ---
func build_asset_library(host: Node3D) -> void:
	# 1. Floor slab (Expanded 32m x 32m gallery space)
	add_box_to_world(host, Vector3(30, 0.05, 15), Vector3(32, 0.1, 32), Color(0.16, 0.18, 0.20))
	add_label(host, Vector3(30, 2.5, 31), "Voxel Exhibition Gallery")
	
	# 2. Main structural walls (dark industrial tones)
	add_box_to_world(host, Vector3(30, 2.0, -1.0), Vector3(32, 4.0, 0.5), Color(0.22, 0.25, 0.28)) # Back
	add_box_to_world(host, Vector3(14.0, 2.0, 15), Vector3(0.5, 4.0, 32.5), Color(0.22, 0.25, 0.28)) # Left
	add_box_to_world(host, Vector3(46.0, 2.0, 15), Vector3(0.5, 4.0, 32.5), Color(0.22, 0.25, 0.28)) # Right
	
	# Front wall with entrance gap
	add_box_to_world(host, Vector3(21.0, 2.0, 31.0), Vector3(14.0, 4.0, 0.5), Color(0.22, 0.25, 0.28))
	add_box_to_world(host, Vector3(39.0, 2.0, 31.0), Vector3(14.0, 4.0, 0.5), Color(0.22, 0.25, 0.28))
	add_box_to_world(host, Vector3(30.0, 3.5, 31.0), Vector3(4.0, 1.0, 0.5), Color(0.22, 0.25, 0.28))
	
	# 3. Emissive lighting fixtures (cyan neon tubes)
	add_box_to_world(host, Vector3(22, 3.8, 15), Vector3(4, 0.1, 0.3), Color(0.15, 0.84, 1.0))
	add_box_to_world(host, Vector3(38, 3.8, 15), Vector3(4, 0.1, 0.3), Color(0.15, 0.84, 1.0))
	add_box_to_world(host, Vector3(30, 3.8, 8), Vector3(0.3, 0.1, 4), Color(0.15, 0.84, 1.0))
	add_box_to_world(host, Vector3(30, 3.8, 22), Vector3(0.3, 0.1, 4), Color(0.15, 0.84, 1.0))
	
	# --- Wing A (Left wall): Characters, Droids & NPCs (x = 18.0) ---
	add_label(host, Vector3(18.0, 2.2, 16.0), "WING A: Characters & Rigs")
	_add_library_display(
		host, Vector3(18.0, 0.0, 4.0), 
		"Clone Commander Display", 
		"Clone Commander (High Fidelity) Standing Rig. Press 'E' to cycle anims (Walk/Aim/Neutral). Built from clone_commander.json.", 
		"clone_commander", 
		"res://assets/3d/generated/google/clone_commander_v1/clone_commander_actor.tscn"
	)
	_add_library_display(
		host, Vector3(18.0, 0.0, 8.0), 
		"B1 Droid Target Display", 
		"Rigged B1 Battle Droid remote display. Press 'E' to trigger 'aim' and fire a red laser blaster beam!", 
		"b1_droid", 
		"res://assets/3d/generated/google/droid_b1_character_v1/droid_b1_actor.tscn"
	)
	_add_library_display(
		host, Vector3(18.0, 0.0, 12.0), 
		"Wookiee NPC Display", 
		"Tall Wookiee (High Fidelity) Standing Rig representing Chalmun. Press 'E' to cycle anims (Walk/Aim/Neutral). Built from wookiee.json.", 
		"wookiee", 
		"res://assets/3d/generated/google/wookiee_v1/wookiee_actor.tscn"
	)
	_add_library_display(
		host, Vector3(18.0, 0.0, 16.0), 
		"Jawa NPC Display", 
		"Short Jawa (High Fidelity) Standing Rig representing Ruzz-tha. Press 'E' to cycle anims (Walk/Aim/Neutral). Built from jawa.json.", 
		"jawa", 
		"res://assets/3d/generated/google/jawa_v1/jawa_actor.tscn"
	)
	_add_library_display(
		host, Vector3(18.0, 0.0, 20.0), 
		"Weequay NPC Display", 
		"Weequay (High Fidelity) Standing Rig representing Greeshk/Guard. Press 'E' to cycle anims (Walk/Aim/Neutral). Built from weequay.json.", 
		"weequay", 
		"res://assets/3d/generated/google/weequay_v1/weequay_actor.tscn"
	)
	_add_library_display(
		host, Vector3(18.0, 0.0, 24.0), 
		"Abyssinian NPC Display", 
		"Abyssinian (High Fidelity) Standing Rig representing Djas Puhr. Press 'E' to cycle anims (Walk/Aim/Neutral). Built from abyssinian.json.", 
		"abyssinian", 
		"res://assets/3d/generated/google/abyssinian_v1/abyssinian_actor.tscn"
	)
	_add_library_display(
		host, Vector3(18.0, 0.0, 28.0), 
		"Republic Officer Display", 
		"Republic Officer (High Fidelity) Standing Rig representing Vesh Talon. Press 'E' to cycle anims (Walk/Aim/Neutral). Built from republic_officer.json.", 
		"republic_officer", 
		"res://assets/3d/generated/google/republic_officer_v1/republic_officer_actor.tscn"
	)

	
	# --- Wing B (Right wall): Vehicles & Ships (x = 42.0) ---
	add_label(host, Vector3(42.0, 2.2, 15.0), "WING B: Vehicles & Ships")
	_add_library_display(
		host, Vector3(42.0, 0.0, 8.0), 
		"Kenney Speeder Craft", 
		"Curated space Speeder-A glider. Flat-shaded Kenney space-kit GLB model. Press 'E' to trigger hover-boost spin!", 
		"speeder", 
		""
	)
	_add_library_display(
		host, Vector3(42.0, 0.0, 15.0), 
		"Kenney Cargo Ship", 
		"Curated Cargo-A shuttle ship. Replaced with procedural blockout. Press 'E' to trigger hover-boost spin!", 
		"cargo", 
		""
	)
	_add_library_display(
		host, Vector3(42.0, 0.0, 22.0), 
		"Kenney Miner Craft", 
		"Curated Miner transport shuttle. Replaced with procedural blockout. Press 'E' to trigger hover-boost spin!", 
		"miner", 
		""
	)
	
	# --- Wing C (Back wall): modular Buildings & Props (z = 3.0) ---
	add_label(host, Vector3(31.0, 2.2, 3.0), "WING C: Modular Buildings & Props")
	_add_library_display(
		host, Vector3(22.0, 0.0, 3.0), 
		"Voxel Cantina Table Prop", 
		"Custom voxel cantina table tabletop. Central metal post with tiny cyan cup. Press 'E' to inspect.", 
		"table", 
		""
	)
	_add_library_display(
		host, Vector3(25.0, 0.0, 3.0), 
		"Voxel Cantina Bar Counter", 
		"Modular bar counter decorator. Side trims and beverage taps. Press 'E' to inspect.", 
		"bar", 
		""
	)
	_add_library_display(
		host, Vector3(28.0, 0.0, 3.0), 
		"Desert Doorway model", 
		"Rounded desert adobe doorway frame with custom texturing noise. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/buildings/desert_doorway.tscn"
	)
	_add_library_display(
		host, Vector3(31.0, 0.0, 3.0), 
		"Moisture Vaporator model", 
		"Desert moisture vaporator tower with cooling fins and glowing status light. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/buildings/moisture_vaporator.tscn"
	)
	_add_library_display(
		host, Vector3(34.0, 0.0, 3.0), 
		"Dome Cap model", 
		"Curved adobe roof dome cap for modular building construction. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/buildings/dome_cap.tscn"
	)
	_add_library_display(
		host, Vector3(37.0, 0.0, 3.0), 
		"Combat Barricade model", 
		"Sturdy concrete barricade cover block with yellow/black hazard striping. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/buildings/combat_barricade.tscn"
	)
	_add_library_display(
		host, Vector3(40.0, 0.0, 3.0), 
		"Landing Pad Light model", 
		"Landing pad boundary warning post with glowing yellow beacon light. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/buildings/landing_pad_light.tscn"
	)
	
	# --- Wing D (Center Island): Weapons & Gear (z = 16.0) ---
	add_label(host, Vector3(30.0, 2.2, 16.0), "WING D: Weapons & Gear")
	_add_library_display(
		host, Vector3(24.0, 0.0, 16.0), 
		"Blaster Pistol model", 
		"Chunky voxel sidearm blaster pistol with custom texturing. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/weapons/blaster_pistol.tscn"
	)
	_add_library_display(
		host, Vector3(27.0, 0.0, 16.0), 
		"Blaster Rifle model", 
		"Standard military blaster rifle longarm with scope and wooden stock. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/weapons/blaster_rifle.tscn"
	)
	_add_library_display(
		host, Vector3(30.0, 0.0, 16.0), 
		"Wookiee Bowcaster model", 
		"Wookiee bowcaster crossbow frame with front dual magnetic spheres. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/weapons/bowcaster.tscn"
	)
	_add_library_display(
		host, Vector3(33.0, 0.0, 16.0), 
		"Lightsaber model", 
		"Voxel lightsaber hilt with custom emissive glowing cyan energy blade. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/weapons/lightsaber.tscn"
	)
	_add_library_display(
		host, Vector3(36.0, 0.0, 16.0), 
		"Thermal Detonator model", 
		"Textured weathered grey sphere with glowing red activation button. Press 'E' to inspect.", 
		"prop", 
		"res://assets/3d/generated/google/weapons/thermal_detonator.tscn"
	)



func _add_library_display(host: Node3D, pos: Vector3, title: String, desc: String, type: String, model_path: String) -> void:
	# 1. Spawn Pedestal Box
	var pedestal_color := Color(0.24, 0.28, 0.31)
	add_box_to_world(host, pos + Vector3(0, 0.4, 0), Vector3(1.1, 0.8, 1.1), pedestal_color)
	
	# 2. Spawn Inspectable Interactive Marker (Collision Body + custom script)
	var body := StaticBody3D.new()
	body.name = "LibraryDisplay_%s" % title.replace(" ", "_")
	body.position = pos + Vector3(0, 0.4, 0)
	body.set_meta("inspectable", true)
	body.set_meta("title", title)
	body.set_meta("description", desc)
	body.set_script(load("res://scripts/world/voxel_library_display.gd"))
	body.display_type = type
	host.add_child(body)
	
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 2.0, 1.2)
	collision.shape = shape
	body.add_child(collision)
	
	# 3. Instantiate the Model
	if model_path != "":
		if ResourceLoader.exists(model_path):
			var model: Node3D = load(model_path).instantiate()
			model.name = "model"
			model.position = Vector3(0, 0.65, 0) # Offset above pedestal
			body.add_child(model)
			body.target_node = model
			
			# If B1 Droid, spawn the laser beam!
			if type == "b1_droid":
				var beam := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.03
				cyl.bottom_radius = 0.03
				cyl.height = 7.0
				beam.mesh = cyl
				
				# Rotate cylinder so it points forward along -Z axis
				beam.rotation_degrees = Vector3(90, 0, 0)
				beam.position = Vector3(0, 0.35, -3.8) # Position in front of blaster barrel
				
				# Emissive red laser material
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(1, 0.1, 0.1)
				mat.emission_enabled = true
				mat.emission = Color(1, 0.1, 0.1)
				mat.emission_energy_multiplier = 4.0
				beam.material_override = mat
				beam.visible = false
				
				body.add_child(beam)
				body.laser_beam = beam
				
	# If Table or Bar prop, build them programmatically
	elif type == "table":
		var table_holder := Node3D.new()
		table_holder.position = Vector3(0, 0.4, 0)
		body.add_child(table_holder)
		# Central metal post
		add_box(table_holder, Vector3(0, 0.2, 0), Vector3(0.18, 0.4, 0.18), Color(0.42, 0.46, 0.5))
		# Circular tabletop slab
		add_box(table_holder, Vector3(0, 0.42, 0), Vector3(0.9, 0.06, 0.9), Color(0.18, 0.21, 0.24))
		# Glowing cyan cup
		add_box(table_holder, Vector3(0.2, 0.48, 0.1), Vector3(0.08, 0.08, 0.08), Color(0.15, 0.84, 1.0))
		body.target_node = table_holder
		
	elif type == "cargo":
		var ship_holder := Node3D.new()
		ship_holder.position = Vector3(0, 0.4, 0)
		body.add_child(ship_holder)
		_add_procedural_cargo_ship(ship_holder, Vector3.ZERO, 0)
	elif type == "speeder":
		var ship_holder := Node3D.new()
		ship_holder.position = Vector3(0, 0.4, 0)
		body.add_child(ship_holder)
		_add_procedural_speeder(ship_holder, Vector3.ZERO, 0)
	elif type == "miner":
		var ship_holder := Node3D.new()
		ship_holder.position = Vector3(0, 0.4, 0)
		body.add_child(ship_holder)
		_add_procedural_miner(ship_holder, Vector3.ZERO, 0)
		
	elif type == "bar":
		var bar_holder := Node3D.new()
		bar_holder.position = Vector3(0, 0.4, 0)
		body.add_child(bar_holder)
		# Counter base
		add_box(bar_holder, Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.45), Color(0.22, 0.25, 0.28))
		# Counter top trim plate
		add_box(bar_holder, Vector3(0, 0.62, 0), Vector3(0.94, 0.04, 0.48), Color(0.68, 0.57, 0.42))
		# Service taps
		add_box(bar_holder, Vector3(0.1, 0.72, -0.05), Vector3(0.06, 0.16, 0.06), Color(0.5, 0.55, 0.6))
		add_box(bar_holder, Vector3(0.15, 0.8, -0.05), Vector3(0.12, 0.04, 0.06), Color(0.5, 0.55, 0.6))
		body.target_node = bar_holder
		
	elif type == "crate":
		# Add a barrel beside the crate
		add_box(body, Vector3(0.42, 0.5, 0.0), Vector3(0.6, 1.0, 0.6), Color(0.4, 0.45, 0.5))
