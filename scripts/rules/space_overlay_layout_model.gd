extends RefCounted

static func layout_for_viewport(viewport_size: Vector2) -> Dictionary:
	var safe_size := Vector2(maxf(viewport_size.x, 640.0), maxf(viewport_size.y, 480.0))
	var panel_width := clampf(safe_size.x * 0.32, 360.0, 500.0)
	var map_origin := Vector2(32.0, 154.0)
	var map_size := Vector2(
		maxf(440.0, safe_size.x - panel_width - 76.0),
		maxf(320.0, safe_size.y - 190.0)
	)
	var panel_x := map_origin.x + map_size.x + 28.0
	var available_panel_width := maxf(320.0, safe_size.x - panel_x - 32.0)
	return {
		"viewport_size": safe_size,
		"panel_width_budget": panel_width,
		"mode_status_position": Vector2(34.0, 82.0),
		"mode_status_size": Vector2(map_size.x, 38.0),
		"traffic_status_position": Vector2(34.0, 122.0),
		"traffic_status_size": Vector2(map_size.x, 28.0),
		"map_origin": map_origin,
		"map_size": map_size,
		"panel_x": panel_x,
		"panel_width": available_panel_width,
	}
