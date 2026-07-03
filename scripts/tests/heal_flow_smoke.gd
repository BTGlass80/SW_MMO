extends SceneTree
## Regression guard for the server's submit_heal COMPOSITION PRECEDENCE (DIV-0013 / F8).
## network_manager is a Node autoload that is not headlessly instantiable, so — like
## claim_flow_smoke / auth_flow_smoke — this replicates its First-Aid validation chain with
## the REAL recovery_model and locks the ordering + the retry gate:
##   self -> no_target -> out_of_range -> no_wound -> beyond_help -> already_treated -> heal.
##   The retry gate (per-target `heal_treated`) blocks re-treating the SAME wound level until
##   it changes (no spam-to-success after a failed roll). recovery_model_smoke covers
##   heal_check itself; this covers the network_manager COMPOSITION around it.

const Recovery := preload("res://scripts/rules/recovery_model.gd")

var _failures: Array[String] = []
var _rng := RandomNumberGenerator.new()

# Faithful mirror of submit_heal's server-side precedence. `st` carries
# peer_characters / peer_zones / records / heal_treated; mutates them exactly as the RPC
# does (heal_treated set before the roll; the target record's wound drops on success).
func _heal(st: Dictionary, healer: int, target: int, heal_pool: Dictionary) -> Dictionary:
	if String(st["peer_characters"].get(healer, "")) == "":
		return {"ok": false, "reason": "unregistered"}
	if target == healer:
		return {"ok": false, "reason": "self"}
	var target_char := String(st["peer_characters"].get(target, ""))
	if target_char == "":
		return {"ok": false, "reason": "no_target"}
	if String(st["peer_zones"].get(healer, "")) != String(st["peer_zones"].get(target, "")):
		return {"ok": false, "reason": "out_of_range"}
	var t_record: Dictionary = st["records"].get(target_char, {})
	if t_record.is_empty():
		return {"ok": false, "reason": "no_target"}
	var level := String((t_record.get("sheet", {}) as Dictionary).get("wound_state", "healthy"))
	if level == "healthy":
		return {"ok": false, "reason": "no_wound"}
	if level == "dead":
		return {"ok": false, "reason": "beyond_help"}
	if String(st["heal_treated"].get(target, "")) == level:
		return {"ok": false, "reason": "already_treated"}
	st["heal_treated"][target] = level
	var result: Dictionary = Recovery.heal_check(_rng, heal_pool, level)
	var healed := bool(result.get("healed", false))
	var new_level := String(result.get("new_level", level))
	if healed:
		(t_record["sheet"] as Dictionary)["wound_state"] = new_level
		if new_level == "healthy":
			st["heal_treated"].erase(target)  # fully healed -> reset the gate (F28)
	return {"ok": healed, "reason": "" if healed else "failed", "to": new_level}

# Test affordance: simulate the target taking a fresh wound (combat damage / re-injury).
func _rewound(st: Dictionary, target_char: String, wound: String) -> void:
	(st["records"][target_char] as Dictionary)["sheet"] = {"wound_state": wound}

# Test affordance: the target is DOWNED again by fresh combat damage (sev >= 3). Mirrors
# _handle_player_downed CLEARING the First-Aid retry gate (DIV-0027 verify: revive-persist): a fresh
# down is new damage, so a medic must be able to re-treat even at a level they treated earlier this
# session (e.g. revived incap->wounded_twice, then knocked back to incap).
func _redown(st: Dictionary, target_peer: int, target_char: String, wound: String) -> void:
	(st["records"][target_char] as Dictionary)["sheet"] = {"wound_state": wound}
	st["heal_treated"].erase(target_peer)  # the down resets the gate

func _fresh() -> Dictionary:
	return {"peer_characters": {}, "peer_zones": {}, "records": {}, "heal_treated": {}}

func _register(st: Dictionary, peer: int, char_id: String, zone: String, wound: String) -> void:
	st["peer_characters"][peer] = char_id
	st["peer_zones"][peer] = zone
	st["records"][char_id] = {"sheet": {"wound_state": wound}}

