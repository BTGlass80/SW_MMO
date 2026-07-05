extends SceneTree
## Pure smoke for the WEG ammo / power-pack sink model (DIV-0029). No RNG in the model (nothing to
## seed), no nodes/sockets. Locks: shots_per_weapon reads `ammo` (0/absent = not tracked); uses_ammo
## excludes melee + single_use; consume decrements; empty+pack auto-reloads (spends a pack, refills);
## empty+no-pack rejects (can_fire false, consume ok=false); non-ammo weapons never gate/decrement;
## lazy migration (a sheet with no ammo block inits full shots + STARTING_PACKS on first fire);
## add_packs/remove_pack (the vendor path); initial_ammo (the chargen grace kit).

const AmmoModel := preload("res://scripts/rules/ammo_model.gd")
const WEAPONS_PATH := "res://data/weapons_clone_wars.json"

var _failures: Array[String] = []

func _init() -> void:
	var pistol := {"ammo": 100}          # blaster_pistol shape
	var heavy := {"ammo": 25}            # heavy_blaster_pistol shape
	var melee := {"damage": "STR+3D"}    # vibroblade: no `ammo`
	var grenade := {"ammo": 0, "single_use": true}  # frag/thermal shape
	var flash := {"ammo": 1}             # single-shot pistol (edge: universal pack still reloads it)

	# --- shots_per_weapon / uses_ammo classification ---
	_assert_equal(AmmoModel.shots_per_weapon(pistol), 100, "shots_per_weapon reads the WEG ammo field")
	_assert_equal(AmmoModel.shots_per_weapon(melee), 0, "a weapon with no ammo field is not ammo-tracked (0)")
	_assert_true(AmmoModel.uses_ammo(pistol), "a blaster pistol uses ammo")
	_assert_true(not AmmoModel.uses_ammo(melee), "a melee weapon does NOT use ammo (excluded)")
	_assert_true(not AmmoModel.uses_ammo(grenade), "a single_use grenade does NOT use ammo (stays latent)")
	_assert_true(AmmoModel.uses_ammo(flash), "a 1-shot ammo weapon still uses ammo")

	# --- initial_ammo (chargen grace) ---
	var fresh := {"inventory": AmmoModel.initial_packs(), "ammo": {"migrated_packs": true}}
	_assert_equal(AmmoModel.packs(fresh), AmmoModel.STARTING_PACKS, "initial_ammo grants STARTING_PACKS")
	_assert_true(not fresh.has("blaster_pistol"), "initial_ammo carries no per-weapon entry (lazy on first fire)")

	# --- consume from a full magazine decrements by one (no reload) ---
	var a := {"ammo": {"blaster_pistol": 100, "migrated_packs": true}, "inventory": [{"template_key": "blaster_power_pack", "quantity": 2}]}
	var r := AmmoModel.consume(a, "blaster_pistol", pistol)
	_assert_true(bool(r["ok"]), "a shot with ammo succeeds")
	_assert_equal(int(r["shots_left"]), 99, "a fired shot decrements the magazine by 1")
	_assert_true(not bool(r["reloaded"]), "a full magazine does not reload")
	_assert_equal(AmmoModel.packs(a), 2, "a normal shot does not touch the pack count")

	# --- empty magazine + a carried pack AUTO-RELOADS (spends a pack, refills to full, fires the shot) ---
	var b := {"ammo": {"blaster_pistol": 0, "migrated_packs": true}, "inventory": [{"template_key": "blaster_power_pack", "quantity": 1}]}
	_assert_true(AmmoModel.can_fire(b, "blaster_pistol", pistol), "empty magazine + a pack CAN fire (will reload)")
	var rb := AmmoModel.consume(b, "blaster_pistol", pistol)
	_assert_true(bool(rb["ok"]), "empty+pack consume succeeds")
	_assert_true(bool(rb["reloaded"]), "empty magazine auto-reloads from a pack")
	_assert_equal(int(rb["packs_left"]), 0, "auto-reload spends exactly one pack")
	_assert_equal(int(b.get("ammo", {})["blaster_pistol"]), 99, "reload refills to full (100) then the shot spends one -> 99")

	# --- empty magazine + NO pack REJECTS ---
	var c := {"ammo": {"blaster_pistol": 0, "migrated_packs": true}, "inventory": []}
	_assert_true(not AmmoModel.can_fire(c, "blaster_pistol", pistol), "empty + no pack CANNOT fire (out_of_ammo)")
	var rc := AmmoModel.consume(c, "blaster_pistol", pistol)
	_assert_true(not bool(rc["ok"]), "empty + no pack consume fails (defensive; the submit gate rejects first)")
	_assert_equal(int(c.get("ammo", {})["blaster_pistol"]), 0, "a failed consume does not go negative")

	# --- non-ammo weapon: never gates, never decrements ---
	var m := {"ammo": {"migrated_packs": true}, "inventory": []}
	_assert_true(AmmoModel.can_fire(m, "vibroblade", melee), "a melee weapon can always fire")
	var rm := AmmoModel.consume(m, "vibroblade", melee)
	_assert_true(bool(rm["ok"]), "a melee consume is a no-op success")
	_assert_true(not m.get("ammo", {}).has("vibroblade"), "a melee weapon never writes an ammo entry")
	_assert_true(AmmoModel.can_fire({}, "frag_grenade", grenade), "a single_use grenade can always fire (latent)")

	# --- LAZY MIGRATION: a sheet with no ammo block inits full shots + STARTING_PACKS on first fire ---
	var legacy := {}  # a veteran's sheet.ammo before this system
	_assert_true(AmmoModel.can_fire(legacy, "blaster_pistol", pistol), "a legacy (no-ammo) sheet reads as a full magazine -> can fire")
	var rl := AmmoModel.consume(legacy, "blaster_pistol", pistol)
	_assert_true(bool(rl["ok"]), "the veteran's first fire succeeds")
	_assert_equal(int(legacy.get("ammo", {})["blaster_pistol"]), 99, "first fire inits the magazine to full then spends one (100 -> 99)")
	_assert_equal(AmmoModel.packs(legacy), AmmoModel.STARTING_PACKS, "first fire grants STARTING_PACKS (no stranded veterans)")
	_assert_true(not bool(rl["reloaded"]), "the migrated first fire is from the fresh full magazine, not a reload")

	# --- heavy magazine drains to empty then reloads: consume 25 shots, the 26th reloads ---
	var h := {"ammo": {"heavy_blaster_pistol": 25, "migrated_packs": true}, "inventory": [{"template_key": "blaster_power_pack", "quantity": 1}]}
	for i in range(25):
		AmmoModel.consume(h, "heavy_blaster_pistol", heavy)
	_assert_equal(int(h.get("ammo", {})["heavy_blaster_pistol"]), 0, "25 shots empties a 25-round heavy magazine")
	_assert_equal(AmmoModel.packs(h), 1, "draining the magazine has not yet touched the pack")
	var r26 := AmmoModel.consume(h, "heavy_blaster_pistol", heavy)
	_assert_true(bool(r26["reloaded"]), "the 26th shot auto-reloads")
	_assert_equal(AmmoModel.packs(h), 0, "the 26th shot spends the pack")
	_assert_equal(int(h.get("ammo", {})["heavy_blaster_pistol"]), 24, "reloaded heavy magazine (25) less the fired shot -> 24")

	# --- add_packs / remove_pack (the vendor buy/sell path) ---
	var v := {"inventory": AmmoModel.initial_packs(), "ammo": {}}
	AmmoModel.add_packs(v, 3)
	_assert_equal(AmmoModel.packs(v), AmmoModel.STARTING_PACKS + 3, "add_packs stacks onto the carried count")
	var rem := AmmoModel.remove_pack(v)
	_assert_true(bool(rem["ok"]), "remove_pack succeeds while packs remain")
	_assert_equal(int(rem["packs_left"]), AmmoModel.STARTING_PACKS + 2, "remove_pack drops the count by one")
	var empty_v := {"inventory": []}
	_assert_true(not bool(AmmoModel.remove_pack(empty_v)["ok"]), "remove_pack fails with no packs (nothing to sell)")

	# --- PACK_COST is the WEG anchor ---
	_assert_equal(AmmoModel.PACK_COST, 25, "a power pack costs the WEG-anchored 25 credits")

	# --- REAL DATA: the equipped starter weapon (blaster_pistol) is ammo-tracked at 100; a melee row is not ---
	var weapons: Dictionary = _load_json(WEAPONS_PATH).get("weapons", {})
	if not weapons.is_empty():
		_assert_equal(AmmoModel.shots_per_weapon(weapons.get("blaster_pistol", {})), 100, "real blaster_pistol data carries ammo 100")
		_assert_true(AmmoModel.uses_ammo(weapons.get("blaster_pistol", {})), "real blaster_pistol is ammo-tracked")
		_assert_true(not AmmoModel.uses_ammo(weapons.get("vibroblade", {})), "real vibroblade (melee) is NOT ammo-tracked")
		_assert_true(not AmmoModel.uses_ammo(weapons.get("frag_grenade", {})), "real frag_grenade (single_use) stays latent")

	if _failures.is_empty():
		print("ammo_model_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

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
