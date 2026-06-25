extends Node
## Server-authoritative networking core for the SW MMO foundation.
##
## A dedicated (or listen) server owns the WorldState and, later, RNG seeds and
## combat resolution. Clients send input INTENTS and render authoritative
## snapshots; they never own position truth. We use explicit RPCs rather than
## scene replication so the authority/anti-cheat story stays simple and maps
## directly onto action-window combat (client sends a fire intent -> server
## resolves a WEG D6 window with a server-owned seed -> broadcasts an envelope).
##
## Registered as the `Net` autoload. In the solo slice (main.tscn) it stays in
## Mode.NONE and does nothing.

const WorldState := preload("res://scripts/net/world_state.gd")
const CombatArena := preload("res://scripts/net/combat_arena.gd")
const PersistenceStore := preload("res://scripts/net/persistence_store.gd")
const ZoneState := preload("res://scripts/net/zone_state.gd")
const Territory := preload("res://scripts/net/territory_model.gd")
const Chargen := preload("res://scripts/rules/chargen_model.gd")
const Progression := preload("res://scripts/rules/progression_model.gd")
const Equipment := preload("res://scripts/rules/equipment_model.gd")
const OrgModel := preload("res://scripts/net/org_model.gd")
const COMBATANT_DATA_PATH := "res://data/prototype_combatants.json"
const SPECIES_DATA_PATH := "res://data/species_clone_wars.json"
const SKILL_CATALOG_PATH := "res://data/weg_skill_catalog.json"
const WEAPONS_DATA_PATH := "res://data/weapons_clone_wars.json"
const ARMOR_DATA_PATH := "res://data/armor_clone_wars.json"
const COMBAT_CP_REWARD := 3   # gameplay CP for disabling the training target (prototype-tunable)

const DEFAULT_PORT := 24555
const MAX_CLIENTS := 32
const SERVER_TICK_HZ := 20
const CLIENT_SEND_HZ := 20
const COMBAT_WINDOW_SECONDS := 5.0
const AUTOSAVE_SECONDS := 30.0
const DIRECTOR_TICK_SECONDS := 30.0
const RESOURCE_TICK_SECONDS := 60.0
const CURRENT_ZONE := "tatooine.mos_eisley.spaceport"
const ZONES_DATA_PATH := "res://data/zones_clone_wars.json"

enum Mode { NONE, SERVER, CLIENT }

signal server_started(port: int)
signal client_connected()
signal client_failed()
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal snapshot_applied(snapshot: Dictionary)
signal combat_envelope(envelope: Dictionary)
signal wallet_updated(wallet: Dictionary)
signal skill_raise_replied(result: Dictionary)
signal equip_replied(result: Dictionary)
signal claim_replied(result: Dictionary)

var mode: int = Mode.NONE
var state: WorldState = null          # server only
var arena: CombatArena = null         # server only
var store: PersistenceStore = null    # server only
var zones: ZoneState = null           # server only (world-sim director)
var territory: Territory = null       # server only (org claims + passive income)
var _org_model = null                 # server only (OrgModel instance: claim validation)
var combat_window_seconds: float = COMBAT_WINDOW_SECONDS
var director_tick_seconds: float = DIRECTOR_TICK_SECONDS
var resource_tick_seconds: float = RESOURCE_TICK_SECONDS

var _species_data := {}               # server only (chargen species ranges)
var _skill_attr := {}                 # server only (skill key -> governing attribute)
var _weapons_catalog := {}            # server only (weapon key -> stats; for equip)
var _armor_catalog := {}              # server only (armor key -> stats; for equip)
var last_snapshot: Dictionary = {}    # client view of the world
var last_wallet: Dictionary = {}      # client view of its own CP wallet
var connected: bool = false           # client: handshake complete

var _server_accum := 0.0
var _client_accum := 0.0
var _combat_accum := 0.0
var _autosave_accum := 0.0
var _director_accum := 0.0
var _resource_accum := 0.0
var _peer_characters := {}            # peer_id -> character_id (server)
var _peer_zones := {}                 # peer_id -> current_zone_id (server)
var _default_zone: String = CURRENT_ZONE  # server: zone new peers start in
var _peer_orgs := {}                  # peer_id -> org_id (server; for snapshot treasury)
var _territory_influence := {}        # org_id -> {zone_id -> int} (server; territory infl)
var _server_rng := RandomNumberGenerator.new()
var _local_move := Vector2.ZERO
var _local_yaw := 0.0
var _local_jump := false

