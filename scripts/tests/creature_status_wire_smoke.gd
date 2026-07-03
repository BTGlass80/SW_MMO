extends SceneTree
## Flow guard for the LIVE creature venom/restraint STATUS wiring (DIV-0024). CombatArena is directly
## instantiable (RefCounted) so — like hostile_aggression_smoke — this drives the REAL arena for the
## mechanic and MIRRORS the net-layer seeding + tiering (bake rider via CreatureSpecialAttackModel.describe_spawn,
## seed on a LANDED hostile hit, tick_status_effects once per window, casualties -> DIV-0027 killer-0 takeouts).
## creature_special_attack_model_smoke covers the pure schedule/descriptor math; this locks the server WIRING:
##   (A) poison SEEDS on a landed hit + the schedule ticks apply STR-resisted (armor-IGNORED) damage on the
##       right windows honoring `onset`;
##   (B) a re-bite REFRESHES the schedule (no infinite stacking);
##   (C) restraint opposed-break resolves BOTH ways (break-free clears; held applies armor-soaked crush);
##   (D) a DOWNED victim (>= DISABLED_SEVERITY) is NEVER ticked (the DIV-0027 downed loop owns them);
##   (E) determinism under a fixed server seed.
## Pure / deterministic: server-owned SEEDED rng; no nodes, sockets, RNG-in-model, or randomize(). No user:// writes.

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const CreatureSpecialAttack := preload("res://scripts/rules/creature_special_attack_model.gd")
const CREATURE_DATA_PATH := "res://data/creatures_clone_wars.json"

var _failures: Array[String] = []
var _rules: Object

# A guaranteed-HIT hostile attack side: a huge to-hit pool so its bite always LANDS (so seeding is
# deterministic), a 0D DIRECT bite (the VENOM/HOLD rider is the threat, not the bite), and a defined
# creature Strength (target_soak_pool) that restraint hold_damage resolves against.
func _hostile_pools(str_code: String) -> Dictionary:
	return {
		"target_attack_pool": _rules.parse_pool("15D"),
		"target_damage_pool": _rules.parse_pool("0D"),
		"target_soak_pool": _rules.parse_pool(str_code),
		"target_armor": {}, "target_scale": "character", "target_stun_mode": false,
	}

func _rider(cdata: Dictionary, key: String, seed: int) -> Dictionary:
	return CreatureSpecialAttack.describe_spawn(cdata, {"creature_key": key}, _rules, seed)

