extends SceneTree
## Headless smoke for the pure siege state machine (scripts/net/siege_state_model.gd, DIV-0021).
## Drives, on the compressed PROTOTYPE profile: config defaults + snapshot immunity, declaration
## validation (every reject reason), a FULL siege through every phase (capture at the final tally),
## an EARLY capture (hold-for-duration short-circuit), a REPEL (final tally < 75), an ABORT with
## refund (grace) vs forfeit (post-grace), a RESTART catch-up resume (bleed re-applied + pvp
## re-derived), a control-bleed span, and a mustering-only ally commit. NO RNG is required; if any
## were added it would be seeded. Everything is deterministic wall-clock math.

const Siege := preload("res://scripts/net/siege_state_model.gd")

const T0 := 1_000_000  # base wall-clock (epoch seconds) for every scenario

var _failures: Array[String] = []

func _init() -> void:
	_test_config_defaults_and_snapshot()
	_test_declaration_validation()
	_test_full_siege_capture()
	_test_early_capture()
	_test_repel()
	_test_abort_refund_and_forfeit()
	_test_restart_catch_up()
	_test_control_bleed_span()
	_test_mustering_only_ally_commit()
	_finish()

# A valid declaration params block (contested node, Dominant influence, rank 4, funded).
func _base_params(now: int) -> Dictionary:
	return {
		"siege_id": "sg_test",
		"claim_id": "clm1", "node_id": "node1", "zone_id": "zoneA",
		"defender_org_id": "org_def", "attacker_org_id": "org_atk",
		"declared_by_char_id": "char_leader",
		"declarer_rank": 4, "attacker_influence": 40, "attacker_treasury": 10000,
		"zone_security_base": "contested", "now": now,
	}

# --- §8 defaults + snapshot immunity ---
func _test_config_defaults_and_snapshot() -> void:
	var d := Siege.default_config()
	_assert_equal(d["mustering_hours"], 24.0, "deliberate default mustering_hours = 24")
	_assert_equal(d["assault_count"], 3, "deliberate default assault_count = 3")
	_assert_equal(d["cooldown_hours"], 168.0, "deliberate default cooldown_hours = 168")
	_assert_equal(d["capture_threshold"], 75.0, "capture threshold HIGH = 75")
	_assert_equal(d["attacker_min_influence"], 40, "attacker min influence = Dominant 40")
	_assert_equal(d["control_per_guard_defeated"], 12.0, "guard-defeated control swing = 12")

	var p := Siege.prototype_config()
	_assert_equal(p["mustering_hours"], 0.25, "prototype mustering compressed to 0.25h")
	_assert_equal(p["assault_count"], 2, "prototype assault_count = 2")
	_assert_equal(p["capture_threshold"], 75.0, "prototype keeps the 75 threshold (mechanics unchanged)")
	_assert_equal(p["control_per_guard_defeated"], 12.0, "prototype keeps scoring deltas")

	# Constructor default is the prototype profile.
	var m: Object = Siege.new()
	_assert_equal(float(m.config["mustering_hours"]), 0.25, "constructor default = prototype profile")

	# Snapshot at declaration is immune to a later retune of the model's live config.
	m.declare(_base_params(T0))
	m.config["capture_threshold"] = 999.0
	m.config["mustering_hours"] = 999.0
	_assert_equal(float(m.get_siege("sg_test")["config"]["capture_threshold"]), 75.0, "snapshot immune to retune (threshold)")
	_assert_equal(float(m.get_siege("sg_test")["config"]["mustering_hours"]), 0.25, "snapshot immune to retune (timers)")

	# A model built with the deliberate config snapshots the deliberate timers.
	var md: Object = Siege.new(Siege.default_config())
	md.declare(_base_params(T0))
	_assert_equal(float(md.get_siege("sg_test")["config"]["mustering_hours"]), 24.0, "deliberate-profile siege snapshots 24h mustering")

