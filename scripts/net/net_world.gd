extends Node3D
## Networked world entry point (the first shared-world slice).
##
## Reads cmdline user args (after `--`):
##   --server            run as a dedicated, headless, authoritative server
##   --connect <host>    run as a client connecting to <host> (default 127.0.0.1)
## With no args it defaults to a client connecting to 127.0.0.1 (handy in-editor).
##
## The server owns positions; this view only renders the authoritative snapshots
## and forwards the local player's input intent. Geometry here is intentionally
## a minimal shared ground for the netcode milestone; the full shared Mos Eisley
## (extracted from main.gd into a reusable world_builder) is the next slice.

const ChatModel := preload("res://scripts/net/chat_model.gd")
const MOUSE_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.55
const WorldBuilder := preload("res://scripts/world/world_builder.gd")
const MonsterBuilder := preload("res://scripts/world/monster_builder.gd")
const NpcBuilder := preload("res://scripts/world/npc_builder.gd")
const LandmarkBuilder := preload("res://scripts/world/landmark_builder.gd")  # signature Mos Eisley landmark
const DialogueModel := preload("res://scripts/rules/dialogue_model.gd")
const PlayerStatusBadgeModel := preload("res://scripts/rules/player_status_badge_model.gd")  # venom/restraint/wound status readout
const AmmoStatusModel := preload("res://scripts/rules/ammo_status_model.gd")  # DIV-0029: equipped-weapon ammo HUD readout + reload inference

const DialogueOverlay := preload("res://scripts/world/dialogue_overlay.gd")
const UnifiedHUD := preload("res://scripts/world/unified_hud.gd")
const SpaceMapOverlay := preload("res://scripts/world/space_map_overlay.gd")
const CraftingModel := preload("res://scripts/rules/crafting_model.gd")



var _builder: WorldBuilder
var _hud: CanvasLayer

var _is_server := false
var _connect_attempts := 0
var _local_id := 0
var _yaw := 0.0
var _pitch := -0.18

var _camera: Camera3D
var _status: Label
var _snapshots_logged := 0
var _npcs_seen := false
var _avatars: Dictionary = {}   # peer_id -> {"root": Node3D, "seen": bool}
var _npc_nodes: Dictionary = {} # npc_id -> {"root": Node3D, "seen": bool} (E27 ambient NPCs)
var _named_npc_nodes: Dictionary = {} # id -> {"root": Node3D} (named NPCs rendered via npc_builder)
var _npc_builder: NpcBuilder
var _last_named_npc_shown := -1
var _npc_talk_count := {}    # named-NPC id -> how many times talked (rotates dialogue lines)
var _talk_probe := false     # headless: --talk talks to the first named NPC once after connecting
var _talk_sent := false
var _talk_accum := 0.0
var _last_npc_shown := -1       # log ambient-NPC render-count CHANGES only
var _aim := 0
var _spend_cp := 0          # Character Points staged for the NEXT shot (WEG: +1D each); reset on fire
var _use_fp := false        # Force Point staged for the NEXT shot (WEG: doubles dice); reset on fire
var _cover := 0             # F50: take 1/4 cover for this shot (0/1). WEG: attacking exposes you, so
                            # firing caps your cover at 1/4 (COVER_QUARTER) — full cover needs a
                            # not-attacking stance, so this is an honest on/off toggle.
var _dodge := false         # F52: active dodge staged for this shot (attack at -1D, defend with dodge)
var _fire_cp := 0           # headless: --fire-cp N stages CP on the autofire path
var _fire_fp := false       # headless: --fire-fp stages a Force Point on autofire
var _fire_target := 0       # headless DIV-0019: --fire-target <peer> aims autofire at a PLAYER (0 = the dummy/creature)
var _fire_nearest := false  # headless DIV-0019: --fire-nearest aims autofire at the first other player in the zone
var _fire_cover := 0        # headless: --fire-cover 1 takes 1/4 cover on the autofire path
var _fire_dodge := false    # headless: --fire-dodge stages an active dodge on the autofire path (F52)
var _autofire := false
var _autodefend := false     # headless: --autodefend submits a full-dodge defensive stance each window (F51)
var _autowalk := false
var _walk_accum := 0.0       # headless: throttles the [pos] readout while autowalking
var _autofire_accum := 0.0
var _account := "guest"
var _name := ""
var _species := ""
var _quickstart := false
var _no_register := false   # headless test: connect but never authenticate (verifies unauth peers stay out of the world)
var _raise_skill := ""
var _zone := ""
var _equip := ""            # headless: "slot:item_key" to equip once after connecting
var _equip_sent := false
var _equip_accum := 0.0
var _faction := ""          # headless org membership (test affordance)
var _faction_axis := ""
var _faction_rank := ""
var _territory_influence := ""
var _claim := ""            # headless: node_id to claim once after connecting
var _claim_sent := false
var _claim_accum := 0.0
var _chat := ""             # headless: "channel:text" to send once after connecting
var _chat_sent := false
var _chat_accum := 0.0
var _say := ""              # headless: a free-text chat line ("/org regroup") via parse_input
var _say_sent := false
var _say_accum := 0.0
var _chat_input: LineEdit   # GUI free-text chat entry (Enter to open, Enter to send)
var _secret := ""           # account ownership secret (E26)
var _start_wound := ""       # headless DIV-0012 test: start a new char at a recoverable wound tier
var _heal_other := false     # headless DIV-0013 test: First-Aid the first other player once
var _heal_sent := false
var _heal_accum := 0.0
var _travel := ""            # headless DIV-0014 test: travel to this zone_id once after connecting
var _travel_sent := false
var _travel_accum := 0.0
var _accept_quest := ""      # headless DIV-0020: accept this quest_id once after connecting (before travel)
var _accept_quest_sent := false
var _claim_quest := ""       # headless DIV-0020: claim this quest_id once, late (after the objective completes)
var _claim_quest_sent := false
var _quest_accum := 0.0
var _prev_quests: Dictionary = {}   # DIV-0020: last-seen quest block, to toast complete/claim transitions
var _zone_list: Array = []   # DIV-0014: loaded zones from the snapshot (for the T travel key)
var _travel_idx := 0
var _last_zone_name := ""    # log zone CHANGES only
var _last_player_count := -1 # log zone-presence (players-here) CHANGES only
var _raise_accum := 0.0
var _raise_sent := false
var _wallet_label: Label
var _credits_label: Label          # Wave F economy: the player's credit balance
var _last_credits := -1
var _buy := ""                     # headless: item_key to buy once after connecting
var _buy_sent := false
var _sell := ""                    # headless: item_key to sell once after connecting
var _sell_sent := false
var _vendor_list_req := false      # headless: --vendor-list requests the stock once
var _buy_insurance_req := false    # headless: --buy-insurance buys a death-insurance policy once
var _econ_accum := 0.0
var _condition_label: Label
var _last_condition := "healthy|0|false"   # composite (wound|poison|held) so we log status CHANGES only
var _target_label: Label           # F47: at-a-glance target status (companion to the condition HUD)
var _last_target := ""             # so we log target-status CHANGES only
var _highlighted_target: Dictionary = {}

var _org_label: Label
var _last_org_line := ""           # so we log org/territory CHANGES only
var _boost_label: Label
var _last_boost := ""              # so we log combat CP/FP CHANGES only
var _ammo_label: Label            # DIV-0029: equipped-weapon ammo readout (hidden for melee / no-ammo)
var _last_ammo := ""              # so we log ammo-readout CHANGES only
var _prev_ammo: Dictionary = {}   # previous snapshot's "you".ammo block — client-side auto-reload inference
var _sheet_panel: ColorRect            # F24: character sheet (toggle with V); hidden by default
var _combat_log: Label
var _combat_lines: Array[String] = []
var _zone_label: Label
var _news_label: Label
var _chat_log: Label
var _chat_lines: Array[String] = []
var _last_news := ""
var _last_control := ""       # F35: log zone faction-control CHANGES only
var _last_alert := ""         # F37: flag zone ALERT-level escalations (Director consequence)

# --- Wave F visibility: combat-target mesh, shop panel, death card, toasts (all client-only) ---
var _monster_builder: MonsterBuilder
var _target_mesh: Node3D          # the currently-rendered combat target (monster / training remote)
var _target_mesh_key := ""        # "kind|name" of what's shown, so we rebuild only on target CHANGE
var _target_ttl := 0.0            # seconds until the idle target mesh despawns (refreshed each shot)
var _pvp_marker: Node3D           # PvP: floating "TARGET" marker parented over the highlighted player
var _pvp_marker_ttl := 0.0
var _shop_open := false           # the shop overlay owns the cursor while open (like the chat box)
var _shop_panel: Panel
var _shop_title: Label

var _econ_test_server := false
var _space_cargo_test_server := false
var _econ_test_c1 := false
var _econ_test_c2 := false
var _econ_c1_started := false
var _econ_c2_started := false

var _item_ident_c1 := false
var _item_ident_c2 := false
var _item_ident_c3 := false
var _item_ident_c1_started := false
var _item_ident_c2_started := false
var _item_ident_c3_started := false
var _is_soak_client := false

var _space_cargo_test_c1 := false
var _space_cargo_c1_started := false
var _shop_list: VBoxContainer
var _quest_open := false
var _quest_panel: Panel
var _my_sheet := {}
var _quest_list: VBoxContainer
var _crafting_open := false
var _crafting_panel: Panel
var _crafting_list: VBoxContainer
var _bazaar_open := false
var _bazaar_panel: Panel
var _bazaar_list: VBoxContainer
var _inventory_sell_list: VBoxContainer
var _bazaar_listings := {}


var _death_overlay: ColorRect     # DIV-0006: brief full-screen "you were killed" card
var _death_label: Label
var _downed_panel: Label          # DIV-0027: persistent amber "you are DOWN — press Y to yield" panel
var _is_downed := false           # DIV-0027: client is downed-in-field (gates the Y yield key)
var _yield_on_down := false       # headless DIV-0027: auto-yield when downed (two-process test hook)
# DIV-0022 headless PvP-consent affordances (two-process test hooks)
var _duel := ""              # --duel <name>: challenge the named player once after connecting
var _duel_sent := false
var _duel_accept := false    # --duel-accept: accept the single pending challenge
var _duel_accept_sent := false
var _quit_after: float = 0.0
var _quit_accum: float = 0.0
var _yield_duel := false     # --yield-duel: concede an active duel once
var _yield_duel_sent := false
var _place_bounty := ""      # --place-bounty <name>:<amount>: place a bounty once after connecting
var _place_bounty_sent := false
var _leave_after := ""       # --leave-after <zone>: travel out LATE (after an accepted duel is active) to test zone-leave abort
var _leave_after_sent := false
var _consent_accum := 0.0
var _toast_label: Label           # transient HUD feedback (credits/loot/buy/sell/force-awaken)
var _toast_tween: Tween
var _onboarding_panel: Panel
var _onboarding_shown := false

func _ready() -> void:
	_parse_args()

	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.snapshot_applied.connect(_on_snapshot)
	Net.client_connected.connect(_on_client_connected)
	Net.client_failed.connect(_on_client_failed)
	Net.combat_envelope.connect(_on_combat_envelope)
	Net.wallet_updated.connect(_on_wallet_updated)
	Net.skill_raise_replied.connect(_on_skill_raise_replied)
	Net.equip_replied.connect(_on_equip_replied)
	Net.claim_replied.connect(_on_claim_replied)
	Net.chat_received.connect(_on_chat_received)
	Net.auth_replied.connect(_on_auth_replied)
	Net.heal_replied.connect(_on_heal_replied)
	Net.zone_replied.connect(_on_zone_replied)
	Net.sheet_updated.connect(_on_sheet_updated)
	Net.credits_updated.connect(_on_credits_updated)
	Net.vendor_listed.connect(_on_vendor_listed)
	Net.buy_replied.connect(_on_buy_replied)
	Net.sell_replied.connect(_on_sell_replied)
	Net.died.connect(_on_died)
	Net.downed.connect(_on_downed)      # DIV-0027: downed-in-field (distinct from death)
	Net.revived.connect(_on_revived)    # DIV-0027: a medic First-Aided you back up
	Net.insurance_replied.connect(_on_insurance_replied)
	Net.force_awakened_replied.connect(_on_force_awakened)
	Net.fire_rejected.connect(_on_fire_rejected)
	Net.quests_updated.connect(_on_quests_updated)          # DIV-0020: live quest progress
	Net.quest_catalog_received.connect(_on_quest_catalog)   # DIV-0020: notice-board catalog
	Net.duel_replied.connect(_on_duel_replied)              # DIV-0022: duel command outcome
	Net.duel_notified.connect(_on_duel_notified)            # DIV-0022: duel state change involving me
	Net.bounty_replied.connect(_on_bounty_replied)          # DIV-0022: bounty command outcome
	Net.bounty_notified.connect(_on_bounty_notified)        # DIV-0022: bounty placed on me / collected
	Net.survey_replied.connect(_on_survey_replied)
	Net.harvest_replied.connect(_on_harvest_replied)
	Net.craft_replied.connect(_on_craft_replied)
	Net.bazaar_listings_updated.connect(_on_bazaar_listings_updated)
	Net.bazaar_list_replied.connect(_on_bazaar_list_replied)
	Net.bazaar_buy_replied.connect(_on_bazaar_buy_replied)



	if _is_server:
		var combat_window := _arg_value("--combat-window")
		if combat_window != "":
			Net.combat_window_seconds = maxf(float(combat_window), 0.1)
		var director_tick := _arg_value("--director-tick")
		if director_tick != "":
			Net.director_tick_seconds = maxf(float(director_tick), 0.1)
		var resource_tick := _arg_value("--resource-tick")
		if resource_tick != "":
			Net.resource_tick_seconds = maxf(float(resource_tick), 0.1)
		# TEST-ONLY: enable the register_account build.org self-grant affordance (org identity/rank/
		# influence over the wire). Off on a real server; the two-process harness opts in explicitly.
		Net.allow_test_org = OS.get_cmdline_user_args().has("--allow-test-org")
		Net.force_hostile_key = _arg_value("--force-hostile")  # TEST-ONLY: force a specific lethal creature to spawn
		Net.force_awaken_now = OS.get_cmdline_user_args().has("--force-awaken")  # TEST-ONLY: force a Force awakening
		if OS.get_cmdline_user_args().has("--dev-admin-allowlist"):
			Net.admin_allowlist = ["admin", "operator"]
		
		if _econ_test_server or _space_cargo_test_server or OS.get_cmdline_user_args().has("--item-ident-test-server"):
			Net.allow_test_org = true
			
		var port_arg := _arg_value("--port")
		var port := int(port_arg) if port_arg != "" else 24555
		Net.start_server(port)
		
		if OS.get_cmdline_user_args().has("--item-ident-test-server"):
			print("[server] Starting item_ident test data injection in 1s...")
			await get_tree().create_timer(1.0).timeout
			print("[server] Injecting item_c1 and item_c2 records!")
			var s_c1_record = Net._cached_load("item_c1")
			if s_c1_record.is_empty():
				s_c1_record = {"id": "item_c1", "sheet": {}}
			s_c1_record["sheet"]["credits"] = 1000
			s_c1_record["sheet"]["first_aid"] = "6D"
			s_c1_record["sheet"]["inventory"] = [
				{"instance_id": "res1", "template_id": "resource_stack", "stack_count": 5, "stats": {"resource_type": "organic_tissue"}},
				{"instance_id": "res2", "template_id": "resource_stack", "stack_count": 5, "stats": {"resource_type": "medical_biogel"}}
			]
			Net._cached_save("item_c1", s_c1_record)
			var c1_peer = Net.admin_get_peer_by_character("item_c1")
			if c1_peer > 0:
				Net.admin_push_sheet(c1_peer, s_c1_record)
			var s_c2_record = Net._cached_load("item_c2")
			if s_c2_record.is_empty():
				s_c2_record = {"id": "item_c2", "sheet": {}}
			s_c2_record["sheet"]["credits"] = 5000
			s_c2_record["sheet"]["first_aid"] = "30D"
			s_c2_record["sheet"]["wounds"] = 1
			s_c2_record["sheet"]["wound_state"] = "wounded"
			Net._cached_save("item_c2", s_c2_record)
			var c2_peer = Net.admin_get_peer_by_character("item_c2")
			if c2_peer > 0:
				Net.admin_push_sheet(c2_peer, s_c2_record)
		
		if _space_cargo_test_server:
			await get_tree().create_timer(1.0).timeout
			var target_account = _account if _account != "" else "pilot_1"
			var s_p1_record = Net._cached_load(target_account)
			if s_p1_record.is_empty():
				s_p1_record = {"id": target_account, "sheet": {}}
			s_p1_record["sheet"]["credits"] = 5000
			s_p1_record["sheet"]["ships"] = ["ship_1"]
			Net._cached_save(target_account, s_p1_record)
			var p1_peer = Net.admin_get_peer_by_character(target_account)
			if p1_peer > 0:
				Net.admin_push_sheet(p1_peer, s_p1_record)
			
		if _econ_test_server:
			await get_tree().create_timer(1.0).timeout
			var s_c1_record = Net._cached_load("crafter_1")
			if s_c1_record.is_empty():
				s_c1_record = {"id": "crafter_1", "sheet": {}}
			s_c1_record["sheet"]["credits"] = 1000
			s_c1_record["sheet"]["wounds"] = 0
			s_c1_record["sheet"]["inventory"] = [
				{"instance_id": "res1", "template_id": "resource_stack", "stack_count": 5, "stats": {"resource_type": "organic_tissue"}},
				{"instance_id": "res2", "template_id": "resource_stack", "stack_count": 5, "stats": {"resource_type": "medical_biogel"}}
			]
			Net._cached_save("crafter_1", s_c1_record)
			var s_c2_record = Net._cached_load("buyer_1")
			if s_c2_record.is_empty():
				s_c2_record = {"id": "buyer_1", "sheet": {}}
			s_c2_record["sheet"]["credits"] = 5000
			s_c2_record["sheet"]["wounds"] = 2
			Net._cached_save("buyer_1", s_c2_record)
			
		return

	_builder = WorldBuilder.new()
	_builder.build_lighting(self)
	_builder.build_ground(self)
	_builder.build_settlement(self)
	# Signature landmark east of Spaceport Row (settlement core ends ~x=30): a Mos Eisley cantina plaza
	LandmarkBuilder.new().build_cantina_plaza(self, Vector3(65, 0, 0))

	_monster_builder = MonsterBuilder.new()
	_npc_builder = NpcBuilder.new()
	_build_camera()
	_build_hud()
	var dialogue_overlay := DialogueOverlay.new()
	dialogue_overlay.name = "DialogueOverlay"
	add_child(dialogue_overlay)

	var space_map := SpaceMapOverlay.new()
	space_map.name = "SpaceMapOverlay"
	add_child(space_map)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_status("Connecting...")
	var port_arg := _arg_value("--port")
	var port := int(port_arg) if port_arg != "" else 24555
	Net.start_client(_resolve_host(), port)

