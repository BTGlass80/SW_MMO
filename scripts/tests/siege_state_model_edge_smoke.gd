extends SceneTree
## HARDENING smoke for the pure siege state machine (scripts/rules/siege_state_model.gd). Adversarial
## coverage beyond siege_smoke.gd: a confirmed declare()-collision data-corruption bug (regression
## below), full to_dict()/apply_persisted() round-trip fidelity (incl. _seq continuity so a restored
## server never mints a colliding auto-id), control-meter clamp at both bounds + peak tracking across
## a bleed, every apply_scoring_event/apply_hold_tick reject path, enforce_influence_gate's refund vs
## forfeit branches (untested by siege_smoke.gd), concede/withdraw on non-actionable states, and the
## "open" intervention_mode window (siege_smoke.gd only exercises "mustering_only"). No RNG (the
## model has none); everything is deterministic wall-clock math.

const Siege := preload("res://scripts/rules/siege_state_model.gd")

const T0 := 2_000_000

var _failures: Array[String] = []

func _init() -> void:
	_test_duplicate_siege_id_bug_fix()
	_test_persist_round_trip_fidelity_and_seq_continuity()
	_test_apply_persisted_empty_and_missing_pvp_consent()
	_test_control_meter_clamps_at_bounds_and_tracks_peak()
	_test_apply_scoring_event_reject_paths()
	_test_apply_hold_tick_tie()
	_test_enforce_influence_gate_both_branches()
	_test_concede_and_withdraw_invalid_states()
	_test_open_intervention_mode_window()
	_test_is_node_available_unknown_node()
	_finish()

func _base_params(now: int, node_id: String = "node1", siege_id: String = "sg_test", attacker_org := "org_atk") -> Dictionary:
	return {
		"siege_id": siege_id,
		"claim_id": "clm1", "node_id": node_id, "zone_id": "zoneA",
		"defender_org_id": "org_def", "attacker_org_id": attacker_org,
		"declared_by_char_id": "char_leader",
		"declarer_rank": 4, "attacker_influence": 40, "attacker_treasury": 10000,
		"zone_security_base": "contested", "now": now,
	}

# ---------------------------------------------------------------------------------------------
# CONFIRMED BUG (fixed in this pass): declare() blindly overwrote sieges[sid] on an explicit-id
# collision (no existence check), even across UNRELATED nodes/attackers. That corrupted the clobbered
# siege's node_id AND left `_node_active_siege` pointing a stale node at a record that no longer
# references it, PERMANENTLY soft-locking the original node (nothing ever clears the stale index
# entry, since _to_archive/_abort key off the record's OWN node_id, which now points elsewhere).
# ---------------------------------------------------------------------------------------------
func _test_duplicate_siege_id_bug_fix() -> void:
	var m: Object = Siege.new()
	var d1: Dictionary = m.declare(_base_params(T0, "nodeA", "sg_dup", "org_atk"))
	_assert_true(bool(d1["ok"]), "first declaration with id sg_dup succeeds")
	_assert_equal(m.active_siege_for_node("nodeA"), "sg_dup", "nodeA is tracked under sg_dup")

	# A DIFFERENT attacker (avoids the concurrency-cap gate masking this) reuses the same siege_id
	# against a DIFFERENT node.
	var v: Dictionary = m.validate_declaration(_base_params(T0, "nodeB", "sg_dup", "org_other"))
	_assert_equal(String(v["reason"]), "duplicate_siege_id", "validate_declaration rejects a colliding siege_id")
	var d2: Dictionary = m.declare(_base_params(T0, "nodeB", "sg_dup", "org_other"))
	_assert_equal(bool(d2["ok"]), false, "declare() rejects the colliding siege_id")
	_assert_equal(String(d2["reason"]), "duplicate_siege_id", "rejection reason is duplicate_siege_id")

	# The original record and index are UNTOUCHED.
	_assert_equal(String(m.get_siege("sg_dup")["node_id"]), "nodeA", "the original siege's node_id is not clobbered")
	_assert_equal(m.active_siege_for_node("nodeA"), "sg_dup", "nodeA's index entry still points at the original record")
	_assert_equal(m.active_siege_for_node("nodeB"), "", "nodeB was never touched by the rejected declaration")
	_assert_true(bool(m.is_node_available("nodeB", T0)["available"]), "nodeB remains free after the rejected collision")

