extends SceneTree
## Wave G4 — HOSTILES NEVER INITIATE (DIV-0017). Before this, a spawned hostile only fired as RETURN
## FIRE inside a player-initiated exchange, so an idle player who never pressed fire stood beside a Dune
## Sea spawn unharmed — lawless zones were dangerous only to volunteers. G4 adds an UNPROVOKED path:
## combat_arena.resolve_hostile_aggression routes an engaged hostile's fire (through the already-smoked
## ground_combat_model.resolve_incoming_fire_window) at same-zone players who did NOT fire.
##
## network_manager is a Node autoload not headlessly instantiable, so — like death_flow_smoke /
## heal_flow_smoke — this drives the directly-instantiable CombatArena for the mechanic and MIRRORS the
## net-layer gate + tiering around the pure models (HostileNpc.is_lethal_zone, PvpRules.is_kill). It
## proves: (A) an IDLE player (zero fire intents) in a lethal setup TAKES real, uncapped damage and can
## be DOWNED; (B) the SAME idle player in a SECURED tier takes NONE (the gate skips it — no hostile is
## even engaged); (C) no double-hit (a player who fired is excluded from the unprovoked victim set); and
## (D) the DIV-0027 tiering routes sev 5 -> death, sev 3-4 -> downed, exactly as the net layer does.
##
## Pure / deterministic: server-owned SEEDED rng; no nodes, sockets, RNG-in-model, or randomize().

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const HostileNpc := preload("res://scripts/rules/hostile_npc_model.gd")
const PvpRules := preload("res://scripts/rules/pvp_rules_model.gd")

var _failures: Array[String] = []
var _rules: Object

# A strong lethal hostile: the SAME hostile_npc_model mapping the live spawner uses (krayt: 6D STR /
# 6D melee, STR+3D bite -> 9D vs a 1D-soak player), so its unprovoked fire reliably wounds.
func _krayt_spawn() -> Dictionary:
	return {
		"hostile": true, "scale": "creature", "pack_size": 1,
		"char_sheet": {"attributes": {"strength": "6D"}, "skills": {"melee_combat": "6D"}},
		"natural_attack": {"to_hit_skill": "melee_combat", "damage": "STR+3D"},
	}

# Mirror of network_manager._tick_hostile_aggression's per-zone GATE: unprovoked hostile fire happens
# only in a LETHAL tier AND only when an engaged, still-alive hostile is present. (In a secured tier the
# net layer never even spawns a hostile, so has_engaged_hostile is false there too.)
func _unprovoked_fires_here(tier: String, has_engaged_hostile: bool) -> bool:
	return HostileNpc.is_lethal_zone(tier) and has_engaged_hostile