func _run_econ_c1() -> void:
	await get_tree().create_timer(1.0).timeout
	var item_instance = ""
	for i in range(5):
		Net.send_craft("basic_medpac")
		var result = await Net.craft_replied
		var outcome = result[0] if result is Array else result
		print("[c1] Craft outcome: ", outcome)
		item_instance = outcome.get("item", {}).get("instance_id", "")
		if item_instance != "":
			break
		await get_tree().create_timer(0.5).timeout
		
	if item_instance != "":
		print("[c1] Sending bazaar list for ", item_instance)
		Net.send_bazaar_list(item_instance, 1500)
	else:
		print("[c1] ERROR: No medpac found in craft result!")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)

func _run_econ_c2() -> void:
	await get_tree().create_timer(1.0).timeout
	Net.send_request_bazaar_listings()
	await get_tree().create_timer(1.0).timeout
	var found_listing = ""
	for l_id in _bazaar_listings.keys():
		var l = _bazaar_listings[l_id]
		if l.get("item", {}).get("template_id") == "medpac":
			found_listing = l_id
	if found_listing != "":
		Net.send_bazaar_buy(found_listing)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)

func _run_item_ident_c1() -> void:
	print("[c1] Waiting for initial snapshot...")
	while _my_sheet.is_empty():
		await get_tree().process_frame
	print("[c1] Snapshot received!")
	var item_instance = ""
	var outcome = {}
	print("[c1] Sheet before crafting: ", _my_sheet)
	for i in range(5):
		Net.send_craft("basic_medpac")
		var result = await Net.craft_replied
		outcome = result[0] if result is Array else result
		item_instance = outcome.get("item", {}).get("instance_id", "")
		if item_instance != "": break
		await get_tree().create_timer(0.5).timeout
	if item_instance != "":
		print("[c1] Crafted: ", item_instance)
		var f = FileAccess.open("user://item_ident_test.txt", FileAccess.WRITE)
		f.store_string(item_instance)
		f.close()
		Net.send_bazaar_list(item_instance, 100)
	else:
		print("[c1] ERROR: No item crafted! Outcome: ", outcome)
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)

func _run_item_ident_c2() -> void:
	print("[c2] Waiting for initial snapshot...")
	while _my_sheet.is_empty():
		await get_tree().process_frame
	print("[c2] Snapshot received!")
	Net.send_request_bazaar_listings()
	await get_tree().create_timer(1.0).timeout
	var f = FileAccess.open("user://item_ident_test.txt", FileAccess.READ)
	var target_instance = f.get_as_text().strip_edges()
	f.close()
	
	var found_listing = ""
	for l_id in _bazaar_listings.keys():
		var l = _bazaar_listings[l_id]
		if l.get("item", {}).get("instance_id") == target_instance:
			found_listing = l_id
	if found_listing != "":
		Net.send_bazaar_buy(found_listing)
		print("[c2] Bought listing for instance: ", target_instance)
	else:
		print("[c2] ERROR: Listing not found for: ", target_instance)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)

func _run_item_ident_c3() -> void:
	print("[c3] Waiting for initial snapshot...")
	while _my_sheet.is_empty():
		await get_tree().process_frame
	print("[c3] Snapshot received!")
	var f = FileAccess.open("user://item_ident_test.txt", FileAccess.READ)
	var target_instance = f.get_as_text().strip_edges()
	f.close()
	
	var found = false
	for item in _my_sheet.get("inventory", []):
		if typeof(item) == TYPE_DICTIONARY and item.get("instance_id") == target_instance:
			found = true
			break
			
	if found:
		print("[c3] Verified item instance in inventory after restart: ", target_instance)
		Net.send_use_item(target_instance)
		var result = await Net.use_item_replied
		if bool(result.get("ok", false)):
			await get_tree().process_frame
			if String(_my_sheet.get("wound_state", "wounded")) == "healthy":
				print("[c3] Used item instance successfully after restart: ", target_instance)
			else:
				print("[c3] ERROR: Use succeeded but wound_state did not clear. Sheet: ", _my_sheet)
		else:
			print("[c3] ERROR: Item use failed: ", result)
	else:
		print("[c3] ERROR: Item instance NOT found in inventory!")
		
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)

func _run_space_cargo_c1() -> void:
	print("[space] Starting _run_space_cargo_c1...")
	while not _my_sheet.get("ships", []).has("ship_1"):
		print("[space] Waiting for sheet_updated with ship_1...")
		await Net.sheet_updated
	print("[space] Sheet received with ship_1! Launching ship...")
	Net.send_launch_ship("ship_1")
	var launch_result = await Net.launch_ship_replied
	var launch_outcome = launch_result[0] if launch_result is Array else launch_result
	print("[space] Launch outcome: ", launch_outcome)
	
	if bool(launch_outcome.get("ok", false)):
		await get_tree().create_timer(1.0).timeout
		print("[space] Harvesting asteroid...")
		Net.send_space_harvest("asteroid_field")
		
		await get_tree().create_timer(1.0).timeout
		print("[space] Landing ship...")
		Net.send_land_ship()
		var land_result = await Net.land_ship_replied
		var land_outcome = land_result[0] if land_result is Array else land_result
		print("[space] Land outcome: ", land_outcome)
		
		# Wait for the sheet update from the landing sequence
		await get_tree().create_timer(0.5).timeout
		
		var sheet = _my_sheet
		var inventory: Array = sheet.get("inventory", [])
		var item_instance_id = ""
		for item in inventory:
			if typeof(item) == TYPE_DICTIONARY and item.get("template_id") == "asteroid_field":
				item_instance_id = item.get("instance_id", "asteroid_field")
				break
		if item_instance_id != "":
			print("[space] Selling cargo...")
			Net.send_sell(item_instance_id)
			var sell_result = await Net.sell_replied
			print("[space] Sell outcome: ", sell_result)
		else:
			print("[space] Cargo not found in inventory!")
		
		# Assert the cargo transfer
		print("[space] End of space cargo test.")
		var found_cargo = false
		inventory = _my_sheet.get("inventory", [])
		print("[space] Inventory after landing: ", inventory)
		for item in inventory:
			if item is Dictionary and item.get("template_id", "") == "asteroid_field":
				found_cargo = true
				break
		if found_cargo:
			print("[space] OK: Cargo successfully transferred to personal inventory.")
		else:
			print("[space] ERROR: Cargo was NOT found in personal inventory!")
			get_tree().quit(1)
			return
	else:
		print("[space] ERROR: Failed to launch.")
		
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	_is_server = args.has("--server")
	_autofire = args.has("--autofire")
	_autowalk = args.has("--autowalk")
	var account := _arg_value("--account")
	if account != "":
		_account = account



	if _no_register:
		return
	if _quickstart:
		_name = _arg_value("--name")
	_species = _arg_value("--species")
	_quickstart = args.has("--quickstart")
	_no_register = args.has("--no-register")
	_raise_skill = _arg_value("--raise-skill")
	_zone = _arg_value("--zone")  # optional starting zone (server validates)
	_equip = _arg_value("--equip")  # headless "slot:item_key" equip-swap test affordance
	_faction = _arg_value("--faction")
	_faction_axis = _arg_value("--faction-axis")
	_faction_rank = _arg_value("--faction-rank")
	_territory_influence = _arg_value("--territory-influence")
	_claim = _arg_value("--claim")  # headless: node_id to claim once after connecting
	_chat = _arg_value("--chat")  # headless: "channel:text" to send once after connecting
	_secret = _arg_value("--secret")  # account ownership secret (binds the peer to the account)
	_fire_cp = maxi(int(_arg_value("--fire-cp")), 0)  # headless: stage CP on autofire shots
	_fire_cover = clampi(int(_arg_value("--fire-cover")), 0, 1)  # headless: take 1/4 cover on autofire shots (F50)
	_autodefend = args.has("--autodefend")  # headless: full-dodge defensive stance each window (F51)
	_fire_dodge = args.has("--fire-dodge")  # headless: active dodge on autofire shots (F52)
	_fire_fp = args.has("--fire-fp")  # headless: stage a Force Point on autofire shots
	_fire_target = maxi(int(_arg_value("--fire-target")), 0)  # headless DIV-0019: aim autofire at a player peer
	_fire_nearest = args.has("--fire-nearest")  # headless DIV-0019: aim autofire at the first other player
	_start_wound = _arg_value("--start-wound")  # headless DIV-0012: new char starts wounded
	_heal_other = args.has("--heal-other")  # headless DIV-0013: First-Aid the first other player once
	_travel = _arg_value("--travel")  # headless DIV-0014: travel to this zone_id once
	_say = _arg_value("--say")  # headless: a free-text chat line through parse_input (F22)
	_buy = _arg_value("--buy")  # headless Wave F: buy this item_key once
	_sell = _arg_value("--sell")  # headless Wave F: sell this item_key once
	_vendor_list_req = args.has("--vendor-list")  # headless Wave F: request the vendor stock once
	_buy_insurance_req = args.has("--buy-insurance")  # headless Wave F: buy a death-insurance policy once
	_talk_probe = args.has("--talk")  # headless: talk to the first named NPC once (verifies dialogue)
	_accept_quest = _arg_value("--accept-quest")  # headless DIV-0020: accept a quest once after connecting
	_claim_quest = _arg_value("--claim-quest")    # headless DIV-0020: claim a quest once, late
	_yield_on_down = args.has("--yield")          # headless DIV-0027: auto-yield when downed (two-process test hook)
	_duel = _arg_value("--duel")                  # headless DIV-0022: challenge the named player to a duel
	
	_econ_test_server = args.has("--economy-test-server")
	_space_cargo_test_server = args.has("--space-cargo-test-server")
	_econ_test_c1 = args.has("--economy-test-c1")
	_econ_test_c2 = args.has("--economy-test-c2")
	_duel_accept = args.has("--duel-accept")      # headless DIV-0022: accept the single pending duel
	_yield_duel = args.has("--yield-duel")        # headless DIV-0022: concede an active duel
	_place_bounty = _arg_value("--place-bounty")  # headless DIV-0022: "name:amount" bounty placement
	_leave_after = _arg_value("--leave-after")    # headless DIV-0022: travel out LATE (zone-leave duel-abort test)
	var qa := _arg_value("--quit-after")
	if qa != "":
		_quit_after = float(qa)
	_space_cargo_test_c1 = args.has("--space-cargo-test-c1")
	_item_ident_c1 = args.has("--item-ident-c1")
	_item_ident_c2 = args.has("--item-ident-c2")
	_item_ident_c3 = args.has("--item-ident-c3")
	_is_soak_client = args.has("--soak-client")

	if _econ_test_c1 and _account == "guest":
		_account = "crafter_1"
	if _econ_test_c2 and _account == "guest":
		_account = "buyer_1"
	if _space_cargo_test_c1 and _account == "guest":
		_account = "pilot_1"

func _resolve_host() -> String:
	var host := _arg_value("--connect")
	return host if host != "" else "127.0.0.1"

func _arg_value(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var idx := args.find(flag)
	if idx >= 0 and idx + 1 < args.size():
		return args[idx + 1]
	return ""

func _process(delta: float) -> void:
	if _is_server:
		return
	_send_local_input()
	_update_camera()
	_update_combat_target(delta)

	# Sweep for target under the crosshair in first person
	var target_info := _find_target_under_crosshair()
	if target_info != _highlighted_target:
		_highlighted_target = target_info
		if not _highlighted_target.is_empty():
			if _target_label != null:
				_target_label.text = "Target: %s" % _highlighted_target["name"]
		else:
			if _target_label != null:
				_target_label.text = "Target: None"

	if _econ_test_c1 and Net.connected and not _econ_c1_started:
		_econ_c1_started = true
		_run_econ_c1()
	
	if _econ_test_c2 and Net.connected and not _econ_c2_started:
		_econ_c2_started = true
		_run_econ_c2()

	if _space_cargo_test_c1 and Net.connected and not _space_cargo_c1_started:
		_space_cargo_c1_started = true
		_run_space_cargo_c1()

	if _item_ident_c1 and Net.connected and not _item_ident_c1_started:
		_item_ident_c1_started = true
		_run_item_ident_c1()
		
	if _item_ident_c2 and Net.connected and not _item_ident_c2_started:
		_item_ident_c2_started = true
		_run_item_ident_c2()
		
	if _item_ident_c3 and Net.connected and not _item_ident_c3_started:
		_item_ident_c3_started = true
		_run_item_ident_c3()

	if _is_soak_client and Net.connected and not has_node("SoakBot"):
		var soak_bot = preload("res://scripts/net/soak_bot.gd").new()
		soak_bot.name = "SoakBot"
		add_child(soak_bot)

	if _yield_on_down and _is_downed and Net.connected:
		Net.send_yield()  # headless DIV-0027: auto-yield when downed (two-process test hook; server is idempotent + rate-limited)
	# DIV-0022 headless PvP-consent: challenge / accept / place-bounty / yield-duel, staggered so both
	# peers have registered and the challenge has propagated before the accept fires.
	if (_duel != "" or _duel_accept or _place_bounty != "" or _yield_duel or _leave_after != "") and Net.connected:
		_consent_accum += delta
		if _duel != "" and not _duel_sent and _consent_accum >= 3.5:
			var tgt := _peer_by_name(_duel)
			if tgt != 0:
				_duel_sent = true
				Net.send_duel_challenge(tgt, false)
				print("[duel] client challenging %s (peer %d)" % [_duel, tgt])
		if _duel_accept and not _duel_accept_sent and _consent_accum >= 5.0:
			_duel_accept_sent = true
			Net.send_duel_accept(0)  # accept the single pending offer
			print("[duel] client accepting pending challenge")
		if _place_bounty != "" and not _place_bounty_sent and _consent_accum >= 2.5:
			var parts := _place_bounty.split(":", true, 1)
			if parts.size() == 2:
				var bp := _peer_by_name(String(parts[0]))
				if bp != 0:
					_place_bounty_sent = true
					Net.send_place_bounty(bp, int(String(parts[1])))
					print("[bounty] client placing %s on %s (peer %d)" % [String(parts[1]), String(parts[0]), bp])
		if _yield_duel and not _yield_duel_sent and _consent_accum >= 6.0:
			_yield_duel_sent = true
			Net.send_duel_yield()
			print("[duel] client yielding")
		if _leave_after != "" and not _leave_after_sent and _consent_accum >= 8.0:
			_leave_after_sent = true  # travel out AFTER the duel is active -> server aborts the active duel
			Net.send_change_zone(_leave_after)
			print("[duel] client leaving the zone to %s (zone-leave abort test)" % _leave_after)
	if _quit_after > 0.0:
		_quit_accum += delta
		if _quit_accum >= _quit_after:
			print("[test] --quit-after timeout reached, exiting.")
			get_tree().quit(0)
			
	if (_autofire or _autodefend) and Net.connected:
		_autofire_accum += delta
		if _autofire_accum >= 0.4:
			_autofire_accum = 0.0
			if _autodefend:
				Net.send_fire_intent({"full_dodge": true})  # F51: headless defensive-stance loop
			else:
				var tgt := _fire_target
				if _fire_nearest and tgt == 0:
					tgt = _first_other_player()  # DIV-0019: target the first other player in the zone
				Net.send_fire_intent({"aim": 3, "cover": _fire_cover, "cp": _fire_cp, "fp": _fire_fp, "dodge": _fire_dodge, "target_peer": tgt})
	if _raise_skill != "" and not _raise_sent and Net.connected:
		_raise_accum += delta
		if _raise_accum >= 6.0:  # let some CP accrue first, then raise once (headless test)
			_raise_sent = true
			Net.send_skill_raise(_raise_skill)
	if _equip != "" and not _equip_sent and Net.connected:
		_equip_accum += delta
		if _equip_accum >= 3.0:  # after register, swap loadout once (headless test)
			_equip_sent = true
			var parts := _equip.split(":")
			if parts.size() == 2:
				Net.send_equip(String(parts[0]), String(parts[1]))
	if _claim != "" and not _claim_sent and Net.connected:
		_claim_accum += delta
		if _claim_accum >= 3.5:  # after register + org set, claim a node once (headless test)
			_claim_sent = true
			Net.send_claim_node(_claim)
	if _chat != "" and not _chat_sent and Net.connected:
		_chat_accum += delta
		if _chat_accum >= 3.0:  # after register, say one line (headless test)
			_chat_sent = true
			var parts := _chat.split(":", true, 1)  # split on the FIRST colon only
			if parts.size() == 2:
				Net.send_chat(String(parts[0]), String(parts[1]))
	if _heal_other and not _heal_sent and Net.connected:
		_heal_accum += delta
		if _heal_accum >= 4.0:  # after both peers have registered, First-Aid the nearest wounded ally
			var other := _best_heal_target()
			if other != 0:
				_heal_sent = true
				Net.send_heal(other)
	if _travel != "" and not _travel_sent and Net.connected:
		_travel_accum += delta
		if _travel_accum >= 3.0:  # after register, travel to the requested zone once
			_travel_sent = true
			Net.send_change_zone(_travel)
	# DIV-0020 headless: accept a quest EARLY (before the 3.0s travel arms its reach_zone objective),
	# then claim it LATE (after the objective completes + the server pushes it back complete).
	if (_accept_quest != "" or _claim_quest != "") and Net.connected:
		_quest_accum += delta
		if _accept_quest != "" and not _accept_quest_sent and _quest_accum >= 2.5:
			_accept_quest_sent = true
			Net.send_accept_quest(_accept_quest)
			print("[quest] client accepting %s" % _accept_quest)
		if _claim_quest != "" and not _claim_quest_sent and _quest_accum >= 7.0:
			_claim_quest_sent = true
			Net.send_claim_quest(_claim_quest)
			print("[quest] client claiming %s" % _claim_quest)
	if _say != "" and not _say_sent and Net.connected:
		_say_accum += delta
		if _say_accum >= 3.0:  # after register, send one free-text chat line via parse_input
			_say_sent = true
			_submit_chat_line(_say)
	# Wave F economy headless affordances: request stock / buy / sell / insure once, after register settles.
	if (_vendor_list_req or _buy != "" or _sell != "" or _buy_insurance_req) and Net.connected:
		_econ_accum += delta
		if _econ_accum >= 3.5:
			if _vendor_list_req:
				_vendor_list_req = false
				Net.send_vendor_list()
			if _buy != "" and not _buy_sent:
				_buy_sent = true
				Net.send_buy(_buy)
			if _sell != "" and not _sell_sent:
				_sell_sent = true
				Net.send_sell(_sell)
			if _buy_insurance_req:
				_buy_insurance_req = false
				Net.send_buy_insurance()
	# headless: talk to the first named NPC once (dialogue verification without walking to one)
	if _talk_probe and not _talk_sent and Net.connected:
		_talk_accum += delta
		if _talk_accum >= 4.0:
			var named: Array = Net.last_snapshot.get("named_npcs", [])
			if not named.is_empty():
				_talk_sent = true
				_do_talk(named[0])
	# headless net-movement readout: log the server-authoritative position while autowalking
	if _autowalk and Net.connected:
		_walk_accum += delta
		if _walk_accum >= 1.5:
			_walk_accum = 0.0
			var p := _my_position()
			print("[pos] x=%.2f y=%.2f z=%.2f" % [p.x, p.y, p.z])

# --- input / camera (client only) ---
func _send_local_input() -> void:
	if _shop_open or (_chat_input != null and _chat_input.has_focus()):
		Net.set_local_input(Vector2.ZERO, _yaw, false)  # shop open / typing in chat: don't move/jump
		return
	var move := Vector2.ZERO
	move.y -= 1.0 if Input.is_key_pressed(KEY_W) else 0.0
	move.y += 1.0 if Input.is_key_pressed(KEY_S) else 0.0
	move.x -= 1.0 if Input.is_key_pressed(KEY_A) else 0.0
	move.x += 1.0 if Input.is_key_pressed(KEY_D) else 0.0
	if _autowalk:
		move = Vector2(0.0, -1.0)  # forward, for headless persistence testing
	if move.length() > 1.0:
		move = move.normalized()
	Net.set_local_input(move, _yaw, Input.is_key_pressed(KEY_SPACE))

func _input(event: InputEvent) -> void:
	if _is_server:
		return
	# While a panel overlay is open it owns the cursor: only its key/Esc (close) act; everything
	# else is swallowed here so it never fires/recaptures the mouse.
	if _onboarding_panel != null and _onboarding_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER):
			_onboarding_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if _quest_open:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_J or event.keycode == KEY_ESCAPE):
			_close_quest_panel()
		return
	if _shop_open:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_B or event.keycode == KEY_ESCAPE):
			_close_shop()
		return
	if _crafting_open:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_O or event.keycode == KEY_ESCAPE):
			_close_crafting_panel()
		return
	if _bazaar_open:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_L or event.keycode == KEY_ESCAPE):
			_close_bazaar_panel()
		return



	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.25, 0.8)
	elif event is InputEventKey and event.pressed:
		# While the chat box has focus, the LineEdit owns the keyboard — don't trigger game
		# keys (the event still propagates to the LineEdit after this returns). Esc closes it;
		# Enter submits via the LineEdit's text_submitted signal.
		if _chat_input != null and _chat_input.has_focus():
			if event.keycode == KEY_ESCAPE:
				_close_chat_input()
			return
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_Y and _is_downed:
			Net.send_yield()  # DIV-0027: a downed player yields -> accept death + respawn
			_set_status("Yielding…")
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_open_chat_input()  # open the chat box (type, Enter to send)
		elif event.keycode == KEY_K:
			Net.send_skill_raise("blaster")  # spend CP to raise Blaster a pip
		elif event.keycode == KEY_V:
			if _sheet_panel != null:  # toggle the character sheet
				_sheet_panel.visible = not _sheet_panel.visible
		elif event.keycode == KEY_H:
			var other := _best_heal_target()  # First Aid the nearest WOUNDED ally
			if other != 0:
				Net.send_heal(other)
				_set_status("First Aid -> peer %d…" % other)
			else:
				_set_status("First Aid: no wounded ally nearby.")
		elif event.keycode == KEY_T:
			if not _zone_list.is_empty():  # cycle travel to the next loaded zone
				_travel_idx = (_travel_idx + 1) % _zone_list.size()
				var z: Dictionary = _zone_list[_travel_idx]
				Net.send_change_zone(String(z.get("id", "")))
				_set_status("Traveling to %s…" % String(z.get("name", z.get("id", ""))))
		elif event.keycode == KEY_B:
			_toggle_shop()  # Wave F economy: open/close the shop overlay (server-priced stock)
		elif event.keycode == KEY_J:
			_toggle_quest_panel() # open/close quest journal bulletin board
		elif event.keycode == KEY_U:
			Net.send_survey()
			_set_status("Scanning area for resources...")
		elif event.keycode == KEY_I:
			Net.send_harvest()
			_set_status("Extracting resource deposit...")
		elif event.keycode == KEY_O:
			_toggle_crafting_panel()
		elif event.keycode == KEY_L:
			_toggle_bazaar_panel()
		elif event.keycode == KEY_E:

			_talk_to_nearest_npc()  # talk to the nearest named NPC (dialogue_model)
		elif event.keycode == KEY_C:
			_spend_cp = (_spend_cp + 1) % 6  # cycle 0..5 CP staged for the next shot (WEG: +1D each)
			_announce_next_shot()
		elif event.keycode == KEY_F:
			_use_fp = not _use_fp  # toggle a Force Point for the next shot (WEG: doubles dice)
			_announce_next_shot()
		elif event.keycode == KEY_X:
			_cover = 1 - _cover  # F50: toggle 1/4 cover for the next shot (reduces incoming return fire)
			_announce_next_shot()
		elif event.keycode == KEY_G:
			Net.send_fire_intent({"full_dodge": true})  # F51: defensive stance — forgo the attack, full dodge
			_set_status("Defensive stance — full dodge (no attack this window).")
		elif event.keycode == KEY_Z:
			_dodge = not _dodge  # F52: toggle active dodge for the next shot (attack -1D, defend with dodge)
			_announce_next_shot()
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_aim = mini(_aim + 1, 3)
			_announce_next_shot()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var target_peer := 0
			var target_npc := ""
			if _highlighted_target.has("peer_id"):
				target_peer = _highlighted_target["peer_id"]
			elif _highlighted_target.has("npc_id"):
				target_npc = _highlighted_target["npc_id"]
			
			Net.send_fire_intent({
				"aim": _aim,
				"cover": _cover,
				"cp": _spend_cp,
				"fp": _use_fp,
				"dodge": _dodge,
				"target_peer": target_peer,
				"target_npc": target_npc
			})
			
			# Trigger instant client-side muzzle flash and laser tracer
			_spawn_muzzle_flash()
			if _camera != null:
				var basis := _camera.global_transform.basis
				var muzzle_pos := _camera.global_position - basis.z * 0.9 - basis.y * 0.25 + basis.x * 0.2
				var target_pos := _camera.global_position - basis.z * 35.0
				if _highlighted_target.has("pos"):
					target_pos = _highlighted_target["pos"]
				_spawn_laser_tracer(muzzle_pos, target_pos)
			
			_aim = 0
			_spend_cp = 0
			_use_fp = false
			_cover = 0
			_dodge = false