# --- §2 declaration validation (every reject path) ---
func _test_declaration_validation() -> void:
	var m: Object = Siege.new()

	var p_secured := _base_params(T0)
	p_secured["zone_security_base"] = "secured"
	_assert_equal(String(m.validate_declaration(p_secured)["reason"]), "base_not_contestable", "secured base rejected")

	var p_inf := _base_params(T0)
	p_inf["attacker_influence"] = 39
	_assert_equal(String(m.validate_declaration(p_inf)["reason"]), "influence_too_low", "below Dominant influence rejected")

	var p_rank := _base_params(T0)
	p_rank["declarer_rank"] = 3
	_assert_equal(String(m.validate_declaration(p_rank)["reason"]), "rank_too_low", "below rank 4 rejected")

	var p_broke := _base_params(T0)
	p_broke["attacker_treasury"] = 9999
	_assert_equal(String(m.validate_declaration(p_broke)["reason"]), "insufficient_treasury", "under war-chest cost rejected")

	# A lawless base is contestable.
	var p_lawless := _base_params(T0)
	p_lawless["zone_security_base"] = "lawless"
	_assert_true(bool(m.validate_declaration(p_lawless)["ok"]), "lawless base is contestable")

	# A clean declaration passes and records the siege + escrow.
	var d: Dictionary = m.declare(_base_params(T0))
	_assert_true(bool(d["ok"]), "clean declaration accepted")
	_assert_equal(int(d["war_chest_credits"]), 10000, "war-chest escrowed = 10000")
	_assert_equal(m.state_of("sg_test"), "declared", "fresh siege is in declared")
	_assert_equal(bool(m.pvp_consent_for("sg_test")["active"]), false, "no pvp consent in declared")

	# Per-node: a second attacker cannot siege the same live node.
	var p_same_node := _base_params(T0)
	p_same_node["attacker_org_id"] = "org_other"
	p_same_node["siege_id"] = "sg_other"
	_assert_equal(String(m.validate_declaration(p_same_node)["reason"]), "node_under_siege", "node already under siege rejected")

	# Per-org concurrency: the same attacker cannot open a second outgoing siege on another node.
	var p_other_node := _base_params(T0)
	p_other_node["node_id"] = "node2"
	p_other_node["siege_id"] = "sg_second"
	_assert_equal(String(m.validate_declaration(p_other_node)["reason"]), "concurrency_cap", "outgoing concurrency cap rejected")

