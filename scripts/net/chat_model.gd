extends RefCounted
## Pure chat / emote validation + normalization model (E25) — the first social/RP
## channel on the wire. No nodes, sockets, or RNG; the server's submit_chat RPC drives
## it and chat_model_smoke tests it. Strips control characters, clamps length, and
## whitelists the channel so untrusted client text can be safely broadcast.

const CHANNELS := ["say", "emote", "ooc", "org"]
const MAX_LENGTH := 256

# Slash-command -> channel map for free-text chat input (the GUI LineEdit + the headless
# --say affordance). Includes short aliases. Plain text (no leading "/") defaults to "say".
const COMMANDS := {
	"say": "say", "s": "say",
	"ooc": "ooc", "o": "ooc",
	"org": "org", "g": "org",
	"emote": "emote", "em": "emote", "me": "emote", "e": "emote",
}

## GUI game commands (distinct from chat channels) recognized by the command bar.
const GAME_COMMANDS := ["raise", "travel", "heal"]

## Recognize a GUI game command in a free-text line: "/raise dodge" -> {cmd:"raise",
## arg:"dodge"}; "/travel tatooine.dune_sea" -> {cmd:"travel", arg:"…"}; "/heal" ->
## {cmd:"heal", arg:""}. A chat channel ("/say", "/ooc", …) or any non-command line returns
## {cmd:"", arg:""} so the caller falls through to chat (parse_input). Command words never
## overlap the chat channels, so the two parsers compose cleanly.
static func parse_command(raw: String) -> Dictionary:
	var text := raw.strip_edges()
	if not text.begins_with("/"):
		return {"cmd": "", "arg": ""}
	var sp := text.find(" ")
	var cmd := text.substr(1).to_lower() if sp < 0 else text.substr(1, sp - 1).to_lower()
	var arg := "" if sp < 0 else text.substr(sp + 1).strip_edges()
	if GAME_COMMANDS.has(cmd):
		return {"cmd": cmd, "arg": arg}
	return {"cmd": "", "arg": ""}

## Parse a free-text chat line into {channel, text}. "/ooc hi" -> {ooc, "hi"}; "/g regroup"
## -> {org, "regroup"}; plain "hello" -> {say, "hello"}; an UNKNOWN "/cmd …" is kept verbatim
## as say (never silently dropped); blank input -> {channel:"", text:""} (caller sends nothing).
static func parse_input(raw: String) -> Dictionary:
	var text := raw.strip_edges()
	if text == "":
		return {"channel": "", "text": ""}
	if text.begins_with("/"):
		var sp := text.find(" ")
		var cmd := text.substr(1).to_lower() if sp < 0 else text.substr(1, sp - 1).to_lower()
		var rest := "" if sp < 0 else text.substr(sp + 1)
		if COMMANDS.has(cmd):
			return {"channel": String(COMMANDS[cmd]), "text": rest.strip_edges()}
		return {"channel": "say", "text": text}  # unknown command -> say it verbatim
	return {"channel": "say", "text": text}

## Remove control characters (code point < 32, e.g. newlines/tabs) and DEL (127),
## leaving a clean single line, then trim the ends. Keeps all printable text.
static func sanitize(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 32 and code != 127:
			out += text[i]
	return out.strip_edges()

## Validate + normalize a chat line for broadcast. Returns {ok, reason, message}.
## reasons: "bad_channel" (not in CHANNELS) / "empty" (nothing left after sanitize).
## message = {channel, speaker, text} with text sanitized + clamped to MAX_LENGTH.
static func normalize(channel: String, text: String, speaker: String) -> Dictionary:
	if not CHANNELS.has(channel):
		return {"ok": false, "reason": "bad_channel", "message": {}}
	var clean := sanitize(text)
	if clean.length() > MAX_LENGTH:
		clean = clean.substr(0, MAX_LENGTH)
	if clean == "":
		return {"ok": false, "reason": "empty", "message": {}}
	return {
		"ok": true,
		"reason": "",
		"message": {"channel": channel, "speaker": speaker, "text": clean},
	}

## Render a normalized message for a log/HUD line (say "Name: text", emote "* Name text",
## ooc "[OOC] Name: text", org "[Org] Name: text").
static func format_line(message: Dictionary) -> String:
	var channel := String(message.get("channel", "say"))
	var speaker := String(message.get("speaker", "Someone"))
	var text := String(message.get("text", ""))
	match channel:
		"emote":
			return "* %s %s" % [speaker, text]
		"ooc":
			return "[OOC] %s: %s" % [speaker, text]
		"org":
			return "[Org] %s: %s" % [speaker, text]
		_:
			return "%s: %s" % [speaker, text]