func _update_camera() -> void:
	if _camera == null or _local_id == 0:
		return
	var me := _find_player(_local_id)
	if me.is_empty():
		return
	var pos: Vector3 = me.get("pos", Vector3.ZERO)
	_camera.global_position = pos + Vector3(0.0, EYE_HEIGHT, 0.0)
	_camera.basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)

# --- net signal handlers ---
func _on_client_connected() -> void:
	_local_id = Net.local_peer_id()
	var build := {}
	if _species != "" or _quickstart:
		build = {"species": _species if _species != "" else "human", "quickstart": true}
	if _zone != "":
		build["zone"] = _zone  # request a starting zone (server validates against its roster)
	if _faction != "":
		build["org"] = {
			"faction_id": _faction,
			"faction_axis": _faction_axis if _faction_axis != "" else "independent",
			"faction_rank": int(_faction_rank) if _faction_rank != "" else 1,
			"influence": int(_territory_influence) if _territory_influence != "" else 0,
		}
	if _secret != "":
		build["secret"] = _secret  # E26: bind/authorize this account
	if _start_wound != "":
		build["wound"] = _start_wound  # DIV-0012 test: seed a recoverable wound on a new char
	if _no_register:
		# Connected but deliberately un-authenticated: the server must NOT place this peer in the
		# world (no avatar, no simulation). Used by the unauth-peer two-process check.
		print("[unauth] peer %d connected WITHOUT registering" % _local_id)
		_set_status("Connected as peer %d — not registering (unauth)." % _local_id)
		return
	Net.send_register(_account, _name, build)
	var who := _name if _name != "" else "account %s" % _account
	_set_status("Connected as peer %d (%s)." % [_local_id, who])

func _on_client_failed() -> void:
	_connect_attempts += 1
	if _connect_attempts <= 5:
		_set_status("Connect failed; retry %d/5..." % _connect_attempts)
		var port_arg := _arg_value("--port")
		var port := int(port_arg) if port_arg != "" else 24555
		var err := Net.start_client(_resolve_host(), port)
		if err != OK:
			print("Failed to start client")
	else:
		_set_status("Could not reach server.")

func _on_player_joined(_peer_id: int) -> void:
	pass

func _on_player_left(peer_id: int) -> void:
	if _avatars.has(peer_id):
		(_avatars[peer_id]["root"] as Node3D).queue_free()
		_avatars.erase(peer_id)

func _on_snapshot(snapshot: Dictionary) -> void:
	var npc_count := (snapshot.get("npcs", []) as Array).size()
	var first_npcs := npc_count > 0 and not _npcs_seen  # log the moment ambient NPCs appear
	if npc_count > 0:
		_npcs_seen = true
	if _snapshots_logged < 6 or first_npcs:
		_snapshots_logged += 1
		var z: Dictionary = snapshot.get("zone", {})
		print("[net] client received snapshot tick=%d players=%d zone=%s/%s npcs=%d" % [
			int(snapshot.get("tick", -1)),
			(snapshot.get("players", []) as Array).size(),
			String(z.get("alert_level", "-")),
			String(z.get("effective_security", "-")),
			npc_count,
		])
	if _is_server:
		return
	var seen := {}
	for entry in snapshot.get("players", []):
		var id := int(entry.get("id", 0))
		seen[id] = true
		var pos: Vector3 = entry.get("pos", Vector3.ZERO)
		if not _avatars.has(id):
			_avatars[id] = {"root": _spawn_avatar(id, String(entry.get("name", ""))), "seen": false, "wound": "healthy"}
		var record: Dictionary = _avatars[id]
		var root := record["root"] as Node3D
		# First person: hide our own capsule.
		root.visible = id != _local_id
		if record["seen"]:
			root.global_position = root.global_position.lerp(pos, 0.5)
		else:
			root.global_position = pos
			record["seen"] = true
		# Show OTHER players' wound condition on their nameplate (so a medic can see who's hurt)
		# + faction allegiance (F36) + live venom/restraint status (surfaced from the snapshot;
		# the status fields are absent when inactive, so read them null-safe with .get()).
		if id != _local_id:
			_update_nameplate(record, id, String(entry.get("name", "")), String(entry.get("wound", "healthy")), String(entry.get("axis", "")), int(entry.get("status_poison_rounds_left", 0)), bool(entry.get("status_restrained", false)))
	for id in _avatars.keys():
		if not seen.has(id):
			(_avatars[id]["root"] as Node3D).queue_free()
			_avatars.erase(id)
	_reconcile_npcs(snapshot.get("npcs", []))  # E27: render the zone's ambient NPCs
	_reconcile_named_npcs(snapshot.get("named_npcs", []))  # render the zone's NAMED NPCs via npc_builder
	var here_count := (snapshot.get("players", []) as Array).size()
	_set_status("Peer %d | players in zone: %d" % [_local_id, here_count])
	if here_count != _last_player_count:
		_last_player_count = here_count
		print("[presence] players_here=%d" % here_count)
	var zone: Dictionary = snapshot.get("zone", {})
	var ranked: Array = _sorted_influence(zone.get("influence", {}))  # F35: zone faction control
	if _zone_label != null and not zone.is_empty():
		_zone_label.text = "%s — alert: %s | security: %s | control: %s" % [
			String(zone.get("display_name", "Zone")),
			String(zone.get("alert_level", "")),
			String(zone.get("effective_security", "")),
			_control_summary(ranked),
		]
	var zone_name := String(zone.get("display_name", ""))
	var alert := String(zone.get("alert_level", ""))
	if zone_name != "" and zone_name != _last_zone_name:
		_last_zone_name = zone_name
		_last_alert = alert  # F37: baseline the new zone's alert (travel/join isn't an escalation)
		print("[zone] now in %s (%s)" % [zone_name, String(zone.get("effective_security", ""))])
	elif alert != "" and alert != _last_alert:
		# F37: the alert level shifted WITHIN the current zone — a Director response to faction
		# dynamics (e.g. one side's influence crossing a threshold). Surface it as an event.
		print("[alert] %s: %s -> %s" % [String(zone.get("zone_id", zone_name)), _last_alert, alert])
		_set_status("Security in %s is now: %s" % [zone_name, alert])
		_last_alert = alert
	# F35: surface the Director's per-zone faction influence (who controls/contests this place —
	# the persistent-world state the player's actions feed via E24). Already in the snapshot; just
	# render + log it on change. Pure presentation.
	var control_log := ""
	for pair in ranked:
		control_log += "%s=%d " % [String(pair[0]), int(pair[1])]
	control_log = control_log.strip_edges()
	if control_log != _last_control:
		_last_control = control_log
		if control_log != "":
			print("[control] %s %s" % [String(zone.get("zone_id", zone_name)), control_log])
	_zone_list = snapshot.get("zone_list", _zone_list)  # cache the travel list (DIV-0014)
	var headline := String(zone.get("event", ""))
	if _news_label != null:
		_news_label.text = ("NEWS — " + headline) if headline != "" else ""
	if headline != "" and headline != _last_news:
		_last_news = headline
		print("[news] %s" % headline)
	var you: Dictionary = snapshot.get("you", {})
	_update_condition(String(you.get("wound", "healthy")), int(you.get("wound_penalty", 0)), int(you.get("status_poison_rounds_left", 0)), bool(you.get("status_restrained", false)))
	_update_boost(int(you.get("cp", 0)), int(you.get("fp", 0)))
	_update_ammo(you.get("ammo", {}))  # DIV-0029: equipped-weapon shots/packs readout + reload inference
	_update_org(snapshot.get("territory", {}))

func _find_player(peer_id: int) -> Dictionary:
	for entry in Net.last_snapshot.get("players", []):
		if int(entry.get("id", 0)) == peer_id:
			return entry
	return {}

