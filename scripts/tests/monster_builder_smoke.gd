extends SceneTree
## Headless smoke test for the combat-target builder used by the networked client to
## render the thing the player is fighting (a hostile creature mesh or the training
## remote). Verifies each kind builds a nameplated mesh tree and that a creature's
## look (scale + tint) is DETERMINISTIC from its name — so every client draws the same
## "Womp Rat" and the same "Krayt Dragon", and the two look distinct.

const MonsterBuilder := preload("res://scripts/world/monster_builder.gd")

var _failures: Array[String] = []

func _init() -> void:
	var builder := MonsterBuilder.new()

	# --- training remote (the shared dummy) ---
	var remote := builder.build_target("remote", "B1 Training Remote")
	_assert_true(remote is Node3D, "remote is a Node3D")
	_assert_true(remote.get_child_count() >= 3, "remote builds several parts (got %d)" % remote.get_child_count())
	_assert_true(_has_nameplate(remote, "B1 Training Remote"), "remote carries its nameplate")

	# --- hostile creature (monster) ---
	var beast := builder.build_target("monster", "Womp Rat")
	_assert_true(beast is Node3D, "beast is a Node3D")
	_assert_true(_mesh_count(beast) >= 8, "beast builds a blocky body/legs/head (got %d meshes)" % _mesh_count(beast))
	_assert_true(_has_nameplate(beast, "Womp Rat"), "beast carries its nameplate")

	# --- determinism: same name -> identical scale + tint ---
	var a := builder.beast_appearance("Krayt Dragon")
	var b := builder.beast_appearance("Krayt Dragon")
	_assert_equal(float(a["scale"]), float(b["scale"]), "appearance scale is deterministic")
	_assert_true((a["color"] as Color).is_equal_approx(b["color"] as Color), "appearance tint is deterministic")

	# --- keyword sizing: vermin small, megafauna large, distinct hues ---
	var rat := builder.beast_appearance("Womp Rat")
	var dragon := builder.beast_appearance("Krayt Dragon")
	_assert_true(float(rat["scale"]) < float(dragon["scale"]), "a rat reads smaller than a dragon")
	_assert_true(not (rat["color"] as Color).is_equal_approx(dragon["color"] as Color), "distinct creatures get distinct tints")

	remote.free()
	beast.free()
	_finish()

func _has_nameplate(root: Node3D, text: String) -> bool:
	var label := root.get_node_or_null("Nameplate") as Label3D
	return label != null and label.text == text

func _mesh_count(root: Node3D) -> int:
	var n := 0
	for child in root.get_children():
		if child is MeshInstance3D:
			n += 1
	return n

func _finish() -> void:
	if _failures.is_empty():
		print("monster_builder_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
