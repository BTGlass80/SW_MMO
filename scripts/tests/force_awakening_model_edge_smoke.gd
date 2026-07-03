extends SceneTree
## HARDENING smoke for the pure Force-awakening track (scripts/rules/force_awakening_model.gd).
## Adversarial edge-case coverage beyond force_awakening_model_smoke.gd: try_advance never fires
## while still DORMANT (no matter how high attunement is, it needs the manifest roll first),
## try_manifest/try_awaken are no-ops on the wrong phase, unknown signal keys smuggled directly into
## an unlock dict are ignored by attunement scoring, apply_completion preserves an EXISTING non-empty
## force_skills block instead of overwriting it, apply_completion synthesizes a valid unlock from a
## sheet with no force_unlock key at all, and a characterization of the (documented, not "fixed")
## same-tick cascade where manifest+advance+awaken can all fire in one director_tick call. All rolls
## take a SEEDED RNG.

const Awaken = preload("res://scripts/rules/force_awakening_model.gd")
const ForceSkills = preload("res://scripts/rules/force_skills_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- try_advance never fires from DORMANT, no matter how high the attunement is ---
	var hot_dormant := {"phase": Awaken.PHASE_DORMANT, "signals": {"disables": 100}}  # attunement 200
	var adv := Awaken.try_advance(hot_dormant)
	_assert_equal(int(adv["phase"]), Awaken.PHASE_DORMANT, "try_advance never leaves DORMANT; it needs the manifest roll first")
	_assert_equal(bool(adv["advanced"]), false, "advanced flag is false when still dormant")

	# --- try_manifest is a no-op once already in-progress (not dormant) ---
	var in_progress := {"phase": 2, "signals": {"disables": 100}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var m := Awaken.try_manifest(rng, in_progress, 0)
	_assert_equal(bool(m["manifested"]), false, "try_manifest is a no-op on a non-dormant (already in-progress) track")
	_assert_equal(int(m["unlock"]["phase"]), 2, "phase is untouched by a no-op manifest attempt")

	# --- try_awaken is a no-op on any phase other than 4 ---
	var phase3 := {"phase": 3, "signals": {"disables": 100}}
	var a3 := Awaken.try_awaken(rng, phase3)
	_assert_equal(bool(a3["awakened"]), false, "try_awaken is a no-op at phase 3 (must be exactly phase 4)")
	var complete_already := {"phase": Awaken.PHASE_COMPLETE, "signals": {}}
	var a5 := Awaken.try_awaken(rng, complete_already)
	_assert_equal(bool(a5["awakened"]), false, "try_awaken is a no-op on an already-COMPLETE track")

	# --- unknown signal keys smuggled directly into an unlock dict (bypassing record_signal) are ignored ---
	var smuggled := {"phase": Awaken.PHASE_DORMANT, "signals": {"disables": 5, "totally_made_up": 999999}}
	_assert_equal(Awaken.attunement_score(smuggled), 10, "an unknown signal key present in the raw dict contributes nothing to the score (5 disables * weight 2 = 10)")

	# --- record_signal default amount is 1 ---
	var one := Awaken.record_signal(Awaken.initial_unlock(), "cp_spent")  # no amount arg
	_assert_equal(int((one["signals"] as Dictionary)["cp_spent"]), 1, "record_signal defaults amount to 1 when omitted")

	# --- apply_completion PRESERVES an existing non-empty force_skills block ---
	var custom_skills := {"control": 7, "sense": 2, "alter": 0}
	var sheet_with_skills := {"force_unlock": {"phase": 4, "signals": {}}, "force_skills": custom_skills}
	var flipped := Awaken.apply_completion(sheet_with_skills)
	_assert_equal(int((flipped["force_skills"] as Dictionary)["control"]), 7, "an existing non-empty force_skills block is NOT clobbered by apply_completion")

	# --- apply_completion on a sheet with NO force_unlock key at all synthesizes a valid COMPLETE one ---
	var bare_sheet := {"attributes": {"strength": "2D"}}
	var bare_flipped := Awaken.apply_completion(bare_sheet)
	_assert_equal(bool(bare_flipped["force_sensitive"]), true, "apply_completion flips force_sensitive even from a sheet with no prior unlock state")
	_assert_equal(int((bare_flipped["force_unlock"] as Dictionary)["phase"]), Awaken.PHASE_COMPLETE, "a synthesized unlock is set to COMPLETE")
	_assert_true(ForceSkills.can_use_force(bare_flipped), "the synthesized sheet can now use the Force")

	# --- CHARACTERIZATION (not a "should", just locking in current behavior): a single director_tick
	# call CAN cascade DORMANT all the way to COMPLETE when attunement is already maxed out before the
	# first roll (manifest succeeds AND the awaken roll succeeds in the same call). The reported `event`
	# is whichever stage ran LAST ("awaken" wins over "manifest" when both fire in one tick).
	var cascade_rng := RandomNumberGenerator.new()
	cascade_rng.seed = 777
	var cascade_result := {}
	for i in range(5000):
		var fresh := {"phase": Awaken.PHASE_DORMANT, "signals": {"disables": 60}}  # attunement 120, past every threshold
		var r := Awaken.director_tick(cascade_rng, fresh, 0)
		if int(r["phase"]) == Awaken.PHASE_COMPLETE:
			cascade_result = r
			break
	_assert_true(not cascade_result.is_empty(), "found a seeded draw where one director_tick call cascades DORMANT straight to COMPLETE")
	_assert_equal(String(cascade_result.get("event", "")), "awaken", "the reported event for a same-tick manifest+awaken cascade is 'awaken' (documented current behavior)")
	_assert_equal(bool(cascade_result.get("changed", false)), true, "the cascading tick reports changed=true")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("force_awakening_model_edge_smoke: OK")
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