# --- FULL siege through every phase, ending captured at the final tally ---
func _test_full_siege_capture() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0))

	# Grace window: advancing before the deadline does not transition.
	m.advance("sg_test", T0 + 100)
	_assert_equal(m.state_of("sg_test"), "declared", "still declared inside grace")

	# grace end (T0+180) -> mustering; schedule computed.
	m.advance("sg_test", T0 + 180)
	_assert_equal(m.state_of("sg_test"), "mustering", "grace end -> mustering")
	var s: Dictionary = m.get_siege("sg_test")
	var windows: Array = s["schedule"]["assault_windows"]
	_assert_equal(windows.size(), 2, "prototype schedules 2 assault windows")
	# mustering end = (T0+180)+900 = T0+1080 = assault#0 start.
	_assert_equal(int(windows[0]["start_unix"]), T0 + 1080, "assault#0 start = mustering end")
	_assert_equal(int(windows[0]["end_unix"]), T0 + 1440, "assault#0 end = start + window")
	_assert_equal(int(windows[1]["start_unix"]), T0 + 1800, "assault#1 start = a0 end + lull")
	_assert_equal(int(windows[1]["end_unix"]), T0 + 2160, "assault#1 end")
	_assert_equal(bool(m.pvp_consent_for("sg_test")["active"]), false, "no pvp consent in mustering")

	# assault#0 start.
	m.advance("sg_test", T0 + 1080)
	_assert_equal(m.state_of("sg_test"), "assault", "mustering end -> assault#0")
	_assert_equal(int(m.get_siege("sg_test")["schedule"]["current_assault_index"]), 0, "current assault index 0")
	_assert_equal(bool(m.pvp_consent_for("sg_test")["active"]), true, "pvp consent ACTIVE in assault")

	# A modest attacker gain in assault#0 (guard defeat = +12, stays < 75).
	var ev: Dictionary = m.apply_scoring_event("sg_test", {"kind": "guard_defeated", "char_id": "c1", "org_id": "org_atk"}, T0 + 1100)
	_assert_true(bool(ev["ok"]), "guard_defeated scored in assault")
	_assert_equal(float(m.get_siege("sg_test")["control_meter"]["value"]), 12.0, "control = 12 after guard defeat")
	# Audit points accrue unclamped.
	_assert_equal(float(m.get_siege("sg_test")["score"]["attacker_points"]), 10.0, "guard defeat = 10 audit points")

	# assault#0 window end -> lull (more windows remain).
	m.advance("sg_test", T0 + 1440)
	_assert_equal(m.state_of("sg_test"), "lull", "assault#0 end -> lull")
	_assert_equal(int(m.get_siege("sg_test")["schedule"]["current_assault_index"]), 1, "lull advances index to 1")
	_assert_equal(bool(m.pvp_consent_for("sg_test")["active"]), false, "no pvp consent in lull")
	_assert_equal(float(m.get_siege("sg_test")["control_meter"]["value"]), 12.0, "control unchanged at lull entry")

	# assault#1 start (T0+1800): lull bled 360s at 60/h = -6 -> 12-6 = 6.
	m.advance("sg_test", T0 + 1800)
	_assert_equal(m.state_of("sg_test"), "assault", "lull end -> assault#1")
	_assert_true(is_equal_approx(float(m.get_siege("sg_test")["control_meter"]["value"]), 6.0), "lull bleed 12 -> 6 by assault#1")

	# Build to 66 early (4 objectives), then cross 75 near the very end so the final TALLY (not the
	# hold-for-duration short-circuit) decides it.
	for i in 4:
		m.apply_scoring_event("sg_test", {"kind": "objective", "side": "attacker", "char_id": "c1", "org_id": "org_atk"}, T0 + 1810)
	_assert_true(is_equal_approx(float(m.get_siege("sg_test")["control_meter"]["value"]), 66.0), "4 objectives -> 66")
	# 30 s before window end: +12 -> 78 (>= 75), but only 30 s < 60 s hold, so no early capture.
	m.apply_scoring_event("sg_test", {"kind": "guard_defeated", "char_id": "c1", "org_id": "org_atk"}, T0 + 2130)
	_assert_true(is_equal_approx(float(m.get_siege("sg_test")["control_meter"]["value"]), 78.0), "late guard defeat -> 78")

	# assault#1 window end -> resolution (final tally, 78 >= 75 = captured) -> cooldown.
	m.advance("sg_test", T0 + 2160)
	_assert_equal(m.state_of("sg_test"), "cooldown", "final assault end -> cooldown")
	var oc: Dictionary = m.get_siege("sg_test")["outcome"]
	_assert_equal(String(oc["result"]), "captured", "final tally >= 75 -> captured")
	_assert_equal(bool(oc["early_capture"]), false, "captured via final tally, not early")
	_assert_true(is_equal_approx(float(oc["final_control"]), 78.0), "final control recorded = 78")
	_assert_equal(String(oc["war_chest_disposition"]), "forfeit", "war-chest forfeit on resolution")
	_assert_equal(int(m.get_siege("sg_test")["war_chest_credits"]), 0, "war-chest zeroed at cooldown")
	# Node is still locked during the cooldown state.
	_assert_equal(String(m.is_node_available("node1", T0 + 2200)["reason"]), "node_in_cooldown", "node locked during cooldown")

	# cooldown deadline (T0+2160 + 1800 = T0+3960) -> archive captured; node released.
	m.advance("sg_test", T0 + 3960)
	_assert_equal(m.state_of("sg_test"), "captured", "cooldown end -> captured archive")
	_assert_equal(bool(m.pvp_consent_for("sg_test")["active"]), false, "no pvp consent when archived")
	_assert_true(bool(m.is_node_available("node1", T0 + 3961)["available"]), "node released after cooldown archive")

