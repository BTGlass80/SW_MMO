extends SceneTree
## Smoke for the pure PvP-CONSENT model (Wave F / DIV-0022). Asserts the §1.2 precedence + the entire
## §10 truth table plus the duel/bounty state lifecycle: a challenge accepted -> mutual consent permits a
## duel in a PROTECTED zone; decline/expire/abort revoke it; bounty-as-consent grants lethal attackability
## in contested (not secured); lawless open-PvP is UNAFFECTED (permitted without consent); a non-consenting
## bystander in a protected zone is still safe. Deterministic; the only "RNG" here is a seeded generator we
## never actually draw from (the model has none) — seeded per convention.

const Consent := preload("res://scripts/rules/pvp_consent_model.gd")

var _failures: Array[String] = []
var _rng := RandomNumberGenerator.new()

# Player fixtures (server-shaped inputs).
func _p(id: int, node: String, newbie := false) -> Dictionary:
	return {"id": id, "is_player": true, "node_id": node, "newbie_protected": newbie}

func _init() -> void:
	_rng.seed = 0xC0FFEE   # seeded per project convention; model is RNG-free

	var Z := "tatooine.mos_eisley.cantina"   # a shared node
	var A := _p(12, Z)
	var B := _p(34, Z)

	# ---------------------------------------------------------------------------------------------
	# 1. HARD DENIES / wrong caller (rules 1-3)
	# ---------------------------------------------------------------------------------------------
	_expect(Consent.resolve(A, {"id": 99, "is_player": false, "node_id": Z}, {"zone_tier": "lawless"}),
		false, "pve_target", false, "a non-player target routes to the PvE gate, not here")
	_expect(Consent.resolve(A, A, {"zone_tier": "lawless"}),
		false, "self", false, "no self-fire even in lawless")
	_expect(Consent.resolve(A, _p(34, "other.zone"), {"zone_tier": "lawless"}),
		false, "not_colocated", false, "a target in a different node is not attackable")

	# ---------------------------------------------------------------------------------------------
	# 2. CONSENT TRUTH TABLE (§10) via raw ctx — zone x duel x bounty, no newbie
	# ---------------------------------------------------------------------------------------------
	# secured: only an active duel opens PvP (non-lethal); bounty never reaches secured.
	_expect(_r("secured", false, false, false), false, "protected_zone", false, "secured, no consent -> safe")
	_expect(_r("secured", false, true,  false), false, "protected_zone", false, "secured excludes bounty (never eligible there)")
	_expect(_r("secured", true,  false, false), true,  "duel", false, "secured duel allowed, non-lethal")
	_expect(_r("secured", true,  true,  false), true,  "duel", false, "duel outranks bounty in secured")
	# contested: bounty is the only non-duel opener; open PvP still denied.
	_expect(_r("contested", false, false, false), false, "protected_zone", false, "contested, no consent -> safe")
	_expect(_r("contested", false, true,  false), true,  "bounty", true, "contested bounty -> lethal attackable")
	_expect(_r("contested", true,  false, false), true,  "duel", false, "contested duel -> non-lethal")
	_expect(_r("contested", true,  true,  false), true,  "duel", false, "duel outranks bounty in contested")
	# lawless: open PvP by default; bounty is tagged ABOVE lawless_open for collection; duel still wins.
	_expect(_r("lawless", false, false, false), true, "lawless_open", true, "lawless open PvP without any consent")
	_expect(_r("lawless", false, true,  false), true, "bounty", true, "lawless bounty tagged for collection")
	_expect(_r("lawless", true,  false, false), true, "duel", false, "friendly duel in a lawless zone stays non-lethal")
	_expect(_r("lawless", true,  true,  false), true, "duel", false, "duel outranks bounty + zone")

	# ---------------------------------------------------------------------------------------------
	# 3. Duel-lethal opt-in flips the lethal column
	# ---------------------------------------------------------------------------------------------
	_expect(Consent.resolve(A, B, {"zone_tier": "secured", "duel_active": true, "duel_lethal": true}),
		true, "duel", true, "a lethal-opt-in duel is lethal even in secured")

	# ---------------------------------------------------------------------------------------------
	# 4. Newbie-protection overlay (rule 6): flips every row to deny EXCEPT active-duel rows
	# ---------------------------------------------------------------------------------------------
	var An := _p(12, Z, true)   # protected attacker
	var Bn := _p(34, Z, true)   # protected target
	# lawless: protection blocks open PvP + bounty (symmetric — neither ganks nor is ganked)
	_expect(Consent.resolve(An, B, {"zone_tier": "lawless"}), false, "newbie_protected", false, "protected attacker can't lawless-gank")
	_expect(Consent.resolve(A, Bn, {"zone_tier": "lawless"}), false, "newbie_protected", false, "protected target safe in lawless")
	_expect(Consent.resolve(A, Bn, {"zone_tier": "contested", "bounty_eligible": true}), false, "newbie_protected", false, "protected target can't be bounty-hunted")
	# ...but a duel the newbie CHOSE still stands (rule 5 above rule 6)
	_expect(Consent.resolve(An, Bn, {"zone_tier": "secured", "duel_active": true}), true, "duel", false, "a protected player may still opt into a friendly duel")
	# siege hook still outranks even newbie (rule 4)
	_expect(Consent.resolve(An, Bn, {"zone_tier": "secured", "siege_forced": true}), true, "siege", true, "siege forces PvP above every guard")

	# ---------------------------------------------------------------------------------------------
	# 5. DUEL LIFECYCLE through the real state + may_fire() (challenge -> accept -> revoke)
	# ---------------------------------------------------------------------------------------------
	var st := Consent.new_state()
	var C := _p(56, Z)   # a non-consenting bystander, same protected zone

	# baseline: in a secured zone, with NO consent, everyone is safe (incl. the bystander)
	_expect(Consent.may_fire(st, A, B, "secured"), false, "protected_zone", false, "secured baseline: A cannot fire B")
	_expect(Consent.may_fire(st, A, C, "secured"), false, "protected_zone", false, "secured baseline: bystander C safe")

	# challenge A->B, then accept: an ACTIVE mutual duel is created
	var ch := Consent.challenge(st, 12, 34, Z, 100.0)
	_assert(bool(ch["ok"]), "challenge A->B accepted into OFFERED")
	st = ch["state"]
	_assert(not Consent.duel_active(st, 12, 34), "an OFFERED (unaccepted) duel does NOT yet grant attackability")
	_expect(Consent.may_fire(st, A, B, "secured"), false, "protected_zone", false, "an unaccepted challenge does not open PvP")
	var ac := Consent.accept(st, 12, 34, 105.0)
	_assert(bool(ac["ok"]), "accept flips OFFERED -> ACTIVE")
	st = ac["state"]
	_assert(Consent.duel_active(st, 12, 34), "accepted duel is active")

	# mutual consent now permits the duel in the PROTECTED (secured) zone, non-lethal...
	_expect(Consent.may_fire(st, A, B, "secured"), true, "duel", false, "accepted duel permits PvP in a protected zone")
	_expect(Consent.may_fire(st, B, A, "secured"), true, "duel", false, "duel is symmetric (B may fire A too)")
	# ...but the non-consenting bystander C is STILL safe (duel binds only the A<->B pair)
	_expect(Consent.may_fire(st, A, C, "secured"), false, "protected_zone", false, "bystander C is still safe during the A<->B duel")
	_expect(Consent.may_fire(st, C, A, "secured"), false, "protected_zone", false, "C cannot fire a duelist in a protected zone")

	# one active duel per player: A can't be challenged into a second while dueling B
	_assert(not bool(Consent.challenge(st, 12, 56, Z, 106.0)["ok"]), "one-active-duel invariant blocks a second duel for A")

	# --- REVOKE via abort (a duelist leaves the zone / disconnects) ---
	var ab := Consent.abort(st, 12)
	_assert(bool(ab["ok"]), "abort ends A's active duel")
	var st_ab: Dictionary = ab["state"]
	_assert(not Consent.duel_active(st_ab, 12, 34), "aborted duel no longer active")
	_expect(Consent.may_fire(st_ab, A, B, "secured"), false, "protected_zone", false, "after abort the pair is protected again")

	# --- REVOKE via decline (before accept) ---
	var st2 := Consent.new_state()
	st2 = Consent.challenge(st2, 12, 34, Z, 200.0)["state"]
	st2 = Consent.decline(st2, 12, 34)["state"]
	var ac2 := Consent.accept(st2, 12, 34, 205.0)
	_assert(not bool(ac2["ok"]), "a declined offer cannot be accepted")
	_expect(Consent.may_fire(st2, A, B, "secured"), false, "protected_zone", false, "declined challenge grants no PvP")

	# --- REVOKE via expire (offer TTL elapses) ---
	var st3 := Consent.new_state()
	st3 = Consent.challenge(st3, 12, 34, Z, 300.0)["state"]
	var ex := Consent.expire(st3, 300.0 + Consent.OFFER_TTL + 1.0)
	_assert(bool(ex["ok"]), "offer past its TTL is swept to ENDED")
	st3 = ex["state"]
	_assert(not bool(Consent.accept(st3, 12, 34, 400.0)["ok"]), "an expired offer cannot be accepted")

	# ---------------------------------------------------------------------------------------------
	# 6. BOUNTY-AS-CONSENT lifecycle through the real state + may_fire()
	# ---------------------------------------------------------------------------------------------
	var bst := Consent.new_state()
	# self-bounty + below-minimum are rejected (anti-abuse)
	_assert(not bool(Consent.place_bounty(bst, 34, 34, 1000, 0.0)["ok"]), "no self-bounty")
	_assert(not bool(Consent.place_bounty(bst, 12, 34, 10, 0.0)["ok"]), "below MIN_BOUNTY rejected")
	# placer 12 posts 1000cr on target 34
	var pb := Consent.place_bounty(bst, 12, 34, 1000, 0.0)
	_assert(bool(pb["ok"]), "valid bounty placed")
	_assert(int(pb["posting_fee"]) == 100, "posting fee = 10% of 1000 = 100")
	bst = pb["state"]
	_assert(Consent.bounty_pot(bst, 34) == 1000, "pot escrows the full 1000")

	# a THIRD-party hunter (56) is eligible in contested/lawless, NOT in secured
	_assert(Consent.bounty_eligible(bst, 56, 34, "contested"), "hunter eligible in contested")
	_assert(Consent.bounty_eligible(bst, 56, 34, "lawless"), "hunter eligible in lawless")
	_assert(not Consent.bounty_eligible(bst, 56, 34, "secured"), "bounty never reaches secured")
	# the PLACER cannot collect their own bounty (no self-collection funnel)
	_assert(not Consent.bounty_eligible(bst, 12, 34, "contested"), "placer is not an eligible collector")

	var hunter := _p(56, Z)
	var bountied := _p(34, Z)
	# bounty permits a LETHAL attack in contested for the hunter; a plain bystander stays protected
	_expect(Consent.may_fire(bst, hunter, bountied, "contested"), true, "bounty", true, "bounty grants a lethal hunt in contested")
	_expect(Consent.may_fire(bst, A, bountied, "secured"), false, "protected_zone", false, "the bountied target is still safe in secured")
	# collection on death: the hunter collects the pot; the placer cannot
	_assert(not bool(Consent.collect_bounty(bst, 34, 12)["ok"]), "the placer cannot collect")
	var col := Consent.collect_bounty(bst, 34, 56)
	_assert(bool(col["ok"]) and int(col["payout"]) == 1000, "hunter collects the 1000 pot on the kill")
	_assert(not Consent.has_bounty(col["state"], 34), "the bounty record is cleared after collection")

	# ---------------------------------------------------------------------------------------------
	# 7. LAWLESS open-PvP is UNAFFECTED by the consent layer (permitted with an empty state)
	# ---------------------------------------------------------------------------------------------
	var empty := Consent.new_state()
	_expect(Consent.may_fire(empty, A, B, "lawless"), true, "lawless_open", true, "lawless open PvP needs no consent record")
	# and a bystander in lawless is likewise open (zone rule, not a consent grant)
	_expect(Consent.may_fire(empty, A, C, "lawless"), true, "lawless_open", true, "lawless applies to everyone co-located")

	# ---------------------------------------------------------------------------------------------
	# result
	# ---------------------------------------------------------------------------------------------
	if _failures.is_empty():
		print("pvp_consent_model_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

# Build a raw ctx and resolve for the truth-table rows. `bounty` is the CALLER's intent to fund a hunt;
# the §10 note (*) is that a bounty is never ELIGIBLE in secured (secured is not in min_tiers), so the
# pre-resolver would yield false there — modeled here so _r reproduces the system-level §10 table.
func _r(tier: String, duel: bool, bounty: bool, newbie: bool) -> Dictionary:
	var a := {"id": 12, "is_player": true, "node_id": "z", "newbie_protected": newbie}
	var b := {"id": 34, "is_player": true, "node_id": "z", "newbie_protected": newbie}
	var eligible := bounty and tier != "secured"
	return Consent.resolve(a, b, {"zone_tier": tier, "duel_active": duel, "bounty_eligible": eligible})

func _expect(res: Dictionary, allowed: bool, reason: String, lethal: bool, label: String) -> void:
	if bool(res.get("allowed")) != allowed:
		_failures.append("%s: allowed expected %s, got %s" % [label, str(allowed), str(res.get("allowed"))])
	if String(res.get("reason")) != reason:
		_failures.append("%s: reason expected %s, got %s" % [label, reason, str(res.get("reason"))])
	if bool(res.get("lethal")) != lethal:
		_failures.append("%s: lethal expected %s, got %s" % [label, str(lethal), str(res.get("lethal"))])

func _assert(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)
