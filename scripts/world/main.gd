extends Node3D
## Solo (single-player) world entry. Builds the shared Mos Eisley settlement via
## WorldBuilder, then layers the single-player blaster range, controllers, HUD, and
## overlays on top. The networked world (scripts/net/net_world.gd) reuses the same
## WorldBuilder so geometry is authored once.

const PlayerController = preload("res://scripts/player/player_controller.gd")
const ModalOverlayModel = preload("res://scripts/rules/modal_overlay_model.gd")
const BlasterRange = preload("res://scripts/world/blaster_range.gd")
const InspectController = preload("res://scripts/world/inspect_controller.gd")
const SpaceMapOverlay = preload("res://scripts/world/space_map_overlay.gd")
const CharacterSheetOverlay = preload("res://scripts/world/character_sheet_overlay.gd")
const DialogueOverlay = preload("res://scripts/world/dialogue_overlay.gd")
const MovingTargetController = preload("res://scripts/world/moving_target_controller.gd")
const WorldBuilder = preload("res://scripts/world/world_builder.gd")
const MonsterBuilder = preload("res://scripts/world/monster_builder.gd")
const NpcBuilder = preload("res://scripts/world/npc_builder.gd")
const UnifiedHUD = preload("res://scripts/world/unified_hud.gd")
const LandmarkBuilder = preload("res://scripts/world/landmark_builder.gd")
const CombatBarricade = preload("res://assets/3d/generated/google/buildings/combat_barricade.tscn")
const DesertDoorway = preload("res://assets/3d/generated/google/buildings/desert_doorway.tscn")


var _builder: WorldBuilder
var _hud: CanvasLayer
var _ground_layer_visible_before_modal := {}


func _ready() -> void:
	_builder = WorldBuilder.new()
	_builder.build_lighting(self)
	_builder.build_ground(self)
	_builder.build_settlement(self)
	LandmarkBuilder.new().build_cantina_plaza(self, Vector3(65.0, 0.0, 0.0), 1138)
	_spawn_solo_npcs()
	_spawn_wildlife()
	if OS.get_cmdline_args().has("--asset-gallery"):
		_builder.build_asset_library(self)


	_build_blaster_range()
	_build_player()
	_build_hud()
	_build_range_controller()
	_build_moving_target_controller()
	_build_inspection_controller()
	_build_space_map_overlay()
	_build_character_sheet_overlay()
	_build_dialogue_overlay()


func _process(_delta: float) -> void:
	_sync_ground_gameplay_layers()

func _build_player() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerController)
	player.position = Vector3(-20, 1.2, -4.0)

	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.55
	player.add_child(head)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 74
	camera.current = true
	head.add_child(camera)

	add_child(player)

func _build_hud() -> void:
	_hud = UnifiedHUD.new()
	_hud.name = "HUD"
	_hud.add_to_group("ground_gameplay_layer")
	add_child(_hud)
	_add_crosshair(_hud)

func _build_range_controller() -> void:
	var controller := Node.new()
	controller.name = "BlasterRangeController"
	controller.set_script(BlasterRange)
	controller.result_label = _hud._log_label
	controller.status_label = _hud._log_label
	controller.telemetry_label = _hud._telemetry_label
	add_child(controller)

func _build_inspection_controller() -> void:
	var controller := Node.new()
	controller.name = "InspectController"
	controller.set_script(InspectController)
	controller.result_label = _hud._log_label
	add_child(controller)


func _build_space_map_overlay() -> void:
	var overlay := SpaceMapOverlay.new()
	overlay.name = "SpaceMapOverlay"
	add_child(overlay)

func _build_character_sheet_overlay() -> void:
	var overlay := CharacterSheetOverlay.new()
	overlay.name = "CharacterSheetOverlay"
	add_child(overlay)

func _add_crosshair(layer: CanvasLayer) -> void:
	var horizontal := ColorRect.new()
	horizontal.position = Vector2(635, 359)
	horizontal.size = Vector2(10, 2)
	horizontal.color = Color(0.09, 0.08, 0.06, 0.75)
	layer.add_child(horizontal)

	var vertical := ColorRect.new()
	vertical.position = Vector2(639, 355)
	vertical.size = Vector2(2, 10)
	vertical.color = Color(0.09, 0.08, 0.06, 0.75)
	layer.add_child(vertical)

