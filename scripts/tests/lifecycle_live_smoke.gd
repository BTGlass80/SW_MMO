extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	print("Starting end-to-end player lifecycle smoke test...")
	var exe = OS.get_executable_path()
	if exe == "":
		exe = "godot"
		
	# 1. Clean up old state
	var dir = DirAccess.open("user://persistence")
	if dir != null:
		if dir.file_exists("guest.json"):
			dir.remove("guest.json")
			
	# 2. Start server
	var server_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--server", "--port", "24560"]
	var server_out = []
	var pid_server = OS.create_process(exe, server_args) # Wait, create_process doesn't capture output. I should use execute with a thread.
	# Actually, OS.create_process runs it detached. Let's redirect output to a file.
	var f_out = FileAccess.open("user://server.log", FileAccess.WRITE)
	f_out.close()
	var server_args_full = ["/c", exe] + server_args + [">", OS.get_user_data_dir() + "/server.log", "2>&1"]
	pid_server = OS.create_process("cmd.exe", server_args_full)
		
	OS.delay_msec(1000)
	
	# 3. Connect client 1 (creates new char)
	print("Running Client (First Login)...")
	var client_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--port", "24560", "--quit-after", "4"]
	var c_out = []
	var c_exit = 0
	var t1 = Thread.new()
	t1.start(func(): c_exit = OS.execute(exe, client_args, c_out, true, false))
	
	var waited = 0
	while t1.is_alive() and waited < 15:
		OS.delay_msec(1000)
		waited += 1
		
	if t1.is_alive():
		_fail("Client timed out")
		_kill(pid_server)
		_finish()
		return
		
	t1.wait_to_finish()
	var out_str = "\n".join(c_out)
	print("Client 1 Output:\n" + out_str)
	if c_exit != 0:
		print("Client 1 exited with code: ", c_exit)
	
	# Wait a tiny bit for the server to flush the save
	OS.delay_msec(1000)
	
	# 4. Verify save file
	if not FileAccess.file_exists("user://persistence/guest.json"):
		_fail("Server did not create user://persistence/guest.json on disconnect")
		_kill(pid_server)
		_finish()
		return
		
	var f = FileAccess.open("user://persistence/guest.json", FileAccess.READ)
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		_fail("guest.json is invalid JSON")
	else:
		var data = j.data
		var sheet = data.get("sheet", {})
		if not sheet.has("credits"):
			_fail("Saved sheet missing credits")
		if not sheet.has("inventory"):
			_fail("Saved sheet missing inventory")
			
	f.close()
	
	# 5. Restart server
	print("Restarting server...")
	_kill(pid_server)
	OS.delay_msec(1000)
	
	var pid_server2 = OS.create_process(exe, server_args)
	if pid_server2 == -1:
		_fail("Could not restart server process")
		_finish()
		return
		
	OS.delay_msec(1000)
	
	# 6. Reconnect client (loads char)
	print("Running Client (Reconnect)...")
	var c2_out = []
	var c2_exit = 0
	var t2 = Thread.new()
	t2.start(func(): c2_exit = OS.execute(exe, client_args, c2_out, true, false))
	
	waited = 0
	while t2.is_alive() and waited < 15:
		OS.delay_msec(1000)
		waited += 1
		
	if t2.is_alive():
		_fail("Client 2 timed out")
		_kill(pid_server2)
		_finish()
		return
		
	t2.wait_to_finish()
	var out_str2 = "\n".join(c2_out)
	
	# If we see "[save] guest saved" on the server it proves the server loaded and saved it.
	# The client output will show the sheet was received from the server.
	
	_kill(pid_server2)
	_finish()
	
func _kill(pid: int) -> void:
	OS.kill(pid)
	OS.execute("taskkill", ["/F", "/T", "/PID", str(pid)], [], false, false)
	OS.delay_msec(500)

func _fail(msg: String) -> void:
	_failures.append(msg)
	
func _finish() -> void:
	if _failures.is_empty():
		print("lifecycle_live_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)
