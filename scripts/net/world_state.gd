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
const SPAWN_POINT := Vector3(-20.0, 1.2, -6.0) # Docking Bay 94 firing line, matches solo slice
const GROUND_Y := 1.2

var players: Dictionary = {}   # peer_id:int -> player dict {id,name,pos,yaw,move,jump}
var tick_index: int = 0

func add_player(peer_id: int, display_name: String = "", spawn: Vector3 = SPAWN_POINT) -> Dictionary:
	var resolved_name := display_name if display_name != "" else "Spacer-%d" % peer_id
	var player := {
		"id": peer_id,
		"name": resolved_name,
		"pos": spawn,
		"yaw": 0.0,
		"move": Vector2.ZERO,
		"jump": false,
	}
	players[peer_id] = player
	return player

func remove_player(peer_id: int) -> void:
	players.erase(peer_id)

func has_player(peer_id: int) -> bool:
	return players.has(peer_id)

func get_player(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

## Record a client's most recent input intent. The server applies it on the next
## tick; clients never move themselves authoritatively.
func set_input(peer_id: int, move: Vector2, yaw: float, jump: bool = false) -> void:
	var player: Dictionary = players.get(peer_id, {})
	if player.is_empty():
		return
	var clamped := move
	if clamped.length() > 1.0:
		clamped = clamped.normalized()
	player["move"] = clamped
	player["yaw"] = yaw
	player["jump"] = jump

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
			pos += direction * MOVE_SPEED * delta
			pos.x = clampf(pos.x, -HALF_BOUNDS, HALF_BOUNDS)
			pos.z = clampf(pos.z, -HALF_BOUNDS, HALF_BOUNDS)
			pos.y = GROUND_Y
			player["pos"] = pos
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