# --- scene building (client only) ---
func _spawn_avatar(peer_id: int, display_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Avatar_%d" % peer_id

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	mesh.mesh = capsule
	mesh.position.y = 0.85
	var material := StandardMaterial3D.new()
	material.albedo_color = _color_for_peer(peer_id)
	material.roughness = 0.88
	mesh.material_override = material
	root.add_child(mesh)

	var label := Label3D.new()
	label.name = "Nameplate"
	label.text = display_name if display_name != "" else "Spacer-%d" % peer_id
	label.position.y = 2.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.modulate = Color(0.09, 0.08, 0.06)
	root.add_child(label)

	add_child(root)
	return root

func _color_for_peer(peer_id: int) -> Color:
	var hue := fposmod(float(peer_id) * 0.6180339887, 1.0)
	return Color.from_hsv(hue, 0.55, 0.72)

# Show a remote player's live status on their nameplate (so a medic can see who's hurt/held/
# poisoned and target First Aid). Healthy + un-poisoned + un-held -> just the name (identical
# to before); any active status -> "Name — <combined status>" tinted to the TOP status. The
# poison/restraint params default to no-status so any legacy caller renders byte-identically.
func _update_nameplate(record: Dictionary, peer_id: int, display_name: String, wound: String, axis: String = "", poison_rounds_left: int = 0, restrained: bool = false) -> void:
	var label := (record["root"] as Node3D).get_node_or_null("Nameplate") as Label3D
	var base := display_name if display_name != "" else "Spacer-%d" % peer_id
	if axis != "":
		base += " [%s]" % _axis_pretty(axis)  # F36: faction allegiance
	var badge := PlayerStatusBadgeModel.badge_for(wound, poison_rounds_left, restrained)
	if label != null:
		if not bool(badge.get("active", false)):
			# healthy + clean: unchanged from the pre-status build
			label.text = base
			label.modulate = Color(0.09, 0.08, 0.06)
		else:
			label.text = "%s — %s" % [base, String(badge.get("combined", ""))]
			label.modulate = _status_color(String(badge.get("color_key", "healthy")))
	if String(record.get("wound", "healthy")) != wound:
		record["wound"] = wound
		print("[nameplate] %s is %s" % [base, _condition_pretty(wound)])

# E27: render the zone's ambient NPCs as muted markers (distinct from player avatars),
# reconciled each snapshot — spawn new, lerp existing, free despawned/zone-left. The roster
# is per-zone, so this naturally swaps when the player travels (F11/DIV-0014).
func _reconcile_npcs(npcs: Array) -> void:
	var seen := {}
	for entry in npcs:
		var npc: Dictionary = entry
		var id := String(npc.get("id", ""))
		if id == "":
			continue
		seen[id] = true
		var p: Dictionary = npc.get("pos", {})
		var pos := Vector3(float(p.get("x", 0.0)), float(p.get("y", 1.2)), float(p.get("z", 0.0)))
		if not _npc_nodes.has(id):
			_npc_nodes[id] = {"root": _spawn_npc(id, String(npc.get("kind", "civilian")), pos), "seen": false}
		var rec: Dictionary = _npc_nodes[id]
		var root := rec["root"] as Node3D
		if rec["seen"]:
			root.global_position = root.global_position.lerp(pos, 0.25)
		else:
			root.global_position = pos
			rec["seen"] = true
	for id in _npc_nodes.keys():
		if not seen.has(id):
			(_npc_nodes[id]["root"] as Node3D).queue_free()
			_npc_nodes.erase(id)
	if _npc_nodes.size() != _last_npc_shown:
		_last_npc_shown = _npc_nodes.size()
		print("[npc] showing %d ambient NPC(s)" % _npc_nodes.size())

# Render the zone's NAMED NPCs (from the snapshot's named_npcs) as distinct low-poly figures via
# npc_builder, reconciled each snapshot like the ambient roster — spawn new, keep positioned, free on
# zone-leave. Purely presentation from server-provided data (id/name/kind/faction_axis/pos).
func _reconcile_named_npcs(npcs: Array) -> void:
	var seen := {}
	for entry in npcs:
		var npc: Dictionary = entry
		var id := String(npc.get("id", ""))
		if id == "" or _npc_builder == null:
			continue
		seen[id] = true
		var p: Dictionary = npc.get("pos", {})
		var pos := Vector3(float(p.get("x", 0.0)), float(p.get("y", 1.2)), float(p.get("z", 0.0)))
		if not _named_npc_nodes.has(id):
			var root: Node3D = _npc_builder.build_npc(String(npc.get("kind", "civilian")), String(npc.get("name", id)), String(npc.get("faction_axis", "independent")))
			add_child(root)
			root.global_position = pos
			_named_npc_nodes[id] = {"root": root}
	for id in _named_npc_nodes.keys():
		if not seen.has(id):
			(_named_npc_nodes[id]["root"] as Node3D).queue_free()
			_named_npc_nodes.erase(id)
	if _named_npc_nodes.size() != _last_named_npc_shown:
		_last_named_npc_shown = _named_npc_nodes.size()
		print("[npc] showing %d named NPC(s)" % _named_npc_nodes.size())

func _spawn_npc(npc_id: String, kind: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "NPC_%s" % npc_id
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.6
	mesh.mesh = capsule
	mesh.position.y = 0.8
	var material := StandardMaterial3D.new()
	var hue := fposmod(float(absi(hash(kind))) * 0.6180339887, 1.0)
	material.albedo_color = Color.from_hsv(hue, 0.22, 0.62)  # muted/desaturated vs. saturated players
	material.roughness = 0.95
	mesh.material_override = material
	root.add_child(mesh)
	var label := Label3D.new()
	label.text = kind.replace("_", " ")
	label.position.y = 1.95
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.modulate = Color(0.20, 0.18, 0.14)
	root.add_child(label)
	add_child(root)  # must be in the tree BEFORE global_position (else !is_inside_tree() spam)
	root.global_position = pos
	return root

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 74
	_camera.current = true
	add_child(_camera)  # must be in the tree BEFORE global_position (else !is_inside_tree() spam)
	_camera.global_position = Vector3(-20, 1.75, -4.0)

func _build_hud() -> void:
	_hud = UnifiedHUD.new()
	_hud.name = "HUD"
	add_child(_hud)
	
	# Map standard status and logs to the bottom log feed
	_status = _hud._log_label
	_combat_log = _hud._log_label
	_zone_label = _hud._telemetry_label
	
	# Place client-side status badges inside the left panel
	_wallet_label = Label.new()
	_wallet_label.add_theme_font_size_override("font_size", 12)
	_hud._left_panel.add_child(_wallet_label)
	_wallet_label.position = Vector2(12, 34)
	
	_condition_label = Label.new()
	_condition_label.add_theme_font_size_override("font_size", 12)
	_hud._left_panel.add_child(_condition_label)
	_condition_label.position = Vector2(12, 54)
	
	_boost_label = Label.new()
	_boost_label.add_theme_font_size_override("font_size", 12)
	_hud._left_panel.add_child(_boost_label)
	_boost_label.position = Vector2(12, 74)
	
	_ammo_label = Label.new()
	_ammo_label.add_theme_font_size_override("font_size", 12)
	_hud._left_panel.add_child(_ammo_label)
	_ammo_label.position = Vector2(12, 94)

	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 12)
	_hud._left_panel.add_child(_credits_label)
	_credits_label.position = Vector2(12, 114)

	_target_label = Label.new()
	_target_label.add_theme_font_size_override("font_size", 12)
	_hud._left_panel.add_child(_target_label)
	_target_label.position = Vector2(12, 134)

	_org_label = Label.new()
	_org_label.add_theme_font_size_override("font_size", 12)
	_hud._left_panel.add_child(_org_label)
	_org_label.position = Vector2(12, 154)
	
	# Resize left panel to fit all network labels
	_hud._left_panel.size = Vector2(250, 185)

	# Hide default stats loop of UnifiedHUD since multiplayer tracks its own sheet
	_hud.set_process(false)
	if _hud._health_label != null:
		_hud._health_label.visible = false
	if _hud._force_points_label != null:
		_hud._force_points_label.visible = false
	if _hud._defense_label != null:
		_hud._defense_label.visible = false

	# Add a simple center reticule for combat targeting
	var reticule := ColorRect.new()
	reticule.color = Color(1, 1, 1, 0.5)
	reticule.custom_minimum_size = Vector2(4, 4)
	reticule.set_anchors_preset(Control.PRESET_CENTER)
	_hud.add_child(reticule)

	# Update HUD controls cheat sheet with the actual multiplayer keybinds
	if _hud._help_label != null:
		_hud._help_label.text = "Movement: WASD / Space\nLook: Mouse\nAim Blaster: RMB (+1D)\nFire Blaster: LMB\nInteract / Talk: E\n\n[V] Character Sheet\n[M] Space Map / Bridge\n[B] Open Shop\n[J] Quest Bulletin\n[U] Survey Area\n[I] Manual Harvest\n[O] Crafting Station\n[H] First Aid (nearest)\n[C] Spend CP (+1D/ea)\n[F] Toggle Force Point\n[X] Toggle Cover (1/4)\n[Z] Toggle Active Dodge\n[G] Defensive Full Dodge\n[T] Change Zone (travel)"
		_hud._right_panel.size = Vector2(250, 310)




	# Position Chat and news on the main container
	_news_label = Label.new()
	_news_label.position = Vector2(290, 70)
	_news_label.size = Vector2(700, 36)
	_news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_label.text = ""
	_news_label.add_theme_font_size_override("font_size", 13)
	_news_label.modulate = Color(0.9, 0.8, 0.4)
	_hud._root.add_child(_news_label)

	_chat_log = Label.new()
	_chat_log.position = Vector2(290, 114)
	_chat_log.size = Vector2(700, 320)
	_chat_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_log.text = "Chat log idle."
	_chat_log.add_theme_font_size_override("font_size", 13)
	_chat_log.modulate = Color(0.8, 0.85, 0.9)
	_hud._root.add_child(_chat_log)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Press Enter to chat (/say /ooc /org /emote) or /help..."
	_chat_input.position = Vector2(290, 450)
	_chat_input.size = Vector2(700, 34)
	_chat_input.add_theme_font_size_override("font_size", 14)
	_chat_input.text_submitted.connect(_on_chat_submitted)
	_hud._root.add_child(_chat_input)

	# Styled character sheet panel with background
	_sheet_panel = ColorRect.new()
	_sheet_panel.position = Vector2(1012, 320)
	_sheet_panel.size = Vector2(250, 220)
	_sheet_panel.color = Color(0.08, 0.09, 0.11, 0.85)
	_sheet_panel.visible = false
	_hud._root.add_child(_sheet_panel)
	
	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.35, 0.38, 0.42, 0.5)
	border.border_width = 1.0
	border.editor_only = false
	_sheet_panel.add_child(border)
	
	var sheet_label := Label.new()
	sheet_label.name = "SheetLabel"
	sheet_label.position = Vector2(12, 10)
	sheet_label.size = Vector2(226, 200)
	sheet_label.text = "Character Sheet Loading..."
	sheet_label.add_theme_font_size_override("font_size", 12)
	sheet_label.modulate = Color(0.85, 0.9, 0.85)
	sheet_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_panel.add_child(sheet_label)


	# Reticle HUD: a small, translucent neon-cyan crosshair in the center of the screen
	var reticle := Control.new()
	reticle.name = "Reticle"
	reticle.anchors_preset = Control.PRESET_CENTER
	_hud.add_child(reticle)

	
	# Horizontal line
	var h_line := ColorRect.new()
	h_line.size = Vector2(16, 2)
	h_line.position = Vector2(-8, -1)
	h_line.color = Color(0.18, 0.90, 0.96, 0.65) # neon cyan
	reticle.add_child(h_line)
	
	# Vertical line
	var v_line := ColorRect.new()
	v_line.size = Vector2(2, 16)
	v_line.position = Vector2(-1, -8)
	v_line.color = Color(0.18, 0.90, 0.96, 0.65)
	reticle.add_child(v_line)


	_build_shop_panel(_hud)
	_build_quest_panel(_hud)
	_build_crafting_panel(_hud)
	_build_bazaar_panel(_hud)
	_build_toast(_hud)
	_build_death_overlay(_hud)
	_build_downed_panel(_hud)
	_build_onboarding_panel(_hud)



func _build_onboarding_panel(layer: CanvasLayer) -> void:
	_onboarding_panel = Panel.new()
	_onboarding_panel.name = "OnboardingPanel"
	_onboarding_panel.custom_minimum_size = Vector2(460, 360)
	_onboarding_panel.set_anchors_preset(Control.PRESET_CENTER)
	_onboarding_panel.visible = false
	layer.add_child(_onboarding_panel)

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.18, 0.90, 0.96, 0.8) # neon cyan
	_onboarding_panel.add_theme_stylebox_override("panel", style_box)

	var r_label := RichTextLabel.new()
	r_label.bbcode_enabled = true
	r_label.text = "[center][b]Welcome to Mos Eisley![/b][/center]\n\n[b]CONTROLS:[/b]\n• [color=#2ee6f5]WASD[/color] to move, [color=#2ee6f5]Mouse[/color] to look.\n• [color=#2ee6f5]Right Click[/color] to aim (+1D), [color=#2ee6f5]Left Click[/color] to fire.\n• [color=#2ee6f5]F[/color]: Toggle Auto-fire (combat windows).\n• [color=#2ee6f5]X[/color]: Take Cover (+Def, -Atk).\n• [color=#2ee6f5]TAB[/color]: Target. [color=#2ee6f5]E[/color]: Interact.\n• [color=#2ee6f5]ENTER[/color]: Chat. [color=#2ee6f5]V[/color]: Character Sheet.\n• [color=#2ee6f5]B[/color]: Shop. [color=#2ee6f5]J[/color]: Quests. [color=#2ee6f5]M[/color]: Travel.\n\n[b]THE LOOP:[/b]\n1. Spar the dummy (red sphere) to earn CP.\n2. Spend CP ([color=#2ee6f5]C[/color]) to raise Blaster/Dodge.\n3. Buy gear ([color=#2ee6f5]B[/color]) at vendors.\n4. Travel ([color=#2ee6f5]T[/color]) to Contested/Lawless zones.\n5. Danger: PvP + lethal death (durability loss).\n\n[center][color=#888888]Press [Esc] or click here to dismiss.[/color][/center]"
	r_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	r_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_onboarding_panel.add_child(r_label)

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.pressed.connect(func():
		_onboarding_panel.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
	_onboarding_panel.add_child(btn)

# Wave F economy: a real, clickable shop overlay (hidden until B). Populated from the
# server-priced vendor_listed payload; Buy/Sell buttons call Net.send_buy/Net.send_sell.
func _build_shop_panel(layer: CanvasLayer) -> void:
	_shop_panel = Panel.new()
	_shop_panel.name = "ShopPanel"
	_shop_panel.position = Vector2(360, 96)
	_shop_panel.size = Vector2(600, 430)
	_shop_panel.visible = false
	layer.add_child(_shop_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 12)
	vbox.size = Vector2(568, 406)
	vbox.add_theme_constant_override("separation", 6)
	_shop_panel.add_child(vbox)

	_shop_title = Label.new()
	_shop_title.text = "Vendor"
	_shop_title.add_theme_font_size_override("font_size", 19)
	vbox.add_child(_shop_title)

	var hint := Label.new()
	hint.text = "Click Buy / Sell — B or Esc to close"
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(568, 356)
	vbox.add_child(scroll)

	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_shop_list)

func _build_quest_panel(layer: CanvasLayer) -> void:
	_quest_panel = Panel.new()
	_quest_panel.name = "QuestPanel"
	_quest_panel.position = Vector2(360, 96)
	_quest_panel.size = Vector2(600, 430)
	_quest_panel.visible = false
	layer.add_child(_quest_panel)

	# Style panel background
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.35, 0.38, 0.42, 0.6)
	_quest_panel.add_theme_stylebox_override("panel", style_box)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 12)
	vbox.size = Vector2(568, 406)
	vbox.add_theme_constant_override("separation", 6)
	_quest_panel.add_child(vbox)

	var header := Label.new()
	header.text = "MISSION BULLETIN & JOURNAL"
	header.add_theme_font_size_override("font_size", 16)
	header.modulate = Color(0.18, 0.90, 0.96) # bright cyan
	vbox.add_child(header)

	var hint := Label.new()
	hint.text = "Accept missions from the bulletin or claim completed rewards. J or Esc to close."
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(568, 356)
	vbox.add_child(scroll)

	_quest_list = VBoxContainer.new()
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_quest_list)

func _toggle_quest_panel() -> void:
	if _quest_open:
		_close_quest_panel()
	else:
		_open_quest_panel()

func _open_quest_panel() -> void:
	if _shop_open:
		_close_shop()
	_quest_open = true
	if _quest_panel != null:
		_quest_panel.visible = true
		_refresh_quest_panel()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_status("Journal open — click Accept/Claim · J or Esc to close.")

func _close_quest_panel() -> void:
	_quest_open = false
	if _quest_panel != null:
		_quest_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_quest_panel() -> void:
	if _quest_list == null:
		return
	
	for child in _quest_list.get_children():
		child.queue_free()
		
	var catalog := Net.quest_catalog
	var player_quests := Net.last_quests
	
	if catalog.is_empty():
		var label := Label.new()
		label.text = "Bulletin Board empty. Loading missions..."
		label.add_theme_font_size_override("font_size", 13)
		_quest_list.add_child(label)
		return
		
	for qid in catalog.keys():
		var def: Dictionary = catalog[qid]
		var qname := String(def.get("name", qid))
		var qdesc := String(def.get("description", ""))
		var reward_creds := int((def.get("reward", {}) as Dictionary).get("credits", 0))
		var reward_cp := int((def.get("reward", {}) as Dictionary).get("cp", 0))
		
		var obj: Dictionary = def.get("objective", {})
		var obj_kind := String(obj.get("kind", ""))
		var obj_count := int(obj.get("count", 1))
		var obj_detail := ""
		match obj_kind:
			"disable":
				var target := String(obj.get("target_key", ""))
				if target != "":
					obj_detail = "Eliminate %d %s" % [obj_count, target.capitalize()]
				else:
					obj_detail = "Eliminate %d hostiles" % obj_count
			"reach_zone":
				obj_detail = "Reach security zone: %s" % String(obj.get("zone_id", ""))
			"earn_credits":
				obj_detail = "Accrue %d credits" % obj_count
			_:
				obj_detail = "Complete objective"
				
		var row := ColorRect.new()
		row.custom_minimum_size = Vector2(568, 80)
		row.color = Color(0.12, 0.14, 0.16, 0.6)
		_quest_list.add_child(row)
		
		var title_label := Label.new()
		title_label.text = qname
		title_label.position = Vector2(10, 8)
		title_label.add_theme_font_size_override("font_size", 14)
		title_label.modulate = Color(0.9, 0.9, 0.8)
		row.add_child(title_label)
		
		var desc_label := Label.new()
		desc_label.text = "%s\nObjective: %s" % [qdesc, obj_detail]
		desc_label.position = Vector2(10, 26)
		desc_label.size = Vector2(400, 50)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.modulate = Color(0.7, 0.7, 0.7)
		row.add_child(desc_label)
		
		var reward_label := Label.new()
		reward_label.text = "Reward: %d cr | %d CP" % [reward_creds, reward_cp]
		reward_label.position = Vector2(420, 8)
		reward_label.add_theme_font_size_override("font_size", 11)
		reward_label.modulate = Color(0.48, 0.90, 0.55)
		row.add_child(reward_label)
		
		var action_btn := Button.new()
		action_btn.size = Vector2(120, 26)
		action_btn.position = Vector2(420, 34)
		action_btn.add_theme_font_size_override("font_size", 11)
		row.add_child(action_btn)
		
		if not player_quests.has(qid):
			action_btn.text = "Accept"
			# We use a helper function to avoid lambda scope capture issues in connect
			action_btn.pressed.connect(_on_accept_quest_btn.bind(qid, qname))
		else:
			var st: Dictionary = player_quests[qid]
			var complete := bool(st.get("complete", false))
			var claimed := bool(st.get("claimed", false))
			var progress := int(st.get("progress", 0))
			
			if claimed:
				action_btn.text = "Completed"
				action_btn.disabled = true
			elif complete:
				action_btn.text = "Claim Reward"
				action_btn.modulate = Color(0.4, 1.0, 0.4)
				action_btn.pressed.connect(_on_claim_quest_btn.bind(qid, qname))
			else:
				action_btn.text = "Progress: %d/%d" % [progress, obj_count]
				action_btn.disabled = true

func _on_accept_quest_btn(qid: String, qname: String) -> void:
	Net.send_accept_quest(qid)
	_set_status("Accepted quest: %s" % qname)
	_toast("Quest Accepted: %s" % qname, Color(0.18, 0.90, 0.96))
	get_tree().create_timer(0.25).timeout.connect(_refresh_quest_panel)

func _on_claim_quest_btn(qid: String, qname: String) -> void:
	Net.send_claim_quest(qid)
	_set_status("Claiming reward for quest: %s" % qname)
	get_tree().create_timer(0.25).timeout.connect(_refresh_quest_panel)

# --- Surveying and Crafting UI (SWG Playable Alpha Loop) ---

func _build_crafting_panel(layer: CanvasLayer) -> void:
	_crafting_panel = Panel.new()
	_crafting_panel.name = "CraftingPanel"
	_crafting_panel.position = Vector2(360, 96)
	_crafting_panel.size = Vector2(600, 430)
	_crafting_panel.visible = false
	layer.add_child(_crafting_panel)

	# Style panel background (glassmorphism/premium look matching quest/shop)
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.09, 0.08, 0.12, 0.94)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.40, 0.35, 0.48, 0.6)
	_crafting_panel.add_theme_stylebox_override("panel", style_box)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 12)
	vbox.size = Vector2(568, 406)
	vbox.add_theme_constant_override("separation", 6)
	_crafting_panel.add_child(vbox)

	var header := Label.new()
	header.text = "SWG CRAFTING WORKSTATION & SCHEMATICS"
	header.add_theme_font_size_override("font_size", 16)
	header.modulate = Color(0.70, 0.50, 0.95) # violet/purple tint
	vbox.add_child(header)

	var hint := Label.new()
	hint.text = "Synthesize items from raw resources. O or Esc to close."
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(568, 356)
	vbox.add_child(scroll)

	_crafting_list = VBoxContainer.new()
	_crafting_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crafting_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_crafting_list)

