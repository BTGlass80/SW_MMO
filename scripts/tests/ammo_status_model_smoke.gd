extends SceneTree
## Pure-model smoke for scripts/rules/ammo_status_model.gd (DIV-0029 ammo HUD readout).
## Covers: should_show gating (ammo weapon vs melee/empty); readout formatting + null-safe flooring;
## the is_dry / is_low thresholds (the <20% boundary, dry, zero-capacity guard); color_key mapping to
## the wound palette (healthy/wounded/downed); and reload_happened (real reload vs pack-sell vs swap).

const Ammo = preload("res://scripts/rules/ammo_status_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- should_show: only ammo-tracked weapons get a readout ---
	_assert_equal(Ammo.should_show({"uses_ammo": true, "shots": 6, "capacity": 6, "packs": 2}), true, "ammo weapon shows")
	_assert_equal(Ammo.should_show({"uses_ammo": false, "packs": 2}), false, "melee/no-ammo hides")
	_assert_equal(Ammo.should_show({}), false, "empty block hides")

	# --- readout_text: formatting + null-safe floor (no negative counts) ---
	_assert_equal(Ammo.readout_text({"uses_ammo": true, "shots": 4, "capacity": 6, "packs": 2}), "Ammo 4/6 | packs 2", "readout format")
	_assert_equal(Ammo.readout_text({"uses_ammo": true, "shots": 100, "capacity": 100, "packs": 0}), "Ammo 100/100 | packs 0", "readout full")
	_assert_equal(Ammo.readout_text({"uses_ammo": true, "shots": -3, "capacity": 6, "packs": -1}), "Ammo 0/6 | packs 0", "readout floors negatives")

	# --- is_dry: empty AND no pack ---
	_assert_equal(Ammo.is_dry({"uses_ammo": true, "shots": 0, "capacity": 6, "packs": 0}), true, "0 shots + 0 packs = dry")
	_assert_equal(Ammo.is_dry({"uses_ammo": true, "shots": 0, "capacity": 6, "packs": 1}), false, "0 shots but pack = not dry")
	_assert_equal(Ammo.is_dry({"uses_ammo": true, "shots": 1, "capacity": 6, "packs": 0}), false, "shot left = not dry")
	_assert_equal(Ammo.is_dry({"uses_ammo": false, "packs": 0}), false, "non-ammo never dry")

	# --- is_low: <20% of capacity, dry, guards ---
	_assert_equal(Ammo.is_low({"uses_ammo": true, "shots": 1, "capacity": 6, "packs": 2}), true, "1/6 (16%) is low")
	_assert_equal(Ammo.is_low({"uses_ammo": true, "shots": 2, "capacity": 6, "packs": 2}), false, "2/6 (33%) not low")
	# 100-mag boundary: 19 < 20% true, exactly 20 not (20/100 == 0.20 is not < 0.20)
	_assert_equal(Ammo.is_low({"uses_ammo": true, "shots": 19, "capacity": 100, "packs": 0}), true, "19/100 below 20%")
	_assert_equal(Ammo.is_low({"uses_ammo": true, "shots": 20, "capacity": 100, "packs": 0}), false, "20/100 at 20% not low")
	_assert_equal(Ammo.is_low({"uses_ammo": true, "shots": 0, "capacity": 6, "packs": 0}), true, "dry is low")
	_assert_equal(Ammo.is_low({"uses_ammo": true, "shots": 0, "capacity": 0, "packs": 3}), false, "zero-capacity guard")
	_assert_equal(Ammo.is_low({"uses_ammo": false, "packs": 0}), false, "non-ammo never low")

	# --- color_key: dry -> downed (red), low -> wounded (orange), else healthy (green) ---
	_assert_equal(Ammo.color_key({"uses_ammo": true, "shots": 6, "capacity": 6, "packs": 2}), "healthy", "full = healthy key")
	_assert_equal(Ammo.color_key({"uses_ammo": true, "shots": 1, "capacity": 6, "packs": 2}), "wounded", "low = wounded key")
	_assert_equal(Ammo.color_key({"uses_ammo": true, "shots": 0, "capacity": 6, "packs": 1}), "wounded", "empty-with-pack = wounded key")
	_assert_equal(Ammo.color_key({"uses_ammo": true, "shots": 0, "capacity": 6, "packs": 0}), "downed", "dry = downed key")
	_assert_equal(Ammo.color_key({"uses_ammo": false, "packs": 0}), "healthy", "non-ammo = healthy key")

	# --- reload_happened: same weapon, packs drop AND magazine refills ---
	var before := {"uses_ammo": true, "weapon": "hold_out_blaster", "shots": 0, "capacity": 6, "packs": 2}
	var after_reload := {"uses_ammo": true, "weapon": "hold_out_blaster", "shots": 5, "capacity": 6, "packs": 1}
	_assert_equal(Ammo.reload_happened(before, after_reload), true, "packs drop + shots rise = reload")
	# a normal shot (shots fall, packs unchanged) is NOT a reload
	_assert_equal(Ammo.reload_happened(
		{"uses_ammo": true, "weapon": "hold_out_blaster", "shots": 5, "capacity": 6, "packs": 2},
		{"uses_ammo": true, "weapon": "hold_out_blaster", "shots": 4, "capacity": 6, "packs": 2}), false, "plain shot not reload")
	# a vendor pack SELL (packs drop, shots unchanged) is NOT a reload
	_assert_equal(Ammo.reload_happened(
		{"uses_ammo": true, "weapon": "hold_out_blaster", "shots": 6, "capacity": 6, "packs": 2},
		{"uses_ammo": true, "weapon": "hold_out_blaster", "shots": 6, "capacity": 6, "packs": 1}), false, "pack sell not reload")
	# a weapon SWAP (different key) is NOT a reload even if packs fell + shots rose
	_assert_equal(Ammo.reload_happened(
		{"uses_ammo": true, "weapon": "hold_out_blaster", "shots": 0, "capacity": 6, "packs": 2},
		{"uses_ammo": true, "weapon": "blaster_pistol", "shots": 100, "capacity": 100, "packs": 1}), false, "weapon swap not reload")
	# a prev/cur that isn't an ammo weapon -> never a reload
	_assert_equal(Ammo.reload_happened({"uses_ammo": false}, after_reload), false, "non-ammo prev not reload")
	_assert_equal(Ammo.reload_happened({}, {}), false, "empty diff not reload")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("ammo_status_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
