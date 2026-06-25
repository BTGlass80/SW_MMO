extends RefCounted

static func is_modal_overlay_active(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("modal_gameplay_overlay"):
		if is_visible_modal_node(node):
			return true
	return false

static func is_visible_modal_node(node: Node) -> bool:
	if node is CanvasLayer:
		return (node as CanvasLayer).visible
	if node is CanvasItem:
		return (node as CanvasItem).visible
	return false

static func should_show_ground_gameplay_layer(modal_active: bool) -> bool:
	return not modal_active
