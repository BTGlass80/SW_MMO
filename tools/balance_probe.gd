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
const GroundCombatModel := preload("res://scripts/rules/ground_combat_model.gd")  # regime: direct soak-pool ladder
const CreatureSpawn := preload("res://scripts/rules/creature_spawn_model.gd")  # G15: tier banding + spawn mix

const IID_WINDOWS := 2000       # per creature/profile: fresh-state exchanges for the severity histogram
const CAMPAIGNS := 300          # campaigns per creature/profile/model
const CAMPAIGN_CAP := 400       # max windows per campaign before declaring "survived"
const REGIME_CAMPAIGNS := 150   # armor-condition regime: campaigns per cell (bounded runtime)
const REGIME_CAMPAIGN_CAP := 120  # armor-condition regime: window cap per campaign
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
	# Synthetic +3D-energy full-coverage TEST armor. The shipped catalog maxes at +2D energy, which the
	# -6 quality floor drives to 0 BEFORE the broken-halving runs -> no REAL armor leaves a positive
	# remnant for _apply_broken_pool_multiplier to act on. This synthetic armor (energy 9 pips) is the
	# only way to make the fix's HALVING gradient (full 6D > broken 3D+1 > bare 3D) observable in-path.
	armors["probe_energy_3d"] = {
		"name": "Probe Test Energy Armor (+3D, full)",
		"protection_energy": "+3D",
		"protection_physical": "+3D",
		"dexterity_penalty": "",
		"cost": 0,
		"vendor_stocked": false,
	}
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

	# G15 (DIV-0028): the NAMED acceptance instrument — full-roster lethality->tier table, per-tier
	# cr/min monotonicity, and a seeded 6k-roll spawn mix per alert band.
	_g15_acceptance(arena, creatures)

	# NEW (DIV-0026): sweep the broken-armor regime alongside the pristine probe above.
	_armor_condition_regime(arena, creatures, sheet, armors, profiles)

	if rules != null and is_instance_valid(rules):
		rules.free()   # d6_rules is a Node — free it so the tool leaks nothing at exit (no engine stderr)
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

func _campaigns(arena: Object, key: String, pools: Dictionary, spawn: Dictionary, seed_v: int, p: Dictionary, use_escalate: bool, quality_pips: int = 0, campaigns_n: int = CAMPAIGNS, cap: int = CAMPAIGN_CAP) -> Dictionary:
	var deaths := 0
	var lengths: Array = []
	var terminal := {}
	for c in range(campaigns_n):
		var level := "healthy"
		var sev := 0
		_reset_player(arena, 0, quality_pips)
		_engage(arena, key, pools, spawn)
		for w in range(cap):
			if not arena.has_hostile_target(key):
				_engage(arena, key, pools, spawn)  # Director respawn
			_reset_player(arena, sev, quality_pips)  # project tracked level + pinned armor condition
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

func _reset_player(arena: Object, sev: int, quality_pips: int = 0) -> void:
	arena.set_player_combat(1, {"player_wound_severity": sev, "player_character_points": 0, "player_force_points": 0, "player_armor_quality_pips": quality_pips})

# --- DIV-0026 broken-armor regime (added alongside the pristine probe; does not alter it) ---

# Swap peer 1's equipped armor to `armor_key` ("" = no armor / bare Strength), rebuilding its pools.
func _equip_variant(arena: Object, base_sheet: Dictionary, armor_key: String) -> void:
	var s := base_sheet.duplicate(true)
	var eq: Dictionary = (s.get("equipment", {}) as Dictionary).duplicate(true)
	eq["armor"] = armor_key
	s["equipment"] = eq
	arena.set_player_sheet(1, s)

# Fresh-state incoming-severity histogram at a PINNED armor-quality level (mirrors the main IID loop).
func _iid_probe(arena: Object, key: String, pools: Dictionary, spawn: Dictionary, p: Dictionary, quality_pips: int, seed_base: int) -> Dictionary:
	var hist := [0, 0, 0, 0, 0, 0]
	for i in range(IID_WINDOWS):
		_reset_player(arena, 0, quality_pips)
		_engage(arena, key, pools, spawn)
		var sev := _one_window(arena, seed_base + i * 13, p)
		hist[clampi(sev, 0, 5)] += 1
	return {"none": hist[0], "out": hist[3] + hist[4] + hist[5], "kill": hist[5]}

