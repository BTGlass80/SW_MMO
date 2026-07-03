extends SceneTree
## Consent-wire flow guard (DIV-0022). Proves the THREE clamps that must coexist after the duel wiring:
##   1. DIV-0016 sparring cap (dummy return fire never exceeds Wounded 2)
##   2. DIV-0022 duel KO clamp (a non-lethal duel's target/return-fire never exceeds Incapacitated 3)
##   3. DIV-0019 lethal lawless/bounty PvP (no clamp — a victim can be driven to Killed 5)
## plus the pure duel lifecycle (challenge->accept->active->conclude_ko) and the §1.2 precedence the arena
## gate is built from (duel in secured allowed non-lethal; no-duel secured denied; lawless open lethal).
## All seeds fixed; pure arena + consent model, no sockets.

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const PvpConsent := preload("res://scripts/rules/pvp_consent_model.gd")

var _failures: Array[String] = []
var _rules: Object

const GANKER := {"attributes": {"dexterity": "4D", "strength": "3D", "perception": "5D"}, "skills": {"blaster": "3D"}, "equipment": {"weapon": "hand_cannon"}}
const VICTIM := {"attributes": {"dexterity": "2D", "strength": "1D", "perception": "1D"}, "skills": {}, "equipment": {"weapon": "pea_shooter"}}

func _weapons() -> Dictionary:
	return {"hand_cannon": {"damage": "12D", "skill": "blaster"}, "pea_shooter": {"damage": "2D", "skill": "blaster"}}

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {"blaster": "4D+1", "dodge": "4D", "soak": "3D", "weapon": "training_blaster", "armor": "blast_vest", "scale": "character"},
		"weapons": {"training_blaster": {"damage": "4D"}, "remote_stun_blaster": {"damage": "3D+2"}},
		"armors": {"blast_vest": {"protection_energy": "0D+1", "protection_physical": "1D", "dexterity_penalty": "-1D", "coverage": ["torso"]}},
		"targets": {"b1_training_silhouette": {"blaster": "3D", "weapon": "remote_stun_blaster", "soak": "2D", "scale": "character", "distance": 12.0, "cover_level": 0, "stun_return_fire": false, "name": "B1 Training Remote"}},
	}

