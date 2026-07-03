extends RefCounted
## Pure, socket-free structured-telemetry writer (Wave G — "telemetry before
## tuning"). PT1's whole value is data we currently cannot see: death, loot,
## time-to-kill, insurance, economy flow. This is the writer only; routing it
## from the live print sites (network_manager.gd, combat_arena.gd, ...) is a
## later wiring pass and is deliberately NOT done here.
##
## Appends ONE JSON object per line (JSONL) to a log file under a safe writable
## directory: user:// by default, or an injected path for tests/tools. NEVER
## point this at C:\SW_MUSH or the project source tree.
##
## The SERVER owns the clock, so this class never touches Time/OS/Date itself —
## callers pass their own "ts" (or any other field) inside `fields`. Given the
## same event type + fields in the same order, log_event always serializes the
## same bytes (deterministic; no hidden clock, no random ids).
##
## Robustness: a failed open (missing/unwritable directory, path collision,
## etc.) degrades to a safe no-op — log_event returns false rather than
## crashing the caller. A telemetry outage must never take down the server.

const DEFAULT_PATH := "user://telemetry/events.jsonl"

var _path: String

func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	_ensure_dir()

## The JSONL file path this writer appends to.
func path() -> String:
	return _path

## Appends one structured event line: {"type": type, ...fields}. `fields` is
## free-form (death/buy/sell/loot/travel/window_resolve/... all share this one
## shape) — the caller decides what belongs on each event, including any "ts".
## Returns true on a successful append, false if the file could not be opened
## (no exception is raised).
func log_event(type: String, fields: Dictionary = {}) -> bool:
	var event: Dictionary = {"type": type}
	for key in fields.keys():
		event[key] = fields[key]
	var file := _open_for_append()
	if file == null:
		return false
	file.store_line(JSON.stringify(event))
	file.close()
	return true

## Reads every logged event back, in append order, as parsed Dictionaries.
## Blank lines and lines that fail to parse as a JSON object are silently
## skipped (e.g. a torn trailing line from a crash mid-write) rather than
## failing the whole read.
func read_all() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not FileAccess.file_exists(_path):
		return events
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return events
	var text := file.get_as_text()
	file.close()
	for line in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty():
			continue
		var json := JSON.new()
		if json.parse(trimmed) != OK:
			continue
		var parsed: Variant = json.data
		if typeof(parsed) == TYPE_DICTIONARY:
			events.append(parsed as Dictionary)
	return events

## Returns the last `n` logged events (or fewer, if the log has fewer than
## `n`). `n <= 0` returns an empty array.
func tail(n: int) -> Array[Dictionary]:
	if n <= 0:
		return []
	var events := read_all()
	if events.size() <= n:
		return events
	return events.slice(events.size() - n, events.size())

func _ensure_dir() -> void:
	var dir_path := _path.get_base_dir()
	if dir_path != "":
		DirAccess.make_dir_recursive_absolute(dir_path)

func _open_for_append() -> FileAccess:
	if FileAccess.file_exists(_path):
		var file := FileAccess.open(_path, FileAccess.READ_WRITE)
		if file == null:
			return null
		file.seek_end()
		return file
	return FileAccess.open(_path, FileAccess.WRITE)
