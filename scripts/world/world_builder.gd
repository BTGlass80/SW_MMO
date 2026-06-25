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

func _init(seed_value: int = 1138) -> void:
	_rng.seed = seed_value
	_load_rooms()

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
	shape.size = Vector3(120, 1, 120)
	collision.shape = shape
	collision.position.y = -0.55
	ground.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(120, 1, 120)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.55
	mesh_instance.material_override = make_material(Color(0.68, 0.57, 0.42), 0.95)
	ground.add_child(mesh_instance)

func build_settlement(host: Node3D) -> void:
	add_box_to_world(host, Vector3(3, 0.03, 0), Vector3(54, 0.08, 10), Color(0.53, 0.45, 0.34))
	add_box_to_world(host, Vector3(3, 0.09, -5.2), Vector3(54, 0.1, 0.35), Color(0.82, 0.63, 0.20))
	add_box_to_world(host, Vector3(3, 0.09, 5.2), Vector3(54, 0.1, 0.35), Color(0.82, 0.63, 0.20))
	add_label(host, Vector3(3, 2.4, 0), "Spaceport Row")

	_add_landing_pad(host, Vector3(-20, 0.02, -13))
	add_label(host, Vector3(-20, 2.0, -13), "Docking Bay 94")
	add_inspectable_marker(host, Vector3(-25.5, 1.3, -10.0), Vector3(1.2, 2.6, 7.0), _room_title("docking_bay_94_entrance", "Docking Bay 94"), _room_inspection("docking_bay_94_entrance", "Cracked steps drop into a scorched bay pit lined with loaders, fuel cells, and cargo cover."))
	_add_bay_94_details(host, Vector3(-20, 0, -13))

	_add_landing_pad(host, Vector3(14, 0.02, -12))
	add_label(host, Vector3(14, 2.0, -12), "Docking Bay 86")
	add_inspectable_marker(host, Vector3(14, 1.2, -7.5), Vector3(6, 2.4, 1.2), _room_title("docking_bay_86", "Docking Bay 86"), _room_inspection("docking_bay_86", "A practical small-craft bay with brusque admin droid service and little patience for loitering."))
	_add_landing_pad(host, Vector3(-16, 0.02, 14))
	add_label(host, Vector3(-16, 2.0, 14), "Docking Bay 87")
	add_inspectable_marker(host, Vector3(-16, 1.2, 8.5), Vector3(6, 2.4, 1.2), _room_title("docking_bay_87", "Docking Bay 87"), _room_inspection("docking_bay_87", "A modernized bay favored by smugglers, merchants, and anyone who prefers flexible inspections."))

	_add_hab_block(host, Vector3(-3, 0, 12), Vector3(7, 3, 5), Color(0.53, 0.47, 0.39))
	add_label(host, Vector3(-3, 3.7, 12), "Customs")
	add_inspectable_marker(host, Vector3(-3, 1.6, 8.9), Vector3(6, 3.2, 1.2), _room_title("spaceport_customs_office", "Spaceport Customs"), _room_inspection("spaceport_customs_office", "A dusty office where paperwork, confiscated goods, and quiet bribes all pile up."))
	_add_hab_block(host, Vector3(9, 0, 11), Vector3(8, 3, 5), Color(0.45, 0.45, 0.40))
	add_label(host, Vector3(9, 3.7, 11), "Transport Depot")
	add_inspectable_marker(host, Vector3(9, 1.6, 7.9), Vector3(7, 3.2, 1.2), _room_title("transport_depot", "Transport Depot"), _room_inspection("transport_depot", "Rows of uncomfortable passengers wait beside a cafe selling overpriced food and worse advice."))
	_add_hab_block(host, Vector3(9, 0, -20), Vector3(8, 3, 6), Color(0.49, 0.44, 0.36))
	add_label(host, Vector3(9, 3.7, -20), "Spaceport Speeders")
	add_inspectable_marker(host, Vector3(9, 1.6, -16.4), Vector3(7, 3.2, 1.2), _room_title("spaceport_speeders", "Spaceport Speeders"), _room_inspection("spaceport_speeders", "A cluttered speeder shop smelling of lubricant, ozone, and hard bargaining."))
	_add_tower(host, Vector3(-7, 0, -24), 8)
	add_label(host, Vector3(-7, 10.4, -24), "Control Tower")
	add_inspectable_marker(host, Vector3(-7, 4.5, -20.8), Vector3(4, 9, 1.2), _room_title("mos_eisley_control_tower", "Control Tower"), _room_inspection("mos_eisley_control_tower", "A tall observation module coordinates landings while trying to stay above the dust and noise."))

	# Parked low-poly craft on the docking bays (Bay 94 is left clear for the range).
	place_model(host, SHIP_CARGO, Vector3(14, 0.45, -12), 40.0, 2.4)
	place_model(host, SHIP_SPEEDER, Vector3(-16, 0.55, 14), -25.0, 2.2)
	place_model(host, SHIP_MINER, Vector3(4, 0.4, -19), 90.0, 1.8)

	# A little life: barrels by Customs and the Transport Depot.
	for spot in [Vector3(-6.5, 0, 9.6), Vector3(-5.6, 0, 9.9), Vector3(12.5, 0, 8.4), Vector3(13.2, 0, 8.0)]:
		place_model(host, BARREL_MODEL, spot, 0.0, BARREL_SCALE)

	for x in [-9, -3, 3, 15, 20]:
		_add_crate_stack(host, Vector3(x, 0, 6.8), _rng.randi_range(1, 3))

	# Additive data-driven set-dressing — loaded from mos_eisley_props.json.
	# No-op when the file is absent or malformed; never touches the hardcoded layout.
	_place_data_props(host)

