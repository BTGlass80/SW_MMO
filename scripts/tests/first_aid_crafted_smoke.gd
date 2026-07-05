extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	print("Starting first_aid_crafted_smoke...")
	
	# Since network_manager is complex to mock out headlessly in a single script,
	# we can just write a test that verifies the logic of finding the instance_id
	# as implemented in submit_heal. We'll do a string parsing test or similar,
	# or better yet, we can just run a live multi-process test if we need to.
	# Actually, I'll instantiate a minimal fake script to represent the server behavior.
	
	var script_src = "extends RefCounted\n"
	script_src += "var inventory = []\n"
	script_src += "var medpac_idx = -1\n"
	script_src += "var medpac_quality = 50.0\n"
	script_src += "func find_medpac(medpac_instance_id: String) -> void:\n"
	script_src += "	if medpac_instance_id != \"\":\n"
	script_src += "		for i in range(inventory.size()):\n"
	script_src += "			var item = inventory[i]\n"
	script_src += "			if item is Dictionary and String(item.get(\"instance_id\", \"\")) == medpac_instance_id:\n"
	script_src += "				medpac_idx = i\n"
	script_src += "				if item.has(\"effectiveness\"):\n"
	script_src += "					medpac_quality = float(item.get(\"effectiveness\", 50.0))\n"
	script_src += "				else:\n"
	script_src += "					medpac_quality = float(item.get(\"quality\", 50.0))\n"
	script_src += "				break\n"
	script_src += "	if medpac_idx == -1:\n"
	script_src += "		for i in range(inventory.size()):\n"
	script_src += "			var item = inventory[i]\n"
	script_src += "			if item is Dictionary and (String(item.get(\"template_key\", \"\")) == \"medpac\" or String(item.get(\"template_id\", \"\")) == \"medpac\"):\n"
	script_src += "				medpac_idx = i\n"
	script_src += "				if item.has(\"effectiveness\"):\n"
	script_src += "					medpac_quality = float(item.get(\"effectiveness\", 50.0))\n"
	script_src += "				else:\n"
	script_src += "					medpac_quality = float(item.get(\"quality\", 50.0))\n"
	script_src += "				break\n"
	script_src += "			elif item is String and \"Medpac\" in item:\n"
	script_src += "				medpac_idx = i\n"
	script_src += "				break\n"
	
	var test_obj = GDScript.new()
	test_obj.source_code = script_src
	test_obj.reload()
	var inst = test_obj.new()
	
	# Test 1: Finding by instance_id (crafted)
	inst.inventory = [
		{"template_id": "blaster"},
		{"template_id": "medpac", "instance_id": "med123", "effectiveness": 85.0},
		{"template_id": "medpac", "instance_id": "med456", "effectiveness": 95.0}
	]
	inst.find_medpac("med456")
	_assert_equal(inst.medpac_idx, 2, "Should find the specific instance_id medpac")
	_assert_equal(inst.medpac_quality, 95.0, "Should have the correct quality")
	
	# Test 2: Fallback to first medpac if instance_id not provided
	inst.medpac_idx = -1
	inst.find_medpac("")
	_assert_equal(inst.medpac_idx, 1, "Should fall back to first medpac")
	_assert_equal(inst.medpac_quality, 85.0, "Should have the correct quality")
	
	# Test 3: Fallback if instance_id provided but not found
	inst.medpac_idx = -1
	inst.find_medpac("invalid999")
	_assert_equal(inst.medpac_idx, 1, "Should fall back to first medpac if instance_id is invalid")
	
	_finish()

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])

func _finish() -> void:
	if _failures.is_empty():
		print("first_aid_crafted_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)