# Deterministic (no RNG) resolved-soak ladder: the EXACT pool live combat builds on a covered hit,
# pristine(0)/near-floor(-5)/broken(-6), via apply_armor_to_soak then _apply_broken_pool_multiplier.
func _soak_ladder(ground: Object, str_pool: Dictionary, armor: Dictionary, label: String) -> void:
	print("  %s" % label)
	print("    Str-only (no armor): %s" % rules.pool_to_string(str_pool))
	for pips in [0, -5, -6]:
		var armored: Dictionary = rules.apply_armor_to_soak(str_pool, armor, "energy", pips)
		var fixed: Dictionary = ground._apply_broken_pool_multiplier(rules, str_pool, armored, true, pips)
		var note := ""
		if pips == -6:
			var combined := int(armored.get("dice", 0)) * 3 + int(armored.get("pips", 0))
			var old_bug: Dictionary = rules.normalize_pool(0, int(float(combined) * 0.5))
			note = "   (OLD bug halved COMBINED -> %s, BELOW bare Str)" % rules.pool_to_string(old_bug)
		print("    quality %+d: armored=%-5s  FIXED soak=%-5s%s" % [
			pips, rules.pool_to_string(armored), rules.pool_to_string(fixed), note])

func _armor_condition_regime(arena: Object, creatures: Dictionary, base_sheet: Dictionary, armors: Dictionary, profiles: Dictionary) -> void:
	var ground := GroundCombatModel.new()
	print("\n################  ARMOR CONDITION REGIME  (DIV-0026 broken-pool fix)  ################")
	print("# Invariant: full-quality armor soaks MOST; broken(-6) soaks LESS than full but NEVER below")
	print("# bare Strength (no armor). Pip levels: pristine 0 / near-floor -5 (NOT broken) / broken -6.")
	print("# NOTE: the shipped armor catalog maxes at +2D energy, which the -6 quality penalty zeroes")
	print("#       BEFORE the broken-halving -> on real gear broken soak == bare (the fix's floor, not a")
	print("#       cliff below it). 'probe_energy_3d' (+3D) is synthetic so the HALVING gradient shows.")

	var str_pool: Dictionary = rules.parse_pool(String((base_sheet.get("attributes", {}) as Dictionary).get("strength", "3D")))
	print("\n-- (A) resolved SOAK pool on a COVERED hit (exact live-combat pipeline, deterministic) --")
	_soak_ladder(ground, str_pool, armors.get("probe_energy_3d", {}), "probe_energy_3d (+3D energy, full)  <- matches the fix's documented unit case")
	_soak_ladder(ground, str_pool, armors.get("blast_vest", {}), "blast_vest (+1D energy, torso only)  <- the REAL starter armor")

	var green: Dictionary = profiles.get("green", {"aim": 0, "cover": 0, "dodge": false})
	var variants := [
		["heavy+3D pristine(0)", "probe_energy_3d", 0],
		["heavy+3D near(-5)",    "probe_energy_3d", -5],
		["heavy+3D BROKEN(-6)",  "probe_energy_3d", -6],
		["blast+1D pristine(0)", "blast_vest",      0],
		["blast+1D near(-5)",    "blast_vest",      -5],
		["blast+1D BROKEN(-6)",  "blast_vest",      -6],
		["NO ARMOR (bare Str)",  "",                0],
	]
	print("\n-- (B) incoming severity per 5s window, green profile, %d windows/cell (higher out%% = dies faster) --" % IID_WINDOWS)
	for key in ["hitcher_crab", "tusken_warrior", "acklay"]:
		var spawn := _spawn(creatures, key)
		var pools: Dictionary = HostileNpc.attack_pools_from_creature(rules, spawn)
		print("  vs %-14s (creature dmg %s):" % [key, rules.pool_to_string(pools["target_damage_pool"])])
		for v in variants:
			_equip_variant(arena, base_sheet, String(v[1]))
			var r := _iid_probe(arena, key, pools, spawn, green, int(v[2]), hash(key + String(v[0])))
			print("    %-22s none %5.1f%%   out(3+) %6.2f%%   kill(5) %6.2f%%" % [
				String(v[0]), 100.0 * r["none"] / IID_WINDOWS, 100.0 * r["out"] / IID_WINDOWS, 100.0 * r["kill"] / IID_WINDOWS])

	print("\n-- (C) LIVE(maxi) campaign windows-to-out (TTK) vs tusken_warrior, %d campaigns cap %d --" % [REGIME_CAMPAIGNS, REGIME_CAMPAIGN_CAP])
	var tk := "tusken_warrior"
	var tspawn := _spawn(creatures, tk)
	var tpools: Dictionary = HostileNpc.attack_pools_from_creature(rules, tspawn)
	for v in variants:
		_equip_variant(arena, base_sheet, String(v[1]))
		var c := _campaigns(arena, tk, tpools, tspawn, hash(tk + String(v[0])) + 7000000, green, false, int(v[2]), REGIME_CAMPAIGNS, REGIME_CAMPAIGN_CAP)
		print("    %-22s died %3d/%d   median windows-to-out %-7s (~%s)" % [
			String(v[0]), c["deaths"], REGIME_CAMPAIGNS, _fmt(c["median"]), _mins(c["median"])])

