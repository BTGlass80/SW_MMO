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

var _builder: WorldBuilder
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
var _last_condition := "healthy"   # so we log condition CHANGES only
var _target_label: Label           # F47: at-a-glance target status (companion to the condition HUD)
var _last_target := ""             # so we log target-status CHANGES only
var _org_label: Label
var _last_org_line := ""           # so we log org/territory CHANGES only
var _boost_label: Label
var _last_boost := ""              # so we log combat CP/FP CHANGES only
var _sheet_panel: Label            # F24: character sheet (toggle with V); hidden by default
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
var _shop_list: VBoxContainer
var _death_overlay: ColorRect     # DIV-0006: brief full-screen "you were killed" card
var _death_label: Label
var _toast_label: Label           # transient HUD feedback (credits/loot/buy/sell/force-awaken)
var _toast_tween: Tween

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
	Net.insurance_replied.connect(_on_insurance_replied)
	Net.force_awakened_replied.connect(_on_force_awakened)
	Net.fire_rejected.connect(_on_fire_rejected)

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
		Net.start_server()
		return

	_builder = WorldBuilder.new()
	_builder.build_lighting(self)
	_builder.build_ground(self)
	_builder.build_settlement(self)
	_monster_builder = MonsterBuilder.new()
	_build_camera()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Net.start_client(_resolve_host())

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	_is_server = args.has("--server")
	_autofire = args.has("--autofire")
	_autowalk = args.has("--autowalk")
	var account := _arg_value("--account")
	if account != "":
		_account = account
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
	# While the shop overlay is open it owns the cursor: only B/Esc (close) act; everything
	# else is swallowed here so it never fires/recaptures the mouse. The Buy/Sell Buttons still
	# receive their clicks via the normal GUI pass (we don't mark the event handled).
	if _shop_open:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_B or event.keycode == KEY_ESCAPE):
			_close_shop()
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
			Net.send_fire_intent({"aim": _aim, "cover": _cover, "cp": _spend_cp, "fp": _use_fp, "dodge": _dodge})
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
		Net.start_client(_resolve_host())
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
		# + faction allegiance (F36).
		if id != _local_id:
			_update_nameplate(record, id, String(entry.get("name", "")), String(entry.get("wound", "healthy")), String(entry.get("axis", "")))
	for id in _avatars.keys():
		if not seen.has(id):
			(_avatars[id]["root"] as Node3D).queue_free()
			_avatars.erase(id)
	_reconcile_npcs(snapshot.get("npcs", []))  # E27: render the zone's ambient NPCs
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
	_update_condition(String(you.get("wound", "healthy")), int(you.get("wound_penalty", 0)))
	_update_boost(int(you.get("cp", 0)), int(you.get("fp", 0)))
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

