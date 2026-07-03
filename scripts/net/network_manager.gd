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
const PendingInfluence := preload("res://scripts/net/pending_influence_model.gd")
const ChatModel := preload("res://scripts/net/chat_model.gd")
const Auth := preload("res://scripts/net/account_auth_model.gd")
const AmbientSim := preload("res://scripts/net/ambient_sim_model.gd")
const Recovery := preload("res://scripts/rules/recovery_model.gd")
const DerivedStats := preload("res://scripts/rules/derived_stats_model.gd")
const WoundLadder := preload("res://scripts/rules/wound_ladder_model.gd")  # F46: surface the WEG action penalty
const EconomyModel := preload("res://scripts/rules/economy_model.gd")      # Wave F: WEG-anchored buy/sell/loot (DIV-0018)
const VendorModel := preload("res://scripts/rules/vendor_model.gd")        # vendor stock + Bargain/Director pricing
const ReputationModel := preload("res://scripts/rules/reputation_model.gd") # standing-tier buy discount
const HostileNpc := preload("res://scripts/rules/hostile_npc_model.gd")     # DIV-0017: creature -> lethal target pools
const CreatureSpawn := preload("res://scripts/rules/creature_spawn_model.gd") # seeded hostile spawn rolls
const CreatureSpecialAttack := preload("res://scripts/rules/creature_special_attack_model.gd") # DIV-0024: venom/restraint riders
const DeathPenalty := preload("res://scripts/rules/death_penalty_model.gd")   # DIV-0006: death penalty + respawn
const ForceAwaken := preload("res://scripts/rules/force_awakening_model.gd")   # DIV-0011: SWG-Village earned unlock
const PvpRules := preload("res://scripts/rules/pvp_rules_model.gd")            # DIV-0019: zone-based PvP consent gate
const DOWNED := preload("res://scripts/rules/downed_model.gd")                 # DIV-0027: death tiering + downed escape hatch
const QuestModel := preload("res://scripts/rules/quest_model.gd")              # DIV-0020: accepted quests + progress + reward
const HarvestModel := preload("res://scripts/rules/harvest_model.gd")          # DIV-0023: a disabled creature -> a sellable field-dressed good
const CorpseDecay := preload("res://scripts/rules/corpse_decay_model.gd")       # DIV-0025: player-corpse decay + third-party full-loot (lawless)
const ArmorRepairModel := preload("res://scripts/rules/armor_repair_model.gd")  # DIV-0026 (Seam 4b): armor broken-tier repair credit-sink (priced off sell_price)
const TelemetryLog := preload("res://scripts/net/telemetry_log.gd")              # Wave G (Seam 5): server-side structured-telemetry writer (JSONL under user://)
const COMBATANT_DATA_PATH := "res://data/prototype_combatants.json"
const SPECIES_DATA_PATH := "res://data/species_clone_wars.json"
const SKILL_CATALOG_PATH := "res://data/weg_skill_catalog.json"
const WEAPONS_DATA_PATH := "res://data/weapons_clone_wars.json"
const ARMOR_DATA_PATH := "res://data/armor_clone_wars.json"
const CREATURES_DATA_PATH := "res://data/creatures_clone_wars.json"
const VENDOR_STOCK_PATH := "res://data/vendor_stock_by_zone.json"  # per-zone vendor variety (overnight C1)
const NPCS_DATA_PATH := "res://data/npcs_clone_wars.json"  # named NPCs (overnight C1) placed per zone
const QUESTS_DATA_PATH := "res://data/quests_clone_wars.json"  # DIV-0020: quest defs — notice board + rewards
const HARVEST_VALUES_PATH := "res://data/harvest_values_clone_wars.json"  # DIV-0023: per-good/per-resource harvest credit values (Option A)
const HOSTILE_DISTANCE := 10.0  # DIV-0017: nominal engagement range for a spawned hostile creature
const CORPSE_LOOT_RADIUS := 12.0  # DIV-0025: how close a third party must stand to loot a player's corpse
const COMBAT_CP_REWARD := 3   # gameplay CP for disabling the training target (prototype-tunable)
const DISABLE_INFLUENCE := 5  # Director zone-influence a disable feeds to the shooter's faction axis (owner-tunable)
const KILL_TERRITORY_INFLUENCE := Territory.KILL_TERRITORY_INFLUENCE  # F63: defined in territory_model (co-located with the claim floor)
# DIV-0012: wound tiers a character recovers from naturally (own Strength vs Guide_19 §3
# difficulty, one Director tick = one recovery interval). incapacitated/mortally_wounded/
# dead are EXCLUDED — they need First Aid/Medicine by another, and the lethal tiers are
# owner-gated death (DIV-0006).
const HEALABLE_WOUND_LEVELS := ["stunned", "wounded", "wounded_twice"]

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
signal chat_received(message: Dictionary)
signal auth_replied(result: Dictionary)
signal heal_replied(result: Dictionary)
signal zone_replied(result: Dictionary)
signal sheet_updated(summary: Dictionary)
signal credits_updated(credits: int)       # Wave F economy: the player's credit balance changed
signal vendor_listed(payload: Dictionary)   # server-priced vendor stock
signal buy_replied(result: Dictionary)
signal sell_replied(result: Dictionary)
signal repair_replied(result: Dictionary)   # DIV-0026 (Seam 4b): outcome of an armor repair
signal died(notice: Dictionary)             # DIV-0006: this client was killed + respawned
signal downed(notice: Dictionary)           # DIV-0027: this client was downed-in-field (sev 3-4, not dead)
signal revived(notice: Dictionary)          # DIV-0027: this client was First-Aided back above the downed floor
signal insurance_replied(result: Dictionary) # DIV-0006: buy-insurance outcome
signal force_awakened_replied(notice: Dictionary) # DIV-0011: this client's Force sensitivity awakened
signal fire_rejected(result: Dictionary)    # DIV-0019: a PvP fire intent was refused (zone/consent)
signal quests_updated(quests: Dictionary)   # DIV-0020: this client's live quest progress changed
signal quest_catalog_received(defs: Dictionary) # DIV-0020: the available-quest catalog (notice board)
signal harvested(notice: Dictionary)        # DIV-0023: this client field-dressed a disabled creature into a sellable good
signal loot_corpse_replied(result: Dictionary) # DIV-0025: outcome of looting another player's corpse

var mode: int = Mode.NONE
var state: WorldState = null          # server only
var arena: CombatArena = null         # server only
var store: PersistenceStore = null    # server only
var zones: ZoneState = null           # server only (world-sim director)
var territory: Territory = null       # server only (org claims + passive income)
var _org_model = null                 # server only (OrgModel instance: claim validation)
var _pending_model = null             # server only (PendingInfluence instance: E24 loop)
var _derived = null                   # server only (DerivedStats instance: DIV-0015 species move)
var _vendor = null                    # server only (VendorModel instance: buy pricing / stock)
var _reputation = null                # server only (ReputationModel instance: standing-tier discount)
var _buy_catalog := {}                # server only (merged {item_key -> {cost, vendor_stocked, name, kind}})
var _creature_spawn = null            # server only (CreatureSpawn instance: seeded hostile spawn rolls)
var _creatures_data := {}             # server only (creatures container for the spawner)
var _vendor_stock_by_zone := {}       # server only (zone_id -> {item_keys:[...]}) per-zone vendor variety
var _named_npcs_by_zone := {}         # server only (zone_id -> [named-NPC snapshot entries w/ deterministic pos])
var _quest_defs := {}                 # server only (DIV-0020: quest_id -> def; the notice-board catalog)
var _harvest_values := {}             # server only (DIV-0023: {by_good, by_resource, default} credit values for field-dressed goods)
var force_hostile_key := ""           # TEST-ONLY: force this creature key to spawn in lethal zones (--force-hostile)
var force_awaken_now := false         # TEST-ONLY: force a connected latent to awaken next Director tick (--force-awaken)
var _visited_zones := {}              # DIV-0011: character_id -> {zone_id:true} for the distinct-zones awakening signal
var combat_window_seconds: float = COMBAT_WINDOW_SECONDS
var director_tick_seconds: float = DIRECTOR_TICK_SECONDS
var resource_tick_seconds: float = RESOURCE_TICK_SECONDS
# Security gate: the register_account `build.org` affordance lets a client self-assign org
# identity/rank/territory-influence. That is a TEST-ONLY convenience and MUST stay off on a real
# server (otherwise any peer self-grants a rank-99 faction + claim-floor influence over the wire,
# bypassing the owner-gated faction-join and the earn-through-play territory loop). Off by default;
# the headless two-process harness opts in with `--allow-test-org`.
var allow_test_org := false

var _species_data := {}               # server only (chargen species ranges)
var _skill_attr := {}                 # server only (skill key -> governing attribute)
var _weapons_catalog := {}            # server only (weapon key -> stats; for equip)
var _armor_catalog := {}              # server only (armor key -> stats; for equip)
var last_snapshot: Dictionary = {}    # client view of the world
var last_wallet: Dictionary = {}      # client view of its own CP wallet
var last_credits: int = 0             # client view of its own credit balance (Wave F economy)
var last_quests: Dictionary = {}      # client view of its own quest progress (DIV-0020)
var quest_catalog: Dictionary = {}    # client view of the quest catalog / notice board (DIV-0020)
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
var _peer_axes := {}                  # peer_id -> faction_axis (server; E24 influence)
var _peer_ranks := {}                 # peer_id -> faction_rank (server; F34 territory-authority HUD)
var _territory_influence := {}        # org_id -> {zone_id -> int} (server; territory infl)
var _pending_zone_influence := []     # E8/E24: [{zone_id, axis, delta}] accrued from play
var _record_cache := {}               # E26: character_id -> record (kills per-call JSON I/O)
var _peer_rpc_budget := {}            # E26: peer_id -> {tokens, last_ms} reliable-RPC bucket
var _ambient := {}                    # E27: zone_id -> ambient NPC roster (Director-advanced)
var _heal_treated := {}               # DIV-0013: target_peer -> wound level last First-Aided (retry gate)
var _downed := {}                     # DIV-0027: peer -> {severity:int, killer:int, name:String, rounds:int} — server-only downed-in-field state (rebuilt on login from persisted wound_state)
var _corpses := {}                    # DIV-0025: character_id -> {zone_id, pos:{x,y,z}, decay_unix:float, security_tier:String} — server-only corpse index (rebuilt from records on boot)
var _zone_list_cache: Array = []      # DIV-0014: cached [{id, name}] travel list (zones are static)
var _server_rng := RandomNumberGenerator.new()
var _telemetry: TelemetryLog = null   # server only (Wave G/Seam 5: structured-telemetry JSONL writer; null in client/solo)
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
	_pending_model = PendingInfluence.new()
	# F58/F59: restore the persisted world (faction influence + pending + org claims) over the
	# seeded roster. AFTER territory/pending are created so their state can be restored too.
	_load_world_state()
	_scan_corpses()  # DIV-0025: rebuild the corpse registry from persisted records so bodies survive a restart
	_derived = DerivedStats.new()
	_vendor = VendorModel.new()
	_reputation = ReputationModel.new()
	_build_buy_catalog()  # merged priced catalog for buy/sell (Wave F economy)
	_creature_spawn = CreatureSpawn.new()
	_creatures_data = _load_json_root(CREATURES_DATA_PATH)  # DIV-0017: hostile spawn source
	_harvest_values = _load_json_root(HARVEST_VALUES_PATH)  # DIV-0023: harvest good -> credit value (Option A)
	_vendor_stock_by_zone = _load_json_container(VENDOR_STOCK_PATH, "vendor_stock_by_zone")  # per-zone vendor variety
	_load_named_npcs()  # named NPCs placed per zone (broadcast in the snapshot for client rendering)
	_quest_defs = QuestModel.defs_from_data(_load_json_root(QUESTS_DATA_PATH))  # DIV-0020: notice-board quest catalog
	_species_data = _load_species()
	_skill_attr = _load_skill_attributes()
	_server_rng.randomize()
	_telemetry = TelemetryLog.new()  # Wave G/Seam 5: one server-owned JSONL writer under user://telemetry/events.jsonl
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
	_telemetry = null  # drop the server-only telemetry writer so a later start_client never keeps a live server writer

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
	# A peer enters the world (state/arena/zone) ONLY on a successful register_account auth — not on
	# raw ENet connect — so an un-authenticated peer is never a simulated, snapshot-broadcast ghost
	# avatar. Its gameplay RPCs are dropped too: they all gate on state.has_player (false until auth).
	print("[net] peer %d connected (awaiting auth)" % id)

func _on_peer_disconnected(id: int) -> void:
	if mode != Mode.SERVER:
		return
	_save_peer(id)
	var character_id := String(_peer_characters.get(id, ""))  # capture before the map erase below
	state.remove_player(id)
	if arena != null:
		arena.remove_player(id)
		arena.clear_intents_targeting(id)  # DIV-0019: cancel PvP shots aimed at a player who disconnected
	_peer_characters.erase(id)
	_peer_zones.erase(id)
	_peer_orgs.erase(id)
	_peer_axes.erase(id)
	_peer_ranks.erase(id)  # F34: territory-authority rank
	_peer_rpc_budget.erase(id)
	_heal_treated.erase(id)  # DIV-0013: drop this peer's First-Aid retry gate (keyed by target peer)
	_downed.erase(id)  # DIV-0027: no orphan downed-tick against an absent peer (persisted wound_state carries it to relogin)
	if character_id != "": _visited_zones.erase(character_id)  # DIV-0011: drop the distinct-zones tracker
	# Evict the record cache on disconnect: _save_peer just flushed final state to disk, the
	# single-session lock means no other peer holds this character, and the next login does a
	# fresh read-through. Bounds _record_cache to connected players (no unbounded session leak)
	# and prevents a record outliving its session.
	if character_id != "" and _record_cache.erase(character_id):
		print("[cache] evicted %s on disconnect (cache size=%d)" % [character_id, _record_cache.size()])
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
	if not state.has_player(sender):
		return
	# F32: an incapacitated/mortally/dead character (arena wound >= DISABLED_SEVERITY) is out
	# and cannot move — zero their input (mirrors F31's no-fire gate so the "out" state is coherent).
	var can_act := true
	if arena != null and arena.has_player(sender):
		can_act = int((arena.player_state(sender) as Dictionary).get("player_wound_severity", 0)) < CombatArena.DISABLED_SEVERITY
	state.set_input(sender, move, yaw, jump, can_act)

@rpc("authority", "call_remote", "unreliable_ordered")
func apply_snapshot(snapshot: Dictionary) -> void:
	last_snapshot = snapshot
	snapshot_applied.emit(snapshot)

# client -> server: a fire intent for the current combat window. A non-zero intent.target_peer names a
# PLAYER target (DIV-0019 PvP): the server gates it here on live zone/security (open PvP only in a
# shared LAWLESS zone) and re-validates at resolution (_build_pvp_gate). target_peer 0 = the shared
# dummy/creature, unchanged.
@rpc("any_peer", "call_remote", "reliable")
func submit_fire_intent(intent: Dictionary) -> void:
	if mode != Mode.SERVER or arena == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	if not arena.has_player(sender):
		return
	var target := int(intent.get("target_peer", 0))
	if target != 0:
		if target == sender or not arena.has_player(target) or zones == null:
			return  # no self-fire / phantom target
		var sz := String(_peer_zones.get(sender, _default_zone))
		var tz := String(_peer_zones.get(target, _default_zone))
		var gate: Dictionary = PvpRules.can_fire(sz, tz, zones.effective_security(sz), zones.effective_security(tz))
		if not bool(gate.get("allowed", false)):
			print("[pvp] peer %d fire on %d refused (%s)" % [sender, target, String(gate.get("reason", ""))])
			fire_result.rpc_id(sender, {"ok": false, "reason": String(gate.get("reason", "rejected")), "target_peer": target})
			return
	arena.submit_fire_intent(sender, intent)

# server -> client: a PvP fire intent was refused (protected zone / different zone / etc.)
@rpc("authority", "call_remote", "reliable")
func fire_result(result: Dictionary) -> void:
	fire_rejected.emit(result)