func _arena() -> CombatArena:
	return CombatArena.new(_rules, _combat_data(), "b1_training_silhouette", _weapons(), {})

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()

	# --- Clamp 2 (DIV-0022 duel KO): a NON-LETHAL duel caps the victim at Incapacitated (3), NEVER above. ---
	var duel_gate := {2: {"lethal": false, "cap": CombatArena.DUEL_KO_SEVERITY}}
	var d := _arena()
	d.register_player(2, "Ganker", GANKER)
	d.register_player(3, "Victim", VICTIM)
	var duel_max := 0
	var duel_cas_sev := 0
	for w in range(16):
		d.submit_fire_intent(2, {"aim": 3, "target_peer": 3})
		var res: Dictionary = d.resolve_window(3100 + w, duel_gate)
		duel_max = maxi(duel_max, int(d.player_state(3).get("player_wound_severity", 0)))
		for c in res.get("casualties", []):
			duel_cas_sev = maxi(duel_cas_sev, int((c as Dictionary).get("severity", 0)))
	_assert_true(duel_max >= CombatArena.DUEL_KO_SEVERITY, "a non-lethal duel drives the victim to the KO floor (>=3)")
	_assert_equal(duel_max, CombatArena.DUEL_KO_SEVERITY, "a non-lethal duel NEVER exceeds Incapacitated (3) — the duel KO clamp holds")
	_assert_true(duel_cas_sev == CombatArena.DUEL_KO_SEVERITY, "the duel casualty is emitted at exactly sev 3 (KO), never 4/5")
	_assert_true(String(d.player_state(3).get("player_wound_level", "")) == "incapacitated", "the duel KO victim carries the incapacitated level string (coherent with the capped sev)")

	# --- Clamp 3 (DIV-0019 lethal): the SAME ganker/victim under a LETHAL gate CAN exceed 3 (reach 5). ---
	var lethal_gate := {2: true}  # legacy bare-true auth == lethal, no clamp
	var l := _arena()
	l.register_player(2, "Ganker", GANKER)
	l.register_player(3, "Victim", VICTIM)
	var lethal_max := 0
	for w in range(16):
		l.submit_fire_intent(2, {"aim": 3, "target_peer": 3})
		l.resolve_window(3100 + w, lethal_gate)  # SAME seeds as the duel run
		lethal_max = maxi(lethal_max, int(l.player_state(3).get("player_wound_severity", 0)))
		if lethal_max >= 5:
			break
	_assert_true(lethal_max > CombatArena.DUEL_KO_SEVERITY, "lethal lawless PvP is NOT clamped — the victim exceeds 3 (got %d)" % lethal_max)
	_assert_true(lethal_max >= 5, "lethal lawless PvP can reach Killed (5) where the duel clamp would have stopped at 3")

	# --- Clamp 1 (DIV-0016 sparring): the shared training dummy still caps return fire at Wounded (2). ---
	var s := _arena()
	s.register_player(4, "Recruit", {"attributes": {"dexterity": "2D", "strength": "1D"}})
	var dummy_max := 0
	for w in range(30):
		s.reset_target()
		s.submit_fire_intent(4, {"aim": 0})  # no target_peer -> the shared dummy
		s.resolve_window(8200 + w)
		dummy_max = maxi(dummy_max, int(s.player_state(4).get("player_wound_severity", 0)))
	_assert_true(dummy_max <= CombatArena.SPARRING_MAX_SEVERITY, "the DIV-0016 sparring cap still holds (dummy return fire <= 2)")

	# The three ceilings are genuinely distinct and ordered: 2 (dummy) < 3 (duel KO) < 5 (lethal).
	_assert_true(CombatArena.SPARRING_MAX_SEVERITY < CombatArena.DUEL_KO_SEVERITY, "sparring cap (2) is below the duel KO cap (3)")
	_assert_true(CombatArena.DUEL_KO_SEVERITY < CombatArena.PVP_NO_CLAMP, "duel KO cap (3) is below the lethal no-clamp sentinel")

	# --- Pure duel lifecycle (the net layer drives these transitions) ---
	var st := PvpConsent.new_state()
	var ch: Dictionary = PvpConsent.challenge(st, 2, 3, "tatooine.mos_eisley.spaceport", 100.0, false)
	_assert_true(bool(ch.get("ok", false)), "challenge creates an OFFERED duel")
	st = ch["state"]
	_assert_equal(PvpConsent.offers_to(st, 3), [2], "offers_to lists the challenger for the challenged peer")
	var ac: Dictionary = PvpConsent.accept(st, 2, 3, 200.0)
	_assert_true(bool(ac.get("ok", false)), "accept moves OFFERED -> ACTIVE")
	st = ac["state"]
	_assert_true(PvpConsent.duel_active(st, 2, 3), "the pair is now mutually attackable (duel_active)")
	_assert_true(not PvpConsent.duel_lethal(st, 2, 3), "a default duel is NON-lethal")
	_assert_equal(int((PvpConsent.active_duel_of(st, 3) as Dictionary).get("opponent", 0)), 2, "active_duel_of names the opponent")
	var ko: Dictionary = PvpConsent.conclude_ko(st, 3)  # peer 3 reached the KO floor -> peer 2 wins
	_assert_true(bool(ko.get("ok", false)), "conclude_ko ends the ACTIVE duel")
	st = ko["state"]
	_assert_true(not PvpConsent.duel_active(st, 2, 3), "the duel is over after a KO")

	# --- BLOCKER 1 (audit): the challenger CANNOT self-accept his own offer (one-sided-consent bypass) ---
	var cs := PvpConsent.new_state()
	var off: Dictionary = PvpConsent.challenge(cs, 2, 3, "secured.newbie_zone", 10.0, true)  # A(2) offers B(3), LETHAL
	cs = off["state"]
	# the offer must expose the proposed lethality so the acceptor consents to the ACTUAL terms.
	var offered_rec: Dictionary = (cs.get("duels", {}) as Dictionary)[PvpConsent.pair_key(2, 3)]
	_assert_equal(bool(offered_rec.get("lethal", false)), true, "the OFFER carries the proposed lethality (acceptor consents to the real stakes)")
	# A self-accepts by claiming B is the challenger: accept(challenger=3, acceptor=2) on A's own offer.
	var self_ac: Dictionary = PvpConsent.accept(cs, 3, 2, 20.0)
	_assert_equal(String(self_ac.get("reason", "")), "wrong_side", "the challenger cannot self-accept (acceptor must be the CHALLENGED side)")
	_assert_true(not PvpConsent.duel_active(self_ac["state"], 2, 3), "the self-accept attack does NOT drive the duel ACTIVE")
	_assert_true(not PvpConsent.duel_active(cs, 2, 3), "the offer stays OFFERED, never active, after a wrong-side accept")
	# The legit acceptor (B=3) can still accept A's(2) offer.
	var good_ac: Dictionary = PvpConsent.accept(cs, 2, 3, 30.0)
	_assert_true(bool(good_ac.get("ok", false)) and PvpConsent.duel_active(good_ac["state"], 2, 3), "the true challenged party (B) CAN accept the offer")
	_assert_true(PvpConsent.duel_lethal(good_ac["state"], 2, 3), "the accepted duel keeps the offered LETHAL terms")

	# --- BLOCKER 2 (audit): abort ends a fled duelist's live duel/offer so it can't linger to timeout ---
	var zs := PvpConsent.new_state()
	zs = PvpConsent.challenge(zs, 5, 6, "z", 0.0, false)["state"]
	zs = PvpConsent.accept(zs, 5, 6, 1.0)["state"]
	_assert_true(PvpConsent.duel_active(zs, 5, 6), "duel active before either leaves")
	var ab: Dictionary = PvpConsent.abort(zs, 5)  # peer 5 travels away -> the net layer calls abort(traveler)
	_assert_true(bool(ab.get("ok", false)), "abort ends the traveler's live duel")
	zs = ab["state"]
	_assert_true(not PvpConsent.duel_active(zs, 5, 6), "a fled duelist's duel is ENDED (not left ACTIVE until DUEL_MAX_DURATION)")
	_assert_true(PvpConsent.active_duel_of(zs, 6).is_empty(), "the STAYING opponent is also freed (can duel again)")
	# a pending OFFER is aborted on leave too (not just active duels).
	var os: Dictionary = PvpConsent.challenge(PvpConsent.new_state(), 7, 8, "z", 0.0, false)["state"]
	os = PvpConsent.abort(os, 8)["state"]  # the CHALLENGED party leaves
	_assert_equal(PvpConsent.offers_to(os, 8), [], "a pending offer is aborted when the challenged party leaves the zone")

	# --- §1.2 precedence the arena gate is built from ---
	var A := {"id": 2, "is_player": true, "node_id": "z", "newbie_protected": false}
	var B := {"id": 3, "is_player": true, "node_id": "z", "newbie_protected": false}
	var secured_no_duel := PvpConsent.resolve(A, B, {"zone_tier": "secured", "duel_active": false, "bounty_eligible": false})
	_assert_equal(String(secured_no_duel.get("reason", "")), "protected_zone", "secured + no consent = protected (zone protection intact)")
	_assert_equal(bool(secured_no_duel.get("allowed", false)), false, "secured no-duel shot is DENIED")
	var secured_duel := PvpConsent.resolve(A, B, {"zone_tier": "secured", "duel_active": true, "duel_lethal": false, "bounty_eligible": false})
	_assert_equal(String(secured_duel.get("reason", "")), "duel", "a duel makes a secured target attackable")
	_assert_equal(bool(secured_duel.get("lethal", true)), false, "a default duel is non-lethal (arena maps this to the KO clamp)")
	var lawless_open := PvpConsent.resolve(A, B, {"zone_tier": "lawless", "duel_active": false, "bounty_eligible": false})
	_assert_equal(String(lawless_open.get("reason", "")), "lawless_open", "lawless with no consent still fires (DIV-0019 preserved)")
	_assert_equal(bool(lawless_open.get("lethal", false)), true, "lawless open PvP is lethal")

	if _rules.has_method("free"):
		_rules.free()
	if _failures.is_empty():
		print("pvp_consent_wire_smoke: OK")
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
