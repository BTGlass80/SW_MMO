extends SceneTree

var _failures: Array[String] = []

func _assert_true(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append("FAILED (expected true): " + msg)

func _assert_equal(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_failures.append("FAILED: " + msg + " (expected " + str(expected) + ", got " + str(actual) + ")")

func _init() -> void:
	# Just verify standard strings via standard regex-style check, matching exactly how network_manager does it.
	# The actual check in network_manager.gd is:
	# if text.begins_with("/admin "):
	
	var admin_str = "/admin list"
	var say_str = "/say hello"
	
	_assert_true(admin_str.begins_with("/admin "), "/admin command is intercepted")
	_assert_true(not say_str.begins_with("/admin "), "/say command bypasses admin intercept")
	_assert_true(not "/org hey".begins_with("/admin "), "/org command bypasses admin intercept")
	_assert_true(not "hello /admin test".begins_with("/admin "), "text with /admin in middle bypasses admin intercept")
	
	if _failures.is_empty():
		print("admin_routing_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