# ---------------------------------------------------------------------------------------------------
# G15 (DIV-0028) ACCEPTANCE: measured-lethality tiers, cr/min monotonicity, per-alert spawn mix.
# ---------------------------------------------------------------------------------------------------

const G15_IID := 2000        # windows per creature for the P(out)/window measurement
const G15_KILL := 400        # windows per creature for the windows-per-kill measurement
const G15_MIX_ROLLS := 6000  # seeded spawn rolls per alert scenario

func _g15_acceptance(arena: Object, creatures: Dictionary) -> void:
	print("\n################  G15 ACCEPTANCE (DIV-0028): lethality-derived tiers + loot-by-tier  ################")
	print("# green quickstart profile (aim 0 / cover 0 / no dodge). Tier bands: t1<0.5%%  t2<3%%  t3<20%%  t4>=20%%")
	print("# boss(t5)>=~90%% or a named apex-legendary. HOSTILE creatures return fire (measured); NON-HOSTILE")
	print("# fauna are NEVER a lethal target in the live path (network_manager skips them) -> in-play P(out)=0.")

	var green := {"aim": 0, "cover": 0, "dodge": false}
	var keys: Array = creatures.keys()
	keys.sort()
	# per (data) tier: accumulate cr/min for the monotonicity summary (hostile creatures only).
	var tier_crmin := {1: [], 2: [], 3: [], 4: [], 5: []}
	print("\n-- (A) full-roster table: creature | scale | hostile | data_tier | measured_tier | P(out)/win | wpk | cr/min --")
	for key in keys:
		var c: Dictionary = creatures[key]
		var scale := String(c.get("scale", "creature"))
		var hostile := bool(c.get("hostile", false))
		var data_tier := int(c.get("threat_tier", 2))
		if not hostile:
			print("  %-20s %-9s hostile=false data_t%d  (non-hostile fauna — not a lethal target; in-play P(out)=0, cr/min=0)" % [key, scale, data_tier])
			continue
		var spawn := _spawn(creatures, key)
		var pools: Dictionary = HostileNpc.attack_pools_from_creature(rules, spawn)
		# P(out)/window
		var hist := [0, 0, 0, 0, 0, 0]
		var seed_base := hash(key + "g15")
		for i in range(G15_IID):
			_reset_player(arena, 0)
			_engage(arena, key, pools, spawn)
			hist[clampi(_one_window(arena, seed_base + i * 13, green), 0, 5)] += 1
		var p_out := 100.0 * float(hist[3] + hist[4] + hist[5]) / G15_IID
		# windows per kill
		var kills := 0
		var windows := 0
		for i in range(G15_KILL):
			_reset_player(arena, 0)
			if not arena.has_hostile_target(key):
				_engage(arena, key, pools, spawn)
			_one_window(arena, hash(key) + 6000000 + i * 17, green)
			windows += 1
			if arena.hostile_target_disabled(key):
				kills += 1
				arena.remove_hostile_target(key)
		if arena.has_hostile_target(key):
			arena.remove_hostile_target(key)
		var wpk := float(windows) / maxf(kills, 1.0)
		# loot expectation (exercises EconomyModel.roll_loot's tier multiplier via _spawn's threat_tier)
		var loot_total := 0
		for i in range(LOOT_SAMPLES):
			var l: Dictionary = EconomyModel.roll_loot(spawn, hash(key) + 20000 + i)
			loot_total += int(l["credits"]) + int(l["salvage_credits"])
		var loot_mean := float(loot_total) / LOOT_SAMPLES
		var cr_min := loot_mean / wpk * (60.0 / WINDOW_SECONDS)
		var meas := _g15_band(p_out)
		var flag := "" if meas == data_tier else "   <-- data_tier %d vs measured %d" % [data_tier, meas]
		tier_crmin[clampi(data_tier, 1, 5)].append(cr_min)
		print("  %-20s %-9s hostile=true  t%d          t%d           %6.2f%%    %6.2f   %7.1f%s" % [
			key, scale, data_tier, meas, p_out, wpk, cr_min, flag])

	print("\n-- (B) per-DATA-tier mean cr/min (must be MONOTONE NON-DECREASING across ambient tiers t1->t4) --")
	var prev := -1.0
	var monotone := true
	for t in [1, 2, 3, 4]:
		var arr: Array = tier_crmin[t]
		if arr.is_empty():
			print("    t%d: (no hostile creatures at this tier)" % t)
			continue
		var mean := 0.0
		for v in arr:
			mean += float(v)
		mean /= arr.size()
		if mean + 0.001 < prev:
			monotone = false
		print("    t%d: n=%d  mean cr/min = %.1f" % [t, arr.size(), mean])
		prev = mean
	var boss_arr: Array = tier_crmin[5]
	if not boss_arr.is_empty():
		var bmean := 0.0
		for v in boss_arr:
			bmean += float(v)
		bmean /= boss_arr.size()
		print("    t5(boss): n=%d  mean cr/min = %.1f  (event channel — outside the ambient monotone requirement)" % [boss_arr.size(), bmean])
	print("    => ambient cr/min monotone non-decreasing t1->t4: %s" % ("YES" if monotone else "NO -- FAILED"))

	_g15_spawn_mix(creatures)