func _test_persist_round_trip_fidelity_and_seq_continuity() -> void:
	var live: Object = Siege.new()
	# Commit an ally during mustering (the only intervention_mode="mustering_only" window), THEN
	# advance into assault and score, so the persisted blob carries a non-trivial intervenors[] +
	# score.contributions[] + control_meter + auto-generated siege_id (exercises _seq persistence).
	var d: Dictionary = live.declare(_base_params(T0, "nodeR", ""))  # auto id -> exercises _seq = 1
	var sid := String(d["siege_id"])
	_assert_equal(sid, "sg_0001", "auto-generated id from a fresh instance is sg_0001 (seq starts at 0)")
	live.advance(sid, T0 + 180)   # -> mustering
	live.commit_ally(sid, {"org_id": "org_ally", "side": "attacker", "committer_rank": 4, "ally_influence": 20, "committed_by_char_id": "ally_lead"}, T0 + 100)
	live.advance(sid, T0 + 1080)  # -> assault#0
	live.apply_scoring_event(sid, {"kind": "objective", "side": "attacker", "char_id": "c1", "org_id": "org_atk"}, T0 + 1100)
	live.apply_scoring_event(sid, {"kind": "guard_defeated", "char_id": "c1", "org_id": "org_atk"}, T0 + 1105)

	var before: Dictionary = live.get_siege(sid).duplicate(true)
	var blob: Dictionary = live.to_dict()

	var boot: Object = Siege.new()
	boot.apply_persisted(blob)
	var after: Dictionary = boot.get_siege(sid)

	# Field-by-field fidelity (pvp_consent.active is transient/re-derived, checked separately).
	_assert_equal(String(after["state"]), String(before["state"]), "round-trip: state")
	_assert_equal(float(after["control_meter"]["value"]), float(before["control_meter"]["value"]), "round-trip: control_meter.value")
	_assert_equal(float(after["control_meter"]["peak"]), float(before["control_meter"]["peak"]), "round-trip: control_meter.peak")
	_assert_equal((after["score"]["contributions"] as Array).size(), (before["score"]["contributions"] as Array).size(), "round-trip: score.contributions size")
	_assert_equal(float(after["score"]["attacker_points"]), float(before["score"]["attacker_points"]), "round-trip: score.attacker_points")
	_assert_equal((after["intervenors"] as Array).size(), (before["intervenors"] as Array).size(), "round-trip: intervenors size")
	_assert_equal(String((after["intervenors"] as Array)[0]["org_id"]), "org_ally", "round-trip: intervenor org_id preserved")
	_assert_equal(int(after["war_chest_credits"]), int(before["war_chest_credits"]), "round-trip: war_chest_credits")
	_assert_equal(float(after["config"]["capture_threshold"]), float(before["config"]["capture_threshold"]), "round-trip: snapshotted config")
	_assert_equal(bool(boot.pvp_consent_for(sid)["active"]), true, "round-trip: pvp_consent re-derived true (state is assault)")
	_assert_equal(boot.active_siege_for_node("nodeR"), sid, "round-trip: node index rebuilt")

	# _seq CONTINUITY: a restored server must not mint an id that collides with a restored record. The
	# next auto-declare on the restored instance must continue counting from the persisted _seq, not
	# restart at sg_0001 (which would immediately collide were sg_0001 still non-terminal -- and even
	# once terminal, silently reusing an id number is a latent footgun this guards against). Use a
	# DIFFERENT attacker org so the restored sg_0001's outgoing-attack concurrency cap doesn't mask this.
	var d2: Dictionary = boot.declare(_base_params(T0 + 5000, "nodeS", "", "org_other"))
	_assert_true(bool(d2["ok"]), "a fresh declare on the restored instance succeeds")
	_assert_equal(String(d2["siege_id"]), "sg_0002", "auto-id continues from the persisted _seq (does not collide with sg_0001)")