# --- EARLY capture: hold >= threshold for capture_hold_seconds short-circuits to resolution ---
func _test_early_capture() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0))
	m.advance("sg_test", T0 + 1080)  # -> assault#0
	# 5 objectives = 75 (>= threshold) -> hold_since set at T0+1090.
	for i in 5:
		m.apply_scoring_event("sg_test", {"kind": "objective", "side": "attacker", "org_id": "org_atk"}, T0 + 1090)
	_assert_true(is_equal_approx(float(m.get_siege("sg_test")["control_meter"]["value"]), 75.0), "5 objectives -> 75")
	_assert_equal(int(m.get_siege("sg_test")["control_meter"]["hold_since_unix"]), T0 + 1090, "hold_since set on reaching threshold")

	# 60 s later (still inside the 360 s window) the hold-for-duration fires early capture.
	m.advance("sg_test", T0 + 1150)
	_assert_equal(m.state_of("sg_test"), "cooldown", "early capture short-circuits to resolution->cooldown")
	var oc: Dictionary = m.get_siege("sg_test")["outcome"]
	_assert_equal(String(oc["result"]), "captured", "early capture result = captured")
	_assert_equal(bool(oc["early_capture"]), true, "early_capture flagged true")
	_assert_equal(int(oc["resolved_unix"]), T0 + 1150, "early capture resolved at hold+duration instant")

# --- REPEL: neither assault reaches the threshold; final tally < 75 = defender holds ---
func _test_repel() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0))
	m.advance("sg_test", T0 + 1080)  # assault#0
	m.apply_scoring_event("sg_test", {"kind": "guard_defeated", "org_id": "org_atk"}, T0 + 1100)  # +12
	m.advance("sg_test", T0 + 1440)  # -> lull (12 -> bleeds)
	m.advance("sg_test", T0 + 1800)  # assault#1 (~6)
	m.apply_scoring_event("sg_test", {"kind": "objective", "side": "attacker", "org_id": "org_atk"}, T0 + 1810)  # +15 -> ~21
	m.advance("sg_test", T0 + 2160)  # final assault end -> resolution -> cooldown
	var oc: Dictionary = m.get_siege("sg_test")["outcome"]
	_assert_equal(String(oc["result"]), "repelled", "final tally < 75 -> repelled")
	_assert_true(float(oc["final_control"]) < 75.0, "repelled final control below threshold")
	m.advance("sg_test", T0 + 5000)  # past cooldown
	_assert_equal(m.state_of("sg_test"), "repelled", "cooldown end -> repelled archive")

