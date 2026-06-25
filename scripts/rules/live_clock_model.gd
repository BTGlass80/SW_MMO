extends RefCounted

static func ticks_for_delta(delta: float, accumulator: float, tick_seconds: float) -> Dictionary:
	var safe_tick_seconds := maxf(tick_seconds, 0.1)
	var remaining := accumulator + maxf(delta, 0.0)
	var ticks := 0
	while remaining >= safe_tick_seconds:
		ticks += 1
		remaining -= safe_tick_seconds
	return {
		"ticks": ticks,
		"accumulator": remaining,
	}
