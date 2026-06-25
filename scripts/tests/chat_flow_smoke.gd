extends SceneTree
## Regression guard for the server's submit_chat DELIVERY-SCOPE composition (E25/F2 zone
## chat + F20 org chat). network_manager is a Node autoload that is not headlessly
## instantiable, so — like claim_flow / auth_flow / heal_flow / zone_flow — this replicates
## its routing with the REAL chat_model and locks BOTH layers:
##   1. validation: chat_model.normalize whitelists the channel + rejects empty.
##   2. delivery scope: ooc -> ALL connected peers; org -> same-org members in ANY zone
##      (none if the sender has no org); say/emote -> same-ZONE peers only. The sender is
##      always among the recipients (the local echo).

const ChatModel := preload("res://scripts/net/chat_model.gd")

var _failures: Array[String] = []

# Faithful mirror of submit_chat's recipient selection (assumes the message normalized OK).
# `st` holds peers (all connected), zones (peer->zone), orgs (peer->org_id).
func _recipients(st: Dictionary, sender: int, channel: String) -> Array:
	if channel == "ooc":
		return (st["peers"] as Array).duplicate()  # galaxy-wide
	if channel == "org":
		var my_org := String(st["orgs"].get(sender, ""))
		if my_org == "":
			return []  # no org -> not delivered
		var out: Array = []
		for pid in st["peers"]:
			if String(st["orgs"].get(pid, "")) == my_org:
				out.append(pid)
		return out
	# say / emote -> same zone as the speaker
	var my_zone := String(st["zones"].get(sender, "default"))
	var zout: Array = []
	for pid in st["peers"]:
		if String(st["zones"].get(pid, "default")) == my_zone:
			zout.append(pid)
	return zout

func _init() -> void:
	# --- 1. validation (real chat_model) ---
	for ch in ["say", "emote", "ooc", "org"]:
		_assert_true(bool(ChatModel.normalize(ch, "hello", "X")["ok"]), "%s is a valid channel" % ch)
	_assert_equal(String(ChatModel.normalize("shout", "hi", "X")["reason"]), "bad_channel", "unknown channel -> bad_channel")
	_assert_equal(String(ChatModel.normalize("org", "   ", "X")["reason"]), "empty", "blank org text -> empty")

	# --- 2. delivery scope ---
	# Roster: peers 1,2 = hutt org in spaceport; 3 = hutt org in dune_sea; 4 = no org in
	# spaceport; 5 = republic org in spaceport.
	var st := {
		"peers": [1, 2, 3, 4, 5],
		"zones": {1: "spaceport", 2: "spaceport", 3: "dune_sea", 4: "spaceport", 5: "spaceport"},
		"orgs": {1: "hutt", 2: "hutt", 3: "hutt", 4: "", 5: "republic"},
	}

	# ooc from peer 1 -> everyone.
	_assert_equal(_recipients(st, 1, "ooc").size(), 5, "ooc reaches all 5 peers")

	# say from peer 1 (spaceport) -> the spaceport peers only (1,2,4,5), NOT the dune_sea peer 3.
	var say_rcpt := _recipients(st, 1, "say")
	_assert_true(_has(say_rcpt, 1) and _has(say_rcpt, 2) and _has(say_rcpt, 4) and _has(say_rcpt, 5), "say reaches same-zone peers (incl. sender)")
	_assert_true(not _has(say_rcpt, 3), "say does NOT reach a different-zone peer")
	_assert_equal(say_rcpt.size(), 4, "say recipient count = the 4 spaceport peers")

	# org from peer 1 (hutt) -> the hutt members in ANY zone (1,2,3), NOT no-org 4 or republic 5.
	var org_rcpt := _recipients(st, 1, "org")
	_assert_true(_has(org_rcpt, 1) and _has(org_rcpt, 2) and _has(org_rcpt, 3), "org reaches same-org members incl. cross-zone (peer 3 in dune_sea)")
	_assert_true(not _has(org_rcpt, 4) and not _has(org_rcpt, 5), "org excludes no-org + other-org peers")
	_assert_equal(org_rcpt.size(), 3, "org recipient count = the 3 hutt members")

	# org from the no-org peer 4 -> nobody (not delivered).
	_assert_equal(_recipients(st, 4, "org").size(), 0, "a no-org sender's org chat is not delivered")

	# emote scopes like say (same zone).
	_assert_equal(_recipients(st, 3, "emote").size(), 1, "emote from the lone dune_sea peer reaches only itself")

	if _failures.is_empty():
		print("chat_flow_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _has(arr: Array, v: int) -> bool:
	return arr.has(v)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