# DIV-0019: the authoritative RESOLVE-TIME PvP re-gate. Re-checks every queued player-target pair
# against live zone/security (closing a Director mid-window tier-flip) into a {shooter: true} map the
# zone-agnostic arena consumes. Only same-zone lawless pairs are authorized.
func _build_pvp_gate() -> Dictionary:
	var gate := {}
	if arena == null or zones == null:
		return gate
	var pending: Dictionary = arena.pending_pvp_targets()
	for shooter in pending:
		var target := int(pending[shooter])
		if target == int(shooter) or not arena.has_player(target):
			continue
		var sz := String(_peer_zones.get(int(shooter), _default_zone))
		var tz := String(_peer_zones.get(target, _default_zone))
		if bool(PvpRules.can_fire(sz, tz, zones.effective_security(sz), zones.effective_security(tz)).get("allowed", false)):
			gate[int(shooter)] = true
	return gate

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
	if not _rate_ok(sender):
		return
	# NOTE: do NOT require state.has_player here — a first-time auth is exactly the case where the
	# peer is not yet in the world. World-entry happens below, only after auth+bind succeeds.
	var character_id := account_id.strip_edges()
	if character_id == "":
		character_id = "peer_%d" % sender
	# E26 ownership guard: present the matching account_secret (if the record has one)
	# BEFORE loading/overwriting this character. An unsecured account is claimed by the
	# provided secret; a wrong secret is rejected without touching the character.
	var record := _cached_load(character_id)
	var auth: Dictionary = Auth.check_secret(String(record.get("account_secret", "")), String(build.get("secret", "")))
	if not bool(auth["ok"]):
		print("[auth] peer %d denied for %s (%s)" % [sender, character_id, String(auth["reason"])])
		auth_result.rpc_id(sender, {"ok": false, "reason": String(auth["reason"]), "account_id": character_id})
		return
	# Single-session lock: refuse to bind a character another connected peer already owns
	# (two authorized sessions on one character would clobber it via last-writer-wins saves
	# + a shared cached record).
	for pid in _peer_characters.keys():
		if pid != sender and String(_peer_characters[pid]) == character_id:
			print("[auth] peer %d denied for %s (already_logged_in)" % [sender, character_id])
			auth_result.rpc_id(sender, {"ok": false, "reason": "already_logged_in", "account_id": character_id})
			return
	# Flush the OUTGOING character before re-pointing the live slot. A same-peer switch A->B leaves the
	# peer in state/arena, so world-entry below is skipped and the slot is just re-pointed at B — but
	# A's live position (WorldState) + combat (arena) are persisted ONLY by _save_peer, which keys on
	# _peer_characters[sender]. Without this flush a same-peer character switch silently discards up to
	# one autosave interval (~30s) of A's movement + in-window wound/CP. Safe here: on a re-register the
	# peer is already in state and _peer_characters[sender] still holds A.
	if _peer_characters.has(sender) and String(_peer_characters[sender]) != character_id:
		_save_peer(sender)
	_peer_characters[sender] = character_id
	# World-entry: an authenticated peer enters the simulation HERE (formerly on raw connect). First
	# auth -> add to state/arena at the default zone; a re-register (already in state) skips this.
	if not state.has_player(sender):
		state.add_player(sender)
		if arena != null:
			arena.register_player(sender)
		_peer_zones[sender] = _default_zone
		print("[net] peer %d entered world via auth (players=%d)" % [sender, state.player_count()])
		player_joined.emit(sender)
	# Optional starting zone (carried on the build dict so the RPC signature is stable);
	# only honored when it names a real loaded zone, else the peer keeps the default. With no
	# explicit request, restore the last-traveled zone persisted on the record (DIV-0014).
	var requested_zone := String(build.get("zone", ""))
	if requested_zone == "":
		requested_zone = String(record.get("zone", ""))
	if requested_zone != "" and zones != null and zones.has_zone(requested_zone):
		_peer_zones[sender] = requested_zone
		print("[net] peer %d assigned zone %s (%s)" % [sender, requested_zone, zones.effective_security(requested_zone)])
	var existing := state.get_player(sender)
	var chosen_name := display_name.strip_edges()
	if chosen_name == "":
		chosen_name = String(record.get("name", existing.get("name", "")))
	# G7: canonical Star Wars figure names are reserved (Chargen.is_reserved_name, ported from the MUSH
	# name policy). Enforce at the single registration name-resolution point by falling back to the
	# account id — this is the one name that flows to the record, world state, and arena, so a reserved
	# name can never land. A client-facing rejection message is a follow-up (needs an error round-trip).
	if chosen_name != "" and Chargen.is_reserved_name(chosen_name):
		print("[chargen] reserved name '%s' rejected -> using account id '%s'" % [chosen_name, character_id])
		chosen_name = character_id
	if record.is_empty():
		record = _create_character(character_id, chosen_name, build)  # new char: run chargen
	else:
		record["name"] = chosen_name
	# E26: bind/persist the account secret on the record (the first claim writes it).
	var new_secret := String(auth["secret"])
	if String(record.get("account_secret", "")) != new_secret:
		record["account_secret"] = new_secret
		_cached_save(character_id, record)
	# Optional org membership (TEST-ONLY affordance on the build dict, gated by allow_test_org):
	# set the persisted record.org and seed the org's territory influence in the player's current
	# zone. On a normal server this branch is OFF, so a client cannot self-assign faction/rank/
	# influence over the wire — org membership originates server-side (the owner-gated faction-join)
	# and territory influence accrues only through play (_accrue_territory_influence on kills).
	# Always refresh _peer_orgs from the record (a server-granted org loaded from disk still applies).
	var build_org: Dictionary = build.get("org", {})
	if allow_test_org and not build_org.is_empty() and String(build_org.get("faction_id", "")) != "":
		record["org"] = {
			"faction_id": String(build_org.get("faction_id", "")),
			"faction_axis": String(build_org.get("faction_axis", "independent")),
			"faction_rank": int(build_org.get("faction_rank", 1)),
			"faction_rep": int(build_org.get("faction_rep", 0)),
			"guild_ids": [],
		}
		_cached_save(character_id, record)
		var seed_infl := int(build_org.get("influence", 0))
		if seed_infl > 0:
			_set_territory_influence(String(build_org["faction_id"]), String(_peer_zones.get(sender, _default_zone)), seed_infl)
	if record.has("org") and typeof(record["org"]) == TYPE_DICTIONARY:
		_peer_orgs[sender] = String((record["org"] as Dictionary).get("faction_id", ""))
		_peer_axes[sender] = String((record["org"] as Dictionary).get("faction_axis", ""))
		_peer_ranks[sender] = int((record["org"] as Dictionary).get("faction_rank", 0))  # F34
	else:
		_peer_orgs.erase(sender)  # clear stale org/axis on re-register to a no-org character
		_peer_axes.erase(sender)
		_peer_ranks.erase(sender)
	var pos := PersistenceStore.record_pos(record, WorldState.SPAWN_POINT)
	var yaw := PersistenceStore.record_yaw(record, 0.0)
	state.restore_player(sender, pos, yaw, chosen_name)
	# DIV-0015: set the authoritative real-time move speed from the species' WEG Move rate,
	# scaled to the baseline (move 10 -> the established 6.5; wookiee 11 -> ~7.15; etc.).
	if _derived != null:
		var species_move := int(_derived.move_for_species({"species": _species_data}, String(record.get("species", "human"))))
		var move_speed := WorldState.MOVE_SPEED * float(species_move) / float(DerivedStats.DEFAULT_MOVE)
		state.set_move_speed(sender, move_speed)
		print("[move] peer %d species=%s move=%d speed=%.2f" % [sender, String(record.get("species", "human")), species_move, move_speed])
	if arena != null:
		arena.set_player_combat(sender, PersistenceStore.combat_from_record(record))
		arena.set_player_name(sender, chosen_name)
		arena.set_player_sheet(sender, record.get("sheet", {}))  # combat uses the character's own stats
	# DIV-0027: MANDATORY anti-softlock. Combat damage IS persisted (apply_combat flushes the live wound
	# to sheet.wound_state), so a player who logged out DOWNED (incapacitated/mortally_wounded) reloads
	# frozen by the arena DISABLED guard. Reconstruct _downed + re-send the downed_notice so BOTH escape
	# hatches (the bleed-out tick + the yield command) are restored — a logout-while-downed is not a softlock.
	var restored_sev := PersistenceStore.severity_for_wound_state(String((record.get("sheet", {}) as Dictionary).get("wound_state", "healthy")))
	if DOWNED.is_downed_severity(restored_sev):
		_downed[sender] = {"severity": restored_sev, "killer": 0, "name": "your wounds", "rounds": 0}
		if mode == Mode.SERVER:
			downed_notice.rpc_id(sender, {"severity": restored_sev, "killer": "your wounds", "can_yield": true, "bleeding": (restored_sev >= 4)})
	print("[persist] peer %d -> %s (%s) loaded at (%.1f, %.1f, %.1f) [weapon=%s]" % [sender, character_id, chosen_name, pos.x, pos.y, pos.z,
		String((record.get("sheet", {}) as Dictionary).get("equipment", {}).get("weapon", "?"))])
	_push_sheet(sender, record)  # F24: send the character sheet to the client's sheet panel
	apply_credits.rpc_id(sender, int((record.get("sheet", {}) as Dictionary).get("credits", 0)))  # Wave F: show the wallet on login
	_push_quests(sender, record)  # DIV-0020: quest catalog (notice board) + this player's live progress

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
	# Debug/test affordance (DIV-0012 verification): start a new character at a recoverable
	# wound tier so the recovery tick has something to heal. Only the "can still act" tiers.
	var start_wound := String(build.get("wound", ""))
	if HEALABLE_WOUND_LEVELS.has(start_wound):
		sheet["wound_state"] = start_wound
	record["sheet"] = sheet
	record["species"] = species_key
	record["quests"] = QuestModel.initial_quests()  # DIV-0020: empty accepted-quest block
	_cached_save(character_id, record)
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

