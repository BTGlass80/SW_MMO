extends SceneTree
## Arena-level flow guard for zone-based PvP (Wave F / DIV-0019). Exercises combat_arena.resolve_window
## with a pvp_gate: the shot lands on the TARGET PLAYER (not the dummy), the DIV-0016 sparring clamp is
## bypassed (PvP is lethal), the envelope + tiered casualties route correctly, the resolve-time gate
## drops an unauthorized shot, stale-target cancellation works, the hoisted disabled guard + floor-aware
## clamp hold, and the PvE path is byte-compatible (no gate arg, dummy clamp still 2). All seeds fixed.

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const PvpRules := preload("res://scripts/rules/pvp_rules_model.gd")

var _failures: Array[String] = []
var _rules: Object

# A ganker (A) with overwhelming damage + high initiative, and a fragile victim (B).
const GANKER := {"attributes": {"dexterity": "4D", "strength": "3D", "perception": "5D"}, "skills": {"blaster": "3D"}, "equipment": {"weapon": "hand_cannon"}}
const VICTIM := {"attributes": {"dexterity": "2D", "strength": "1D", "perception": "1D"}, "skills": {}, "equipment": {"weapon": "pea_shooter"}}

func _weapons() -> Dictionary:
	return {"hand_cannon": {"damage": "12D", "skill": "blaster"}, "pea_shooter": {"damage": "2D", "skill": "blaster"}}