# A synthetic creature table so venom damage / rounds / onset and restraint hold_damage are EXACT.
func _synthetic() -> Dictionary:
	return {"creatures": {
		"venom_soak_test": {"special_attack": {"poison": {"damage": "4D", "rounds": 3, "onset": 1, "note": "x"}}},
		"venom_lethal_test": {"special_attack": {"poison": {"damage": "6D", "rounds": 3, "onset": 0, "note": "x"}}},
		"grip_break_test": {"special_attack": {"restraint": {"kind": "grapple", "hold_damage": "", "note": "y"}}},
		"grip_crush_test": {"special_attack": {"restraint": {"kind": "constriction", "hold_damage": "STR+2D", "note": "z"}}},
	}}

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	var data := _combat_data()
	var cdata := _synthetic()

	# =========================================================================================
	# (A) POISON seeds on a landed hit; onset honored; STR resists (armor IGNORED).
	# venom_soak_test: 4D poison, rounds 3, onset 1 -> schedule rounds [2,3,4]. A 30D-Strength victim
	# FULLY soaks it (severity stays 0), so we can watch the SCHEDULE cleanly: envelopes appear ONLY on
	# the onset+ windows (never windows 0-1), with the right absolute rounds, and stop after the last.
	# =========================================================================================
	var arena := CombatArena.new(_rules, data)
	arena.register_hostile_target("z", _hostile_pools("3D"), {"distance": 3.0, "cover_level": 0, "name": "Spor Crawler"}, {}, _rider(cdata, "venom_soak_test", 111))
	arena.register_player(10, "Tank", {"attributes": {"dexterity": "1D", "strength": "30D"}, "skills": {}})
	# LANDED bite seeds the rider; the 0D direct bite deals no wound (severity still 0).
	arena.resolve_hostile_aggression("z", [10], 5000)
	_assert_equal(int(arena.player_state(10).get("player_wound_severity", 0)), 0, "the 0D direct bite deals no wound (only the venom rider seeds)")
	_assert_equal(int(arena.player_status_summary(10).get("poison_rounds_left", 0)), 3, "a landed hostile hit SEEDS the venom (3 scheduled ticks ahead)")
	_assert_true(not bool(arena.player_status_summary(10).get("restrained", false)), "a poison-only rider seeds NO restraint")
	_assert_equal(String(arena.player_status_summary(10).get("source", "")), "Spor Crawler", "the status carries the injecting creature name")

	# Walk the schedule: envelopes ONLY on windows where an absolute round is due (rounds 2,3,4 = calls at
	# _status_window 2,3,4), NONE on the onset windows (0,1), and none after it runs its course.
	var rounds_fired: Array = []
	for w in range(7):
		var tick: Dictionary = arena.tick_status_effects(6000 + w)
		for env in tick.get("envelopes", []):
			var e: Dictionary = env
			if String(e.get("status", "")) == "poison":
				rounds_fired.append(int(e.get("round", -1)))
				_assert_equal(int(e.get("subject_id", 0)), 10, "a poison envelope names the victim as subject")
				_assert_true(bool(e.get("lethal", false)), "venom envelopes are flagged lethal (no DIV-0016 clamp)")
	_assert_equal(rounds_fired, [2, 3, 4], "venom ticks fire ONLY on the scheduled windows honoring onset 1 (rounds 2,3,4)")
	_assert_equal(int(arena.player_state(10).get("player_wound_severity", 0)), 0, "a 30D-Strength body fully RESISTS the venom (bare-STR soak) — severity never moves")
	_assert_equal(int(arena.player_status_summary(10).get("poison_rounds_left", 0)), 0, "the venom is cleared once the last scheduled tick applies")

	# --- ARMOR IS IGNORED by venom + it is LETHAL: a 1D-Strength victim in HEAVY armor is still downed.
	# (If armor were wrongly applied, 1D+10D soak would fully absorb the 6D venom and nothing would happen.)
	var armored := CombatArena.new(_rules, data, "b1_training_silhouette", {}, {"heavy_plate": {"protection_energy": "10D", "protection_physical": "10D", "coverage": ["full"]}})
	armored.register_hostile_target("z", _hostile_pools("3D"), {"distance": 3.0, "cover_level": 0, "name": "Spor Crawler"}, {}, _rider(cdata, "venom_lethal_test", 222))
	armored.register_player(11, "Plated", {"attributes": {"dexterity": "1D", "strength": "1D"}, "skills": {}, "equipment": {"armor": "heavy_plate"}})
	armored.resolve_hostile_aggression("z", [11], 5100)
	_assert_equal(int(armored.player_state(11).get("player_wound_severity", 0)), 0, "before ticking, the armored victim is unwounded (0D direct bite)")
	var poison_casualty := false
	for w in range(6):
		var t2: Dictionary = armored.tick_status_effects(6100 + w)
		for c in t2.get("casualties", []):
			if int((c as Dictionary).get("peer", 0)) == 11 and int((c as Dictionary).get("killer", -1)) == 0:
				poison_casualty = true
	_assert_true(int(armored.player_state(11).get("player_wound_severity", 0)) >= CombatArena.DISABLED_SEVERITY, "venom IGNORES armor and is LETHAL — the heavily-armored 1D victim is downed by the toxin")
	_assert_true(poison_casualty, "a venom kill emits a casualty {peer, killer:0} routed through the DIV-0027 takeout path")

	# =========================================================================================
	# (B) RE-BITE REFRESHES the schedule (no infinite stacking) — a fresh bite resets rounds + applied_window.
	# =========================================================================================
	var reb := CombatArena.new(_rules, data)
	reb.register_hostile_target("z", _hostile_pools("3D"), {"distance": 3.0, "cover_level": 0, "name": "Spor Crawler"}, {}, _rider(cdata, "venom_soak_test", 333))
	reb.register_player(12, "Repeat", {"attributes": {"dexterity": "1D", "strength": "30D"}, "skills": {}})
	reb.resolve_hostile_aggression("z", [12], 5200)
	reb.tick_status_effects(6200)  # consume a window (onset window; still 3 ahead)
	reb.tick_status_effects(6201)
	reb.tick_status_effects(6202)  # round 2 fires -> now 2 ahead
	_assert_equal(int(reb.player_status_summary(12).get("poison_rounds_left", 0)), 2, "mid-schedule the venom has 2 ticks left (baseline before the re-bite)")
	reb.resolve_hostile_aggression("z", [12], 5299)  # RE-BITE
	_assert_equal(int(reb.player_status_summary(12).get("poison_rounds_left", 0)), 3, "a RE-BITE REFRESHES the schedule back to full (3) rather than stacking")

	# =========================================================================================
	# (C) RESTRAINT opposed-break — BOTH branches, deterministically chosen by the STR mismatch.
	# =========================================================================================
	# BREAK branch: a 12D-Strength victim vs a 1D-Strength holder wins the opposed roll and breaks free.
	var brk := CombatArena.new(_rules, data)
	brk.register_hostile_target("z", _hostile_pools("1D"), {"distance": 3.0, "cover_level": 0, "name": "Glim Worm"}, {}, _rider(cdata, "grip_break_test", 444))
	brk.register_player(20, "Strong", {"attributes": {"dexterity": "1D", "strength": "12D"}, "skills": {}})
	brk.resolve_hostile_aggression("z", [20], 5300)
	_assert_true(bool(brk.player_status_summary(20).get("restrained", false)), "a landed hit SEEDS restraint (victim is held)")
	var broke := false
	for w in range(4):
		var tb: Dictionary = brk.tick_status_effects(6300 + w)
		for env in tb.get("envelopes", []):
			if String((env as Dictionary).get("status", "")) == "restraint" and bool((env as Dictionary).get("broke_free", false)):
				broke = true
		if not bool(brk.player_status_summary(20).get("restrained", false)):
			break
	_assert_true(broke, "a far-stronger victim WINS the opposed break check and breaks free")
	_assert_true(not bool(brk.player_status_summary(20).get("restrained", false)), "breaking free CLEARS the restraint status")

	# HELD (pure hold, empty hold_damage): a 1D victim vs an 8D holder stays gripped, takes NO crush.
	var held := CombatArena.new(_rules, data)
	held.register_hostile_target("z", _hostile_pools("8D"), {"distance": 3.0, "cover_level": 0, "name": "Glim Worm"}, {}, _rider(cdata, "grip_break_test", 555))
	held.register_player(21, "Weak", {"attributes": {"dexterity": "1D", "strength": "1D"}, "skills": {}})
	held.resolve_hostile_aggression("z", [21], 5400)
	for w in range(3):
		held.tick_status_effects(6400 + w)
	_assert_true(bool(held.player_status_summary(21).get("restrained", false)), "a much weaker victim LOSES the break check and stays held")
	_assert_equal(int(held.player_state(21).get("player_wound_severity", 0)), 0, "an EMPTY-hold_damage grapple crushes for nothing (pure hold, severity stays 0)")

	# HELD + CRUSH (STR+2D hold_damage): a 1D victim vs an 8D holder is held and crushed -> downed casualty.
	var crush := CombatArena.new(_rules, data)
	crush.register_hostile_target("z", _hostile_pools("8D"), {"distance": 3.0, "cover_level": 0, "name": "Stalker Lizard"}, {}, _rider(cdata, "grip_crush_test", 666))
	crush.register_player(22, "Prey", {"attributes": {"dexterity": "1D", "strength": "1D"}, "skills": {}})
	crush.resolve_hostile_aggression("z", [22], 5500)
	var crush_casualty := false
	for w in range(5):
		var tc: Dictionary = crush.tick_status_effects(6500 + w)
		for c in tc.get("casualties", []):
			if int((c as Dictionary).get("peer", 0)) == 22 and int((c as Dictionary).get("killer", -1)) == 0:
				crush_casualty = true
		if int(crush.player_state(22).get("player_wound_severity", 0)) >= CombatArena.DISABLED_SEVERITY:
			break
	_assert_true(int(crush.player_state(22).get("player_wound_severity", 0)) >= CombatArena.DISABLED_SEVERITY, "a held victim takes the STR+2D crush and is downed")
	_assert_true(crush_casualty, "a hold-crush kill emits a casualty {peer, killer:0} for the DIV-0027 path")

	# =========================================================================================
	# (D) a DOWNED victim (>= DISABLED_SEVERITY) is NEVER ticked — the downed loop owns them; status is dropped.
	# =========================================================================================
	var dn := CombatArena.new(_rules, data)
	dn.register_hostile_target("z", _hostile_pools("3D"), {"distance": 3.0, "cover_level": 0, "name": "Spor Crawler"}, {}, _rider(cdata, "venom_lethal_test", 777))
	dn.register_player(30, "Fallen", {"attributes": {"dexterity": "1D", "strength": "1D"}, "skills": {}})
	dn.resolve_hostile_aggression("z", [30], 5600)  # seed venom while UP
	_assert_true(int(dn.player_status_summary(30).get("poison_rounds_left", 0)) > 0, "the victim is poisoned while still up")
	dn.set_player_combat(30, {"player_wound_severity": CombatArena.DISABLED_SEVERITY, "player_wound_level": "incapacitated"})  # now DOWNED (by the downed loop's domain)
	var dtick: Dictionary = dn.tick_status_effects(6600)
	var touched_downed := false
	for env in dtick.get("envelopes", []):
		if int((env as Dictionary).get("subject_id", 0)) == 30:
			touched_downed = true
	_assert_true(not touched_downed, "a DOWNED victim is NEVER ticked (no status envelope emitted for them)")
	_assert_equal(int(dn.player_status_summary(30).get("poison_rounds_left", 0)), 0, "a downed victim's lingering status is DROPPED (the downed loop owns them)")
	_assert_equal(int(dn.player_state(30).get("player_wound_severity", 0)), CombatArena.DISABLED_SEVERITY, "the venom does not further escalate a downed victim's wound")

	# =========================================================================================
	# (E) DETERMINISM: identical setup + identical server seeds -> identical wound outcome (server owns every die).
	# =========================================================================================
	var det1 := _run_venom_to_end(cdata, 888, 7000)
	var det2 := _run_venom_to_end(cdata, 888, 7000)
	_assert_equal(det1, det2, "same rider seed + same per-window seeds reproduce the identical venom outcome (replayable/auditable)")

	# --- REAL-data composition: a real creature's rider bakes + seeds through the same wiring. ---
	var real := _load_json(CREATURE_DATA_PATH)
	if not (real.get("creatures", {}) as Dictionary).is_empty() and (real.get("creatures", {}) as Dictionary).has("spor_crawler"):
		var real_rider := _rider(real, "spor_crawler", 999)
		_assert_true(bool(real_rider.get("has_special_attack", false)), "spor_crawler (real data) bakes a special_attack rider")
		_assert_true(not (real_rider.get("poison_schedule", []) as Array).is_empty(), "spor_crawler bakes a non-empty poison schedule")
		var ra := CombatArena.new(_rules, data)
		ra.register_hostile_target("z", _hostile_pools("2D"), {"distance": 3.0, "cover_level": 0, "name": "Spor Crawler"}, {}, real_rider)
		ra.register_player(40, "Field", {"attributes": {"dexterity": "1D", "strength": "2D"}, "skills": {}})
		ra.resolve_hostile_aggression("z", [40], 5700)
		_assert_true(int(ra.player_status_summary(40).get("poison_rounds_left", 0)) > 0, "a real-data creature seeds venom onto a victim through the live wiring")

	if _rules.has_method("free"):
		_rules.free()
	if _failures.is_empty():
		print("creature_status_wire_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

# Drive a 1D victim through a full lethal venom schedule; return the final wound severity (for determinism).
func _run_venom_to_end(cdata: Dictionary, rider_seed: int, tick_seed: int) -> int:
	var a := CombatArena.new(_rules, _combat_data())
	a.register_hostile_target("z", _hostile_pools("3D"), {"distance": 3.0, "cover_level": 0, "name": "Spor Crawler"}, {}, _rider(cdata, "venom_lethal_test", rider_seed))
	a.register_player(99, "Sub", {"attributes": {"dexterity": "1D", "strength": "1D"}, "skills": {}})
	a.resolve_hostile_aggression("z", [99], tick_seed)
	for w in range(6):
		a.tick_status_effects(tick_seed + 1 + w)
	return int(a.player_state(99).get("player_wound_severity", 0))

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {
			"blaster": "4D+1", "dodge": "4D", "soak": "3D",
			"weapon": "training_blaster", "armor": "blast_vest", "scale": "character",
		},
		"weapons": {"training_blaster": {"damage": "4D"}, "remote_stun_blaster": {"damage": "3D+2"}},
		"armors": {"blast_vest": {"protection_energy": "0D+1", "protection_physical": "1D", "dexterity_penalty": "-1D", "coverage": ["torso"]}},
		"targets": {"b1_training_silhouette": {
			"blaster": "3D", "weapon": "remote_stun_blaster", "soak": "2D",
			"scale": "character", "distance": 12.0, "cover_level": 0, "name": "B1 Training Remote",
		}},
	}

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