# Show a remote player's wound condition on their nameplate (so a medic can see who's hurt
# and target First Aid). Healthy -> just the name; wounded -> "Name — Condition" tinted.
func _update_nameplate(record: Dictionary, peer_id: int, display_name: String, wound: String, axis: String = "") -> void:
	var label := (record["root"] as Node3D).get_node_or_null("Nameplate") as Label3D
	var base := display_name if display_name != "" else "Spacer-%d" % peer_id
	if axis != "":
		base += " [%s]" % _axis_pretty(axis)  # F36: faction allegiance
	if label != null:
		if wound == "healthy":
			label.text = base
			label.modulate = Color(0.09, 0.08, 0.06)
		else:
			label.text = "%s — %s" % [base, _condition_pretty(wound)]
			label.modulate = _condition_color(wound)
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
	root.global_position = pos
	add_child(root)
	return root

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 74
	_camera.current = true
	_camera.global_position = Vector3(-20, 1.75, -6)
	add_child(_camera)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(18, 16)
	_status.text = "Connecting..."
	_status.add_theme_font_size_override("font_size", 17)
	_status.modulate = Color(0.09, 0.08, 0.06)
	layer.add_child(_status)

	var controls := Label.new()
	controls.position = Vector2(18, 40)
	controls.text = "WASD move · mouse look · RMB aim · C cycle CP · F Force Point · LMB fire · H First Aid · T travel · B shop · V sheet · Enter chat · Esc release"
	controls.add_theme_font_size_override("font_size", 14)
	controls.modulate = Color(0.09, 0.08, 0.06)
	layer.add_child(controls)

	_combat_log = Label.new()
	_combat_log.position = Vector2(18, 70)
	_combat_log.size = Vector2(900, 220)
	_combat_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combat_log.text = "Combat log:"
	_combat_log.add_theme_font_size_override("font_size", 14)
	_combat_log.modulate = Color(0.12, 0.10, 0.07)
	layer.add_child(_combat_log)

	_zone_label = Label.new()
	_zone_label.position = Vector2(760, 16)
	_zone_label.text = "Zone: ..."
	_zone_label.add_theme_font_size_override("font_size", 15)
	_zone_label.modulate = Color(0.10, 0.09, 0.07)
	layer.add_child(_zone_label)

	_wallet_label = Label.new()
	_wallet_label.position = Vector2(760, 40)
	_wallet_label.text = "CP: -   (K: raise Blaster)"
	_wallet_label.add_theme_font_size_override("font_size", 14)
	_wallet_label.modulate = Color(0.10, 0.09, 0.07)
	layer.add_child(_wallet_label)

	_credits_label = Label.new()  # Wave F economy: credit balance (B: shop)
	_credits_label.position = Vector2(760, 140)
	_credits_label.text = "Credits: -   (B: shop)"
	_credits_label.add_theme_font_size_override("font_size", 14)
	_credits_label.modulate = Color(0.16, 0.14, 0.05)
	layer.add_child(_credits_label)

	_condition_label = Label.new()
	_condition_label.position = Vector2(760, 60)
	_condition_label.text = "Condition: Healthy"
	_condition_label.add_theme_font_size_override("font_size", 14)
	_condition_label.modulate = _condition_color("healthy")
	layer.add_child(_condition_label)

	_boost_label = Label.new()
	_boost_label.position = Vector2(760, 100)
	_boost_label.text = "Boost (C/F): - CP · - FP"
	_boost_label.add_theme_font_size_override("font_size", 14)
	_boost_label.modulate = Color(0.10, 0.10, 0.13)
	layer.add_child(_boost_label)

	_target_label = Label.new()  # F47: persistent target status (the combat log only shows it on a hit)
	_target_label.position = Vector2(760, 120)
	_target_label.text = ""
	_target_label.add_theme_font_size_override("font_size", 14)
	_target_label.modulate = Color(0.16, 0.09, 0.08)
	layer.add_child(_target_label)

	_org_label = Label.new()
	_org_label.position = Vector2(760, 80)
	_org_label.text = ""
	_org_label.add_theme_font_size_override("font_size", 14)
	_org_label.modulate = Color(0.12, 0.10, 0.16)
	layer.add_child(_org_label)

	_news_label = Label.new()
	_news_label.position = Vector2(18, 300)
	_news_label.size = Vector2(900, 40)
	_news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_label.text = ""
	_news_label.add_theme_font_size_override("font_size", 14)
	_news_label.modulate = Color(0.30, 0.16, 0.10)
	layer.add_child(_news_label)

	_chat_log = Label.new()
	_chat_log.position = Vector2(18, 350)
	_chat_log.size = Vector2(900, 150)
	_chat_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_log.text = "Chat:"
	_chat_log.add_theme_font_size_override("font_size", 14)
	_chat_log.modulate = Color(0.09, 0.10, 0.15)
	layer.add_child(_chat_log)

	_chat_input = LineEdit.new()  # F22: GUI chat entry (Enter opens, type, Enter sends, Esc cancels)
	_chat_input.placeholder_text = "Enter: chat (/say /ooc /org /emote) or a command (/help lists them)"
	_chat_input.position = Vector2(18, 510)
	_chat_input.size = Vector2(560, 30)
	_chat_input.add_theme_font_size_override("font_size", 15)
	_chat_input.text_submitted.connect(_on_chat_submitted)
	layer.add_child(_chat_input)

	_sheet_panel = Label.new()  # F24: character sheet, toggled with V (hidden until then)
	_sheet_panel.position = Vector2(18, 90)
	_sheet_panel.text = "Character Sheet (press V)…"
	_sheet_panel.add_theme_font_size_override("font_size", 14)
	_sheet_panel.modulate = Color(0.07, 0.09, 0.12)
	_sheet_panel.visible = false
	layer.add_child(_sheet_panel)

	_build_shop_panel(layer)     # Wave F economy: real shop overlay (B), replaces the console dump
	_build_toast(layer)          # transient credit/loot/buy/sell/force-awaken feedback
	_build_death_overlay(layer)  # DIV-0006: full-screen "you were killed" card

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
func _update_condition(wound: String, penalty: int = 0) -> void:
	var label := _condition_pretty(wound)
	if penalty > 0:
		label += " (-%dD to actions)" % penalty  # F46: the WEG wound penalty — why a wounded character fights worse
	if _condition_label != null:
		_condition_label.text = "Condition: %s" % label
		_condition_label.modulate = _condition_color(wound)
	if wound != _last_condition:
		_last_condition = wound
		print("[condition] you=%s penalty=-%dD" % [wound, penalty])

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
		"protected_zone": "You can't attack players here — this zone is protected. (Open PvP is lawless-only.)",
		"protected_target": "That player is in a protected zone.",
		"different_zone": "That player isn't in your zone.",
	}
	var msg := String(messages.get(reason, "PvP fire refused (%s)." % reason))
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

func _on_heal_replied(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		print("[firstaid] healed peer %d: %s -> %s" % [int(result.get("target_id", 0)), String(result.get("from", "")), String(result.get("to", ""))])
		_set_status("First Aid: %s -> %s" % [String(result.get("from", "")), String(result.get("to", ""))])
	else:
		print("[firstaid] heal failed (%s)" % String(result.get("reason", "")))
		_set_status("First Aid failed (%s)." % String(result.get("reason", "")))

func _on_sheet_updated(summary: Dictionary) -> void:
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
	lines.append("Credits: %d" % int(summary.get("credits", 0)))
	var w: Dictionary = summary.get("cp_wallet", {})
	lines.append("CP wallet: %d gameplay · %d prestige" % [int(w.get("gameplay_cp", 0)), int(w.get("rp_cp", 0))])
	lines.append("(press V to hide)")
	if _sheet_panel != null:
		_sheet_panel.text = "\n".join(lines)
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
		"who":
			_show_who()  # client-local roster of same-zone players (from the snapshot)
		"help":
			var help := ChatModel.command_help()
			# F54: /help also lists the KEYBINDS — none of these (H heal, K raise, X/Z/G defense,
			# T travel, V sheet) are otherwise discoverable, so a new player can't find them.
			var keys := "Keys: WASD move · Space jump · LMB fire · RMB aim · X cover · Z dodge · G full-dodge · C CP · F Force Point · H heal ally · K raise Blaster · V sheet · T travel · B shop · Enter chat"
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
