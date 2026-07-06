extends SceneTree

var _failures: Array[String] = []

func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr(msg)

func _finish() -> void:
	if _failures.is_empty():
		print("space_cargo_live_rpc_smoke: OK")
		quit(0)
	else:
		quit(1)

func _init() -> void:
	print("Starting Space Cargo RPC multi-process test...")
	var t_dir = DirAccess.open("user://telemetry")
	if t_dir != null and t_dir.file_exists("space_cargo_events.jsonl"):
		t_dir.remove("space_cargo_events.jsonl")

	var exe = OS.get_executable_path()
	if exe == "":
		exe = "godot"

	var server_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--server", "--space-cargo-test-server", "--port", "24557", "--telemetry-file", "user://telemetry/space_cargo_events.jsonl"]
	var pid_server = OS.create_process(exe, server_args)
	if pid_server == -1:
		_fail("Could not start server process")
		_finish()
		return
		
	OS.delay_msec(1000)

	print("Running Client 1 (Pilot)...")
	var client1_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--space-cargo-test-c1", "--port", "24557"]
	
	var c1_out = []
	var c1_exit = 0
	
	var t1 = Thread.new()
	t1.start(func(): 
		c1_exit = OS.execute(exe, client1_args, c1_out, true, false)
	)
	
	var waited = 0
	while t1.is_alive() and waited < 15:
		OS.delay_msec(1000)
		waited += 1
		
	if t1.is_alive():
		_fail("Client 1 timed out and hung!")
		OS.kill(pid_server)
		# Try to kill the child process if it's stuck
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)
		# Wait a bit for the client to realize server died and exit
		OS.delay_msec(2000)
	else:
		t1.wait_to_finish()
		print("Client 1 Output:\n" + "\n".join(c1_out))
		if c1_exit != 0:
			_fail("Client 1 failed. Output: " + "\n".join(c1_out))
		OS.kill(pid_server)
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)

	var events = []
	print("--- TELEMETRY LOGS ---")
	if t_dir != null and t_dir.file_exists("space_cargo_events.jsonl"):
		var f = FileAccess.open("user://telemetry/space_cargo_events.jsonl", FileAccess.READ)
		while not f.eof_reached():
			var line = f.get_line().strip_edges()
			if line != "":
				print(line)
				var p = JSON.parse_string(line)
				if p != null:
					events.append(p)
	print("----------------------")

	var found_faucet = false
	var found_sink = false
	
	for ev in events:
		var ev_type = ev.get("type", ev.get("event", ""))
		if ev_type == "faucet_harvest" and ev.get("item_template") == "asteroid_field":
			found_faucet = true
		if ev_type == "sink_fee" and ev.get("fee_type") == "docking":
			found_sink = true

	if not found_faucet:
		_fail("Did not find faucet_harvest for asteroid_field in telemetry")
	if not found_sink:
		_fail("Did not find sink_fee for docking in telemetry")

	_finish()

