extends RefCounted

const ArmorConditionModel = preload("res://scripts/rules/armor_condition_model.gd")
const ArmorRepairModel = preload("res://scripts/rules/armor_repair_model.gd")
const WoundLadderModel = preload("res://scripts/rules/wound_ladder_model.gd")
const MAX_AIM_DICE := 3
const ACTION_WINDOW_SECONDS := 5.0
const COVER_QUARTER := 1
const DEFAULT_COVER_LEVEL := 2
const DISABLED_SEVERITY := 3
const DEFENSE_NONE := "none"
const DEFENSE_DODGE := "dodge"
const DEFENSE_FULL_DODGE := "full_dodge"

func initial_state() -> Dictionary:
	return {
		"round": 1,
		"action_window_seconds": ACTION_WINDOW_SECONDS,
		"aim_bonus_dice": 0,
		"player_cover_level": 0,
		"player_wound_severity": 0,
		"player_defense": DEFENSE_NONE,
		"player_character_points": 5,
		"player_force_points": 1,
		"force_point_active": false,
		"pending_attack_cp": 0,
		"pending_soak_cp": 0,
		"player_armor_quality_pips": 0,
	}

func add_aim(state: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next["aim_bonus_dice"] = mini(int(next.get("aim_bonus_dice", 0)) + 1, MAX_AIM_DICE)
	return next

func toggle_cover(state: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next["player_cover_level"] = 0 if int(next.get("player_cover_level", 0)) > 0 else DEFAULT_COVER_LEVEL
	return next

func declare_defense(state: Dictionary, defense_type: String) -> Dictionary:
	var next := state.duplicate(true)
	if defense_type == DEFENSE_DODGE or defense_type == DEFENSE_FULL_DODGE:
		next["player_defense"] = defense_type
	else:
		next["player_defense"] = DEFENSE_NONE
	return next

func queue_attack_cp(state: Dictionary, count: int = 1) -> Dictionary:
	return _queue_cp(state, "pending_attack_cp", count)

func queue_soak_cp(state: Dictionary, count: int = 1) -> Dictionary:
	return _queue_cp(state, "pending_soak_cp", count)

func activate_force_point(state: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	if int(next.get("player_force_points", 0)) <= 0:
		return next
	if int(next.get("pending_attack_cp", 0)) > 0 or int(next.get("pending_soak_cp", 0)) > 0:
		return next
	next["force_point_active"] = true
	return next

func resolve_exchange_with_action_window(rules: Object, state: Dictionary, target_state: Dictionary, pools: Dictionary, distance: float, target_cover_level: int, action_window: Dictionary, exchange_seed: int = -1, defender_defense_stance: String = DEFENSE_NONE) -> Dictionary:
	if not _action_window_ready(action_window):
		return _invalid_action_window_result(state, target_state, action_window, exchange_seed)
	var result := resolve_exchange(rules, state, target_state, pools, distance, target_cover_level, exchange_seed, defender_defense_stance)
	result["action_window"] = action_window
	return result

# `defender_defense_stance` (G3 / DIV-0019): the TARGET's DECLARED reaction dodge stance
# (DEFENSE_DODGE / DEFENSE_FULL_DODGE) against THIS attacker's shot. DEFENSE_NONE (the default) is
# byte-identical to the pre-G3 path: no defender roll, no RNG draw, empty defense — so every PvE /
# dummy / creature caller is unchanged. The defender's dodge pool comes from pools.target_dodge_pool.
func resolve_exchange(rules: Object, state: Dictionary, target_state: Dictionary, pools: Dictionary, distance: float, target_cover_level: int, exchange_seed: int = -1, defender_defense_stance: String = DEFENSE_NONE) -> Dictionary:
	var target_severity := int(target_state.get("wound_severity", 0))
	if target_severity >= DISABLED_SEVERITY:
		var disabled_round := int(state.get("round", 1))
		return {
			"already_disabled": true,
			"state": state.duplicate(true),
			"target_state": target_state.duplicate(true),
			"exchange_seed": exchange_seed,
			"events": [{
				"type": "target_already_disabled",
				"round": disabled_round,
				"exchange_seed": exchange_seed,
			}],
		}

	var rng := _rng_for_exchange(exchange_seed)
	var next_state := state.duplicate(true)
	var next_target := target_state.duplicate(true)
	var round_num := int(next_state.get("round", 1))
	var events := []
	if String(next_state.get("player_defense", DEFENSE_NONE)) == DEFENSE_FULL_DODGE:
		return _resolve_full_dodge_exchange(rules, next_state, next_target, pools, distance, rng, round_num, exchange_seed)

	var player_wound_penalty := _wound_penalty_dice(int(next_state.get("player_wound_severity", 0)))
	var force_point_spent := _consume_force_point(next_state)
	var aim_bonus := int(next_state.get("aim_bonus_dice", 0))
	var aim_pool := {"dice": aim_bonus, "pips": 0}
	var player_action_count := _player_action_count(next_state)
	var attack_cp_spent := _consume_cp(next_state, "pending_attack_cp")
	var player_armor: Dictionary = pools.get("player_armor", {})
	var attacker_scale := String(pools.get("attacker_scale", "character"))
	var target_scale := String(pools.get("target_scale", "character"))
	var attack_base_pool: Dictionary = rules.apply_wound_penalty(pools["attacker_pool"], player_wound_penalty)
	attack_base_pool = rules.apply_armor_dexterity_penalty(attack_base_pool, player_armor)
	if force_point_spent:
		attack_base_pool = rules.apply_force_point(attack_base_pool)
	attack_base_pool = rules.apply_multi_action_penalty(attack_base_pool, player_action_count)
	var shot_pool: Dictionary = rules.add_pools(attack_base_pool, aim_pool)
	shot_pool = rules.apply_scale_to_attack_pool(shot_pool, attacker_scale, target_scale)
	# G3 (DIV-0019): the DEFENDER's WEG reaction dodge vs this shot. Empty ({}) for every non-PvP path
	# (stance NONE) -> no RNG draw -> byte-identical to before; a declared-dodge PvP defender raises the
	# attacker's effective difficulty (dodge REPLACES the range difficulty; full_dodge ADDS to it).
	var defender_defense := _build_defender_reaction(rules, pools, next_target, defender_defense_stance, rng)
	var attack: Dictionary = rules.resolve_ranged_attack(shot_pool, distance, target_cover_level, rng, defender_defense, attack_cp_spent)
	events.append(_attack_event("player_attack", round_num, exchange_seed, attack, player_action_count, player_wound_penalty, shot_pool, attack_cp_spent, force_point_spent))
	next_state["aim_bonus_dice"] = 0
	if int(next_state.get("player_cover_level", 0)) > COVER_QUARTER:
		next_state["player_cover_level"] = COVER_QUARTER

	var target_damage := {}
	var target_wound := {}
	var target_disabled := false
	var target_wound_penalty := _wound_penalty_dice(target_severity)
	if bool(attack["success"]):
		var target_armor_profile: Dictionary = pools.get("target_armor", {})
		var target_hit_location := ArmorConditionModel.hit_location_for_attack(attack, String(pools.get("target_hit_location_override", "")))
		var target_armor: Dictionary = ArmorConditionModel.armor_for_location(target_armor_profile, target_hit_location)
		var target_armor_applied := not target_armor.is_empty()
		var target_armor_quality_pips := int(next_target.get("armor_quality_pips", pools.get("target_armor_quality_pips", 0)))
		var target_soak_base: Dictionary = rules.apply_armor_to_soak(
			pools["target_soak_pool"],
			target_armor,
			"energy",
			target_armor_quality_pips
		)
		# DIV-0026 (Seam 4a): armor sitting AT the condition floor (-6) is "broken" -> only its ARMOR
		# contribution is HALVED until repaired (bare Strength is never sapped). Applied on the armored
		# base BEFORE scale/wound so the halving stacks in the documented order; gated on armor_applied so
		# an UNCOVERED hit (no armor contribution) is untouched. pool_multiplier is 1.0 for any non-floor
		# pip, so every non-broken path stays byte-identical (no RNG/pool change). Passes the pre-armor
		# soak pool so the helper can isolate + halve the armor delta alone.
		target_soak_base = _apply_broken_pool_multiplier(rules, pools["target_soak_pool"], target_soak_base, target_armor_applied, target_armor_quality_pips)
		target_soak_base = rules.apply_scale_to_soak_pool(target_soak_base, attacker_scale, target_scale)
		var target_soak_pool: Dictionary = rules.apply_wound_penalty(target_soak_base, target_wound_penalty)
		# WEG (Guide_01): a Force Point doubles ALL your dice this round — damage included. This pool
		# was the one FP-affected roll that previously did NOT double (attack/dodge/soak all do). A
		# MELEE weapon doubles only the STR portion (not the weapon bonus), so the arena precomputes
		# damage_pool_fp = 2*STR + bonus; a ranged weapon falls back to doubling its whole flat pool.
		var base_damage: Dictionary = pools["damage_pool"]
		if force_point_spent:
			base_damage = pools.get("damage_pool_fp", rules.apply_force_point(pools["damage_pool"]))
		var damage_pool: Dictionary = rules.apply_scale_to_damage_pool(base_damage, attacker_scale, target_scale)
		target_damage = rules.resolve_damage(damage_pool, target_soak_pool, rng)
		target_wound = target_damage["wound"]
		# G2 (DIV-0006/0019): expose the RAW single-hit severity from THIS exchange, distinct from the
		# max-folded running `wound_severity`. The arena needs it to ACCUMULATE a player target up the WEG
		# wound ladder (escalate()) without double-counting the target's already-projected prior wound.
		# Purely additive — every existing consumer still reads the unchanged max-folded wound_severity.
		next_target["this_hit_severity"] = int(target_wound["severity"])
		target_severity = maxi(target_severity, int(target_wound["severity"]))
		next_target["wound_severity"] = target_severity
		next_target["armor_quality_pips"] = target_armor_quality_pips
		next_target["hit_location"] = target_hit_location
		next_target["armor_applied"] = target_armor_applied
		next_target["armor_coverage"] = ArmorConditionModel.covered_locations(target_armor_profile)
		next_target = ArmorConditionModel.apply_degradation(next_target, "armor_quality_pips", target_armor, target_damage)
		target_disabled = target_severity >= DISABLED_SEVERITY
		events.append(_damage_event("target_damage", round_num, exchange_seed, target_damage, target_severity, target_disabled, target_wound_penalty, next_target))

	var return_fire := {}
	# DIV-0019: suppress the target's auto return-fire when the caller opts in (a declared PvP duel
	# where the defender ALSO queued their own attack -> one attack each, no double-count). Defaulted
	# false so every existing caller (dummy/creature/incoming) is byte-identical; a passive PvP victim
	# (no queued intent) leaves it false and still reaction-fires once.
	if not target_disabled and not bool(pools.get("suppress_return_fire", false)):
		return_fire = _resolve_return_fire(rules, next_state, pools, distance, rng, target_severity, force_point_spent)
		events.append(_return_fire_event(round_num, exchange_seed, return_fire))
		next_state["player_wound_severity"] = maxi(
			int(next_state.get("player_wound_severity", 0)),
			int(return_fire.get("player_wound_severity", 0))
		)

	next_state["round"] = round_num + 1
	events.append({
		"type": "exchange_completed",
		"round": round_num,
		"exchange_seed": exchange_seed,
		"next_round": int(next_state["round"]),
		"target_disabled": target_disabled,
		"player_wound_severity": int(next_state.get("player_wound_severity", 0)),
	})

	return {
		"already_disabled": false,
		"round": round_num,
		"exchange_seed": exchange_seed,
		"aim_bonus_dice": aim_bonus,
		"player_action_count": player_action_count,
		"player_wound_penalty_dice": player_wound_penalty,
		"attack_cp_spent": attack_cp_spent,
		"soak_cp_spent": int(return_fire.get("soak_cp_spent", 0)),
		"force_point_spent": force_point_spent,
		"shot_pool": shot_pool,
		"attack": attack,
		"target_damage": target_damage,
		"target_wound": target_wound,
		"target_disabled": target_disabled,
		"return_fire": return_fire,
		"events": events,
		"state": next_state,
		"target_state": next_target,
	}

func _resolve_full_dodge_exchange(rules: Object, state: Dictionary, target_state: Dictionary, pools: Dictionary, distance: float, rng: RandomNumberGenerator, round_num: int, exchange_seed: int) -> Dictionary:
	var player_wound_penalty := _wound_penalty_dice(int(state.get("player_wound_severity", 0)))
	var force_point_spent := _consume_force_point(state)
	var target_wound_severity := int(target_state.get("wound_severity", 0))
	var return_fire := _resolve_return_fire(rules, state, pools, distance, rng, target_wound_severity, force_point_spent)
	state["player_wound_severity"] = maxi(
		int(state.get("player_wound_severity", 0)),
		int(return_fire.get("player_wound_severity", 0))
	)
	state["round"] = round_num + 1

	var events := [
		{
			"type": "player_full_dodge",
			"round": round_num,
			"exchange_seed": exchange_seed,
			"action_count": 1,
			"wound_penalty_dice": player_wound_penalty,
			"force_point_spent": force_point_spent,
			"defense_type": DEFENSE_FULL_DODGE,
		},
		_return_fire_event(round_num, exchange_seed, return_fire),
		{
			"type": "exchange_completed",
			"round": round_num,
			"exchange_seed": exchange_seed,
			"next_round": int(state["round"]),
			"target_disabled": false,
			"player_wound_severity": int(state.get("player_wound_severity", 0)),
		},
	]

	return {
		"already_disabled": false,
		"player_attack_skipped": true,
		"skip_reason": DEFENSE_FULL_DODGE,
		"round": round_num,
		"exchange_seed": exchange_seed,
		"aim_bonus_dice": int(state.get("aim_bonus_dice", 0)),
		"player_action_count": 1,
		"player_wound_penalty_dice": player_wound_penalty,
		"attack_cp_spent": 0,
		"soak_cp_spent": int(return_fire.get("soak_cp_spent", 0)),
		"force_point_spent": force_point_spent,
		"shot_pool": {"dice": 0, "pips": 0},
		"attack": {},
		"target_damage": {},
		"target_wound": {},
		"target_disabled": false,
		"return_fire": return_fire,
		"events": events,
		"state": state,
		"target_state": target_state,
	}

func _resolve_return_fire(rules: Object, state: Dictionary, pools: Dictionary, distance: float, rng: RandomNumberGenerator, target_wound_severity: int = 0, force_point_active: bool = false) -> Dictionary:
	var player_wound_penalty := _wound_penalty_dice(int(state.get("player_wound_severity", 0)))
	var target_wound_penalty := _wound_penalty_dice(target_wound_severity)
	var player_armor_profile: Dictionary = pools.get("player_armor", {})
	var target_armor: Dictionary = pools.get("target_armor", {})
	var player_scale := String(pools.get("attacker_scale", "character"))
	var target_scale := String(pools.get("target_scale", "character"))
	var target_attack_pool: Dictionary = rules.apply_wound_penalty(pools["target_attack_pool"], target_wound_penalty)
	target_attack_pool = rules.apply_armor_dexterity_penalty(target_attack_pool, target_armor)
	var dodge_pool: Dictionary = rules.apply_wound_penalty(
		pools.get("player_dodge_pool", {"dice": 0, "pips": 0}),
		player_wound_penalty
	)
	dodge_pool = rules.apply_armor_dexterity_penalty(dodge_pool, player_armor_profile)
	if force_point_active:
		dodge_pool = rules.apply_force_point(dodge_pool)
	target_attack_pool = rules.apply_scale_to_attack_pool(target_attack_pool, target_scale, player_scale)
	dodge_pool = rules.apply_scale_to_dodge_pool(dodge_pool, target_scale, player_scale)
	var defense := _build_defense(
		dodge_pool,
		String(state.get("player_defense", DEFENSE_NONE))
	)
	var attack: Dictionary = rules.resolve_ranged_attack(
		target_attack_pool,
		distance,
		int(state.get("player_cover_level", 0)),
		rng,
		defense
	)

	state["player_defense"] = DEFENSE_NONE
	if not bool(attack["success"]):
		return {
			"attack": attack,
			"hit": false,
			"damage": {},
			"wound": {},
			"player_wound_severity": int(state.get("player_wound_severity", 0)),
			"player_wound_penalty_dice": player_wound_penalty,
			"target_wound_penalty_dice": target_wound_penalty,
			"soak_cp_spent": 0,
			"force_point_active": force_point_active,
			"defense_used": defense,
		}

	var player_strength_pool: Dictionary = pools["player_soak_pool"]
	if force_point_active:
		player_strength_pool = rules.apply_force_point(player_strength_pool)
	var player_armor_quality_pips := int(state.get("player_armor_quality_pips", pools.get("player_armor_quality_pips", 0)))
	var player_hit_location := ArmorConditionModel.hit_location_for_attack(attack, String(pools.get("player_hit_location_override", "")))
	var player_armor: Dictionary = ArmorConditionModel.armor_for_location(player_armor_profile, player_hit_location)
	var player_armor_applied := not player_armor.is_empty()
	var player_soak_base: Dictionary = rules.apply_armor_to_soak(
		player_strength_pool,
		player_armor,
		"energy",
		player_armor_quality_pips
	)
	# DIV-0026 (Seam 4a): the player's OWN broken armor (pips at the -6 floor) halves only its ARMOR
	# contribution too — never the wearer's bare Strength. Same order/gating as the target side: on the
	# armored base, before scale/wound, only when armor covered the hit. Passes the pre-armor Strength
	# pool so the helper isolates + halves the armor delta. Non-broken -> multiplier 1.0 -> byte-identical.
	player_soak_base = _apply_broken_pool_multiplier(rules, player_strength_pool, player_soak_base, player_armor_applied, player_armor_quality_pips)
	player_soak_base = rules.apply_scale_to_soak_pool(player_soak_base, target_scale, player_scale)
	var player_soak_pool: Dictionary = rules.apply_wound_penalty(player_soak_base, player_wound_penalty)
	var soak_cp_spent := _consume_cp(state, "pending_soak_cp")
	var target_damage_pool: Dictionary = pools.get("target_damage_pool", pools["damage_pool"])
	var damage_pool: Dictionary = rules.apply_scale_to_damage_pool(target_damage_pool, target_scale, player_scale)
	# DIV-0016: incoming-fire lethality is data-driven. DEFAULT true = pure WEG STUN (incoming fire
	# can only Stun, sev<=1) — unchanged for every existing caller/path. A sparring target sets
	# target_stun_mode=false so its fire can roll a real wound (the arena then caps it at
	# SPARRING_MAX_SEVERITY so it stays non-lethal).
	var stun_mode := bool(pools.get("target_stun_mode", true))
	var damage: Dictionary = rules.resolve_damage(damage_pool, player_soak_pool, rng, stun_mode, soak_cp_spent)
	var wound: Dictionary = damage["wound"]
	var armor_state := {
		"player_armor_quality_pips": player_armor_quality_pips,
	}
	armor_state = ArmorConditionModel.apply_degradation(armor_state, "player_armor_quality_pips", player_armor, damage)
	state["player_armor_quality_pips"] = int(armor_state.get("player_armor_quality_pips", player_armor_quality_pips))
	return {
		"attack": attack,
		"hit": true,
		"player_hit_location": player_hit_location,
		"player_armor_applied": player_armor_applied,
		"player_armor_coverage": ArmorConditionModel.covered_locations(player_armor_profile),
		"damage": damage,
		"wound": wound,
		"player_wound_severity": maxi(
			int(state.get("player_wound_severity", 0)),
			int(wound["severity"])
		),
		"player_wound_penalty_dice": player_wound_penalty,
		"target_wound_penalty_dice": target_wound_penalty,
		"soak_cp_spent": soak_cp_spent,
		"force_point_active": force_point_active,
		"defense_used": defense,
		"player_armor_quality_pips_before": int(armor_state.get("armor_quality_pips_before", player_armor_quality_pips)),
		"player_armor_quality_pips_after": int(armor_state.get("armor_quality_pips_after", player_armor_quality_pips)),
		"player_armor_degraded_pips": int(armor_state.get("armor_degraded_pips", 0)),
	}

func resolve_incoming_fire_window_with_action_window(rules: Object, state: Dictionary, pools: Dictionary, incoming_attacks: Array, action_window: Dictionary, exchange_seed: int = -1) -> Dictionary:
	if not _action_window_ready(action_window):
		return _invalid_action_window_result(state, {}, action_window, exchange_seed)
	var result := resolve_incoming_fire_window(rules, state, pools, incoming_attacks, exchange_seed)
	result["action_window"] = action_window
	return result

func resolve_incoming_fire_window(rules: Object, state: Dictionary, pools: Dictionary, incoming_attacks: Array, exchange_seed: int = -1) -> Dictionary:
	var rng := _rng_for_exchange(exchange_seed)
	var next_state := state.duplicate(true)
	var round_num := int(next_state.get("round", 1))
	var player_wound_penalty := _wound_penalty_dice(int(next_state.get("player_wound_severity", 0)))
	var force_point_spent := _consume_force_point(next_state)
	var player_armor: Dictionary = pools.get("player_armor", {})
	var dodge_pool: Dictionary = rules.apply_wound_penalty(
		pools.get("player_dodge_pool", {"dice": 0, "pips": 0}),
		player_wound_penalty
	)
	dodge_pool = rules.apply_armor_dexterity_penalty(dodge_pool, player_armor)
	if force_point_spent:
		dodge_pool = rules.apply_force_point(dodge_pool)
	var defense := _build_defense(dodge_pool, String(next_state.get("player_defense", DEFENSE_NONE)))
	if not defense.is_empty():
		defense = rules.prepare_ranged_defense(defense, rng)

	var events := []
	var attack_results := []
	for i in range(incoming_attacks.size()):
		var incoming: Dictionary = incoming_attacks[i]
		var source_pools: Dictionary = pools.duplicate(true)
		if incoming.has("attack_pool"):
			source_pools["target_attack_pool"] = incoming["attack_pool"]
		if incoming.has("damage_pool"):
			source_pools["target_damage_pool"] = incoming["damage_pool"]
		if incoming.has("armor"):
			source_pools["target_armor"] = incoming["armor"]
		if incoming.has("scale"):
			source_pools["target_scale"] = String(incoming["scale"])
		if incoming.has("hit_location"):
			source_pools["player_hit_location_override"] = String(incoming["hit_location"])
		if incoming.has("player_hit_location_override"):
			source_pools["player_hit_location_override"] = String(incoming["player_hit_location_override"])
		var result := _resolve_single_incoming_attack(
			rules,
			next_state,
			source_pools,
			float(incoming.get("distance", 12.0)),
			int(incoming.get("cover_level", next_state.get("player_cover_level", 0))),
			rng,
			int(incoming.get("wound_severity", 0)),
			force_point_spent,
			defense
		)
		result["source_id"] = String(incoming.get("source_id", "incoming_%d" % i))
		result["source_name"] = String(incoming.get("source_name", result["source_id"]))
		attack_results.append(result)
		events.append(_incoming_fire_event(round_num, exchange_seed, result))
		next_state["player_wound_severity"] = maxi(
			int(next_state.get("player_wound_severity", 0)),
			int(result.get("player_wound_severity", 0))
		)

	next_state["player_defense"] = DEFENSE_NONE
	next_state["round"] = round_num + 1
	events.append({
		"type": "incoming_fire_window_completed",
		"round": round_num,
		"exchange_seed": exchange_seed,
		"next_round": int(next_state["round"]),
		"player_wound_severity": int(next_state.get("player_wound_severity", 0)),
		"incoming_count": attack_results.size(),
		"force_point_spent": force_point_spent,
	})

	return {
		"round": round_num,
		"exchange_seed": exchange_seed,
		"force_point_spent": force_point_spent,
		"defense": defense,
		"incoming": attack_results,
		"events": events,
		"state": next_state,
	}

func _resolve_single_incoming_attack(rules: Object, state: Dictionary, pools: Dictionary, distance: float, cover_level: int, rng: RandomNumberGenerator, target_wound_severity: int, force_point_active: bool, defense: Dictionary) -> Dictionary:
	var player_wound_penalty := _wound_penalty_dice(int(state.get("player_wound_severity", 0)))
	var target_wound_penalty := _wound_penalty_dice(target_wound_severity)
	var player_armor_profile: Dictionary = pools.get("player_armor", {})
	var target_armor: Dictionary = pools.get("target_armor", {})
	var player_scale := String(pools.get("attacker_scale", "character"))
	var target_scale := String(pools.get("target_scale", "character"))
	var target_attack_pool: Dictionary = rules.apply_wound_penalty(pools["target_attack_pool"], target_wound_penalty)
	target_attack_pool = rules.apply_armor_dexterity_penalty(target_attack_pool, target_armor)
	target_attack_pool = rules.apply_scale_to_attack_pool(target_attack_pool, target_scale, player_scale)
	var attack: Dictionary = rules.resolve_ranged_attack(
		target_attack_pool,
		distance,
		cover_level,
		rng,
		defense
	)
	if not bool(attack["success"]):
		return {
			"attack": attack,
			"hit": false,
			"damage": {},
			"wound": {},
			"player_wound_severity": int(state.get("player_wound_severity", 0)),
			"player_wound_penalty_dice": player_wound_penalty,
			"target_wound_penalty_dice": target_wound_penalty,
			"soak_cp_spent": 0,
			"force_point_active": force_point_active,
			"defense_used": defense,
		}

	var player_strength_pool: Dictionary = pools["player_soak_pool"]
	if force_point_active:
		player_strength_pool = rules.apply_force_point(player_strength_pool)
	var player_armor_quality_pips := int(state.get("player_armor_quality_pips", pools.get("player_armor_quality_pips", 0)))
	var player_hit_location := ArmorConditionModel.hit_location_for_attack(attack, String(pools.get("player_hit_location_override", "")))
	var player_armor: Dictionary = ArmorConditionModel.armor_for_location(player_armor_profile, player_hit_location)
	var player_armor_applied := not player_armor.is_empty()
	var player_soak_base: Dictionary = rules.apply_armor_to_soak(
		player_strength_pool,
		player_armor,
		"energy",
		player_armor_quality_pips
	)
	# DIV-0026 (Seam 4a): the player's OWN broken armor (pips at the -6 floor) halves only its ARMOR
	# contribution too — never the wearer's bare Strength. Same order/gating as the target side: on the
	# armored base, before scale/wound, only when armor covered the hit. Passes the pre-armor Strength
	# pool so the helper isolates + halves the armor delta. Non-broken -> multiplier 1.0 -> byte-identical.
	player_soak_base = _apply_broken_pool_multiplier(rules, player_strength_pool, player_soak_base, player_armor_applied, player_armor_quality_pips)
	player_soak_base = rules.apply_scale_to_soak_pool(player_soak_base, target_scale, player_scale)
	var player_soak_pool: Dictionary = rules.apply_wound_penalty(player_soak_base, player_wound_penalty)
	var soak_cp_spent := _consume_cp(state, "pending_soak_cp")
	var target_damage_pool: Dictionary = pools.get("target_damage_pool", pools["damage_pool"])
	var damage_pool: Dictionary = rules.apply_scale_to_damage_pool(target_damage_pool, target_scale, player_scale)
	# DIV-0016: incoming-fire lethality is data-driven. DEFAULT true = pure WEG STUN (incoming fire
	# can only Stun, sev<=1) — unchanged for every existing caller/path. A sparring target sets
	# target_stun_mode=false so its fire can roll a real wound (the arena then caps it at
	# SPARRING_MAX_SEVERITY so it stays non-lethal).
	var stun_mode := bool(pools.get("target_stun_mode", true))
	var damage: Dictionary = rules.resolve_damage(damage_pool, player_soak_pool, rng, stun_mode, soak_cp_spent)
	var wound: Dictionary = damage["wound"]
	var armor_state := {
		"player_armor_quality_pips": player_armor_quality_pips,
	}
	armor_state = ArmorConditionModel.apply_degradation(armor_state, "player_armor_quality_pips", player_armor, damage)
	state["player_armor_quality_pips"] = int(armor_state.get("player_armor_quality_pips", player_armor_quality_pips))
	return {
		"attack": attack,
		"hit": true,
		"player_hit_location": player_hit_location,
		"player_armor_applied": player_armor_applied,
		"player_armor_coverage": ArmorConditionModel.covered_locations(player_armor_profile),
		"damage": damage,
		"wound": wound,
		"player_wound_severity": maxi(
			int(state.get("player_wound_severity", 0)),
			int(wound["severity"])
		),
		"player_wound_penalty_dice": player_wound_penalty,
		"target_wound_penalty_dice": target_wound_penalty,
		"soak_cp_spent": soak_cp_spent,
		"force_point_active": force_point_active,
		"defense_used": defense,
		"player_armor_quality_pips_before": int(armor_state.get("armor_quality_pips_before", player_armor_quality_pips)),
		"player_armor_quality_pips_after": int(armor_state.get("armor_quality_pips_after", player_armor_quality_pips)),
		"player_armor_degraded_pips": int(armor_state.get("armor_degraded_pips", 0)),
	}

func _rng_for_exchange(exchange_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if exchange_seed >= 0:
		rng.seed = exchange_seed
	else:
		rng.randomize()
	return rng

func _action_window_ready(action_window: Dictionary) -> bool:
	return bool(action_window.get("ready", false)) and String(action_window.get("phase", "")) == "resolution"

func _invalid_action_window_result(state: Dictionary, target_state: Dictionary, action_window: Dictionary, exchange_seed: int) -> Dictionary:
	return {
		"invalid_action_window": true,
		"already_disabled": false,
		"round": int(state.get("round", 1)),
		"exchange_seed": exchange_seed,
		"events": [{
			"type": "action_window_invalid",
			"round": int(state.get("round", 1)),
			"exchange_seed": exchange_seed,
			"errors": action_window.get("errors", []),
			"phase": String(action_window.get("phase", "")),
		}],
		"state": state.duplicate(true),
		"target_state": target_state.duplicate(true),
		"action_window": action_window,
	}

func _player_action_count(state: Dictionary) -> int:
	var defense_type := String(state.get("player_defense", DEFENSE_NONE))
	if defense_type == DEFENSE_DODGE:
		return 2
	return 1

func _queue_cp(state: Dictionary, key: String, count: int) -> Dictionary:
	var next := state.duplicate(true)
	if bool(next.get("force_point_active", false)):
		return next
	var available := int(next.get("player_character_points", 0))
	var current := int(next.get(key, 0))
	next[key] = clampi(current + maxi(count, 0), 0, mini(available, 5))
	return next

func _consume_cp(state: Dictionary, key: String) -> int:
	var available := int(state.get("player_character_points", 0))
	var requested := int(state.get(key, 0))
	var spent := clampi(requested, 0, mini(available, 5))
	state["player_character_points"] = maxi(available - spent, 0)
	state[key] = 0
	return spent

func _consume_force_point(state: Dictionary) -> bool:
	if not bool(state.get("force_point_active", false)):
		return false
	var available := int(state.get("player_force_points", 0))
	if available <= 0:
		state["force_point_active"] = false
		return false
	state["player_force_points"] = available - 1
	state["force_point_active"] = false
	return true

# DIV-0026 (Seam 4a): halve ONLY the ARMOR's contribution to soak when the equipped armor is "broken"
# (its quality pips sit at the condition floor, -6). ArmorRepairModel owns the broken boolean + the exact
# multiplier (0.5); this just applies it — to the armor BONUS (armored_pool - unarmored_pool), NOT to the
# whole armored pool. Halving the combined Strength+armor pool would make broken armor soak WORSE than
# wearing nothing (it would sap innate Strength), which is nonsensical: broken armor should degrade its
# OWN protection, never the wearer's body. So we isolate the armor delta in total-pip space, halve just
# that, and re-add it to the untouched unarmored (Strength) pool. No-ops (returns the armored pool
# unchanged) when armor did not cover the hit, or the multiplier is 1.0 (any non-floor pip) — so every
# existing non-broken path is byte-for-byte identical. maxi(...,0) guards the degenerate armored<unarmored
# case. (verify: broken-pool — halve the armor bonus, floor the result at bare Strength.)
func _apply_broken_pool_multiplier(rules: Object, unarmored_pool: Dictionary, armored_pool: Dictionary, armor_applied: bool, quality_pips: int) -> Dictionary:
	if not armor_applied:
		return armored_pool
	var multiplier := ArmorRepairModel.pool_multiplier(quality_pips)
	if multiplier == 1.0:
		return armored_pool
	var unarmored_pips := int(unarmored_pool.get("dice", 0)) * 3 + int(unarmored_pool.get("pips", 0))
	var armored_pips := int(armored_pool.get("dice", 0)) * 3 + int(armored_pool.get("pips", 0))
	var armor_bonus_pips := maxi(armored_pips - unarmored_pips, 0)          # the armor's contribution only
	var halved_bonus := int(float(armor_bonus_pips) * multiplier)          # halve ONLY the armor bonus
	return rules.normalize_pool(0, unarmored_pips + halved_bonus)          # bare Strength + half the armor

func _wound_penalty_dice(severity: int) -> int:
	# Delegate to the canonical WEG wound ladder (DIV-0008). Single-hit severities map:
	# sev 0->0, 1->1 (stunned), 2->1 (wounded), 3->0, 4->0, 5->0 — the "out" tiers
	# (incapacitated/mortally/dead) carry NO penalty because a downed character can't act
	# (Guide_19 §1 / Guide_01 §7). The -2D tier belongs to wounded_twice, which is reached
	# ONLY cumulatively via WoundLadderModel.escalate() and never from a single-hit severity.
	return WoundLadderModel.penalty_dice_for_severity(severity)

# G3 (DIV-0019): assemble a DEFENDER player's reaction dodge vs an incoming primary attack. Mirrors
# _resolve_return_fire's penalization of the dodge pool (defender wound penalty + armor Dexterity
# penalty + scale) but keyed off the DEFENDER (target_*) side, then caches one roll via
# prepare_ranged_defense — the contract built for exactly this (one dodge reused across the window).
# Returns {} for DEFENSE_NONE so the non-PvP path draws no RNG and stays byte-identical.
func _build_defender_reaction(rules: Object, pools: Dictionary, target_state: Dictionary, defense_stance: String, rng: RandomNumberGenerator) -> Dictionary:
	if defense_stance != DEFENSE_DODGE and defense_stance != DEFENSE_FULL_DODGE:
		return {}
	var defender_wound_penalty := _wound_penalty_dice(int(target_state.get("wound_severity", 0)))
	var defender_armor: Dictionary = pools.get("target_armor", {})
	var attacker_scale := String(pools.get("attacker_scale", "character"))
	var defender_scale := String(pools.get("target_scale", "character"))
	var dodge_pool: Dictionary = rules.apply_wound_penalty(
		pools.get("target_dodge_pool", {"dice": 0, "pips": 0}),
		defender_wound_penalty
	)
	dodge_pool = rules.apply_armor_dexterity_penalty(dodge_pool, defender_armor)
	dodge_pool = rules.apply_scale_to_dodge_pool(dodge_pool, attacker_scale, defender_scale)
	var defense := _build_defense(dodge_pool, defense_stance)
	if not defense.is_empty():
		defense = rules.prepare_ranged_defense(defense, rng)
	return defense

func _build_defense(dodge_pool: Dictionary, defense_type: String) -> Dictionary:
	if defense_type == DEFENSE_NONE:
		return {}
	var action_count := 2 if defense_type == DEFENSE_DODGE else 1
	return {
		"type": defense_type,
		"pool": dodge_pool,
		"action_count": action_count,
	}

func _attack_event(event_type: String, round_num: int, exchange_seed: int, attack: Dictionary, action_count: int, wound_penalty_dice: int, shot_pool: Dictionary, attack_cp_spent: int = 0, force_point_spent: bool = false) -> Dictionary:
	return {
		"type": event_type,
		"round": round_num,
		"exchange_seed": exchange_seed,
		"action_count": action_count,
		"wound_penalty_dice": wound_penalty_dice,
		"attack_cp_spent": attack_cp_spent,
		"attack_cp_total": int(attack.get("attack_cp", {}).get("total", 0)),
		"force_point_spent": force_point_spent,
		"shot_pool": _pool_text(shot_pool),
		"range_name": String(attack.get("range_name", "")),
		"distance": float(attack.get("distance", 0.0)),
		"difficulty": int(attack.get("difficulty", 0)),
		"attack_total": int(attack.get("attack", {}).get("total", 0)),
		"margin": int(attack.get("margin", 0)),
		"success": bool(attack.get("success", false)),
		"blocked": bool(attack.get("blocked", false)),
		"cover_level": int(attack.get("cover", {}).get("level", 0)),
		"defense_type": String(attack.get("defense", {}).get("type", DEFENSE_NONE)),
	}

func _damage_event(event_type: String, round_num: int, exchange_seed: int, damage: Dictionary, wound_severity: int, disabled: bool, wound_penalty_dice: int = 0, armor_state: Dictionary = {}) -> Dictionary:
	var wound: Dictionary = damage.get("wound", {})
	return {
		"type": event_type,
		"round": round_num,
		"exchange_seed": exchange_seed,
		"wound_penalty_dice": wound_penalty_dice,
		"damage_total": int(damage.get("damage_roll", {}).get("total", 0)),
		"soak_total": int(damage.get("soak_roll", {}).get("total", 0)),
		"margin": int(damage.get("margin", 0)),
		"wound_key": String(wound.get("key", "no_damage")),
		"wound_severity": wound_severity,
		"disabled": disabled,
		"hit_location": String(armor_state.get("hit_location", "")),
		"armor_applied": bool(armor_state.get("armor_applied", false)),
		"armor_coverage": armor_state.get("armor_coverage", []),
		"armor_quality_pips_before": int(armor_state.get("armor_quality_pips_before", armor_state.get("armor_quality_pips", 0))),
		"armor_quality_pips_after": int(armor_state.get("armor_quality_pips_after", armor_state.get("armor_quality_pips", 0))),
		"armor_degraded_pips": int(armor_state.get("armor_degraded_pips", 0)),
	}

func _return_fire_event(round_num: int, exchange_seed: int, return_fire: Dictionary) -> Dictionary:
	var attack: Dictionary = return_fire.get("attack", {})
	var damage: Dictionary = return_fire.get("damage", {})
	var wound: Dictionary = return_fire.get("wound", {})
	return {
		"type": "remote_return_fire",
		"round": round_num,
		"exchange_seed": exchange_seed,
		"hit": bool(return_fire.get("hit", false)),
		"difficulty": int(attack.get("difficulty", 0)),
		"attack_total": int(attack.get("attack", {}).get("total", 0)),
		"margin": int(attack.get("margin", 0)),
		"cover_level": int(attack.get("cover", {}).get("level", 0)),
		"defense_type": String(attack.get("defense", {}).get("type", DEFENSE_NONE)),
		"player_wound_penalty_dice": int(return_fire.get("player_wound_penalty_dice", 0)),
		"target_wound_penalty_dice": int(return_fire.get("target_wound_penalty_dice", 0)),
		"soak_cp_spent": int(return_fire.get("soak_cp_spent", 0)),
		"soak_cp_total": int(damage.get("soak_cp", {}).get("total", 0)),
		"force_point_active": bool(return_fire.get("force_point_active", false)),
		"player_hit_location": String(return_fire.get("player_hit_location", "")),
		"player_armor_applied": bool(return_fire.get("player_armor_applied", false)),
		"player_armor_coverage": return_fire.get("player_armor_coverage", []),
		"player_armor_quality_pips_before": int(return_fire.get("player_armor_quality_pips_before", 0)),
		"player_armor_quality_pips_after": int(return_fire.get("player_armor_quality_pips_after", 0)),
		"player_armor_degraded_pips": int(return_fire.get("player_armor_degraded_pips", 0)),
		"damage_total": int(damage.get("damage_roll", {}).get("total", 0)),
		"soak_total": int(damage.get("soak_roll", {}).get("total", 0)),
		"wound_key": String(wound.get("key", "no_damage")),
		"player_wound_severity": int(return_fire.get("player_wound_severity", 0)),
	}

func _incoming_fire_event(round_num: int, exchange_seed: int, incoming_fire: Dictionary) -> Dictionary:
	var event := _return_fire_event(round_num, exchange_seed, incoming_fire)
	event["type"] = "incoming_fire"
	event["source_id"] = String(incoming_fire.get("source_id", ""))
	event["source_name"] = String(incoming_fire.get("source_name", ""))
	return event

func _pool_text(pool: Dictionary) -> String:
	var dice := int(pool.get("dice", 0))
	var pips := int(pool.get("pips", 0))
	if pips == 0:
		return "%dD" % dice
	return "%dD+%d" % [dice, pips]

func wound_name_for_severity(severity: int) -> String:
	if severity <= 0:
		return "OK"
	if severity == 1:
		return "Stunned"
	if severity == 2:
		return "Wounded"
	if severity == 3:
		return "Incapacitated"
	if severity == 4:
		return "Mortally Wounded"
	return "Killed"
