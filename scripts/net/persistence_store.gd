extends RefCounted
## Server-side player persistence (M1.4 backbone). JSON first; SQLite/Postgres later
## per docs/PERSISTENCE_DESIGN.md. Record shape follows
## data/schemas/player_persistence.schema.json (only the fields we have data for now
## are populated; org/city/world_hooks arrive with the M2 systems).
##
## Pure/socket-free (filesystem only) so it is headlessly unit-testable. One JSON file
## per character under root_dir. The server loads on login and snapshots on
## save/logout + on a periodic autosave tick. The server owns position truth — a
## restored record is authoritative, never client-reported.

const SCHEMA_VERSION := 1
const DEFAULT_ZONE := "tatooine.mos_eisley.spaceport"

var _root: String

func _init(root_dir: String = "user://persistence") -> void:
	_root = root_dir.trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(_root)

func record_path(character_id: String) -> String:
	return "%s/%s.json" % [_root, _sanitize(character_id)]

func has_record(character_id: String) -> bool:
	# A surviving .tmp (a crash in save_record's rename window) still counts as a character so the
	# server loads + recovers it rather than re-creating it from scratch.
	return FileAccess.file_exists(record_path(character_id)) or FileAccess.file_exists(record_path(character_id) + ".tmp")

func load_record(character_id: String) -> Dictionary:
	var record := _read_json(record_path(character_id))
	if not record.is_empty():
		return record
	# Crash-recovery: if the live file is missing/corrupt but the freshly-written copy survived under
	# .tmp (a crash in the rename window below), recover from it instead of losing the character.
	return _read_json(record_path(character_id) + ".tmp")

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	# Use the quiet instance parser (not JSON.parse_string) so a corrupt/half-written file — which
	# the crash-recovery path deliberately encounters — returns {} silently instead of logging an
	# engine parse error (which would be noise and could trip the smoke gate's error grep).
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func save_record(character_id: String, record: Dictionary) -> bool:
	var to_write := record.duplicate(true)
	to_write["last_saved_unix"] = Time.get_unix_time_from_system()
	# Atomic-ish write: serialize to a sibling .tmp, then rename it over the live file. A crash
	# mid-write can only ever truncate the .tmp — the live record is never left half-written (which
	# would make load_record() return {} and the server silently re-create the character as
	# brand-new, losing it). The 30s autosave hits this window continuously.
	var final_path := record_path(character_id)
	var tmp_path := final_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_write, "\t"))
	file.close()
	var dir := DirAccess.open(_root)
	if dir == null:
		return false
	var final_name := final_path.get_file()
	var tmp_name := tmp_path.get_file()
	if dir.file_exists(final_name) and dir.remove(final_name) != OK:
		return false
	return dir.rename(tmp_name, final_name) == OK

func default_record(character_id: String, account_id: String, display_name: String, spawn: Vector3, yaw: float = 0.0) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"character_id": character_id,
		"account_id": account_id,
		"name": display_name,
		"position": {
			"zone_id": DEFAULT_ZONE,
			"pos": {"x": spawn.x, "y": spawn.y, "z": spawn.z},
			"yaw": yaw,
		},
		"sheet": {
			"attributes": {},
			"skills": {},
			"character_points": 5,
			"force_points": 1,
			"force_sensitive": false,
			"wound_state": "healthy",
			"credits": 0,
		},
		"created_unix": Time.get_unix_time_from_system(),
		"extra": {},
	}

func load_or_create(character_id: String, account_id: String, display_name: String, spawn: Vector3) -> Dictionary:
	var record := load_record(character_id)
	if record.is_empty():
		return default_record(character_id, account_id, display_name, spawn)
	return record

# --- typed helpers for the netcode layer ---
static func record_pos(record: Dictionary, fallback: Vector3) -> Vector3:
	var p: Dictionary = (record.get("position", {}) as Dictionary).get("pos", {})
	if p.is_empty():
		return fallback
	return Vector3(float(p.get("x", fallback.x)), float(p.get("y", fallback.y)), float(p.get("z", fallback.z)))

static func record_yaw(record: Dictionary, fallback: float = 0.0) -> float:
	return float((record.get("position", {}) as Dictionary).get("yaw", fallback))

static func apply_position(record: Dictionary, pos: Vector3, yaw: float) -> Dictionary:
	var next := record.duplicate(true)
	var position: Dictionary = next.get("position", {})
	position["pos"] = {"x": pos.x, "y": pos.y, "z": pos.z}
	position["yaw"] = yaw
	if not position.has("zone_id"):
		position["zone_id"] = DEFAULT_ZONE
	next["position"] = position
	return next

static func apply_combat(record: Dictionary, combat_state: Dictionary) -> Dictionary:
	var next := record.duplicate(true)
	var sheet: Dictionary = next.get("sheet", {})
	sheet["character_points"] = int(combat_state.get("player_character_points", sheet.get("character_points", 5)))
	sheet["force_points"] = int(combat_state.get("player_force_points", sheet.get("force_points", 1)))
	sheet["wound_state"] = wound_state_for_severity(int(combat_state.get("player_wound_severity", 0)))
	next["sheet"] = sheet
	return next

static func combat_from_record(record: Dictionary) -> Dictionary:
	var sheet: Dictionary = record.get("sheet", {})
	return {
		"player_character_points": int(sheet.get("character_points", 5)),
		"player_force_points": int(sheet.get("force_points", 1)),
		"player_wound_severity": severity_for_wound_state(String(sheet.get("wound_state", "healthy"))),
	}

static func wound_state_for_severity(severity: int) -> String:
	match severity:
		0: return "healthy"
		1: return "stunned"
		2: return "wounded"
		3: return "incapacitated"
		4: return "mortally_wounded"
		_: return "dead"

static func severity_for_wound_state(state: String) -> int:
	match state:
		"healthy": return 0
		"stunned": return 1
		"wounded", "wounded_twice": return 2
		"incapacitated": return 3
		"mortally_wounded": return 4
		"dead": return 5
	return 0

func _sanitize(character_id: String) -> String:
	var safe := ""
	for i in character_id.length():
		var c := character_id[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "-" or c == "_":
			safe += c
		else:
			safe += "_"
	return safe if safe != "" else "anon"
