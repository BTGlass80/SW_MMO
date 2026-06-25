extends SceneTree

const COMBATANT_DATA_PATH = "res://data/prototype_combatants.json"
const CHARACTER_DATA_PATH = "res://data/prototype_characters.json"
const SKILL_CATALOG_PATH = "res://data/prototype_skill_catalog.json"
const SPACEPORT_ROW_DATA_PATH = "res://data/mos_eisley_spaceport_row.json"
const SPACE_TACTICAL_DATA_PATH = "res://data/space_tactical_slice.json"
const SpaceStatusModel = preload("res://scripts/rules/space_status_model.gd")
const SpaceTacticalModel = preload("res://scripts/rules/space_tactical_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	_assert_true(FileAccess.file_exists(COMBATANT_DATA_PATH), "combatant data file exists")
	_assert_true(FileAccess.file_exists(CHARACTER_DATA_PATH), "character data file exists")
	_assert_true(FileAccess.file_exists(SKILL_CATALOG_PATH), "skill catalog file exists")
	_assert_true(FileAccess.file_exists(SPACEPORT_ROW_DATA_PATH), "spaceport row data file exists")
	_assert_true(FileAccess.file_exists(SPACE_TACTICAL_DATA_PATH), "space tactical data file exists")

	var file := FileAccess.open(COMBATANT_DATA_PATH, FileAccess.READ)
	if file == null:
		_failures.append("combatant data file opens")
		_finish()
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("combatant data parses as dictionary")
		_finish()
		return

	var data: Dictionary = parsed
	var trainee: Dictionary = data.get("range_trainee", {})
	var weapons: Dictionary = data.get("weapons", {})
	var armors: Dictionary = data.get("armors", {})
	var targets: Dictionary = data.get("targets", {})
	var weapon_key := String(trainee.get("weapon", ""))
	var armor_key := String(trainee.get("armor", ""))
	var weapon: Dictionary = weapons.get(weapon_key, {})
	var armor: Dictionary = armors.get(armor_key, {})
	var target: Dictionary = targets.get("b1_training_silhouette", {})
	var walker_target: Dictionary = targets.get("walker_armor_plate", {})

	_assert_equal(trainee.get("blaster", ""), "4D+1", "range trainee blaster pool")
	_assert_equal(trainee.get("dodge", ""), "4D", "range trainee dodge pool")
	_assert_equal(trainee.get("soak", ""), "3D", "range trainee soak pool")
	_assert_equal(trainee.get("character_points", 0), 5, "range trainee character points")
	_assert_equal(trainee.get("force_points", 0), 1, "range trainee force points")
	_assert_equal(weapon.get("damage", ""), "4D", "training blaster damage")
	_assert_equal(weapons.get("remote_stun_blaster", {}).get("damage", ""), "3D+2", "remote stun blaster damage")
	_assert_equal(armor.get("protection_energy", ""), "0D+1", "training armor energy protection")
	_assert_equal(armor.get("coverage", []), ["torso"], "training armor is torso coverage")
	_assert_equal(armors.has("heavy_battle_armor"), true, "heavy armor prototype entry")
	_assert_equal(target.get("blaster", ""), "3D", "B1 silhouette blaster pool")
	_assert_equal(target.get("weapon", ""), "remote_stun_blaster", "B1 silhouette return-fire weapon")
	_assert_equal(target.get("soak", ""), "2D", "B1 silhouette soak")
	_assert_equal(walker_target.get("scale", ""), "walker", "walker armor target scale")
	_assert_equal(walker_target.get("soak", ""), "4D", "walker armor target soak")

	var character_data := _load_json_or_finish(CHARACTER_DATA_PATH, "character data")
	var skill_catalog := _load_json_or_finish(SKILL_CATALOG_PATH, "skill catalog")
	if character_data.is_empty() or skill_catalog.is_empty():
		return
	var range_sheet: Dictionary = character_data.get("characters", {}).get("range_trainee", {})
	var skills: Dictionary = skill_catalog.get("skills", {})
	_assert_equal(range_sheet.get("skill_bonuses", {}).get("blaster", ""), "1D+1", "range trainee blaster skill bonus")
	_assert_equal(skills.get("blaster", {}).get("attribute", ""), "dexterity", "skill catalog blaster attribute")
	_assert_equal(skills.get("sensors", {}).get("attribute", ""), "mechanical", "skill catalog sensors attribute")

	var spaceport_file := FileAccess.open(SPACEPORT_ROW_DATA_PATH, FileAccess.READ)
	if spaceport_file == null:
		_failures.append("spaceport row data file opens")
		_finish()
		return

	var spaceport_parsed: Variant = JSON.parse_string(spaceport_file.get_as_text())
	if typeof(spaceport_parsed) != TYPE_DICTIONARY:
		_failures.append("spaceport row data parses as dictionary")
		_finish()
		return

	var spaceport_data: Dictionary = spaceport_parsed
	var source: Dictionary = spaceport_data.get("source", {})
	var rooms: Array = spaceport_data.get("rooms", [])
	var exits: Array = spaceport_data.get("exits", [])
	_assert_equal(spaceport_data.get("area_key", ""), "tatooine.mos_eisley.spaceport_row", "spaceport row area key")
	_assert_equal(source.get("source_policy", "").contains("SW_MUSH remains read-only"), true, "spaceport data source policy")
	_assert_equal(rooms.size(), 9, "curated spaceport room count")
	_assert_equal(exits.size(), 8, "curated spaceport exit count")

	var bay_94 := _room_by_slug(rooms, "docking_bay_94_entrance")
	var tower := _room_by_slug(rooms, "mos_eisley_control_tower")
	_assert_equal(bay_94.get("name", ""), "Docking Bay 94 - Entrance", "Bay 94 curated room name")
	_assert_equal(bay_94.get("map_position", {}).get("x", 0.0), 5.17, "Bay 94 map x")
	_assert_equal(tower.get("style", ""), "civic", "tower style")

	var space_file := FileAccess.open(SPACE_TACTICAL_DATA_PATH, FileAccess.READ)
	if space_file == null:
		_failures.append("space tactical data file opens")
		_finish()
		return

	var space_parsed: Variant = JSON.parse_string(space_file.get_as_text())
	if typeof(space_parsed) != TYPE_DICTIONARY:
		_failures.append("space tactical data parses as dictionary")
		_finish()
		return

	var space_data: Dictionary = space_parsed
	var contacts: Array = space_data.get("contacts", [])
	var range_bands: Array = space_data.get("range_bands", [])
	var stations: Array = space_data.get("stations", [])
	var player_ship: Dictionary = space_data.get("player_ship", {})
	var gunnery_drill: Dictionary = space_data.get("gunnery_drill", {})
	_assert_equal(space_data.get("area_key", ""), "tatooine.mos_eisley.approach", "space tactical area key")
	_assert_equal(contacts.size(), 5, "space tactical contact count")
	_assert_equal(range_bands.size(), 4, "space tactical range band count")
	_assert_equal(stations.has("pilot"), true, "space tactical pilot station")
	_assert_equal(stations.has("sensors"), true, "space tactical sensors station")
	_assert_equal(stations.has("commander"), true, "space tactical commander station")
	_assert_equal(stations.has("communications"), true, "space tactical communications station")
	_assert_equal(_contact_by_id(contacts, "sensor_shadow").get("hidden_until_revealed", false), true, "sensor shadow starts hidden")
	_assert_equal(_contact_by_id(contacts, "sensor_shadow").get("counterfire", false), true, "sensor shadow can counterfire")
	_assert_equal(_contact_by_id(contacts, "sensor_shadow").get("counterfire_requires_solution", false), true, "sensor shadow requires ready solution before counterfire")
	_assert_equal(_contact_by_id(contacts, "sensor_shadow").get("movement", {}).get("track_target", ""), "player", "sensor shadow tracks player ship")
	_assert_equal(_contact_by_id(contacts, "sensor_shadow").get("movement", {}).get("hold_range", 0), 80, "sensor shadow holds at short engagement range")
	_assert_equal(_contact_by_id(contacts, "sensor_shadow").get("movement", {}).get("lock_rounds_to_fire", 0), 2, "sensor shadow has two-round weapon solution clock")
	_assert_equal(_contact_by_id(contacts, "sensor_shadow").get("transponder", {}).get("threat", ""), "hostile", "sensor shadow has hostile identification profile")
	var hutt_courier: Dictionary = _contact_by_id(contacts, "hutt_courier")
	var hutt_condition: Dictionary = hutt_courier.get("condition", {})
	_assert_equal(hutt_condition.get("repairable_systems", []).has("cargo lift"), true, "hutt courier has custom cargo repair target")
	_assert_equal(hutt_condition.get("repair_difficulties", {}).get("cargo_lift", ""), "very difficult", "hutt courier cargo repair difficulty is data-driven")
	_assert_equal(
		SpaceStatusModel.selected_contact_repair_label(hutt_courier),
		"Repair: cargo_lift (Very Difficult), sensor_mast (Difficult)",
		"hutt courier selected repair label shows data-driven difficulties"
	)
	_assert_equal(_contact_by_id(contacts, "republic_customs_ping").get("movement", {}).has("move_units"), true, "space tactical patrol has movement profile")
	_assert_equal(player_ship.get("scale", ""), "starfighter", "space tactical player ship scale")
	_assert_equal(player_ship.get("navigator_pool", ""), "4D", "space tactical player ship has navigator pool")
	_assert_equal(player_ship.get("communications_pool", ""), "4D", "space tactical player ship has communications pool")
	_assert_equal(_crew_station_names(player_ship.get("crew", [])).has("commander"), true, "space tactical player ship has commander crew station")
	_assert_equal(gunnery_drill.get("default_target_id", ""), "sensor_shadow", "space tactical default gunnery target")
	_assert_equal(gunnery_drill.get("station_assist_action", {}).get("target_action", ""), "maneuver", "space tactical station assist targets maneuver")
	_assert_equal(gunnery_drill.get("station_assist_actions", []).size(), 8, "space tactical has rotating station assist actions")
	_assert_equal(_assist_targets(gunnery_drill.get("station_assist_actions", [])).has("targeting_solution"), true, "station assist actions include commander targeting coordination")
	_assert_equal(_assist_targets(gunnery_drill.get("station_assist_actions", [])).has("gunnery"), true, "station assist actions include gunnery")
	_assert_equal(_assist_targets(gunnery_drill.get("station_assist_actions", [])).has("repair"), true, "station assist actions include repair")
	_assert_equal(_assist_targets(gunnery_drill.get("station_assist_actions", [])).has("astrogation"), true, "station assist actions include astrogation")
	_assert_equal(_assist_targets(gunnery_drill.get("station_assist_actions", [])).has("communications"), true, "station assist actions include communications")
	_assert_equal(gunnery_drill.get("astrogation_action", {}).get("difficulty", 0), 15, "space tactical astrogation action difficulty")
	_assert_equal(gunnery_drill.get("identification_action", {}).get("difficulty", 0), 15, "space tactical identification action difficulty")
	_assert_equal(gunnery_drill.get("comms_hail_action", {}).get("difficulty", 0), 10, "space tactical comms hail action difficulty")
	_assert_equal(gunnery_drill.get("comms_hail_action", {}).get("delay_weapon_solution_on_success", false), true, "space tactical comms can delay weapon solution")
	_assert_equal(gunnery_drill.get("comms_hail_action", {}).get("weapon_solution_delay_rounds", 0), 1, "space tactical comms delay is one round")
	_assert_equal(gunnery_drill.get("comms_hail_action", {}).get("advance_weapon_solution_on_failure", false), true, "space tactical failed comms can pressure weapon solution")
	_assert_equal(gunnery_drill.get("comms_hail_action", {}).get("weapon_solution_pressure_rounds", 0), 1, "space tactical failed comms pressure is one round")
	_assert_equal(gunnery_drill.get("maneuver_action", {}).get("hazards", []).size(), 2, "space tactical maneuver has approach hazards")
	_assert_equal(gunnery_drill.get("maneuver_action", {}).get("break_weapon_solutions", false), true, "space tactical maneuver can break weapon solutions")
	var route_preview := SpaceTacticalModel.new().maneuver_route_preview(player_ship, gunnery_drill.get("maneuver_action", {}))
	_assert_equal(route_preview["hazard_context"]["crossed"].size(), 2, "space tactical route preview crosses both approach hazards")
	_assert_equal(route_preview["hazard_context"]["difficulty_modifier"], 10, "space tactical route preview sums hazard difficulty")
	_assert_equal(route_preview["hazard_context"]["collision_possible"], true, "space tactical route preview preserves collision risk from debris")
	_assert_equal(route_preview["difficulty"], 25, "space tactical route preview includes both hazard modifiers")

	_finish()

func _room_by_slug(rooms: Array, slug: String) -> Dictionary:
	for room in rooms:
		if typeof(room) == TYPE_DICTIONARY and String(room.get("slug", "")) == slug:
			return room
	return {}

func _contact_by_id(contacts: Array, contact_id: String) -> Dictionary:
	for contact in contacts:
		if typeof(contact) == TYPE_DICTIONARY and String(contact.get("id", "")) == contact_id:
			return contact
	return {}

func _assist_targets(actions: Array) -> Array:
	var targets: Array = []
	for action in actions:
		if typeof(action) == TYPE_DICTIONARY:
			targets.append(String(action.get("target_action", "")))
	return targets

func _crew_station_names(crew: Array) -> Array:
	var stations: Array = []
	for member in crew:
		if typeof(member) == TYPE_DICTIONARY:
			stations.append(String(member.get("station", "")))
	return stations

func _load_json_or_finish(path: String, label: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("%s file opens" % label)
		_finish()
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("%s parses as dictionary" % label)
		_finish()
		return {}
	return parsed

func _finish() -> void:
	if _failures.is_empty():
		print("data_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
