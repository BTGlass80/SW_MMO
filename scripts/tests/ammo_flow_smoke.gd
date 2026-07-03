extends SceneTree
## Flow guard for the LIVE ammo-sink wiring (DIV-0029). network_manager is a Node autoload not headlessly
## instantiable, so — like harvest_wire_smoke / creature_status_wire_smoke — this drives the REAL CombatArena
## (RefCounted) to produce REAL resolved envelopes (target_key / pvp shapes), then MIRRORS the net-layer
## composition around the pure AmmoModel:
##   * _envelope_consumes_ammo(env)   — a real shot (hostile / PvP) spends a shot; the training dummy is free
##   * _consume_ammo_for_shot(sheet)  — decrement the equipped weapon; auto-reload from a pack when empty
##   * _peer_can_fire(sheet)          — the SUBMIT gate that rejects out_of_ammo
## ammo_model_smoke covers the pure decrement/reload/migration math; THIS locks the seam decisions:
##   (A) firing a live hostile with ammo DECREMENTS the equipped magazine;
##   (B) the free-sparring dummy shot does NOT decrement;
##   (C) empty + a pack AUTO-RELOADS (spends the pack) so the shot still lands;
##   (D) empty + no pack is REJECTED by the submit gate (out_of_ammo);
##   (E) a legacy sheet (no ammo block) migrates on first fire (full shots + STARTING_PACKS);
##   (F) a MELEE weapon at a real target never decrements/gates (single_use excluded likewise).
## Deterministic: the arena's server-owned seeds are fixed; no sockets, no user:// writes, no randomize().

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const AmmoModel := preload("res://scripts/rules/ammo_model.gd")
const WEAPONS_PATH := "res://data/weapons_clone_wars.json"

var _failures: Array[String] = []
var _rules: Object
var _weapons: Dictionary = {}

# --- mirrors of the network_manager server helpers under test (kept byte-faithful to the HOT seam) ---

# mirror of network_manager._envelope_consumes_ammo
func _envelope_consumes_ammo(env: Dictionary) -> bool:
	if bool(env.get("unprovoked", false)):
		return false
	if bool(env.get("pvp", false)):
		return true
	return String(env.get("target_key", "")) != ""

# mirror of network_manager._consume_ammo_for_shot (sheet-level; no store / telemetry / RPC).
# Returns {changed, reloaded, shots_left, packs_left}; changed=false for a non-ammo weapon (no-op).
func _consume_ammo_for_shot(sheet: Dictionary) -> Dictionary:
	var weapon_key := String((sheet.get("equipment", {}) as Dictionary).get("weapon", ""))
	var wdict: Dictionary = _weapons.get(weapon_key, {})
	if not AmmoModel.uses_ammo(wdict):
		return {"changed": false, "reloaded": false}
	var ammo: Dictionary = sheet.get("ammo", {})
	var r := AmmoModel.consume(ammo, weapon_key, wdict)
	sheet["ammo"] = ammo
	return {"changed": true, "reloaded": bool(r.get("reloaded", false)), "shots_left": int(r.get("shots_left", 0)), "packs_left": int(r.get("packs_left", 0))}

# mirror of network_manager._peer_can_fire_ammo (the submit gate)
func _peer_can_fire(sheet: Dictionary) -> bool:
	var weapon_key := String((sheet.get("equipment", {}) as Dictionary).get("weapon", ""))
	var wdict: Dictionary = _weapons.get(weapon_key, {})
	return AmmoModel.can_fire(sheet.get("ammo", {}), weapon_key, wdict)

func _sheet(weapon_key: String, ammo: Dictionary) -> Dictionary:
	return {
		"attributes": {"dexterity": "4D", "strength": "3D", "perception": "3D"},
		"skills": {"blaster": "2D", "melee_combat": "2D"},
		"equipment": {"weapon": weapon_key, "armor": ""},
		"ammo": ammo,
	}

func _hostile_pools(str_code: String) -> Dictionary:
	return {
		"target_attack_pool": _rules.parse_pool("2D"),
		"target_damage_pool": _rules.parse_pool("3D"),
		"target_soak_pool": _rules.parse_pool(str_code),
		"target_armor": {}, "target_scale": "character", "target_stun_mode": false,
	}

# Resolve ONE window in a fresh arena where `peer` (with `sheet` pools) fires at either a live hostile
# ("crab") or the shared training dummy. Returns the shooter's resolved envelope ({} if none).
func _fire_once(sheet: Dictionary, at_hostile: bool) -> Dictionary:
	var arena := CombatArena.new(_rules, _combat_data(), "b1_training_silhouette", _weapons, {})
	arena.register_player(1, "Spacer", sheet)
	if at_hostile:
		arena.register_hostile_target("crab", _hostile_pools("2D"), {"distance": 8.0, "cover_level": 0, "name": "Hitcher Crab"})
		arena.set_player_target(1, "crab")
	arena.submit_fire_intent(1, {})
	var result: Dictionary = arena.resolve_window(4242)
	for env in result.get("envelopes", []):
		if int((env as Dictionary).get("shooter_id", 0)) == 1:
			return env
	return {}

