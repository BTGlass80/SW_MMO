extends RefCounted

static func badge_for_state(state: String) -> Dictionary:
	var normalized := state.strip_edges().to_lower()
	match normalized:
		"ready":
			return _badge("READY", Color(1.0, 0.24, 0.16))
		"waiting":
			return _badge("WAIT", Color(0.72, 0.74, 0.76))
		"covered":
			return _badge("TUCKED", Color(0.34, 0.70, 1.0))
		"covering":
			return _badge("COVER", Color(0.72, 0.44, 1.0))
		"coordinating":
			return _badge("HOLD", Color(0.92, 0.72, 0.24))
		"flanking":
			return _badge("FLANK", Color(0.96, 0.54, 0.20))
		"reloading":
			return _badge("RELOAD", Color(0.42, 0.82, 1.0))
		"hesitating":
			return _badge("HESITATE", Color(0.76, 0.64, 0.50))
		"fallback":
			return _badge("FALLBACK", Color(0.92, 0.40, 0.18))
		"suppressed":
			return _badge("SUPPRESSED", Color(0.42, 0.86, 0.46))
		"pinned":
			return _badge("PINNED", Color(0.92, 0.82, 0.22))
		"disabled":
			return _badge("DOWN", Color(0.56, 0.06, 0.05))
		"inert":
			return _badge("INERT", Color(0.50, 0.54, 0.56))
		_:
			if normalized == "":
				return _badge("UNKNOWN", Color(0.82, 0.82, 0.82))
			return _badge(normalized.to_upper(), Color(0.82, 0.82, 0.82))

static func badge_height_for_profile(profile_key: String) -> float:
	if profile_key == "walker_armor_plate":
		return 2.05
	return 1.45

static func explanation_for_state(state: String) -> String:
	var normalized := state.strip_edges().to_lower()
	match normalized:
		"ready":
			return "armed to fire on this live tick"
		"waiting":
			return "armed, cadence not ready"
		"covered":
			return "tucked behind cover"
		"covering":
			return "applying covering pressure"
		"coordinating":
			return "holding for fire-team timing"
		"flanking":
			return "repositioning"
		"reloading":
			return "cycling weapon"
		"hesitating":
			return "morale hesitation"
		"fallback":
			return "falling back from damage"
		"suppressed":
			return "suppressed by recent hit"
		"pinned":
			return "pinned by near miss"
		"disabled":
			return "disabled by wounds"
		"inert":
			return "not a return-fire source"
		_:
			return "unclassified live state"

static func _badge(text: String, color: Color) -> Dictionary:
	return {
		"visible": true,
		"text": text,
		"color": color,
	}
