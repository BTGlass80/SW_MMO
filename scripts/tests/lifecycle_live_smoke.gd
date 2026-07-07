extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	print("Starting end-to-end player lifecycle smoke test...")
	var exe = OS.get_executable_path()
	if exe == "":
		exe = "godot"
	var test_account := "lifecycle_test"
		
	# 1. Clean up old state
	var dir = DirAccess.open("user://persistence")
	if dir != null:
		if dir.file_exists("%s.json" % test_account):
			dir.remove("%s.json" % test_account)
			
	# 2. Start server
	var server_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--server", "--port", "24560"]
	var pid_server = OS.create_process(exe, server_args)
	if pid_server == -1:
		_fail("Could not start server process")
		_finish()
		return
		
	OS.delay_msec(1000)
	
	# 3. Connect client 1 (creates new char)
	print("Running Client (First Login)...")
	var client_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--port", "24560", "--account", test_account, "--quit-after", "4"]
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
		_fail("Client 1 exited with code %d" % c_exit)
		_kill(pid_server)
		_finish()
		return
	
	# Wait a tiny bit for the server to flush the save
	OS.delay_msec(1000)
	
	# 4. Verify save file
	var save_path := "user://persistence/%s.json" % test_account
	if not FileAccess.file_exists(save_path):
		_fail("Server did not create %s on disconnect" % save_path)
		_kill(pid_server)
		_finish()
		return
		
	var f = FileAccess.open(save_path, FileAccess.READ)
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		_fail("%s is invalid JSON" % save_path)
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
	print("Client 2 Output:\n" + out_str2)
	if c2_exit != 0:
		_fail("Client 2 exited with code %d" % c2_exit)
	if not out_str2.contains("[credits] balance="):
		_fail("Reconnect client did not receive a credited character sheet")
	
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
