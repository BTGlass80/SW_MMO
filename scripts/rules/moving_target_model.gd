extends RefCounted

static func local_offset(elapsed_seconds: float, axis_name: String, distance: float, speed: float, pattern: String = "sine") -> Vector3:
	var axis := _axis_for_name(axis_name)
	var safe_distance := maxf(distance, 0.0)
	if safe_distance <= 0.0:
		return Vector3.ZERO
	var safe_speed := maxf(speed, 0.0)
	if safe_speed <= 0.0:
		return Vector3.ZERO
	var phase := _phase_for_pattern(elapsed_seconds, safe_speed, pattern)
	return axis * safe_distance * phase

static func should_move(wound_severity: int, motion_paused: bool = false) -> bool:
	return not motion_paused and wound_severity < 3

static func _axis_for_name(axis_name: String) -> Vector3:
	match axis_name.strip_edges().to_lower():
		"x":
			return Vector3.RIGHT
		"z":
			return Vector3.FORWARD
		"y":
			return Vector3.UP
		_:
			return Vector3.RIGHT

static func _phase_for_pattern(elapsed_seconds: float, speed: float, pattern: String) -> float:
	match pattern.strip_edges().to_lower():
		"patrol", "triangle":
			var cycle := fposmod(elapsed_seconds * speed, 4.0)
			if cycle < 1.0:
				return cycle
			if cycle < 3.0:
				return 2.0 - cycle
			return cycle - 4.0
		_:
			return sin(elapsed_seconds * speed)