func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_recursive(child)

func _sync_ground_gameplay_layers() -> void:
	var modal_active := ModalOverlayModel.is_modal_overlay_active(get_tree())
	var should_show := ModalOverlayModel.should_show_ground_gameplay_layer(modal_active)
	for node in get_tree().get_nodes_in_group("ground_gameplay_layer"):
		if not node is CanvasLayer and not node is CanvasItem:
			continue
		var node_id := node.get_instance_id()
		if not should_show:
			if not _ground_layer_visible_before_modal.has(node_id):
				_ground_layer_visible_before_modal[node_id] = bool(node.visible)
			node.visible = false
		elif _ground_layer_visible_before_modal.has(node_id):
			node.visible = bool(_ground_layer_visible_before_modal[node_id])
			_ground_layer_visible_before_modal.erase(node_id)

func _build_blaster_range() -> void:
	_builder.add_box_to_world(self, Vector3(-20, 0.11, -18), Vector3(8, 0.08, 1.0), Color(0.34, 0.29, 0.22))
	_builder.add_box_to_world(self, Vector3(-20, 0.2, -11), Vector3(2.8, 0.18, 0.25), Color(0.83, 0.64, 0.18))
	_builder.add_box_to_world(self, Vector3(-20, 0.2, -23), Vector3(2.8, 0.18, 0.25), Color(0.83, 0.64, 0.18))
	_builder.add_box_to_world(self, Vector3(-20, 0.2, -39), Vector3(2.8, 0.18, 0.25), Color(0.83, 0.64, 0.18))

	_add_range_target(Vector3(-20, 1.1, -12), "B1 training silhouette - short", 0, "b1_training_silhouette", {}, {"fire_cadence_ticks": 1, "fire_phase_ticks": 0, "suppression_ticks": 1})
	_add_range_target(Vector3(-20, 1.1, -18), "B1 lateral remote - moving", 1, "b1_training_silhouette", {"axis": "x", "distance": 4.0, "speed": 1.6, "pattern": "sine"}, {"fire_cadence_ticks": 2, "fire_phase_ticks": 1, "suppression_ticks": 2, "pinning_ticks": 1, "pinning_miss_margin": 2, "fallback_ticks": 1, "fallback_on_wound_severity": 2, "reload_ticks": 1, "reload_cadence_ticks": 4, "reload_phase_ticks": 3, "morale_hold_ticks": 1, "morale_cadence_ticks": 3, "morale_phase_ticks": 2, "morale_min_wound_severity": 1, "covering_fire_ticks": 1, "covering_fire_cadence_ticks": 5, "covering_fire_phase_ticks": 4})
	_add_range_target(Vector3(-20, 1.1, -24), "B1 behind cargo - medium", 2, "b1_training_silhouette", {}, {"fire_cadence_ticks": 2, "fire_phase_ticks": 0, "suppression_ticks": 1, "pinning_ticks": 1, "pinning_miss_margin": 3, "peek_exposed_ticks": 1, "peek_covered_ticks": 1, "peek_phase_ticks": 0, "fallback_ticks": 2, "fallback_on_wound_severity": 2, "coordination_group": "bay_cover_pair", "coordination_priority": 1, "morale_hold_ticks": 1, "morale_cadence_ticks": 4, "morale_phase_ticks": 3, "morale_min_wound_severity": 1, "covering_fire_ticks": 1, "covering_fire_cadence_ticks": 4, "covering_fire_phase_ticks": 1})
	_add_range_target(Vector3(-20, 1.1, -40), "B1 behind bay wall - long", 3, "b1_training_silhouette", {}, {"fire_cadence_ticks": 3, "fire_phase_ticks": 2, "suppression_ticks": 1, "pinning_ticks": 1, "pinning_miss_margin": 3, "peek_exposed_ticks": 1, "peek_covered_ticks": 2, "peek_phase_ticks": 2, "fallback_ticks": 2, "fallback_on_wound_severity": 2, "coordination_group": "bay_cover_pair", "coordination_priority": 0, "flank_move_ticks": 1, "flank_cadence_ticks": 5, "flank_phase_ticks": 1, "reload_ticks": 1, "reload_cadence_ticks": 6, "reload_phase_ticks": 5, "covering_fire_ticks": 1, "covering_fire_cadence_ticks": 5, "covering_fire_phase_ticks": 4})
	_add_walker_armor_target(Vector3(-14, 1.55, -34), "Walker-scale moving armor plate", 0, {"axis": "x", "distance": 2.5, "speed": 0.75, "pattern": "patrol"})
	
	# Training barricades instead of random crate clutter
	var barricade_scene = null
	if ResourceLoader.exists("res://assets/3d/generated/google/buildings/combat_barricade.tscn"):
		barricade_scene = CombatBarricade
	
	if barricade_scene:
		var b1 = barricade_scene.instantiate()
		b1.position = Vector3(-20.7, 0.0, -24)
		add_child(b1)
		var b2 = barricade_scene.instantiate()
		b2.position = Vector3(-20.8, 0.0, -40)
		add_child(b2)
	else:
		_builder.add_box_to_world(self, Vector3(-20.7, 0.6, -24), Vector3(2.4, 1.2, 0.4), Color(0.4, 0.45, 0.5)) # Short barricade
		_builder.add_box_to_world(self, Vector3(-20.8, 0.9, -40), Vector3(2.4, 1.8, 0.4), Color(0.35, 0.4, 0.45)) # Tall barricade
	
	# Firing line stations
	if barricade_scene:
		var fb1 = barricade_scene.instantiate()
		fb1.position = Vector3(-18.5, 0.0, -7)
		add_child(fb1)
		var fb2 = barricade_scene.instantiate()
		fb2.position = Vector3(-21.5, 0.0, -7)
		add_child(fb2)
	else:
		_builder.add_box_to_world(self, Vector3(-18.5, 0.5, -7), Vector3(1.2, 1.0, 0.4), Color(0.32, 0.29, 0.24))
		_builder.add_box_to_world(self, Vector3(-21.5, 0.5, -7), Vector3(1.2, 1.0, 0.4), Color(0.32, 0.29, 0.24))

	# Exit/arrival landmark pointing toward the settlement
	var doorway_scene = null
	if ResourceLoader.exists("res://assets/3d/generated/google/buildings/desert_doorway.tscn"):
		doorway_scene = DesertDoorway
	
	if doorway_scene:
		var door1 = doorway_scene.instantiate()
		door1.position = Vector3(-20, 0.0, -2)
		door1.rotation_degrees = Vector3(0, 90, 0)
		door1.scale = Vector3(1.5, 1.5, 1.5)
		add_child(door1)
	else:
		_builder.add_box_to_world(self, Vector3(-20, 4.0, -2), Vector3(7.0, 0.6, 0.6), Color(0.7, 0.3, 0.2)) # Arch overhead
		_builder.add_box_to_world(self, Vector3(-23.2, 2.0, -2), Vector3(0.6, 4.0, 0.6), Color(0.3, 0.3, 0.3)) # Pillar L
		_builder.add_box_to_world(self, Vector3(-16.8, 2.0, -2), Vector3(0.6, 4.0, 0.6), Color(0.3, 0.3, 0.3)) # Pillar R

