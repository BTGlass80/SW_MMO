extends SceneTree
## Flow guard for the Wave F hostile-PvE death loop (S11-S13). network_manager is a Node autoload not
## headlessly instantiable, so — like heal_flow_smoke / economy_flow_smoke — this mirrors the server
## COMPOSITION around the pure models: the lethal death TRIGGER (lethal envelope + shooter taken out),
## _handle_player_death's record mutation (apply_death -> wounded respawn, durability loss, corpse
## manifest, credits KEPT, respawn zone), the creature LOOT hook, and submit_buy_insurance's credit
## debit. death_penalty_model_smoke / economy_model_smoke cover the pure math; this locks the wiring
## (DIV-0006 / DIV-0017 / DIV-0018).

const DeathPenalty := preload("res://scripts/rules/death_penalty_model.gd")
const EconomyModel := preload("res://scripts/rules/economy_model.gd")

const DISABLED_SEVERITY := 3  # mirrors CombatArena.DISABLED_SEVERITY
const RESPAWN_ZONE := "tatooine.mos_eisley.spaceport"

var _failures: Array[String] = []

# mirror of _resolve_combat_window's per-envelope death trigger
func _death_triggers(envelope: Dictionary, wound_severity: int) -> bool:
	return bool(envelope.get("lethal", false)) and wound_severity >= DISABLED_SEVERITY

# mirror of _handle_player_death's record-side effects (no arena/state/RPC)
func _kill(record: Dictionary, tier: String, corpse_pos: Dictionary) -> Dictionary:
	var outcome: Dictionary = DeathPenalty.apply_death(record["sheet"], tier)
	var dropped: Array = outcome["dropped"]
	var wh: Dictionary = record.get("world_hooks", {})
	if not dropped.is_empty():
		wh["corpse"] = {"zone_id": tier, "pos": corpse_pos, "items": dropped, "decay_unix": 0.0}
	else:
		wh["corpse"] = null
	record["world_hooks"] = wh
	record["sheet"] = outcome["sheet"]
	record["zone"] = RESPAWN_ZONE  # respawn at the secured spaceport
	return outcome

# mirror of submit_buy_insurance's credit debit + grant
func _buy_insurance(record: Dictionary) -> Dictionary:
	var sheet: Dictionary = record["sheet"]
	if int(sheet.get("credits", 0)) < DeathPenalty.INSURANCE_PREMIUM:
		return {"ok": false, "reason": "cannot_afford"}
	sheet["credits"] = int(sheet["credits"]) - DeathPenalty.INSURANCE_PREMIUM
	var granted: Dictionary = DeathPenalty.buy_insurance(sheet, true)
	record["sheet"] = granted["sheet"]
	return {"ok": true, "charges": int((granted["sheet"].get("insurance", {}) as Dictionary).get("charges", 0))}

func _new_record(credits: int) -> Dictionary:
	return {"sheet": {
		"credits": credits, "wound_state": "healthy",
		"equipment": {"weapon": "blaster_pistol", "armor": "blast_vest"},
		"inventory": ["blaster_pistol", "blast_vest", "hold_out_blaster", "blast_helmet"],
		"item_durability": {},
	}, "world_hooks": {}}

