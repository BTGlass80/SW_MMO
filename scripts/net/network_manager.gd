extends Node
## Server-authoritative networking core for the SW MMO foundation.
##
## A dedicated (or listen) server owns the WorldState and, later, RNG seeds and
## combat resolution. Clients send input INTENTS and render authoritative
## snapshots; they never own position truth. We use explicit RPCs rather than
## scene replication so the authority/anti-cheat story stays simple and maps
## directly onto action-window combat (client sends a fire intent -> server
## resolves a WEG D6 window with a server-owned seed -> broadcasts an envelope).
##
## Registered as the `Net` autoload. In the solo slice (main.tscn) it stays in
## Mode.NONE and does nothing.

const WorldState := preload("res://scripts/net/world_state.gd")

const DEFAULT_PORT := 24555
const MAX_CLIENTS := 32
const SERVER_TICK_HZ := 20
const CLIENT_SEND_HZ := 20

enum Mode { NONE, SERVER, CLIENT }

signal server_started(port: int)
signal client_connected()
signal client_failed()
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal snapshot_applied(snapshot: Dictionary)

var mode: int = Mode.NONE
var state: WorldState = null          # server only
var last_snapshot: Dictionary = {}    # client view of the world
var connected: bool = false           # client: handshake complete

var _server_accum := 0.0
var _client_accum := 0.0
var _local_move := Vector2.ZERO
var _local_yaw := 0.0
var _local_jump := false

func _ready() -> void:
	set_physics_process(true)

func start_server(port: int = DEFAULT_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("[net] failed to create server on port %d (err %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.SERVER
	state = WorldState.new()
	print("[net] server listening on port %d" % port)
	server_started.emit(port)
	return OK

func start_client(host: String = "127.0.0.1", port: int = DEFAULT_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		push_error("[net] failed to create client to %s:%d (err %d)" % [host, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	mode = Mode.CLIENT
	connected = false
	print("[net] client connecting to %s:%d" % [host, port])
	return OK

func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	mode = Mode.NONE
	state = null
	last_snapshot = {}
	connected = false

func local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()

## Called by the client view each frame with the local input intent.
func set_local_input(move: Vector2, yaw: float, jump: bool = false) -> void:
	_local_move = move
	_local_yaw = yaw
	_local_jump = jump

# --- server signal handlers ---
func _on_peer_connected(id: int) -> void:
	if mode != Mode.SERVER:
		return
	state.add_player(id)
	print("[net] peer %d joined (players=%d)" % [id, state.player_count()])
	player_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	if mode != Mode.SERVER:
		return
	state.remove_player(id)
	print("[net] peer %d left (players=%d)" % [id, state.player_count()])
	player_left.emit(id)

# --- client signal handlers ---
func _on_connected() -> void:
	connected = true
	print("[net] connected to server as peer %d" % local_peer_id())
	client_connected.emit()

func _on_connection_failed() -> void:
	print("[net] connection failed")
	mode = Mode.NONE
	connected = false
	client_failed.emit()

func _on_server_disconnected() -> void:
	print("[net] server disconnected")
	mode = Mode.NONE
	connected = false

# --- RPCs ---
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(move: Vector2, yaw: float, jump: bool) -> void:
	if mode != Mode.SERVER or state == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if state.has_player(sender):
		state.set_input(sender, move, yaw, jump)

@rpc("authority", "call_remote", "unreliable_ordered")
func apply_snapshot(snapshot: Dictionary) -> void:
	last_snapshot = snapshot
	snapshot_applied.emit(snapshot)

func _physics_process(delta: float) -> void:
	match mode:
		Mode.SERVER:
			var step := 1.0 / float(SERVER_TICK_HZ)
			_server_accum += delta
			while _server_accum >= step:
				state.tick(step)
				_server_accum -= step
			apply_snapshot.rpc(state.snapshot())
		Mode.CLIENT:
			if not connected:
				return
			_client_accum += delta
			var step := 1.0 / float(CLIENT_SEND_HZ)
			if _client_accum >= step:
				_client_accum = 0.0
				submit_input.rpc_id(1, _local_move, _local_yaw, _local_jump)
