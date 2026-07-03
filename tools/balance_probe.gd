extends SceneTree
## balance_probe.gd — Monte Carlo the LIVE combat path (arena → ground_combat → d6_rules)
## for a quickstart human vs real hostile creatures. Reports per-exchange incoming-wound
## distributions, campaign time-to-death under (a) the LIVE maxi() accumulation and
## (b) the unwired WoundLadder.escalate() model, player kill rates, and loot economics.
## Run: godot --headless --path . --script res://tools/balance_probe.gd
## Deterministic (seeded); no live files touched.

const CombatArena := preload("res://scripts/net/combat_arena.gd")
const HostileNpc := preload("res://scripts/rules/hostile_npc_model.gd")
const Chargen := preload("res://scripts/rules/chargen_model.gd")
const Ladder := preload("res://scripts/rules/wound_ladder_model.gd")
const EconomyModel := preload("res://scripts/rules/economy_model.gd")

const IID_WINDOWS := 2000       # per creature/profile: fresh-state exchanges for the severity histogram
const CAMPAIGNS := 300          # campaigns per creature/profile/model
const CAMPAIGN_CAP := 400       # max windows per campaign before declaring "survived"
const KILL_BATCH := 400         # windows for player-offense (windows-per-creature-kill)
const LOOT_SAMPLES := 4000
const HOSTILE_DISTANCE := 10.0  # mirrors network_manager
const WINDOW_SECONDS := 5.0     # live action-window length

var rules: Object