func _build_moving_target_controller() -> void:
	var controller := Node.new()
	controller.name = "MovingTargetController"
	controller.set_script(MovingTargetController)
	add_child(controller)

func _add_range_target(pos: Vector3, target_name: String, cover_level: int, target_profile: String = "b1_training_silhouette", motion: Dictionary = {}, behavior: Dictionary = {}) -> void:
	var body := StaticBody3D.new()
	body.name = target_name
	body.position = pos
	body.set_meta("combat_target", true)
	body.set_meta("target_name", target_name)
	body.set_meta("target_profile", target_profile)
	body.set_meta("cover_level", cover_level)
	body.set_meta("wound_severity", 0)
	body.add_to_group("range_targets")
	_apply_motion_metadata(body, pos, motion)
	_apply_behavior_metadata(body, behavior)
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 2.2, 0.35)
	collision.shape = shape
	body.add_child(collision)

	_builder.add_box(body, Vector3(0, -0.15, 0), Vector3(0.72, 1.45, 0.22), Color(0.63, 0.53, 0.38), "torso")
	_builder.add_box(body, Vector3(0, 0.82, 0), Vector3(0.46, 0.42, 0.22), Color(0.72, 0.63, 0.46), "head")
	_builder.add_box(body, Vector3(-0.52, -0.05, 0), Vector3(0.2, 1.1, 0.18), Color(0.57, 0.48, 0.35), "left_arm")
	_builder.add_box(body, Vector3(0.52, -0.05, 0), Vector3(0.2, 1.1, 0.18), Color(0.57, 0.48, 0.35), "right_arm")
	_builder.add_box(body, Vector3(0, -1.05, 0), Vector3(0.95, 0.2, 0.18), Color(0.18, 0.18, 0.16), "legs")