# --- ABORT with refund (grace) vs forfeit (post-grace) ---
func _test_abort_refund_and_forfeit() -> void:
	# In-grace withdraw -> aborted, full refund, short abort cooldown.
	var mg: Object = Siege.new()
	mg.declare(_base_params(T0))
	# Rank gate on withdraw.
	_assert_equal(String(mg.withdraw("sg_test", 3, T0 + 50)["reason"]), "rank_too_low", "under-rank withdraw rejected")
	var r: Dictionary = mg.withdraw("sg_test", 4, T0 + 50)  # inside the 180 s grace
	_assert_equal(String(r["result"]), "aborted", "grace withdraw -> aborted")
	_assert_equal(String(r["war_chest_disposition"]), "refunded_full", "grace withdraw refunds war-chest")
	_assert_equal(int(r["refund_credits"]), 10000, "grace refund = full 10000")
	_assert_equal(mg.state_of("sg_test"), "aborted", "state aborted after grace withdraw")
	# Abort cooldown (360 s) locks the node, then releases.
	_assert_equal(String(mg.is_node_available("node1", T0 + 100)["reason"]), "node_in_cooldown", "abort cooldown locks node")
	_assert_true(bool(mg.is_node_available("node1", T0 + 50 + 360 + 1)["available"]), "abort cooldown expires -> node free")

	# Post-grace (mustering) withdraw -> aborted, war-chest FORFEIT.
	var mf: Object = Siege.new()
	mf.declare(_base_params(T0))
	mf.advance("sg_test", T0 + 180)  # -> mustering
	_assert_equal(mf.state_of("sg_test"), "mustering", "advanced to mustering")
	var r2: Dictionary = mf.withdraw("sg_test", 4, T0 + 300)
	_assert_equal(String(r2["result"]), "aborted", "mustering withdraw -> aborted")
	_assert_equal(String(r2["war_chest_disposition"]), "forfeit", "post-grace withdraw forfeits war-chest")
	_assert_equal(int(r2["refund_credits"]), 0, "post-grace refund = 0")

# --- RESTART catch-up: persist mid-assault, restore, advance far; bleed + phases catch up, pvp re-derived ---
func _test_restart_catch_up() -> void:
	var live: Object = Siege.new()
	live.declare(_base_params(T0))
	live.advance("sg_test", T0 + 1080)  # assault#0
	live.apply_scoring_event("sg_test", {"kind": "guard_defeated", "org_id": "org_atk"}, T0 + 1100)  # +12
	_assert_equal(live.state_of("sg_test"), "assault", "live siege mid assault#0")

	var blob: Dictionary = live.to_dict()
	# Corrupt the persisted transient flag to prove it is RE-DERIVED (never trusted from disk).
	(blob["sieges"]["sg_test"]["pvp_consent"] as Dictionary)["active"] = false

	var boot: Object = Siege.new()
	boot.apply_persisted(blob)
	_assert_equal(boot.state_of("sg_test"), "assault", "restored mid-assault state")
	_assert_equal(bool(boot.pvp_consent_for("sg_test")["active"]), true, "pvp consent RE-DERIVED true (assault), not from disk")
	_assert_equal(float(boot.get_siege("sg_test")["control_meter"]["value"]), 12.0, "restored control value")
	_assert_equal((boot.get_siege("sg_test")["score"]["contributions"] as Array).size(), 1, "restored audit log")
	_assert_equal(boot.active_siege_for_node("node1"), "sg_test", "node->active-siege index rebuilt on restore")

	# Server was down a long time: advance far past every remaining boundary + the cooldown.
	boot.advance("sg_test", T0 + 100000)
	_assert_equal(boot.state_of("sg_test"), "repelled", "catch-up resolves an unattended siege (no scoring in downtime -> repelled)")
	_assert_equal(bool(boot.pvp_consent_for("sg_test")["active"]), false, "pvp consent off after catch-up archive")
	# The lead bled away across the unattended lull/assault#1 (nobody present to hold it).
	_assert_true(float(boot.get_siege("sg_test")["outcome"]["final_control"]) < 75.0, "control bled below threshold during downtime")