func _toggle_crafting_panel() -> void:
	if _crafting_open:
		_close_crafting_panel()
	else:
		_open_crafting_panel()

func _open_crafting_panel() -> void:
	_close_all_overlays() # Close quest and shop panels to avoid UI overlap
	_crafting_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _crafting_panel != null:
		_crafting_panel.visible = true
		_refresh_crafting_panel()

func _close_crafting_panel() -> void:
	_crafting_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _crafting_panel != null:
		_crafting_panel.visible = false

func _refresh_crafting_panel() -> void:
	if _crafting_list == null:
		return
	for child in _crafting_list.get_children():
		child.queue_free()

	var sheet: Dictionary = {}
	if Net.mode == Net.Mode.CLIENT and Net._local_sheet.has("sheet"):
		sheet = Net._local_sheet.get("sheet", {})
	
	var resources: Dictionary = sheet.get("resources", {})
	
	var mat_header := Label.new()
	mat_header.text = "YOUR STASH:"
	mat_header.add_theme_font_size_override("font_size", 11)
	mat_header.modulate = Color(0.6, 0.6, 0.7)
	_crafting_list.add_child(mat_header)
	
	var ores = resources.get("copper_ore", {"count": 0, "quality": 0.0})
	var sands = resources.get("silicate_sand", {"count": 0, "quality": 0.0})
	var hides = resources.get("animal_hide", {"count": 0, "quality": 0.0})
	
	var stash_lbl := Label.new()
	stash_lbl.text = "• Copper Ore: %d units (Q: %d%%)   • Silicate Sand: %d units (Q: %d%%)   • Animal Hides: %d units (Q: %d%%)" % [
		int(ores.get("count", 0)), int(ores.get("quality", 0.0)),
		int(sands.get("count", 0)), int(sands.get("quality", 0.0)),
		int(hides.get("count", 0)), int(hides.get("quality", 0.0))
	]
	stash_lbl.add_theme_font_size_override("font_size", 12)
	stash_lbl.modulate = Color(0.85, 0.85, 0.90)
	_crafting_list.add_child(stash_lbl)
	
	var spacer := ColorRect.new()
	spacer.custom_minimum_size = Vector2(568, 1)
	spacer.color = Color(0.3, 0.3, 0.35, 0.5)
	_crafting_list.add_child(spacer)

	var schematics: Array = CraftingModel.get_schematics()
	for sch_val in schematics:
		if not sch_val is Dictionary:
			continue
		var sch := sch_val as Dictionary
		var key: String = sch.get("key", "")
		var item_name: String = sch.get("name", "")
		var reqs: Dictionary = sch.get("requires", {})

		
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(550, 75)
		
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.12, 0.11, 0.15, 0.85)
		box.border_width_left = 1
		box.border_color = Color(0.45, 0.40, 0.55, 0.4)
		panel.add_theme_stylebox_override("panel", box)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		panel.add_child(hbox)
		
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(info_vbox)
		
		var name_lbl := Label.new()
		name_lbl.text = item_name
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.modulate = Color(0.82, 0.72, 0.98)
		info_vbox.add_child(name_lbl)
		
		var req_str := "Requires: "
		var can_craft := true
		for res_type in reqs.keys():
			var req_cnt = int(reqs[res_type])
			var cur_cnt = int(resources.get(res_type, {}).get("count", 0))
			var color_tag = "[color=#66ff66]" if cur_cnt >= req_cnt else "[color=#ff6666]"
			var r_name = res_type.replace("_", " ").capitalize()
			req_str += "%s%d/%d %s[/color]  " % [color_tag, cur_cnt, req_cnt, r_name]
			if cur_cnt < req_cnt:
				can_craft = false
				
		var req_lbl := RichTextLabel.new()
		req_lbl.bbcode_enabled = true
		req_lbl.text = req_str
		req_lbl.custom_minimum_size = Vector2(360, 24)
		req_lbl.scroll_active = false
		info_vbox.add_child(req_lbl)
		
		var btn_container := VBoxContainer.new()
		btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(btn_container)
		
		var craft_btn := Button.new()
		craft_btn.text = "Craft Schematic"
		craft_btn.disabled = not can_craft
		craft_btn.custom_minimum_size = Vector2(130, 32)
		craft_btn.pressed.connect(_on_craft_btn.bind(key))
		btn_container.add_child(craft_btn)
		
		_crafting_list.add_child(panel)

func _on_craft_btn(item_type: String) -> void:
	Net.send_craft(item_type)
	_set_status("Synthesizing: %s..." % item_type.capitalize())

func _build_bazaar_panel(layer: CanvasLayer) -> void:
	_bazaar_panel = Panel.new()
	_bazaar_panel.name = "BazaarPanel"
	_bazaar_panel.position = Vector2(360, 96)
	_bazaar_panel.size = Vector2(600, 430)
	_bazaar_panel.visible = false
	layer.add_child(_bazaar_panel)

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.10, 0.12, 0.94)
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.18, 0.65, 0.70, 0.6) # teal border
	_bazaar_panel.add_theme_stylebox_override("panel", style_box)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(16, 12)
	vbox.size = Vector2(568, 406)
	vbox.add_theme_constant_override("separation", 6)
	_bazaar_panel.add_child(vbox)

	var header := Label.new()
	header.text = "PLAYER BAZAAR MARKETPLACE"
	header.add_theme_font_size_override("font_size", 16)
	header.modulate = Color(0.18, 0.90, 0.96) # bright cyan
	vbox.add_child(header)

	var hint := Label.new()
	hint.text = "List your crafted goods or purchase items. L or Esc to close."
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(568, 356)
	vbox.add_child(tabs)

	# Tab 1: Browse Market
	var browse_vbox := VBoxContainer.new()
	browse_vbox.name = "Browse Market"
	tabs.add_child(browse_vbox)

	var browse_scroll := ScrollContainer.new()
	browse_scroll.custom_minimum_size = Vector2(550, 310)
	browse_vbox.add_child(browse_scroll)

	_bazaar_list = VBoxContainer.new()
	_bazaar_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bazaar_list.add_theme_constant_override("separation", 8)
	browse_scroll.add_child(_bazaar_list)

	# Tab 2: Sell Items
	var sell_vbox := VBoxContainer.new()
	sell_vbox.name = "List Items"
	tabs.add_child(sell_vbox)

	var sell_scroll := ScrollContainer.new()
	sell_scroll.custom_minimum_size = Vector2(550, 310)
	sell_vbox.add_child(sell_scroll)

	_inventory_sell_list = VBoxContainer.new()
	_inventory_sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_sell_list.add_theme_constant_override("separation", 8)
	sell_scroll.add_child(_inventory_sell_list)

func _toggle_bazaar_panel() -> void:
	if _bazaar_open:
		_close_bazaar_panel()
	else:
		_open_bazaar_panel()

func _open_bazaar_panel() -> void:
	_close_all_overlays()
	_bazaar_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _bazaar_panel != null:
		_bazaar_panel.visible = true
		Net.send_request_bazaar_listings()
		_refresh_bazaar_panel()
	_set_status("Bazaar open — click Buy or List Items.")

func _close_bazaar_panel() -> void:
	_bazaar_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _bazaar_panel != null:
		_bazaar_panel.visible = false

func _refresh_bazaar_panel() -> void:
	if _bazaar_list == null or _inventory_sell_list == null:
		return
	
	# Clear lists
	for child in _bazaar_list.get_children():
		child.queue_free()
	for child in _inventory_sell_list.get_children():
		child.queue_free()

	# Populate Active Listings
	if _bazaar_listings.is_empty():
		var label := Label.new()
		label.text = "No listings currently active on the Bazaar."
		label.add_theme_font_size_override("font_size", 12)
		_bazaar_list.add_child(label)
	else:
		for listing_id in _bazaar_listings.keys():
			var l: Dictionary = _bazaar_listings[listing_id]
			var price := int(l.get("price", 0))
			var item: Dictionary = l.get("item", {})
			var name := String(item.get("display_name", item.get("name", "Unknown Item")))
			var quality := float(item.get("quality", 50.0))
			var cond := int(item.get("condition", 1))
			var max_cond := int(item.get("max_condition", 1))
			var seller := String(l.get("seller_id", "Unknown Seller"))

			var row := ColorRect.new()
			row.custom_minimum_size = Vector2(540, 60)
			row.color = Color(0.12, 0.14, 0.16, 0.6)
			_bazaar_list.add_child(row)

			var info_lbl := Label.new()
			info_lbl.text = "%s (Q: %.1f%%, Cond: %d/%d)\nSeller: %s · Price: %d credits" % [name, quality, cond, max_cond, seller, price]
			info_lbl.position = Vector2(12, 10)
			info_lbl.add_theme_font_size_override("font_size", 12)
			info_lbl.modulate = Color(0.85, 0.95, 0.95)
			row.add_child(info_lbl)

			var buy_btn := Button.new()
			buy_btn.text = "Buy Item"
			buy_btn.size = Vector2(100, 26)
			buy_btn.position = Vector2(430, 17)
			buy_btn.add_theme_font_size_override("font_size", 11)
			buy_btn.pressed.connect(_on_buy_bazaar_item.bind(listing_id))
			row.add_child(buy_btn)

	# Populate Player Inventory for selling
	var sheet: Dictionary = Net.last_sheet

	var inventory: Array = sheet.get("inventory", [])
	var filtered_inv: Array = []
	for val in inventory:
		if val is Dictionary:
			filtered_inv.append(val)

	if filtered_inv.is_empty():
		var label := Label.new()
		label.text = "You have no items in your inventory that can be listed."
		label.add_theme_font_size_override("font_size", 12)
		_inventory_sell_list.add_child(label)
	else:
		for item in filtered_inv:
			var item_id := String(item.get("instance_id", item.get("id", "")))
			if item_id == "":
				continue
			var name := String(item.get("display_name", item.get("name", "Unknown Item")))
			var quality := float(item.get("quality", 50.0))
			var cond := int(item.get("condition", 1))
			var max_cond := int(item.get("max_condition", 1))

			var row := ColorRect.new()
			row.custom_minimum_size = Vector2(540, 60)
			row.color = Color(0.12, 0.14, 0.16, 0.6)
			_inventory_sell_list.add_child(row)

			var info_lbl := Label.new()
			info_lbl.text = "%s (Q: %.1f%%, Cond: %d/%d)" % [name, quality, cond, max_cond]
			info_lbl.position = Vector2(12, 20)
			info_lbl.add_theme_font_size_override("font_size", 12)
			info_lbl.modulate = Color(0.85, 0.95, 0.95)
			row.add_child(info_lbl)

			var price_edit := LineEdit.new()
			price_edit.placeholder_text = "Price"
			price_edit.size = Vector2(80, 26)
			price_edit.position = Vector2(330, 17)
			price_edit.add_theme_font_size_override("font_size", 11)
			row.add_child(price_edit)

			var list_btn := Button.new()
			list_btn.text = "List (5% fee)"
			list_btn.size = Vector2(100, 26)
			list_btn.position = Vector2(430, 17)
			list_btn.add_theme_font_size_override("font_size", 11)
			list_btn.pressed.connect(_on_list_bazaar_item.bind(item_id, price_edit))
			row.add_child(list_btn)

func _on_buy_bazaar_item(listing_id: String) -> void:
	Net.send_bazaar_buy(listing_id)
	_set_status("Sending purchase request to server...")

func _on_list_bazaar_item(item_id: String, price_edit: LineEdit) -> void:
	var price_text := price_edit.text
	var price := int(price_text)
	if price <= 0:
		_set_status("Invalid price: must be greater than 0.")
		_toast("Invalid Price", Color(0.9, 0.3, 0.3))
		return
	Net.send_bazaar_list(item_id, price)
	_set_status("Sending listing request to server...")

func _on_bazaar_listings_updated(listings: Dictionary) -> void:
	_bazaar_listings = listings
	if _bazaar_open:
		_refresh_bazaar_panel()

func _on_bazaar_list_replied(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_set_status("Item listed on Bazaar successfully!")
		_toast("Item Listed!", Color(0.18, 0.90, 0.55))
		if _bazaar_open:
			_refresh_bazaar_panel()
	else:
		var reason = String(result.get("reason", "failed"))
		_set_status("Listing failed: " + reason)
		_toast("Listing Failed", Color(0.9, 0.3, 0.3))

func _on_bazaar_buy_replied(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_set_status("Purchased item from Bazaar successfully!")
		_toast("Item Purchased!", Color(0.18, 0.90, 0.55))
		if _bazaar_open:
			_refresh_bazaar_panel()
	else:
		var reason = String(result.get("reason", "failed"))
		_set_status("Purchase failed: " + reason)
		_toast("Purchase Failed", Color(0.9, 0.3, 0.3))

func _close_all_overlays() -> void:
	if _quest_open:
		_close_quest_panel()
	if _shop_open:
		_close_shop()
	if _crafting_open:
		_close_crafting_panel()
	if _bazaar_open:
		_close_bazaar_panel()


func _on_survey_replied(res: Dictionary) -> void:
	if not res.get("ok", false):
		_set_status("Survey scan returned no results.")
		return
	var r_name: String = res.get("name", "")
	var dist = int(res.get("distance", 0))
	var qual = int(res.get("quality", 0))
	var msg := "Survey: Located %s (Quality: %d%%) at distance %dm. Press I to harvest!" % [
		r_name, qual, dist
	]
	_log_message(msg)
	_toast("Resource Spotted!", Color(0.70, 0.50, 0.95))

func _on_harvest_replied(res: Dictionary) -> void:
	if not res.get("ok", false):
		_set_status("Harvest failed: " + String(res.get("reason", "unknown error")))
		return
	var r_type: String = res.get("type", "")
	var count = int(res.get("count", 0))
	var qual = int(res.get("quality", 0))
	var r_name = r_type.replace("_", " ").capitalize()
	var msg := "Harvest: Extracted %d units of %s (Quality: %d%%)!" % [count, r_name, qual]
	_log_message(msg)
	_toast("+%d %s" % [count, r_name], Color(0.40, 0.95, 0.40))
	if _crafting_open:
		_refresh_crafting_panel()

func _on_craft_replied(res: Dictionary) -> void:
	if not res.get("ok", false):
		_set_status("Craft failed: " + String(res.get("reason", "unknown error")))
		_toast("Synthesis Failed", Color(0.95, 0.40, 0.40))
		return
	var item_type: String = res.get("item_type", "")
	var qual = int(res.get("quality", 0))
	var msg := "Craft: Successfully synthesized %s (Item Quality: %d%%)!" % [
		item_type.capitalize(), qual
	]
	_log_message(msg)
	_toast("Synthesis Successful!", Color(0.70, 0.50, 0.95))
	if _crafting_open:
		_refresh_crafting_panel()

func _log_message(msg: String) -> void:
	print("[system] %s" % msg)
	_combat_lines.append(msg)
	while _combat_lines.size() > 8:
		_combat_lines.pop_front()
	if _combat_log != null:
		_combat_log.text = "Combat log:\n" + "\n".join(_combat_lines)

# Transient HUD toast (fades out): loot/credit gains, buy/sell, Force-awakening.


func _build_toast(layer: CanvasLayer) -> void:
	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.position = Vector2(18, 264)
	_toast_label.add_theme_font_size_override("font_size", 21)
	_toast_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.82))
	_toast_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02))
	_toast_label.add_theme_constant_override("outline_size", 6)
	_toast_label.modulate = Color(1, 1, 1, 0)
	_toast_label.text = ""
	layer.add_child(_toast_label)

# DIV-0006: a full-screen death card that fades in, holds, and fades out.
func _build_death_overlay(layer: CanvasLayer) -> void:
	_death_overlay = ColorRect.new()
	_death_overlay.name = "DeathOverlay"
	_death_overlay.color = Color(0.32, 0.03, 0.03, 0.0)
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never intercept shop/chat clicks
	_death_overlay.visible = false
	layer.add_child(_death_overlay)

	_death_label = Label.new()
	_death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_death_label.add_theme_font_size_override("font_size", 30)
	_death_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.88))
	_death_label.add_theme_color_override("font_outline_color", Color(0.10, 0.0, 0.0))
	_death_label.add_theme_constant_override("outline_size", 10)
	_death_label.text = ""
	_death_overlay.add_child(_death_label)

# DIV-0027: a persistent AMBER banner shown while downed-in-field (distinct from the red death card —
# amber = recoverable). Stays up until a medic revives you or you yield.
func _build_downed_panel(layer: CanvasLayer) -> void:
	_downed_panel = Label.new()
	_downed_panel.name = "DownedPanel"
	_downed_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_downed_panel.anchor_left = 0.5
	_downed_panel.anchor_right = 0.5
	_downed_panel.position = Vector2(-260, 96)
	_downed_panel.custom_minimum_size = Vector2(520, 0)
	_downed_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_downed_panel.add_theme_font_size_override("font_size", 22)
	_downed_panel.add_theme_color_override("font_color", Color(0.98, 0.74, 0.28))
	_downed_panel.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.0))
	_downed_panel.add_theme_constant_override("outline_size", 8)
	_downed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_downed_panel.visible = false
	layer.add_child(_downed_panel)

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

# Show what's staged for the next shot (aim dice + any CP / Force Point spend).
func _announce_next_shot() -> void:
	var bits := "Aim +%dD" % _aim if _aim > 0 else "Next shot"
	if _spend_cp > 0:
		bits += " · +%dCP" % _spend_cp
	if _use_fp:
		bits += " · Force Point"
	if _cover > 0:
		bits += " · in cover"
	if _dodge:
		bits += " · dodging"
	_set_status("%s — LMB fires (C CP · F Force Point · X cover · Z dodge · G full-dodge)" % bits)