func _add_walker_armor_target(pos: Vector3, target_name: String, cover_level: int, motion: Dictionary = {}) -> void:
	var body := StaticBody3D.new()
	body.name = target_name
	body.position = pos
	body.set_meta("combat_target", true)
	body.set_meta("target_name", target_name)
	body.set_meta("target_profile", "walker_armor_plate")
	body.set_meta("cover_level", cover_level)
	body.set_meta("wound_severity", 0)
	body.add_to_group("range_targets")
	_apply_motion_metadata(body, pos, motion)
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 3.1, 0.55)
	collision.shape = shape
	body.add_child(collision)

	_builder.add_box(body, Vector3(0, 0, 0), Vector3(2.8, 3.1, 0.45), Color(0.18, 0.20, 0.20), "torso")
	_builder.add_box(body, Vector3(0, 0.9, -0.28), Vector3(2.2, 0.22, 0.18), Color(0.72, 0.54, 0.18), "head")
	_builder.add_box(body, Vector3(-1.08, -0.45, -0.3), Vector3(0.22, 1.6, 0.18), Color(0.15, 0.18, 0.18), "left_arm")
	_builder.add_box(body, Vector3(1.08, -0.45, -0.3), Vector3(0.22, 1.6, 0.18), Color(0.15, 0.18, 0.18), "right_arm")

func _apply_motion_metadata(body: Node3D, pos: Vector3, motion: Dictionary) -> void:
	if motion.is_empty():
		return
	body.add_to_group("moving_range_targets")
	body.set_meta("motion_origin", pos)
	body.set_meta("motion_axis", String(motion.get("axis", "x")))
	body.set_meta("motion_distance", float(motion.get("distance", 0.0)))
	body.set_meta("motion_speed", float(motion.get("speed", 0.0)))
	body.set_meta("motion_pattern", String(motion.get("pattern", "sine")))

func _apply_behavior_metadata(body: Node3D, behavior: Dictionary) -> void:
	if behavior.is_empty():
		return
	body.set_meta("fire_cadence_ticks", maxi(int(behavior.get("fire_cadence_ticks", 1)), 1))
	body.set_meta("fire_phase_ticks", int(behavior.get("fire_phase_ticks", 0)))
	body.set_meta("suppression_ticks", maxi(int(behavior.get("suppression_ticks", 0)), 0))
	body.set_meta("pinning_ticks", maxi(int(behavior.get("pinning_ticks", 0)), 0))
	body.set_meta("pinning_miss_margin", maxi(int(behavior.get("pinning_miss_margin", 0)), 0))
	body.set_meta("peek_exposed_ticks", maxi(int(behavior.get("peek_exposed_ticks", 0)), 0))
	body.set_meta("peek_covered_ticks", maxi(int(behavior.get("peek_covered_ticks", 0)), 0))
	body.set_meta("peek_phase_ticks", int(behavior.get("peek_phase_ticks", behavior.get("fire_phase_ticks", 0))))
	body.set_meta("fallback_ticks", maxi(int(behavior.get("fallback_ticks", 0)), 0))
	body.set_meta("fallback_on_wound_severity", maxi(int(behavior.get("fallback_on_wound_severity", 2)), 1))
	body.set_meta("coordination_group", String(behavior.get("coordination_group", "")))
	body.set_meta("coordination_priority", int(behavior.get("coordination_priority", 0)))
	body.set_meta("flank_move_ticks", maxi(int(behavior.get("flank_move_ticks", 0)), 0))
	body.set_meta("flank_cadence_ticks", maxi(int(behavior.get("flank_cadence_ticks", 0)), 0))
	body.set_meta("flank_phase_ticks", int(behavior.get("flank_phase_ticks", behavior.get("fire_phase_ticks", 0))))
	body.set_meta("reload_ticks", maxi(int(behavior.get("reload_ticks", 0)), 0))
	body.set_meta("reload_cadence_ticks", maxi(int(behavior.get("reload_cadence_ticks", 0)), 0))
	body.set_meta("reload_phase_ticks", int(behavior.get("reload_phase_ticks", behavior.get("fire_phase_ticks", 0))))
	body.set_meta("morale_hold_ticks", maxi(int(behavior.get("morale_hold_ticks", 0)), 0))
	body.set_meta("morale_cadence_ticks", maxi(int(behavior.get("morale_cadence_ticks", 0)), 0))
	body.set_meta("morale_phase_ticks", int(behavior.get("morale_phase_ticks", behavior.get("fire_phase_ticks", 0))))
	body.set_meta("morale_min_wound_severity", maxi(int(behavior.get("morale_min_wound_severity", 1)), 1))
	body.set_meta("covering_fire_ticks", maxi(int(behavior.get("covering_fire_ticks", 0)), 0))
	body.set_meta("covering_fire_cadence_ticks", maxi(int(behavior.get("covering_fire_cadence_ticks", 0)), 0))
	body.set_meta("covering_fire_phase_ticks", int(behavior.get("covering_fire_phase_ticks", behavior.get("fire_phase_ticks", 0))))

