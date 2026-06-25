extends SceneTree

const ModalOverlayModel = preload("res://scripts/rules/modal_overlay_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	var layer := CanvasLayer.new()
	layer.visible = true
	_assert_equal(ModalOverlayModel.is_visible_modal_node(layer), true, "visible CanvasLayer modal node is active")
	layer.visible = false
	_assert_equal(ModalOverlayModel.is_visible_modal_node(layer), false, "hidden CanvasLayer modal node is inactive")

	var control := Control.new()
	control.visible = true
	_assert_equal(ModalOverlayModel.is_visible_modal_node(control), true, "visible CanvasItem modal node is active")
	control.visible = false
	_assert_equal(ModalOverlayModel.is_visible_modal_node(control), false, "hidden CanvasItem modal node is inactive")

	var plain := Node.new()
	_assert_equal(ModalOverlayModel.is_visible_modal_node(plain), false, "plain node is not a visible modal node")
	_assert_equal(ModalOverlayModel.should_show_ground_gameplay_layer(false), true, "ground layer visible without modal")
	_assert_equal(ModalOverlayModel.should_show_ground_gameplay_layer(true), false, "ground layer hidden while modal is active")
	layer.free()
	control.free()
	plain.free()

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("modal_overlay_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
