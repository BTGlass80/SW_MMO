extends RefCounted
## Pure NPC dialogue-selection model. Deterministic, NO RNG, non-mutating, no nodes/sockets.
## Given a named-NPC record (as loaded from data/npcs_clone_wars.json) plus a light talk context,
## decides which stub line to show. This is pure text selection over the NPC's dialogue_lines[] --
## NOT a WEG/MUSH mechanic, so it needs no divergence-ledger row. The SERVER owns the live talk_count;
## this is the headlessly-testable logic that maps (npc, talk_count) -> a line, robustly.
##
## NPC record fields consumed (all optional / defensively read): id, name, role, faction_axis,
## dialogue_lines (Array[String]). Missing/malformed fields never crash -- they degrade to a
## role-based default line or a neutral flavor prefix.

# {id -> npc} map from the parsed data file's "npcs" array. Skips entries without a string id.
static func npcs_from_data(data: Dictionary) -> Dictionary:
	var out := {}
	for n in data.get("npcs", []):
		if typeof(n) == TYPE_DICTIONARY and String((n as Dictionary).get("id", "")) != "":
			out[String((n as Dictionary)["id"])] = n
	return out

# The NPC's dialogue_lines as a clean Array[String] (empty if missing/malformed).
static func lines_of(npc: Dictionary) -> Array:
	var out: Array = []
	var raw: Variant = npc.get("dialogue_lines", [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for l in raw:
		out.append(String(l))
	return out

# A role/name-based fallback used when an NPC ships no dialogue_lines. Always non-empty.
static func default_line(npc: Dictionary) -> String:
	var role := String(npc.get("role", "")).strip_edges()
	var name := String(npc.get("name", "")).strip_edges()
	if name != "" and role != "":
		return "%s, %s, gives you a wordless nod." % [name, role]
	if name != "":
		return "%s gives you a wordless nod." % name
	if role != "":
		return "The %s gives you a wordless nod." % role
	return "They have nothing to say just now."

# The opening/first line. Falls back to a non-empty role-based default when there are no lines.
static func greeting(npc: Dictionary) -> String:
	var lines := lines_of(npc)
	if lines.is_empty():
		return default_line(npc)
	return String(lines[0])

# Deterministically rotate through dialogue_lines by talk_count so repeat-talking cycles the stubs
# (0,1,2,0,1,2,...) and never crashes on an empty list. Negative talk_count wraps via posmod.
static func next_line(npc: Dictionary, talk_count: int) -> String:
	var lines := lines_of(npc)
	if lines.is_empty():
		return default_line(npc)
	return String(lines[posmod(talk_count, lines.size())])

# Symmetric opposition map between faction axes (Clone Wars, 20 BBY). Independent /
# bounty_hunters_guild stay neutral to everyone -- hired talent and locals pick no side.
const OPPOSED := {
	"republic": ["cis", "hutt"],
	"cis": ["republic"],
	"hutt": ["republic"],
	"independent": [],
	"bounty_hunters_guild": [],
}

# "aligned" | "opposed" | "neutral" -- how the player's axis relates to the NPC's. Empty/unknown
# axes are neutral. Deterministic and case-insensitive.
static func faction_relation(npc_axis: String, player_axis: String) -> String:
	var a := npc_axis.strip_edges().to_lower()
	var p := player_axis.strip_edges().to_lower()
	if a == "" or p == "":
		return "neutral"
	if a == p:
		return "aligned"
	if (OPPOSED.get(a, []) as Array).has(p):
		return "opposed"
	return "neutral"

# Optional pure-text prefix (friendlier when the player shares the NPC's axis, cooler when opposed,
# "" when neutral). Deterministic. Prepend it to greeting()/next_line() as desired.
static func faction_flavor(npc: Dictionary, player_faction_axis: String) -> String:
	match faction_relation(String(npc.get("faction_axis", "")), player_faction_axis):
		"aligned":
			return "(with a flicker of recognition) "
		"opposed":
			return "(guarded, sizing up your allegiance) "
	return ""

# Convenience: the next line with the faction-flavor prefix applied. Deterministic.
static func line_with_flavor(npc: Dictionary, talk_count: int, player_faction_axis: String) -> String:
	return faction_flavor(npc, player_faction_axis) + next_line(npc, talk_count)
