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
const CombatArena := preload("res://scripts/net/combat_arena.gd")
const PersistenceStore := preload("res://scripts/net/persistence_store.gd")
const COMBATANT_DATA_PATH := "res://data/prototype_combatants.json"

const DEFAULT_PORT := 24555
const MAX_CLIENTS := 32
const SERVER_TICK_HZ := 20
const CLIENT_SEND_HZ := 20
const COMBAT_WINDOW_SECONDS := 5.0
const AUTOSAVE_SECONDS := 30.0

enum Mode { NONE, SERVER, CLIENT }

signal server_started(port: int)
signal client_connected()
signal client_failed()
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal snapshot_applied(snapshot: Dictionary)
signal combat_envelope(envelope: Dictionary)

var mode: int = Mode.NONE
var state: WorldState = null          # server only
var arena: CombatArena = null         # server only
var store: PersistenceStore = null    # server only
var combat_window_seconds: float = COMBAT_WINDOW_SECONDS
var last_snapshot: Dictionary = {}    # client view of the world
var connected: bool = false           # client: handshake complete

var _server_accum := 0.0
var _client_accum := 0.0
var _combat_accum := 0.0
var _autosave_accum := 0.0
var _peer_characters := {}            # peer_id -> character_id (server)
var _server_rng := RandomNumberGenerator.new()
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
	arena = CombatArena.new(D6Rules, _load_combat_data())
	store = PersistenceStore.new("user://persistence")
	_server_rng.randomize()
	print("[net] server listening on port %d (combat window %.1fs)" % [port, combat_window_seconds])
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
	if arena != null:
		arena.register_player(id)
	print("[net] peer %d joined (players=%d)" % [id, state.player_count()])
	player_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	if mode != Mode.SERVER:
		return
	_save_peer(id)
	state.remove_player(id)
	if arena != null:
		arena.remove_player(id)
	_peer_characters.erase(id)
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

# client -> server: a fire intent for the current combat window
@rpc("any_peer", "call_remote", "reliable")
func submit_fire_intent(intent: Dictionary) -> void:
	if mode != Mode.SERVER or arena == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if arena.has_player(sender):
		arena.submit_fire_intent(sender, intent)

# server -> clients: a resolved WEG combat exchange envelope
@rpc("authority", "call_remote", "reliable")
func apply_combat_envelope(envelope: Dictionary) -> void:
	combat_envelope.emit(envelope)

func send_fire_intent(intent: Dictionary) -> void:
	if mode == Mode.CLIENT and connected:
		submit_fire_intent.rpc_id(1, intent)

# client -> server: identify which character to load/persist for this peer, and the
# chosen display name (empty keeps the saved/default name)
@rpc("any_peer", "call_remote", "reliable")
func register_account(account_id: String, display_name: String = "") -> void:
	if mode != Mode.SERVER or store == null or state == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not state.has_player(sender):
		return
	var character_id := account_id.strip_edges()
	if character_id == "":
		character_id = "peer_%d" % sender
	_peer_characters[sender] = character_id
	var existing := state.get_player(sender)
	var record := store.load_record(character_id)
	var chosen_name := display_name.strip_edges()
	if chosen_name == "":
		chosen_name = String(record.get("name", existing.get("name", "")))
	if record.is_empty():
		record = store.default_record(character_id, character_id, chosen_name, WorldState.SPAWN_POINT)
	else:
		record["name"] = chosen_name
	var pos := PersistenceStore.record_pos(record, WorldState.SPAWN_POINT)
	var yaw := PersistenceStore.record_yaw(record, 0.0)
	state.restore_player(sender, pos, yaw, chosen_name)
	if arena != null:
		arena.set_player_combat(sender, PersistenceStore.combat_from_record(record))
		arena.set_player_name(sender, chosen_name)
	print("[persist] peer %d -> %s (%s) loaded at (%.1f, %.1f, %.1f)" % [sender, character_id, chosen_name, pos.x, pos.y, pos.z])

func send_register(account_id: String, display_name: String = "") -> void:
	if mode == Mode.CLIENT and connected:
		register_account.rpc_id(1, account_id, display_name)

func _physics_process(delta: float) -> void:
	match mode:
		Mode.SERVER:
			var step := 1.0 / float(SERVER_TICK_HZ)
			_server_accum += delta
			while _server_accum >= step:
				state.tick(step)
				_server_accum -= step
			apply_snapshot.rpc(state.snapshot())
			_combat_accum += delta
			if _combat_accum >= combat_window_seconds:
				_combat_accum = 0.0
				_resolve_combat_window()
			_autosave_accum += delta
			if _autosave_accum >= AUTOSAVE_SECONDS:
				_autosave_accum = 0.0
				for pid in _peer_characters.keys():
					_save_peer(pid)
		Mode.CLIENT:
			if not connected:
				return
			_client_accum += delta
			var step := 1.0 / float(CLIENT_SEND_HZ)
			if _client_accum >= step:
				_client_accum = 0.0
				submit_input.rpc_id(1, _local_move, _local_yaw, _local_jump)

func _load_combat_data() -> Dictionary:
	if not FileAccess.file_exists(COMBATANT_DATA_PATH):
		return {}
	var file := FileAccess.open(COMBATANT_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _resolve_combat_window() -> void:
	if arena == null or arena.pending_intent_count() == 0:
		return
	var result := arena.resolve_window(_server_rng.randi())
	var envelopes: Array = result.get("envelopes", [])
	for envelope in envelopes:
		apply_combat_envelope.rpc(envelope)
	print("[combat] window %d resolved: %d shot(s), target severity %d" % [
		int(result.get("window", 0)),
		envelopes.size(),
		int((result.get("target_state", {}) as Dictionary).get("wound_severity", 0)),
	])
	if bool(result.get("target_disabled", false)):
		arena.reset_target()
		print("[combat] target disabled — respawned")

func _save_peer(peer_id: int) -> void:
	if store == null or state == null:
		return
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var player := state.get_player(peer_id)
	if player.is_empty():
		return
	var record := store.load_or_create(character_id, character_id, String(player.get("name", "")), WorldState.SPAWN_POINT)
	record = PersistenceStore.apply_position(record, player.get("pos", WorldState.SPAWN_POINT), float(player.get("yaw", 0.0)))
	if arena != null:
		record = PersistenceStore.apply_combat(record, arena.player_state(peer_id))
	record["name"] = String(player.get("name", ""))
	store.save_record(character_id, record)