func _arena() -> CombatArena:
	return CombatArena.new(_rules, _combat_data(), "b1_training_silhouette", _weapons(), {})

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()

	# 11 + 12 + 13 + 14: A fires at B (authorized). The shot lands on B (dummy untouched), drives B PAST
	# the sparring cap into the 'out' band, the envelope is tagged pvp, and a casualty is reported.
	var a := _arena()
	a.register_player(2, "Ganker", GANKER)
	a.register_player(3, "Victim", VICTIM)
	var b_max := 0
	var saw_pvp := false
	var saw_casualty := false
	var casualty_sev := 0
	for w in range(12):
		a.submit_fire_intent(2, {"aim": 3, "target_peer": 3})
		var res: Dictionary = a.resolve_window(4000 + w, {2: true})
		b_max = maxi(b_max, int(a.player_state(3).get("player_wound_severity", 0)))
		for env in res.get("envelopes", []):
			if bool((env as Dictionary).get("pvp", false)):
				saw_pvp = true
				_assert_equal(int((env as Dictionary).get("target_peer_id", 0)), 3, "PvP envelope names the target peer")
				_assert_equal(String((env as Dictionary).get("target_name", "")), "Victim", "PvP envelope carries the target PLAYER's name, not the dummy")
		for c in res.get("casualties", []):
			saw_casualty = true
			casualty_sev = maxi(casualty_sev, int((c as Dictionary).get("severity", 0)))
			_assert_equal(int((c as Dictionary).get("killer", 0)), 2, "casualty credits the killer")
			_assert_equal(int((c as Dictionary).get("peer", 0)), 3, "casualty names the victim")
		if a.player_state(3).get("player_wound_severity", 0) >= PvpRules.PVP_DEATH_SEVERITY:
			break
	_assert_equal(int(a.target_state().get("wound_severity", 0)), 0, "the shared training dummy is UNTOUCHED by PvP fire")
	_assert_true(b_max >= CombatArena.DISABLED_SEVERITY, "PvP drives the victim PAST the sparring cap (>= 3) — the clamp is bypassed")
	_assert_true(saw_pvp, "a PvP shot yields a pvp-tagged envelope")
	_assert_true(saw_casualty and casualty_sev >= CombatArena.DISABLED_SEVERITY, "a downed/killed victim is reported as a casualty")
	# G2 wiring proof (DIV-0006/0019): the victim was driven down THROUGH the WEG ladder — the escalate()
	# seam populated a real disabled-tier LEVEL string on the player's live state. The old highest-hit-wins
	# path never wrote player_wound_level, so this asserts the new accumulation code path actually ran.
	var victim_level := String(a.player_state(3).get("player_wound_level", ""))
	_assert_true(victim_level in ["incapacitated", "mortally_wounded", "dead"],
		"a downed PvP victim carries a disabled-tier wound LEVEL from escalate() (got '%s')" % victim_level)

	# 19: resolve-time gate DROPS an unauthorized shot — B is untouched AND it does NOT fall through to the dummy.
	var g := _arena()
	g.register_player(2, "Ganker", GANKER)
	g.register_player(3, "Victim", VICTIM)
	g.submit_fire_intent(2, {"aim": 3, "target_peer": 3})
	var gres: Dictionary = g.resolve_window(1234, {})  # empty gate = not authorized
	_assert_equal(int(g.player_state(3).get("player_wound_severity", 0)), 0, "an ungated PvP shot does NOT wound the target")
	_assert_equal(int(g.target_state().get("wound_severity", 0)), 0, "an ungated PvP shot is DROPPED, not redirected to the dummy")
	_assert_equal((gres.get("envelopes", []) as Array).size(), 0, "a dropped PvP shot yields no envelope")

	# 20: stale-target cancellation — clear_intents_targeting drops a queued shot AT a peer who left.
	var s := _arena()
	s.register_player(2, "Ganker", GANKER)
	s.register_player(3, "Victim", VICTIM)
	s.submit_fire_intent(2, {"aim": 3, "target_peer": 3})
	_assert_equal(s.pending_intent_count(), 1, "the PvP intent is queued")
	_assert_equal(int((s.pending_pvp_targets() as Dictionary).get(2, 0)), 3, "pending_pvp_targets maps shooter->target")
	s.clear_intents_targeting(3)
	_assert_equal(s.pending_intent_count(), 0, "clear_intents_targeting drops shots aimed at the departed player")

	# 17: hoisted disabled-before-acting guard — a shooter dropped to 'out' MID-window (queued while
	# healthy, then disabled before its turn by a higher-initiative opponent) has its queued shot
	# SKIPPED at resolve. Simulate the mid-window drop deterministically via set_player_combat.
	var d := _arena()
	d.register_player(2, "Ganker", GANKER)
	d.register_player(3, "Victim", VICTIM)
	d.submit_fire_intent(2, {"aim": 3})                  # A queues a dummy shot
	d.submit_fire_intent(3, {"aim": 3})                  # B queues a shot WHILE healthy
	d.set_player_combat(3, {"player_wound_severity": 3}) # B is dropped to 'out' before it resolves
	var dres: Dictionary = d.resolve_window(555)
	var shooters_resolved: Array = []
	for env in dres.get("envelopes", []):
		shooters_resolved.append(int((env as Dictionary).get("shooter_id", 0)))
	_assert_true(not shooters_resolved.has(3), "a shooter disabled before its turn has its queued shot SKIPPED (resolve-time guard)")
	_assert_true(shooters_resolved.has(2), "the still-healthy shooter resolves normally")

	# 18: floor-aware clamp — a PvP-wounded player who ALSO fires the shared dummy is NOT healed by the
	# sparring clamp back below their PvP wound.
	var f := _arena()
	f.register_player(3, "Victim", VICTIM)
	f.set_player_combat(3, {"player_wound_severity": 4})  # already mortally wounded from a PvP hit
	# sev 4 >= DISABLED_SEVERITY, so a dummy shot is skipped entirely (guard) — the wound is untouched.
	f.submit_fire_intent(3, {"aim": 0})  # target_peer 0 -> dummy
	f.resolve_window(99)
	_assert_equal(int(f.player_state(3).get("player_wound_severity", 0)), 4, "a PvP-wounded (sev 4) player firing the dummy is NOT clamp-healed to 2")

	# 16: reaction fire retained — a passive victim (no queued intent) still auto-return-fires. Use a
	# WEAK attacker vs a TANKY target so the target survives the shot and can shoot back (return fire is
	# skipped only when the target is disabled — a one-shot kill would hide it).
	var weak := {"attributes": {"dexterity": "3D", "strength": "2D"}, "skills": {"blaster": "1D"}, "equipment": {"weapon": "pea_shooter"}}
	var tank := {"attributes": {"dexterity": "3D", "strength": "4D", "perception": "3D"}, "skills": {"dodge": "1D"}, "equipment": {"weapon": "pea_shooter"}}
	var r := _arena()
	r.register_player(2, "Skirmisher", weak)
	r.register_player(3, "Tank", tank)
	var saw_return := false
	for w in range(10):
		r.submit_fire_intent(2, {"aim": 0, "target_peer": 3})  # only A queues; B is passive
		for env in r.resolve_window(700 + w, {2: true}).get("envelopes", []):
			for ev in (env as Dictionary).get("events", []):
				if String((ev as Dictionary).get("type", "")) == "remote_return_fire":
					saw_return = true
	_assert_true(saw_return, "a passive PvP victim still reaction-fires (return fire not suppressed)")

	# 21 + 22: PvE regression + determinism. No target_peer -> the shared dummy, DIV-0016 clamp still
	# holds (<= 2), resolve_window works with NO gate arg, and identical seeds reproduce identical state.
	var p1 := CombatArena.new(_rules, _sparring_data())
	p1.register_player(2, "Recruit", {"attributes": {"dexterity": "2D", "strength": "1D"}})
	var pmax := 0
	for w in range(30):
		p1.reset_target()
		p1.submit_fire_intent(2, {"aim": 0})  # no target_peer, no gate arg
		p1.resolve_window(8000 + w)
		pmax = maxi(pmax, int(p1.player_state(2).get("player_wound_severity", 0)))
	_assert_true(pmax <= CombatArena.SPARRING_MAX_SEVERITY, "PvE regression: no-target sparring still caps at Wounded(2), no gate arg required")

	var det_a := _pvp_run(9999)
	var det_b := _pvp_run(9999)
	_assert_equal(det_a, det_b, "identical seed reproduces identical PvP victim wound (deterministic)")

	if _rules.has_method("free"):
		_rules.free()
	if _failures.is_empty():
		print("pvp_flow_smoke: OK")
		quit(0)
	else:
		for fail in _failures:
			printerr(fail)
		quit(1)

# One deterministic PvP window; returns the victim's resulting wound severity.
func _pvp_run(seed: int) -> int:
	var a := _arena()
	a.register_player(2, "Ganker", GANKER)
	a.register_player(3, "Victim", VICTIM)
	a.submit_fire_intent(2, {"aim": 3, "target_peer": 3})
	a.resolve_window(seed, {2: true})
	return int(a.player_state(3).get("player_wound_severity", 0))

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {"blaster": "4D+1", "dodge": "4D", "soak": "3D", "weapon": "training_blaster", "armor": "blast_vest", "scale": "character"},
		"weapons": {"training_blaster": {"damage": "4D"}, "remote_stun_blaster": {"damage": "3D+2"}},
		"armors": {"blast_vest": {"protection_energy": "0D+1", "protection_physical": "1D", "dexterity_penalty": "-1D", "coverage": ["torso"]}},
		"targets": {"b1_training_silhouette": {"blaster": "3D", "weapon": "remote_stun_blaster", "soak": "2D", "scale": "character", "distance": 12.0, "cover_level": 0, "name": "B1 Training Remote"}},
	}

func _sparring_data() -> Dictionary:
	var d := _combat_data()
	((d["targets"] as Dictionary)["b1_training_silhouette"] as Dictionary)["stun_return_fire"] = false
	return d

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
