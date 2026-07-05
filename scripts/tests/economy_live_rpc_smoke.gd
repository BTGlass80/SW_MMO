extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	print("Starting economy RPC multi-process test...")
	var t_dir = DirAccess.open("user://telemetry")
	if t_dir != null and t_dir.file_exists("events.jsonl"):
		t_dir.remove("events.jsonl")

	var exe = OS.get_executable_path()
	if exe == "":
		exe = "godot"

	# Clean up any old db or state
	var dir = DirAccess.open("user://")
	if dir != null:
		if dir.file_exists("bazaar.json"): dir.remove("bazaar.json")
		if dir.file_exists("record_cache.json"): dir.remove("record_cache.json")
		if dir.dir_exists("telemetry"):
			var t_dir2 = DirAccess.open("user://telemetry")
			if t_dir2 != null and t_dir2.file_exists("events.jsonl"):
				t_dir2.remove("events.jsonl")

	var server_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--server", "--economy-test-server", "--port", "24556"]
	var pid_server = OS.create_process(exe, server_args)
	if pid_server == -1:
		_fail("Could not start server process")
		_finish()
		return
		
	# Wait for server to start
	OS.delay_msec(1000)

	print("Running Client 1 (Crafter)...")
	var output = []
	var client1_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--economy-test-c1", "--port", "24556"]
	
	var c1_exit = 0
	var t1 = Thread.new()
	t1.start(func(): c1_exit = OS.execute(exe, client1_args, output, true, false))
	
	var waited = 0
	while t1.is_alive() and waited < 15:
		OS.delay_msec(1000)
		waited += 1
		
	if t1.is_alive():
		OS.kill(pid_server)
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)
		_fail("Client 1 timed out")
		_finish()
		return
	else:
		t1.wait_to_finish()
		print("Client 1 finished with exit code %d" % c1_exit)
		print("Client 1 Output:\n" + "\n".join(output))
		if c1_exit != 0:
			_fail("Client 1 failed. Output: " + "\n".join(output))
		
	print("Running Client 2 (Buyer)...")
	# We want Client 2 to run after Client 1 has listed the item
	var output2 = []
	var client2_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--economy-test-c2", "--port", "24556"]
	
	var c2_exit = 0
	var t2 = Thread.new()
	t2.start(func(): c2_exit = OS.execute(exe, client2_args, output2, true, false))
	
	waited = 0
	while t2.is_alive() and waited < 15:
		OS.delay_msec(1000)
		waited += 1
		
	if t2.is_alive():
		OS.kill(pid_server)
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)
		_fail("Client 2 timed out")
		_finish()
		return
	else:
		t2.wait_to_finish()
		print("Client 2 finished with exit code %d" % c2_exit)
		print("Client 2 Output:\n" + "\n".join(output2))
		if c2_exit != 0:
			_fail("Client 2 failed. Output: " + "\n".join(output2))

	OS.kill(pid_server)
	OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)

	# Verify telemetry
	var events = []
	if t_dir != null and t_dir.file_exists("events.jsonl"):
		var f = FileAccess.open("user://telemetry/events.jsonl", FileAccess.READ)
		while not f.eof_reached():
			var line = f.get_line()
			if line != "":
				var json = JSON.new()
				if json.parse(line) == OK:
					if json.data.has("type"):
						events.append(json.data.get("type"))
					elif json.data.has("event"):
						events.append(json.data.get("event"))
					else:
						# If it has no 'event' key, it might just be the event string itself?
						print("Telemetry line: ", line)
					
	if not events.has("bazaar_list") or not events.has("bazaar_buy"):
		_fail("Telemetry did not contain bazaar events. Found: " + str(events))
		
	_finish()
	
func _fail(msg: String):
	_failures.append(msg)
	
func _finish():
	if _failures.is_empty():
		print("economy_live_rpc_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)
