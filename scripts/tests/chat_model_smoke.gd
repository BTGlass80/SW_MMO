extends SceneTree
## Headless smoke for the pure chat/emote model (E25). Verifies channel whitelisting,
## control-character stripping, length clamp, empty rejection, and line formatting.

const ChatModel := preload("res://scripts/net/chat_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# Valid say: ok + message shape preserved.
	var r: Dictionary = ChatModel.normalize("say", "Hello there", "Obi-Wan")
	_assert_true(bool(r["ok"]), "valid say accepted")
	var msg: Dictionary = r["message"]
	_assert_equal(String(msg["channel"]), "say", "channel preserved")
	_assert_equal(String(msg["speaker"]), "Obi-Wan", "speaker preserved")
	_assert_equal(String(msg["text"]), "Hello there", "text preserved")

	# emote + ooc + org are whitelisted; an unknown channel is rejected.
	_assert_true(bool(ChatModel.normalize("emote", "waves", "X")["ok"]), "emote accepted")
	_assert_true(bool(ChatModel.normalize("ooc", "brb", "X")["ok"]), "ooc accepted")
	_assert_true(bool(ChatModel.normalize("org", "regroup at bay 94", "X")["ok"]), "org accepted")
	var bc: Dictionary = ChatModel.normalize("shout", "hi", "X")
	_assert_true(not bool(bc["ok"]) and String(bc["reason"]) == "bad_channel", "non-whitelisted channel rejected")

	# Whitespace/control-only text is rejected as empty.
	var em: Dictionary = ChatModel.normalize("say", "   \t\n  ", "X")
	_assert_true(not bool(em["ok"]) and String(em["reason"]) == "empty", "control/whitespace-only rejected as empty")

	# Control-character stripping + edge trim.
	_assert_equal(ChatModel.sanitize("hi\nthere\t!"), "hithere!", "newline/tab stripped")
	_assert_equal(ChatModel.sanitize("a" + char(127) + "b"), "ab", "DEL stripped")
	_assert_equal(ChatModel.sanitize("  trimmed  "), "trimmed", "edges trimmed")
	_assert_equal(String((ChatModel.normalize("say", "  hi\nthere  ", "X")["message"] as Dictionary)["text"]), "hithere", "normalize sanitizes the text")

	# Length clamp to MAX_LENGTH.
	var long_text := ""
	for i in range(300):
		long_text += "a"
	var lc: Dictionary = ChatModel.normalize("say", long_text, "X")
	_assert_equal(String((lc["message"] as Dictionary)["text"]).length(), ChatModel.MAX_LENGTH, "text clamped to MAX_LENGTH")

	# Line formatting per channel.
	_assert_equal(ChatModel.format_line({"channel": "say", "speaker": "Mara", "text": "hey"}), "Mara: hey", "say format")
	_assert_equal(ChatModel.format_line({"channel": "emote", "speaker": "Mara", "text": "grins"}), "* Mara grins", "emote format")
	_assert_equal(ChatModel.format_line({"channel": "ooc", "speaker": "Mara", "text": "gtg"}), "[OOC] Mara: gtg", "ooc format")
	_assert_equal(ChatModel.format_line({"channel": "org", "speaker": "Mara", "text": "regroup"}), "[Org] Mara: regroup", "org format")

	# Free-text input parsing (GUI LineEdit / --say): slash-commands + aliases + plain text.
	_assert_equal(_parsed("/ooc brb"), ["ooc", "brb"], "/ooc -> ooc channel")
	_assert_equal(_parsed("/g regroup at bay 94"), ["org", "regroup at bay 94"], "/g alias -> org")
	_assert_equal(_parsed("/me waves"), ["emote", "waves"], "/me alias -> emote")
	_assert_equal(_parsed("hello there"), ["say", "hello there"], "plain text -> say")
	_assert_equal(_parsed("   "), ["", ""], "blank input -> empty (nothing sent)")
	_assert_equal(_parsed("/foo bar"), ["say", "/foo bar"], "unknown command -> say verbatim")
	_assert_equal(_parsed("/ooc"), ["ooc", ""], "command with no text -> channel + empty text")

	# Command-bar parsing (GUI game commands, distinct from chat channels).
	_assert_equal(_cmd("/raise dodge"), ["raise", "dodge"], "/raise <skill> -> raise command")
	_assert_equal(_cmd("/travel tatooine.dune_sea"), ["travel", "tatooine.dune_sea"], "/travel <zone> -> travel command")
	_assert_equal(_cmd("/heal"), ["heal", ""], "/heal -> heal command (no arg)")
	_assert_equal(_cmd("/say hello"), ["", ""], "a chat channel is NOT a game command (falls through to chat)")
	_assert_equal(_cmd("plain text"), ["", ""], "plain text is not a command")
	_assert_equal(_cmd("/bogus x"), ["", ""], "an unknown slash word is not a game command")

	if _failures.is_empty():
		print("chat_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _parsed(raw: String) -> Array:
	var r: Dictionary = ChatModel.parse_input(raw)
	return [String(r.get("channel", "")), String(r.get("text", ""))]

func _cmd(raw: String) -> Array:
	var r: Dictionary = ChatModel.parse_command(raw)
	return [String(r.get("cmd", "")), String(r.get("arg", ""))]

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