func _init() -> void:
	rules = load("res://scripts/rules/d6_rules.gd").new()
	var combat_data := _json("res://data/prototype_combatants.json")
	var weapons: Dictionary = _json("res://data/weapons_clone_wars.json").get("weapons", {})
	var armors: Dictionary = _json("res://data/armor_clone_wars.json").get("armor", {})
	var species: Dictionary = _json("res://data/species_clone_wars.json")
	var human: Dictionary = _species(species, "human")
	var creatures: Dictionary = _json("res://data/creatures_clone_wars.json").get("creatures", {})

	var sheet: Dictionary = Chargen.default_sheet(rules, human)
	print("== quickstart human sheet ==")
	print("  attrs: ", sheet.get("attributes", {}))
	print("  skills: ", sheet.get("skills", {}))
	print("  equipment: ", sheet.get("equipment", {}))

	var arena := CombatArena.new(rules, combat_data, "b1_training_silhouette", weapons, armors)
	arena.register_player(1, "Probe", sheet)
	print("  attack pool: %s | damage: %s | perception: %s" % [
		arena.attacker_pool_text(1), arena.damage_pool_text(1), arena.perception_pool_text(1)])

	var roster := ["hitcher_crab", "tusken_warrior", "acklay", "merdeth", "glim_worm", "spor_crawler"]
	var profiles := {
		"green":    {"aim": 0, "cover": 0, "dodge": false},
		"tactical": {"aim": 2, "cover": 2, "dodge": true},
	}

	print("\n== resolved hostile pools (data-quality check) ==")
	for key in roster:
		var spawn := _spawn(creatures, key)
		if spawn.is_empty():
			print("  %s: NOT FOUND" % key)
			continue
		var pools: Dictionary = HostileNpc.attack_pools_from_creature(rules, spawn)
		print("  %-14s atk=%s dmg=%s soak=%s scale=%s" % [key,
			rules.pool_to_string(pools["target_attack_pool"]),
			rules.pool_to_string(pools["target_damage_pool"]),
			rules.pool_to_string(pools["target_soak_pool"]),
			String(pools["target_scale"])])

	var fight_roster := ["hitcher_crab", "tusken_warrior", "acklay", "merdeth"]
	for key in fight_roster:
		var spawn := _spawn(creatures, key)
		var pools: Dictionary = HostileNpc.attack_pools_from_creature(rules, spawn)
		print("\n===== %s =====" % key)
		for pname in profiles:
			var p: Dictionary = profiles[pname]
			var seed_base := hash(key + pname)
			# --- i.i.d. per-exchange incoming severity histogram (player reset healthy each window)
			var hist := [0, 0, 0, 0, 0, 0]
			var creature_hits := 0
			var player_hits := 0
			for i in range(IID_WINDOWS):
				_reset_player(arena, 0)
				_engage(arena, key, pools, spawn)
				var sev := _one_window(arena, seed_base + i * 13, p)
				hist[clampi(sev, 0, 5)] += 1
				if sev > 0:
					creature_hits += 1
				if arena.hostile_target_disabled(key):
					player_hits += 1
			var p_out := float(hist[3] + hist[4] + hist[5]) / IID_WINDOWS
			var p_dead := float(hist[5]) / IID_WINDOWS
			print("  [%s] incoming/window: none %.1f%% stun %.1f%% wound %.1f%% incap %.1f%% mortal %.1f%% kill %.1f%%" % [
				pname, 100.0 * hist[0] / IID_WINDOWS, 100.0 * hist[1] / IID_WINDOWS, 100.0 * hist[2] / IID_WINDOWS,
				100.0 * hist[3] / IID_WINDOWS, 100.0 * hist[4] / IID_WINDOWS, 100.0 * hist[5] / IID_WINDOWS])
			print("           P(single-hit out 3+)=%.2f%%  P(single-hit killed 5)=%.2f%%" % [100.0 * p_out, 100.0 * p_dead])
			# --- campaigns: LIVE maxi model vs escalate() model, with real wound-penalty feedback
			var live := _campaigns(arena, key, pools, spawn, seed_base + 900000, p, false)
			var esc := _campaigns(arena, key, pools, spawn, seed_base + 1800000, p, true)
			print("           LIVE(maxi):   died %d/%d  median windows-to-out %s (~%s)  terminal: %s" % [
				live["deaths"], CAMPAIGNS, _fmt(live["median"]), _mins(live["median"]), live["terminal"]])
			print("           ESCALATE():   died %d/%d  median windows-to-out %s (~%s)  terminal: %s" % [
				esc["deaths"], CAMPAIGNS, _fmt(esc["median"]), _mins(esc["median"]), esc["terminal"]])
		# --- player offense: windows per creature kill (green profile, stays healthy)
		var kills := 0
		var windows := 0
		for i in range(KILL_BATCH):
			_reset_player(arena, 0)
			if not arena.has_hostile_target(key):
				_engage(arena, key, pools, spawn)
			_one_window(arena, hash(key) + 5000000 + i * 17, profiles["green"])
			windows += 1
			if arena.hostile_target_disabled(key):
				kills += 1
				arena.remove_hostile_target(key)
		var wpk := float(windows) / maxf(kills, 1.0)
		# --- loot expectation
		var loot_total := 0
		for i in range(LOOT_SAMPLES):
			var l: Dictionary = EconomyModel.roll_loot(spawn, hash(key) + i)
			loot_total += int(l["credits"]) + int(l["salvage_credits"])
		var loot_mean := float(loot_total) / LOOT_SAMPLES
		var cr_min := loot_mean / wpk * (60.0 / WINDOW_SECONDS)
		print("  offense: %d kills / %d windows -> %.1f windows/kill | loot %.0f cr/kill -> ~%.0f cr/min farming" % [
			kills, windows, wpk, loot_mean, cr_min])

	print("\nbalance_probe: OK")
	quit(0)

func _one_window(arena: Object, seed_v: int, p: Dictionary) -> int:
	arena.submit_fire_intent(1, {"aim": int(p["aim"]), "cover": int(p["cover"]), "dodge": bool(p["dodge"])})
	var res: Dictionary = arena.resolve_window(seed_v)
	for env in res.get("envelopes", []):
		for ev in (env as Dictionary).get("events", []):
			if String((ev as Dictionary).get("type", "")) == "remote_return_fire":
				return _sev_for_key(String((ev as Dictionary).get("wound_key", "no_damage")))
	return 0

