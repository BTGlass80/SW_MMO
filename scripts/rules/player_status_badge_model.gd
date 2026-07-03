extends RefCounted
## Pure, deterministic status-badge model (no nodes, no RNG, no sockets).
##
## Maps a player's live status — WEG wound tier + creature venom (poison rounds) +
## restraint (held) — to a single PRIORITIZED status badge for the nameplate/HUD, plus a
## combined readout when several statuses stack (e.g. a wounded AND poisoned AND held
## player). The server owns this truth and ships it in the snapshot; this model only
## decides how to READ it out, so it is headlessly unit-testable and shares the wound
## vocabulary with net_world._condition_pretty.
##
## Color choices stay in the CLIENT: this model returns stable string `color_key`s that
## the presentation layer maps to Colors (net_world._status_color). That keeps the pure
## logic engine-free and lets the smoke assert on names, not Color literals.
##
## Priority (highest wins the top badge):
##   downed (incapacitated / mortally_wounded / dead)  >
##   restrained ("Held")                                >
##   poisoned  ("Poisoned (n)" / short "☠ n")           >
##   hurt      (stunned / wounded / wounded_twice)      >
##   healthy   (nothing active -> active:false, no badge)

const PRIORITY_DOWNED := 4
const PRIORITY_RESTRAINED := 3
const PRIORITY_POISONED := 2
const PRIORITY_HURT := 1
const PRIORITY_HEALTHY := 0

# Wound tiers that mean "can't act" — a downed player (medic-relevant, DIV-0019).
const DOWNED_STATES := ["incapacitated", "mortally_wounded", "dead"]
# Wound tiers that hurt but can still act.
const HURT_STATES := ["stunned", "wounded", "wounded_twice"]

# Primary entry point. Given a player's live status, return the prioritized badge:
#   {
#     active:    bool,      # false only when healthy AND un-poisoned AND un-held
#     priority:  int,       # the winning status' priority (see constants above)
#     text:      String,    # the TOP badge's full label, e.g. "Poisoned (3)"
#     short:     String,    # the TOP badge's compact tag, e.g. "☠ 3"
#     color_key: String,    # the TOP badge's color key (client maps to a Color)
#     combined:  String,    # ALL active statuses joined priority-desc, e.g.
#                           #   "Incapacitated · Held · Poisoned (3)"
#     parts:     Array,     # each active status as {key,text,short,color_key,priority}
#   }
static func badge_for(wound_state: String, poison_rounds_left: int, restrained: bool) -> Dictionary:
	var parts := _parts(wound_state, poison_rounds_left, restrained)
	if parts.is_empty():
		return {
			"active": false,
			"priority": PRIORITY_HEALTHY,
			"text": "",
			"short": "",
			"color_key": "healthy",
			"combined": "",
			"parts": [],
		}
	var top: Dictionary = parts[0]
	var texts: Array[String] = []
	for part in parts:
		texts.append(String((part as Dictionary)["text"]))
	return {
		"active": true,
		"priority": int(top["priority"]),
		"text": String(top["text"]),
		"short": String(top["short"]),
		"color_key": String(top["color_key"]),
		"combined": " · ".join(texts),
		"parts": parts,
	}

# Convenience: read the badge straight off a snapshot entry (per-player nameplate entry
# OR the "you" block). Null-safe — the status fields are absent when inactive, so this
# uses .get() defaults. Accepts either "wound" (snapshot key) or "wound_state".
static func from_entry(entry: Dictionary) -> Dictionary:
	var wound := String(entry.get("wound", entry.get("wound_state", "healthy")))
	return badge_for(
		wound,
		int(entry.get("status_poison_rounds_left", 0)),
		bool(entry.get("status_restrained", false)))

# The NON-wound status suffix for the local Condition HUD (the wound + its -ND penalty are
# already shown there, so this adds only Held / Poisoned). "" when neither is active.
# Ordered by priority: restrained ("Held") before poisoned ("Poisoned (n)").
static func extra_status_text(poison_rounds_left: int, restrained: bool) -> String:
	var out: Array[String] = []
	if restrained:
		out.append("Held")
	if poison_rounds_left > 0:
		out.append("Poisoned (%d)" % poison_rounds_left)
	return " · ".join(out)

# --- internals ---

static func _parts(wound_state: String, poison_rounds_left: int, restrained: bool) -> Array:
	var parts: Array = []
	var wound_norm := wound_state.strip_edges().to_lower()
	var wound_class := _wound_class(wound_norm)
	if wound_class == "downed":
		parts.append({
			"key": "downed",
			"text": _wound_pretty(wound_norm),
			"short": "DOWN",
			"color_key": _wound_color_key(wound_norm),
			"priority": PRIORITY_DOWNED,
		})
	if restrained:
		parts.append({
			"key": "restrained",
			"text": "Held",
			"short": "Held",
			"color_key": "restrained",
			"priority": PRIORITY_RESTRAINED,
		})
	if poison_rounds_left > 0:
		parts.append({
			"key": "poisoned",
			"text": "Poisoned (%d)" % poison_rounds_left,
			"short": "☠ %d" % poison_rounds_left,
			"color_key": "poisoned",
			"priority": PRIORITY_POISONED,
		})
	if wound_class == "hurt":
		parts.append({
			"key": "hurt",
			"text": _wound_pretty(wound_norm),
			"short": _hurt_short(wound_norm),
			"color_key": _wound_color_key(wound_norm),
			"priority": PRIORITY_HURT,
		})
	# Appended in priority order already; sort defensively so callers get a stable ranking.
	parts.sort_custom(func(a, b): return int((a as Dictionary)["priority"]) > int((b as Dictionary)["priority"]))
	return parts

# healthy | hurt | downed. Unknown non-healthy states fall to "downed" so they render in
# the same "serious" red the legacy nameplate used for anything past wounded_twice.
static func _wound_class(wound_norm: String) -> String:
	if wound_norm == "" or wound_norm == "healthy":
		return "healthy"
	if wound_norm in HURT_STATES:
		return "hurt"
	return "downed"

# Wound vocabulary — kept identical to net_world._condition_pretty.
static func _wound_pretty(wound_norm: String) -> String:
	match wound_norm:
		"healthy": return "Healthy"
		"stunned": return "Stunned"
		"wounded": return "Wounded"
		"wounded_twice": return "Wounded Twice"
		"incapacitated": return "Incapacitated"
		"mortally_wounded": return "Mortally Wounded"
		"dead": return "Dead"
		_: return wound_norm

# Color keys chosen so the CLIENT map reproduces net_world._condition_color exactly for a
# lone wound: stunned -> yellow, wounded/wounded_twice -> orange, everything past that ->
# red ("downed").
static func _wound_color_key(wound_norm: String) -> String:
	match wound_norm:
		"stunned": return "stunned"
		"wounded", "wounded_twice": return "wounded"
		_: return "downed"

static func _hurt_short(wound_norm: String) -> String:
	match wound_norm:
		"stunned": return "Stun"
		"wounded": return "Wound"
		"wounded_twice": return "Wound2"
		_: return "Hurt"
