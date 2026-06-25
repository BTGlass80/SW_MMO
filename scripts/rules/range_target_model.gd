extends RefCounted

static func can_return_fire(profile: Dictionary, wound_severity: int) -> bool:
	if wound_severity >= 3:
		return false
	return _pool_has_dice(profile.get("attack_pool", {})) and _pool_has_dice(profile.get("damage_pool", {}))

static func can_fire_on_live_tick(profile: Dictionary, wound_severity: int, tick_index: int) -> bool:
	if not can_return_fire(profile, wound_severity):
		return false
	if is_suppressed_on_live_tick(profile, tick_index):
		return false
	if is_pinned_on_live_tick(profile, tick_index):
		return false
	if is_falling_back_on_live_tick(profile, tick_index):
		return false
	if is_hesitating_on_live_tick(profile, wound_severity, tick_index):
		return false
	if is_peek_covered_on_live_tick(profile, tick_index):
		return false
	if is_flanking_on_live_tick(profile, tick_index):
		return false
	if is_reloading_on_live_tick(profile, tick_index):
		return false
	if is_covering_on_live_tick(profile, tick_index):
		return false
	var cadence := maxi(int(profile.get("fire_cadence_ticks", 1)), 1)
	var phase := int(profile.get("fire_phase_ticks", 0))
	return posmod(maxi(tick_index, 0) - phase, cadence) == 0

static func live_tick_state(profile: Dictionary, wound_severity: int, tick_index: int) -> String:
	if wound_severity >= 3:
		return "disabled"
	if not can_return_fire(profile, wound_severity):
		return "inert"
	if is_suppressed_on_live_tick(profile, tick_index):
		return "suppressed"
	if is_pinned_on_live_tick(profile, tick_index):
		return "pinned"
	if is_falling_back_on_live_tick(profile, tick_index):
		return "fallback"
	if is_hesitating_on_live_tick(profile, wound_severity, tick_index):
		return "hesitating"
	if is_peek_covered_on_live_tick(profile, tick_index):
		return "covered"
	if is_flanking_on_live_tick(profile, tick_index):
		return "flanking"
	if is_reloading_on_live_tick(profile, tick_index):
		return "reloading"
	if is_covering_on_live_tick(profile, tick_index):
		return "covering"
	if can_fire_on_live_tick(profile, wound_severity, tick_index):
		return "ready"
	return "waiting"

static func live_tick_summary(entries: Array, tick_index: int) -> Dictionary:
	var summary := {
		"armed": 0,
		"ready": 0,
		"waiting": 0,
		"suppressed": 0,
		"pinned": 0,
		"fallback": 0,
		"hesitating": 0,
		"covered": 0,
		"coordinating": 0,
		"flanking": 0,
		"reloading": 0,
		"covering": 0,
		"disabled": 0,
		"inert": 0,
	}
	var states := live_tick_states(entries, tick_index)
	for index in range(entries.size()):
		var entry_variant: Variant = entries[index]
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var profile: Dictionary = entry.get("profile", entry)
		var wound_severity := int(entry.get("wound_severity", 0))
		var state := String(states[index])
		if can_return_fire(profile, wound_severity):
			summary["armed"] = int(summary["armed"]) + 1
		if summary.has(state):
			summary[state] = int(summary[state]) + 1
	return summary

static func live_tick_states(entries: Array, tick_index: int) -> Array:
	var states := []
	var selected_index_by_group := {}
	var selected_priority_by_group := {}
	for index in range(entries.size()):
		var entry_variant: Variant = entries[index]
		if typeof(entry_variant) != TYPE_DICTIONARY:
			states.append("inert")
			continue
		var entry: Dictionary = entry_variant
		var profile: Dictionary = entry.get("profile", entry)
		var wound_severity := int(entry.get("wound_severity", 0))
		var state := live_tick_state(profile, wound_severity, tick_index)
		states.append(state)
		if state != "ready":
			continue
		var coordination_group := String(profile.get("coordination_group", ""))
		if coordination_group == "":
			continue
		var priority := int(profile.get("coordination_priority", index))
		if not selected_index_by_group.has(coordination_group):
			selected_index_by_group[coordination_group] = index
			selected_priority_by_group[coordination_group] = priority
			continue
		var selected_priority := int(selected_priority_by_group[coordination_group])
		if priority < selected_priority:
			states[int(selected_index_by_group[coordination_group])] = "coordinating"
			selected_index_by_group[coordination_group] = index
			selected_priority_by_group[coordination_group] = priority
		else:
			states[index] = "coordinating"
	return states

static func is_suppressed_on_live_tick(profile: Dictionary, tick_index: int) -> bool:
	return tick_index < int(profile.get("suppressed_until_tick", -1))