func _add_bay_94_details(host: Node3D, center: Vector3) -> void:
	add_box_to_world(host, center + Vector3(0, -0.18, 0), Vector3(10, 0.18, 10), Color(0.24, 0.25, 0.25))
	add_box_to_world(host, center + Vector3(0, 0.42, 5.0), Vector3(4.5, 0.8, 0.45), Color(0.31, 0.28, 0.22))
	add_box_to_world(host, center + Vector3(-4.4, 0.6, -2.5), Vector3(1.2, 1.2, 1.2), Color(0.20, 0.21, 0.22))
	add_box_to_world(host, center + Vector3(4.2, 0.6, -2.9), Vector3(1.1, 1.2, 1.1), Color(0.20, 0.21, 0.22))
	add_box_to_world(host, center + Vector3(-2.8, 0.6, -4.2), Vector3(1.5, 1.2, 1.0), Color(0.35, 0.25, 0.16))
	add_box_to_world(host, center + Vector3(2.7, 0.6, -4.0), Vector3(1.5, 1.2, 1.0), Color(0.35, 0.25, 0.16))

## Load extra set-dressing props from PROPS_DATA_PATH and place them via place_model.
## Deterministic: iterates array in order, no RNG. Graceful no-op on missing/malformed file.
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
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	host.add_child(body)
	add_box(body, Vector3.ZERO, size, color)
	add_box(body, Vector3(0, size.y * 0.5 + 0.2, 0), Vector3(size.x + 0.8, 0.4, size.z + 0.8), color.darkened(0.16))
	add_box(body, Vector3(size.x * 0.3, 0.15, -size.z * 0.52), Vector3(1.5, 1.9, 0.18), Color(0.12, 0.11, 0.1))

func _add_tower(host: Node3D, pos: Vector3, height: int) -> void:
	for y in range(height):
		add_box_to_world(host, pos + Vector3(0, y + 0.5, 0), Vector3(3.2, 1, 3.2), Color(0.46, 0.45, 0.40).lightened(y * 0.015))
	add_box_to_world(host, pos + Vector3(0, height + 0.45, 0), Vector3(5.2, 0.9, 5.2), Color(0.30, 0.32, 0.32))
	add_box_to_world(host, pos + Vector3(0, height + 1.6, 0), Vector3(1.2, 1.8, 1.2), Color(0.18, 0.28, 0.32))

func _add_landing_pad(host: Node3D, pos: Vector3) -> void:
	add_box_to_world(host, pos, Vector3(14, 0.25, 14), Color(0.29, 0.31, 0.32))
	add_box_to_world(host, pos + Vector3(0, 0.18, 0), Vector3(10, 0.12, 10), Color(0.38, 0.39, 0.38))
	add_box_to_world(host, pos + Vector3(-4.8, 0.4, -4.8), Vector3(1, 0.8, 1), Color(0.83, 0.64, 0.18))
	add_box_to_world(host, pos + Vector3(4.8, 0.4, -4.8), Vector3(1, 0.8, 1), Color(0.83, 0.64, 0.18))
	add_box_to_world(host, pos + Vector3(-4.8, 0.4, 4.8), Vector3(1, 0.8, 1), Color(0.83, 0.64, 0.18))
	add_box_to_world(host, pos + Vector3(4.8, 0.4, 4.8), Vector3(1, 0.8, 1), Color(0.83, 0.64, 0.18))

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
		var model := instance_model(CRATE_MODEL)
		if model != null:
			model.position.y = -0.5  # base-origin model sits on the collision box floor
			model.scale = Vector3.ONE * CRATE_SCALE
			body.add_child(model)
		else:
			add_box(body, Vector3.ZERO, Vector3(1.0, 1.0, 1.0), Color(0.36, 0.25, 0.16))

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

## Place a low-poly model into the world (purely visual unless the caller adds its
## own collision). Returns the instance, or null if the model could not load.
func place_model(host: Node3D, model_path: String, pos: Vector3, rot_deg: float = 0.0, model_scale: float = 1.0) -> Node3D:
	var inst := instance_model(model_path)
	if inst == null:
		return null
	inst.position = pos
	inst.rotation_degrees.y = rot_deg
	inst.scale = Vector3.ONE * model_scale
	host.add_child(inst)
	return inst

func add_label(host: Node3D, pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.name = "Label_%s" % text.replace(" ", "_")
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.modulate = Color(0.09, 0.08, 0.06)
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
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

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