func _ready() -> void:
	set_physics_process(true)

func start_server(port: int = DEFAULT_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("[net] failed to create server on port %d (err %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.SERVER
	state = WorldState.new()
	_weapons_catalog = _load_json_container(WEAPONS_DATA_PATH, "weapons")
	_armor_catalog = _load_json_container(ARMOR_DATA_PATH, "armor")
	arena = CombatArena.new(D6Rules, _load_combat_data(), "b1_training_silhouette",
		_weapons_catalog, _armor_catalog)
	store = PersistenceStore.new("user://persistence")
	zones = ZoneState.new()
	_load_zones()  # seed the multi-zone roster (the Director ticks them all)
	territory = Territory.new()
	_org_model = OrgModel.new()
	_species_data = _load_species()
	_skill_attr = _load_skill_attributes()
	_server_rng.randomize()
	print("[net] server listening on port %d (combat window %.1fs)" % [port, combat_window_seconds])
	server_started.emit(port)
	return OK

func start_client(host: String = "127.0.0.1", port: int = DEFAULT_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		push_error("[net] failed to create client to %s:%d (err %d)" % [host, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	mode = Mode.CLIENT
	connected = false
	print("[net] client connecting to %s:%d" % [host, port])
	return OK

func stop() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	mode = Mode.NONE
	state = null
	last_snapshot = {}
	connected = false

func local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()

## Called by the client view each frame with the local input intent.
func set_local_input(move: Vector2, yaw: float, jump: bool = false) -> void:
	_local_move = move
	_local_yaw = yaw
	_local_jump = jump

# --- server signal handlers ---
func _on_peer_connected(id: int) -> void:
	if mode != Mode.SERVER:
		return
	state.add_player(id)
	if arena != null:
		arena.register_player(id)
	_peer_zones[id] = _default_zone  # new peers start in the default zone
	print("[net] peer %d joined (players=%d)" % [id, state.player_count()])
	player_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	if mode != Mode.SERVER:
		return
	_save_peer(id)
	state.remove_player(id)
	if arena != null:
		arena.remove_player(id)
	_peer_characters.erase(id)
	_peer_zones.erase(id)
	_peer_orgs.erase(id)
	print("[net] peer %d left (players=%d)" % [id, state.player_count()])
	player_left.emit(id)

# --- client signal handlers ---
func _on_connected() -> void:
	connected = true
	print("[net] connected to server as peer %d" % local_peer_id())
	client_connected.emit()

func _on_connection_failed() -> void:
	print("[net] connection failed")
	mode = Mode.NONE
	connected = false
	client_failed.emit()

func _on_server_disconnected() -> void:
	print("[net] server disconnected")
	mode = Mode.NONE
	connected = false

# --- RPCs ---
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(move: Vector2, yaw: float, jump: bool) -> void:
	if mode != Mode.SERVER or state == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if state.has_player(sender):
		state.set_input(sender, move, yaw, jump)

@rpc("authority", "call_remote", "unreliable_ordered")
func apply_snapshot(snapshot: Dictionary) -> void:
	last_snapshot = snapshot
	snapshot_applied.emit(snapshot)

# client -> server: a fire intent for the current combat window
@rpc("any_peer", "call_remote", "reliable")
func submit_fire_intent(intent: Dictionary) -> void:
	if mode != Mode.SERVER or arena == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if arena.has_player(sender):
		arena.submit_fire_intent(sender, intent)

# server -> clients: a resolved WEG combat exchange envelope
@rpc("authority", "call_remote", "reliable")
func apply_combat_envelope(envelope: Dictionary) -> void:
	combat_envelope.emit(envelope)

func send_fire_intent(intent: Dictionary) -> void:
	if mode == Mode.CLIENT and connected:
		submit_fire_intent.rpc_id(1, intent)

# client -> server: identify the character to load/persist, the chosen display name
# (empty keeps the saved/default name), and a chargen BUILD used only when the
# character does not exist yet ({species, quickstart} or {species, attributes, skills}).
@rpc("any_peer", "call_remote", "reliable")
func register_account(account_id: String, display_name: String = "", build: Dictionary = {}) -> void:
	if mode != Mode.SERVER or store == null or state == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not state.has_player(sender):
		return
	var character_id := account_id.strip_edges()
	if character_id == "":
		character_id = "peer_%d" % sender
	_peer_characters[sender] = character_id
	# Optional starting zone (carried on the build dict so the RPC signature is stable);
	# only honored when it names a real loaded zone, else the peer keeps the default.
	var requested_zone := String(build.get("zone", ""))
	if requested_zone != "" and zones != null and zones.has_zone(requested_zone):
		_peer_zones[sender] = requested_zone
		print("[net] peer %d assigned zone %s (%s)" % [sender, requested_zone, zones.effective_security(requested_zone)])
	var existing := state.get_player(sender)
	var record := store.load_record(character_id)
	var chosen_name := display_name.strip_edges()
	if chosen_name == "":
		chosen_name = String(record.get("name", existing.get("name", "")))
	if record.is_empty():
		record = _create_character(character_id, chosen_name, build)  # new char: run chargen
	else:
		record["name"] = chosen_name
	# Optional org membership (test affordance on the build dict): set the persisted
	# record.org and seed the org's territory influence in the player's current zone
	# (real influence accrual is a later slice). Always refresh _peer_orgs from the record.
	var build_org: Dictionary = build.get("org", {})
	if not build_org.is_empty() and String(build_org.get("faction_id", "")) != "":
		record["org"] = {
			"faction_id": String(build_org.get("faction_id", "")),
			"faction_axis": String(build_org.get("faction_axis", "independent")),
			"faction_rank": int(build_org.get("faction_rank", 1)),
			"faction_rep": int(build_org.get("faction_rep", 0)),
			"guild_ids": [],
		}
		store.save_record(character_id, record)
		var seed_infl := int(build_org.get("influence", 0))
		if seed_infl > 0:
			_set_territory_influence(String(build_org["faction_id"]), String(_peer_zones.get(sender, _default_zone)), seed_infl)
	if record.has("org") and typeof(record["org"]) == TYPE_DICTIONARY:
		_peer_orgs[sender] = String((record["org"] as Dictionary).get("faction_id", ""))
	var pos := PersistenceStore.record_pos(record, WorldState.SPAWN_POINT)
	var yaw := PersistenceStore.record_yaw(record, 0.0)
	state.restore_player(sender, pos, yaw, chosen_name)
	if arena != null:
		arena.set_player_combat(sender, PersistenceStore.combat_from_record(record))
		arena.set_player_name(sender, chosen_name)
		arena.set_player_sheet(sender, record.get("sheet", {}))  # combat uses the character's own stats
	print("[persist] peer %d -> %s (%s) loaded at (%.1f, %.1f, %.1f) [weapon=%s]" % [sender, character_id, chosen_name, pos.x, pos.y, pos.z,
		String((record.get("sheet", {}) as Dictionary).get("equipment", {}).get("weapon", "?"))])

func send_register(account_id: String, display_name: String = "", build: Dictionary = {}) -> void:
	if mode == Mode.CLIENT and connected:
		register_account.rpc_id(1, account_id, display_name, build)

# Build a brand-new character record: validate the requested WEG build (or use a
# deterministic quick-start) and persist it immediately.
func _create_character(character_id: String, display_name: String, build: Dictionary) -> Dictionary:
	var record := store.default_record(character_id, character_id, display_name, WorldState.SPAWN_POINT)
	var species_key := String(build.get("species", "human"))
	var species := _species_for(species_key)
	var sheet := {}
	if build.has("attributes") and not bool(build.get("quickstart", false)):
		var result: Dictionary = Chargen.validate_build(D6Rules, species, build.get("attributes", {}), build.get("skills", {}))
		if bool(result.get("valid", false)):
			sheet = result["sheet"]
		else:
			print("[chargen] invalid build for %s %s — using quick-start" % [character_id, str(result.get("errors", []))])
	if sheet.is_empty():
		sheet = Chargen.default_sheet(D6Rules, species)
	record["sheet"] = sheet
	record["species"] = species_key
	store.save_record(character_id, record)
	print("[chargen] created %s species=%s dex=%s cp=%d" % [
		character_id, species_key,
		String((sheet.get("attributes", {}) as Dictionary).get("dexterity", "?")),
		int(sheet.get("character_points", 0)),
	])
	return record

func _load_species() -> Dictionary:
	if not FileAccess.file_exists(SPECIES_DATA_PATH):
		return {}
	var file := FileAccess.open(SPECIES_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return (parsed as Dictionary).get("species", {})

func _load_json_container(path: String, key: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return (parsed as Dictionary).get(key, {})

func _species_for(species_key: String) -> Dictionary:
	var species: Dictionary = _species_data.get(species_key, {})
	if species.is_empty():
		species = _species_data.get("human", {})
	if species.is_empty():
		# Last-resort fallback so chargen never hard-fails if data is missing.
		var human_range := {"min": "2D", "max": "4D"}
		species = {"attributes": {
			"dexterity": human_range, "knowledge": human_range, "mechanical": human_range,
			"perception": human_range, "strength": human_range, "technical": human_range,
		}}
	return species

# --- C4: progression (CP earn + spend) ---
# client -> server: spend CP to raise one skill by a pip (server validates + persists)
@rpc("any_peer", "call_remote", "reliable")
func submit_skill_raise(skill: String) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := store.load_record(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var wallet: Dictionary = sheet.get("cp_wallet", Progression.new_wallet())
	var attribute := _attribute_for_skill(skill)
	var attr_code := String((sheet.get("attributes", {}) as Dictionary).get(attribute, "2D"))
	var bonus_code := String((sheet.get("skills", {}) as Dictionary).get(skill, "0D"))
	var result: Dictionary = Progression.raise_skill(D6Rules, wallet, attr_code, bonus_code)
	if bool(result.get("ok", false)):
		var skills: Dictionary = sheet.get("skills", {})
		skills[skill] = result["new_skill_bonus"]
		sheet["skills"] = skills
		sheet["cp_wallet"] = result["wallet"]
		record["sheet"] = sheet
		store.save_record(character_id, record)
		if arena != null:
			arena.set_player_sheet(sender, sheet)  # the raise takes effect in combat immediately
		print("[skillraise] peer %d %s %s -> %s (cost %d, attack pool now %s)" % [
			sender, skill, bonus_code, String(result["new_skill_bonus"]), int(result["cost"]),
			arena.attacker_pool_text(sender) if arena != null else "?"])
		skill_raise_result.rpc_id(sender, {"ok": true, "skill": skill, "new_bonus": result["new_skill_bonus"], "cost": result["cost"]})
		apply_wallet.rpc_id(sender, result["wallet"])
	else:
		print("[skillraise] peer %d %s rejected (%s, need %d)" % [sender, skill, String(result.get("reason", "")), int(result.get("cost", 0))])
		skill_raise_result.rpc_id(sender, {"ok": false, "skill": skill, "reason": result.get("reason", ""), "cost": result.get("cost", 0)})

func send_skill_raise(skill: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_skill_raise.rpc_id(1, skill)

# --- E22: inventory / equipment swap (D3) ---
# client -> server: equip a different OWNED item into a slot. The server validates it
# against the loaded catalog + the character's inventory, writes sheet.equipment,
# persists, and rebuilds combat pools so the swap takes effect immediately.
@rpc("any_peer", "call_remote", "reliable")
func submit_equip(slot: String, item_key: String) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := store.load_record(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var result: Dictionary = Equipment.equip(sheet, slot, item_key, _weapons_catalog, _armor_catalog)
	if bool(result.get("ok", false)):
		var new_sheet: Dictionary = result["sheet"]
		record["sheet"] = new_sheet
		store.save_record(character_id, record)
		if arena != null:
			arena.set_player_sheet(sender, new_sheet)  # swap takes effect in combat immediately
		print("[equip] peer %d %s -> %s (damage pool now %s)" % [
			sender, slot, item_key, arena.damage_pool_text(sender) if arena != null else "?"])
		equip_result.rpc_id(sender, {"ok": true, "slot": slot, "item_key": item_key})
	else:
		print("[equip] peer %d %s %s rejected (%s)" % [sender, slot, item_key, String(result.get("reason", ""))])
		equip_result.rpc_id(sender, {"ok": false, "slot": slot, "item_key": item_key, "reason": result.get("reason", "")})

func send_equip(slot: String, item_key: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_equip.rpc_id(1, slot, item_key)

# server -> client: the outcome of an equip request
@rpc("authority", "call_remote", "reliable")
func equip_result(result: Dictionary) -> void:
	equip_replied.emit(result)

# --- E23: org territory claim / release commands ---
# client -> server: claim a node in the player's CURRENT zone for their org. Validated
# via the org-model (valid member + rank>=3) + territory-model (zone claimable, influence
# floor, one-claim-per-node), then persisted into the live Territory so the resource tick
# credits the org treasury. The siege / hostile-takeover loop is owner-gated, NOT here.
@rpc("any_peer", "call_remote", "reliable")
func submit_claim_node(node_id: String) -> void:
	if mode != Mode.SERVER or territory == null or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var node := node_id.strip_edges()
	var org := _org_for_peer(sender)
	if org.is_empty():
		claim_result.rpc_id(sender, {"ok": false, "node_id": node, "reason": "no_org"})
		return
	var zone_id := String(_peer_zones.get(sender, _default_zone))
	var security_base := String(zones.get_zone(zone_id).get("security_base", "secured")) if zones != null else "secured"
	var org_id := String(org.get("faction_id", ""))
	var org_influence := _territory_influence_for(org_id, zone_id)
	var check: Dictionary = _org_model.can_claim_command(org, security_base, org_influence)
	if not bool(check["allowed"]):
		print("[territory] peer %d claim %s denied (%s)" % [sender, node, String(check["reason"])])
		claim_result.rpc_id(sender, {"ok": false, "node_id": node, "reason": String(check["reason"])})
		return
	var claim_id := "%s::%s" % [org_id, node]
	var claim: Dictionary = territory.claim_node(claim_id, node, zone_id, org_id, security_base, org_influence)
	if claim.is_empty():
		print("[territory] peer %d claim %s denied (node_unavailable / already claimed)" % [sender, node])
		claim_result.rpc_id(sender, {"ok": false, "node_id": node, "reason": "node_unavailable"})
		return
	print("[territory] peer %d (%s) CLAIMED %s in %s (tier %s, infl %d)" % [sender, org_id, node, zone_id, String(claim["influence_tier_at_claim"]), org_influence])
	claim_result.rpc_id(sender, {"ok": true, "node_id": node, "org_id": org_id, "zone_id": zone_id, "tier": String(claim["influence_tier_at_claim"])})

# client -> server: release the player's org claim on a node.
@rpc("any_peer", "call_remote", "reliable")
func submit_release_claim(node_id: String) -> void:
	if mode != Mode.SERVER or territory == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	var node := node_id.strip_edges()
	var org_id := String(_org_for_peer(sender).get("faction_id", ""))
	var claim_id := territory.claim_for_node(node)
	if claim_id == "" or String((territory.get_claim(claim_id) as Dictionary).get("org_id", "")) != org_id:
		claim_result.rpc_id(sender, {"ok": false, "node_id": node, "released": true, "reason": "not_your_claim"})
		return
	territory.release_claim(claim_id)
	print("[territory] peer %d (%s) RELEASED %s" % [sender, org_id, node])
	claim_result.rpc_id(sender, {"ok": true, "node_id": node, "released": true})

func send_claim_node(node_id: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_claim_node.rpc_id(1, node_id)

func send_release_claim(node_id: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_release_claim.rpc_id(1, node_id)

# server -> client: the outcome of a claim / release command
@rpc("authority", "call_remote", "reliable")
func claim_result(result: Dictionary) -> void:
	claim_replied.emit(result)

# The persisted org membership dict for a peer (loads the record). {} when none.
# JSON reload can widen ints to float, so coerce the numeric fields the org-model
# validates with a strict typeof == TYPE_INT check (faction_rank / faction_rep).
func _org_for_peer(peer_id: int) -> Dictionary:
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return {}
	var record := store.load_record(character_id)
	var org: Variant = record.get("org", {})
	if typeof(org) != TYPE_DICTIONARY:
		return {}
	var o: Dictionary = (org as Dictionary).duplicate()
	if o.has("faction_rank"):
		o["faction_rank"] = int(o["faction_rank"])
	if o.has("faction_rep"):
		o["faction_rep"] = int(o["faction_rep"])
	return o

func _territory_influence_for(org_id: String, zone_id: String) -> int:
	var by_zone: Dictionary = _territory_influence.get(org_id, {})
	return int(by_zone.get(zone_id, 0))

func _set_territory_influence(org_id: String, zone_id: String, value: int) -> void:
	if not _territory_influence.has(org_id):
		_territory_influence[org_id] = {}
	(_territory_influence[org_id] as Dictionary)[zone_id] = maxi(value, 0)

# A compact territory view for a peer's snapshot: their org treasury + claims in the zone.
func _territory_summary(org_id: String, zone_id: String) -> Dictionary:
	var claims_here: Array = []
	for cid in territory.claims:
		var c: Dictionary = territory.claims[cid]
		if String(c.get("zone_id", "")) == zone_id:
			claims_here.append({
				"node_id": String(c.get("node_id", "")),
				"org_id": String(c.get("org_id", "")),
				"tier": String(c.get("influence_tier_at_claim", "")),
			})
	return {
		"org_id": org_id,
		"treasury": territory.get_org_credits(org_id),
		"claims_in_zone": claims_here,
	}

# server -> client: push the player's current CP wallet
@rpc("authority", "call_remote", "reliable")
func apply_wallet(wallet: Dictionary) -> void:
	last_wallet = wallet
	wallet_updated.emit(wallet)

# server -> client: result of a skill-raise attempt
@rpc("authority", "call_remote", "reliable")
func skill_raise_result(result: Dictionary) -> void:
	skill_raise_replied.emit(result)

func _award_cp(peer_id: int, track: String, amount: int) -> void:
	if store == null:
		return
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var record := store.load_record(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var wallet: Dictionary = Progression.award(sheet.get("cp_wallet", Progression.new_wallet()), track, amount)
	sheet["cp_wallet"] = wallet
	record["sheet"] = sheet
	store.save_record(character_id, record)
	print("[cp] peer %d +%d %s (wallet g=%d r=%d)" % [peer_id, amount, track, int(wallet.get("gameplay_cp", 0)), int(wallet.get("rp_cp", 0))])
	apply_wallet.rpc_id(peer_id, wallet)

func _attribute_for_skill(skill: String) -> String:
	return String(_skill_attr.get(skill, "dexterity"))

func _load_skill_attributes() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(SKILL_CATALOG_PATH):
		return out
	var file := FileAccess.open(SKILL_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var groups: Dictionary = (parsed as Dictionary).get("skills", {})
	for attribute in groups:
		for entry in groups[attribute]:
			if typeof(entry) == TYPE_DICTIONARY:
				out[String((entry as Dictionary).get("key", ""))] = String((entry as Dictionary).get("attribute", attribute))
	return out

func _physics_process(delta: float) -> void:
	match mode:
		Mode.SERVER:
			var step := 1.0 / float(SERVER_TICK_HZ)
			_server_accum += delta
			while _server_accum >= step:
				state.tick(step)
				_server_accum -= step
			# Per-peer snapshot: shared world state + the player's OWN zone + territory view.
			for pid in multiplayer.get_peers():
				apply_snapshot.rpc_id(pid, _build_snapshot(String(_peer_zones.get(pid, _default_zone)), pid))
			_combat_accum += delta
			if _combat_accum >= combat_window_seconds:
				_combat_accum = 0.0
				_resolve_combat_window()
			_autosave_accum += delta
			if _autosave_accum >= AUTOSAVE_SECONDS:
				_autosave_accum = 0.0
				for pid in _peer_characters.keys():
					_save_peer(pid)
			_director_accum += delta
			if _director_accum >= director_tick_seconds:
				_director_accum = 0.0
				if zones != null:
					zones.director_tick()
			_resource_accum += delta
			if _resource_accum >= resource_tick_seconds:
				_resource_accum = 0.0
				if territory != null and territory.claim_count() > 0:
					var gained := territory.accrue_income()
					print("[territory] resource tick: %d claims, org gains %s; treasuries %s" % [territory.claim_count(), str(gained), str(territory.org_credits)])
		Mode.CLIENT:
			if not connected:
				return
			_client_accum += delta
			var step := 1.0 / float(CLIENT_SEND_HZ)
			if _client_accum >= step:
				_client_accum = 0.0
				submit_input.rpc_id(1, _local_move, _local_yaw, _local_jump)

func _build_snapshot(zone_id: String = CURRENT_ZONE, peer_id: int = 0) -> Dictionary:
	var snap := state.snapshot()
	if zones != null:
		snap["zone"] = zones.zone_summary(zone_id)
	if territory != null and peer_id != 0:
		snap["territory"] = _territory_summary(String(_peer_orgs.get(peer_id, "")), zone_id)
	return snap

# Seed the server's zone roster from data/zones_clone_wars.json (the Director ticks
# them all). Falls back to the single hardcoded Mos Eisley zone when the file is
# absent or malformed, so the server always has at least one zone. Sets _default_zone.
func _load_zones() -> void:
	var added := false
	if FileAccess.file_exists(ZONES_DATA_PATH):
		var file := FileAccess.open(ZONES_DATA_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var data: Dictionary = parsed
				var list: Array = data.get("zones", [])
				for entry in list:
					if typeof(entry) != TYPE_DICTIONARY:
						continue
					var z: Dictionary = entry
					var zid := String(z.get("zone_id", ""))
					if zid == "":
						continue
					zones.add_zone(zid, String(z.get("security_base", "secured")),
						z.get("influence", {}), z.get("baseline", {}),
						String(z.get("display_name", zid)))
					added = true
				var dz := String(data.get("default_zone", ""))
				if dz != "" and zones.has_zone(dz):
					_default_zone = dz
				elif not list.is_empty() and typeof(list[0]) == TYPE_DICTIONARY:
					_default_zone = String((list[0] as Dictionary).get("zone_id", CURRENT_ZONE))
	if not added:
		zones.add_zone(CURRENT_ZONE, "secured",
			{"republic": 55, "cis": 5, "hutt": 42, "independent": 25},
			{"republic": 50, "cis": 5, "hutt": 40, "independent": 25},
			"Mos Eisley Spaceport District")
		_default_zone = CURRENT_ZONE
	print("[net] %d zone(s) seeded; default=%s" % [zones.zones.size(), _default_zone])

func _load_combat_data() -> Dictionary:
	if not FileAccess.file_exists(COMBATANT_DATA_PATH):
		return {}
	var file := FileAccess.open(COMBATANT_DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _resolve_combat_window() -> void:
	if arena == null or arena.pending_intent_count() == 0:
		return
	var result := arena.resolve_window(_server_rng.randi())
	var envelopes: Array = result.get("envelopes", [])
	for envelope in envelopes:
		apply_combat_envelope.rpc(envelope)
	print("[combat] window %d resolved: %d shot(s), target severity %d" % [
		int(result.get("window", 0)),
		envelopes.size(),
		int((result.get("target_state", {}) as Dictionary).get("wound_severity", 0)),
	])
	if bool(result.get("target_disabled", false)):
		for envelope in envelopes:
			_award_cp(int(envelope.get("shooter_id", 0)), "gameplay", COMBAT_CP_REWARD)
		arena.reset_target()
		print("[combat] target disabled — respawned")

func _save_peer(peer_id: int) -> void:
	if store == null or state == null:
		return
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var player := state.get_player(peer_id)
	if player.is_empty():
		return
	var record := store.load_or_create(character_id, character_id, String(player.get("name", "")), WorldState.SPAWN_POINT)
	record = PersistenceStore.apply_position(record, player.get("pos", WorldState.SPAWN_POINT), float(player.get("yaw", 0.0)))
	if arena != null:
		record = PersistenceStore.apply_combat(record, arena.player_state(peer_id))
	record["name"] = String(player.get("name", ""))
	store.save_record(character_id, record)
