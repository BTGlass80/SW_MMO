class_name AdminCommands
extends RefCounted
## Minimal admin recovery commands (RWD Priority 9)
## Provides operator escape hatches for stuck states and economy recovery.

static func process_command(cmd: String, args: Array, sender_id: String, net: Variant) -> String:
	match cmd:
		"list":
			var out = "Online Players:\n"
			var players = net.admin_get_online_players()
			for peer in players.keys():
				var char_id = players[peer]
				var zone = net.admin_get_peer_zone(peer)
				out += "- %s (Peer %d) in zone: %s\n" % [char_id, peer, zone]
			return out
			
		"inspect":
			if args.size() < 1: return "Usage: /admin inspect <char_id>"
			var target = args[0]
			var record = net.admin_load_record(target)
			if record.is_empty(): return "Character not found: %s" % target
			var sheet = record.get("sheet", {})
			return "Inspect %s:\nCredits: %s\nWounds: %s (%s)\nShips: %s" % [
				target, 
				str(sheet.get("credits", 0)), 
				str(sheet.get("wounds", 0)), 
				str(sheet.get("wound_state", "healthy")),
				str(sheet.get("ships", []).size())
			]
			
		"grant":
			if args.size() < 3: return "Usage: /admin grant <char_id> <credits|cp|item> <amount|item_id>"
			var target = args[0]
			var type = args[1]
			var val = args[2]
			var record = net.admin_load_record(target)
			if record.is_empty(): return "Character not found: %s" % target
			
			var sheet = record.get("sheet", {})
			if type == "credits":
				var amount = int(val)
				sheet["credits"] = int(sheet.get("credits", 0)) + amount
				record["sheet"] = sheet
				net.admin_save_record(target, record)
				net.admin_log_telemetry("admin_grant", {"ts": Time.get_unix_time_from_system(), "character_id": target, "type": "credits", "amount": amount})
				var target_peer = net.admin_get_peer_by_character(target)
				if target_peer > 0:
					net.admin_push_sheet(target_peer, record)
				return "Granted %d credits to %s" % [amount, target]
			elif type == "cp":
				var amount = int(val)
				sheet["cp"] = int(sheet.get("cp", 0)) + amount
				record["sheet"] = sheet
				net.admin_save_record(target, record)
				var target_peer = net.admin_get_peer_by_character(target)
				if target_peer > 0:
					net.admin_push_sheet(target_peer, record)
				return "Granted %d CP to %s" % [amount, target]
			elif type == "item":
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				var item = {
					"instance_id": str(rng.randi()),
					"template_id": val,
					"quantity": 1
				}
				var inv: Array = sheet.get("inventory", [])
				inv.append(item)
				sheet["inventory"] = inv
				record["sheet"] = sheet
				net.admin_save_record(target, record)
				net.admin_log_telemetry("admin_grant", {"ts": Time.get_unix_time_from_system(), "character_id": target, "type": "item", "item_id": val})
				var target_peer = net.admin_get_peer_by_character(target)
				if target_peer > 0:
					net.admin_push_sheet(target_peer, record)
				return "Granted item %s to %s" % [val, target]
			else:
				return "Unknown grant type: %s" % type
				
		"unstuck":
			if args.size() < 1: return "Usage: /admin unstuck <char_id>"
			var target = args[0]
			var record = net.admin_load_record(target)
			if record.is_empty(): return "Character not found: %s" % target
			var target_peer = net.admin_get_peer_by_character(target)
			if target_peer > 0:
				net.admin_set_peer_zone(target_peer, "mos_eisley")
			return "Unstuck %s to Mos Eisley" % target
			
		"kick":
			if args.size() < 1: return "Usage: /admin kick <char_id>"
			var target = args[0]
			var target_peer = net.admin_get_peer_by_character(target)
			if target_peer > 0:
				net.admin_kick_peer(target_peer)
				return "Kicked %s" % target
			return "Peer not found for %s" % target
			
		"clear_listing":
			if args.size() < 1: return "Usage: /admin clear_listing <listing_id>"
			var listing_id = args[0]
			if net.admin_clear_bazaar_listing(listing_id):
				return "Cleared bazaar listing %s" % listing_id
			return "Listing not found: %s" % listing_id
			
		"clear_space":
			if args.size() < 1: return "Usage: /admin clear_space <char_id>"
			var target = args[0]
			var record = net.admin_load_record(target)
			if record.is_empty(): return "Character not found: %s" % target
			var sheet = record.get("sheet", {})
			var space_state = sheet.get("space_state", {})
			space_state["in_space"] = false
			space_state["ship_cargo"] = []
			sheet["space_state"] = space_state
			record["sheet"] = sheet
			net.admin_save_record(target, record)
			
			var target_peer = net.admin_get_peer_by_character(target)
			if target_peer > 0:
				net.admin_set_peer_zone(target_peer, "mos_eisley")
				
			return "Cleared space state for %s and moved to ground." % target
			
		"export_telemetry":
			net.admin_log_telemetry("admin_export", {"ts": Time.get_unix_time_from_system(), "character_id": sender_id})
			return "Telemetry flushed/exported."
			
	return "Unknown admin command: %s" % cmd
