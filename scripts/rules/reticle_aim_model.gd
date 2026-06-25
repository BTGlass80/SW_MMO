extends RefCounted

static func aim_point_for_mouse_mode(mouse_mode: int, viewport_size: Vector2, mouse_position: Vector2) -> Vector2:
	if mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return viewport_size * 0.5
	return mouse_position
