extends SceneTree
## Headless smoke test for the shared settlement builder used by both the solo and
## networked worlds. Verifies it builds the expected landmarks into a host node and
## that the layout is deterministic (so every client renders the same Mos Eisley).

const WorldBuilder := preload("res://scripts/world/world_builder.gd")

var _failures: Array[String] = []

func _init() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var builder := WorldBuilder.new()
	builder.build_lighting(host)
	builder.build_ground(host)
	builder.build_settlement(host)

	_assert_true(host.get_node_or_null("SettlementGround") != null, "settlement ground built")
	_assert_true(_has_label(host, "Spaceport Row"), "spaceport row label present")
	_assert_true(_has_label(host, "Docking Bay 94"), "bay 94 label present")
	_assert_true(_count_inspectables(host) >= 6, "at least six inspectable markers")

	var total := host.get_child_count()
	_assert_true(total > 40, "settlement builds many nodes (got %d)" % total)

	# Determinism: a fresh builder with the same default seed produces the same count.
	var host2 := Node3D.new()
	get_root().add_child(host2)
	var builder2 := WorldBuilder.new()
	builder2.build_lighting(host2)
	builder2.build_ground(host2)
	builder2.build_settlement(host2)
	_assert_equal(host2.get_child_count(), total, "settlement geometry is deterministic")

	# Primitive helper returns a usable collidable body.
	var probe := Node3D.new()
	get_root().add_child(probe)
	var block := builder.add_box_to_world(probe, Vector3.ZERO, Vector3.ONE, Color.WHITE)
	_assert_true(block is StaticBody3D, "add_box_to_world returns a StaticBody3D")
	_assert_true(block.get_child_count() >= 2, "block has a collision shape and a mesh")

	host.queue_free()
	host2.queue_free()
	probe.queue_free()
	_finish()

func _has_label(host: Node3D, text: String) -> bool:
	for child in host.get_children():
		if child is Label3D and (child as Label3D).text == text:
			return true
	return false

func _count_inspectables(host: Node3D) -> int:
	var count := 0
	for child in host.get_children():
		if child.has_meta("inspectable"):
			count += 1
	return count

func _finish() -> void:
	if _failures.is_empty():
		print("world_builder_smoke: OK")
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
