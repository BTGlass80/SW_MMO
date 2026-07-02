extends SceneTree
## Smoke for the pure SWG-Village Force-awakening track (Wave F / DIV-0011): deterministic signal
## accrual + attunement scoring, the rare cap-gated manifest roll, deterministic phase advancement,
## the phase-4 awaken roll, and the completion flip. All rolls take a SEEDED, server-owned RNG.

const Awaken = preload("res://scripts/rules/force_awakening_model.gd")
const ForceSkills = preload("res://scripts/rules/force_skills_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# --- initial state + signal accrual ---
	var u := Awaken.initial_unlock()
	_assert_equal(int(u["phase"]), Awaken.PHASE_DORMANT, "starts dormant")
	_assert_equal(Awaken.attunement_score(u), 0, "no signals -> 0 attunement")
	_assert_equal(Awaken.counts_toward_cap(u), false, "dormant does NOT count toward the soft cap")

	# record_signal is non-mutating, clamps <=0, ignores unknown keys.
	var u1 := Awaken.record_signal(u, "disables", 3)      # 3 * 2 = 6
	_assert_equal(int(u["phase"]), Awaken.PHASE_DORMANT, "record_signal did not mutate the input")
	u1 = Awaken.record_signal(u1, "zones_visited", 2)     # 2 * 3 = 6  -> 12
	u1 = Awaken.record_signal(u1, "cp_spent", 4)          # 4 * 1 = 4  -> 16
	u1 = Awaken.record_signal(u1, "bogus_signal", 99)     # ignored
	u1 = Awaken.record_signal(u1, "heals_given", -5)      # clamped, ignored
	_assert_equal(Awaken.attunement_score(u1), 16, "weighted attunement = 6+6+4")

	# --- manifest gate: prerequisite + soft cap + roll ---
	var u_low := Awaken.record_signal(Awaken.initial_unlock(), "cp_spent", 5)  # attunement 5 < prereq 10
	_assert_equal(Awaken.can_manifest(u_low, 0), false, "below prereq attunement cannot manifest")
	_assert_equal(Awaken.can_manifest(u1, 0), true, "attuned + under cap CAN manifest")
	_assert_equal(Awaken.can_manifest(u1, Awaken.AWAKEN_SERVER_SOFT_CAP), false, "soft cap blocks new manifests")

	# A seeded RNG that rolls under MANIFEST_CHANCE eventually flips phase 0 -> 1.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1138
	var manifested := false
	var mu := u1
	for i in range(500):
		var r := Awaken.try_manifest(rng, mu, 0)
		mu = r["unlock"]
		if bool(r["manifested"]):
			manifested = true
			break
	_assert_equal(manifested, true, "a ~2% manifest roll succeeds within 500 seeded ticks")
	_assert_equal(int(mu["phase"]), 1, "manifest advances to phase 1")
	_assert_equal(Awaken.counts_toward_cap(mu), true, "an in-progress latent counts toward the cap")

	# --- deterministic advancement 1 -> 4 as attunement crosses thresholds ---
	var adv_unlock := {"phase": 1, "signals": {"disables": 40}}  # 40 * 2 = 80 attunement (>= 70, < 100)
	var adv := Awaken.try_advance(adv_unlock)
	_assert_equal(int(adv["phase"]), 4, "80 attunement advances phase 1 -> 4 (crosses 25/45/70)")
	_assert_equal(bool(adv["advanced"]), true, "advanced flag set")
	# Not enough for the next step stays put.
	var adv_stop := Awaken.try_advance({"phase": 1, "signals": {"cp_spent": 30}})  # 30 attunement (>=25, <45)
	_assert_equal(int(adv_stop["phase"]), 2, "30 attunement advances only 1 -> 2")

	# try_advance never enters COMPLETE (needs the awaken roll).
	var adv_max := Awaken.try_advance({"phase": 1, "signals": {"disables": 60}})  # 120 attunement
	_assert_equal(int(adv_max["phase"]), 4, "deterministic advance caps at phase 4 (COMPLETE needs the roll)")

	# --- phase-4 awaken roll -> COMPLETE ---
	var below := Awaken.try_awaken(rng, {"phase": 4, "signals": {"disables": 40}})  # 80 < 100 prereq
	_assert_equal(bool(below["awakened"]), false, "phase 4 below the 100 attunement prereq does not awaken")
	var awoke := false
	var au := {"phase": 4, "signals": {"disables": 60}}  # 120 attunement, past the prereq
	for i in range(500):
		var r := Awaken.try_awaken(rng, au)
		au = r["unlock"]
		if bool(r["awakened"]):
			awoke = true
			break
	_assert_equal(awoke, true, "the phase-4 awaken roll succeeds within 500 seeded ticks")
	_assert_equal(Awaken.is_complete(au), true, "awaken reaches COMPLETE")

	# --- director_tick single entry point + completion flip ---
	# A fully-attuned phase-4 candidate awakens through director_tick within a bounded number of ticks.
	var dt := {"phase": 4, "signals": {"disables": 60}}
	var event := ""
	for i in range(500):
		var r := Awaken.director_tick(rng, dt, 1)
		dt = r["unlock"]
		if String(r["event"]) == "awaken":
			event = "awaken"
			break
	_assert_equal(event, "awaken", "director_tick drives a ready phase-4 candidate to awaken")
	# A COMPLETE track is inert under further ticks.
	var inert := Awaken.director_tick(rng, dt, 1)
	_assert_equal(bool(inert["changed"]), false, "a COMPLETE track no longer changes")

	# apply_completion flips the sheet force-sensitive + seeds the force-skill block.
	var sheet := {"attributes": {"strength": "3D"}, "force_sensitive": false, "force_unlock": dt}
	_assert_equal(ForceSkills.can_use_force(sheet), false, "pre-completion the sheet cannot use the Force")
	var flipped := Awaken.apply_completion(sheet)
	_assert_equal(ForceSkills.can_use_force(flipped), true, "apply_completion makes the sheet force-sensitive")
	_assert_equal((flipped.get("force_skills", {}) as Dictionary).has("control"), true, "force-skill block seeded on completion")
	_assert_equal(bool(sheet["force_sensitive"]), false, "apply_completion did not mutate the input sheet")

	if _failures.is_empty():
		print("force_awakening_model_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
