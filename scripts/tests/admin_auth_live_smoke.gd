extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	print("Starting admin auth live RPC smoke test...")
	var exe = OS.get_executable_path()
	if exe == "":
		exe = "godot"

	# 1. Start server WITHOUT --dev-admin-allowlist
	var server_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--server", "--port", "24558"]
	var pid_server = OS.create_process(exe, server_args)
	if pid_server == -1:
		_fail("Could not start server process")
		_finish()
		return
		
	# Wait for server to start
	OS.delay_msec(1000)

	print("Running Client 1 (Regular User)...")
	var client1_args = ["--headless", "--path", ".", "res://scenes/net_world.tscn", "--", "--connect", "127.0.0.1", "--say", "/admin list", "--port", "24558", "--quit-after", "5"]
	
	var c1_out = []
	var c1_exit = 0
	var t1 = Thread.new()
	t1.start(func(): c1_exit = OS.execute(exe, client1_args, c1_out, true, false))
	
	var waited = 0
	while t1.is_alive() and waited < 15:
		OS.delay_msec(1000)
		waited += 1
		
	if t1.is_alive():
		_fail("Client 1 timed out and hung!")
		OS.kill(pid_server)
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)
		OS.delay_msec(2000)
	else:
		t1.wait_to_finish()
		var out_str = "\n".join(c1_out)
		print("Client 1 Output:\n" + out_str)
		if c1_exit != 0:
			_fail("Client 1 failed. Output: " + out_str)
			
		# Check for Permission denied
		if not out_str.contains("Permission denied"):
			_fail("Client 1 did not receive 'Permission denied' message for /admin list. Output: " + out_str)
			
		OS.kill(pid_server)
		OS.execute("taskkill", ["/F", "/T", "/PID", str(pid_server)], [], false, false)

	_finish()
	
func _fail(msg: String):
	_failures.append(msg)
	
func _finish():
	if _failures.is_empty():
		print("admin_auth_live_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)
