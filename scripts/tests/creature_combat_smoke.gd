extends SceneTree
## Gate smoke for Wave G item G11: a live combat-content bug where a hostile creature's
## natural_attack.damage was written as PROSE ("opposed (brawling vs. brawling or STR)") instead of
## a machine WEG dice code, so scripts/rules/hostile_npc_model.gd's parse_pool()-based resolution
## silently produced a 0D damage pool — the creature attacked for nothing. This test builds the
## SAME target_* combat mapping the live arena builds (see scripts/net/network_manager.gd's
## `HostileNpc.attack_pools_from_creature(D6Rules, spawn)` call, spawn shaped like
## scripts/rules/creature_spawn_model.gd's roll_spawn() output) for EVERY `hostile:true` creature in
## data/creatures_clone_wars.json, and asserts the resolved attack + damage pools are never 0D. This
## was RED (glim_worm resolved to a 0D damage pool) before the data/creatures_clone_wars.json fix and
## is GREEN after it — turning the whole class of prose-damage content bugs into a gate failure.
##
## Pure / deterministic: no nodes, input, sockets, or rendering; no RNG needed (every hostile
## creature is walked directly and exhaustively, not sampled), matching the harness convention of
## scripts/tests/hostile_npc_model_smoke.gd and scripts/tests/content_smoke.gd.

const HostileNpc = preload("res://scripts/rules/hostile_npc_model.gd")
const CREATURES_PATH := "res://data/creatures_clone_wars.json"

var _failures: Array[String] = []

func _init() -> void:
	var rules = load("res://scripts/rules/d6_rules.gd").new()
	var creatures_data := _load_json(CREATURES_PATH)
	var creatures: Dictionary = creatures_data.get("creatures", {})
	if creatures.is_empty():
		_failures.append("creatures_clone_wars.json loaded a non-empty 'creatures' map")

	var keys: Array = creatures.keys()
	keys.sort()

	var hostile_pools_by_key: Dictionary = {}
	var hostile_count := 0

	for key in keys:
		var c: Dictionary = creatures[key]
		if not bool(c.get("hostile", false)):
			continue
		hostile_count += 1

		var natural_attack: Dictionary = c.get("natural_attack", {})
		var to_hit_skill := String(natural_attack.get("to_hit_skill", ""))
		var damage_code := String(natural_attack.get("damage", ""))
		_assert_true(to_hit_skill != "", "%s: natural_attack.to_hit_skill parses cleanly (non-empty)" % key)
		_assert_true(damage_code != "", "%s: natural_attack.damage parses cleanly (non-empty)" % key)

		# Build the exact spawn shape creature_spawn_model.roll_spawn() hands to the arena.
		var spawn := {
			"creature_key": key,
			"name": String(c.get("name", key)),
			"scale": String(c.get("scale", "creature")),
			"hostile": true,
			"pack_size": 1,
			"char_sheet": c.get("char_sheet", {}),
			"natural_attack": natural_attack,
		}
		var pools: Dictionary = HostileNpc.attack_pools_from_creature(rules, spawn)
		hostile_pools_by_key[key] = pools

		var attack_pool: Dictionary = pools.get("target_attack_pool", {})
		var damage_pool: Dictionary = pools.get("target_damage_pool", {})
		_assert_true(_dice(attack_pool) >= 1, "%s: target_attack_pool resolves to >= 1D (got %s), never 0D" % [key, rules.pool_to_string(attack_pool)])
		_assert_true(_dice(damage_pool) >= 1, "%s: target_damage_pool resolves to >= 1D (got %s), never 0D" % [key, rules.pool_to_string(damage_pool)])

	_assert_true(hostile_count >= 15, "at least fifteen hostile creatures were exercised (got %d)" % hostile_count)

	# --- Named regression coverage for the specific creatures this bug/fix touched -----------------
	# glim_worm: the confirmed 0D case (prose "opposed (brawling vs. brawling or STR)"; its real
	# attack is the special_attack.restraint grapple, so the fix gives natural_attack a sensible
	# STR+1D baseline bite so it is not a combat no-op).
	_assert_pool_text(rules, hostile_pools_by_key, "glim_worm", "target_damage_pool", "2D", "glim_worm damage (STR 1D + STR+1D baseline bite) no longer resolves to 0D")
	# mip_swarm: prose-wrapped but accidentally-parsing "2D auto-damage to anything sharing its
	# space..."; cleaned to a flat 2D code (same intended value, now a real machine dice code).
	_assert_pool_text(rules, hostile_pools_by_key, "mip_swarm", "target_damage_pool", "2D", "mip_swarm damage cleaned to a real 2D code")
	# spor_crawler: prose-wrapped "Poison 5D" duplicated the special_attack.poison damage as a fake
	# strike code; cleaned to a STR+1D baseline sting, leaving the lethal 5D venom in special_attack.
	_assert_pool_text(rules, hostile_pools_by_key, "spor_crawler", "target_damage_pool", "1D+2", "spor_crawler baseline sting (STR 0D+2 + STR+1D) no longer double-counts the poison as a strike code")

	rules.free()  # d6_rules extends Node
	_finish()

func _dice(pool: Dictionary) -> int:
	return int(pool.get("dice", 0))

func _assert_pool_text(rules: Object, pools_by_key: Dictionary, key: String, pool_field: String, expected: String, label: String) -> void:
	if not pools_by_key.has(key):
		_failures.append("%s: creature key present in hostile pool map" % key)
		return
	var pool: Dictionary = (pools_by_key[key] as Dictionary).get(pool_field, {})
	var actual := String(rules.pool_to_string(pool))
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_failures.append("%s exists" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s opens" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as a dictionary" % path)
		return {}
	return parsed

func _finish() -> void:
	if _failures.is_empty():
		print("creature_combat_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)