# --- control-bleed span: a lead is perishable outside assault windows ---
func _test_control_bleed_span() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0))
	m.advance("sg_test", T0 + 1080)  # assault#0
	m.apply_scoring_event("sg_test", {"kind": "objective", "side": "attacker", "org_id": "org_atk"}, T0 + 1100)  # +15
	m.apply_scoring_event("sg_test", {"kind": "objective", "side": "attacker", "org_id": "org_atk"}, T0 + 1100)  # +15 -> 30
	m.advance("sg_test", T0 + 1440)  # -> lull; assault windows do NOT bleed
	_assert_equal(float(m.get_siege("sg_test")["control_meter"]["value"]), 30.0, "no bleed inside assault; 30 at lull entry")

	# 300 s into the lull: 300/3600 * 60 = 5 bled -> 25.
	m.advance("sg_test", T0 + 1740)
	_assert_equal(m.state_of("sg_test"), "lull", "still in lull mid-span")
	_assert_true(is_equal_approx(float(m.get_siege("sg_test")["control_meter"]["value"]), 25.0), "lull bleed 30 -> 25 over 300 s")
	# Advancing again to the same now is idempotent (no double-bleed).
	m.advance("sg_test", T0 + 1740)
	_assert_true(is_equal_approx(float(m.get_siege("sg_test")["control_meter"]["value"]), 25.0), "bleed idempotent for a fixed now")

# --- mustering-only third-party intervention ---
func _test_mustering_only_ally_commit() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0))

	# Cannot commit during the declared grace window (mustering_only).
	var c_declared: Dictionary = m.validate_ally_commit("sg_test", {"org_id": "org_ally", "side": "attacker", "committer_rank": 4, "ally_influence": 20})
	_assert_equal(String(c_declared["reason"]), "not_mustering", "ally cannot commit in declared")

	m.advance("sg_test", T0 + 180)  # -> mustering
	# Rank / influence / principal gates.
	_assert_equal(String(m.validate_ally_commit("sg_test", {"org_id": "org_ally", "side": "attacker", "committer_rank": 3, "ally_influence": 20})["reason"]), "rank_too_low", "ally under rank rejected")
	_assert_equal(String(m.validate_ally_commit("sg_test", {"org_id": "org_ally", "side": "attacker", "committer_rank": 4, "ally_influence": 10})["reason"]), "influence_too_low", "ally under influence rejected")
	_assert_equal(String(m.validate_ally_commit("sg_test", {"org_id": "org_atk", "side": "attacker", "committer_rank": 4, "ally_influence": 20})["reason"]), "is_principal", "a principal cannot be its own ally")

	# A valid attacker-side commit.
	var g: Dictionary = m.commit_ally("sg_test", {"org_id": "org_ally", "side": "attacker", "committer_rank": 4, "ally_influence": 20, "committed_by_char_id": "ally_lead"}, T0 + 200)
	_assert_true(bool(g["ok"]), "valid mustering ally commit accepted")
	_assert_equal((m.get_siege("sg_test")["intervenors"] as Array).size(), 1, "one intervenor recorded")

	# Per-side cap = 1: a second attacker-side ally is rejected.
	_assert_equal(String(m.commit_ally("sg_test", {"org_id": "org_ally2", "side": "attacker", "committer_rank": 4, "ally_influence": 20}, T0 + 210)["reason"]), "ally_cap", "attacker-side ally cap = 1")
	# The other side still has a slot.
	var g2: Dictionary = m.commit_ally("sg_test", {"org_id": "org_ally3", "side": "defender", "committer_rank": 4, "ally_influence": 20}, T0 + 210)
	_assert_true(bool(g2["ok"]), "defender-side ally slot still open")
	_assert_equal((m.get_siege("sg_test")["intervenors"] as Array).size(), 2, "two intervenors (one per side)")
	# The same org cannot re-commit.
	_assert_equal(String(m.commit_ally("sg_test", {"org_id": "org_ally", "side": "defender", "committer_rank": 4, "ally_influence": 20}, T0 + 220)["reason"]), "already_committed", "an org cannot double-commit")

	# Once assaults begin the window is closed.
	m.advance("sg_test", T0 + 1080)  # -> assault#0
	_assert_equal(String(m.validate_ally_commit("sg_test", {"org_id": "org_ally4", "side": "defender", "committer_rank": 4, "ally_influence": 20})["reason"]), "not_mustering", "ally commit closed once assaults start")

func _finish() -> void:
	if _failures.is_empty():
		print("siege_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
