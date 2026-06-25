extends RefCounted
## Pure ambient-NPC sim (E27). Deterministically maintains a small per-zone NPC roster
## keyed to the zone's alert level, advanced by the slow Director tick. Each NPC has a
## position within the zone bounds and a lifespan; expired NPCs despawn and fresh ones
## spawn to keep the population near target. Hash-seeded (no RNG object) so it replays
## identically like zone_state — the spawn/sim foundation beyond headline-only events.
##
## Pure / socket-free; the server folds the roster into the per-peer snapshot as npcs[].

# Target ambient population by alert level (owner-tunable).
const POP_BY_ALERT := {
	"lockdown": 5,      # heavy clone patrols
	"high_alert": 4,
	"underworld": 5,    # thugs / smugglers prowl
	"unrest": 4,
	"standard": 3,
	"lax": 2,
}
const DEFAULT_POP := 3
const NPC_LIFESPAN := 6   # Director ticks an ambient NPC persists before despawn

# NPC archetypes by alert (flavor; Clone Wars Mos Eisley; owner-tunable).
const KINDS_BY_ALERT := {
	"lockdown": ["clone_trooper", "checkpoint_guard"],
	"high_alert": ["clone_trooper", "spacer"],
	"underworld": ["hutt_thug", "smuggler", "spacer"],
	"unrest": ["cis_agitator", "spacer"],
	"standard": ["spacer", "jawa", "moisture_farmer"],
	"lax": ["spacer", "jawa"],
}
const DEFAULT_KINDS := ["spacer", "jawa"]

# The default zone bounds (meters) NPCs spawn within when the caller passes none.
const DEFAULT_BOUNDS := {"min_x": -28.0, "max_x": 28.0, "min_z": -28.0, "max_z": 28.0, "y": 1.2}

static func target_population(alert: String) -> int:
	return int(POP_BY_ALERT.get(alert, DEFAULT_POP))

static func kinds_for(alert: String) -> Array:
	return KINDS_BY_ALERT.get(alert, DEFAULT_KINDS)

# Deterministic position within bounds {min_x,max_x,min_z,max_z,y} from an integer seed.
static func position_for(seed_val: int, bounds: Dictionary) -> Dictionary:
	var min_x := float(bounds.get("min_x", DEFAULT_BOUNDS["min_x"]))
	var max_x := float(bounds.get("max_x", DEFAULT_BOUNDS["max_x"]))
	var min_z := float(bounds.get("min_z", DEFAULT_BOUNDS["min_z"]))
	var max_z := float(bounds.get("max_z", DEFAULT_BOUNDS["max_z"]))
	var hx := absi(hash("x:%d" % seed_val)) % 1000
	var hz := absi(hash("z:%d" % seed_val)) % 1000
	return {
		"x": min_x + (max_x - min_x) * (float(hx) / 1000.0),
		"y": float(bounds.get("y", DEFAULT_BOUNDS["y"])),
		"z": min_z + (max_z - min_z) * (float(hz) / 1000.0),
	}

# Advance one Director tick for a zone. `roster` is the zone's current Array of NPC
# dicts. Returns the NEW roster: NPCs whose expires_at_tick <= tick are despawned, then
# fresh ones spawn (deterministically, hash-seeded by zone+tick+index) up to
# target_population(alert). Fully deterministic — the same inputs always yield the same
# roster.
static func advance(roster: Array, zone_id: String, alert: String, tick: int, bounds: Dictionary = {}) -> Array:
	var box: Dictionary = bounds if not bounds.is_empty() else DEFAULT_BOUNDS
	# 1. Despawn expired NPCs.
	var alive: Array = []
	for npc in roster:
		if int((npc as Dictionary).get("expires_at_tick", 0)) > tick:
			alive.append(npc)
	# 2. Spawn fresh NPCs up to the alert-keyed target.
	var target := target_population(alert)
	var kinds: Array = kinds_for(alert)
	var idx := 0
	while alive.size() < target:
		var seed_val := absi(hash("%s:%d:%d" % [zone_id, tick, idx]))
		alive.append({
			"id": "npc_%s_%d_%d" % [zone_id, tick, idx],
			"kind": String(kinds[seed_val % kinds.size()]),
			"pos": position_for(seed_val, box),
			"spawned_at_tick": tick,
			"expires_at_tick": tick + NPC_LIFESPAN,
		})
		idx += 1
	return alive