func _on_combat_envelope(envelope: Dictionary) -> void:
	var shooter := String(envelope.get("shooter_name", "Someone"))
	var target := String(envelope.get("target_name", "the target"))
	var hit := false
	var wound := -1
	var already := false
	var cp_spent := 0
	var fp_spent := false
	var return_fire_hit := false  # F45: did the target shoot back and connect this window?
	var return_fire_cover := 0    # F50: the player's cover applied against that return fire
	var defended := false         # F51: the shooter took a defensive stance (full dodge) this window
	var attacked_dodging := false # F52: the shooter attacked while actively dodging
	for ev in envelope.get("events", []):
		var event_type := String((ev as Dictionary).get("type", ""))
		if event_type == "player_attack":
			hit = bool((ev as Dictionary).get("success", false))
			cp_spent = int((ev as Dictionary).get("attack_cp_spent", 0))
			fp_spent = bool((ev as Dictionary).get("force_point_spent", false))
			attacked_dodging = int((ev as Dictionary).get("action_count", 1)) >= 2  # F52: dodged while attacking
		elif event_type == "target_damage":
			wound = int((ev as Dictionary).get("wound_severity", -1))
		elif event_type == "target_already_disabled":
			already = true
		elif event_type == "remote_return_fire":
			return_fire_hit = return_fire_hit or bool((ev as Dictionary).get("hit", false))
			return_fire_cover = int((ev as Dictionary).get("cover_level", 0))
		elif event_type == "player_full_dodge":
			defended = true
	# WEG in-play spend surfaced publicly on the shooter's line (both GUI + headless log).
	var spend := ""
	if cp_spent > 0:
		spend += " [+%dCP]" % cp_spent
	if fp_spent:
		spend += " [Force Point]"
	var line := ""
	if defended:
		line = "%s takes a defensive stance (full dodge)" % shooter  # F51
	elif already:
		line = "%s: %s is already down" % [shooter, target]
	elif hit:
		line = "%s hit %s%s" % [shooter, target, (" → %s" % _wound_label(wound)) if wound >= 0 else ""]
	else:
		line = "%s missed %s" % [shooter, target]
	if attacked_dodging:
		line += " (dodging)"  # F52
	line += spend
	print("[combat] %s" % line)
	_combat_lines.append(line)
	# F45: surface the target's RETURN FIRE so a sparring-wounded player sees WHY their condition
	# changed (the medical loop, DIV-0016). The shooter is also who got shot back at; state_delta
	# carries their resulting, sparring-CAPPED wound (so this matches the condition HUD, not the
	# uncapped raw event severity).
	if return_fire_hit:
		var pw := int((envelope.get("state_delta", {}) as Dictionary).get("player_wound_severity", 0))
		var cov := " (in cover)" if return_fire_cover > 0 else ""  # F50: the 1/4 cover applied to the return fire
		var rf := "%s takes return fire%s%s" % [shooter, cov, (" → %s" % _wound_label(pw)) if pw > 0 else " (no damage)"]
		print("[combat] %s" % rf)
		_combat_lines.append(rf)
	while _combat_lines.size() > 8:
		_combat_lines.pop_front()
	if _combat_log != null:
		_combat_log.text = "Combat log:\n" + "\n".join(_combat_lines)
	# F47: persistent at-a-glance TARGET status. The combat log only shows the target's wound on a
	# HIT (a miss line hides it); this always reflects the shared target's current condition.
	var tsev := int(envelope.get("target_wound_severity", 0))
	var tname := String(envelope.get("target_name", "Target"))
	var tcond := "Healthy" if tsev <= 0 else ("Disabled" if tsev >= 3 else _wound_label(tsev))
	if _target_label != null:
		_target_label.text = "Target: %s — %s" % [tname, tcond]
	var tkey := "%s|%d" % [tname, tsev]
	if tkey != _last_target:
		_last_target = tkey
		print("[target] %s %s" % [tname, tcond])
	# Task 1/4: show the thing being fought as a low-poly mesh in front of the player, plus
	# muzzle-flash / hit-spark / floating-damage feedback driven by this envelope's events.
	_render_combat_target(envelope, hit, wound)

# Update the player's own condition readout from the snapshot's "you" block. Reflects combat
# damage, natural recovery (DIV-0012), and First Aid (DIV-0013) as the server changes the wound.
func _update_condition(wound: String, penalty: int = 0, poison_rounds_left: int = 0, restrained: bool = false) -> void:
	var label := _condition_pretty(wound)
	if penalty > 0:
		label += " (-%dD to actions)" % penalty  # F46: the WEG wound penalty — why a wounded character fights worse
	# Surface live venom/restraint on the local readout too (the wound + its penalty are already
	# shown, so append only the non-wound extras: "Held" / "Poisoned (n)"). Blank when clean.
	var extra := PlayerStatusBadgeModel.extra_status_text(poison_rounds_left, restrained)
	if extra != "":
		label += " · " + extra
	# Tint toward the TOP active status (poison/held can outrank the wound); healthy + clean
	# keeps the legacy green.
	var badge := PlayerStatusBadgeModel.badge_for(wound, poison_rounds_left, restrained)
	var col := _condition_color(wound)
	if bool(badge.get("active", false)):
		col = _status_color(String(badge.get("color_key", "healthy")))
	if _condition_label != null:
		_condition_label.text = "Condition: %s" % label
		_condition_label.modulate = col
	var key := "%s|%d|%s" % [wound, poison_rounds_left, str(restrained)]
	if key != _last_condition:
		_last_condition = key
		print("[condition] you=%s penalty=-%dD%s" % [wound, penalty, (" " + extra) if extra != "" else ""])

# Map a PlayerStatusBadgeModel color_key -> the on-screen Color. The wound keys reproduce
# _condition_color exactly (so a lone-wound nameplate/HUD is byte-identical), with distinct
# tints for the new venom/restraint statuses.
func _status_color(color_key: String) -> Color:
	match color_key:
		"stunned": return Color(0.62, 0.58, 0.20)       # matches _condition_color("stunned")
		"wounded": return Color(0.70, 0.42, 0.16)        # matches _condition_color("wounded"/"wounded_twice")
		"downed": return Color(0.72, 0.20, 0.16)         # matches _condition_color(incapacitated+)
		"restrained": return Color(0.42, 0.62, 0.95)     # held — cold blue
		"poisoned": return Color(0.45, 0.78, 0.32)       # venom — sickly green
		"healthy": return Color(0.30, 0.62, 0.30)        # matches _condition_color("healthy")
		_: return Color(0.30, 0.62, 0.30)

# Update the in-combat Character-Point / Force-Point pool readout (the resource the C/F keys
# spend, F5) from the snapshot's "you" block, so a player can see how much they can spend
# before firing. Distinct from the progression CP wallet shown by the K-key wallet label.
func _update_boost(cp: int, fp: int) -> void:
	if _boost_label != null:
		_boost_label.text = "Boost (C/F): %d CP · %d FP" % [cp, fp]
	var line := "%d/%d" % [cp, fp]
	if line != _last_boost:
		_last_boost = line
		print("[boost] cp=%d fp=%d" % [cp, fp])

# DIV-0029: update the equipped-weapon ammo readout from the snapshot's "you".ammo block (built by
# network_manager._ammo_summary). Hidden for a melee / no-ammo weapon; tinted with the wound-severity
# palette (_status_color) when the magazine runs low (<20%) or fully dry (out of shots AND packs). Also
# INFERS a server auto-reload from the packs/shots diff so the player SEES the pack get spent in the
# combat log — the server's "[ammo] auto-reloaded" print never reaches the client.
func _update_ammo(ammo: Dictionary) -> void:
	# Reload inference runs against the PREVIOUS snapshot's ammo, before _prev_ammo is overwritten.
	if AmmoStatusModel.reload_happened(_prev_ammo, ammo):
		_push_combat_line("Reloaded %s — power pack spent (%d left)." % [
			_weapon_pretty(String(ammo.get("weapon", ""))), maxi(int(ammo.get("packs", 0)), 0)])
		print("[ammo] you reloaded (packs left %d)" % maxi(int(ammo.get("packs", 0)), 0))
	_prev_ammo = ammo.duplicate(true)
	if not AmmoStatusModel.should_show(ammo):
		# Melee / single_use / unloaded weapon: no ammo readout to show.
		if _ammo_label != null:
			_ammo_label.text = ""
		_last_ammo = ""
		return
	var text := AmmoStatusModel.readout_text(ammo)
	if _ammo_label != null:
		_ammo_label.text = text
		_ammo_label.modulate = _status_color(AmmoStatusModel.color_key(ammo))
	if text != _last_ammo:
		_last_ammo = text
		print("[ammo] you %s%s" % [text, "  LOW" if AmmoStatusModel.is_low(ammo) else ""])

# Append one line to the combat-log HUD, bounded to the last 8 (matching the inline call sites).
func _push_combat_line(text: String) -> void:
	_combat_lines.append(text)
	while _combat_lines.size() > 8:
		_combat_lines.pop_front()
	if _combat_log != null:
		_combat_log.text = "Combat log:\n" + "\n".join(_combat_lines)

# Prettify a weapon key for HUD text (the client has no weapons catalog). "" -> "your weapon".
func _weapon_pretty(weapon_key: String) -> String:
	if weapon_key == "":
		return "your weapon"
	return weapon_key.replace("_", " ").capitalize()

# Update the org / territory readout from the snapshot's per-peer "territory" block (E23).
# Shows the player's org, its treasury, and how many of the CURRENT zone's claimed nodes its
# org holds vs the zone TOTAL (yours/total — territory control at a glance). `claims_in_zone`
# carries EVERY org's claim (each tagged with org_id), so own-org is filtered out. Updates as
# you travel (DIV-0014); blank for a player with no org.
func _update_org(territory: Dictionary) -> void:
	var org_id := String(territory.get("org_id", ""))
	var line := ""
	var mine := 0
	var total := 0
	var rank := int(territory.get("your_rank", 0))
	if org_id != "":
		var treasury := int(territory.get("treasury", 0))
		for c in territory.get("claims_in_zone", []):
			total += 1
			if String((c as Dictionary).get("org_id", "")) == org_id:
				mine += 1
		# F34: show the viewer's faction RANK + what it authorizes (claim at rank_claim,
		# found-a-city at rank_city) so territory authority isn't opaque until a rejected claim.
		# F53: + how many org-mates are online (coordination presence).
		var members := int(territory.get("org_members_online", 0))
		line = "Org: %s · %s · %d cr · %d online · %d/%d claim(s) here" % [_org_pretty(org_id), _rank_pretty(rank, territory), treasury, members, mine, total]
	if _org_label != null:
		_org_label.text = line
	if line != _last_org_line:
		_last_org_line = line
		if line != "":
			print("[org] %s rank=%d treasury=%d members=%d claims_here=%d/%d" % [org_id, rank, int(territory.get("treasury", 0)), int(territory.get("org_members_online", 0)), mine, total])

# F34: render a faction rank as its territory authority, using thresholds the server sends.
func _rank_pretty(rank: int, territory: Dictionary) -> String:
	var rank_claim := int(territory.get("rank_claim", 3))
	var rank_city := int(territory.get("rank_city", 5))
	if rank >= rank_city:
		return "rank %d (org leader)" % rank
	if rank >= rank_claim:
		return "rank %d (can claim)" % rank
	return "rank %d (need %d to claim)" % [rank, rank_claim]

func _org_pretty(org_id: String) -> String:
	var s := org_id.trim_prefix("org_").replace("_", " ")
	return s.capitalize() if s != "" else org_id

# F35: faction axes by zone influence (desc, nonzero only) → [[axis, inf], ...].
func _sorted_influence(influence: Dictionary) -> Array:
	var pairs: Array = []
	for axis in influence:
		var v := int(influence[axis])
		if v > 0:
			pairs.append([String(axis), v])
	pairs.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	return pairs

# F35: the zone-control HUD string — the top two factions ("Republic 55 · Hutt 42").
func _control_summary(ranked: Array) -> String:
	if ranked.is_empty():
		return "uncontested"
	var parts: Array[String] = []
	for i in range(mini(2, ranked.size())):
		parts.append("%s %d" % [_axis_pretty(String(ranked[i][0])), int(ranked[i][1])])
	return " · ".join(parts)

func _axis_pretty(axis: String) -> String:
	match axis:
		"republic": return "Republic"
		"cis": return "CIS"
		"hutt": return "Hutt"
		"independent": return "Indep."
	return axis.capitalize()

func _condition_pretty(wound: String) -> String:
	match wound:
		"healthy": return "Healthy"
		"stunned": return "Stunned"
		"wounded": return "Wounded"
		"wounded_twice": return "Wounded Twice"
		"incapacitated": return "Incapacitated"
		"mortally_wounded": return "Mortally Wounded"
		"dead": return "Dead"
		_: return wound

func _condition_color(wound: String) -> Color:
	match wound:
		"healthy": return Color(0.30, 0.62, 0.30)
		"stunned": return Color(0.62, 0.58, 0.20)
		"wounded", "wounded_twice": return Color(0.70, 0.42, 0.16)
		_: return Color(0.72, 0.20, 0.16)

func _wound_label(severity: int) -> String:
	match severity:
		0: return "no damage"
		1: return "Stunned"
		2: return "Wounded"
		3: return "Incapacitated"
		4: return "Mortally Wounded"
		_: return "Killed"

func _on_wallet_updated(wallet: Dictionary) -> void:
	if _wallet_label != null:
		_wallet_label.text = "CP: gameplay %d · prestige %d   (K: raise Blaster)" % [
			int(wallet.get("gameplay_cp", 0)), int(wallet.get("rp_cp", 0))]
	print("[cp] wallet g=%d r=%d" % [int(wallet.get("gameplay_cp", 0)), int(wallet.get("rp_cp", 0))])

# Wave F economy: the player's credit balance (pushed on login + every buy/sell/loot).
func _on_credits_updated(credits: int) -> void:
	if _credits_label != null:
		_credits_label.text = "Credits: %d   (B: shop)" % credits
	if credits != _last_credits:
		# Toast a GAIN (loot/sale) — but not the initial login sync (_last_credits == -1).
		if _last_credits >= 0 and credits > _last_credits:
			_toast("+%d credits" % (credits - _last_credits), Color(0.55, 0.90, 0.48))
		_last_credits = credits
		print("[credits] balance=%d" % credits)
	if _shop_open and _shop_title != null:  # keep the open shop's credit line live
		_shop_title.text = "Vendor — Credits: %d" % credits

# DIV-0020: the notice-board quest catalog arrived (login). Client stores it in Net.quest_catalog.
func _on_quest_catalog(defs: Dictionary) -> void:
	print("[quest] notice board: %d quests available" % defs.size())
	if _quest_open:
		_refresh_quest_panel()

# DIV-0020: this client's authoritative quest progress changed. Toast complete/claim transitions and
# print a greppable per-quest state line (the full quest panel is a follow-up presentation slice).
func _on_quests_updated(quests: Dictionary) -> void:
	for qid in quests:
		var st: Dictionary = quests[qid]
		var was: Dictionary = _prev_quests.get(qid, {})
		var qname := String((Net.quest_catalog.get(qid, {}) as Dictionary).get("name", qid))
		if bool(st.get("complete", false)) and not bool(was.get("complete", false)):
			_toast("Quest complete: %s" % qname, Color(0.95, 0.85, 0.35))
		if bool(st.get("claimed", false)) and not bool(was.get("claimed", false)):
			_toast("Quest reward claimed: %s" % qname, Color(0.55, 0.90, 0.48))
		print("[quest] %s progress=%d complete=%s claimed=%s" % [
			qid, int(st.get("progress", 0)), str(bool(st.get("complete", false))), str(bool(st.get("claimed", false)))])
	_prev_quests = quests.duplicate(true)
	if _quest_open:
		_refresh_quest_panel()


# Wave F economy: the vendor's priced stock. Logs it + shows a compact line on the status bar.
func _on_vendor_listed(payload: Dictionary) -> void:
	var stock: Array = payload.get("stock", [])
	print("[vendor] %d items (credits %d, mult %.2f, rep %s):" % [stock.size(), int(payload.get("credits", 0)), float(payload.get("price_mult", 1.0)), String(payload.get("rep_tier", "neutral"))])
	for item in stock:
		print("[vendor]   %s (%s) buy %d / sell %d" % [String((item as Dictionary).get("key", "")), String((item as Dictionary).get("kind", "")), int((item as Dictionary).get("buy", 0)), int((item as Dictionary).get("sell", 0))])
	_populate_shop(payload)  # Task 2: render the priced stock into the clickable shop overlay
	_set_status("Shop: %d items — click Buy/Sell (B closes)." % stock.size())

