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

	var exe = "C:\\Godot 4\\Godot_v4.6.3-stable_win64_console.exe"

	var test_account_id = "pilot_test_%d" % randi()
	var server_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--server", "--space-cargo-test-server", "--account", test_account_id, "--port", "24557", "--telemetry-file", "user://telemetry/space_cargo_events.jsonl"]
	var pid_server = OS.create_process(exe, server_args)
	if pid_server == -1:
		_fail("Could not start server process")
		_finish()
		return
		
	OS.delay_msec(1000)

	print("Running Client 1 (Pilot)...")
	var client1_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--space-cargo-test-c1", "--account", test_account_id, "--port", "24557"]
	
	var pid_client = OS.create_process(exe, client1_args)
	
	var waited = 0
	while OS.is_process_running(pid_client) and waited < 20:
		OS.delay_msec(1000)
		waited += 1
		
	if OS.is_process_running(pid_client):
		_fail("Client 1 timed out and hung!")
		OS.kill(pid_client)
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_client)], [], false, false)
		
		OS.kill(pid_server)
		# Try to kill the child process if it's stuck
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)
		
		OS.delay_msec(2000)
		print("Client 1 Finished.")
		# If we had OS.execute we could check exit code, but we can't easily get it from create_process.
		# We'll rely on telemetry files to assert success.

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
	var found_sell = false
	
	for ev in events:
		var ev_type = ev.get("type", ev.get("event", ""))
		var ev_char = ev.get("character_id", "")
		if ev_char != test_account_id:
			continue
		if ev_type == "faucet_harvest" and ev.get("item_template") == "asteroid_field":
			found_faucet = true
		if ev_type == "sell" and ev.get("item_key") == "asteroid_field":
			found_sell = true

	if not found_faucet:
		_fail("Did not find faucet_harvest for asteroid_field in telemetry")
	if not found_sell:
		_fail("Did not find sell event for asteroid_field in telemetry")

	# Clean up processes
	OS.kill(pid_server)
	OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)
	if OS.is_process_running(pid_client):
		OS.kill(pid_client)
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_client)], [], false, false)

	_finish()