func _build_dialogue_overlay() -> void:
	var overlay := DialogueOverlay.new()
	overlay.name = "DialogueOverlay"
	add_child(overlay)

func _spawn_solo_npcs() -> void:
	var npcs := [
		{
			"pos": Vector3(-3.0, 0.0, 9.5),
			"npc_id": "ct2207_stamp",
			"name": "CT-2207 \"Stamp\"",
			"role": "Republic Customs Liaison",
			"kind": "official",
			"faction": "republic",
			"desc": "A clone trooper customs officer processing cargo manifests.",
			"dialogue": [
				"Republic Checkpoint. Manifest please, citizen.",
				"No flags. Welcome to Tatooine.",
				"Inspections are random and rare. The Hutts run the rest of the planet."
			]
		},
		{
			"pos": Vector3(-7.0, 0.0, -20.0),
			"npc_id": "lt_vesh_talon",
			"name": "Lt. Vesh Talon",
			"role": "Republic Traffic Officer",
			"kind": "official",
			"faction": "republic",
			"desc": "A Republic Navy lieutenant logging spaceport landings.",
			"dialogue": [
				"Mos Eisley Spaceport Control. Lieutenant Talon. Authorized?",
				"Two hundred movements a day. I log the manifests.",
				"Six months in, six to go. Then back to a Venator."
			]
		},
		{
			"pos": Vector3(-20.0, 0.0, -8.0),
			"npc_id": "venn_kator",
			"name": "Venn Kator",
			"role": "Starship Mechanic",
			"kind": "mechanic",
			"faction": "independent",
			"desc": "An oil-stained Corellian starship engineer.",
			"dialogue": [
				"You need something fixed, or you just here to watch?",
				"Corellian Engineering -- best in the galaxy.",
				"Need weapon repairs or new parts? I have standard catalog weapons for trade."
			]
		},
		{
			"pos": Vector3(9.0, 0.0, -15.0),
			"npc_id": "ruzz_tha",
			"name": "Ruzz-tha",
			"role": "Jawa Trade-Elder",
			"kind": "vendor",
			"faction": "independent",
			"desc": "A Jawa merchant in a dark hood with glowing yellow eyes.",
			"dialogue": [
				"M'ni toba! Looking for quality salvage or custom parts?",
				"I have scrap and gear directly from the sandcrawlers. Very reliable.",
				"Need a blaster or a thermal detonator? Let's trade."
			]
		},
		{
			"pos": Vector3(3.0, 0.0, 7.8),
			"npc_id": "greeshk",
			"name": "Greeshk",
			"role": "Hutt Cartel Guard",
			"kind": "thug",
			"faction": "hutt",
			"desc": "A bulkily armored Weequay cartel enforcer.",
			"dialogue": [
				"Jabba's business is Jabba's business. Keep walking, outlander.",
				"Draw a weapon in Jabba's streets and see what happens."
			]
		},
		{
			"pos": Vector3(36.0, 0.0, 38.0),
			"npc_id": "djas_puhr",
			"name": "Djas Puhr",
			"role": "Abyssinian Bounty Hunter",
			"kind": "hunter",
			"faction": "bounty_hunters_guild",
			"desc": "A green-skinned Abyssinian with a single glowing central red eye.",
			"dialogue": [
				"Looking for a bounty? Or are you the bounty?",
				"The Guild has strict rules on Tatooine. Respect them."
			]
		},
		{
			"pos": Vector3(65.0, 0.0, 1.0),
			"npc_id": "wuher",
			"name": "Wuher",
			"role": "Cantina Bartender",
			"kind": "civilian",
			"faction": "independent",
			"desc": "A dour, sour-faced bartender wiping down the glasses behind the counter.",
			"dialogue": [
				"We don't serve their kind here! Your droids, they'll have to wait outside.",
				"Keep it orderly, or you're out. I don't need no trouble with the local guards."
			]
		},
		{
			"pos": Vector3(65.0 + 3.2, 0.0, -1.6),
			"npc_id": "chalmun",
			"name": "Chalmun",
			"role": "Cantina Proprietor",
			"kind": "civilian",
			"faction": "independent",
			"desc": "The imposing, grey-furred Wookiee proprietor of the establishment.",
			"dialogue": [
				"*Low, rumbling Wookiee growl*",
				"Welcome to the cantina, friend. Keep your blasters holstered.",
				"Business is good, but the taxes Jabba demands get steeper every season."
			]
		},
		{
			"pos": Vector3(65.0 - 5.0, 0.0, -15.0),
			"npc_id": "figrin_dan",
			"name": "Figrin D'an",
			"role": "Bith Holo-Musician",
			"kind": "civilian",
			"faction": "independent",
			"desc": "The front-man of the Modal Nodes, checking his Kloo horn valves and muttering about booking rates.",
			"dialogue": [
				"Play it again? We play the same tune all night. The crowd expects it.",
				"Bookings are slim in the Outer Rim. Still better than performing on a Republic cruiser."
			]
		},
		{
			"pos": Vector3(62.5, 0.0, -1.0),
			"npc_id": "kabe",
			"name": "Kabe",
			"role": "Chadra-Fan Scavenger",
			"kind": "civilian",
			"faction": "independent",
			"desc": "A small, bat-eared Chadra-Fan nursing a cup of spotchka, looking for open pockets or dropped credits.",
			"dialogue": [
				"You buying the next round? Spotchka is pricey today.",
				"Watch your pockets, stranger. The cantina has quick fingers."
			]
		},
		{
			"pos": Vector3(72.0, 0.0, 7.0),
			"npc_id": "momaw_nadon",
			"name": "Momaw Nadon",
			"role": "Ithorian exile and botanist",
			"kind": "civilian",
			"faction": "independent",
			"desc": "A tall, slow-speaking Ithorian exile sitting quietly in the booth recesses, nursing his drink.",
			"dialogue": [
				"Peace be with you. The desert is quiet, but the town is loud.",
				"I miss the forests of Ithor. Here, only the weeds survive."
			]
		},
		{
			"pos": Vector3(75.0, 0.0, -12.0),
			"npc_id": "clone_trooper_patrol",
			"name": "CT-5532",
			"role": "Off-duty Clone Trooper",
			"kind": "official",
			"faction": "republic",
			"desc": "An off-duty Republic Clone Trooper with his helmet under his arm, looking tired.",
			"dialogue": [
				"The Outer Rim sieges are taking a toll. Even clones need a drink.",
				"Keep your nose clean, citizen. We're here to keep the peace, not start a war."
			]
		},
		{
			"pos": Vector3(55.0, 0.0, 15.0),
			"npc_id": "separatist_spy",
			"name": "Neimoidian Contact",
			"role": "CIS Information Broker",
			"kind": "broker",
			"faction": "cis",
			"desc": "A nervous Neimoidian constantly checking his datapad and glancing at the door.",
			"dialogue": [
				"I am waiting for someone. Leave me be.",
				"The Trade Federation offers very generous rates... if you know the right people."
			]
		},
		{
			"pos": Vector3(80.0, 0.0, 8.0),
			"npc_id": "booth_smuggler",
			"name": "Ketsu",
			"role": "Independent Smuggler",
			"kind": "pilot",
			"faction": "independent",
			"desc": "A seasoned spacer in worn flight gear with a heavy blaster strapped to her thigh.",
			"dialogue": [
				"I can make the Kessel Run, but right now I'm just making time.",
				"Republic or Separatist, their credits all spend the same."
			]
		},
		{
			"pos": Vector3(52.0, 0.0, -10.0),
			"npc_id": "weequay_guard",
			"name": "Ak-rev",
			"role": "Hutt Cartel Guard",
			"kind": "thug",
			"faction": "hutt",
			"desc": "A heavily scarred Weequay guard keeping a close eye on the Cantina's back rooms.",
			"dialogue": [
				"The Hutts run this world. The Republic just pretends to.",
				"Step back. This area is for Cartel associates only."
			]
		},
		{
			"pos": Vector3(65.0, 0.0, 12.0),
			"npc_id": "devaronian_trader",
			"name": "Vilmarh",
			"role": "Devaronian Hustler",
			"kind": "vendor",
			"faction": "independent",
			"desc": "A red-skinned Devaronian with a wide grin and a coat full of questionable goods.",
			"dialogue": [
				"Looking for blaster parts? Maybe some death sticks? I have everything you need!",
				"My prices are the best in Mos Eisley, guaranteed!"
			]
		},
		{
			"pos": Vector3(60.0, 0.0, 5.0),
			"npc_id": "bith_patron",
			"name": "Lirin",
			"role": "Cantina Patron",
			"kind": "civilian",
			"faction": "independent",
			"desc": "A Bith patron nodding along to the music, occasionally taking a sip of his drink.",
			"dialogue": [
				"Ah, the Modal Nodes are playing my favorite tune.",
				"It's good to relax after a long rotation in the spaceport."
			]
		}



	]


	for npc in npcs:
		_spawn_solo_npc(
			npc["pos"], npc["npc_id"], npc["name"], npc["role"],
			npc["kind"], npc["faction"], npc["desc"], npc["dialogue"]
		)