func _test_apply_persisted_empty_and_missing_pvp_consent() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0, "nodeT", "sg_t"))
	m.apply_persisted({})  # empty payload must be a no-op, not a crash/wipe
	_assert_true(m.has_siege("sg_t"), "apply_persisted({}) is a no-op and does not wipe live state")

	# A persisted blob missing the pvp_consent sub-dict entirely (older schema) must not crash and
	# must still re-derive an active/inactive flag correctly.
	var m2: Object = Siege.new()
	m2.declare(_base_params(T0, "nodeU", "sg_u"))
	m2.advance("sg_u", T0 + 180)
	m2.advance("sg_u", T0 + 1080)  # assault
	var blob: Dictionary = m2.to_dict()
	(blob["sieges"]["sg_u"] as Dictionary).erase("pvp_consent")
	var m3: Object = Siege.new()
	m3.apply_persisted(blob)
	_assert_equal(bool(m3.pvp_consent_for("sg_u")["active"]), true, "a missing pvp_consent sub-dict on restore is synthesized and correctly re-derived (assault -> active)")

func _test_control_meter_clamps_at_bounds_and_tracks_peak() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0, "nodeC", "sg_c"))
	m.advance("sg_c", T0 + 1080)  # -> assault#0
	# Hammer the attacker side well past 100 with repeated objective scores (+15 each, config-tunable).
	for i in 10:
		m.apply_scoring_event("sg_c", {"kind": "objective", "side": "attacker", "org_id": "org_atk"}, T0 + 1090 + i)
	var s: Dictionary = m.get_siege("sg_c")
	_assert_equal(float(s["control_meter"]["value"]), 100.0, "control meter clamps at control_max (100), never overshoots")
	_assert_equal(float(s["control_meter"]["peak"]), 100.0, "peak tracks the clamped max")
	# One more attacker event at the ceiling has a control_delta of exactly 0 (already clamped).
	var ev: Dictionary = m.apply_scoring_event("sg_c", {"kind": "objective", "side": "attacker", "org_id": "org_atk"}, T0 + 1200)
	_assert_equal(float(ev["control_delta"]), 0.0, "a scoring event at the clamp ceiling contributes zero further delta")
	_assert_equal(float(ev["value"]), 100.0, "value stays pinned at the ceiling")

	# Now hammer the DEFENDER side; the meter should clamp at control_min (0), never go negative.
	var m2: Object = Siege.new()
	m2.declare(_base_params(T0, "nodeD", "sg_d"))
	m2.advance("sg_d", T0 + 1080)
	for i in 10:
		m2.apply_scoring_event("sg_d", {"kind": "objective", "side": "defender", "org_id": "org_def"}, T0 + 1090 + i)
	_assert_equal(float(m2.get_siege("sg_d")["control_meter"]["value"]), 0.0, "control meter clamps at control_min (0), never goes negative")
	_assert_equal(float(m2.get_siege("sg_d")["control_meter"]["peak"]), 0.0, "peak never rises above control_start on an all-defender siege (0 is the floor and starting value)")

	# Peak is a HIGH-WATER MARK: it must not fall back down when the meter later bleeds away.
	var m3: Object = Siege.new()
	m3.declare(_base_params(T0, "nodeE", "sg_e"))
	m3.advance("sg_e", T0 + 1080)  # assault#0
	m3.apply_scoring_event("sg_e", {"kind": "objective", "side": "attacker", "org_id": "org_atk"}, T0 + 1090)  # +15
	m3.apply_scoring_event("sg_e", {"kind": "objective", "side": "attacker", "org_id": "org_atk"}, T0 + 1090)  # +15 -> 30
	_assert_equal(float(m3.get_siege("sg_e")["control_meter"]["peak"]), 30.0, "peak recorded at 30")
	m3.advance("sg_e", T0 + 1440)  # -> lull, bleeds
	m3.advance("sg_e", T0 + 1500)  # further bleed
	_assert_true(float(m3.get_siege("sg_e")["control_meter"]["value"]) < 30.0, "value bled down below its high point")
	_assert_equal(float(m3.get_siege("sg_e")["control_meter"]["peak"]), 30.0, "peak is a high-water mark; bleed never lowers it")