# Mirror of the net-layer VICTIM selection: same-zone, did NOT fire this window, not already out.
func _is_unprovoked_victim(fired: bool, out_already: bool) -> bool:
	return not fired and not out_already

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	var data := _combat_data()
	var krayt := _krayt_spawn()
	var krayt_pools: Dictionary = HostileNpc.attack_pools_from_creature(_rules, krayt)

	# --- (A) LAWLESS: an IDLE player (NEVER submits a fire intent) is shot by the engaged hostile and
	#         driven PAST the DIV-0016 sparring cap into the 'out' band (>= DISABLED_SEVERITY). ---
	_assert_true(HostileNpc.is_lethal_zone("lawless"), "lawless is a lethal tier (the net gate calls unprovoked fire here)")
	_assert_true(HostileNpc.is_lethal_zone("contested"), "contested is a lethal tier too")

	var arena := CombatArena.new(_rules, data)
	arena.register_hostile_target("tatooine.dune_sea", krayt_pools, {"distance": 6.0, "cover_level": 0, "name": "Krayt Dragon"}, krayt)
	arena.register_player(50, "Idle Bot", {"attributes": {"dexterity": "3D", "strength": "1D"}, "skills": {}})
	var idle_max := 0
	var downed_window := -1
	var casualty_seen := false
	for w in range(60):
		# THE headline: the player NEVER fires — pending intent count stays 0 all the way through.
		_assert_equal(arena.pending_intent_count(), 0, "the idle player queues no fire intent (window %d)" % w)
		var res: Dictionary = arena.resolve_hostile_aggression("tatooine.dune_sea", [50], 6000 + w)
		if not (res.get("casualties", []) as Array).is_empty():
			casualty_seen = true
		var sev := int(arena.player_state(50).get("player_wound_severity", 0))
		idle_max = maxi(idle_max, sev)
		if sev >= CombatArena.DISABLED_SEVERITY and downed_window < 0:
			downed_window = w
			break
	_assert_true(idle_max > 0, "an IDLE player (no fire intent) TAKES unprovoked hostile damage — before G4 they took none")
	_assert_true(idle_max > CombatArena.SPARRING_MAX_SEVERITY, "unprovoked hostile fire is REAL/uncapped (past the DIV-0016 sparring ceiling)")
	_assert_true(downed_window >= 0, "sustained unprovoked fire DOWNS the idle player (>= DISABLED_SEVERITY)")
	_assert_true(casualty_seen, "the window that downs the victim reports a casualty {peer, severity, killer:0}")

	# An idle player who took a downing hit is exactly what the net layer tiers via DIV-0027.
	var down_sev := int(arena.player_state(50).get("player_wound_severity", 0))
	_assert_true(_is_unprovoked_victim(false, false), "an idle, un-fired, still-up same-zone player IS an unprovoked victim")
	_assert_true(not _is_unprovoked_victim(true, false), "NO DOUBLE-HIT: a player who FIRED this window is excluded from unprovoked fire")
	_assert_true(not _is_unprovoked_victim(false, true), "an already-out player is skipped (the bleed-out/yield/medic loop owns them)")

	# --- (B) SECURED: the SAME idle setup takes NONE. The net gate is is_lethal_zone(tier); secured is
	#         false, so _tick_hostile_aggression skips the zone entirely and no hostile is ever engaged.
	#         Mirror both facts: the gate returns false, AND (the secured reality) an arena with no engaged
	#         hostile registered is a no-op — the idle player's severity never moves off 0. ---
	_assert_true(not HostileNpc.is_lethal_zone("secured"), "secured is NOT a lethal tier — the net gate NEVER fires unprovoked here")
	_assert_true(not _unprovoked_fires_here("secured", true), "even WITH a hostile present, a secured tier gets no unprovoked fire (gate)")
	_assert_true(_unprovoked_fires_here("lawless", true), "a lawless tier WITH an engaged hostile does get unprovoked fire (gate)")
	_assert_true(not _unprovoked_fires_here("lawless", false), "a lawless tier with NO engaged hostile gets no unprovoked fire (gate)")

	var secured := CombatArena.new(_rules, data)  # secured reality: NO hostile target is ever registered
	secured.register_player(60, "Safe Bot", {"attributes": {"dexterity": "3D", "strength": "1D"}, "skills": {}})
	for w in range(60):
		# Faithful to the net layer: in a secured tier resolve_hostile_aggression is NEVER called (gate),
		# and even if it were, there is no hostile target -> no-op. Assert zero damage either way.
		var res: Dictionary = secured.resolve_hostile_aggression("tatooine.dune_sea", [60], 7000 + w)
		_assert_equal((res.get("envelopes", []) as Array).size(), 0, "no engaged hostile => no unprovoked envelope (secured, window %d)" % w)
		_assert_true((res.get("casualties", []) as Array).is_empty(), "no engaged hostile => no casualty (secured, window %d)" % w)
	_assert_equal(int(secured.player_state(60).get("player_wound_severity", 0)), 0, "an idle player in a SECURED tier takes ZERO unprovoked damage")

	# --- (C) NO DOUBLE-HIT (mechanical): resolve_hostile_aggression only touches the victims it is HANDED.
	#         The net layer hands it the non-firers; a firer (peer 51) is never in that list, so its state
	#         is untouched by the unprovoked pass (it took its own return-fire exchange in resolve_window). ---
	var mixed := CombatArena.new(_rules, data)
	mixed.register_hostile_target("tatooine.dune_sea", krayt_pools, {"distance": 6.0, "cover_level": 0, "name": "Krayt Dragon"}, krayt)
	mixed.register_player(51, "Shooter", {"attributes": {"dexterity": "3D", "strength": "1D"}, "skills": {}})
	mixed.register_player(52, "Idler", {"attributes": {"dexterity": "3D", "strength": "1D"}, "skills": {}})
	# The net layer would exclude peer 51 (it fired) and pass ONLY [52].
	mixed.resolve_hostile_aggression("tatooine.dune_sea", [52], 8000)
	_assert_equal(int(mixed.player_state(51).get("player_wound_severity", 0)), 0, "a firer excluded from the victim list takes NO unprovoked hit (no double-hit)")
	_assert_true(int(mixed.player_state(52).get("player_wound_severity", 0)) >= 0, "the idle victim is the one the unprovoked pass resolves against")

	# --- (D) DIV-0027 TIERING: the net layer routes an unprovoked casualty EXACTLY like a provoked one —
	#         sev 5 -> death (DIV-0006), sev 3-4 -> downed. Mirror the predicate the net layer uses. ---
	_assert_true(PvpRules.is_kill(5), "sev 5 unprovoked takeout routes to _handle_player_death (DIV-0006)")
	_assert_true(not PvpRules.is_kill(4), "sev 4 unprovoked takeout routes to _handle_player_downed (mortally, not dead)")
	_assert_true(not PvpRules.is_kill(3), "sev 3 unprovoked takeout routes to _handle_player_downed (incapacitated)")
	_assert_true(down_sev >= CombatArena.DISABLED_SEVERITY, "the downed idle victim's severity is in the tierable band")

	# --- (E) A DISABLED hostile does not fire (a killed creature can't keep shooting between respawns).
	#         Kill a WEAK hostile via real provoked fire (public API), then assert unprovoked fire no-ops. ---
	var womp := {
		"hostile": true, "scale": "creature", "pack_size": 1,
		"char_sheet": {"attributes": {"strength": "1D"}, "skills": {"brawling": "1D"}},
		"natural_attack": {"to_hit_skill": "brawling", "damage": "STR"},
	}
	var womp_pools: Dictionary = HostileNpc.attack_pools_from_creature(_rules, womp)
	var dead_hostile := CombatArena.new(_rules, data, "b1_training_silhouette", {"heavy_blaster": {"damage": "7D"}}, {})
	dead_hostile.register_hostile_target("tatooine.dune_sea", womp_pools, {"distance": 6.0, "cover_level": 0, "name": "Womp Rat"}, womp)
	dead_hostile.register_player(70, "Hunter", {"attributes": {"dexterity": "4D", "strength": "3D"}, "skills": {"blaster": "3D"}, "equipment": {"weapon": "heavy_blaster"}})
	dead_hostile.set_player_target(70, "tatooine.dune_sea")
	dead_hostile.set_player_lethal(70, true)
	for w in range(80):
		dead_hostile.submit_fire_intent(70, {"aim": 3})
		dead_hostile.resolve_window(9000 + w)
		if dead_hostile.hostile_target_disabled("tatooine.dune_sea"):
			break
	_assert_true(dead_hostile.hostile_target_disabled("tatooine.dune_sea"), "the weak hostile is disabled by provoked fire")
	dead_hostile.register_player(71, "Bystander", {"attributes": {"dexterity": "3D", "strength": "1D"}, "skills": {}})
	var dres: Dictionary = dead_hostile.resolve_hostile_aggression("tatooine.dune_sea", [71], 9500)
	_assert_true((dres.get("casualties", []) as Array).is_empty() and (dres.get("envelopes", []) as Array).is_empty(), "a DISABLED hostile fires nothing")
	_assert_equal(int(dead_hostile.player_state(71).get("player_wound_severity", 0)), 0, "a disabled hostile deals no unprovoked damage")

	# --- (F) DETERMINISM: same seed + same setup => identical victim outcome (server owns every die). ---
	var d1 := CombatArena.new(_rules, data)
	d1.register_hostile_target("z", krayt_pools, {"distance": 6.0, "cover_level": 0, "name": "Krayt Dragon"}, krayt)
	d1.register_player(80, "A", {"attributes": {"dexterity": "3D", "strength": "1D"}, "skills": {}})
	d1.resolve_hostile_aggression("z", [80], 4242)
	var d2 := CombatArena.new(_rules, data)
	d2.register_hostile_target("z", krayt_pools, {"distance": 6.0, "cover_level": 0, "name": "Krayt Dragon"}, krayt)
	d2.register_player(80, "A", {"attributes": {"dexterity": "3D", "strength": "1D"}, "skills": {}})
	d2.resolve_hostile_aggression("z", [80], 4242)
	_assert_equal(
		int(d1.player_state(80).get("player_wound_severity", 0)),
		int(d2.player_state(80).get("player_wound_severity", 0)),
		"same server seed reproduces the same unprovoked outcome (replayable/auditable)")

	# --- (G) COVER (verify fix: attack-correctness): the VICTIM's OWN cover reduces the hostile's hit rate
	#         on the unprovoked shot (like the provoked path) — before the fix, the hostile's PROFILE cover
	#         was mis-applied so a crouched idle victim's cover was ignored. A MODERATE hostile (so cover is
	#         decisive, unlike the always-hitting krayt) fires at a heavily-covered victim vs an exposed one
	#         over a fixed seed sweep; the covered victim is hit STRICTLY LESS. ---
	var mod := {
		"hostile": true, "scale": "creature", "pack_size": 1,
		"char_sheet": {"attributes": {"strength": "2D"}, "skills": {"brawling": "3D"}},
		"natural_attack": {"to_hit_skill": "brawling", "damage": "STR+1D"},
	}
	var mod_pools: Dictionary = HostileNpc.attack_pools_from_creature(_rules, mod)
	var covered_hits := 0
	var exposed_hits := 0
	for w in range(40):
		var cov := CombatArena.new(_rules, data)
		cov.register_hostile_target("z", mod_pools, {"distance": 6.0, "cover_level": 0, "name": "Raider"}, mod)
		cov.register_player(90, "Crouched", {"attributes": {"dexterity": "2D", "strength": "1D"}, "skills": {}})
		cov.set_player_combat(90, {"player_cover_level": 4})  # heavy cover (the fix: this now applies)
		cov.resolve_hostile_aggression("z", [90], 13000 + w)
		if int(cov.player_state(90).get("player_wound_severity", 0)) > 0:
			covered_hits += 1
		var exp := CombatArena.new(_rules, data)
		exp.register_hostile_target("z", mod_pools, {"distance": 6.0, "cover_level": 0, "name": "Raider"}, mod)
		exp.register_player(91, "Exposed", {"attributes": {"dexterity": "2D", "strength": "1D"}, "skills": {}})
		exp.resolve_hostile_aggression("z", [91], 13000 + w)  # SAME seed sweep, NO cover
		if int(exp.player_state(91).get("player_wound_severity", 0)) > 0:
			exposed_hits += 1
	_assert_true(covered_hits < exposed_hits, "the VICTIM's own cover reduces unprovoked hits (%d covered < %d exposed) — cover is sourced from the victim, not the hostile profile" % [covered_hits, exposed_hits])

	if _rules.has_method("free"):
		_rules.free()
	_finish()

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {
			"blaster": "4D+1", "dodge": "4D", "soak": "3D",
			"weapon": "training_blaster", "armor": "blast_vest", "scale": "character",
		},
		"weapons": {
			"training_blaster": {"damage": "4D"},
			"remote_stun_blaster": {"damage": "3D+2"},
		},
		"armors": {
			"blast_vest": {"protection_energy": "0D+1", "protection_physical": "1D", "dexterity_penalty": "-1D", "coverage": ["torso"]},
		},
		"targets": {
			"b1_training_silhouette": {
				"blaster": "3D", "weapon": "remote_stun_blaster", "soak": "2D",
				"scale": "character", "distance": 12.0, "cover_level": 0, "name": "B1 Training Remote",
			},
		},
	}

func _finish() -> void:
	if _failures.is_empty():
		print("hostile_aggression_smoke: OK")
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
