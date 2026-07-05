extends RefCounted
## Pure, socket-free authoritative world state + movement simulation.
##
## The dedicated server owns one instance of this. NetworkManager wraps it with
## ENet + RPC, but all gameplay-affecting truth (positions, later: combat) lives
## here so it can be unit-tested headlessly with no networking, and so the server
## never trusts a client's self-reported position. Mirrors the project's existing
## model/controller split (pure logic in scripts/rules/*, presentation elsewhere).

const MOVE_SPEED := 6.5                       # matches PlayerController.SPEED
const HALF_BOUNDS := 58.0                      # settlement ground is 120x120; keep avatars on it
const SPAWN_POINT := Vector3(-20.0, 1.2, -4.0) # Docking Bay 94 firing line, matches solo slice
const GROUND_Y := 1.2

var players: Dictionary = {}   # peer_id:int -> player dict {id,name,pos,yaw,move,jump}
var tick_index: int = 0

const _world_obstacles := [
	# 1. Customs Building
	{"type": "box", "min_x": -6.5, "max_x": 0.5, "min_z": 9.5, "max_z": 14.5},
	# 2. Transport Depot
	{"type": "box", "min_x": 5.0, "max_x": 13.0, "min_z": 8.5, "max_z": 13.5},
	# 3. Spaceport Speeders
	{"type": "box", "min_x": 5.0, "max_x": 13.0, "min_z": -23.0, "max_z": -17.0},
	# 4. Control Tower
	{"type": "box", "min_x": -9.0, "max_x": -5.0, "min_z": -26.0, "max_z": -22.0},
	# 5. Parked Cargo Ship
	{"type": "box", "min_x": 11.0, "max_x": 17.0, "min_z": -15.0, "max_z": -9.0},
	# 6. Parked Speeder Craft
	{"type": "box", "min_x": -17.5, "max_x": -14.5, "min_z": 12.5, "max_z": 15.5},
	# 7. Parked Miner Ship
	{"type": "box", "min_x": 1.5, "max_x": 6.5, "min_z": -21.5, "max_z": -16.5},
	
	# 8. Moisture Vaporators (Cylinders with radius 0.8m)
	{"type": "cylinder", "center_x": -27.0, "center_z": 8.0, "radius_sq": 0.64},
	{"type": "cylinder", "center_x": 20.0, "center_z": -22.0, "radius_sq": 0.64},
	{"type": "cylinder", "center_x": -2.0, "center_z": -22.0, "radius_sq": 0.64},
	
	# 9. Combat Barricades (Boxes)
	{"type": "box", "min_x": -11.5, "max_x": -8.5, "min_z": 4.6, "max_z": 5.4},
	{"type": "box", "min_x": -0.5, "max_x": 2.5, "min_z": 4.6, "max_z": 5.4},
	{"type": "box", "min_x": 16.5, "max_x": 19.5, "min_z": 5.6, "max_z": 6.4},
	
	# 10. Street Crate Stacks (Boxes at Z = 6.8)
	{"type": "box", "min_x": -9.75, "max_x": -8.25, "min_z": 6.05, "max_z": 7.55},
	{"type": "box", "min_x": -3.75, "max_x": -2.25, "min_z": 6.05, "max_z": 7.55},
	{"type": "box", "min_x": 2.25, "max_x": 3.75, "min_z": 6.05, "max_z": 7.55},
	{"type": "box", "min_x": 14.25, "max_x": 15.75, "min_z": 6.05, "max_z": 7.55},
	{"type": "box", "min_x": 19.25, "max_x": 20.75, "min_z": 6.05, "max_z": 7.55},
]


func add_player(peer_id: int, display_name: String = "", spawn: Vector3 = SPAWN_POINT) -> Dictionary:
	var resolved_name := display_name if display_name != "" else "Spacer-%d" % peer_id
	var player := {
		"id": peer_id,
		"name": resolved_name,
		"pos": spawn,
		"yaw": 0.0,
		"move": Vector2.ZERO,
		"jump": false,
		"move_speed": MOVE_SPEED,  # DIV-0015: per-player, set from species at login (default = baseline)
	}
	players[peer_id] = player
	return player