static func is_pinned_on_live_tick(profile: Dictionary, tick_index: int) -> bool:
	return tick_index < int(profile.get("pinned_until_tick", -1))

static func pinning_resume_tick(profile: Dictionary, current_tick: int, attack_margin: int) -> int:
	var pinning_ticks := maxi(int(profile.get("pinning_ticks", 0)), 0)
	if pinning_ticks <= 0 or attack_margin >= 0:
		return current_tick
	var pinning_margin := maxi(int(profile.get("pinning_miss_margin", 0)), 0)
	if pinning_margin <= 0 or attack_margin < -pinning_margin:
		return current_tick
	return current_tick + pinning_ticks + 1

static func is_falling_back_on_live_tick(profile: Dictionary, tick_index: int) -> bool:
	return tick_index < int(profile.get("fallback_until_tick", -1))

static func is_hesitating_on_live_tick(profile: Dictionary, wound_severity: int, tick_index: int) -> bool:
	var hold_ticks := maxi(int(profile.get("morale_hold_ticks", 0)), 0)
	var cadence_ticks := maxi(int(profile.get("morale_cadence_ticks", 0)), 0)
	var threshold := maxi(int(profile.get("morale_min_wound_severity", 1)), 1)
	if tick_index < 0 or hold_ticks <= 0 or cadence_ticks <= 0 or wound_severity < threshold:
		return false
	var cycle_ticks: int = maxi(cadence_ticks, hold_ticks)
	var phase := int(profile.get("morale_phase_ticks", profile.get("fire_phase_ticks", 0)))
	var cycle_pos := posmod(maxi(tick_index, 0) - phase, cycle_ticks)
	return cycle_pos < hold_ticks

static func is_peek_covered_on_live_tick(profile: Dictionary, tick_index: int) -> bool:
	var exposed_ticks := maxi(int(profile.get("peek_exposed_ticks", 0)), 0)
	var covered_ticks := maxi(int(profile.get("peek_covered_ticks", 0)), 0)
	if tick_index < 0 or exposed_ticks <= 0 or covered_ticks <= 0:
		return false
	var cycle_ticks := exposed_ticks + covered_ticks
	var phase := int(profile.get("peek_phase_ticks", profile.get("fire_phase_ticks", 0)))
	var cycle_pos := posmod(maxi(tick_index, 0) - phase, cycle_ticks)
	return cycle_pos >= exposed_ticks

static func is_flanking_on_live_tick(profile: Dictionary, tick_index: int) -> bool:
	var flank_ticks := maxi(int(profile.get("flank_move_ticks", 0)), 0)
	var cadence_ticks := maxi(int(profile.get("flank_cadence_ticks", 0)), 0)
	if tick_index < 0 or flank_ticks <= 0 or cadence_ticks <= 0:
		return false
	var cycle_ticks: int = maxi(cadence_ticks, flank_ticks)
	var phase := int(profile.get("flank_phase_ticks", profile.get("fire_phase_ticks", 0)))
	var cycle_pos := posmod(maxi(tick_index, 0) - phase, cycle_ticks)
	return cycle_pos < flank_ticks

static func is_reloading_on_live_tick(profile: Dictionary, tick_index: int) -> bool:
	var reload_ticks := maxi(int(profile.get("reload_ticks", 0)), 0)
	var cadence_ticks := maxi(int(profile.get("reload_cadence_ticks", 0)), 0)
	if tick_index < 0 or reload_ticks <= 0 or cadence_ticks <= 0:
		return false
	var cycle_ticks: int = maxi(cadence_ticks, reload_ticks)
	var phase := int(profile.get("reload_phase_ticks", profile.get("fire_phase_ticks", 0)))
	var cycle_pos := posmod(maxi(tick_index, 0) - phase, cycle_ticks)
	return cycle_pos < reload_ticks

static func is_covering_on_live_tick(profile: Dictionary, tick_index: int) -> bool:
	var cover_ticks := maxi(int(profile.get("covering_fire_ticks", 0)), 0)
	var cadence_ticks := maxi(int(profile.get("covering_fire_cadence_ticks", 0)), 0)
	if tick_index < 0 or cover_ticks <= 0 or cadence_ticks <= 0:
		return false
	var cycle_ticks: int = maxi(cadence_ticks, cover_ticks)
	var phase := int(profile.get("covering_fire_phase_ticks", profile.get("fire_phase_ticks", 0)))
	var cycle_pos := posmod(maxi(tick_index, 0) - phase, cycle_ticks)
	return cycle_pos < cover_ticks

static func _pool_has_dice(pool: Variant) -> bool:
	if typeof(pool) != TYPE_DICTIONARY:
		return false
	return int(pool.get("dice", 0)) > 0 or int(pool.get("pips", 0)) > 0
