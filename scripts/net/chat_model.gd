extends RefCounted
## Pure chat / emote validation + normalization model (E25) — the first social/RP
## channel on the wire. No nodes, sockets, or RNG; the server's submit_chat RPC drives
## it and chat_model_smoke tests it. Strips control characters, clamps length, and
## whitelists the channel so untrusted client text can be safely broadcast.

const CHANNELS := ["say", "emote", "ooc", "org"]
const MAX_LENGTH := 256

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