func _init() -> void:
	_rng.seed = 1138
	var BIG := {"dice": 20, "pips": 0}   # roll >= 20: clears every field difficulty up to incap(16)
	var NONE := {"dice": 0, "pips": 0}   # roll 0: fails every difficulty (>= stunned 8)

	# --- precedence (none of these reach the roll / the heal_treated set) ---
	var st: Dictionary = _fresh()
	_register(st, 10, "medic", "spaceport", "healthy")   # the healer is itself healthy
	_register(st, 11, "ally", "spaceport", "wounded")
	_register(st, 12, "well", "spaceport", "healthy")
	_register(st, 13, "corpse", "spaceport", "dead")

	_assert_eq(_heal(st, 10, 10, BIG)["reason"], "self", "self-target -> self (before any wound check)")
	_assert_eq(_heal(st, 10, 99, BIG)["reason"], "no_target", "unregistered target -> no_target")
	_register(st, 11, "ally", "dune_sea", "wounded")     # move the ally out of zone
	_assert_eq(_heal(st, 10, 11, BIG)["reason"], "out_of_range", "different zone -> out_of_range (before wound check)")
	_register(st, 11, "ally", "spaceport", "wounded")    # back in range
	_assert_eq(_heal(st, 10, 12, BIG)["reason"], "no_wound", "healthy target -> no_wound")
	_assert_eq(_heal(st, 10, 13, BIG)["reason"], "beyond_help", "dead target -> beyond_help")
	# precedence: no_wound wins over a pre-set retry gate (the gate is checked AFTER the wound tier)
	st["heal_treated"][12] = "healthy"
	_assert_eq(_heal(st, 10, 12, BIG)["reason"], "no_wound", "no_wound precedes the retry gate")

	# --- success walks the ladder down as the level changes ---
	var st2: Dictionary = _fresh()
	_register(st2, 20, "medic2", "spaceport", "healthy")
	_register(st2, 21, "ally2", "spaceport", "wounded")
	var h1: Dictionary = _heal(st2, 20, 21, BIG)
	_assert_true(bool(h1["ok"]), "big pool heals a wounded ally")
	_assert_eq(String(h1["to"]), "stunned", "wounded -> stunned (one step)")
	var h2: Dictionary = _heal(st2, 20, 21, BIG)  # level changed (stunned) -> gate allows
	_assert_true(bool(h2["ok"]), "can re-heal once the level has changed")
	_assert_eq(String(h2["to"]), "healthy", "stunned -> healthy")
	_assert_eq(_heal(st2, 20, 21, BIG)["reason"], "no_wound", "fully healed -> no_wound")

	# --- a failed roll trips the retry gate until the wound changes ---
	var st3: Dictionary = _fresh()
	_register(st3, 30, "medic3", "spaceport", "healthy")
	_register(st3, 31, "ally3", "spaceport", "wounded")
	var f1: Dictionary = _heal(st3, 30, 31, NONE)
	_assert_eq(String(f1["reason"]), "failed", "zero pool fails the heal roll")
	_assert_eq(_heal(st3, 30, 31, NONE)["reason"], "already_treated", "retry at the same wound level is gated (no spam-to-success)")

	# --- F28: the gate RESETS when the wound fully heals, so a re-wound to a previously-treated
	#     level is heal-able again (without the reset, _heal_treated would stale-block it). ---
	var st4: Dictionary = _fresh()
	_register(st4, 40, "medic4", "spaceport", "healthy")
	_register(st4, 41, "ally4", "spaceport", "stunned")
	_assert_true(bool(_heal(st4, 40, 41, BIG)["ok"]), "heal stunned -> healthy (gate had recorded 'stunned')")
	_assert_eq(_heal(st4, 40, 41, BIG)["reason"], "no_wound", "now healthy -> no_wound")
	_rewound(st4, "ally4", "stunned")  # the ally is stunned AGAIN later
	var reheal: Dictionary = _heal(st4, 40, 41, BIG)
	_assert_true(bool(reheal["ok"]), "a re-wound to the same level is heal-able (gate was reset on full heal)")
	_assert_eq(String(reheal["to"]), "healthy", "the re-wound stun heals normally")

	# --- DIV-0027 (verify: revive-persist): the PARTIAL-revive-then-re-DOWN case the downed tier exists
	#     for. A medic revives a downed ally one step (incap->wounded_twice) — the gate stays at the
	#     pre-heal level ('incapacitated'), NOT reset (the ally is not fully healthy). Fresh combat then
	#     knocks the ally back to incapacitated. Without _handle_player_downed clearing the gate, the medic
	#     is refused ('already_treated') and the revive path — the ONLY non-lethal escape from downed — is
	#     dead; the re-down MUST reset the gate. ---
	var st5: Dictionary = _fresh()
	_register(st5, 50, "medic5", "spaceport", "healthy")
	_register(st5, 51, "ally5", "spaceport", "incapacitated")   # downed (sev 3)
	var d1: Dictionary = _heal(st5, 50, 51, BIG)                # partial revive, one step up the ladder
	_assert_true(bool(d1["ok"]), "a downed (incap) ally is First-Aidable")
	_assert_true(String(d1["to"]) != "healthy", "the revive is PARTIAL (not straight to healthy), so the gate is NOT auto-reset")
	_assert_eq(String(st5["heal_treated"].get(51, "")), "incapacitated", "the retry gate is left at the pre-heal 'incapacitated' level")
	# fresh combat re-DOWNS the ally to the very level it was treated at
	_redown(st5, 51, "ally5", "incapacitated")
	var d2: Dictionary = _heal(st5, 50, 51, BIG)
	_assert_true(d2.get("reason", "") != "already_treated", "a re-downed ally is NOT stale-blocked from First Aid (the down reset the gate)")
	_assert_true(bool(d2["ok"]), "the medic can revive the re-downed ally again (revive path preserved)")

	if _failures.is_empty():
		print("heal_flow_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