# Task 2: fill the shop overlay from the server-priced vendor payload. One row per item:
# name · buy/sell price · Buy button · Sell button (Net.send_buy / Net.send_sell).
func _populate_shop(payload: Dictionary) -> void:
	if _shop_list == null or _shop_title == null:
		return
	for child in _shop_list.get_children():
		child.queue_free()
	var credits := int(payload.get("credits", 0))
	var rep := String(payload.get("rep_tier", "neutral"))
	var mult := float(payload.get("price_mult", 1.0))
	_shop_title.text = "Vendor — Credits: %d   (rep: %s · prices x%.2f)" % [credits, rep, mult]
	for item in payload.get("stock", []):
		var it: Dictionary = item
		var key := String(it.get("key", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var nm := Label.new()
		nm.text = String(it.get("name", key))
		nm.custom_minimum_size = Vector2(250, 0)
		nm.add_theme_font_size_override("font_size", 14)
		row.add_child(nm)

		var price := Label.new()
		price.text = "buy %d · sell %d" % [int(it.get("buy", 0)), int(it.get("sell", 0))]
		price.custom_minimum_size = Vector2(150, 0)
		price.add_theme_font_size_override("font_size", 13)
		row.add_child(price)

		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_shop_buy.bind(key))
		row.add_child(buy_btn)

		var sell_btn := Button.new()
		sell_btn.text = "Sell"
		sell_btn.pressed.connect(_on_shop_sell.bind(key))
		row.add_child(sell_btn)

		_shop_list.add_child(row)

func _on_shop_buy(item_key: String) -> void:
	Net.send_buy(item_key)
	_set_status("Buying %s…" % item_key)

func _on_shop_sell(item_key: String) -> void:
	Net.send_sell(item_key)
	_set_status("Selling %s…" % item_key)

func _open_shop() -> void:
	_shop_open = true
	if _shop_panel != null:
		_shop_panel.visible = true
	Net.send_vendor_list()  # request fresh, server-priced stock
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # release the cursor so Buy/Sell are clickable
	_set_status("Shop open — click Buy/Sell · B or Esc to close.")

func _close_shop() -> void:
	_shop_open = false
	if _shop_panel != null:
		_shop_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # resume first-person look + movement

func _toggle_shop() -> void:
	if _shop_open:
		_close_shop()
	else:
		_open_shop()

func _on_buy_replied(result: Dictionary) -> void:
	var item := String(result.get("item_key", ""))
	if bool(result.get("ok", false)):
		var price := int(result.get("price", 0))
		print("[buy] bought %s for %d (credits %d)" % [item, price, int(result.get("credits", 0))])
		_set_status("Bought %s for %d cr." % [item, price])
		_toast("Bought %s  (-%d cr)" % [item, price], Color(0.92, 0.72, 0.40))
		if _shop_open:
			Net.send_vendor_list()  # refresh prices/credits in the open panel
	else:
		print("[buy] %s rejected (%s)" % [item, String(result.get("reason", ""))])
		_set_status("Buy failed: %s (%s)." % [item, String(result.get("reason", ""))])
		_toast("Buy failed: %s" % String(result.get("reason", "")), Color(0.92, 0.42, 0.35))

func _on_sell_replied(result: Dictionary) -> void:
	var item := String(result.get("item_key", ""))
	if bool(result.get("ok", false)):
		var price := int(result.get("price", 0))
		print("[sell] sold %s for %d (credits %d)" % [item, price, int(result.get("credits", 0))])
		_set_status("Sold %s for %d cr." % [item, price])
		_toast("Sold %s  (+%d cr)" % [item, price], Color(0.55, 0.90, 0.48))
		if _shop_open:
			Net.send_vendor_list()  # refresh prices/credits in the open panel
	else:
		print("[sell] %s rejected (%s)" % [item, String(result.get("reason", ""))])
		_set_status("Sell failed: %s (%s)." % [item, String(result.get("reason", ""))])
		_toast("Sell failed: %s" % String(result.get("reason", "")), Color(0.92, 0.42, 0.35))

# DIV-0006: you were killed by a hostile and respawned at the secured spaceport med bay.
func _on_died(notice: Dictionary) -> void:
	var killer := String(notice.get("killer", "a hostile"))
	var dur := int(notice.get("durability_loss", 0))
	var dropped: Array = notice.get("dropped", [])
	var insured := " (insured)" if bool(notice.get("insured", false)) else ""
	var msg := "You were killed by %s in %s. Respawned at the spaceport — gear -%d%% durability, %d item(s) dropped%s. Credits kept." % [
		killer, String(notice.get("zone", "")), dur, dropped.size(), insured]
	print("[death] %s" % msg)
	# DIV-0027: a downed->dead transition — clear the amber downed banner FIRST so the red kill card
	# doesn't stack under it.
	_is_downed = false
	if _downed_panel != null:
		_downed_panel.visible = false
	_set_status(msg)
	_combat_lines.append("*** %s ***" % msg)
	while _combat_lines.size() > 8:
		_combat_lines.pop_front()
	if _combat_log != null:
		_combat_log.text = "Combat log:\n" + "\n".join(_combat_lines)
	# Task 3: a brief full-screen death card. Any target mesh is now stale — drop it.
	_despawn_target()
	_show_death_card("YOU WERE KILLED",
		"%s — gear -%d%% durability, %d item(s) dropped%s\nRespawning at the spaceport med bay… (credits kept)" % [
			killer, dur, dropped.size(), insured])

# DIV-0027: you were DOWNED-in-field (sev 3-4) — not dead. Distinct amber HUD state + the yield
# affordance. Bleeding (sev 4) means the bleed-out death roll is now ticking against you.
func _on_downed(notice: Dictionary) -> void:
	var sev := int(notice.get("severity", 3))
	var killer := String(notice.get("killer", "your wounds"))
	var bleeding := bool(notice.get("bleeding", sev >= 4))
	_is_downed = true
	var msg := "You are DOWN — press Y to yield & respawn, or wait for a medic"
	if bleeding:
		msg += " (bleeding out)"
	if _downed_panel != null:
		_downed_panel.text = msg
		_downed_panel.visible = true
	_set_status("Downed by %s (sev %d). %s" % [killer, sev, "Bleeding out — press Y to yield." if bleeding else "Press Y to yield or await First Aid."])
	print("[downed] %s" % msg)

# DIV-0027: a medic First-Aided you back above the downed floor — clear the downed state.
func _on_revived(notice: Dictionary) -> void:
	_is_downed = false
	if _downed_panel != null:
		_downed_panel.visible = false
	_set_status("A medic revived you.")
	_toast("A medic revived you.", Color(0.55, 0.92, 0.55))
	print("[downed] revived -> %s" % String(notice.get("to", "up")))

# DIV-0011: your hidden Force sensitivity has awakened (the SWG-Village earned unlock).
func _on_force_awakened(notice: Dictionary) -> void:
	var msg := String(notice.get("message", "You feel the Force awaken within you."))
	print("[force] %s" % msg)
	_set_status(msg)
	_combat_lines.append("*** %s ***" % msg)
	while _combat_lines.size() > 8:
		_combat_lines.pop_front()
	if _combat_log != null:
		_combat_log.text = "Combat log:\n" + "\n".join(_combat_lines)
	# Task 3: a prominent (longer, blue) toast for the earned Force unlock.
	_toast(msg, Color(0.62, 0.82, 1.0), 4.5)

# DIV-0019: a PvP fire intent was refused (fired outside a lawless zone / at a protected target).
func _on_fire_rejected(result: Dictionary) -> void:
	var reason := String(result.get("reason", "rejected"))
	var messages := {
		"protected_zone": "You can't attack players here — this zone is protected. (Open PvP is lawless-only; /duel or a bounty opens a target.)",
		"protected_target": "That player is in a protected zone.",
		"different_zone": "That player isn't in your zone.",
		"not_colocated": "That player isn't in your zone.",           # DIV-0022 consent reason
		"newbie_protected": "One of you is under new-player protection — no attack. (Duel with /duel, or /pvp on to opt out.)",  # DIV-0022
		"out_of_ammo": "Out of ammo — buy a power pack from a vendor (B: shop) to reload.",  # DIV-0029
	}
	var msg := String(messages.get(reason, "PvP fire refused (%s)." % reason))
	# DIV-0029: an out_of_ammo reject means the shot never fired — a COMBAT event. Surface it in the
	# combat log too (the server-only "[ammo] ... refused (out_of_ammo)" print never reaches the client),
	# so a player who only watches the log still learns their gun is empty.
	if reason == "out_of_ammo":
		print("[ammo] fire refused (out_of_ammo)")
		_push_combat_line("*** Out of ammo — %s is empty. Buy a power pack (B). ***" % _weapon_pretty(String(result.get("weapon", ""))))
	else:
		print("[pvp] fire refused (%s)" % reason)
	_set_status(msg)

# DIV-0006: buy-insurance outcome.
func _on_insurance_replied(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		print("[insurance] policy bought — %d charge(s), credits %d" % [int(result.get("charges", 0)), int(result.get("credits", 0))])
		_set_status("Insurance: %d covered death(s). Credits %d." % [int(result.get("charges", 0)), int(result.get("credits", 0))])
	else:
		print("[insurance] rejected (%s)" % String(result.get("reason", "")))
		_set_status("Insurance failed: %s (premium %d)." % [String(result.get("reason", "")), int(result.get("premium", 0))])

func _on_skill_raise_replied(result: Dictionary) -> void:
	# F41: surface the result on the GUI status line too (print() only reaches the console; the
	# player who typed /raise otherwise sees the optimistic "Raising…" forever). Parity w/ heal/zone.
	if bool(result.get("ok", false)):
		print("[skillraise] %s raised to %s (cost %d)" % [String(result.get("skill", "")), String(result.get("new_bonus", "")), int(result.get("cost", 0))])
		_set_status("Raised %s to %s (cost %d CP)." % [String(result.get("skill", "")), String(result.get("new_bonus", "")), int(result.get("cost", 0))])
	else:
		print("[skillraise] %s rejected (%s, need %d)" % [String(result.get("skill", "")), String(result.get("reason", "")), int(result.get("cost", 0))])
		_set_status("Raise failed: %s (need %d CP)." % [String(result.get("reason", "")), int(result.get("cost", 0))])

func _on_equip_replied(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		print("[equip] equipped %s in %s" % [String(result.get("item_key", "")), String(result.get("slot", ""))])
		_set_status("Equipped %s." % String(result.get("item_key", "")))
	else:
		print("[equip] %s rejected (%s)" % [String(result.get("item_key", "")), String(result.get("reason", ""))])
		_set_status("Equip failed: %s." % String(result.get("reason", "")))  # F41: parity

func _on_auth_replied(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		print("[auth] login denied for %s (%s)" % [String(result.get("account_id", "")), String(result.get("reason", ""))])
		_set_status("Login denied (%s)." % String(result.get("reason", "")))

# First other player's peer id in the latest snapshot (0 if alone). Used by the H key /
# --heal-other affordance to pick a First-Aid target without a full targeting UI.
# Nearest same-zone WOUNDED player, for First Aid targeting (0 if none). Uses the per-entry
# `wound` (F17) + `pos` (F13) now carried on each snapshot player, so a medic heals whoever is
# hurt nearby instead of a random/healthy bystander. Only same-zone players are in the snapshot
# (F13), so this is implicitly proximity- and zone-scoped.
func _best_heal_target() -> int:
	var my_pos := _my_position()
	var best := 0
	var best_dist := INF
	for entry in Net.last_snapshot.get("players", []):
		var e: Dictionary = entry
		var id := int(e.get("id", 0))
		if id == 0 or id == _local_id:
			continue
		if String(e.get("wound", "healthy")) == "healthy":
			continue
		var p: Vector3 = e.get("pos", Vector3.ZERO)
		var d := my_pos.distance_to(p)
		if d < best_dist:
			best_dist = d
			best = id
	return best

func _my_position() -> Vector3:
	for entry in Net.last_snapshot.get("players", []):
		if int((entry as Dictionary).get("id", 0)) == _local_id:
			return (entry as Dictionary).get("pos", Vector3.ZERO)
	return Vector3.ZERO

# DIV-0019: the first OTHER same-zone player in the snapshot (0 if alone). Used by --fire-nearest to
# aim autofire at a player target without knowing their peer id in advance (the snapshot is zone-scoped).
func _first_other_player() -> int:
	for entry in Net.last_snapshot.get("players", []):
		var id := int((entry as Dictionary).get("id", 0))
		if id != 0 and id != _local_id:
			return id
	return 0

# DIV-0022: resolve a display name (case-insensitive) to a same-zone peer id (0 if none). The snapshot is
# zone-scoped, so /duel /bounty naturally target only co-located players.
func _peer_by_name(display_name: String) -> int:
	var want := display_name.strip_edges().to_lower()
	if want == "":
		return 0
	for entry in Net.last_snapshot.get("players", []):
		var e: Dictionary = entry
		if int(e.get("id", 0)) == _local_id:
			continue
		if String(e.get("name", "")).strip_edges().to_lower() == want:
			return int(e.get("id", 0))
	return 0

# DIV-0022: outcome of a /duel /accept /decline /yield command (combat-log line + status).
func _on_duel_replied(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		var action := String(result.get("action", "duel"))
		print("[duel] %s (target peer %d)" % [action, int(result.get("target_peer", 0))])
		_push_combat_line("Duel: %s." % action)
		_set_status("Duel %s." % action)
	else:
		print("[duel] rejected (%s)" % String(result.get("reason", "")))
		_set_status("Duel failed: %s." % String(result.get("reason", "")))

# DIV-0022: a duel state change involving me (offered/active/declined/ended/ko). Combat-log + status.
func _on_duel_notified(notice: Dictionary) -> void:
	var kind := String(notice.get("kind", ""))
	var line := ""
	match kind:
		"offered":
			line = "%s challenged you to a %s duel — /accept or /decline." % [String(notice.get("from", "Someone")), "lethal" if bool(notice.get("lethal", false)) else "friendly"]
		"active":
			line = "Duel with %s is ON (%s). Fire away!" % [String(notice.get("with", "your opponent")), "lethal" if bool(notice.get("lethal", false)) else "non-lethal"]
		"declined":
			line = "%s declined your duel." % String(notice.get("by", "They"))
		"ended":
			var outcome := String(notice.get("outcome", "ended"))
			if bool(notice.get("you_won", false)):
				line = "You WON the duel (%s) vs %s." % [outcome, String(notice.get("loser", "your opponent"))]
			elif notice.has("winner"):
				line = "Duel over (%s) — %s wins." % [outcome, String(notice.get("winner"))]
			else:
				# No-winner endings (left_zone / offer_expired / expired / disconnect): a draw, not a loss.
				line = "Duel ended (%s) — no winner." % outcome
		_:
			line = "Duel update: %s" % kind
	print("[duel] %s" % line)
	_push_combat_line(line)
	_set_status(line)

# DIV-0022: outcome of a /bounty /payoff /bounties command.
func _on_bounty_replied(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		print("[bounty] rejected (%s)" % String(result.get("reason", "")))
		_set_status("Bounty failed: %s." % String(result.get("reason", "")))
		return
	var action := String(result.get("action", ""))
	match action:
		"placed":
			var msg := "Bounty on %s now %d cr (fee %d)." % [String(result.get("target", "target")), int(result.get("pot", 0)), int(result.get("fee", 0))]
			print("[bounty] %s" % msg)
			_push_combat_line(msg)
			_set_status(msg)
		"paid_off":
			_set_status("Paid off your bounty for %d cr." % int(result.get("cost", 0)))
			print("[bounty] paid off for %d" % int(result.get("cost", 0)))
		"list":
			var board: Array = result.get("board", [])
			print("[bounty] board: %d contract(s)" % board.size())
			for b in board:
				print("[bounty]   %s: %d cr" % [String((b as Dictionary).get("target", "")), int((b as Dictionary).get("pot", 0))])
			_set_status("Bounty board: %d active contract(s)." % board.size())

# DIV-0022: a bounty was placed on me / I collected one on a kill.
func _on_bounty_notified(notice: Dictionary) -> void:
	var kind := String(notice.get("kind", ""))
	if kind == "placed_on_you":
		var msg := "A bounty of %d cr has been placed on your head." % int(notice.get("pot", 0))
		print("[bounty] %s" % msg)
		_push_combat_line("*** %s ***" % msg)
		_toast(msg, Color(0.92, 0.55, 0.25), 4.0)
	elif kind == "collected":
		var msg := "Bounty collected: +%d cr for taking out %s." % [int(notice.get("payout", 0)), String(notice.get("target", "your quarry"))]
		print("[bounty] %s" % msg)
		_push_combat_line("*** %s ***" % msg)
		_toast(msg, Color(0.55, 0.90, 0.48), 4.0)

# Talk to the nearest named NPC within interact range (E key). Rotating line via dialogue_model.
func _talk_to_nearest_npc() -> void:
	var my_pos := _my_position()
	var best := {}
	var best_d := 6.0  # interact range (units)
	for entry in Net.last_snapshot.get("named_npcs", []):
		var e: Dictionary = entry
		var p: Dictionary = e.get("pos", {})
		var pos := Vector3(float(p.get("x", 0.0)), float(p.get("y", 1.2)), float(p.get("z", 0.0)))
		var d := my_pos.distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	if best.is_empty():
		_set_status("No one nearby to talk to.")
		return
	_do_talk(best)

# Show the next dialogue line for a named-NPC snapshot entry (rotates per-NPC via dialogue_model).
func _do_talk(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	var tc := int(_npc_talk_count.get(id, 0))
	var npc := {"name": String(entry.get("name", "")), "role": String(entry.get("role", "")), "dialogue_lines": entry.get("lines", [])}
	var line := DialogueModel.next_line(npc, tc)
	_npc_talk_count[id] = tc + 1
	var say := "%s: \"%s\"" % [String(entry.get("name", "Someone")), line]
	_set_status(say)
	_chat_lines.append(say)
	while _chat_lines.size() > 6:
		_chat_lines.pop_front()
	if _chat_log != null:
		_chat_log.text = "Chat:\n" + "\n".join(_chat_lines)
	print("[talk] %s" % say)

func _on_heal_replied(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		print("[firstaid] healed peer %d: %s -> %s" % [int(result.get("target_id", 0)), String(result.get("from", "")), String(result.get("to", ""))])
		_set_status("First Aid: %s -> %s" % [String(result.get("from", "")), String(result.get("to", ""))])
	else:
		print("[firstaid] heal failed (%s)" % String(result.get("reason", "")))
		_set_status("First Aid failed (%s)." % String(result.get("reason", "")))

func _on_sheet_updated(sheet: Dictionary) -> void:
	_my_sheet = sheet
	
	if not _onboarding_shown and int(sheet.get("character_points", 0)) == 0 and int(sheet.get("credits", 0)) == 1000:
		_onboarding_shown = true
		if _onboarding_panel != null:
			_onboarding_panel.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var summary: Dictionary = sheet.get("summary", {})
	var attrs: Dictionary = summary.get("attributes", {})
	var skills: Dictionary = summary.get("skills", {})
	var lines: Array = ["— Character Sheet —"]
	var force_note := "  (Force-sensitive)" if bool(summary.get("force_sensitive", false)) else ""
	lines.append("Species: %s%s" % [String(summary.get("species", "?")), force_note])
	var astr := ""
	for a in ["dexterity", "knowledge", "mechanical", "perception", "strength", "technical"]:
		if attrs.has(a):
			astr += "%s %s   " % [String(a).substr(0, 3).to_upper(), String(attrs[a])]
	lines.append(astr.strip_edges())
	if not skills.is_empty():
		var sstr := ""
		for s in skills:
			sstr += "%s %s   " % [String(s), String(skills[s])]
		lines.append("Skills: " + sstr.strip_edges())
	lines.append("Gear: weapon=%s · armor=%s" % [String(summary.get("weapon", "-")), String(summary.get("armor", "-"))])
	var inv: Array = summary.get("inventory", [])
	if not inv.is_empty():
		lines.append("Inventory: " + ", ".join(inv))
	lines.append("Credits: %d" % int(summary.get("credits", 0)))
	var w: Dictionary = summary.get("cp_wallet", {})
	lines.append("CP wallet: %d gameplay · %d prestige" % [int(w.get("gameplay_cp", 0)), int(w.get("rp_cp", 0))])
	lines.append("(press V to hide)")
	if _sheet_panel != null:
		var sheet_label: Label = _sheet_panel.get_node("SheetLabel") as Label
		if sheet_label != null:
			sheet_label.text = "\n".join(lines)
	print("[sheet] species=%s dex=%s weapon=%s skills=%d cp=%d" % [
		String(summary.get("species", "?")), String(attrs.get("dexterity", "?")),
		String(summary.get("weapon", "-")), skills.size(),
		int((summary.get("cp_wallet", {}) as Dictionary).get("gameplay_cp", 0))])

func _on_zone_replied(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		print("[zone] traveled to %s" % String(result.get("display_name", result.get("zone_id", ""))))
		_set_status("Arrived in %s." % String(result.get("display_name", result.get("zone_id", ""))))
	else:
		print("[zone] travel rejected (%s)" % String(result.get("reason", "")))
		_set_status("Travel rejected (%s)." % String(result.get("reason", "")))

func _on_chat_received(message: Dictionary) -> void:
	var line := ChatModel.format_line(message)
	print("[chat] %s" % line)
	_chat_lines.append(line)
	while _chat_lines.size() > 6:
		_chat_lines.pop_front()
	if _chat_log != null:
		_chat_log.text = "Chat:\n" + "\n".join(_chat_lines)

# Parse a free-text chat line ("/org regroup" / plain text) and send it. Shared by the GUI
# chat box and the headless --say affordance (F22). Empty channel/text -> nothing sent.
func _submit_chat_line(raw: String) -> void:
	# Command bar: a recognized "/raise|/travel|/heal …" is a game COMMAND; anything else is
	# chat (parse_input -> send_chat). Lets the GUI input reach the full command surface, not
	# just the hardcoded keys (e.g. raise ANY skill, not only blaster via K).
	var command: Dictionary = ChatModel.parse_command(raw)
	var cmd := String(command.get("cmd", ""))
	if cmd != "":
		_dispatch_command(cmd, String(command.get("arg", "")))
		return
	var parsed: Dictionary = ChatModel.parse_input(raw)
	var channel := String(parsed.get("channel", ""))
	var body := String(parsed.get("text", ""))
	if channel != "" and body != "":
		# F39: /org chat needs an org. The server already drops a no-org org-line, but silently —
		# the player saw nothing. Pre-empt with feedback (most players have no org yet: faction-
		# join is owner-gated). The viewer's org is in the snapshot territory block (F12).
		if channel == "org" and String((Net.last_snapshot.get("territory", {}) as Dictionary).get("org_id", "")) == "":
			print("[chat] /org unavailable — not in an org")
			_set_status("You're not in an org — /org chat is unavailable.")
			return
		Net.send_chat(channel, body)

func _dispatch_command(cmd: String, arg: String) -> void:
	match cmd:
		"raise":
			if arg != "":
				Net.send_skill_raise(arg)
				_set_status("Raising %s…" % arg)
			else:
				_usage("/raise <skill>  (e.g. /raise dodge)")  # F40: no silent no-op on a missing arg
		"travel":
			if arg != "":
				Net.send_change_zone(arg)
			else:
				_usage("/travel <zone>  (e.g. /travel tatooine.dune_sea)")
		"heal":
			var t := _best_heal_target()
			if t != 0:
				Net.send_heal(t)
				_set_status("First Aid -> peer %d…" % t)
			else:
				_set_status("First Aid: no wounded ally nearby.")
		"claim":
			if arg != "":
				Net.send_claim_node(arg)  # org claims a node in the current zone
				_set_status("Claiming %s…" % arg)
			else:
				_usage("/claim <node>  (e.g. /claim n1)")
		"release":
			if arg != "":
				Net.send_release_claim(arg)
				_set_status("Releasing %s…" % arg)
			else:
				_usage("/release <node>  (e.g. /release n1)")
		"shop":
			Net.send_vendor_list()  # Wave F economy: list the vendor's priced stock
			_set_status("Requesting vendor stock…")
		"buy":
			if arg != "":
				Net.send_buy(arg)
				_set_status("Buying %s…" % arg)
			else:
				_usage("/buy <item>  (e.g. /buy heavy_blaster) — /shop lists items")
		"sell":
			if arg != "":
				Net.send_sell(arg)
				_set_status("Selling %s…" % arg)
			else:
				_usage("/sell <item>  (e.g. /sell hold_out_blaster)")
		"insure":
			Net.send_buy_insurance()  # DIV-0006: buy a death-insurance policy (500cr / 3 covered deaths)
			_set_status("Buying death insurance…")
		"duel":
			# DIV-0022: challenge a co-located player to an opt-in (default non-lethal) duel.
			if arg != "":
				var tgt := _peer_by_name(arg)
				if tgt != 0:
					Net.send_duel_challenge(tgt, false)
					_set_status("Challenged %s to a duel…" % arg)
				else:
					_set_status("No one named '%s' here to duel." % arg)
			else:
				_usage("/duel <name>  (challenge a player here to a duel)")
		"accept":
			var acc := _peer_by_name(arg) if arg != "" else 0
			Net.send_duel_accept(acc)  # 0 = the single pending offer
			_set_status("Accepting duel…")
		"decline":
			var dec := _peer_by_name(arg) if arg != "" else 0
			Net.send_duel_decline(dec)
			_set_status("Declining duel…")
		"yield":
			Net.send_duel_yield()  # DIV-0022: concede an active duel (distinct from Y = accept death when downed)
			_set_status("Yielding the duel…")
		"bounty":
			# DIV-0022: /bounty <name> <amount> — place a credit-funded bounty on a player.
			var bparts := arg.split(" ", false)
			if bparts.size() >= 2:
				var bt := _peer_by_name(String(bparts[0]))
				if bt != 0:
					Net.send_place_bounty(bt, int(String(bparts[1])))
					_set_status("Placing %s cr bounty on %s…" % [String(bparts[1]), String(bparts[0])])
				else:
					_set_status("No one named '%s' here to bounty." % String(bparts[0]))
			else:
				_usage("/bounty <name> <amount>  (e.g. /bounty Vask 500)")
		"payoff":
			Net.send_pay_off_bounty()  # settle your own bounty
			_set_status("Paying off your bounty…")
		"bounties":
			Net.send_list_bounties()  # request the active bounty board
			_set_status("Requesting the bounty board…")
		"pvp":
			# DIV-0022: /pvp on opts out of newbie protection (one-way).
			if arg.strip_edges().to_lower() == "on":
				Net.send_pvp_optout()
				_set_status("PvP protection dropped — you can now be attacked in dangerous zones.")
			else:
				_usage("/pvp on  (drop newbie protection — one-way)")
		"who":
			_show_who()  # client-local roster of same-zone players (from the snapshot)
		"help":
			var help := ChatModel.command_help()
			# F54: /help also lists the KEYBINDS — none of these (H heal, K raise, X/Z/G defense,
			# T travel, V sheet) are otherwise discoverable, so a new player can't find them.
			var keys := "Keys: WASD move · Space jump · LMB fire · RMB aim · X cover · Z dodge · G full-dodge · C CP · F Force Point · H heal ally · E talk to NPC · K raise Blaster · V sheet · T travel · B shop · Enter chat"
			_set_status(keys)
			print("[help] %s" % help)
			print("[help] %s" % keys)

# F40: a command typed without its required argument gets a usage hint, not a silent no-op.
func _usage(msg: String) -> void:
	print("[cmd] usage: %s" % msg)
	_set_status("Usage: %s" % msg)

func _on_chat_submitted(text: String) -> void:
	_submit_chat_line(text)
	_close_chat_input()

# Client-local /who roster: the same-zone players (the snapshot is already zone-scoped, F13)
# with their condition (F17). No RPC — reads the latest snapshot.
func _show_who() -> void:
	var names: Array = []
	for entry in Net.last_snapshot.get("players", []):
		var e: Dictionary = entry
		var nm := String(e.get("name", "Spacer-%d" % int(e.get("id", 0))))
		var ax := String(e.get("axis", ""))  # F36: faction allegiance (org members only)
		if ax != "":
			nm += " [%s]" % _axis_pretty(ax)
		var wound := String(e.get("wound", "healthy"))
		names.append(nm if wound == "healthy" else "%s (%s)" % [nm, _condition_pretty(wound)])
	var line := "Here (%d): %s" % [names.size(), ", ".join(names)]
	_set_status(line)
	print("[who] %d players: %s" % [names.size(), ", ".join(names)])

func _open_chat_input() -> void:
	if _chat_input == null:
		return
	_chat_input.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # show the cursor so the player can type

func _close_chat_input() -> void:
	if _chat_input == null:
		return
	_chat_input.text = ""
	_chat_input.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # resume first-person look + movement

func _on_claim_replied(result: Dictionary) -> void:
	# F41: surface the result on the GUI status line too (parity w/ heal/zone — print() only
	# reaches the console, so the player who typed /claim otherwise sees "Claiming…" forever).
	var node_id := String(result.get("node_id", ""))
	if bool(result.get("ok", false)):
		if bool(result.get("released", false)):
			print("[territory] released %s" % node_id)
			_set_status("Released %s." % node_id)
		else:
			print("[territory] claimed %s for %s (tier %s)" % [node_id, String(result.get("org_id", "")), String(result.get("tier", ""))])
			_set_status("Claimed %s (%s)." % [node_id, String(result.get("tier", ""))])
	else:
		var verb := "release" if bool(result.get("released", false)) else "claim"
		print("[territory] %s %s rejected (%s)" % [verb, node_id, String(result.get("reason", ""))])
		_set_status("%s of %s rejected: %s." % [verb.capitalize(), node_id, String(result.get("reason", ""))])

# =====================================================================================
# Wave F visibility: combat-target rendering, hit feedback, death card, toasts.
# Pure presentation — everything below reads only signals/snapshots the client already
# receives (no new server or snapshot fields).
# =====================================================================================

# Task 1: render/refresh the low-poly mesh of the thing being fought, in front of the
# player, and fire off the Task-4 feedback (muzzle flash / hit spark / damage number).
func _render_combat_target(envelope: Dictionary, hit: bool, wound: int) -> void:
	if _camera == null or _monster_builder == null:
		return
	var only_local := int(envelope.get("shooter_id", 0)) == _local_id
	# PvP (dormant until the netcode adds `pvp`/`target_peer_id`): highlight the target
	# PLAYER's avatar instead of spawning a creature mesh.
	if bool(envelope.get("pvp", false)):
		_highlight_pvp_target(int(envelope.get("target_peer_id", 0)))
		if only_local:
			_spawn_muzzle_flash()
		return
	var tname := String(envelope.get("target_name", "Target"))
	var tkey := String(envelope.get("target_key", ""))  # "" = the shared training dummy
	var disabled := bool(envelope.get("target_disabled", false))
	var kind := "remote" if tkey == "" else "monster"
	var key := "%s|%s" % [kind, tname]
	if _target_mesh == null or key != _target_mesh_key:
		if disabled:
			return  # a fresh but already-down target — don't pop a corpse into view
		_despawn_target()
		_target_mesh = _monster_builder.build_target(kind, tname)
		add_child(_target_mesh)
		_target_mesh.global_position = _target_spawn_pos()
		_target_mesh_key = key
	# A disabled target lingers only briefly (show the kill), otherwise persists between shots.
	_target_ttl = 1.4 if disabled else 6.0
	if only_local:
		_spawn_muzzle_flash()
	if _target_mesh != null:
		var fx_pos := _target_mesh.global_position + Vector3(0.0, 1.2, 0.0)
		if hit:
			_spawn_hit_spark(fx_pos)
			if wound >= 0:
				_spawn_damage_number(fx_pos, _wound_label(wound), _severity_color(wound))
		if disabled:
			_spawn_damage_number(fx_pos + Vector3(0.0, 0.35, 0.0), "DOWN", Color(0.88, 0.20, 0.15))

# Per-frame: keep the target in front of the player (facing them) and expire it when the
# fight goes quiet. Also expires the dormant PvP marker.
func _update_combat_target(delta: float) -> void:
	if _target_mesh != null and is_instance_valid(_target_mesh):
		_target_ttl -= delta
		if _target_ttl <= 0.0:
			_despawn_target()
		else:
			_position_target_in_front()
	if _pvp_marker != null and is_instance_valid(_pvp_marker):
		_pvp_marker_ttl -= delta
		if _pvp_marker_ttl <= 0.0:
			_pvp_marker.queue_free()
			_pvp_marker = null

func _target_spawn_pos() -> Vector3:
	var me := _my_position()
	var fwd := -_camera.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3(0.0, 0.0, -1.0)
	fwd = fwd.normalized()
	var p := me + fwd * 6.0
	p.y = 0.0
	return p

func _position_target_in_front() -> void:
	if _target_mesh == null or _camera == null:
		return
	var want := _target_spawn_pos()
	_target_mesh.global_position = _target_mesh.global_position.lerp(want, 0.12)
	# Face the player (the meshes are built head-first along -Z, so look_at points the head at them).
	var me := _my_position()
	var flat := Vector3(me.x, _target_mesh.global_position.y, me.z)
	if _target_mesh.global_position.distance_to(flat) > 0.25:
		_target_mesh.look_at(flat, Vector3.UP)

func _despawn_target() -> void:
	if _target_mesh != null and is_instance_valid(_target_mesh):
		_target_mesh.queue_free()
	_target_mesh = null
	_target_mesh_key = ""
	_target_ttl = 0.0

# PvP: a floating marker over the target player's avatar (dormant until the netcode
# tags envelopes with pvp/target_peer_id — then this lights the right avatar up).
func _highlight_pvp_target(peer_id: int) -> void:
	if peer_id == 0 or not _avatars.has(peer_id):
		return
	if _pvp_marker != null and is_instance_valid(_pvp_marker):
		_pvp_marker.queue_free()
	var root := _avatars[peer_id]["root"] as Node3D
	var marker := Label3D.new()
	marker.text = "▼ TARGET ▼"
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 28
	marker.modulate = Color(0.90, 0.20, 0.15)
	marker.outline_size = 6
	marker.no_depth_test = true
	marker.position.y = 2.5
	root.add_child(marker)
	_pvp_marker = marker
	_pvp_marker_ttl = 4.0

# Task 4: a brief bright muzzle flash near the local player's weapon when THEY fire.
func _spawn_muzzle_flash() -> void:
	if _camera == null:
		return
	var flash := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.12
	sph.height = 0.24
	flash.mesh = sph
	flash.material_override = _fx_material(Color(1.0, 0.85, 0.35, 0.9))
	add_child(flash)
	var basis := _camera.global_transform.basis
	flash.global_position = _camera.global_position - basis.z * 0.9 - basis.y * 0.25 + basis.x * 0.2
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3.ONE * 2.2, 0.12)
	tw.parallel().tween_property(flash.material_override, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(flash.queue_free)

# Task 4: a hit spark that pops and fades at the target.
func _spawn_hit_spark(world_pos: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 0.25, 0.25)
	spark.mesh = bm
	spark.material_override = _fx_material(Color(1.0, 0.55, 0.15, 0.95))
	add_child(spark)
	spark.global_position = world_pos
	var tw := create_tween()
	tw.tween_property(spark, "scale", Vector3.ONE * 2.6, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spark.material_override, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(spark.queue_free)

# Task 4: a floating damage/wound label that rises and fades over the target.
func _spawn_damage_number(world_pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.03, 0.02, 0.02, 0.9)
	label.no_depth_test = true
	add_child(label)
	label.global_position = world_pos
	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y + 1.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tw.tween_callback(label.queue_free)

func _fx_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _severity_color(severity: int) -> Color:
	match severity:
		0: return Color(0.72, 0.72, 0.72)
		1: return Color(0.85, 0.80, 0.25)
		2: return Color(0.90, 0.55, 0.18)
		3: return Color(0.90, 0.30, 0.15)
		_: return Color(0.85, 0.12, 0.12)

# Task 3: a transient HUD toast that fades out. Kills any in-flight fade first so rapid
# toasts don't fight over the label's alpha.
func _toast(text: String, color: Color = Color(0.98, 0.95, 0.82), hold: float = 2.4) -> void:
	if _toast_label == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.modulate = Color(1, 1, 1, 1)
	_toast_tween = create_tween()
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)

# Task 3: fade the full-screen death card in, hold, then fade out.
func _show_death_card(title: String, subtitle: String) -> void:
	if _death_overlay == null or _death_label == null:
		return
	_death_label.text = "%s\n\n%s" % [title, subtitle]
	_death_overlay.visible = true
	_death_overlay.color = Color(0.32, 0.03, 0.03, 0.0)
	_death_label.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(_death_overlay, "color:a", 0.55, 0.25)
	tw.parallel().tween_property(_death_label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(_death_overlay, "color:a", 0.0, 1.0)
	tw.parallel().tween_property(_death_label, "modulate:a", 0.0, 1.0)
	tw.tween_callback(_hide_death_overlay)

func _hide_death_overlay() -> void:
	if _death_overlay != null:
		_death_overlay.visible = false

# Find dynamic player or NPC target under the center-screen crosshair/reticle
func _find_target_under_crosshair() -> Dictionary:
	if _camera == null:
		return {}
	var camera_pos := _camera.global_position
	var look_dir := -_camera.global_transform.basis.z.normalized()
	
	var best_target: Dictionary = {}
	var best_score := 0.85 # dot product of ~30 deg
	var best_dist := 9999.0
	
	# Sweep player avatars
	for peer_id in _avatars.keys():
		if peer_id == _local_id:
			continue
		var entry = _avatars[peer_id]
		var root = entry.get("root")
		if not is_instance_valid(root):
			continue
		var pos = root.global_position + Vector3(0.0, 1.0, 0.0)
		var dir_to_target = (pos - camera_pos).normalized()
		var dist = camera_pos.distance_to(pos)
		if dist > 35.0:
			continue
		var dot = look_dir.dot(dir_to_target)
		if dot > best_score:
			best_score = dot
			best_target = {
				"peer_id": peer_id,
				"name": String(entry.get("name", "Player-%d" % peer_id)),
				"pos": pos
			}
			best_dist = dist
			
	# Sweep named NPCs
	for npc_id in _named_npc_nodes.keys():
		var root = _named_npc_nodes[npc_id]["root"]
		if not is_instance_valid(root):
			continue
		var pos = root.global_position + Vector3(0.0, 1.0, 0.0)
		var dir_to_target = (pos - camera_pos).normalized()
		var dist = camera_pos.distance_to(pos)
		if dist > 35.0:
			continue
		var dot = look_dir.dot(dir_to_target)
		if dot > best_score:
			best_score = dot
			best_target = {
				"npc_id": npc_id,
				"name": npc_id,
				"pos": pos
			}
			best_dist = dist
			
	# Sweep ambient NPCs/monsters
	for npc_id in _npc_nodes.keys():
		var root = _npc_nodes[npc_id]["root"]
		if not is_instance_valid(root):
			continue
		var pos = root.global_position + Vector3(0.0, 1.0, 0.0)
		var dir_to_target = (pos - camera_pos).normalized()
		var dist = camera_pos.distance_to(pos)
		if dist > 35.0:
			continue
		var dot = look_dir.dot(dir_to_target)
		if dot > best_score:
			best_score = dot
			best_target = {
				"npc_id": npc_id,
				"name": npc_id,
				"pos": pos
			}
			best_dist = dist
			
	return best_target

# Instantly draw a thin, glowing red cylinder representing a blaster laser beam tracer
func _spawn_laser_tracer(from: Vector3, to: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = from.distance_to(to)
	tracer.mesh = cyl
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.15)
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = mat
	
	add_child(tracer)
	
	tracer.global_position = (from + to) / 2.0
	tracer.look_at(to, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, PI/2.0)
	
	var tw := create_tween()
	tw.tween_property(tracer.material_override, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(tracer.queue_free)
