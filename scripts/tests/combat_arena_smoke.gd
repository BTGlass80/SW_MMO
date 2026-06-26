extends SceneTree
## Headless smoke test for the server-authoritative combat arena (M1.3).
## Verifies: a fire intent resolves to a versioned combat envelope; resolution is
## deterministic under a fixed server seed (replayable/auditable); damage does not
## decrease; multiple shooters each get an envelope; an empty window is a no-op; and
## a disabled target reports already-disabled. All dice are server-owned here.

const CombatArena := preload("res://scripts/net/combat_arena.gd")

var _failures: Array[String] = []
var _rules: Object

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	var data := _combat_data()

	# 1. A single fire intent resolves to one well-formed envelope.
	var a1 := CombatArena.new(_rules, data)
	a1.register_player(2, "Mara")
	a1.set_player_name(2, "Mara Jade")  # M1.5: chosen display name flows into envelopes
	a1.submit_fire_intent(2, {"aim": 3})
	var r1: Dictionary = a1.resolve_window(4242)
	var env1: Array = r1.get("envelopes", [])
	_assert_equal(env1.size(), 1, "one shooter yields one envelope")
	if env1.size() == 1:
		var e: Dictionary = env1[0]
		_assert_equal(String(e.get("message_type", "")), "combat.exchange.resolved", "envelope message type")
		_assert_equal(int(e.get("shooter_id", -1)), 2, "envelope carries shooter id")
		_assert_equal(String(e.get("shooter_name", "")), "Mara Jade", "envelope carries the chosen display name")
		_assert_true(int(e.get("event_count", 0)) > 0, "envelope carries combat events")
		_assert_true(e.has("action_window"), "envelope carries the action window summary")

	# 2. Determinism: same seed + same setup => identical target outcome.
	var a2 := CombatArena.new(_rules, data)
	a2.register_player(2, "Mara")
	a2.submit_fire_intent(2, {"aim": 3})
	var r2: Dictionary = a2.resolve_window(4242)
	_assert_equal(
		int((r2.get("target_state", {}) as Dictionary).get("wound_severity", -1)),
		int((r1.get("target_state", {}) as Dictionary).get("wound_severity", -2)),
		"same server seed reproduces the same target outcome"
	)

	# 3. Empty window is a no-op (intents were consumed in step 1).
	var r_empty: Dictionary = a1.resolve_window(99)
	_assert_equal((r_empty.get("envelopes", []) as Array).size(), 0, "no intents => no envelopes")

	# 4. Two shooters each get an envelope in one window.
	var b := CombatArena.new(_rules, data)
	b.register_player(2, "A")
	b.register_player(3, "B")
	b.submit_fire_intent(2, {"aim": 3})
	b.submit_fire_intent(3, {"aim": 3})
	var rb: Dictionary = b.resolve_window(777)
	_assert_equal((rb.get("envelopes", []) as Array).size(), 2, "two shooters yield two envelopes")

	# 5. Damage never decreases across windows (severity is a max).
	var c := CombatArena.new(_rules, data)
	c.register_player(2, "A")
	var prev := 0
	var monotone := true
	for w in range(15):
		c.submit_fire_intent(2, {"aim": 3})
		c.resolve_window(2000 + w)
		var sev := int(c.target_state().get("wound_severity", 0))
		if sev < prev:
			monotone = false
		prev = sev
	_assert_true(monotone, "target wound severity is monotonic across windows")

	# 6. A target reaches disabled and then reports already-disabled.
	var d := CombatArena.new(_rules, data)
	d.register_player(2, "A")
	var disabled := false
	for w in range(80):
		d.submit_fire_intent(2, {"aim": 3})
		d.resolve_window(3000 + w)
		if d.target_disabled():
			disabled = true
			break
	_assert_true(disabled, "sustained fire disables the training target")
	if disabled:
		d.submit_fire_intent(2, {"aim": 3})
		var rd: Dictionary = d.resolve_window(9001)
		var de: Array = rd.get("envelopes", [])
		_assert_true(de.size() == 1 and bool((de[0].get("flags", {}) as Dictionary).get("already_disabled", false)), "firing at a disabled target reports already-disabled")

	# D1: combat pools come from the character sheet (attack = DEX + blaster bonus).
	var arena := CombatArena.new(_rules, data)
	arena.register_player(7, "Default")  # no sheet -> trainee fallback pools
	_assert_equal(arena.attacker_pool_text(7), "4D+1", "no-sheet player uses the trainee blaster pool")
	arena.register_player(8, "Ace", {"attributes": {"dexterity": "4D", "strength": "3D"}, "skills": {"blaster": "2D"}})
	_assert_equal(arena.attacker_pool_text(8), "6D", "sheet attack pool = DEX 4D + blaster 2D")
	arena.set_player_sheet(8, {"attributes": {"dexterity": "2D"}, "skills": {}})
	_assert_equal(arena.attacker_pool_text(8), "2D", "set_player_sheet rebuilds the attack pool (DEX 2D, untrained)")

	# WEG initiative: the character's own Perception drives the initiative pool (was a fixed 3D).
	arena.register_player(13, "Scout", {"attributes": {"dexterity": "3D", "perception": "4D"}})
	_assert_equal(arena.perception_pool_text(13), "4D", "initiative pool = the sheet's Perception")
	arena.register_player(14, "Rookie")  # no sheet -> trainee fallback keeps the old fixed 3D
	_assert_equal(arena.perception_pool_text(14), "3D", "no-sheet player keeps the 3D initiative fallback")
	# Higher Perception acts first: a 6D-Perception shooter beats a 1D one in initiative order (seeded).
	var iarena := CombatArena.new(_rules, data)
	iarena.register_player(20, "Quick", {"attributes": {"dexterity": "3D", "perception": "6D"}})
	iarena.register_player(21, "Slow", {"attributes": {"dexterity": "3D", "perception": "1D"}})
	iarena.submit_fire_intent(20, {"aim": 0})
	iarena.submit_fire_intent(21, {"aim": 0})
	var ienv: Array = iarena.resolve_window(31337).get("envelopes", [])
	_assert_true(ienv.size() == 2 and int((ienv[0] as Dictionary).get("shooter_id", 0)) == 20, "higher-Perception shooter resolves first in initiative order")

	# D2: the equipped weapon drives the damage pool (armor catalog also supplied).
	var weapons := {"blaster_pistol": {"damage": "4D"}, "heavy_blaster": {"damage": "5D"}}
	var armors := {"blast_vest": {"protection_energy": "+1D", "coverage": ["torso"]}}
	var geared := CombatArena.new(_rules, data, "b1_training_silhouette", weapons, armors)
	geared.register_player(9, "Gunner", {"attributes": {"dexterity": "3D"}, "equipment": {"weapon": "heavy_blaster", "armor": "blast_vest"}})
	_assert_equal(geared.damage_pool_text(9), "5D", "equipped heavy blaster sets a 5D damage pool")
	_assert_equal(geared.damage_pool_fp_text(9), "10D", "F55: a Force Point doubles the RANGED damage pool (5D -> 10D)")
	geared.register_player(10, "Unarmed", {"attributes": {"dexterity": "3D"}})  # no equipment
	_assert_equal(geared.damage_pool_text(10), "4D", "no equipment falls back to the default weapon damage")

	# Melee weapon: damage = STR + the weapon bonus (derived-stats melee model), and the attack
	# uses the weapon's OWN skill (melee_combat), not blaster. Previously a melee weapon dealt
	# 0D because parse_pool("STR+3D") == 0D.
	var mweapons := {"vibroblade": {"damage": "STR+3D", "skill": "melee_combat"}}
	var melee_arena := CombatArena.new(_rules, data, "b1_training_silhouette", mweapons, armors)
	melee_arena.register_player(11, "Blademaster", {"attributes": {"dexterity": "3D", "strength": "2D"}, "skills": {"melee_combat": "1D"}, "equipment": {"weapon": "vibroblade"}})
	_assert_equal(melee_arena.damage_pool_text(11), "5D", "melee vibroblade damage = STR 2D + 3D bonus")
	_assert_equal(melee_arena.damage_pool_fp_text(11), "7D", "F55: a Force Point doubles melee STR(2D) only, not the +3D bonus (5D -> 7D)")
	_assert_equal(melee_arena.attacker_pool_text(11), "4D", "melee attack uses DEX 3D + melee_combat 1D (not blaster)")

	# An INCAPACITATED (sev >= 3) shooter is out and cannot act: the fire intent is dropped.
	var inc := CombatArena.new(_rules, data)
	inc.register_player(12, "Downed")
	inc.set_player_combat(12, {"player_wound_severity": 3})  # incapacitated
	inc.submit_fire_intent(12, {"aim": 3})
	_assert_equal(inc.pending_intent_count(), 0, "an incapacitated shooter's fire intent is dropped")
	_assert_equal((inc.resolve_window(123).get("envelopes", []) as Array).size(), 0, "incapacitated shooter yields no envelope")
	inc.set_player_combat(12, {"player_wound_severity": 2})  # wounded -> 'can still act'
	inc.submit_fire_intent(12, {"aim": 3})
	_assert_equal(inc.pending_intent_count(), 1, "a wounded (can-act) shooter's intent IS queued")

	# DIV-0016: NON-LETHAL SPARRING DAMAGE. A sparring target (stun_return_fire:false) returns fire as
	# a REAL wound, but combat_arena clamps the player at SPARRING_MAX_SEVERITY=2 (Wounded) -- never
	# incapacitated(3+). Lights up the wound/recovery/First-Aid loop with no death/respawn. Low-soak
	# trainee (STR 1D) + weak attack so return fire reliably wounds; reset the target each window so
	# the sparring remote stays alive and keeps returning fire. All seeds fixed (no randomize).
	var spar := CombatArena.new(_rules, _sparring_data())
	spar.register_player(2, "Trainee", {"attributes": {"dexterity": "2D", "strength": "1D"}, "skills": {}})
	var spar_max := 0
	var spar_exceeded := false
	for w in range(60):
		spar.reset_target()
		spar.submit_fire_intent(2, {"aim": 0})
		spar.resolve_window(5000 + w)
		var psev := int(spar.player_state(2).get("player_wound_severity", 0))
		spar_max = maxi(spar_max, psev)
		if psev > CombatArena.SPARRING_MAX_SEVERITY:
			spar_exceeded = true
	_assert_true(not spar_exceeded, "sparring target NEVER pushes the player past Wounded(2) -- no incapacitation/death")
	_assert_true(spar_max >= 2, "sparring return fire actually inflicts a real Wounded(2) (the data-driven non-stun path + the cap are both load-bearing, not a no-op)")
	_assert_true(spar_max < CombatArena.DISABLED_SEVERITY, "the sparring-wounded player is never 'out' (severity stayed below DISABLED_SEVERITY)")
	# Still able to act after being sparring-wounded (the cap kept them below the can't-act tier).
	spar.submit_fire_intent(2, {"aim": 0})
	_assert_equal(spar.pending_intent_count(), 1, "a sparring-wounded player can still queue a fire intent")

	# Clamp only LOWERS: a player already at the ceiling stays exactly 2 after a sparring window
	# (model maxi never heals below 2; arena mini never raises above 2).
	var capped := CombatArena.new(_rules, _sparring_data())
	capped.register_player(2, "Capped", {"attributes": {"dexterity": "2D", "strength": "1D"}, "skills": {}})
	capped.set_player_combat(2, {"player_wound_severity": 2})
	capped.reset_target()
	capped.submit_fire_intent(2, {"aim": 0})
	capped.resolve_window(7000)
	_assert_equal(int(capped.player_state(2).get("player_wound_severity", 0)), 2, "the ceiling clamp holds a wounded player at exactly 2")

	# Stun-default regression: a target WITHOUT stun_return_fire (defaults true) returns PURE WEG stun
	# -- the player can never exceed Stunned(1), exactly as before this change.
	var stun := CombatArena.new(_rules, _combat_data())
	stun.register_player(2, "StunTrainee", {"attributes": {"dexterity": "2D", "strength": "1D"}, "skills": {}})
	var stun_max := 0
	for w in range(40):
		stun.reset_target()
		stun.submit_fire_intent(2, {"aim": 0})
		stun.resolve_window(8000 + w)
		stun_max = maxi(stun_max, int(stun.player_state(2).get("player_wound_severity", 0)))
	_assert_true(stun_max <= 1, "default (no stun_return_fire) return fire is pure WEG stun -- player never exceeds Stunned(1)")

	# F51: a defensive stance (full_dodge) forgoes the attack -> the envelope carries a
	# player_full_dodge event and the player does NOT damage the target.
	var fd := CombatArena.new(_rules, data)
	fd.register_player(30, "Defender", {"attributes": {"dexterity": "3D", "strength": "2D"}})
	fd.submit_fire_intent(30, {"full_dodge": true})
	var fdr: Dictionary = fd.resolve_window(4321)
	var fde: Array = fdr.get("envelopes", [])
	_assert_equal(fde.size(), 1, "a full-dodge intent still yields one envelope")
	if fde.size() == 1:
		_assert_true(((fde[0] as Dictionary).get("event_types", []) as Array).has("player_full_dodge"), "defensive stance emits a player_full_dodge event")
	_assert_equal(int((fdr.get("target_state", {}) as Dictionary).get("wound_severity", -1)), 0, "a full-dodging player does NOT damage the target")

	# F52: an active-dodge intent attacks AND actively dodges -> the player's defense vs the return
	# fire is "dodge" (reflected on the remote_return_fire event). Sparring data so return fire lands;
	# reset the target each window so it keeps shooting back. The player_attack event also gets
	# action_count 2 (the -1D multi-action attack penalty — dodging costs you offense).
	var dg := CombatArena.new(_rules, _sparring_data())
	dg.register_player(31, "Dodger", {"attributes": {"dexterity": "3D", "strength": "2D"}, "skills": {"dodge": "2D"}})
	var found_dodge_defense := false
	var found_multi_action := false
	for w in range(20):
		dg.reset_target()
		dg.submit_fire_intent(31, {"aim": 0, "dodge": true})
		for env in dg.resolve_window(5151 + w).get("envelopes", []):
			for ev in (env as Dictionary).get("events", []):
				var et := String((ev as Dictionary).get("type", ""))
				if et == "remote_return_fire" and String((ev as Dictionary).get("defense_type", "")) == "dodge":
					found_dodge_defense = true
				elif et == "player_attack" and int((ev as Dictionary).get("action_count", 1)) == 2:
					found_multi_action = true
	_assert_true(found_dodge_defense, "an active-dodge attack defends the return fire with defense_type 'dodge'")
	_assert_true(found_multi_action, "an active-dodge attack costs a -1D multi-action (player_attack action_count 2)")

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

## DIV-0016: a copy of the combat data whose training target returns fire as a REAL (arena-capped)
## wound instead of pure stun. Isolated from _combat_data() so the existing tests (which expect the
## stun-default behavior) are untouched.
func _sparring_data() -> Dictionary:
	var d := _combat_data()
	((d["targets"] as Dictionary)["b1_training_silhouette"] as Dictionary)["stun_return_fire"] = false
	return d

func _finish() -> void:
	if _failures.is_empty():
		print("combat_arena_smoke: OK")
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
