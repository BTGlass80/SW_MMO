extends SceneTree
## Flow guard for the DIV-0011 Force-awakening WIRING (S16-S19). network_manager is a Node autoload
## not headlessly instantiable, so — like heal_flow_smoke / death_flow_smoke — this mirrors the server
## composition around the pure force_awakening_model: _feed_force_signal (no-op once COMPLETE),
## _awakened_count (connected-latent soft-cap denominator), and _advance_force_awakenings' completion
## path (director_tick reaches COMPLETE -> apply_completion flips force_sensitive + seeds force_skills).
## force_awakening_model_smoke covers the model itself; this locks the network wiring.

const ForceAwaken := preload("res://scripts/rules/force_awakening_model.gd")
const ForceSkills := preload("res://scripts/rules/force_skills_model.gd")

var _failures: Array[String] = []
var _rng := RandomNumberGenerator.new()

func _feed(sheet: Dictionary, key: String, amount: int) -> void:  # mirror _feed_force_signal
	var unlock: Dictionary = sheet.get("force_unlock", ForceAwaken.initial_unlock())
	if ForceAwaken.is_complete(unlock):
		return
	sheet["force_unlock"] = ForceAwaken.record_signal(unlock, key, amount)

func _count(sheets: Array) -> int:  # mirror _awakened_count
	var n := 0
	for s in sheets:
		if ForceAwaken.counts_toward_cap((s as Dictionary).get("force_unlock", {})):
			n += 1
	return n

func _advance(sheet: Dictionary, cap: int, force_now: bool) -> Dictionary:  # mirror _advance_force_awakenings step
	var unlock: Dictionary = sheet.get("force_unlock", ForceAwaken.initial_unlock())
	if ForceAwaken.is_complete(unlock):
		return {"event": "", "completed": true}
	var result: Dictionary
	if force_now:
		result = {"unlock": {"phase": ForceAwaken.PHASE_COMPLETE, "signals": unlock.get("signals", {})}, "event": "awaken"}
	else:
		result = ForceAwaken.director_tick(_rng, unlock, cap)
	var event := String(result.get("event", ""))
	if event == "":
		return {"event": "", "completed": false}
	sheet["force_unlock"] = result["unlock"]
	var completed := ForceAwaken.is_complete(result["unlock"])
	if completed:
		var flipped: Dictionary = ForceAwaken.apply_completion(sheet)
		for k in flipped:
			sheet[k] = flipped[k]  # mirror record["sheet"] = ForceAwaken.apply_completion(sheet)
	return {"event": event, "completed": completed}

func _init() -> void:
	_rng.seed = 1138

	# --- signal feed accrues, but no-ops once COMPLETE ---
	var s := {"force_unlock": ForceAwaken.initial_unlock()}
	_feed(s, "disables", 3)
	_assert_true(ForceAwaken.attunement_score(s["force_unlock"]) > 0, "feed accrues signals on an active track")
	var done := {"force_unlock": {"phase": ForceAwaken.PHASE_COMPLETE, "signals": {"disables": 1}}}
	_feed(done, "disables", 99)
	_assert_equal(int(((done["force_unlock"] as Dictionary)["signals"] as Dictionary).get("disables", 0)), 1, "feed is a no-op once COMPLETE")

	# --- soft-cap count: only phase>=1 (in-progress + awakened) latents count ---
	var dormant := {"force_unlock": {"phase": 0, "signals": {}}}
	var inprog := {"force_unlock": {"phase": 2, "signals": {}}}
	var awoke := {"force_unlock": {"phase": ForceAwaken.PHASE_COMPLETE, "signals": {}}}
	_assert_equal(_count([dormant, inprog, awoke]), 2, "cap counts in-progress + awakened, not dormant")

	# --- force_now completion flips force_sensitive + seeds force_skills ---
	var fsheet := {"force_sensitive": false, "force_unlock": {"phase": 3, "signals": {"disables": 40}}}
	var r := _advance(fsheet, 1, true)
	_assert_equal(String(r["event"]), "awaken", "force_now awakens")
	_assert_true(bool(r["completed"]), "force_now completes")
	_assert_equal(bool(fsheet["force_sensitive"]), true, "completion flips force_sensitive on the sheet")
	_assert_true(ForceSkills.can_use_force(fsheet), "an awakened sheet can use the Force")
	_assert_true((fsheet.get("force_skills", {}) as Dictionary).has("control"), "completion seeds the force-skill block")
	# A COMPLETE latent is inert under further ticks (no re-awaken).
	_assert_equal(String(_advance(fsheet, 1, false)["event"]), "", "a COMPLETE latent no longer advances")

	# --- natural path: a fully-attuned phase-4 latent awakens through the mirrored step within N ticks ---
	var nat := {"force_sensitive": false, "force_unlock": {"phase": 4, "signals": {"disables": 60}}}
	var awakened := false
	for i in range(500):
		if bool(_advance(nat, 1, false)["completed"]):
			awakened = true
			break
	_assert_true(awakened, "a ready phase-4 latent awakens naturally within 500 seeded ticks")
	_assert_equal(bool(nat["force_sensitive"]), true, "natural completion also flips force_sensitive")

	if _failures.is_empty():
		print("force_flow_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