func _test_apply_scoring_event_reject_paths() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0, "nodeF", "sg_f"))
	# not yet in assault (still declared).
	var r1: Dictionary = m.apply_scoring_event("sg_f", {"kind": "objective", "side": "attacker"}, T0 + 10)
	_assert_equal(bool(r1["ok"]), false, "scoring outside an assault window is rejected")
	_assert_equal(String(r1["reason"]), "not_in_assault", "reject reason is not_in_assault")

	m.advance("sg_f", T0 + 1080)  # -> assault#0
	var r2: Dictionary = m.apply_scoring_event("sg_f", {"kind": "not_a_real_kind", "side": "attacker"}, T0 + 1090)
	_assert_equal(bool(r2["ok"]), false, "an unknown scoring kind is rejected")
	_assert_equal(String(r2["reason"]), "bad_kind", "reject reason is bad_kind")

	var r3: Dictionary = m.apply_scoring_event("sg_f", {"kind": "control_hold_tick", "side": "attacker"}, T0 + 1090)
	_assert_equal(bool(r3["ok"]), false, "control_hold_tick must go through apply_hold_tick, not apply_scoring_event")
	_assert_equal(String(r3["reason"]), "use_apply_hold_tick", "reject reason is use_apply_hold_tick")

	var r4: Dictionary = m.apply_scoring_event("sg_f", {"kind": "objective", "side": "sideways"}, T0 + 1090)
	_assert_equal(bool(r4["ok"]), false, "a garbage side is rejected for a side-agnostic kind")
	_assert_equal(String(r4["reason"]), "bad_side", "reject reason is bad_side")

	# ATTACKER_ONLY_KINDS force the side regardless of what's passed -- no bad_side possible there.
	var r5: Dictionary = m.apply_scoring_event("sg_f", {"kind": "sabotage", "side": "defender"}, T0 + 1090)
	_assert_true(bool(r5["ok"]), "an attacker-only kind succeeds even if 'defender' is passed as side")
	_assert_true(float(r5["control_delta"]) > 0.0, "the attacker-only kind is force-applied to the attacker (positive delta)")

	var r6: Dictionary = m.apply_scoring_event("sg_f", {"kind": "objective"}, T0 + 1090)  # no side field at all
	_assert_equal(bool(r6["ok"]), false, "a missing side is rejected for a side-agnostic kind")

	# unknown siege id.
	var r7: Dictionary = m.apply_scoring_event("no_such_siege", {"kind": "objective", "side": "attacker"}, T0)
	_assert_equal(bool(r7["ok"]), false, "scoring an unknown siege_id is rejected")
	_assert_equal(String(r7["reason"]), "unknown_siege", "reject reason is unknown_siege")

func _test_apply_hold_tick_tie() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0, "nodeG", "sg_g"))
	m.advance("sg_g", T0 + 1080)  # assault#0
	var before := float(m.get_siege("sg_g")["control_meter"]["value"])
	var r: Dictionary = m.apply_hold_tick("sg_g", 3, 3, T0 + 1090)  # tied presence
	_assert_true(bool(r["ok"]), "a tied hold tick reports ok")
	_assert_equal(String(r["reason"]), "tie", "a tied hold tick reports reason=tie")
	_assert_equal(float(r["control_delta"]), 0.0, "a tied hold tick applies zero delta")
	_assert_equal(float(m.get_siege("sg_g")["control_meter"]["value"]), before, "control value is unchanged by a tied hold tick")

	# a hold tick outside assault is rejected same as scoring events.
	var m2: Object = Siege.new()
	m2.declare(_base_params(T0, "nodeH", "sg_h"))
	var r2: Dictionary = m2.apply_hold_tick("sg_h", 5, 1, T0 + 10)
	_assert_equal(bool(r2["ok"]), false, "a hold tick outside assault is rejected")
	_assert_equal(String(r2["reason"]), "not_in_assault", "reject reason is not_in_assault")

