extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	print("Starting item identity smoke test...")
	var exe = OS.get_executable_path()
	if exe == "":
		exe = "godot"
		
	# 1. Clean up old state
	var dir = DirAccess.open("user://")
	if dir != null:
		if dir.file_exists("bazaar.json"): dir.remove("bazaar.json")
		if dir.file_exists("record_cache.json"): dir.remove("record_cache.json")
	var pdir = DirAccess.open("user://persistence")
	if pdir != null:
		if pdir.file_exists("item_c1.json"): pdir.remove("item_c1.json")
		if pdir.file_exists("item_c2.json"): pdir.remove("item_c2.json")
	var tdir = DirAccess.open("user://telemetry")
	if tdir != null:
		if tdir.file_exists("item_identity_events.jsonl"): tdir.remove("item_identity_events.jsonl")
			
	# 2. Start server
	var server_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--server", "--item-ident-test-server", "--port", "24561", "--telemetry-file", "user://telemetry/item_identity_events.jsonl"]
	var pid_server = OS.create_process(exe, server_args)
	if pid_server == -1:
		_fail("Could not start server process")
		_finish()
		return
		
	OS.delay_msec(4000)
	
	# 3. Client 1 (Crafter/Lister)
	print("Running Client 1 (Crafter/Lister)...")
	var client1_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--port", "24561", "--account", "item_c1", "--item-ident-c1", "--quit-after", "30"]
	var c1_out = []
	var c1_exit = 0
	var t1 = Thread.new()
	t1.start(func(): c1_exit = OS.execute(exe, client1_args, c1_out, true, false))
	
	var waited = 0
	while t1.is_alive() and waited < 30:
		OS.delay_msec(1000)
		waited += 1
		
	if t1.is_alive():
		var out1_str_err = "\n".join(c1_out)
		_fail("Client 1 timed out! Output so far: " + out1_str_err)
		_kill(pid_server)
		_finish()
		return
		
	t1.wait_to_finish()
	var out1_str = "\n".join(c1_out)
	print("Client 1 Output:\n", out1_str)
	if not out1_str.contains("[c1] Crafted: "):
		_fail("Client 1 failed to craft item")
		_kill(pid_server)
		_finish()
		return
		
	# 4. Client 2 (Buyer)
	print("Running Client 2 (Buyer)...")
	# We want Client 2 to run after Client 1 has listed the item
	var client2_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--port", "24561", "--account", "item_c2", "--item-ident-c2", "--quit-after", "30"]
	var c2_out = []
	var c2_exit = 0
	var t2 = Thread.new()
	t2.start(func(): c2_exit = OS.execute(exe, client2_args, c2_out, true, false))
	
	waited = 0
	while t2.is_alive() and waited < 30:
		OS.delay_msec(1000)
		waited += 1
		
	if t2.is_alive():
		var out2_str_err = "\n".join(c2_out)
		_fail("Client 2 timed out! Output so far: " + out2_str_err)
		_kill(pid_server)
		_finish()
		return
		
	t2.wait_to_finish()
	var out2_str = "\n".join(c2_out)
	print("Client 2 Output:\n", out2_str)
	if not out2_str.contains("[c2] Bought listing for instance: "):
		_fail("Client 2 failed to buy item")
		_kill(pid_server)
		_finish()
		return
		
	# 5. Restart Server
	print("Restarting Server...")
	_kill(pid_server)
	# Wait for server to start
	OS.delay_msec(2000)
	
	var pid_server2 = OS.create_process(exe, server_args)
	if pid_server2 == -1:
		_fail("Could not restart server process")
		_finish()
		return
		
	OS.delay_msec(2000)
	
	# 6. Client 3 (Buyer Reconnects and Verifies/Sells)
	print("Running Client 3 (Reconnect and Verify)...")
	var client3_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--port", "24561", "--account", "item_c2", "--item-ident-c3", "--quit-after", "30"]
	var c3_out = []
	var c3_exit = 0
	var t3 = Thread.new()
	t3.start(func(): c3_exit = OS.execute(exe, client3_args, c3_out, true, false))
	
	waited = 0
	while t3.is_alive() and waited < 15:
		OS.delay_msec(1000)
		waited += 1
		
	if t3.is_alive():
		_fail("Client 3 timed out")
		_kill(pid_server2)
		_finish()
		return
		
	t3.wait_to_finish()
	var out3_str = "\n".join(c3_out)
	print("Client 3 Output:\n", out3_str)
	if not out3_str.contains("[c3] Verified item instance in inventory after restart: "):
		_fail("Client 3 failed to verify item instance in inventory")
		
	_kill(pid_server2)
	
	# 7. Check Telemetry
	var events = []
	if tdir != null and tdir.file_exists("item_identity_events.jsonl"):
		var f = FileAccess.open("user://telemetry/item_identity_events.jsonl", FileAccess.READ)
		while not f.eof_reached():
			var line = f.get_line()
			if line != "":
				var json = JSON.new()
				if json.parse(line) == OK:
					if json.data.has("type"):
						events.append(json.data.get("type"))
					elif json.data.has("event"):
						events.append(json.data.get("event"))
						
	if not events.has("bazaar_list") or not events.has("bazaar_buy"):
		_fail("Telemetry did not contain expected events. Found: " + str(events))
		
	_finish()
	
func _kill(pid: int) -> void:
	OS.kill(pid)
	OS.execute("taskkill", ["/F", "/T", "/PID", str(pid)], [], false, false)
	OS.delay_msec(500)

func _fail(msg: String) -> void:
	_failures.append(msg)
	
func _finish() -> void:
	if _failures.is_empty():
		print("item_identity_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)
