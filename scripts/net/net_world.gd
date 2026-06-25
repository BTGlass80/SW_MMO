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
		Net.start_server()
		return

	_builder = WorldBuilder.new()
	_builder.build_lighting(self)
	_builder.build_ground(self)
	_builder.build_settlement(self)
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
	_start_wound = _arg_value("--start-wound")  # headless DIV-0012: new char starts wounded
	_heal_other = args.has("--heal-other")  # headless DIV-0013: First-Aid the first other player once
	_travel = _arg_value("--travel")  # headless DIV-0014: travel to this zone_id once
	_say = _arg_value("--say")  # headless: a free-text chat line through parse_input (F22)

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
	if (_autofire or _autodefend) and Net.connected:
		_autofire_accum += delta
		if _autofire_accum >= 0.4:
			_autofire_accum = 0.0
			if _autodefend:
				Net.send_fire_intent({"full_dodge": true})  # F51: headless defensive-stance loop
			else:
				Net.send_fire_intent({"aim": 3, "cover": _fire_cover, "cp": _fire_cp, "fp": _fire_fp, "dodge": _fire_dodge})
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
	# headless net-movement readout: log the server-authoritative position while autowalking
	if _autowalk and Net.connected:
		_walk_accum += delta
		if _walk_accum >= 1.5:
			_walk_accum = 0.0
			var p := _my_position()
			print("[pos] x=%.2f y=%.2f z=%.2f" % [p.x, p.y, p.z])

# --- input / camera (client only) ---
func _send_local_input() -> void:
	if _chat_input != null and _chat_input.has_focus():
		Net.set_local_input(Vector2.ZERO, _yaw, false)  # typing in chat: don't move/jump
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
	controls.text = "WASD move · mouse look · RMB aim · C cycle CP · F Force Point · LMB fire · H First Aid · T travel · V sheet · Enter chat · Esc release"
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
		line = "Org: %s · %s · %d cr · %d/%d claim(s) here" % [_org_pretty(org_id), _rank_pretty(rank, territory), treasury, mine, total]
	if _org_label != null:
		_org_label.text = line
	if line != _last_org_line:
		_last_org_line = line
		if line != "":
			print("[org] %s rank=%d treasury=%d claims_here=%d/%d" % [org_id, rank, int(territory.get("treasury", 0)), mine, total])

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
		"who":
			_show_who()  # client-local roster of same-zone players (from the snapshot)
		"help":
			var help := ChatModel.command_help()
			_set_status(help)
			print("[help] %s" % help)

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
