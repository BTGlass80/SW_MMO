extends SceneTree
## Verifies that the runtime asset manifest contains unique IDs and that all paths exist.

var _failures: Array[String] = []

func _init() -> void:
	var manifest_path = "res://data/runtime_asset_manifest.json"
	if not FileAccess.file_exists(manifest_path):
		_failures.append("Manifest file not found: %s" % manifest_path)
		quit_with_failures()
		return
		
	var file = FileAccess.open(manifest_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		_failures.append("Failed to parse manifest JSON at %s" % manifest_path)
		quit_with_failures()
		return
		
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY or not data.has("assets"):
		_failures.append("Manifest is missing 'assets' array")
		quit_with_failures()
		return
		
	var assets: Array = data["assets"]
	var seen_ids = {}
	
	for a in assets:
		if typeof(a) != TYPE_DICTIONARY:
			_failures.append("Asset entry is not a dictionary: %s" % str(a))
			continue
			
		var id = a.get("id", "")
		if id == "":
			_failures.append("Asset missing id: %s" % str(a))
		elif seen_ids.has(id):
			_failures.append("Duplicate asset id found: %s" % id)
		else:
			seen_ids[id] = true
			
		var path = a.get("path", "")
		if path == "":
			_failures.append("Asset missing path: %s" % id)
		elif not FileAccess.file_exists(path):
			_failures.append("Asset path does not exist for %s: %s" % [id, path])
			
	if _failures.is_empty():
		print("asset_manifest_smoke: OK")
		quit(0)
	else:
		quit_with_failures()

func quit_with_failures() -> void:
	for failure in _failures:
		printerr(failure)
	quit(1)