func _init() -> void:
	# --- death TRIGGER: lethal + out(>=3) fires; anything else does not ---
	_assert_equal(_death_triggers({"lethal": true}, 3), true, "lethal takedown to incapacitated fires death")
	_assert_equal(_death_triggers({"lethal": true}, 5), true, "lethal killing blow fires death")
	_assert_equal(_death_triggers({"lethal": true}, 2), false, "lethal but only Wounded(2) does NOT fire death")
	_assert_equal(_death_triggers({"lethal": false}, 5), false, "a NON-lethal (sparring) hit never fires death, even at high severity")

	# --- uninsured lawless death: wounded respawn, 10% durability, partial drop, credits KEPT, corpse ---
	var rec := _new_record(1000)
	var out := _kill(rec, "lawless", {"x": 1.0, "y": 1.2, "z": 2.0})
	var sheet: Dictionary = rec["sheet"]
	_assert_equal(String(sheet["wound_state"]), "wounded", "respawn wound_state = wounded (sev 2)")
	_assert_equal(int(sheet["credits"]), 1000, "credits are KEPT on death")
	_assert_equal(int((sheet["item_durability"] as Dictionary).get("weapon", -1)), 90, "equipped weapon loses 10% durability")
	_assert_equal(int((sheet["item_durability"] as Dictionary).get("armor", -1)), 90, "equipped armor loses 10% durability")
	_assert_equal((out["dropped"] as Array), ["blast_helmet"], "half of the 2 unequipped items drop (sorted -> blast_helmet)")
	_assert_true(typeof(rec["world_hooks"]["corpse"]) == TYPE_DICTIONARY, "a corpse manifest is written when items drop")
	_assert_equal((((rec["world_hooks"]["corpse"] as Dictionary)["items"]) as Array), ["blast_helmet"], "corpse carries the dropped item")
	_assert_equal(String(rec["zone"]), RESPAWN_ZONE, "respawn relocates to the secured spaceport zone")
	_assert_true(not (sheet["inventory"] as Array).has("blast_helmet"), "the dropped item is removed from inventory")

	# --- insured lawless death: no drops, 3% durability, one charge consumed ---
	var irec := _new_record(1000)
	var ins := _buy_insurance(irec)  # 1000 -> 500, +3 charges
	_assert_true(bool(ins["ok"]) and int(ins["charges"]) == 3, "insurance grants 3 charges")
	_assert_equal(int((irec["sheet"] as Dictionary)["credits"]), 500, "insurance premium debits 500")
	var iout := _kill(irec, "lawless", {"x": 0.0, "y": 0.0, "z": 0.0})
	_assert_equal(bool(iout["insured"]), true, "the death is insured")
	_assert_equal((iout["dropped"] as Array).size(), 0, "an insured death drops NOTHING")
	_assert_equal(int(((irec["sheet"] as Dictionary)["item_durability"] as Dictionary).get("weapon", -1)), 97, "insured durability loss is only 3%")
	_assert_equal(int(((irec["sheet"] as Dictionary)["insurance"] as Dictionary).get("charges", -1)), 2, "one insurance charge is consumed")
	_assert_true(typeof(irec["world_hooks"]["corpse"]) == TYPE_NIL, "no corpse when nothing dropped")

	# --- secured death: penalty-free safety net ---
	var srec := _new_record(1000)
	var sout := _kill(srec, "secured", {"x": 0.0, "y": 0.0, "z": 0.0})
	_assert_equal(int(sout["durability_delta"]), 0, "a secured death costs no durability")
	_assert_equal((sout["dropped"] as Array).size(), 0, "a secured death drops nothing")
	_assert_equal(String((srec["sheet"] as Dictionary)["wound_state"]), "wounded", "secured death still respawns wounded")

	# --- loot: a disabled HOSTILE creature drops credits; a non-hostile drops nothing ---
	var hostile_spawn := {"hostile": true, "scale": "creature", "pack_size": 3}
	var loot := EconomyModel.roll_loot(hostile_spawn, 4242)
	_assert_true(int(loot["credits"]) > 0, "a hostile creature yields loot credits (scaled by pack size)")
	var calm_spawn := {"hostile": false, "scale": "creature", "pack_size": 1}
	_assert_equal(int(EconomyModel.roll_loot(calm_spawn, 4242)["credits"]), 0, "a non-hostile creature yields NO loot")

	# --- insurance affordability ---
	var poor := _new_record(100)
	_assert_equal(String(_buy_insurance(poor)["reason"]), "cannot_afford", "insurance rejected when under the premium")

	if _failures.is_empty():
		print("death_flow_smoke: OK")
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