func _g15_band(p_out: float) -> int:
	if p_out >= 90.0: return 5
	if p_out >= 20.0: return 4
	if p_out >= 3.0: return 3
	if p_out >= 0.5: return 2
	return 1

func _g15_spawn_mix(creatures: Dictionary) -> void:
	var model := CreatureSpawn.new()
	var data := {"creatures": creatures}
	print("\n-- (C) seeded %d-roll spawn mix per alert band (must show: no ambient P(out)>=20%% at DEFAULT," % G15_MIX_ROLLS)
	print("       and NO boss-class ambient at ANY alert) --")
	var scenarios := [
		["secured        (max t2)", "standard", "secured"],
		["lax/lawless     (max t2)", "lax", "lawless"],
		["standard/lawless DEFAULT (max t3)", "standard", "lawless"],
		["high_alert/lawless (max t4)", "high_alert", "lawless"],
		["lockdown/contested (max t4)", "lockdown", "contested"],
		["unknown 'calm'/lawless FAIL-SAFE (max t2)", "calm", "lawless"],
	]
	for sc in scenarios:
		var label := String(sc[0])
		var alert := String(sc[1])
		var security := String(sc[2])
		var counts := {}
		var max_tier := 0
		var boss_hits := 0
		# The unknown-alert fail-safe fires a push_warning per roll — keep that scenario's loop small so
		# the acceptance log isn't buried under thousands of identical warnings (the clamp still shows).
		var rolls := 50 if alert == "calm" else G15_MIX_ROLLS
		for s in range(rolls):
			var pick := String(model.roll_spawn(data, alert, security, s).get("creature_key", ""))
			if pick == "":
				continue
			counts[pick] = int(counts.get(pick, 0)) + 1
			var t := int((creatures.get(pick, {}) as Dictionary).get("threat_tier", 2))
			max_tier = maxi(max_tier, t)
			if model.is_boss(creatures.get(pick, {})):
				boss_hits += 1
		var mix_keys: Array = counts.keys()
		mix_keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
		print("\n  [%s]  alert=%s security=%s  rolls=%d  -> max tier seen: %d  boss ambient: %d" % [label, alert, security, rolls, max_tier, boss_hits])
		var line := ""
		for k in mix_keys:
			var t := int((creatures.get(k, {}) as Dictionary).get("threat_tier", 2))
			line += "%s(t%d):%.1f%%  " % [k, t, 100.0 * float(counts[k]) / rolls]
		print("     " + line)
	# model is a RefCounted — it auto-frees when this scope ends; nothing to free explicitly.

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
	# G15 (reviewer's one-line patch): carry threat_tier so EconomyModel.roll_loot's tier multiplier is
	# actually exercised in the probe (without it, every probed kill defaulted to the tier-2 x1.0 band).
	return {"creature_key": key, "name": String(c.get("name", key)), "scale": String(c.get("scale", "creature")),
		"hostile": bool(c.get("hostile", true)), "pack_size": 1, "threat_tier": int(c.get("threat_tier", 2)),
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
