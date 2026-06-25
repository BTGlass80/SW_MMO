extends RefCounted

const WOUND_NAMES := {
	0: "OK",
	1: "Stunned",
	2: "Wounded",
	3: "Incapacitated",
	4: "Mortally Wounded",
}

static func telemetry_line(state: Dictionary, live_enabled: bool, accumulator: float, tick_seconds: float, volley_count: int, armed_source_count: int = -1, next_source_count: int = -1, audit_summary: Dictionary = {}, suppressed_source_count: int = 0, pinned_source_count: int = 0, covered_source_count: int = 0, fallback_source_count: int = 0, coordinating_source_count: int = 0, flanking_source_count: int = 0, reloading_source_count: int = 0, hesitating_source_count: int = 0, covering_source_count: int = 0) -> String:
	var next_volley := maxf(tick_seconds - accumulator, 0.0)
	var live_text := "running %.1fs" % next_volley if live_enabled else "paused"
	var cover_text := "half" if int(state.get("player_cover_level", 0)) > 0 else "none"
	var defense_text := _defense_text(String(state.get("player_defense", "none")))
	var cp_text := "atk %d / soak %d" % [
		int(state.get("pending_attack_cp", 0)),
		int(state.get("pending_soak_cp", 0)),
	]
	var fp_text := "active" if bool(state.get("force_point_active", false)) else "%d ready" % int(state.get("player_force_points", 0))
	var wound_text := String(WOUND_NAMES.get(int(state.get("player_wound_severity", 0)), "Down"))
	var armed_text := _armed_text(armed_source_count, next_source_count)
	var suppression_text := _suppression_text(suppressed_source_count)
	var pinned_text := _pinned_text(pinned_source_count)
	var covered_text := _covered_text(covered_source_count)
	var fallback_text := _fallback_text(fallback_source_count)
	var coordinating_text := _coordinating_text(coordinating_source_count)
	var flanking_text := _flanking_text(flanking_source_count)
	var reloading_text := _reloading_text(reloading_source_count)
	var hesitating_text := _hesitating_text(hesitating_source_count)
	var covering_text := _covering_text(covering_source_count)
	var audit_text := _audit_text(audit_summary)
	return "Range state | pressure %s | %s%s | cover %s | defense %s | CP %s | FP %s | wound %s | volleys %d%s" % [
		live_text,
		armed_text,
		suppression_text + pinned_text + covered_text + fallback_text + coordinating_text + flanking_text + reloading_text + hesitating_text + covering_text,
		cover_text,
		defense_text,
		cp_text,
		fp_text,
		wound_text,
		maxi(volley_count, 0),
		audit_text,
	]

static func _defense_text(defense_type: String) -> String:
	match defense_type:
		"dodge":
			return "dodge queued"
		"full_dodge":
			return "full dodge queued"
		_:
			return "none"

static func _armed_text(armed_source_count: int, next_source_count: int = -1) -> String:
	if armed_source_count < 0:
		return "armed ?"
	if next_source_count < 0:
		return "armed %d" % armed_source_count
	return "armed %d / next %d" % [armed_source_count, maxi(next_source_count, 0)]

static func _suppression_text(suppressed_source_count: int) -> String:
	if suppressed_source_count <= 0:
		return ""
	return " / suppressed %d" % suppressed_source_count

static func _pinned_text(pinned_source_count: int) -> String:
	if pinned_source_count <= 0:
		return ""
	return " / pinned %d" % pinned_source_count

static func _covered_text(covered_source_count: int) -> String:
	if covered_source_count <= 0:
		return ""
	return " / covered %d" % covered_source_count

static func _fallback_text(fallback_source_count: int) -> String:
	if fallback_source_count <= 0:
		return ""
	return " / fallback %d" % fallback_source_count

static func _coordinating_text(coordinating_source_count: int) -> String:
	if coordinating_source_count <= 0:
		return ""
	return " / coordinating %d" % coordinating_source_count

static func _flanking_text(flanking_source_count: int) -> String:
	if flanking_source_count <= 0:
		return ""
	return " / flanking %d" % flanking_source_count

static func _reloading_text(reloading_source_count: int) -> String:
	if reloading_source_count <= 0:
		return ""
	return " / reloading %d" % reloading_source_count

static func _hesitating_text(hesitating_source_count: int) -> String:
	if hesitating_source_count <= 0:
		return ""
	return " / hesitating %d" % hesitating_source_count

static func _covering_text(covering_source_count: int) -> String:
	if covering_source_count <= 0:
		return ""
	return " / covering %d" % covering_source_count

static func _audit_text(audit_summary: Dictionary) -> String:
	if audit_summary.is_empty() or int(audit_summary.get("count", 0)) <= 0:
		return ""
	var kind := String(audit_summary.get("latest_kind", "")).replace("ground_range_", "")
	if kind == "":
		kind = "event"
	var valid_text := "ok" if bool(audit_summary.get("latest_valid", false)) else "invalid"
	var pressure_text := _audit_pressure_text(audit_summary)
	var armor_text := _audit_armor_text(audit_summary)
	return " | audit %s seed %d e%d %s%s%s" % [
		kind,
		int(audit_summary.get("latest_seed", -1)),
		int(audit_summary.get("latest_event_count", 0)),
		valid_text,
		pressure_text,
		armor_text,
	]

static func _audit_pressure_text(audit_summary: Dictionary) -> String:
	if not bool(audit_summary.get("latest_pressure_present", false)):
		return ""
	var text := " p%d->%d" % [
		int(audit_summary.get("latest_pressure_ready", 0)),
		int(audit_summary.get("latest_pressure_next_ready", 0)),
	]
	var suppressed := int(audit_summary.get("latest_pressure_suppressed", 0))
	var pinned := int(audit_summary.get("latest_pressure_pinned", 0))
	var covered := int(audit_summary.get("latest_pressure_covered", 0))
	var fallback := int(audit_summary.get("latest_pressure_fallback", 0))
	var coordinating := int(audit_summary.get("latest_pressure_coordinating", 0))
	var flanking := int(audit_summary.get("latest_pressure_flanking", 0))
	var reloading := int(audit_summary.get("latest_pressure_reloading", 0))
	var hesitating := int(audit_summary.get("latest_pressure_hesitating", 0))
	var covering := int(audit_summary.get("latest_pressure_covering", 0))
	if suppressed > 0:
		text += " s%d" % suppressed
	if pinned > 0:
		text += " i%d" % pinned
	if covered > 0:
		text += " c%d" % covered
	if fallback > 0:
		text += " f%d" % fallback
	if coordinating > 0:
		text += " g%d" % coordinating
	if flanking > 0:
		text += " k%d" % flanking
	if reloading > 0:
		text += " r%d" % reloading
	if hesitating > 0:
		text += " h%d" % hesitating
	if covering > 0:
		text += " v%d" % covering
	return text

static func _audit_armor_text(audit_summary: Dictionary) -> String:
	if not bool(audit_summary.get("latest_armor_present", false)):
		return ""
	var text := String(audit_summary.get("latest_armor_text", "")).strip_edges()
	if text == "":
		return ""
	return " hit %s" % text
