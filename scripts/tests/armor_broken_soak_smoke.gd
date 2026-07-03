extends SceneTree
## LIVE-wiring guard for DIV-0026 Seam 4a: a BROKEN armor (quality pips AT the -6 condition floor) has
## ONLY its ARMOR contribution HALVED (ArmorRepairModel.pool_multiplier -> 0.5) inside ground_combat_model
## — bare Strength is NEVER sapped (broken-pool fix) — on BOTH the target/defender soak build
## (resolve_exchange) and the player's OWN soak build (return fire). Deterministic: fixed seeds, no
## randomize(). armor_repair_model_smoke pins the pure multiplier math; THIS pins that the resolver
## applies it to the armor delta at the soak seam, that a non-broken pip is byte-identical (multiplier
## 1.0), that broken armor still soaks ABOVE bare Strength, and that an UNCOVERED hit never touches bare
## Strength (the halving is gated on armor actually covering the hit).

const RulesScript := preload("res://scripts/rules/d6_rules.gd")
const ModelScript := preload("res://scripts/rules/ground_combat_model.gd")

var _failures: Array[String] = []
var _rules: Node
var _model: RefCounted

func _init() -> void:
	_rules = RulesScript.new()
	_model = ModelScript.new()
	var floor_pips := -6   # ArmorConditionModel.MIN_QUALITY_PIPS -> the "broken" floor

	# ============ TARGET / DEFENDER soak (resolve_exchange) ============
	# Armor energy 3D so it still contributes even after the -6 pip reduction, making the halving act on
	# a real armored pool (Strength 3D + armor). attacker 20D guarantees a hit so a soak_roll exists.
	var full := _target_exchange(0, 4242)
	var broken := _target_exchange(floor_pips, 4242)
	var full_soak := String(full["target_damage"]["soak_roll"]["pool"])
	var broken_soak := String(broken["target_damage"]["soak_roll"]["pool"])
	var strength_pips := _pips("3D")   # 9 — the bare Strength soak the armor sits ON TOP of, NEVER halved
	# Concrete: full-quality armored soak = Strength 3D + armor 3D = 6D. Broken halves ONLY the armor bonus,
	# not bare Strength: at -6 the armor 3D->1D, so the armored base is 4D (Strength 3D + armor 1D); the
	# armor bonus is the 3-pip (1D) delta over Strength, halved to int(3*0.5)=1 pip -> Strength 9 + 1 = 10
	# pips = 3D+1. (Halving the whole 4D pool -> 2D would sap innate Strength; broken-pool fix forbids that.)
	_assert_equal(full_soak, "6D", "full-quality target armored soak = Strength 3D + armor 3D = 6D")
	_assert_equal(broken_soak, "3D+1", "BROKEN target soak = bare Strength 3D + HALF the armor bonus (1D->+1) = 3D+1")
	var armor_bonus := _pips(_armored_base(floor_pips)) - strength_pips   # the floor-reduced armor's contribution
	_assert_equal(_pips(broken_soak), strength_pips + int(float(armor_bonus) * 0.5),
		"broken soak = bare Strength + HALF the floor-reduced armor bonus (Strength is untouched by the halving)")
	_assert_equal(_pips(broken_soak) > strength_pips, true,
		"broken armor still soaks MORE than bare Strength — the fix halves the armor bonus, it never saps the body")
	_assert_equal(_pips(broken_soak) < _pips(full_soak), true,
		"a broken-armor defender soaks strictly less than the SAME armor at full quality")

	# Determinism: same pips + same seed -> identical rolled soak total (and pool).
	var broken_again := _target_exchange(floor_pips, 4242)
	_assert_equal(int(broken_again["target_damage"]["soak_roll"]["total"]), int(broken["target_damage"]["soak_roll"]["total"]),
		"broken soak roll is deterministic under a fixed seed")

	# A one-pip-above-floor armor is NOT broken -> multiplier 1.0 -> NOT halved (the cliff is only at -6).
	var near := _target_exchange(floor_pips + 1, 4242)
	var near_soak := String(near["target_damage"]["soak_roll"]["pool"])
	_assert_equal(_pips(near_soak) > _pips(broken_soak), true,
		"one pip above the floor (-5) is NOT halved -> soaks more than broken (-6)")

	# ============ PLAYER's OWN soak (return fire) ============
	var full_rf := _player_return_fire(0, 917)
	var broken_rf := _player_return_fire(floor_pips, 917)
	var full_rf_soak := String(full_rf["return_fire"]["damage"]["soak_roll"]["pool"])
	var broken_rf_soak := String(broken_rf["return_fire"]["damage"]["soak_roll"]["pool"])
	_assert_equal(full_rf_soak, "6D", "full-quality player armored soak = Strength 3D + armor 3D = 6D")
	_assert_equal(broken_rf_soak, "3D+1", "BROKEN player soak = bare Strength 3D + HALF the armor bonus = 3D+1 on return fire")
	_assert_equal(_pips(broken_rf_soak) > strength_pips, true,
		"the player's own broken armor still soaks more than bare Strength (only the armor bonus is halved)")
	_assert_equal(_pips(broken_rf_soak) < _pips(full_rf_soak), true,
		"the player's own broken armor soaks less than full quality (the armor bonus is halved)")

	# ============ GATING: an UNCOVERED broken hit does NOT halve bare Strength ============
	# torso-only armor + a left_arm hit -> armor_applied false -> pool_multiplier NOT applied, even at -6.
	var uncovered_full := _target_exchange_uncovered(0, 9001)
	var uncovered_broken := _target_exchange_uncovered(floor_pips, 9001)
	_assert_equal(String(uncovered_broken["target_damage"]["soak_roll"]["pool"]),
		String(uncovered_full["target_damage"]["soak_roll"]["pool"]),
		"an UNCOVERED hit soaks bare Strength — broken armor does NOT halve it (halving is gated on coverage)")

	_rules.free()   # d6_rules is a Node — free it so the smoke leaks nothing at exit (no engine stderr)
	_rules = null
	_model = null

	if _failures.is_empty():
		print("armor_broken_soak_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

# --- exchange builders ---

func _armor() -> Dictionary:
	return {"protection_energy": "3D", "protection_physical": "3D"}

func _base_pools() -> Dictionary:
	return {
		"attacker_pool": {"dice": 4, "pips": 1},
		"damage_pool": {"dice": 4, "pips": 0},
		"player_dodge_pool": {"dice": 4, "pips": 0},
		"player_soak_pool": {"dice": 3, "pips": 0},
		"target_attack_pool": {"dice": 3, "pips": 0},
		"target_soak_pool": {"dice": 3, "pips": 0},
	}

# The armored soak base the model assembles at a given pip level, BEFORE the broken halving — used to
# prove the halved result equals exactly half of this (Strength 3D + energy armor 3D adjusted by pips).
func _armored_base(quality_pips: int) -> String:
	return _rules.pool_to_string(_rules.apply_armor_to_soak({"dice": 3, "pips": 0}, _armor(), "energy", quality_pips))

func _target_exchange(quality_pips: int, seed: int) -> Dictionary:
	var pools := _base_pools()
	pools["attacker_pool"] = {"dice": 20, "pips": 0}   # guarantee a hit so target rolls soak
	pools["target_armor"] = _armor()
	return _model.resolve_exchange(_rules, _model.initial_state(), {"wound_severity": 0, "armor_quality_pips": quality_pips}, pools, 12.0, 0, seed)

func _target_exchange_uncovered(quality_pips: int, seed: int) -> Dictionary:
	var pools := _base_pools()
	pools["attacker_pool"] = {"dice": 20, "pips": 0}
	var armor := _armor()
	armor["coverage"] = ["torso"]                      # only torso covered ...
	pools["target_armor"] = armor
	pools["target_hit_location_override"] = "left_arm" # ... but the hit lands on an uncovered arm
	return _model.resolve_exchange(_rules, _model.initial_state(), {"wound_severity": 0, "armor_quality_pips": quality_pips}, pools, 12.0, 0, seed)

func _player_return_fire(quality_pips: int, seed: int) -> Dictionary:
	var pools := _base_pools()
	pools["target_attack_pool"] = {"dice": 20, "pips": 0}   # guarantee the target's return fire hits
	pools["player_armor"] = _armor()
	var state: Dictionary = _model.initial_state()
	state["player_armor_quality_pips"] = quality_pips
	return _model.resolve_exchange(_rules, state, {"wound_severity": 0}, pools, 12.0, 4, seed)

func _pips(pool_text: String) -> int:
	var p: Dictionary = _rules.parse_pool(pool_text)
	return int(p.get("dice", 0)) * 3 + int(p.get("pips", 0))

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
