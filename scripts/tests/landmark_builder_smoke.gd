extends SceneTree
## Headless smoke test for the Mos Eisley cantina plaza landmark builder. Verifies it
## returns a real Node3D parented under the host, that it contains a healthy number of
## mesh instances with no null meshes, that the signature label is present, and that
## the layout is deterministic (same origin/seed -> identical child counts) so every
## client renders the same landmark.

const LandmarkBuilder := preload("res://scripts/world/landmark_builder.gd")

var _failures: Array[String] = []

func _init() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var builder := LandmarkBuilder.new()
	var root := builder.build_cantina_plaza(host)

	_assert_true(root is Node3D, "build_cantina_plaza returns a Node3D")
	_assert_true(root.get_parent() == host, "landmark root is parented under host")
	_assert_true(host.get_node_or_null("MosEisleyCantinaPlaza") != null, "landmark root findable by name")

	var mesh_count := _count_meshes(root)
	_assert_true(mesh_count > 20, "landmark builds many mesh instances (got %d)" % mesh_count)

	var null_mesh_count := _count_null_meshes(root)
	_assert_equal(null_mesh_count, 0, "no MeshInstance3D has a null mesh")

	_assert_true(_has_label(root, "Mos Eisley Cantina"), "cantina landmark label present")
	_assert_true(root.get_node_or_null("CantinaInterior") != null, "interior furniture group present")

	var domed_huts := _count_named(root, "DomedHut")
	_assert_true(domed_huts >= 3, "at least three domed huts (main hall + two flanking, got %d)" % domed_huts)

	var stalls := _count_named(root, "MarketStall")
	_assert_true(stalls >= 2, "at least two market stalls (got %d)" % stalls)

	var vaporators := _count_named(root, "MoistureVaporator")
	_assert_true(vaporators >= 2, "at least two moisture vaporators (got %d)" % vaporators)

	var walls := _count_named(root, "LowWall")
	_assert_true(walls >= 4, "at least four low-wall perimeter segments (got %d)" % walls)

	# Determinism: a fresh builder with the same default origin/seed produces the same
	# mesh count, so every client renders an identical landmark.
	var host2 := Node3D.new()
	get_root().add_child(host2)
	var builder2 := LandmarkBuilder.new()
	var root2 := builder2.build_cantina_plaza(host2)
	_assert_equal(_count_meshes(root2), mesh_count, "landmark geometry is deterministic")

	# A non-zero origin offsets the whole cluster without changing its shape.
	var host3 := Node3D.new()
	get_root().add_child(host3)
	var builder3 := LandmarkBuilder.new()
	var root3 := builder3.build_cantina_plaza(host3, Vector3(100, 0, 50))
	_assert_equal(root3.position, Vector3(100, 0, 50), "landmark root honors a custom origin")
	_assert_equal(_count_meshes(root3), mesh_count, "offset landmark has identical geometry")

	host.queue_free()
	host2.queue_free()
	host3.queue_free()
	_finish()

func _count_meshes(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		count += 1
	for child in node.get_children():
		count += _count_meshes(child)
	return count

func _count_null_meshes(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh == null:
		count += 1
	for child in node.get_children():
		count += _count_null_meshes(child)
	return count

## Counts nodes whose name starts with `name_prefix`. Uses a prefix match rather than
## equality because Godot auto-disambiguates sibling names ("DomedHut", "DomedHut2", ...)
## when multiple children of the same parent share a base name.
func _count_named(node: Node, name_prefix: String) -> int:
	var count := 0
	if String(node.name).begins_with(name_prefix):
		count += 1
	for child in node.get_children():
		count += _count_named(child, name_prefix)
	return count

func _has_label(node: Node, text: String) -> bool:
	if node is Label3D and (node as Label3D).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false

func _finish() -> void:
	if _failures.is_empty():
		print("landmark_builder_smoke: OK")
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