func _test_enforce_influence_gate_both_branches() -> void:
	# DECLARED (in grace) + influence drop -> aborted, full refund per the default grace fraction.
	var mg: Object = Siege.new()
	mg.declare(_base_params(T0, "nodeI", "sg_i"))
	var g: Dictionary = mg.enforce_influence_gate("sg_i", 10, T0 + 50)  # well below attacker_min_influence (40)
	_assert_true(bool(g["aborted"]), "an influence collapse in the grace window aborts the siege")
	_assert_equal(String(g["result"]), "aborted", "result is aborted")
	_assert_equal(String(g["war_chest_disposition"]), "refunded_full", "grace-window influence-loss abort refunds in full")
	_assert_equal(int(g["refund_credits"]), 10000, "full refund amount")
	_assert_equal(mg.state_of("sg_i"), "aborted", "siege state is aborted")

	# MUSTERING + influence drop -> aborted, FORFEIT (post-grace).
	var mf: Object = Siege.new()
	mf.declare(_base_params(T0, "nodeJ", "sg_j"))
	mf.advance("sg_j", T0 + 180)  # -> mustering
	var g2: Dictionary = mf.enforce_influence_gate("sg_j", 5, T0 + 300)
	_assert_true(bool(g2["aborted"]), "an influence collapse during mustering aborts the siege")
	_assert_equal(String(g2["war_chest_disposition"]), "forfeit", "mustering-phase influence-loss abort forfeits the war-chest")
	_assert_equal(int(g2["refund_credits"]), 0, "no refund on the forfeit path")

	# a HEALTHY influence level is a pure no-op pass-through.
	var mp: Object = Siege.new()
	mp.declare(_base_params(T0, "nodeK", "sg_k"))
	var pass_through: Dictionary = mp.enforce_influence_gate("sg_k", 50, T0 + 50)
	_assert_equal(bool(pass_through["aborted"]), false, "healthy influence does not abort")
	_assert_equal(mp.state_of("sg_k"), "declared", "siege state is untouched by a passing influence check")

	# ASSAULT phase: the gate is defined only for declared/mustering; it must NOT touch an in-progress assault.
	var ma: Object = Siege.new()
	ma.declare(_base_params(T0, "nodeL", "sg_l"))
	ma.advance("sg_l", T0 + 1080)  # -> assault#0
	var during_assault: Dictionary = ma.enforce_influence_gate("sg_l", 0, T0 + 1090)
	_assert_equal(bool(during_assault["aborted"]), false, "the influence gate does not fire once assaults have begun")
	_assert_equal(ma.state_of("sg_l"), "assault", "an in-progress assault is untouched by a post-mustering influence drop")

	# unknown siege id.
	var unk: Dictionary = ma.enforce_influence_gate("nope", 0, T0)
	_assert_equal(bool(unk["ok"]), false, "enforce_influence_gate on an unknown siege_id fails")
	_assert_equal(String(unk["reason"]), "unknown_siege", "reject reason is unknown_siege")

