extends Node3D
## Networked world entry point (the first shared-world slice).
##
## Reads cmdline user args (after `--`):
##   --server            run as a dedicated, headless, authoritative server
##   --connect <host>    run as a client connecting to <host> (default 127.0.0.1)
## With no args it defaults to a client connecting to 127.0.0.1 (handy in-editor).
##
## The server owns positions; this view only renders the authoritative snapshots
## and forwards the local player's input intent. Geometry here is intentionally
## a minimal shared ground for the netcode milestone; the full shared Mos Eisley
## (extracted from main.gd into a reusable world_builder) is the next slice.

const MOUSE_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.55
const WorldBuilder := preload("res://scripts/world/world_builder.gd")

var _builder: WorldBuilder
var _is_server := false
var _connect_attempts := 0
var _local_id := 0
var _yaw := 0.0
var _pitch := -0.18
var _camera: Camera3D
var _status: Label
var _snapshots_logged := 0
var _avatars: Dictionary = {}   # peer_id -> {"root": Node3D, "seen": bool}

func _ready() -> void:
	_parse_args()

	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.snapshot_applied.connect(_on_snapshot)
	Net.client_connected.connect(_on_client_connected)
	Net.client_failed.connect(_on_client_failed)

	if _is_server:
		Net.start_server()
		return

	_builder = WorldBuilder.new()
	_builder.build_lighting(self)
	_builder.build_ground(self)
	_builder.build_settlement(self)
	_build_camera()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Net.start_client(_resolve_host())

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	_is_server = args.has("--server")

func _resolve_host() -> String:
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--connect")
	if idx >= 0 and idx + 1 < args.size():
		return args[idx + 1]
	return "127.0.0.1"

func _process(_delta: float) -> void:
	if _is_server:
		return
	_send_local_input()
	_update_camera()

# --- input / camera (client only) ---
func _send_local_input() -> void:
	var move := Vector2.ZERO
	move.y -= 1.0 if Input.is_key_pressed(KEY_W) else 0.0
	move.y += 1.0 if Input.is_key_pressed(KEY_S) else 0.0
	move.x -= 1.0 if Input.is_key_pressed(KEY_A) else 0.0
	move.x += 1.0 if Input.is_key_pressed(KEY_D) else 0.0
	if move.length() > 1.0:
		move = move.normalized()
	Net.set_local_input(move, _yaw, Input.is_key_pressed(KEY_SPACE))

func _input(event: InputEvent) -> void:
	if _is_server:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.25, 0.8)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_camera() -> void:
	if _camera == null or _local_id == 0:
		return
	var me := _find_player(_local_id)
	if me.is_empty():
		return
	var pos: Vector3 = me.get("pos", Vector3.ZERO)
	_camera.global_position = pos + Vector3(0.0, EYE_HEIGHT, 0.0)
	_camera.basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)

# --- net signal handlers ---
func _on_client_connected() -> void:
	_local_id = Net.local_peer_id()
	_set_status("Connected as peer %d." % _local_id)

func _on_client_failed() -> void:
	_connect_attempts += 1
	if _connect_attempts <= 5:
		_set_status("Connect failed; retry %d/5..." % _connect_attempts)
		Net.start_client(_resolve_host())
	else:
		_set_status("Could not reach server.")

func _on_player_joined(_peer_id: int) -> void:
	pass

func _on_player_left(peer_id: int) -> void:
	if _avatars.has(peer_id):
		(_avatars[peer_id]["root"] as Node3D).queue_free()
		_avatars.erase(peer_id)

func _on_snapshot(snapshot: Dictionary) -> void:
	if _snapshots_logged < 2:
		_snapshots_logged += 1
		print("[net] client received snapshot tick=%d players=%d" % [
			int(snapshot.get("tick", -1)),
			(snapshot.get("players", []) as Array).size(),
		])
	if _is_server:
		return
	var seen := {}
	for entry in snapshot.get("players", []):
		var id := int(entry.get("id", 0))
		seen[id] = true
		var pos: Vector3 = entry.get("pos", Vector3.ZERO)
		if not _avatars.has(id):
			_avatars[id] = {"root": _spawn_avatar(id, String(entry.get("name", ""))), "seen": false}
		var record: Dictionary = _avatars[id]
		var root := record["root"] as Node3D
		# First person: hide our own capsule.
		root.visible = id != _local_id
		if record["seen"]:
			root.global_position = root.global_position.lerp(pos, 0.5)
		else:
			root.global_position = pos
			record["seen"] = true
	for id in _avatars.keys():
		if not seen.has(id):
			(_avatars[id]["root"] as Node3D).queue_free()
			_avatars.erase(id)
	_set_status("Peer %d | players online: %d" % [_local_id, (snapshot.get("players", []) as Array).size()])

func _find_player(peer_id: int) -> Dictionary:
	for entry in Net.last_snapshot.get("players", []):
		if int(entry.get("id", 0)) == peer_id:
			return entry
	return {}

# --- scene building (client only) ---
func _spawn_avatar(peer_id: int, display_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Avatar_%d" % peer_id

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	mesh.mesh = capsule
	mesh.position.y = 0.85
	var material := StandardMaterial3D.new()
	material.albedo_color = _color_for_peer(peer_id)
	material.roughness = 0.88
	mesh.material_override = material
	root.add_child(mesh)

	var label := Label3D.new()
	label.text = display_name if display_name != "" else "Spacer-%d" % peer_id
	label.position.y = 2.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.modulate = Color(0.09, 0.08, 0.06)
	root.add_child(label)

	add_child(root)
	return root

func _color_for_peer(peer_id: int) -> Color:
	var hue := fposmod(float(peer_id) * 0.6180339887, 1.0)
	return Color.from_hsv(hue, 0.55, 0.72)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 74
	_camera.current = true
	_camera.global_position = Vector3(-20, 1.75, -6)
	add_child(_camera)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(18, 16)
	_status.text = "Connecting..."
	_status.add_theme_font_size_override("font_size", 17)
	_status.modulate = Color(0.09, 0.08, 0.06)
	layer.add_child(_status)

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
