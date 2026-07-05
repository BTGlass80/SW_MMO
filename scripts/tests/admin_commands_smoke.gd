extends SceneTree

var _failures: Array[String] = []

class MockRPC:
	func rpc_id(peer, arg1=null):
		pass

class MockNet:
	var _peer_characters = {}
	var _peer_zones = {}
	var _bazaar_listings = {}
	var _telemetry = null
	var request_snapshot = MockRPC.new()
	var _storage = {}
	
	func admin_get_peer_by_character(char_id: String) -> int:
		for peer in _peer_characters:
			if _peer_characters[peer] == char_id:
				return peer
		return 0
		
	func admin_set_peer_zone(peer: int, zone: String) -> void:
		_peer_zones[peer] = zone
		
	func admin_load_record(char_id: String) -> Dictionary:
		if _storage.has(char_id):
			return _storage[char_id].duplicate(true)
		return {}
		
	func admin_save_record(char_id: String, record: Dictionary) -> void:
		_storage[char_id] = record.duplicate(true)
		
	func admin_push_sheet(peer: int, record: Dictionary) -> void:
		pass
		
func _init() -> void:
	var net = MockNet.new()
	
	# Mock active character
	net._storage["pilot_1"] = {
		"sheet": {
			"credits": 1000,
			"cp": 50,
			"wounds": 1,
			"inventory": [],
			"space_state": {
				"in_space": true,
				"ship_cargo": [{"instance_id": "cargo1", "template_id": "starship_salvage"}]
			}
		}
	}
	net._peer_characters[1] = "pilot_1"
	net._peer_zones[1] = "space_1"
	
	var AdminCommands = preload("res://scripts/net/admin_commands.gd")
	
	# 1. Test grant credits
	var res1 = AdminCommands.process_command("grant", ["pilot_1", "credits", "500"], "pilot_1", net)
	if net._storage["pilot_1"]["sheet"]["credits"] != 1500:
		_failures.append("Failed to grant credits. Result: %s" % res1)
		
	# 2. Test clear_space
	var res2 = AdminCommands.process_command("clear_space", ["pilot_1"], "pilot_1", net)
	if net._storage["pilot_1"]["sheet"]["space_state"]["in_space"] == true:
		_failures.append("Failed to clear space state. Result: %s" % res2)
		
	# 3. Test unstuck
	var res3 = AdminCommands.process_command("unstuck", ["pilot_1"], "pilot_1", net)
	if net._peer_zones[1] != "mos_eisley":
		_failures.append("Failed to unstuck character. Result: %s" % res3)
		
	if _failures.is_empty():
		print("admin_commands_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)