func _campaigns(arena: Object, key: String, pools: Dictionary, spawn: Dictionary, seed_v: int, p: Dictionary, use_escalate: bool) -> Dictionary:
	var deaths := 0
	var lengths: Array = []
	var terminal := {}
	for c in range(CAMPAIGNS):
		var level := "healthy"
		var sev := 0
		_reset_player(arena, 0)
		_engage(arena, key, pools, spawn)
		for w in range(CAMPAIGN_CAP):
			if not arena.has_hostile_target(key):
				_engage(arena, key, pools, spawn)  # Director respawn
			_reset_player(arena, sev)  # project tracked level onto the arena's severity int
			var rolled := _one_window(arena, seed_v + c * 100000 + w * 7, p)
			if arena.hostile_target_disabled(key):
				arena.remove_hostile_target(key)
			if use_escalate:
				level = Ladder.escalate(level, rolled)
				sev = _sev_for_level(level)
			else:
				sev = maxi(sev, rolled)
				level = _level_for_live_sev(sev)
			if sev >= 3:
				deaths += 1
				lengths.append(w + 1)
				terminal[level] = int(terminal.get(level, 0)) + 1
				break
	lengths.sort()
	var median: float = -1.0 if lengths.is_empty() else float(lengths[lengths.size() / 2])
	return {"deaths": deaths, "median": median, "terminal": terminal}

func _engage(arena: Object, key: String, pools: Dictionary, spawn: Dictionary) -> void:
	arena.register_hostile_target(key, pools, {"distance": HOSTILE_DISTANCE, "cover_level": 0, "name": key}, spawn)
	arena.set_player_target(1, key)
	arena.set_player_lethal(1, true)

func _reset_player(arena: Object, sev: int) -> void:
	arena.set_player_combat(1, {"player_wound_severity": sev, "player_character_points": 0, "player_force_points": 0, "player_armor_quality_pips": 0})

func _sev_for_key(k: String) -> int:
	match k:
		"stunned", "stunned_unconscious": return 1
		"wounded": return 2
		"incapacitated": return 3
		"mortally_wounded": return 4
		"killed": return 5
		_: return 0

func _sev_for_level(level: String) -> int:
	# Project a ladder level onto the arena severity int. wounded_twice has no int of its
	# own (the -2D penalty is INEXPRESSIBLE through the current severity plumbing — see the
	# P0-2 seam note); approximate with 2 (-1D), which slightly FLATTERS survival.
	match level:
		"healthy": return 0
		"stunned": return 1
		"wounded", "wounded_twice": return 2
		"incapacitated": return 3
		"mortally_wounded": return 4
		_: return 5

func _level_for_live_sev(sev: int) -> String:
	return Ladder.level_for_severity(sev)

func _spawn(creatures: Dictionary, key: String) -> Dictionary:
	var c: Dictionary = creatures.get(key, {})
	if c.is_empty():
		return {}
	return {"creature_key": key, "name": String(c.get("name", key)), "scale": String(c.get("scale", "creature")),
		"hostile": bool(c.get("hostile", true)), "pack_size": 1,
		"char_sheet": c.get("char_sheet", {}), "natural_attack": c.get("natural_attack", {})}

func _species(data: Dictionary, key: String) -> Dictionary:
	var s: Variant = data.get("species", data)
	if s is Dictionary and (s as Dictionary).has(key):
		return (s as Dictionary)[key]
	return {}

func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		return {}
	return j.data if typeof(j.data) == TYPE_DICTIONARY else {}

func _fmt(v: float) -> String:
	return "never" if v < 0.0 else str(int(v))

func _mins(v: float) -> String:
	return "-" if v < 0.0 else "%.1f min" % (v * WINDOW_SECONDS / 60.0)