func _spawn_solo_npc(pos: Vector3, npc_id: String, display_name: String, role: String, kind: String, faction_axis: String, desc: String, dialogue: Array) -> void:
	var npc_builder = NpcBuilder.new()
	var visual: Node3D = npc_builder.build_npc(kind, display_name, faction_axis)
	
	var body := StaticBody3D.new()
	body.name = "NPC_" + npc_id
	body.position = pos
	add_child(body)
	
	# Add visual
	body.add_child(visual)
	
	# Add collision shape
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	body.add_child(collision)
	
	# Add metadata for Dialogue Overlay
	body.set_meta("npc_id", npc_id)
	body.set_meta("title", display_name)
	body.set_meta("npc_role", role)
	body.set_meta("description", desc)
	body.set_meta("dialogue_lines", dialogue)

func _spawn_wildlife() -> void:
	var beasts := [
		{"pos": Vector3(-38.0, 0.0, -38.0), "name": "Wild Bantha", "profile": "bantha_target"},
		{"pos": Vector3(38.0, 0.0, -38.0), "name": "Wild Dewback", "profile": "dewback_target"},
		{"pos": Vector3(-38.0, 0.0, 38.0), "name": "Wild Womp Rat", "profile": "womp_rat_target"}
	]
	
	for beast in beasts:
		_spawn_wildlife_target(beast["pos"], beast["name"], beast["profile"])

func _spawn_wildlife_target(pos: Vector3, target_name: String, target_profile: String) -> void:
	var body := StaticBody3D.new()
	body.name = target_name
	body.position = pos
	body.set_meta("combat_target", true)
	body.set_meta("target_name", target_name)
	body.set_meta("target_profile", target_profile)
	body.set_meta("cover_level", 0)
	body.set_meta("wound_severity", 0)
	body.add_to_group("range_targets")
	body.add_to_group("wildlife_targets")
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var size_val := Vector3(1.2, 1.2, 1.2)
	if target_profile == "womp_rat_target":
		size_val = Vector3(0.6, 0.6, 0.6)
	elif target_profile == "bantha_target" or target_profile == "dewback_target":
		size_val = Vector3(2.5, 2.5, 2.5)
	shape.size = size_val
	collision.shape = shape
	collision.position.y = size_val.y * 0.5
	body.add_child(collision)

	# Build monster/beast visual
	var mb = MonsterBuilder.new()
	var visual = mb.build_target("monster", target_name)
	body.add_child(visual)



