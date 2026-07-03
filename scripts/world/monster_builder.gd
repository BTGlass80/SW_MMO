extends RefCounted
## Procedural low-poly builder for combat *targets* — the thing the player is
## fighting. Same blocky art language as scripts/world/world_builder.gd (BoxMesh +
## StandardMaterial3D, no textures), but scoped to living targets rather than the
## settlement geometry.
##
## Pure construction: build_target() returns a fresh, unparented Node3D tree that the
## caller (scripts/net/net_world.gd) adds into the world and positions. No gameplay
## state, no input, no autoloads — so it is headlessly unit-testable.
##
##   kind == "remote"  -> the shared training dummy (a hovering B1 target remote)
##   kind == "monster" -> a hostile creature, TINTED + SCALED deterministically by name
##                        (so a "Womp Rat" reads small/brown and a "Krayt Dragon" large/green)

# Name keywords that bias a beast SMALL (vermin) or LARGE (megafauna). Deterministic size.
const SMALL_WORDS := ["rat", "mynock", "scurrier", "womp", "vole", "squill", "gnat", "worrt"]
const LARGE_WORDS := ["bantha", "krayt", "rancor", "dragon", "dewback", "reek", "wampa", "sarlacc", "acklay"]
const REPTILE_WORDS := ["dragon", "krayt", "lizard", "reptile", "dewback", "greel", "gank"]
const SAND_WORDS := ["rat", "bantha", "dewback", "tusk", "sand", "worrt", "massiff"]

# --- entry point ---
func build_target(kind: String, display_name: String) -> Node3D:
	match kind:
		"remote":
			return build_training_remote(display_name)
		_:
			return build_beast(display_name)

# The training dummy: a floating spherical target remote (the "B1 Training Remote" the
# server names it). Metallic, symmetric — reads clearly as a droid, not a beast.
func build_training_remote(display_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "TrainingRemote"
	var body_col := Color(0.62, 0.63, 0.66)

	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	sphere.mesh = sm
	sphere.position = Vector3(0.0, 1.3, 0.0)
	var mat := make_material(body_col, 0.35)
	mat.metallic = 0.6
	sphere.material_override = mat
	root.add_child(sphere)

	# Front sensor "eye" (points -Z, the facing the caller aims at the player).
	add_box(root, Vector3(0.0, 1.3, -0.27), Vector3(0.16, 0.12, 0.08), Color(0.08, 0.05, 0.05))
	# Three little blaster-nub emitters around the equator.
	for a in [0.0, 120.0, 240.0]:
		var rad := deg_to_rad(a)
		add_box(root, Vector3(sin(rad) * 0.3, 1.3, cos(rad) * 0.3), Vector3(0.09, 0.09, 0.12), Color(0.30, 0.30, 0.33))

	_nameplate(root, display_name if display_name != "" else "B1 Training Remote", 1.75, Color(0.14, 0.12, 0.28))
	return root

# A hostile creature: a low-poly blocky quadruped, tinted + scaled from its NAME so
# each species reads distinct without any per-creature art. Faces -Z (the caller
# look_at()s it toward the player, so the head ends up pointing at them).
func build_beast(display_name: String) -> Node3D:
	var look := beast_appearance(display_name)
	var s: float = look["scale"]
	var body_col: Color = look["color"]
	var limb_col := body_col.darkened(0.24)

	var root := Node3D.new()
	root.name = "Beast"
	# Torso + shoulders.
	add_box(root, Vector3(0.0, 0.62 * s, 0.0), Vector3(0.8 * s, 0.7 * s, 1.5 * s), body_col)
	add_box(root, Vector3(0.0, 0.80 * s, 0.45 * s), Vector3(0.95 * s, 0.72 * s, 0.7 * s), body_col.lightened(0.05))
	# Neck + head at the front (-Z).
	add_box(root, Vector3(0.0, 0.88 * s, -0.85 * s), Vector3(0.5 * s, 0.45 * s, 0.5 * s), body_col)
	add_box(root, Vector3(0.0, 1.02 * s, -1.18 * s), Vector3(0.55 * s, 0.5 * s, 0.6 * s), body_col.lightened(0.08))
	# Eyes.
	add_box(root, Vector3(-0.16 * s, 1.10 * s, -1.45 * s), Vector3(0.1 * s, 0.1 * s, 0.08 * s), Color(0.05, 0.04, 0.03))
	add_box(root, Vector3(0.16 * s, 1.10 * s, -1.45 * s), Vector3(0.1 * s, 0.1 * s, 0.08 * s), Color(0.05, 0.04, 0.03))
	# Four legs (span ground .. torso).
	for lx in [-0.3 * s, 0.3 * s]:
		for lz in [-0.55 * s, 0.6 * s]:
			add_box(root, Vector3(lx, 0.31 * s, lz), Vector3(0.18 * s, 0.62 * s, 0.2 * s), limb_col)
	# Tail (+Z).
	add_box(root, Vector3(0.0, 0.72 * s, 0.95 * s), Vector3(0.2 * s, 0.2 * s, 0.6 * s), limb_col)

	_nameplate(root, display_name if display_name != "" else "Creature", 1.55 * s + 0.35, Color(0.5, 0.12, 0.1))
	return root

# Deterministic appearance for a creature name -> {"scale", "color", "hue"}. Vermin read
# small, megafauna large; reptilian names skew green, desert fauna tan; everything else
# gets a stable hashed hue so distinct creatures still look distinct.
func beast_appearance(display_name: String) -> Dictionary:
	var lname := display_name.to_lower()
	var h := absi(hash(display_name))
	var hue := fposmod(float(h) * 0.6180339887, 1.0)
	var sat := 0.34
	var val := 0.52
	var scale := 1.0
	if _contains_any(lname, SMALL_WORDS):
		scale = 0.72
	elif _contains_any(lname, LARGE_WORDS):
		scale = 1.7
	else:
		scale = 0.9 + fposmod(float(h) * 0.001, 0.6)  # 0.9 .. 1.5
	if _contains_any(lname, REPTILE_WORDS):
		hue = 0.30
		sat = 0.34
	elif _contains_any(lname, SAND_WORDS):
		hue = 0.09
		sat = 0.30
	return {"scale": scale, "color": Color.from_hsv(hue, sat, val), "hue": hue}

# --- primitives (mesh-only; combat targets need no collision) ---
func add_box(parent: Node3D, local_pos: Vector3, size: Vector3, color: Color, roughness: float = 0.9) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.material_override = make_material(color, roughness)
	parent.add_child(mesh_instance)
	return mesh_instance

func make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _nameplate(root: Node3D, text: String, y: float, color: Color) -> void:
	var label := Label3D.new()
	label.name = "Nameplate"
	label.text = text
	label.position = Vector3(0.0, y, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 26
	label.modulate = color
	root.add_child(label)

func _contains_any(s: String, keys: Array) -> bool:
	for k in keys:
		if s.contains(String(k)):
			return true
	return false