func _test_concede_and_withdraw_invalid_states() -> void:
	var m: Object = Siege.new()
	m.declare(_base_params(T0, "nodeM", "sg_m"))
	m.advance("sg_m", T0 + 180)   # mustering
	m.advance("sg_m", T0 + 1080)  # assault#0
	m.advance("sg_m", T0 + 1440)  # lull
	m.advance("sg_m", T0 + 1800)  # assault#1 (last, prototype assault_count=2)
	m.advance("sg_m", T0 + 2160)  # -> resolution -> cooldown (repelled: no scoring happened)
	_assert_equal(m.state_of("sg_m"), "cooldown", "setup: siege reached cooldown with no scoring")

	# withdraw()/concede() are undefined once the siege is resolving/cooling/archived.
	var w: Dictionary = m.withdraw("sg_m", 4, T0 + 2200)
	_assert_equal(bool(w["ok"]), false, "withdraw during cooldown is rejected")
	_assert_equal(String(w["reason"]), "not_withdrawable", "reject reason is not_withdrawable")
	var c: Dictionary = m.concede("sg_m", 4, T0 + 2200)
	_assert_equal(bool(c["ok"]), false, "concede during cooldown is rejected")
	_assert_equal(String(c["reason"]), "not_concedable", "reject reason is not_concedable")

	m.advance("sg_m", T0 + 100000)  # -> archive
	_assert_equal(m.state_of("sg_m"), "repelled", "setup: siege archived as repelled")
	_assert_equal(bool(m.withdraw("sg_m", 4, T0 + 100001)["ok"]), false, "withdraw on an archived siege is rejected")
	_assert_equal(bool(m.concede("sg_m", 4, T0 + 100001)["ok"]), false, "concede on an archived siege is rejected")

	# concede() succeeds from "declared" too (a defender can concede immediately, before mustering).
	var mc: Object = Siege.new()
	mc.declare(_base_params(T0, "nodeN", "sg_n"))
	var conceded: Dictionary = mc.concede("sg_n", 4, T0 + 10)
	_assert_true(bool(conceded["ok"]), "a defender may concede while still in the declared grace window")
	_assert_equal(String(conceded["result"]), "captured", "a concession resolves as captured")
	_assert_equal(mc.state_of("sg_n"), "cooldown", "concede flushes resolution straight through to cooldown")

	# unknown siege ids fail cleanly for both.
	_assert_equal(bool(m.withdraw("nope", 4, T0)["ok"]), false, "withdraw on an unknown siege fails")
	_assert_equal(bool(m.concede("nope", 4, T0)["ok"]), false, "concede on an unknown siege fails")

func _test_open_intervention_mode_window() -> void:
	var cfg := Siege.prototype_config()
	cfg["intervention_mode"] = "open"
	var m: Object = Siege.new(cfg)
	m.declare(_base_params(T0, "nodeO", "sg_o"))

	# "open" allows commits during the DECLARED grace window too (unlike mustering_only). Actually
	# COMMIT here (not just validate) so the later per-side-cap assertion during lull is meaningful.
	var during_declared: Dictionary = m.commit_ally("sg_o", {"org_id": "org_ally1", "side": "attacker", "committer_rank": 4, "ally_influence": 20}, T0 + 10)
	_assert_true(bool(during_declared["ok"]), "open intervention_mode allows a commit during the declared grace window")

	m.advance("sg_o", T0 + 180)   # mustering
	m.advance("sg_o", T0 + 1080)  # assault#0 (index 0 of 2; NOT the last window)
	var during_early_assault: Dictionary = m.validate_ally_commit("sg_o", {"org_id": "org_ally2", "side": "defender", "committer_rank": 4, "ally_influence": 20})
	_assert_true(bool(during_early_assault["ok"]), "open mode allows a commit during a non-final assault window")

	m.advance("sg_o", T0 + 1440)  # lull
	var during_lull: Dictionary = m.validate_ally_commit("sg_o", {"org_id": "org_ally3", "side": "attacker", "committer_rank": 4, "ally_influence": 20})
	_assert_equal(String(during_lull["reason"]), "ally_cap", "commit during lull is gated by the per-side cap here (attacker slot already taken by org_ally1), proving the WINDOW itself was open")

	m.advance("sg_o", T0 + 1800)  # assault#1 (the LAST window, index 1 of 2)
	var during_final_assault: Dictionary = m.validate_ally_commit("sg_o", {"org_id": "org_ally4", "side": "defender", "committer_rank": 4, "ally_influence": 20})
	_assert_equal(String(during_final_assault["reason"]), "window_closed", "open mode CLOSES the window once the final assault begins")

func _test_is_node_available_unknown_node() -> void:
	var m: Object = Siege.new()
	var r: Dictionary = m.is_node_available("never_seen_node", T0)
	_assert_true(bool(r["available"]), "a node with no siege history at all is available")
	_assert_equal(String(r["reason"]), "", "no reason needed when available")

func _finish() -> void:
	if _failures.is_empty():
		print("siege_state_model_edge_smoke: OK")
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