func _init() -> void:
	_rules = load("res://scripts/rules/d6_rules.gd").new()
	_weapons = _load_json(WEAPONS_PATH).get("weapons", {})
	_assert_true(not _weapons.is_empty(), "weapons catalog loads")
	_assert_true(AmmoModel.uses_ammo(_weapons.get("blaster_pistol", {})), "blaster_pistol is ammo-tracked (test premise)")

	# =========================================================================================
	# (A) firing a LIVE HOSTILE with ammo -> the envelope is a real shot -> the magazine decrements.
	# =========================================================================================
	var hostile_sheet := _sheet("blaster_pistol", {"blaster_pistol": 100, "packs": 2})
	var hostile_env := _fire_once(hostile_sheet, true)
	_assert_true(not hostile_env.is_empty(), "a fire intent at a live hostile resolves an envelope")
	_assert_equal(String(hostile_env.get("target_key", "")), "crab", "the hostile shot's envelope names the creature target")
	_assert_true(_envelope_consumes_ammo(hostile_env), "a hostile shot is a REAL shot that consumes ammo")
	var ra := _consume_ammo_for_shot(hostile_sheet)
	_assert_true(bool(ra["changed"]), "the equipped blaster consumed ammo on the resolved hostile shot")
	_assert_equal(int((hostile_sheet["ammo"] as Dictionary)["blaster_pistol"]), 99, "the hostile shot decremented the magazine 100 -> 99")
	_assert_equal(int((hostile_sheet["ammo"] as Dictionary)["packs"]), 2, "a normal shot did not touch the packs")

	# =========================================================================================
	# (B) the FREE-SPARRING training-dummy shot does NOT decrement (target_key=="" and not pvp).
	# =========================================================================================
	var dummy_sheet := _sheet("blaster_pistol", {"blaster_pistol": 100, "packs": 2})
	var dummy_env := _fire_once(dummy_sheet, false)
	_assert_true(not dummy_env.is_empty(), "a fire intent at the dummy resolves an envelope")
	_assert_equal(String(dummy_env.get("target_key", "")), "", "the dummy shot's envelope has an empty target_key")
	_assert_true(not _envelope_consumes_ammo(dummy_env), "a training-dummy shot is FREE sparring (no ammo consumed)")
	# The seam skips _consume_ammo_for_shot for a free shot, so the magazine is untouched.
	_assert_equal(int((dummy_sheet["ammo"] as Dictionary)["blaster_pistol"]), 100, "the free dummy shot left the magazine at 100")

	# =========================================================================================
	# (C) empty magazine + a carried pack AUTO-RELOADS on the resolved shot (spends the pack, refills).
	# =========================================================================================
	var reload_sheet := _sheet("blaster_pistol", {"blaster_pistol": 0, "packs": 1})
	_assert_true(_peer_can_fire(reload_sheet), "empty + a pack passes the submit gate (it will reload)")
	var rc := _consume_ammo_for_shot(reload_sheet)
	_assert_true(bool(rc["reloaded"]), "the resolved shot auto-reloaded from a pack")
	_assert_equal(int(rc["packs_left"]), 0, "the auto-reload spent exactly one pack")
	_assert_equal(int((reload_sheet["ammo"] as Dictionary)["blaster_pistol"]), 99, "reloaded magazine (100) less the fired shot -> 99")

	# =========================================================================================
	# (D) empty magazine + NO pack is REJECTED by the submit gate (out_of_ammo).
	# =========================================================================================
	var dry_sheet := _sheet("blaster_pistol", {"blaster_pistol": 0, "packs": 0})
	_assert_true(not _peer_can_fire(dry_sheet), "empty + no pack is refused at submit (out_of_ammo)")

	# =========================================================================================
	# (E) a LEGACY sheet (no ammo block) migrates on first fire: full shots less one + STARTING_PACKS.
	# =========================================================================================
	var legacy_sheet := _sheet("blaster_pistol", {})
	_assert_true(_peer_can_fire(legacy_sheet), "a legacy sheet reads as a full magazine -> passes the submit gate")
	var re := _consume_ammo_for_shot(legacy_sheet)
	_assert_true(bool(re["changed"]) and not bool(re["reloaded"]), "the veteran's first fire is a fresh-magazine shot, not a reload")
	_assert_equal(int((legacy_sheet["ammo"] as Dictionary)["blaster_pistol"]), 99, "first fire inits to full then spends one (100 -> 99)")
	_assert_equal(int((legacy_sheet["ammo"] as Dictionary)["packs"]), AmmoModel.STARTING_PACKS, "first fire grants STARTING_PACKS (no stranded veteran)")

	# =========================================================================================
	# (F) a MELEE weapon at a REAL target never decrements or gates (single_use excluded the same way).
	# =========================================================================================
	var melee_sheet := _sheet("vibroblade", {"packs": 0})
	var melee_env := _fire_once(melee_sheet, true)
	_assert_true(not melee_env.is_empty(), "a melee fire intent at a hostile resolves an envelope")
	_assert_true(_envelope_consumes_ammo(melee_env), "the melee envelope IS a real-target shot by shape")
	_assert_true(_peer_can_fire(melee_sheet), "a melee weapon always passes the submit gate (no ammo)")
	var rf := _consume_ammo_for_shot(melee_sheet)
	_assert_true(not bool(rf["changed"]), "a melee weapon consumes NO ammo even at a real target")
	_assert_true(not (melee_sheet["ammo"] as Dictionary).has("vibroblade"), "a melee shot writes no ammo entry")

	if _rules.has_method("free"):
		_rules.free()
	if _failures.is_empty():
		print("ammo_flow_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _combat_data() -> Dictionary:
	return {
		"range_trainee": {
			"blaster": "4D+1", "dodge": "4D", "soak": "3D",
			"weapon": "blaster_pistol", "armor": "", "scale": "character",
		},
		"weapons": {},
		"armors": {},
		"targets": {"b1_training_silhouette": {
			"blaster": "3D", "weapon": "", "soak": "2D",
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