func remove_player(peer_id: int) -> void:
	players.erase(peer_id)

func has_player(peer_id: int) -> bool:
	return players.has(peer_id)

func get_player(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

## Set a player's authoritative real-time movement speed (DIV-0015: derived from species
## at login). Clamped to a sane floor so a bad value can never freeze a player.
func set_move_speed(peer_id: int, speed: float) -> void:
	var player: Dictionary = players.get(peer_id, {})
	if player.is_empty():
		return
	player["move_speed"] = maxf(speed, 0.5)

## Snap a player to an authoritative restored position (from persistence on login).
func restore_player(peer_id: int, pos: Vector3, yaw: float, display_name: String = "") -> void:
	var player: Dictionary = players.get(peer_id, {})
	if player.is_empty():
		return
	player["pos"] = pos
	player["yaw"] = yaw
	if display_name != "":
		player["name"] = display_name

## Record a client's most recent input intent. The server applies it on the next
## tick; clients never move themselves authoritatively. `can_act` = false (an
## incapacitated / mortally wounded / dead character — see CombatArena.DISABLED_SEVERITY)
## zeroes movement + jump: an out character can't walk. yaw (look direction) still applies.
func set_input(peer_id: int, move: Vector2, yaw: float, jump: bool = false, can_act: bool = true) -> void:
	var player: Dictionary = players.get(peer_id, {})
	if player.is_empty():
		return
	var clamped := move if can_act else Vector2.ZERO
	if clamped.length() > 1.0:
		clamped = clamped.normalized()
	player["move"] = clamped
	player["yaw"] = yaw
	player["jump"] = jump and can_act

var _grids_loaded := false
var _main_bar_grid := {}
var _back_hallway_grid := {}

func _load_collision_grids() -> void:
	if _grids_loaded:
		return
	_grids_loaded = true
	_main_bar_grid = _load_json("res://assets/3d/generated/google/cantina_main_bar_v1/collision_grid.json")
	_back_hallway_grid = _load_json("res://assets/3d/generated/google/cantina_back_hallway_v1/collision_grid.json")

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var text := file.get_as_text()
		file.close()
		var parser := JSON.new()
		if parser.parse(text) == OK:
			if parser.data is Dictionary:
				return parser.data
	return {}

func is_blocked(pos: Vector3) -> bool:
	# Check center, 4 cardinal points, and 4 diagonal points at player capsule radius 0.36m
	var radius := 0.36
	var diag := radius * 0.7071
	
	if _is_point_blocked(pos):
		return true
	if _is_point_blocked(pos + Vector3(radius, 0.0, 0.0)):
		return true
	if _is_point_blocked(pos + Vector3(-radius, 0.0, 0.0)):
		return true
	if _is_point_blocked(pos + Vector3(0.0, 0.0, radius)):
		return true
	if _is_point_blocked(pos + Vector3(0.0, 0.0, -radius)):
		return true
	if _is_point_blocked(pos + Vector3(diag, 0.0, diag)):
		return true
	if _is_point_blocked(pos + Vector3(-diag, 0.0, diag)):
		return true
	if _is_point_blocked(pos + Vector3(diag, 0.0, -diag)):
		return true
	if _is_point_blocked(pos + Vector3(-diag, 0.0, -diag)):
		return true
	return false

func _is_point_blocked(pos: Vector3) -> bool:
	# 1. Check static world obstacles (buildings, props, barricades, crates outside cantina)
	for obs in _world_obstacles:
		var otype: String = obs.get("type", "")
		if otype == "box":
			if pos.x >= float(obs["min_x"]) and pos.x <= float(obs["max_x"]) and pos.z >= float(obs["min_z"]) and pos.z <= float(obs["max_z"]):
				return true
		elif otype == "cylinder":
			var dx: float = pos.x - float(obs["center_x"])
			var dz: float = pos.z - float(obs["center_z"])
			if (dx * dx + dz * dz) <= float(obs["radius_sq"]):
				return true

	# 2. Check outer cantina dome walls (centered at (65.0, 6.0), radius 29.5)
	# Only apply check when close to the dome wall (distance between 29.5 and 31.0 meters)
	var center := Vector2(65.0, 6.0)
	var player_p := Vector2(pos.x, pos.z)
	var dist := player_p.distance_to(center)
	if dist > 29.5 and dist < 31.0:
		# Allow crossing ONLY via the entrance doorway channel
		var in_doorway := pos.x >= 62.5 and pos.x <= 67.5 and pos.z >= 29.0 and pos.z <= 35.5
		if not in_doorway:
			return true

	# 3. Check voxel cantina rooms (Main Bar & Back Hallway)
	_load_collision_grids()
	
	# Check main bar grid (origin centered at X = 65.0, Z = 3.1)
	var rel_bar_x := pos.x - 65.0
	var rel_bar_z := pos.z - 3.1
	if _main_bar_grid.size() > 0:
		var cell_size: float = _main_bar_grid.get("cell_size", 0.8)
		var gw: int = _main_bar_grid.get("grid_width", 96)
		var gh: int = _main_bar_grid.get("grid_height", 96)
		var blockers: Array = _main_bar_grid.get("blockers", [])
		
		var gx := int(floor(rel_bar_x / cell_size + gw / 2.0))
		var gy := int(floor(rel_bar_z / cell_size + gh / 2.0))
		
		if gx >= 0 and gx < gw and gy >= 0 and gy < gh:
			var idx := gy * gw + gx
			if idx >= 0 and idx < blockers.size() and int(blockers[idx]) == 1:
				return true
				
	# Check back hallway grid (origin centered at X = 65.0, Z = -23.3)
	var rel_hall_x := pos.x - 65.0
	var rel_hall_z := pos.z - (-23.3)
	if _back_hallway_grid.size() > 0:
		var cell_size: float = _back_hallway_grid.get("cell_size", 0.8)
		var gw: int = _back_hallway_grid.get("grid_width", 96)
		var gh: int = _back_hallway_grid.get("grid_height", 96)
		var blockers: Array = _back_hallway_grid.get("blockers", [])
		
		var gx := int(floor(rel_hall_x / cell_size + gw / 2.0))
		var gy := int(floor(rel_hall_z / cell_size + gh / 2.0))
		
		if gx >= 0 and gx < gw and gy >= 0 and gy < gh:
			var idx := gy * gw + gx
			if idx >= 0 and idx < blockers.size() and int(blockers[idx]) == 1:
				return true

	return false




## Advance the authoritative simulation by delta seconds.
func tick(delta: float) -> void:
	for peer_id in players:
		var player: Dictionary = players[peer_id]
		var move: Vector2 = player.get("move", Vector2.ZERO)
		if move.length_squared() > 0.0001:
			var yaw: float = player.get("yaw", 0.0)
			var basis := Basis(Vector3.UP, yaw)
			var direction: Vector3 = basis * Vector3(move.x, 0.0, move.y)
			var pos: Vector3 = player.get("pos", SPAWN_POINT)
			var next_pos := pos + direction * float(player.get("move_speed", MOVE_SPEED)) * delta
			
			# Slide collision resolution
			if is_blocked(next_pos):
				var slide_x := Vector3(next_pos.x, next_pos.y, pos.z)
				if not is_blocked(slide_x):
					next_pos = slide_x
				else:
					var slide_z := Vector3(pos.x, next_pos.y, next_pos.z)
					if not is_blocked(slide_z):
						next_pos = slide_z
					else:
						next_pos = pos
						
			next_pos.x = clampf(next_pos.x, -HALF_BOUNDS, HALF_BOUNDS)
			next_pos.z = clampf(next_pos.z, -HALF_BOUNDS, HALF_BOUNDS)
			next_pos.y = GROUND_Y
			player["pos"] = next_pos
	tick_index += 1


## A compact, RPC-serializable view of the world for broadcast to clients.
func snapshot() -> Dictionary:
	var list: Array = []
	for peer_id in players:
		var player: Dictionary = players[peer_id]
		list.append({
			"id": int(player.get("id", peer_id)),
			"name": String(player.get("name", "")),
			"pos": player.get("pos", SPAWN_POINT),
			"yaw": float(player.get("yaw", 0.0)),
		})
	return {"tick": tick_index, "players": list}

func player_count() -> int:
	return players.size()