# Load a JSON file's full top-level object (creature_spawn_model.roll_spawn wants the {"creatures":{...}} root).
func _load_json_root(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

# Load named NPCs (data/npcs_clone_wars.json), give each a DETERMINISTIC position (hash of id -> a
# point scattered around the shared settlement), map role/flags to an npc_builder kind, and group by
# zone. Precomputed once at boot; the per-zone list rides the snapshot for the client to render.
func _load_named_npcs() -> void:
	_named_npcs_by_zone = {}
	var npcs: Array = _load_json_root(NPCS_DATA_PATH).get("npcs", [])
	for entry in npcs:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var npc: Dictionary = entry
		var zone_id := String(npc.get("zone_id", ""))
		if zone_id == "":
			continue
		var id := String(npc.get("id", ""))
		var h := absi(hash(id))
		var angle := fposmod(float(h) * 0.6180339887, 1.0) * TAU
		var radius := 8.0 + fposmod(float(h / 7) * 0.381966011, 1.0) * 30.0
		if not _named_npcs_by_zone.has(zone_id):
			_named_npcs_by_zone[zone_id] = []
		(_named_npcs_by_zone[zone_id] as Array).append({
			"id": id,
			"name": String(npc.get("name", id)),
			"role": String(npc.get("role", "")),
			"faction_axis": String(npc.get("faction_axis", "independent")),
			"kind": _npc_kind(npc),
			"pos": {"x": cos(angle) * radius, "y": WorldState.GROUND_Y, "z": sin(angle) * radius},
			"lines": npc.get("dialogue_lines", []),
		})
	var counts := {}
	for z in _named_npcs_by_zone:
		counts[z] = (_named_npcs_by_zone[z] as Array).size()
	print("[npc] named NPCs by zone: %s" % str(counts))

# Map an NPC's role / flags to an npc_builder mesh kind.
func _npc_kind(npc: Dictionary) -> String:
	if bool(npc.get("vendor", false)):
		return "vendor"
	var role := String(npc.get("role", "")).to_lower()
	for pair in [["bounty", "hunter"], ["hunter", "hunter"], ["liaison", "official"], ["customs", "official"], ["official", "official"], ["officer", "official"], ["enforcer", "thug"], ["thug", "thug"], ["guard", "thug"], ["mechanic", "mechanic"], ["tech", "mechanic"], ["broker", "broker"], ["fixer", "broker"], ["slicer", "broker"], ["pilot", "pilot"], ["merchant", "vendor"], ["trader", "vendor"], ["barkeep", "vendor"], ["bartender", "vendor"]]:
		if role.find(String(pair[0])) >= 0:
			return String(pair[1])
	return "civilian"

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
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
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
		_cached_save(character_id, record)
		if arena != null:
			arena.set_player_sheet(sender, sheet)  # the raise takes effect in combat immediately
		print("[skillraise] peer %d %s %s -> %s (cost %d, attack pool now %s)" % [
			sender, skill, bonus_code, String(result["new_skill_bonus"]), int(result["cost"]),
			arena.attacker_pool_text(sender) if arena != null else "?"])
		skill_raise_result.rpc_id(sender, {"ok": true, "skill": skill, "new_bonus": result["new_skill_bonus"], "cost": result["cost"]})
		apply_wallet.rpc_id(sender, result["wallet"])
		_push_sheet(sender, record)  # F24: refresh the sheet panel after the raise
		_feed_force_signal(sender, "cp_spent", int(result["cost"]))  # DIV-0011: spending CP nudges the awakening track
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
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var result: Dictionary = Equipment.equip(sheet, slot, item_key, _weapons_catalog, _armor_catalog)
	if bool(result.get("ok", false)):
		var new_sheet: Dictionary = result["sheet"]
		record["sheet"] = new_sheet
		_cached_save(character_id, record)
		if arena != null:
			arena.set_player_sheet(sender, new_sheet)  # swap takes effect in combat immediately
		print("[equip] peer %d %s -> %s (damage pool now %s)" % [
			sender, slot, item_key, arena.damage_pool_text(sender) if arena != null else "?"])
		equip_result.rpc_id(sender, {"ok": true, "slot": slot, "item_key": item_key})
		_push_sheet(sender, record)  # F24: refresh the sheet panel after the swap
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

# --- DIV-0013: First Aid / Medicine — a medic heals a wounded ally ---
# client -> server: apply First Aid to another CONNECTED player in the SAME zone. Heal pool =
# the healer's Technical attribute + first_aid skill; rolled vs the target's wound-level
# difficulty (Guide_19 §3, server-owned seed). Success drops the target's wound ONE level
# (CAN treat incapacitated + stabilize mortally_wounded; healthy/dead rejected). A per-target
# retry gate blocks re-treating the same wound level until it changes (no spam-to-success).
# Cooperative healing only — NOT PvP (owner-gated); no death roll/penalty here.
@rpc("any_peer", "call_remote", "reliable")
func submit_heal(target_id: int) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var healer := multiplayer.get_remote_sender_id()
	if not _rate_ok(healer):
		return
	var healer_char := String(_peer_characters.get(healer, ""))
	if healer_char == "":
		return
	if target_id == healer:
		heal_result.rpc_id(healer, {"ok": false, "reason": "self"})
		return
	var target_char := String(_peer_characters.get(target_id, ""))
	if target_char == "":
		heal_result.rpc_id(healer, {"ok": false, "reason": "no_target"})
		return
	if String(_peer_zones.get(healer, _default_zone)) != String(_peer_zones.get(target_id, _default_zone)):
		heal_result.rpc_id(healer, {"ok": false, "reason": "out_of_range"})
		return
	var t_record := _cached_load(target_char)
	if t_record.is_empty():
		heal_result.rpc_id(healer, {"ok": false, "reason": "no_target"})
		return
	var t_sheet: Dictionary = t_record.get("sheet", {})
	var level := _live_wound_state(target_id, t_sheet)  # DIV-0016: treat the LIVE combat wound, not the autosave-lagged sheet
	if level == "healthy":
		heal_result.rpc_id(healer, {"ok": false, "reason": "no_wound", "target_id": target_id})
		return
	if level == "dead":
		heal_result.rpc_id(healer, {"ok": false, "reason": "beyond_help", "target_id": target_id})
		return
	if String(_heal_treated.get(target_id, "")) == level:
		heal_result.rpc_id(healer, {"ok": false, "reason": "already_treated", "target_id": target_id})
		return
	_heal_treated[target_id] = level  # one First Aid per wound level until it changes
	var h_sheet: Dictionary = _cached_load(healer_char).get("sheet", {})
	var tech := String((h_sheet.get("attributes", {}) as Dictionary).get("technical", "2D"))
	var first_aid := String((h_sheet.get("skills", {}) as Dictionary).get("first_aid", "0D"))
	var heal_pool: Dictionary = D6Rules.add_pools(D6Rules.parse_pool(tech), D6Rules.parse_pool(first_aid))
	var result: Dictionary = Recovery.heal_check(_server_rng, heal_pool, level)
	var healed := bool(result.get("healed", false))
	var new_level := String(result.get("new_level", level))
	if healed:
		t_sheet["wound_state"] = new_level
		t_record["sheet"] = t_sheet
		_cached_save(target_char, t_record)
		_feed_force_signal(healer, "heals_given", 1)      # DIV-0011: saving an ally nudges the medic's track
		_feed_force_signal(target_id, "recoveries", 1)    # DIV-0011: surviving a wound nudges the patient's track
		if arena != null:
			# G2: pass the wound LEVEL string too (the severity int collapses wounded_twice->wounded).
			arena.set_player_combat(target_id, {"player_wound_severity": PersistenceStore.severity_for_wound_state(new_level), "player_wound_level": new_level})
		# DIV-0027: First Aid is the REVIVE path. A heal that drops the live severity below the downed
		# floor clears _downed immediately (dismisses the victim's card, stops the bleed-out tick); a
		# partial mortally->incap heal keeps them downed but updates the tracked severity so the sev-4
		# bleed-out stops calling death_roll.
		if _downed.has(target_id):
			var healed_sev := PersistenceStore.severity_for_wound_state(new_level)
			if healed_sev < CombatArena.DISABLED_SEVERITY:
				_clear_downed(target_id)
				if mode == Mode.SERVER:
					revived_notice.rpc_id(target_id, {"healer": healer, "to": new_level})
			else:
				(_downed[target_id] as Dictionary)["severity"] = healed_sev
		if new_level == "healthy":
			_heal_treated.erase(target_id)  # fully healed -> reset the retry gate (a future wound is fresh)
	print("[firstaid] peer %d -> peer %d (%s): %s -> %s (First Aid %s rolled %d vs %d)" % [
		healer, target_id, target_char, level, new_level,
		String(D6Rules.pool_to_string(heal_pool)), int(result.get("roll_total", 0)), int(result.get("difficulty", 0))])
	heal_result.rpc_id(healer, {"ok": healed, "reason": "" if healed else "failed",
		"target_id": target_id, "from": level, "to": new_level})

func send_heal(target_id: int) -> void:
	if mode == Mode.CLIENT and connected:
		submit_heal.rpc_id(1, target_id)

# server -> client: the outcome of a First Aid attempt
@rpc("authority", "call_remote", "reliable")
func heal_result(result: Dictionary) -> void:
	heal_replied.emit(result)

# --- DIV-0014: inter-zone travel (command fast-travel between the loaded zones) ---
# client -> server: move to a loaded zone. Server updates the peer's zone (snapshot routing,
# zone-scoped chat, ambient, and the territory view all follow `_peer_zones`), persists it on
# the record (restored on next login), and replies. No adjacency/route/cost modeled yet.
@rpc("any_peer", "call_remote", "reliable")
func submit_change_zone(zone_id: String) -> void:
	if mode != Mode.SERVER or store == null or zones == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	if not zones.has_zone(zone_id):
		zone_result.rpc_id(sender, {"ok": false, "reason": "unknown_zone", "zone_id": zone_id})
		return
	if String(_peer_zones.get(sender, _default_zone)) == zone_id:
		zone_result.rpc_id(sender, {"ok": false, "reason": "already_here", "zone_id": zone_id})
		return
	# An open combat window pins you in place: leaving the zone CANCELS your queued shot so it can't
	# resolve a few ticks later and mis-credit its zone-scoped envelope (F65) + faction/territory
	# influence to the DESTINATION zone you never fought in. Mirrors the clear on disconnect/resolve.
	if arena != null:
		arena.clear_intent(sender)
		arena.clear_intents_targeting(sender)  # DIV-0019: cancel PvP shots aimed at a player who just left the zone
	_peer_zones[sender] = zone_id
	var record := _cached_load(character_id)
	if not record.is_empty():
		record["zone"] = zone_id  # persist so the next login restores this zone
		_cached_save(character_id, record)
	_feed_quest_event(sender, {"type": "travel", "zone_id": zone_id})  # DIV-0020: reach_zone objectives
	_refresh_peer_hostility(sender)  # DIV-0017: engage/disengage the destination zone's hostile immediately
	if not _visited_zones.has(character_id):
		_visited_zones[character_id] = {}
	if not (_visited_zones[character_id] as Dictionary).has(zone_id):
		(_visited_zones[character_id] as Dictionary)[zone_id] = true
		_feed_force_signal(sender, "zones_visited", 1)  # DIV-0011: reaching a new zone nudges the track
	print("[zone] peer %d traveled to %s (%s)" % [sender, zone_id, zones.effective_security(zone_id)])
	if _telemetry != null:  # Seam 5: travel telemetry (server owns the clock)
		_telemetry.log_event("travel", {
			"ts": Time.get_unix_time_from_system(), "character_id": character_id,
			"zone_id": zone_id, "security_tier": zones.effective_security(zone_id),
		})
	zone_result.rpc_id(sender, {"ok": true, "zone_id": zone_id, "display_name": zones.zone_summary(zone_id).get("display_name", zone_id)})

func send_change_zone(zone_id: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_change_zone.rpc_id(1, zone_id)

# server -> client: the outcome of a travel request
@rpc("authority", "call_remote", "reliable")
func zone_result(result: Dictionary) -> void:
	zone_replied.emit(result)

# Static {id, display_name} list of loaded zones (for the client's travel picker). Cached —
# zones are seeded once at start, so this is built at most once per server.
func _zone_list() -> Array:
	if not _zone_list_cache.is_empty() or zones == null:
		return _zone_list_cache
	for zid in zones.zones:
		_zone_list_cache.append({"id": String(zid), "name": String((zones.zone_summary(zid) as Dictionary).get("display_name", zid))})
	return _zone_list_cache

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
	if not _rate_ok(sender):
		return
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
	if not _rate_ok(sender):
		return
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

# --- E25: chat / emote (first social channel on the wire) ---
# client -> server: a chat line. Validated + normalized via the pure chat-model
# (channel whitelist + control-char strip + length clamp) using the player's display
# name as the speaker, then broadcast to every connected peer.
@rpc("any_peer", "call_remote", "reliable")
func submit_chat(channel: String, text: String) -> void:
	if mode != Mode.SERVER or state == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	# F62: only authenticated, in-world players may chat. Without this, an un-registered peer (not in
	# `state` since F57) could still inject chat under the "Spacer-N" default name — submit_chat was
	# the one any_peer RPC missing the auth gate every other gameplay RPC (input/fire/skill/equip/
	# heal/zone/claim) already enforces.
	if not state.has_player(sender):
		return
	var speaker := String(state.get_player(sender).get("name", "Spacer-%d" % sender))
	var result: Dictionary = ChatModel.normalize(channel, text, speaker)
	if not bool(result["ok"]):
		print("[chat] peer %d rejected (%s)" % [sender, String(result.get("reason", ""))])
		return
	var message: Dictionary = result["message"]
	print("[chat] %s" % ChatModel.format_line(message))
	# Delivery scope by channel: ooc = galaxy-wide; org = same-org members in ANY zone (cross-
	# zone faction coordination); say/emote = LOCAL to the speaker's current zone (standard MMO
	# proximity chat). Each iterates connected peers (incl. the sender, for the local echo).
	if channel == "ooc":
		apply_chat.rpc(message)  # global broadcast
	elif channel == "org":
		var my_org := String(_peer_orgs.get(sender, ""))
		if my_org == "":
			print("[chat] peer %d org-chat with no org — not delivered" % sender)
			return
		for pid in multiplayer.get_peers():
			if String(_peer_orgs.get(pid, "")) == my_org:
				apply_chat.rpc_id(pid, message)  # same-org members, any zone
	else:
		var speaker_zone := String(_peer_zones.get(sender, _default_zone))
		for pid in multiplayer.get_peers():
			if String(_peer_zones.get(pid, _default_zone)) == speaker_zone:
				apply_chat.rpc_id(pid, message)  # same-zone peers only

func send_chat(channel: String, text: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_chat.rpc_id(1, channel, text)

# server -> clients: a normalized chat message
@rpc("authority", "call_remote", "reliable")
func apply_chat(message: Dictionary) -> void:
	chat_received.emit(message)

# server -> client: an auth / ownership rejection (e.g. a wrong account secret)
@rpc("authority", "call_remote", "reliable")
func auth_result(result: Dictionary) -> void:
	auth_replied.emit(result)

# The persisted org membership dict for a peer (loads the record). {} when none.
# JSON reload can widen ints to float, so coerce the numeric fields the org-model
# validates with a strict typeof == TYPE_INT check (faction_rank / faction_rep).
func _org_for_peer(peer_id: int) -> Dictionary:
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return {}
	var record := _cached_load(character_id)
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

# A member's kill-in-zone earns their ORG territory influence (FACTION_TERRITORY_DESIGN
# §2), so claims become earnable through play rather than test-seeded. No-op without an org.
func _accrue_territory_influence(peer_id: int, amount: int) -> void:
	var org_id := String(_peer_orgs.get(peer_id, ""))
	if org_id == "":
		return
	var zone_id := String(_peer_zones.get(peer_id, _default_zone))
	var earned := _territory_influence_for(org_id, zone_id) + amount
	_set_territory_influence(org_id, zone_id, earned)
	print("[territory] %s +%d territory influence in %s (now %d)" % [org_id, amount, zone_id, earned])

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

# F24: a compact character-sheet summary for the client's sheet panel (species, the 6
# attributes, NON-ZERO skill bonuses, equipped weapon/armor, CP wallet, force-sensitivity).
func _sheet_summary(record: Dictionary) -> Dictionary:
	var sheet: Dictionary = record.get("sheet", {})
	var trained := {}
	for k in (sheet.get("skills", {}) as Dictionary):
		var v := String((sheet["skills"] as Dictionary)[k])
		if v != "" and v != "0D":
			trained[k] = v  # only skills above the attribute default — keep it compact
	var equipment: Dictionary = sheet.get("equipment", {})
	return {
		"species": String(record.get("species", sheet.get("species", "human"))),
		"attributes": sheet.get("attributes", {}),
		"skills": trained,
		"weapon": String(equipment.get("weapon", "")),
		"armor": String(equipment.get("armor", "")),
		"cp_wallet": sheet.get("cp_wallet", {}),
		"credits": int(sheet.get("credits", 0)),  # Wave F economy: show the wallet balance on the sheet
		"force_sensitive": bool(sheet.get("force_sensitive", false)),
	}

func _push_sheet(peer: int, record: Dictionary) -> void:
	if mode == Mode.SERVER:
		apply_sheet.rpc_id(peer, _sheet_summary(record))

# server -> client: the player's authoritative character-sheet summary (login + on change)
@rpc("authority", "call_remote", "reliable")
func apply_sheet(summary: Dictionary) -> void:
	sheet_updated.emit(summary)

# --- Wave F: WEG-anchored credit economy (DIV-0018) ---
# Merge the weapon + armor catalogs into a flat priced catalog {item_key -> {cost, vendor_stocked,
# name, kind}} that EconomyModel.buy/can_buy/sell consult (they need `cost` + `vendor_stocked`).
func _build_buy_catalog() -> void:
	_buy_catalog = {}
	for k in _weapons_catalog:
		var w: Dictionary = _weapons_catalog[k]
		_buy_catalog[String(k)] = {"cost": int(w.get("cost", 0)), "vendor_stocked": bool(w.get("vendor_stocked", false)), "name": String(w.get("name", k)), "kind": "weapon"}
	for k in _armor_catalog:
		var a: Dictionary = _armor_catalog[k]
		_buy_catalog[String(k)] = {"cost": int(a.get("cost", 0)), "vendor_stocked": bool(a.get("vendor_stocked", false)), "name": String(a.get("name", k)), "kind": "armor"}

# The Director price multiplier for a zone (trade_boom/merchant_arrival cheapen goods; via vendor_model).
func _zone_price_multiplier(zone_id: String) -> float:
	if zones == null or _vendor == null:
		return 1.0
	return _vendor.director_multiplier_for_event(String((zones.zone_summary(zone_id) as Dictionary).get("event_type", "")))

# The player's buy-discount tier from their org standing (org.faction_rep 0..100 -> standing_tier).
func _rep_tier_for(record: Dictionary) -> String:
	if _reputation == null:
		return "neutral"
	var org: Variant = record.get("org", {})
	if typeof(org) != TYPE_DICTIONARY:
		return "neutral"
	return _reputation.standing_tier(int((org as Dictionary).get("faction_rep", 0)))

# The player's Bargain skill as a {dice, pips} pair (WEG: Bargain reduces vendor price, 3%/die).
func _bargain_for(sheet: Dictionary) -> Dictionary:
	var pool: Dictionary = D6Rules.parse_pool(String((sheet.get("skills", {}) as Dictionary).get("bargain", "0D")))
	return {"dice": int(pool.get("dice", 0)), "pips": int(pool.get("pips", 0))}

# The final per-player buy price for one catalog item in the player's current zone.
func _buy_price_for(sender: int, record: Dictionary, list_cost: int) -> int:
	var sheet: Dictionary = record.get("sheet", {})
	var bargain := _bargain_for(sheet)
	var zone_id := String(_peer_zones.get(sender, _default_zone))
	return EconomyModel.buy_price(list_cost, _zone_price_multiplier(zone_id), int(bargain["dice"]), int(bargain["pips"]), _rep_tier_for(record), _vendor)

# Credit the player's persisted wallet by `amount` (may be negative; floored at 0) and push the new
# balance + sheet. The single credit mutation point — loot (S13), buy/sell, and future sinks route here.
func _award_credits(peer_id: int, amount: int) -> void:
	if store == null or amount == 0:
		return
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var credits := maxi(int(sheet.get("credits", 0)) + amount, 0)
	sheet["credits"] = credits
	record["sheet"] = sheet
	_cached_save(character_id, record)
	if mode == Mode.SERVER:
		apply_credits.rpc_id(peer_id, credits)
		_push_sheet(peer_id, record)
	print("[credits] peer %d %+d -> %d" % [peer_id, amount, credits])
	if amount > 0:
		_feed_quest_event(peer_id, {"type": "credits", "amount": amount})  # DIV-0020: earn_credits objectives

# server -> client: the player's authoritative credit balance
@rpc("authority", "call_remote", "reliable")
func apply_credits(credits: int) -> void:
	last_credits = credits
	credits_updated.emit(credits)

# DIV-0023 (Seam 1, Option A): field-dress a just-disabled harvestable creature into a sellable good and
# pay its sale value as INSTANT CREDITS (mirrors the salvage_credits path in _award_credits). This is IN
# ADDITION to loot credits — the good is a SEPARATE reward — and it fires ONCE per creature because the
# ONLY caller is inside the `not looted.has(tkey)` dedup block (one credited shooter per kill). Most
# creatures carry no harvest block, so has_harvest short-circuits cheaply and the hot loot path stays cheap.
#
# OPTION A = instant credits (the owner-recommended default). OPTION B (the DEFERRED upgrade + the OPEN
# OWNER DECISION in docs/design/LATENT_MODEL_WIRING_PLAN.md §Seam 1) grants a CARRYABLE inventory resource
# good the vendor buys back — object-permanence for crafting / quest turn-ins and the living-world scarcity
# index. When Option B ships, this is where result.good would append to sheet.inventory instead of (or
# alongside) the credit grant. Server owns the RNG (a fresh _server_rng.randi() seed, independent of loot).
func _maybe_harvest(shooter: int, spawn: Dictionary, tkey: String) -> void:
	if not HarvestModel.has_harvest(spawn, _creatures_data):
		return  # ~15 of the creatures carry a harvest block; the rest no-op here
	var dress_pool = _field_dress_pool(shooter)  # survival pool ("xD+y" dict) or null = untrained 0D
	var harvest: Dictionary = HarvestModel.roll_harvest(D6Rules, spawn, _creatures_data, dress_pool, _server_rng.randi())
	var good := String(harvest.get("good", ""))
	var qty := int(harvest.get("quantity", 0))
	# quantity > 0 (not `success`) so a PARTIAL recovery still pays its reduced yield; a gated failure
	# (e.g. an untrained field-dresser vs the krayt difficulty 15) yields quantity 0 -> no credit.
	if not bool(harvest.get("harvestable", false)) or qty <= 0:
		print("[harvest] peer %d field-dressed %s: nothing recovered (%s)" % [
			shooter, String(spawn.get("name", tkey)), String(harvest.get("tier", ""))])
		return
	var resource := String(harvest.get("resource", ""))
	var value := _harvest_value_per_unit(good, resource) * qty
	if value > 0:
		_award_credits(shooter, value)  # same single credit-mutation point loot/buy/sell route through
		if mode == Mode.SERVER:
			harvest_notice.rpc_id(shooter, {
				"good": good, "resource": resource, "quantity": qty,
				"credits": value, "tier": String(harvest.get("tier", "")),
			})
		# feed a future harvest objective (no-op today: no quest def has a "harvest" objective, so
		# record_event returns unchanged and _feed_quest_event writes nothing — safe forward hook).
		_feed_quest_event(shooter, {"type": "harvest", "good": good, "resource": resource, "quantity": qty})
	print("[harvest] peer %d field-dressed %s: %d x %s (%s, %s) -> %d credits" % [
		shooter, String(spawn.get("name", tkey)), qty, good, resource, String(harvest.get("tier", "")), value])

# The shooter's WEG field-dressing pool for harvest_model.roll_harvest: the survival skill parsed to a
# {dice,pips} dict, or `null` (untrained -> 0D, which the model coerces). Mirrors _bargain_for, but
# resolves the sheet from the peer since the loot hook holds only the shooter id, not the record.
func _field_dress_pool(peer_id: int):
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return null
	var record := _cached_load(character_id)
	if record.is_empty():
		return null
	var skills: Dictionary = (record.get("sheet", {}) as Dictionary).get("skills", {})
	if not skills.has(HarvestModel.FIELD_DRESS_SKILL):
		return null  # untrained -> the model treats null as 0D
	return D6Rules.parse_pool(String(skills.get(HarvestModel.FIELD_DRESS_SKILL, "0D")))

# DIV-0023 Option A: the per-unit credit value of a harvested good. A per-good override wins; else the
# resource bucket; else the table default. TUNABLE CONTENT within DIV-0018 (kept in the same order as
# creature loot) — NOT a WEG-fixed number and NOT an owner fork. harvest_wire_smoke mirrors this lookup.
func _harvest_value_per_unit(good: String, resource: String) -> int:
	var by_good: Dictionary = _harvest_values.get("by_good", {})
	if by_good.has(good):
		return maxi(int(by_good[good]), 0)
	var by_resource: Dictionary = _harvest_values.get("by_resource", {})
	if by_resource.has(resource):
		return maxi(int(by_resource[resource]), 0)
	return maxi(int(_harvest_values.get("default", 0)), 0)

# server -> client: you field-dressed a creature into a sellable good (DIV-0023 toast/log)
@rpc("authority", "call_remote", "reliable")
func harvest_notice(notice: Dictionary) -> void:
	harvested.emit(notice)

# The set of item keys a vendor sells in a zone (data/vendor_stock_by_zone.json). Empty = the full
# stocked catalog (fallback for any zone without a curated list), so the economy still works everywhere.
func _zone_stock_keys(zone_id: String) -> Dictionary:
	var out := {}
	var z: Dictionary = _vendor_stock_by_zone.get(zone_id, {})
	for k in z.get("item_keys", []):
		out[String(k)] = true
	return out

# client -> server: request the vendor's server-priced stock (buy + 40% sell prices).
@rpc("any_peer", "call_remote", "reliable")
func submit_vendor_list() -> void:
	if mode != Mode.SERVER or store == null or _vendor == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var zone_id := String(_peer_zones.get(sender, _default_zone))
	var mult := _zone_price_multiplier(zone_id)
	var rep_tier := _rep_tier_for(record)
	var bargain := _bargain_for(sheet)
	var allowed := _zone_stock_keys(zone_id)  # per-zone variety; empty = full stocked catalog
	var stock: Array = []
	for item in _vendor.list_stock({"weapons": _weapons_catalog}, {"armor": _armor_catalog}):
		var key := String((item as Dictionary)["key"])
		if not allowed.is_empty() and not allowed.has(key):
			continue  # this zone's vendor doesn't carry it
		var list_cost := int((item as Dictionary).get("base_cost", 0))
		stock.append({
			"key": key,
			"kind": String((item as Dictionary)["kind"]),
			"name": String((item as Dictionary)["name"]),
			"buy": EconomyModel.buy_price(list_cost, mult, int(bargain["dice"]), int(bargain["pips"]), rep_tier, _vendor),
			"sell": EconomyModel.sell_price(list_cost),
		})
	print("[vendor] peer %d listed %d items (zone %s mult %.2f rep %s)" % [sender, stock.size(), zone_id, mult, rep_tier])
	vendor_result.rpc_id(sender, {"stock": stock, "credits": int(sheet.get("credits", 0)), "rep_tier": rep_tier, "price_mult": mult})

# server -> client: the priced vendor stock
@rpc("authority", "call_remote", "reliable")
func vendor_result(payload: Dictionary) -> void:
	vendor_listed.emit(payload)

# client -> server: buy an item (the primary credit SINK). Server prices it, debits credits, and
# appends it to the character's inventory (EconomyModel.buy validates stock + affordability).
@rpc("any_peer", "call_remote", "reliable")
func submit_buy(item_key: String) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var key := item_key.strip_edges()
	if not _buy_catalog.has(key):
		buy_result.rpc_id(sender, {"ok": false, "item_key": key, "reason": "unknown_item"})
		return
	var sheet: Dictionary = record.get("sheet", {})
	var price := _buy_price_for(sender, record, int((_buy_catalog[key] as Dictionary).get("cost", 0)))
	var result: Dictionary = EconomyModel.buy(sheet, key, price, _buy_catalog)
	if bool(result.get("ok", false)):
		var new_sheet: Dictionary = result["sheet"]
		record["sheet"] = new_sheet
		_cached_save(character_id, record)
		apply_credits.rpc_id(sender, int(new_sheet.get("credits", 0)))
		_push_sheet(sender, record)
		print("[buy] peer %d bought %s for %d (credits now %d)" % [sender, key, price, int(new_sheet.get("credits", 0))])
		if _telemetry != null:  # Seam 5: buy telemetry (economy flow)
			_telemetry.log_event("buy", {
				"ts": Time.get_unix_time_from_system(), "character_id": character_id,
				"item_key": key, "price": price, "credits": int(new_sheet.get("credits", 0)),
			})
		buy_result.rpc_id(sender, {"ok": true, "item_key": key, "price": price, "credits": int(new_sheet.get("credits", 0))})
	else:
		print("[buy] peer %d buy %s rejected (%s, price %d)" % [sender, key, String(result.get("reason", "")), price])
		buy_result.rpc_id(sender, {"ok": false, "item_key": key, "reason": String(result.get("reason", "")), "price": price})

# client -> server: sell an OWNED, unequipped item back to a vendor at 40% of list (the churn spread).
@rpc("any_peer", "call_remote", "reliable")
func submit_sell(item_key: String) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var key := item_key.strip_edges()
	if not _buy_catalog.has(key):
		sell_result.rpc_id(sender, {"ok": false, "item_key": key, "reason": "unknown_item"})
		return
	var sheet: Dictionary = record.get("sheet", {})
	var price := EconomyModel.sell_price(int((_buy_catalog[key] as Dictionary).get("cost", 0)))
	var result: Dictionary = EconomyModel.sell(sheet, key, price)
	if bool(result.get("ok", false)):
		var new_sheet: Dictionary = result["sheet"]
		record["sheet"] = new_sheet
		_cached_save(character_id, record)
		apply_credits.rpc_id(sender, int(new_sheet.get("credits", 0)))
		_push_sheet(sender, record)
		print("[sell] peer %d sold %s for %d (credits now %d)" % [sender, key, price, int(new_sheet.get("credits", 0))])
		if _telemetry != null:  # Seam 5: sell telemetry (economy flow)
			_telemetry.log_event("sell", {
				"ts": Time.get_unix_time_from_system(), "character_id": character_id,
				"item_key": key, "price": price, "credits": int(new_sheet.get("credits", 0)),
			})
		sell_result.rpc_id(sender, {"ok": true, "item_key": key, "price": price, "credits": int(new_sheet.get("credits", 0))})
	else:
		print("[sell] peer %d sell %s rejected (%s)" % [sender, key, String(result.get("reason", ""))])
		sell_result.rpc_id(sender, {"ok": false, "item_key": key, "reason": String(result.get("reason", ""))})

# server -> client: the outcome of a buy / sell
@rpc("authority", "call_remote", "reliable")
func buy_result(result: Dictionary) -> void:
	buy_replied.emit(result)

@rpc("authority", "call_remote", "reliable")
func sell_result(result: Dictionary) -> void:
	sell_replied.emit(result)

func send_vendor_list() -> void:
	if mode == Mode.CLIENT and connected:
		submit_vendor_list.rpc_id(1)

func send_buy(item_key: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_buy.rpc_id(1, item_key)

func send_sell(item_key: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_sell.rpc_id(1, item_key)

func send_repair_armor(item_key: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_repair_armor.rpc_id(1, item_key)

# client -> server: repair the EQUIPPED armor's broken condition back to full quality at a vendor — a
# pure credit SINK (DIV-0026, Seam 4b), same interaction class as buy/sell. Combat DRIVES the armor's
# quality pips DOWN toward the -6 condition floor ("broken" -> soak HALVED by Seam 4a); this restores
# them to PRISTINE (0 = NEW_QUALITY_PIPS, the real repair ceiling — combat only degrades DOWN from 0, so
# repairing to the +6 clamp bound would mint super-armor) for a fee priced off the SAME economy buy-back
# (ArmorRepairModel.repair_cost -> EconomyModel.sell_price), so dump-and-rebuy never dominates repair.
# The live pip lives in the arena combat state (the SOURCE Seam 4a's soak build reads); the restored pip
# is written back THERE via set_player_combat. Like armor degradation itself, the pip axis is
# session-scoped (not persisted onto the sheet today) — cross-relog durability would need a sheet field
# + a schema/DIV note and is intentionally OUT OF SCOPE here. Server owns all credits (_award_credits).
@rpc("any_peer", "call_remote", "reliable")
func submit_repair_armor(item_key: String) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var key := item_key.strip_edges()
	if not _buy_catalog.has(key):
		repair_result.rpc_id(sender, {"ok": false, "item_key": key, "reason": "unknown_item"})
		return
	var sheet: Dictionary = record.get("sheet", {})
	# v1 repairs the EQUIPPED armor only — that is the one item whose live quality pips exist (in the
	# arena combat state). A request for anything else has no pip axis to restore, so reject cleanly.
	var equipped_armor := String((sheet.get("equipment", {}) as Dictionary).get("armor", ""))
	if key == "" or key != equipped_armor:
		repair_result.rpc_id(sender, {"ok": false, "item_key": key, "reason": "not_equipped"})
		return
	var list_cost := int((_buy_catalog[key] as Dictionary).get("cost", 0))
	if list_cost <= 0:
		# unpriced gear (contraband / faction-issued) -> the model returns cost 0; reject like buy/sell.
		repair_result.rpc_id(sender, {"ok": false, "item_key": key, "reason": "unpriced"})
		return
	var current_pips := _equipped_armor_pips(sender)
	# v1 = full rebuild to PRISTINE (0), the real repair ceiling — NOT MAX_QUALITY_PIPS (+6). Combat only
	# ever degrades pips DOWN from 0, so a +6 target would grant +2D super-armor above undamaged AND charge
	# for pristine gear (the model now clamps to NEW_QUALITY_PIPS, but keep the intent explicit here).
	var target := int(ArmorRepairModel.NEW_QUALITY_PIPS)
	var cost := ArmorRepairModel.repair_cost(current_pips, target, list_cost)
	var credits := int(sheet.get("credits", 0))
	if cost <= 0:
		# already at the ceiling (nothing to restore) -> a no-op reply, never a charge.
		repair_result.rpc_id(sender, {"ok": true, "item_key": key, "cost": 0, "credits": credits, "quality_pips": current_pips, "reason": "no_op"})
		return
	if credits < cost:
		repair_result.rpc_id(sender, {"ok": false, "item_key": key, "reason": "cannot_afford", "cost": cost, "credits": credits})
		return
	var restored := ArmorRepairModel.restore(current_pips, target)
	_award_credits(sender, -cost)                    # the single credit-mutation point buy/sell/loot share (floored >= 0)
	_set_equipped_armor_pips(sender, restored)       # write the restored pip where Seam 4a's soak build reads it
	var new_credits := int((_cached_load(character_id).get("sheet", {}) as Dictionary).get("credits", 0))
	print("[repair] peer %d repaired %s %+d->%+d for %d (credits now %d)" % [sender, key, current_pips, restored, cost, new_credits])
	if _telemetry != null:   # Seam 5: repair telemetry (economy sink flow)
		_telemetry.log_event("repair", {
			"ts": Time.get_unix_time_from_system(), "character_id": character_id,
			"item_key": key, "cost": cost, "credits": new_credits,
			"quality_pips_before": current_pips, "quality_pips_after": restored,
		})
	repair_result.rpc_id(sender, {"ok": true, "item_key": key, "cost": cost, "credits": new_credits, "quality_pips": restored})

# server -> client: the outcome of an armor repair (mirrors buy_result / sell_result)
@rpc("authority", "call_remote", "reliable")
func repair_result(result: Dictionary) -> void:
	repair_replied.emit(result)

# The equipped armor's LIVE quality pips (session-scoped; held in the arena combat state Seam 4a reads).
# Undamaged / no live combat state -> 0 (full quality), which repair_cost treats as a no-op (nothing to fix).
func _equipped_armor_pips(peer_id: int) -> int:
	if arena == null or not arena.has_player(peer_id):
		return 0
	return int(arena.player_state(peer_id).get("player_armor_quality_pips", 0))

# Write the repaired pip back to the arena combat state — the SAME field the soak build (Seam 4a) reads,
# so a repaired armor actually un-halves soak in the next exchange. set_player_combat merges only the
# provided key, leaving wound/CP/FP untouched.
func _set_equipped_armor_pips(peer_id: int, pips: int) -> void:
	if arena == null or not arena.has_player(peer_id):
		return
	arena.set_player_combat(peer_id, {"player_armor_quality_pips": pips})

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
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var wallet: Dictionary = Progression.award(sheet.get("cp_wallet", Progression.new_wallet()), track, amount)
	sheet["cp_wallet"] = wallet
	record["sheet"] = sheet
	_cached_save(character_id, record)
	print("[cp] peer %d +%d %s (wallet g=%d r=%d)" % [peer_id, amount, track, int(wallet.get("gameplay_cp", 0)), int(wallet.get("rp_cp", 0))])
	apply_wallet.rpc_id(peer_id, wallet)
	_push_sheet(peer_id, record)  # F30: keep the character sheet panel's CP wallet current after a CP award

# --- DIV-0020: quests (accept / progress / claim) -----------------------------------------------
# record["quests"] (quest_id -> {progress, complete, claimed}) is the live state; QuestModel is the
# pure, non-mutating authority. Progress is fed from live play (hostile disables, zone travel, credit
# gains). Every mutator uses QuestModel's RETURN value (the model duplicates, never aliases the arg).

# The player's quest block, backfilling a legacy record that predates quests so returning players get it.
func _record_quests(record: Dictionary) -> Dictionary:
	var q: Variant = record.get("quests", null)
	return q if typeof(q) == TYPE_DICTIONARY else QuestModel.initial_quests()

# Feed one play EVENT into a peer's accepted quests; persist + push only if something actually changed.
func _feed_quest_event(peer_id: int, event: Dictionary) -> void:
	if store == null or _quest_defs.is_empty():
		return
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var before: Dictionary = _record_quests(record)
	var after: Dictionary = QuestModel.record_event(before, _quest_defs, event)
	if after == before:
		return  # nothing accepted cares about this event — no write, no push
	record["quests"] = after
	_cached_save(character_id, record)
	if mode == Mode.SERVER:
		apply_quests.rpc_id(peer_id, after)

# Send the quest catalog (notice board) + this player's live progress on login/register.
func _push_quests(peer_id: int, record: Dictionary) -> void:
	if mode != Mode.SERVER:
		return
	apply_quest_catalog.rpc_id(peer_id, _quest_defs)
	apply_quests.rpc_id(peer_id, _record_quests(record))

# client -> server: accept a quest from the notice board (idempotent — keeps existing progress).
@rpc("any_peer", "call_remote", "reliable")
func submit_accept_quest(quest_id: String) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	if not _quest_defs.has(quest_id):
		return  # unknown quest id — ignore
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var after: Dictionary = QuestModel.accept(_record_quests(record), quest_id)
	record["quests"] = after
	_cached_save(character_id, record)
	print("[quest] peer %d accepted %s" % [sender, quest_id])
	apply_quests.rpc_id(sender, after)

# client -> server: claim a COMPLETED quest's one-time reward (credits + CP).
@rpc("any_peer", "call_remote", "reliable")
func submit_claim_quest(quest_id: String) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var result: Dictionary = QuestModel.claim(_record_quests(record), _quest_defs, quest_id)
	if not bool(result.get("ok", false)):
		return  # not complete / already claimed / unknown — no-op (no double reward)
	# Persist the CLAIM first, THEN award — each award does its own load/save on the persisted record,
	# so nothing clobbers a stale copy (the claimed quest is already `claimed`, so a credit-reward feed
	# skips it and only advances OTHER accepted earn_credits quests).
	record["quests"] = result.get("quests", {})
	_cached_save(character_id, record)
	var reward: Dictionary = result.get("reward", {})
	var cp := int(reward.get("cp", 0))
	var credits := int(reward.get("credits", 0))
	if cp > 0:
		_award_cp(sender, "gameplay", cp)   # quest reward -> gameplay CP track
	if credits > 0:
		_award_credits(sender, credits)     # quest reward -> wallet (may advance earn_credits quests)
	print("[quest] peer %d claimed %s (+%d cr, +%d cp)" % [sender, quest_id, credits, cp])
	# Push the FINAL state (reload — the credit reward's feed may have advanced other quests).
	apply_quests.rpc_id(sender, _record_quests(_cached_load(character_id)))

# server -> client: the full quest catalog (notice-board content: id/name/description/objective/reward/giver).
@rpc("authority", "call_remote", "reliable")
func apply_quest_catalog(defs: Dictionary) -> void:
	quest_catalog = defs
	quest_catalog_received.emit(defs)

# server -> client: this client's authoritative quest progress (login + on change).
@rpc("authority", "call_remote", "reliable")
func apply_quests(quests: Dictionary) -> void:
	last_quests = quests
	quests_updated.emit(quests)

# client -> server senders
func send_accept_quest(quest_id: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_accept_quest.rpc_id(1, quest_id)

func send_claim_quest(quest_id: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_claim_quest.rpc_id(1, quest_id)

# E24: accrue Director zone-influence from a player action onto the player's faction
# axis in their current zone. Buffered in _pending_zone_influence (the E8 model) and
# folded into the live zone at the next Director tick. No-op when the player has no axis.
func _accrue_zone_influence(peer_id: int, delta: int) -> void:
	if zones == null:
		return
	var axis := String(_peer_axes.get(peer_id, ""))
	if axis == "":
		return
	var zone_id := String(_peer_zones.get(peer_id, _default_zone))
	_pending_zone_influence = _pending_model.add_pending(_pending_zone_influence, zone_id, axis, delta)

# E24: fold the accrued per-zone influence into the live zones (clamped 0-100) and clear
# it. Called just before the Director tick so player activity shifts faction influence,
# which then decays / re-derives normally. Logs the resulting posture.
func _fold_pending_influence() -> void:
	if zones == null or _pending_zone_influence.is_empty():
		return
	var zone_ids := {}
	for entry in _pending_zone_influence:
		zone_ids[String((entry as Dictionary).get("zone_id", ""))] = true
	for zid in zone_ids.keys():
		var folded: Dictionary = _pending_model.fold_and_clear(_pending_zone_influence, String(zid))
		_pending_zone_influence = folded["remaining"]
		var deltas: Dictionary = folded["deltas"]
		if deltas.is_empty() or not zones.has_zone(String(zid)):
			continue
		for axis in deltas:
			zones.apply_influence_delta(String(zid), String(axis), int(deltas[axis]))
		var z: Dictionary = zones.get_zone(String(zid))
		print("[influence] zone %s +%s -> influence %s, alert %s, security %s" % [
			String(zid), str(deltas), str(z.get("influence", {})),
			String(z.get("alert_level", "")), zones.effective_security(String(zid))])

# F58: persist/restore the server-global world record (faction-influence zone state + the
# uncommitted pending influence). Previously the entire player-driven territory reset to its seed on
# every reboot; now it survives a restart. Saved each Director tick; loaded once on boot after the
# roster is seeded. (Org territory CLAIMS in the separate Territory model are a follow-up slice.)
func _save_world_state() -> void:
	if store == null or zones == null:
		return
	var world := zones.to_dict()
	world["pending_zone_influence"] = _pending_zone_influence
	world["territory_influence"] = _territory_influence  # F61: org influence that GATES claim eligibility
	if territory != null:
		world["territory"] = territory.to_dict()  # F59: org claims + treasuries
	store.save_world(world)

func _load_world_state() -> void:
	if store == null or zones == null:
		return
	var world := store.load_world()
	if world.is_empty():
		return
	zones.apply_persisted(world)
	_pending_zone_influence = world.get("pending_zone_influence", [])
	# F61: restore the org territory-influence that gates claim eligibility (it earned the claims F59
	# restores; without this it reset on every reboot). JSON parses numbers as float -> re-int the
	# nested {org -> {zone -> int}} so the typed claim_node(org_influence:int) path stays clean.
	var saved_ti: Dictionary = world.get("territory_influence", {})
	_territory_influence = {}
	for org_id in saved_ti:
		var zmap: Dictionary = saved_ti[org_id]
		var out := {}
		for zone_id in zmap:
			out[zone_id] = int(zmap[zone_id])
		_territory_influence[org_id] = out
	if territory != null:
		territory.apply_persisted(world.get("territory", {}))  # F59: restore org claims + treasuries
	print("[persist] world state restored (tick_index=%d, pending=%d, claims=%d, ti_orgs=%d)" % [
		zones.tick_index, _pending_zone_influence.size(),
		territory.claim_count() if territory != null else 0, _territory_influence.size()])

# E27: advance each zone's ambient NPC roster (Director-paced, deterministic, hash-seeded
# like zone_state). Folded into the per-peer snapshot as npcs[].
func _advance_ambient() -> void:
	if zones == null:
		return
	var counts := {}
	for zone_id in zones.zones:
		var alert := String((zones.get_zone(zone_id) as Dictionary).get("alert_level", "standard"))
		_ambient[zone_id] = AmbientSim.advance(_ambient.get(zone_id, []), String(zone_id), alert, zones.tick_index, {})
		counts[zone_id] = (_ambient[zone_id] as Array).size()
	print("[ambient] tick %d npc counts %s" % [zones.tick_index, str(counts)])

# --- DIV-0017: hostile-creature PvE (the shared lethal source) ---
# Once per Director tick: keep each LETHAL (lawless/contested) zone that has players in it stocked
# with one active hostile creature target, and despawn hostiles from zones that have calmed to safe.
# Then re-point every player at their zone's hostile (lethal) or back at the shared training dummy.
func _advance_hostiles() -> void:
	if zones == null or arena == null or _creature_spawn == null:
		return
	for zone_id in zones.zones:
		var tier := zones.effective_security(zone_id)
		if not HostileNpc.is_lethal_zone(tier):
			if arena.has_hostile_target(zone_id):
				arena.remove_hostile_target(zone_id)  # zone calmed -> despawn any lingering hostile
			continue
		if not arena.has_hostile_target(zone_id) and _players_in_zone(zone_id) > 0:
			var alert := String((zones.get_zone(zone_id) as Dictionary).get("alert_level", "standard"))
			var spawn: Dictionary = _forced_spawn() if force_hostile_key != "" else _creature_spawn.roll_spawn(_creatures_data, alert, tier, _server_rng.randi())
			if spawn.is_empty() or not bool(spawn.get("hostile", false)):
				continue  # only HOSTILE creatures become lethal targets (retry next tick)
			var pools: Dictionary = HostileNpc.attack_pools_from_creature(D6Rules, spawn)
			# DIV-0024: bake this creature's venom/restraint rider with a SERVER-owned seed (the poison
			# schedule is pre-rolled deterministically here; the arena seeds it onto a victim on a landed hit).
			var rider: Dictionary = CreatureSpecialAttack.describe_spawn(_creatures_data, spawn, D6Rules, _server_rng.randi())
			arena.register_hostile_target(zone_id, pools, {"distance": HOSTILE_DISTANCE, "cover_level": 0, "name": String(spawn.get("name", "Creature"))}, spawn, rider)
			print("[hostile] %s spawned in %s (%s, pack %d)" % [String(spawn.get("name", "")), zone_id, tier, int(spawn.get("pack_size", 1))])
	_refresh_all_hostility()

# TEST-ONLY (--force-hostile): build a single-head spawn of a specific creature key, bypassing the
# seeded random pick, so a two-process death check is deterministic. Empty when the key is unknown.
func _forced_spawn() -> Dictionary:
	var c: Dictionary = (_creatures_data.get("creatures", {}) as Dictionary).get(force_hostile_key, {})
	if c.is_empty():
		return {}
	return {
		"creature_key": force_hostile_key, "name": String(c.get("name", force_hostile_key)),
		"scale": String(c.get("scale", "creature")), "hostile": bool(c.get("hostile", true)), "pack_size": 1,
		"char_sheet": c.get("char_sheet", {}), "natural_attack": c.get("natural_attack", {}),
	}

func _players_in_zone(zone_id: String) -> int:
	var n := 0
	for pid in _peer_zones:
		if String(_peer_zones[pid]) == zone_id:
			n += 1
	return n

func _refresh_all_hostility() -> void:
	for peer_id in _peer_characters.keys():
		_refresh_peer_hostility(int(peer_id))

# Point ONE player at their current zone's hostile creature (lethal) if there is one, else back at
# the shared training dummy (non-lethal). Called on travel + each hostile tick so engagement follows
# the player's zone. The lethal flag is what lifts the DIV-0016 sparring clamp (S6).
func _refresh_peer_hostility(peer_id: int) -> void:
	if arena == null or not arena.has_player(peer_id):
		return
	var zone_id := String(_peer_zones.get(peer_id, _default_zone))
	var lethal_here := zones != null and HostileNpc.is_lethal_zone(zones.effective_security(zone_id))
	if lethal_here and arena.has_hostile_target(zone_id):
		arena.set_player_target(peer_id, zone_id)
		arena.set_player_lethal(peer_id, true)
	elif zone_id == _default_zone and not lethal_here:
		# G13/G10: the shared training dummy is the SPAWN/spaceport (secured) practice aid — the auto-
		# fallback ONLY here. Fire on it is capped-CP sparring, no economy faucet (see _resolve_combat_window).
		arena.set_player_target(peer_id, "")   # "" = the shared training dummy
		arena.set_player_lethal(peer_id, false)
	else:
		# G13/G10: any OTHER zone with no live hostile -> HOLD FIRE (no target, no dummy fallback). A lawless
		# zone between hostile spawns is empty: autofire connects with nothing until the Director spawns one,
		# so a cross-zone autofire bot can no longer farm the spaceport dummy (Fable: 20 hits in 45s).
		arena.set_player_target(peer_id, CombatArena.HOLD_TARGET)
		arena.set_player_lethal(peer_id, false)

# G4 (DIV-0017): UNPROVOKED hostile aggression. Runs every COMBAT WINDOW: each ENGAGED, still-alive
# hostile in a LETHAL (lawless/contested) zone fires at the same-zone players who did NOT declare a shot
# this window (fired_ids — captured before resolve_window cleared intents). Routes through the arena's
# resolve_hostile_aggression (which uses the smoked ground_combat_model.resolve_incoming_fire_window),
# so a player who never presses fire is STILL in danger in a lawless zone (restores the death loop /
# insurance sink / zone fantasy). SECURED (and any non-lethal) zones NEVER reach the fire step — the
# is_lethal_zone gate skips them, and _advance_hostiles never spawns a hostile there anyway. No player is
# double-hit: a shooter already took their return-fire exchange in resolve_window and is excluded here.
# Casualties route through the SAME DIV-0027 tiering as provoked combat (sev 5 -> _handle_player_death;
# sev 3-4 -> _handle_player_downed) — no parallel death path. killer 0 = a creature (no player credit).
func _tick_hostile_aggression(fired_ids: Array) -> void:
	if arena == null or zones == null:
		return
	var fired := {}
	for pid in fired_ids:
		fired[int(pid)] = true
	var takedowns := {}  # victim_peer -> {killer:0, name, severity} (dedup, keep MAX severity)
	for zone_id in zones.zones:
		if not HostileNpc.is_lethal_zone(zones.effective_security(zone_id)):
			continue  # DIV-0017: secured / any non-lethal tier gets NO unprovoked fire (safe zones stay safe)
		if not arena.has_hostile_target(zone_id) or arena.hostile_target_disabled(zone_id):
			continue  # only an engaged, still-alive hostile initiates
		# Idle victims: same-zone, in the arena, did NOT fire this window, and not already out.
		var victims: Array = []
		for pid in _peer_zones:
			var peer := int(pid)
			if String(_peer_zones[pid]) != zone_id or fired.has(peer) or not arena.has_player(peer):
				continue
			if int((arena.player_state(peer) as Dictionary).get("player_wound_severity", 0)) >= CombatArena.DISABLED_SEVERITY:
				continue
			victims.append(peer)
		if victims.is_empty():
			continue
		var result: Dictionary = arena.resolve_hostile_aggression(zone_id, victims, _server_rng.randi())
		# Broadcast the incoming-fire envelopes to same-zone peers (scoped like provoked combat, F65).
		for envelope in result.get("envelopes", []):
			var ez := String(_peer_zones.get(int((envelope as Dictionary).get("shooter_id", 0)), _default_zone))
			for pid2 in multiplayer.get_peers():
				if String(_peer_zones.get(pid2, _default_zone)) == ez:
					apply_combat_envelope.rpc_id(pid2, envelope)
		var hname := String((arena.hostile_target_state(zone_id) as Dictionary).get("name", "a hostile"))
		for c in result.get("casualties", []):
			var vic := int((c as Dictionary).get("peer", 0))
			var csev := int((c as Dictionary).get("severity", CombatArena.DISABLED_SEVERITY))
			if not takedowns.has(vic) or csev > int((takedowns[vic] as Dictionary).get("severity", 0)):
				takedowns[vic] = {"killer": 0, "name": hname, "severity": csev}
	# DIV-0027: TIER each unprovoked takeout exactly once — identical routing to _resolve_combat_window.
	for victim in takedowns:
		if state != null and state.has_player(int(victim)):
			var td: Dictionary = takedowns[victim]
			var s := int(td.get("severity", CombatArena.DISABLED_SEVERITY))
			if PvpRules.is_kill(s):
				_handle_player_death(int(victim), String(td["name"]), 0, not _downed.has(int(victim)))
			else:
				_handle_player_downed(int(victim), 0, s, String(td["name"]))

# DIV-0024: advance every player's active venom/restraint status ONE combat window. Runs once per window
# (after the provoked + unprovoked fire passes have seeded new status). Broadcasts each status envelope to
# same-zone peers (scoped like combat, F65) and routes casualties through the SAME DIV-0027 downed/death
# tiering as _resolve_combat_window / _tick_hostile_aggression — a venom/hold-crush kill tiers identically
# (killer 0 = a creature, no player credit). Server owns the seed (_server_rng); nothing here is random.
func _tick_status_effects() -> void:
	if arena == null:
		return
	var result: Dictionary = arena.tick_status_effects(_server_rng.randi())
	for envelope in result.get("envelopes", []):
		var ez := String(_peer_zones.get(int((envelope as Dictionary).get("shooter_id", 0)), _default_zone))
		for pid in multiplayer.get_peers():
			if String(_peer_zones.get(pid, _default_zone)) == ez:
				apply_combat_envelope.rpc_id(pid, envelope)
	var takedowns := {}  # victim_peer -> {killer:0, name, severity} (dedup, keep MAX severity)
	for c in result.get("casualties", []):
		var vic := int((c as Dictionary).get("peer", 0))
		var csev := int((c as Dictionary).get("severity", CombatArena.DISABLED_SEVERITY))
		if not takedowns.has(vic) or csev > int((takedowns[vic] as Dictionary).get("severity", 0)):
			takedowns[vic] = {"killer": 0, "name": "a creature's venom", "severity": csev}
	for victim in takedowns:
		if state != null and state.has_player(int(victim)):
			var td: Dictionary = takedowns[victim]
			var s := int(td.get("severity", CombatArena.DISABLED_SEVERITY))
			if PvpRules.is_kill(s):
				_handle_player_death(int(victim), String(td["name"]), 0, not _downed.has(int(victim)))
			else:
				_handle_player_downed(int(victim), 0, s, String(td["name"]))

# DIV-0006: the death consequence. A player taken OUT (live wound >= DISABLED_SEVERITY) by a LETHAL
# hostile is killed: apply the death penalty (durability loss + partial inventory drop + insurance),
# write the corpse manifest, relocate to the secured spaceport med bay, respawn 'wounded' (credits
# KEPT), and disengage from the hostile. v1 fires on incapacitation (a lone character taken out by a
# hostile in a lawless/contested zone is killed) rather than modeling the mortally-wounded death-roll
# grace; the survivable incapacitated/mortally band remains the non-lethal medical loop's domain.
func _handle_player_death(peer_id: int, killer_name: String, killer_peer: int = 0, credit_killer: bool = true) -> void:
	if store == null:
		return
	# DIV-0027: the single choke point where the downed set is cleared — a sev-5 finish, a bleed-out, or
	# a yield all pass through here, so no orphan _downed entry keeps ticking after a death (idempotent).
	_downed.erase(peer_id)
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var zone_id := String(_peer_zones.get(peer_id, _default_zone))
	var tier := zones.effective_security(zone_id) if zones != null else "lawless"
	var outcome: Dictionary = DeathPenalty.apply_death(sheet, tier)
	var new_sheet: Dictionary = outcome["sheet"]  # wound_state=wounded, durability loss, drops removed, insurance consumed
	var dropped: Array = outcome["dropped"]
	# Corpse manifest -> record.world_hooks.corpse. In LAWLESS the corpse is FULL-LOOT (DIV-0019/DIV-0025):
	# submit_loot_corpse lets a third party take the dropped set within the DIV-0006 decay window. The SERVER
	# owns the clock — stamp decay_unix now (wall-clock, so the body keeps aging across a restart) and index
	# the corpse in _corpses so the loot RPC + the despawn tick can find it without scanning every record.
	var world_hooks: Dictionary = record.get("world_hooks", {})
	if not dropped.is_empty():
		var dpos: Vector3 = state.get_player(peer_id).get("pos", WorldState.SPAWN_POINT) if state != null else WorldState.SPAWN_POINT
		var decay_unix := Time.get_unix_time_from_system()
		var pos_dict := {"x": dpos.x, "y": dpos.y, "z": dpos.z}
		world_hooks["corpse"] = {"zone_id": zone_id, "pos": pos_dict, "items": dropped, "decay_unix": decay_unix, "full_loot": PvpRules.is_full_loot(tier)}
		_corpses[character_id] = {"zone_id": zone_id, "pos": pos_dict, "decay_unix": decay_unix, "security_tier": tier}
	else:
		world_hooks["corpse"] = null
		_corpses.erase(character_id)  # a fresh no-drop death overwrites any prior corpse for this character
	record["world_hooks"] = world_hooks
	record["sheet"] = new_sheet
	# Respawn at the secured spaceport med bay (WorldState.SPAWN_POINT), default zone.
	_peer_zones[peer_id] = _default_zone
	record["zone"] = _default_zone
	_cached_save(character_id, record)
	if state != null:
		state.restore_player(peer_id, WorldState.SPAWN_POINT, 0.0)
	if arena != null:
		arena.set_player_sheet(peer_id, new_sheet)  # rebuild pools from the post-death sheet
		arena.set_player_combat(peer_id, {"player_wound_severity": PersistenceStore.severity_for_wound_state(String(new_sheet.get("wound_state", "wounded")))})
		arena.set_player_target(peer_id, "")   # disengage from the hostile
		arena.set_player_lethal(peer_id, false)
		arena.clear_intents_targeting(peer_id) # cancel shots aimed at the (now-respawned) victim
		arena.clear_status(peer_id)            # DIV-0024 (audit fix): drop any venom/restraint so a schedule
		                                       # seeded before death can't tick the respawn (respawn sev 2 < the
		                                       # tick loop's DISABLED_SEVERITY skip guard, which would re-down it)
	_heal_treated.erase(peer_id)
	# DIV-0019/DIV-0027: credit the killer ONCE per takeout. A fresh instant-kill (sev 5) credits here;
	# every downed-origin death (bleed-out, yield, or a finishing hit on an already-downed victim) passes
	# credit_killer=false because the attacker was already credited at the DOWN — no double reward.
	if credit_killer:
		_credit_takedown(killer_peer)
	print("[death] peer %d killed by %s in %s (%s): durability -%d%%, dropped %d, insured=%s -> respawn wounded @ spaceport (credits kept %d)" % [
		peer_id, killer_name, zone_id, tier, int(outcome["durability_delta"]), dropped.size(), str(bool(outcome["insured"])), int(new_sheet.get("credits", 0))])
	if _telemetry != null:  # Seam 5: death telemetry (death rate / penalty flow)
		_telemetry.log_event("death", {
			"ts": Time.get_unix_time_from_system(), "character_id": character_id,
			"zone": zone_id, "tier": tier, "killer": killer_name,
			"durability_delta": int(outcome["durability_delta"]), "dropped": dropped.size(),
			"insured": bool(outcome["insured"]), "credits": int(new_sheet.get("credits", 0)),
		})
	if mode == Mode.SERVER:
		apply_credits.rpc_id(peer_id, int(new_sheet.get("credits", 0)))  # unchanged (credits kept) — refresh the client
		_push_sheet(peer_id, record)
		death_notice.rpc_id(peer_id, {
			"killer": killer_name, "zone": zone_id, "security": tier,
			"durability_loss": int(outcome["durability_delta"]), "dropped": dropped,
			"insured": bool(outcome["insured"]), "respawn": "spaceport",
		})

# server -> client: you were killed and respawned (DIV-0006)
@rpc("authority", "call_remote", "reliable")
func death_notice(notice: Dictionary) -> void:
	died.emit(notice)

# DIV-0019/DIV-0027: the killer-reward block, extracted from _handle_player_death so a DOWN and a KILL
# credit the attacker identically, and every downed->death re-uses it exactly ZERO more times. Guards
# arena.has_player so a disconnected killer never strands the reward.
func _credit_takedown(killer_peer: int) -> void:
	if killer_peer > 0 and arena != null and arena.has_player(killer_peer):
		_award_cp(killer_peer, "gameplay", COMBAT_CP_REWARD)
		_accrue_zone_influence(killer_peer, DISABLE_INFLUENCE)
		_accrue_territory_influence(killer_peer, KILL_TERRITORY_INFLUENCE)
		_feed_force_signal(killer_peer, "disables", 1)

# ============================================================================================
# DIV-0025 (Seam 3) — corpse decay + third-party looting. The pure CorpseDecay model owns EVERY gate
# (lawless-only full-loot per DIV-0019, contested owner-protected, secured no-corpse, and the DIV-0006
# decay windows / expiry); the server only supplies the clock (elapsed) + the position gate and performs
# the item transfer + manifest null-out. Credits are NEVER on a corpse (DIV-0006 credits KEPT).
# ============================================================================================

# Rebuild the RAM-only corpse registry from persisted records on boot so a corpse survives a server
# restart (decay_unix is wall-clock, so it keeps aging). Scans each character's world_hooks.corpse.
func _scan_corpses() -> void:
	if store == null:
		return
	_corpses.clear()
	for cid in store.list_character_ids():
		var record := store.load_record(String(cid))
		if record.is_empty():
			continue
		var manifest = (record.get("world_hooks", {}) as Dictionary).get("corpse", null)
		if typeof(manifest) != TYPE_DICTIONARY:
			continue
		_corpses[String(cid)] = {
			"zone_id": String((manifest as Dictionary).get("zone_id", "")),
			"pos": (manifest as Dictionary).get("pos", {}),
			"decay_unix": float((manifest as Dictionary).get("decay_unix", 0.0)),
			"security_tier": _tier_from_manifest(manifest),
		}
	if not _corpses.is_empty():
		print("[corpse] registry restored: %d corpse(s) on boot" % _corpses.size())

# The decay tier for a corpse: the registry-stored death tier when indexed, else derived from the
# manifest's own full_loot stamp (full_loot <-> lawless, otherwise contested). secured never writes a
# corpse body, so those are the only two tiers a real corpse can carry.
func _tier_from_manifest(manifest) -> String:
	return "lawless" if (typeof(manifest) == TYPE_DICTIONARY and bool((manifest as Dictionary).get("full_loot", false))) else "contested"

func _corpse_tier(character_id: String, manifest) -> String:
	if _corpses.has(character_id):
		return String((_corpses[character_id] as Dictionary).get("security_tier", "contested"))
	return _tier_from_manifest(manifest)

# True when the looting peer is standing within CORPSE_LOOT_RADIUS of the corpse's fallen position. The
# server owns positions (state.get_player). When there is no world state (headless composition), the
# spatial gate is skipped — the same-zone gate in the RPC still applies.
func _within_loot_range(peer_id: int, manifest: Dictionary) -> bool:
	if state == null:
		return true
	var player: Dictionary = state.get_player(peer_id)
	if player.is_empty():
		return false
	var cp: Dictionary = manifest.get("pos", {})
	var corpse_pos := Vector3(float(cp.get("x", 0.0)), float(cp.get("y", 0.0)), float(cp.get("z", 0.0)))
	var looter_pos: Vector3 = player.get("pos", corpse_pos)
	return looter_pos.distance_to(corpse_pos) <= CORPSE_LOOT_RADIUS

# client -> server: a THIRD PARTY loots another player's corpse. Gated ENTIRELY by
# CorpseDecay.loot_for_third_party — lawless full-loot only (DIV-0019), contested owner-protected, secured
# no body, nothing past the decay window (DIV-0006). On success the dropped set transfers into the looter's
# inventory (EconomyModel.grant_items, same append shape as buy) and the victim manifest is NULLED +
# de-indexed so it can never be double-looted. Credits are ALWAYS 0 here (DIV-0006) — never transferred.
@rpc("any_peer", "call_remote", "reliable")
func submit_loot_corpse(target_character_id: String) -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	var looter_id := String(_peer_characters.get(sender, ""))
	if looter_id == "":
		return
	var target := target_character_id.strip_edges()
	if target == "":
		loot_corpse_result.rpc_id(sender, {"ok": false, "reason": "no_corpse", "items": [], "target": target})
		return
	# Owner-retrieval vs third-party loot (DIV-0006/0019, audit fix 2026-07-03). A SELF-loot is NO LONGER
	# rejected outright — it routes to CorpseDecay.loot_for_owner: a CONTESTED corpse ("decays, owner-
	# retrieval only") is the owner's to reclaim within the 2h window; a LAWLESS full-loot corpse is FORFEIT
	# (the DIV-0019 penalty stands, up for grabs by third parties); secured drops no body. Identity is
	# compared on the CANONICAL record path, not raw ids (two distinct raw ids can sanitize to the SAME file
	# — a raw-string check would be bypassable), but loot_for_owner forfeits full-loot corpses so the self
	# path can never be abused to self-recover a lawless drop. Without this the contested drop was
	# unrecoverable by ANYONE (third party -> "protected", owner -> blocked) and silently decayed = deleted.
	var is_self := store.record_path(target) == store.record_path(looter_id)
	# The corpse manifest lives on the CORPSE OWNER's record: the looter's OWN record for a self-retrieval
	# (target sanitizes to looter_id's file), else the target's. Loading via the canonical owner id keeps the
	# self case a SINGLE record (looter == owner) so the grant + manifest-null never race two cached copies.
	var owner_id := looter_id if is_self else target
	var owner_rec := _cached_load(owner_id)
	if owner_rec.is_empty():
		loot_corpse_result.rpc_id(sender, {"ok": false, "reason": "no_corpse", "items": [], "target": target})
		return
	var world_hooks: Dictionary = owner_rec.get("world_hooks", {})
	var manifest = world_hooks.get("corpse", null)
	if typeof(manifest) != TYPE_DICTIONARY:
		loot_corpse_result.rpc_id(sender, {"ok": false, "reason": "no_corpse", "items": [], "target": target})
		return
	# Same-zone + in-range gate (server owns positions).
	if String(_peer_zones.get(sender, _default_zone)) != String((manifest as Dictionary).get("zone_id", "")):
		loot_corpse_result.rpc_id(sender, {"ok": false, "reason": "out_of_range", "items": [], "target": target})
		return
	if not _within_loot_range(sender, manifest):
		loot_corpse_result.rpc_id(sender, {"ok": false, "reason": "out_of_range", "items": [], "target": target})
		return
	# The pure model is the ONLY authority on WHETHER + WHAT may be taken — by tier, elapsed, and who asks.
	var tier := _corpse_tier(owner_id, manifest)
	var elapsed := int(Time.get_unix_time_from_system() - float((manifest as Dictionary).get("decay_unix", 0.0)))
	var result: Dictionary = CorpseDecay.loot_for_owner(manifest, tier, elapsed) if is_self else CorpseDecay.loot_for_third_party(manifest, tier, elapsed)
	if not (bool(result.get("retrieved", false)) or bool(result.get("looted", false))):
		loot_corpse_result.rpc_id(sender, {"ok": false, "reason": String(result.get("reason", "")), "items": [], "target": target})
		return
	var items: Array = result.get("items", [])
	# Transfer the dropped set into the LOOTER's inventory (credits ALWAYS 0 — DIV-0006 keeps them). For a
	# self-retrieval owner_id == looter_id, so owner_rec IS this same cached record: grant + null on the ONE
	# record and save once. For a third party, grant on the looter, then null the victim's manifest separately.
	var looter := _cached_load(looter_id)
	if looter.is_empty():
		loot_corpse_result.rpc_id(sender, {"ok": false, "reason": "no_corpse", "items": [], "target": target})
		return
	looter["sheet"] = EconomyModel.grant_items(looter.get("sheet", {}), items)
	if is_self:
		var lh: Dictionary = looter.get("world_hooks", {})
		lh["corpse"] = null
		looter["world_hooks"] = lh
		_cached_save(looter_id, looter)
	else:
		_cached_save(looter_id, looter)
		world_hooks["corpse"] = null
		owner_rec["world_hooks"] = world_hooks
		_cached_save(owner_id, owner_rec)
	_corpses.erase(owner_id)
	_push_sheet(sender, looter)  # refresh the looter's sheet panel with the transferred items
	print("[corpse] peer %d (%s) %s %s corpse (%s): %d item(s) %s" % [sender, looter_id, ("retrieved own" if is_self else "looted"), tier, String(result.get("reason", "")), items.size(), str(items)])
	loot_corpse_result.rpc_id(sender, {"ok": true, "reason": String(result.get("reason", "")), "items": items, "target": target})

# server -> client: the outcome of a corpse-loot attempt (reasons: looted / no_corpse / protected /
# expired / out_of_range).
@rpc("authority", "call_remote", "reliable")
func loot_corpse_result(result: Dictionary) -> void:
	loot_corpse_replied.emit(result)

# client helper: loot another player's corpse by character id
func send_loot_corpse(target_character_id: String) -> void:
	if mode == Mode.CLIENT and connected:
		submit_loot_corpse.rpc_id(1, target_character_id)

# DIV-0025: reap corpses whose DIV-0006 decay window has elapsed. Runs on the Director cadence (coarse is
# fine — CorpseDecay.is_expired's boundary is inclusive). Nulls the manifest on the persisted record and
# de-indexes so the body no longer exists / is not lootable.
func _despawn_expired_corpses() -> void:
	if _corpses.is_empty():
		return
	var now := Time.get_unix_time_from_system()
	for cid in _corpses.keys().duplicate():  # duplicate: the loop erases from _corpses
		var entry: Dictionary = _corpses[cid]
		var elapsed := int(now - float(entry.get("decay_unix", 0.0)))
		if CorpseDecay.is_expired(String(entry.get("security_tier", "contested")), elapsed):
			var record := _cached_load(String(cid))
			if not record.is_empty():
				var wh: Dictionary = record.get("world_hooks", {})
				wh["corpse"] = null
				record["world_hooks"] = wh
				_cached_save(String(cid), record)
			_corpses.erase(cid)
			print("[corpse] despawned %s's expired corpse (elapsed %ds)" % [cid, elapsed])

# DIV-0027: the tiered NON-lethal outcome for sev 3-4. NO DeathPenalty, NO respawn, NO zone move — the
# player stays where they fell (the arena DISABLED guard already freezes them from acting). Records the
# server-side downed state, credits the attacker ONCE (at the down), and notifies the victim with the
# yield affordance. A finishing hit on an already-downed victim does NOT re-credit or reset rounds.
func _handle_player_downed(peer_id: int, killer_peer: int, severity: int, killer_name: String) -> void:
	if store == null:
		return
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var already := _downed.has(peer_id)
	var rounds := int((_downed.get(peer_id, {}) as Dictionary).get("rounds", 0)) if already else 0
	_downed[peer_id] = {"severity": severity, "killer": killer_peer, "name": killer_name, "rounds": rounds}
	# DIV-0013/DIV-0027 (verify: revive-persist): a fresh down is new combat damage, so reset the
	# First-Aid retry gate — otherwise a player re-downed to a wound level a medic ALREADY treated this
	# session (e.g. revived incap->wounded, then knocked back to incap) is permanently refused First Aid,
	# defeating the revive path and forcing a lethal exit. The gate's "one First Aid per level until it
	# changes" intent still holds: a damage-driven return to a treated level IS a change.
	_heal_treated.erase(peer_id)
	if not already:
		_credit_takedown(killer_peer)  # one reward per takeout — credited at the DOWN, never again on bleed-out/yield
	print("[downed] peer %d downed by %s (sev %d, bleeding=%s) — no penalty, frozen in field%s" % [
		peer_id, killer_name, severity, str(severity >= 4), " (already down)" if already else ""])
	if mode == Mode.SERVER:
		downed_notice.rpc_id(peer_id, {"severity": severity, "killer": killer_name, "can_yield": true, "bleeding": (severity >= 4)})

# DIV-0027: the single funnel from downed -> full death (bleed-out OR yield). killer_peer 0 +
# credit_killer=false: the attacker was already credited at the down, so no re-reward.
func _resolve_downed_to_death(peer_id: int, cause: String) -> void:
	var kname := String((_downed.get(peer_id, {}) as Dictionary).get("name", "your wounds"))
	print("[downed] peer %d -> death (%s)" % [peer_id, cause])
	_handle_player_death(peer_id, kname, 0, false)

func _clear_downed(peer_id: int) -> void:
	_downed.erase(peer_id)

# DIV-0027: escape hatch (a). Runs every COMBAT WINDOW (5s) — NOT inside _resolve_combat_window (which
# early-returns on zero intents, so a lone downed player with no shooters must still tick). Re-syncs the
# live severity each tick (a mid-tick First Aid 4->3 correctly stops the bleed), then advances the pure
# downed decision: mortally_wounded bleeds out (recovery_model.death_roll, certain by round 13); an
# untreated incapacitated deteriorates to mortally_wounded after INCAP_DETERIORATE_WINDOWS. Guaranteed-
# terminating with ZERO player input.
func _tick_downed() -> void:
	if _downed.is_empty():
		return
	for peer in _downed.keys().duplicate():  # duplicate: the loop mutates _downed via death/revive
		var e: Dictionary = _downed[peer]
		var live := int(e.get("severity", DOWNED.DISABLED_SEVERITY))
		if arena != null and arena.has_player(peer):
			live = int((arena.player_state(peer) as Dictionary).get("player_wound_severity", live))
		e["severity"] = live
		var res: Dictionary = DOWNED.downed_tick(e, _server_rng)
		match String(res.get("action", "hold")):
			"revived":
				_clear_downed(peer)
				if mode == Mode.SERVER:
					revived_notice.rpc_id(peer, {"healer": 0, "to": PersistenceStore.wound_state_for_severity(live)})
			"die":
				_resolve_downed_to_death(peer, "bled_out")
			"deteriorate":
				e["severity"] = 4
				e["rounds"] = 0
				_downed[peer] = e
				if arena != null and arena.has_player(peer):
					arena.set_player_combat(peer, {"player_wound_severity": 4, "player_wound_level": "mortally_wounded"})
				print("[downed] peer %d deteriorated incapacitated -> mortally_wounded (safety net)" % peer)
				if mode == Mode.SERVER:
					downed_notice.rpc_id(peer, {"severity": 4, "killer": String(e.get("name", "your wounds")), "can_yield": true, "bleeding": true})
			_:  # "hold"
				e["rounds"] = int(res.get("rounds", int(e.get("rounds", 0))))
				_downed[peer] = e

# server -> client: you are DOWNED-in-field (sev 3-4). Distinct from death; carries the yield affordance.
@rpc("authority", "call_remote", "reliable")
func downed_notice(notice: Dictionary) -> void:
	downed.emit(notice)

# server -> client: a medic First-Aided you back above the downed floor (DIV-0013 revive).
@rpc("authority", "call_remote", "reliable")
func revived_notice(notice: Dictionary) -> void:
	revived.emit(notice)

# client -> server: a downed player voluntarily yields (accepts death + respawn). DIV-0027 escape hatch
# (b) — the universal always-available out. Server re-validates _downed membership so a non-downed client
# can't self-respawn. Routes to the full death path (yield == accept death); killer 0 (already credited).
@rpc("any_peer", "call_remote", "reliable")
func submit_yield() -> void:
	if mode != Mode.SERVER:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	if not _downed.has(sender):
		return  # nothing to yield — reject
	_resolve_downed_to_death(sender, "yield")

# client -> server helper: yield while downed.
func send_yield() -> void:
	if mode == Mode.CLIENT and connected:
		submit_yield.rpc_id(1)

# client -> server: buy a death-insurance policy (DIV-0006): debit INSURANCE_PREMIUM, grant charges.
@rpc("any_peer", "call_remote", "reliable")
func submit_buy_insurance() -> void:
	if mode != Mode.SERVER or store == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _rate_ok(sender):
		return
	var character_id := String(_peer_characters.get(sender, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	if int(sheet.get("credits", 0)) < DeathPenalty.INSURANCE_PREMIUM:
		insurance_result.rpc_id(sender, {"ok": false, "reason": "cannot_afford", "premium": DeathPenalty.INSURANCE_PREMIUM})
		return
	sheet["credits"] = int(sheet.get("credits", 0)) - DeathPenalty.INSURANCE_PREMIUM
	var granted: Dictionary = DeathPenalty.buy_insurance(sheet, true)
	var new_sheet: Dictionary = granted["sheet"]
	record["sheet"] = new_sheet
	_cached_save(character_id, record)
	var charges := int((new_sheet.get("insurance", {}) as Dictionary).get("charges", 0))
	apply_credits.rpc_id(sender, int(new_sheet.get("credits", 0)))
	_push_sheet(sender, record)
	print("[insurance] peer %d bought a policy for %d (charges now %d, credits %d)" % [sender, DeathPenalty.INSURANCE_PREMIUM, charges, int(new_sheet.get("credits", 0))])
	insurance_result.rpc_id(sender, {"ok": true, "charges": charges, "premium": DeathPenalty.INSURANCE_PREMIUM, "credits": int(new_sheet.get("credits", 0))})

# server -> client: buy-insurance outcome
@rpc("authority", "call_remote", "reliable")
func insurance_result(result: Dictionary) -> void:
	insurance_replied.emit(result)

func send_buy_insurance() -> void:
	if mode == Mode.CLIENT and connected:
		submit_buy_insurance.rpc_id(1)

# --- DIV-0011: SWG-Village Force awakening (the hidden, rare, earned unlock) ---
# Accrue a deterministic awakening signal onto a character's hidden force_unlock track. No-op once
# COMPLETE (awakened). Persists the updated unlock. The signals map play -> latent progress.
func _feed_force_signal(peer_id: int, signal_key: String, amount: int = 1) -> void:
	if store == null or amount <= 0:
		return
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		return
	var sheet: Dictionary = record.get("sheet", {})
	var unlock: Dictionary = sheet.get("force_unlock", ForceAwaken.initial_unlock())
	if ForceAwaken.is_complete(unlock):
		return
	sheet["force_unlock"] = ForceAwaken.record_signal(unlock, signal_key, amount)
	record["sheet"] = sheet
	_cached_save(character_id, record)

# The server soft-cap denominator: connected characters that have begun awakening (phase >= 1).
# v1 counts CONNECTED latents only (offline latents don't hold a slot); a server-global persisted
# tally is a tracked follow-up.
func _awakened_count() -> int:
	var n := 0
	for pid in _peer_characters.keys():
		var cid := String(_peer_characters[pid])
		if cid == "":
			continue
		var rec := _cached_load(cid)
		if ForceAwaken.counts_toward_cap((rec.get("sheet", {}) as Dictionary).get("force_unlock", {})):
			n += 1
	return n

# Each Director tick: feed the per-tick "tense_ticks" signal to every connected player standing in a
# dangerous (lawless/contested/high-alert) zone — surviving tense places nudges the latent along.
func _feed_tense_ticks() -> void:
	if zones == null:
		return
	for peer_id in _peer_characters.keys():
		var zone_id := String(_peer_zones.get(peer_id, _default_zone))
		if _creature_spawn != null and _creature_spawn.is_dangerous_posture(String((zones.get_zone(zone_id) as Dictionary).get("alert_level", "standard")), zones.effective_security(zone_id)):
			_feed_force_signal(int(peer_id), "tense_ticks", 1)

# One Director-tick step of every connected latent's awakening track (manifest / advance / awaken).
# On completion, flip force_sensitive (apply_completion) + push the sheet + notify the client. Rare
# by design — the manifest/awaken rolls + soft cap live in the pure model's tunable dials.
func _advance_force_awakenings() -> void:
	if store == null:
		return
	var cap_count := _awakened_count()
	for pid in _peer_characters.keys():
		var character_id := String(_peer_characters[pid])
		if character_id == "":
			continue
		var record := _cached_load(character_id)
		if record.is_empty():
			continue
		var sheet: Dictionary = record.get("sheet", {})
		var unlock: Dictionary = sheet.get("force_unlock", ForceAwaken.initial_unlock())
		if ForceAwaken.is_complete(unlock):
			continue
		var result: Dictionary
		if force_awaken_now:  # TEST-ONLY: jump straight to COMPLETE
			result = {"unlock": {"phase": ForceAwaken.PHASE_COMPLETE, "signals": unlock.get("signals", {})}, "event": "awaken"}
		else:
			result = ForceAwaken.director_tick(_server_rng, unlock, cap_count)
		var event := String(result.get("event", ""))
		if event == "":
			continue
		sheet["force_unlock"] = result["unlock"]
		var completed := ForceAwaken.is_complete(result["unlock"])
		if completed:
			sheet = ForceAwaken.apply_completion(sheet)  # flips force_sensitive + seeds the force-skill block
		record["sheet"] = sheet
		_cached_save(character_id, record)
		if event == "manifest":
			cap_count += 1  # a newly-manifested latent now holds a soft-cap slot
		print("[force] peer %d %s -> phase %d%s" % [int(pid), event, int((sheet["force_unlock"] as Dictionary)["phase"]), " (AWAKENED)" if completed else ""])
		if completed:
			_push_sheet(int(pid), record)
			if mode == Mode.SERVER:
				force_awakened.rpc_id(int(pid), {"message": "You feel the Force awaken within you."})

# server -> client: your Force sensitivity has awakened (DIV-0011)
@rpc("authority", "call_remote", "reliable")
func force_awakened(notice: Dictionary) -> void:
	force_awakened_replied.emit(notice)

# DIV-0012: natural wound recovery. Once per Director tick (= one recovery interval), each
# CONNECTED character whose persisted wound is a "can still act" tier (stunned/wounded/
# wounded_twice) makes a self-recovery heal_check with their OWN Strength vs the Guide_19 §3
# difficulty (server-owned RNG). On success the wound drops one level: persist it and refresh
# ONLY the live combat wound penalty (set_player_combat merges just player_wound_severity, so
# depleted CP/FP are untouched). incapacitated+ are excluded (need medical / owner-gated death).
func _recover_wounds() -> void:
	if arena == null:
		return
	for peer_id in _peer_characters.keys():
		var character_id := String(_peer_characters[peer_id])
		if character_id == "":
			continue
		var record := _cached_load(character_id)
		if record.is_empty():
			continue
		var sheet: Dictionary = record.get("sheet", {})
		var level := _live_wound_state(peer_id, sheet)  # DIV-0016: recover LIVE combat wounds too, not just the autosave-lagged sheet
		if not HEALABLE_WOUND_LEVELS.has(level):
			continue
		var strength_code := String((sheet.get("attributes", {}) as Dictionary).get("strength", "2D"))
		var strength_pool: Dictionary = D6Rules.parse_pool(strength_code)
		var result: Dictionary = Recovery.heal_check(_server_rng, strength_pool, level)
		if not bool(result.get("healed", false)):
			continue
		var new_level := String(result.get("new_level", level))
		sheet["wound_state"] = new_level
		record["sheet"] = sheet
		_cached_save(character_id, record)
		# G14 (DIV-0008): write the healed LEVEL STRING back alongside the severity so a wounded_twice->wounded
		# recovery is NOT re-collapsed to 'wounded' by set_player_combat's severity->level fallback (both pin to
		# severity 2). Without the explicit level the -2D tier would be silently erased on the first recovery tick.
		arena.set_player_combat(peer_id, {
			"player_wound_severity": PersistenceStore.severity_for_wound_state(new_level),
			"player_wound_level": new_level,
		})
		_feed_force_signal(peer_id, "recoveries", 1)      # DIV-0011: recovering from a wound nudges the track
		if new_level == "healthy":
			_heal_treated.erase(peer_id)  # fully recovered -> reset the First-Aid retry gate (DIV-0013/F8)
		print("[recovery] peer %d %s healed %s -> %s (Strength %s rolled %d vs %d)" % [
			peer_id, character_id, level, new_level, strength_code,
			int(result.get("roll_total", 0)), int(result.get("difficulty", 0))])

# DIV-0016: the player's CURRENT wound level. During play the LIVE wound lives in the arena
# (player_wound_severity — combat damage, recovery, First Aid all flow through it; the condition HUD
# + nameplate + you.wound already read it). sheet.wound_state only catches up on autosave (~30s), so
# a freshly combat-wounded player would otherwise read 'healthy' to First Aid + natural recovery and
# be untreatable. Prefer the arena (the live truth, seeded from the sheet at login, persisted back on
# save); fall back to the sheet for any character not currently in the arena.
func _live_wound_state(peer_id: int, sheet: Dictionary) -> String:
	if arena != null and arena.has_player(peer_id):
		var ps: Dictionary = arena.player_state(peer_id)
		# G14 (DIV-0008): prefer the arena's wound LEVEL STRING — it is the cross-window source of truth
		# that distinguishes wounded (-1D) from wounded_twice (-2D). Deriving from the severity int here
		# collapses wounded_twice -> wounded (severity_for_level pins both to 2), which would make a live
		# wounded_twice patient heal at the wrong difficulty and skip a ladder rung. Fall back to the
		# severity-derived level only when no level string is present.
		var lvl := String(ps.get("player_wound_level", ""))
		if lvl != "":
			return lvl
		return PersistenceStore.wound_state_for_severity(int(ps.get("player_wound_severity", 0)))
	return String(sheet.get("wound_state", "healthy"))

func _attribute_for_skill(skill: String) -> String:
	return String(_skill_attr.get(skill, "dexterity"))

# --- E26: record cache + reliable-RPC rate limiting ---
# Read-through cache: the first load hits disk; subsequent reads (skill-raise, equip,
# claim, CP award, org lookups) hit memory — killing the load+rewrite-per-call JSON I/O.
func _cached_load(character_id: String) -> Dictionary:
	if _record_cache.has(character_id):
		return _record_cache[character_id]
	var record := store.load_record(character_id)
	if not record.is_empty():
		_record_cache[character_id] = record
	return record

# Write-through: update the cache AND persist.
func _cached_save(character_id: String, record: Dictionary) -> void:
	_record_cache[character_id] = record
	store.save_record(character_id, record)

# Token-bucket reliable-RPC throttle. Returns false (drop) when a peer exceeds its budget.
# Server-only; uses a real clock fed into the pure account_auth_model bucket.
func _rate_ok(peer_id: int) -> bool:
	var r: Dictionary = Auth.consume_token(_peer_rpc_budget.get(peer_id, {}), Time.get_ticks_msec())
	_peer_rpc_budget[peer_id] = r["budget"]
	if not bool(r["allowed"]):
		print("[ratelimit] peer %d throttled" % peer_id)
	return bool(r["allowed"])

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
				var fired_ids: Array = arena.pending_shooter_ids() if arena != null else []  # G4: capture the provoked shooters BEFORE resolve clears intents
				_resolve_combat_window()
				_tick_hostile_aggression(fired_ids)  # G4 (DIV-0017): unprovoked hostile fire at same-zone players who did NOT fire (lethal zones only)
				_tick_status_effects()  # DIV-0024: advance venom/restraint riders seeded by the two fire passes above (before the downed tick)
				_tick_downed()  # DIV-0027: bleed-out / deterioration for downed players (SEPARATE call — _resolve_combat_window early-returns on zero intents; a lone downed player must still tick)
			_autosave_accum += delta
			if _autosave_accum >= AUTOSAVE_SECONDS:
				_autosave_accum = 0.0
				for pid in _peer_characters.keys():
					_save_peer(pid)
			_director_accum += delta
			if _director_accum >= director_tick_seconds:
				_director_accum = 0.0
				if zones != null:
					_fold_pending_influence()  # E24: fold player activity into influence first
					zones.director_tick()
					_advance_ambient()  # E27: advance the ambient NPC roster per zone
					_advance_hostiles()  # DIV-0017: (re)spawn + engage hostile creatures in lethal zones
					_despawn_expired_corpses()  # DIV-0025: reap player corpses past their DIV-0006 decay window
					_save_world_state()  # F58: persist the advanced territory so it survives a restart
				_recover_wounds()  # DIV-0012: natural wound recovery for connected players
				_feed_tense_ticks()  # DIV-0011: tense-zone participation feeds the awakening track
				_advance_force_awakenings()  # DIV-0011: step every connected latent's hidden awakening
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
	# Zone-scoped presence: a peer only sees players in its OWN zone (consistent with
	# zone-scoped chat, F2 — the zones are distinct places). state.snapshot() returns a fresh
	# dict + fresh entries each call, so per-peer filtering is safe. The peer's own entry is in
	# its own zone, so it is retained (needed for the first-person camera). Standard MMO zone
	# visibility, not a WEG/MUSH mechanic divergence (see DIV-0001).
	if peer_id != 0:
		var here: Array = []
		for p in snap.get("players", []):
			if String(_peer_zones.get(int((p as Dictionary).get("id", 0)), _default_zone)) == zone_id:
				here.append(p)
		snap["players"] = here
	# Enrich each (zone-filtered) player entry with its live wound condition so OTHER players'
	# nameplates show who's hurt (supports First Aid targeting), AND its faction axis (F36) so
	# nameplates + /who show allegiance — the people-level companion to the F35 zone-control HUD.
	# Entries are fresh per call.
	for p in snap.get("players", []):
		var ppid := int((p as Dictionary).get("id", 0))
		if arena != null and arena.has_player(ppid):
			# G14 (DIV-0008): prefer the wound LEVEL STRING so an ally's nameplate shows wounded_twice (the -2D
			# tier) for correct First-Aid targeting, not the severity-collapsed 'wounded'. Fall back to severity.
			var pps: Dictionary = arena.player_state(ppid)
			var pw := String(pps.get("player_wound_level", ""))
			if pw == "":
				pw = PersistenceStore.wound_state_for_severity(int(pps.get("player_wound_severity", 0)))
			(p as Dictionary)["wound"] = pw
			# DIV-0024: compact venom/restraint status on the nameplate (additive — only when active).
			var pstat := arena.player_status_summary(ppid)
			if int(pstat.get("poison_rounds_left", 0)) > 0:
				(p as Dictionary)["status_poison_rounds_left"] = int(pstat["poison_rounds_left"])
			if bool(pstat.get("restrained", false)):
				(p as Dictionary)["status_restrained"] = true
			if String(pstat.get("source", "")) != "" and (int(pstat.get("poison_rounds_left", 0)) > 0 or bool(pstat.get("restrained", false))):
				(p as Dictionary)["status_source"] = String(pstat["source"])
		var pax := String(_peer_axes.get(ppid, ""))
		if pax != "":
			(p as Dictionary)["axis"] = pax  # F36: faction allegiance (only org members carry one)
	if zones != null:
		snap["zone"] = zones.zone_summary(zone_id)
	if territory != null and peer_id != 0:
		var my_org := String(_peer_orgs.get(peer_id, ""))
		var tsum := _territory_summary(my_org, zone_id)
		# F34: surface the viewer's own faction RANK (territory authority — gates claim at
		# RANK_CLAIM, found-a-city at RANK_CITY) so the org HUD can show it. Pure display of
		# stored state; the thresholds ride along so the client needs no hardcoded numbers.
		tsum["your_rank"] = int(_peer_ranks.get(peer_id, 0))
		tsum["rank_claim"] = OrgModel.RANK_CLAIM
		tsum["rank_city"] = OrgModel.RANK_CITY
		# F53: how many of the viewer's org-mates are ONLINE (cross-zone) — coordination presence.
		# Counted from the live per-peer org map (connected members only).
		var members_online := 0
		if my_org != "":
			for pid in _peer_orgs:
				if String(_peer_orgs[pid]) == my_org:
					members_online += 1
		tsum["org_members_online"] = members_online
		snap["territory"] = tsum
	snap["npcs"] = _ambient.get(zone_id, [])  # E27: ambient NPCs in the player's zone
	snap["named_npcs"] = _named_npcs_by_zone.get(zone_id, [])  # named NPCs in this zone (client renders w/ npc_builder)
	snap["zone_list"] = _zone_list()  # DIV-0014: loaded zones for the client's travel picker (cached)
	# Per-peer "you" block: the player's OWN live wound condition (so the client can show a
	# condition readout that reflects combat damage, natural recovery, and First Aid). Pure
	# presentation data surfaced from the live combat state — no new mechanic.
	if arena != null and peer_id != 0 and arena.has_player(peer_id):
		var ps: Dictionary = arena.player_state(peer_id)
		# G14 (DIV-0008): prefer the wound LEVEL STRING so the client readout shows the true
		# wounded_twice (-2D) tier — the severity int collapses wounded/wounded_twice to 2, which
		# would display -1D while live combat applies -2D. Fall back to the severity mapping when no
		# level is tracked (freshly restored / healthy state with no level string).
		var ws := String(ps.get("player_wound_level", ""))
		if ws == "":
			ws = PersistenceStore.wound_state_for_severity(int(ps.get("player_wound_severity", 0)))
		var mystat := arena.player_status_summary(peer_id)  # DIV-0024: my own venom/restraint status
		snap["you"] = {
			"wound": ws,
			"wound_penalty": WoundLadder.penalty_dice_for_level(ws),  # F46: the WEG -ND action penalty for this wound
			"cp": int(ps.get("player_character_points", 0)),  # in-combat Character Points (C key, F5)
			"fp": int(ps.get("player_force_points", 0)),       # Force Points (F key, F5)
			"status_poison_rounds_left": int(mystat.get("poison_rounds_left", 0)),  # DIV-0024: "Poisoned (n)"
			"status_restrained": bool(mystat.get("restrained", false)),             # DIV-0024: "Held"
			"status_source": String(mystat.get("source", "")),                      # the injecting creature
		}
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
	var pvp_gate := _build_pvp_gate()  # DIV-0019: authorize player-target pairs from live zone/security
	var result := arena.resolve_window(_server_rng.randi(), pvp_gate)
	var envelopes: Array = result.get("envelopes", [])
	for envelope in envelopes:
		# F65: scope each combat envelope to the SHOOTER's zone (like say/emote chat, F2/F62) — combat
		# is local presence, not galaxy-wide. Previously apply_combat_envelope.rpc broadcast every shot
		# to ALL peers, so a player saw cross-zone fights in their combat log + F47 target HUD.
		var shooter_zone := String(_peer_zones.get(int(envelope.get("shooter_id", 0)), _default_zone))
		for pid in multiplayer.get_peers():
			if String(_peer_zones.get(pid, _default_zone)) == shooter_zone:
				apply_combat_envelope.rpc_id(pid, envelope)
	print("[combat] window %d resolved: %d shot(s), dummy severity %d" % [
		int(result.get("window", 0)),
		envelopes.size(),
		int((result.get("target_state", {}) as Dictionary).get("wound_severity", 0)),
	])
	if _telemetry != null:  # Seam 5: combat-window resolution telemetry (throughput / TTK)
		_telemetry.log_event("window_resolve", {
			"ts": Time.get_unix_time_from_system(),
			"window": int(result.get("window", 0)), "envelope_count": envelopes.size(),
		})
	# Per-envelope consequences: kill credit (dummy OR hostile), creature LOOT + despawn (DIV-0018).
	# Player DEATHS (DIV-0006/0019) are COLLECTED + deduped, then applied once — a PvP victim can be both
	# a casualty (hit by an attack) and a return-fire shooter-death in the same window.
	var dummy_disabled := bool(result.get("target_disabled", false))
	var looted := {}  # hostile keys already looted/despawned this window (one shooter credited)
	# DIV-0027: victim_peer -> {killer, name, severity}. Carries SEVERITY so the net layer can TIER the
	# takeout (sev 5 = death; sev 3-4 = downed). Dedup keeps the MAX severity per victim so a finishing
	# sev-5 is never downgraded by a prior sev-3 write in the same window.
	var takedowns := {}
	for envelope in envelopes:
		var shooter := int(envelope.get("shooter_id", 0))
		var tkey := String(envelope.get("target_key", ""))
		var target_down := (tkey == "" and dummy_disabled) or (tkey != "" and bool(envelope.get("target_disabled", false)))
		if target_down:
			# G13/G10: the shared training dummy is INFINITE sparring practice, NOT a faucet. It pays the
			# capped gameplay CP (progression practice, bounded by the dual-track cap) and NOTHING that feeds
			# the world economy — no zone/territory influence, no Force progress. Only a REAL hostile disable
			# (tkey != "") drives the Director economy, so a cross-zone autofire bot can't farm influence /
			# territory / Force off the spaceport dummy (Fable measured 20 dummy hits in 45s doing exactly that).
			_award_cp(shooter, "gameplay", COMBAT_CP_REWARD)
			var is_hostile_disable := tkey != ""
			if is_hostile_disable:
				_accrue_zone_influence(shooter, DISABLE_INFLUENCE)  # E24: play feeds faction influence
				_accrue_territory_influence(shooter, KILL_TERRITORY_INFLUENCE)  # earn org territory influence
				_feed_force_signal(shooter, "disables", 1)  # DIV-0011: a combat disable nudges the track
			# DIV-0018: a disabled HOSTILE creature drops loot credits (the training dummy is CP-only). Despawn it.
			if tkey != "" and not looted.has(tkey):
				looted[tkey] = true
				var spawn: Dictionary = arena.hostile_target_spawn(tkey)
				var loot: Dictionary = EconomyModel.roll_loot(spawn, _server_rng.randi())
				var loot_credits := int(loot.get("credits", 0)) + int(loot.get("salvage_credits", 0))
				if loot_credits > 0:
					_award_credits(shooter, loot_credits)
				print("[loot] peer %d looted %s: %d credits (%d + salvage %d)" % [
					shooter, String(spawn.get("name", tkey)), loot_credits, int(loot.get("credits", 0)), int(loot.get("salvage_credits", 0))])
				if _telemetry != null:  # Seam 5: creature-loot telemetry (economy inflow)
					_telemetry.log_event("loot", {
						# character_id must be the PERSISTENT character-id STRING (like death/buy/sell/travel),
						# not the transient peer int — else loot (the primary economy INFLOW) can't be joined
						# to a character's other events for a faucet/sink tally (verify: coverage-correctness).
						"ts": Time.get_unix_time_from_system(), "character_id": String(_peer_characters.get(shooter, "")), "peer_id": shooter,
						"creature_key": String(spawn.get("creature_key", tkey)),
						"loot_credits": int(loot.get("credits", 0)), "salvage_credits": int(loot.get("salvage_credits", 0)),
					})
				# DIV-0020: a disabled HOSTILE creature advances disable objectives (creature_key narrows the targeted ones).
				_feed_quest_event(shooter, {"type": "disable", "creature_key": String(spawn.get("creature_key", ""))})
				_maybe_harvest(shooter, spawn, tkey)  # DIV-0023: ~15 creatures ALSO field-dress into a sellable good (Option A)
				arena.remove_hostile_target(tkey)  # a fresh hostile may spawn next Director tick
		# A LETHAL hit that took the SHOOTER out (creature or PvP return fire) is a takeout.
		if bool(envelope.get("lethal", false)) and arena.has_player(shooter):
			var sev := int((arena.player_state(shooter) as Dictionary).get("player_wound_severity", 0))
			if sev >= CombatArena.DISABLED_SEVERITY:
				var rf_killer := int(envelope.get("target_peer_id", 0)) if bool(envelope.get("pvp", false)) else 0
				if not takedowns.has(shooter) or sev > int((takedowns[shooter] as Dictionary).get("severity", 0)):
					takedowns[shooter] = {"killer": rf_killer, "name": String(envelope.get("target_name", "a hostile")), "severity": sev}
	# DIV-0019: a PvP victim taken OUT by an incoming attack (the TARGET side of an authorized shot).
	for c in result.get("casualties", []):
		var vic := int((c as Dictionary).get("peer", 0))
		var kp := int((c as Dictionary).get("killer", 0))
		var csev := int((c as Dictionary).get("severity", CombatArena.DISABLED_SEVERITY))
		var kname := String(state.get_player(kp).get("name", "another spacer")) if (state != null and state.has_player(kp)) else "another spacer"
		var prior_sev := int((takedowns.get(vic, {}) as Dictionary).get("severity", 0))
		var prior_killer := int((takedowns.get(vic, {}) as Dictionary).get("killer", 0))
		# DIV-0027 (verify: casualty-routing): keep the MAX-severity entry for the tier/name, but break an
		# EQUAL-severity tie toward a REAL attacker (kp>0) over a creature/self takeout (killer 0) — so a
		# PvP aggressor who co-disabled the victim at the same final severity still earns the takeout credit
		# (CP / zone / territory / Force signal) instead of it being lost to killer 0.
		if not takedowns.has(vic) or csev > prior_sev or (csev == prior_sev and kp > 0 and prior_killer == 0):
			takedowns[vic] = {"killer": kp, "name": kname, "severity": csev}
	# DIV-0027: TIER each takeout exactly once. sev 5 -> full death (DIV-0006, UNCHANGED); sev 3-4 -> downed
	# (no penalty, frozen in field, escape hatches). credit_killer = not already-downed so a finishing hit
	# on an already-credited downed victim does not re-reward the attacker.
	for victim in takedowns:
		if state != null and state.has_player(int(victim)):
			var td: Dictionary = takedowns[victim]
			var s := int(td.get("severity", CombatArena.DISABLED_SEVERITY))
			if PvpRules.is_kill(s):
				_handle_player_death(int(victim), String(td["name"]), int(td["killer"]), not _downed.has(int(victim)))
			else:
				_handle_player_downed(int(victim), int(td["killer"]), s, String(td["name"]))
	if dummy_disabled:
		arena.reset_target()
		print("[combat] training target disabled — respawned")

func _save_peer(peer_id: int) -> void:
	if store == null or state == null:
		return
	var character_id := String(_peer_characters.get(peer_id, ""))
	if character_id == "":
		return
	var player := state.get_player(peer_id)
	if player.is_empty():
		return
	var record := _cached_load(character_id)
	if record.is_empty():
		record = store.default_record(character_id, character_id, String(player.get("name", "")), WorldState.SPAWN_POINT)
	record = PersistenceStore.apply_position(record, player.get("pos", WorldState.SPAWN_POINT), float(player.get("yaw", 0.0)))
	if arena != null:
		record = PersistenceStore.apply_combat(record, arena.player_state(peer_id))
	record["name"] = String(player.get("name", ""))
	_cached_save(character_id, record)
