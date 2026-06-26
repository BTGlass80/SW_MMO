extends RefCounted
## Pure, server-authoritative world-sim zone director (M2.0 scaffold).
##
## Tracks per-zone faction influence (republic/cis/hutt/independent, 0-100, NOT
## zero-sum), a DERIVED alert level, and a DERIVED effective security tier, advanced
## by a SLOW deterministic Director tick (default ~30s, wholly separate from the
## 20 Hz movement tick). No LLM — the optional Director "flavor" layer is an OPEN
## OWNER DECISION and is intentionally left off here; everything below is pure and
## deterministic. Shapes follow data/schemas/{faction_zone_state,security_zone}
## .schema.json; thresholds per docs/WORLD_SIM_DESIGN.md §2.3 / §3.2 (owner-tunable).
##
## Pure/socket-free so it is headlessly unit-testable.

const SCHEMA_VERSION := 1
const FACTIONS := ["republic", "cis", "hutt", "independent"]
const TIERS := ["secured", "contested", "lawless"]  # index 0 = safest

# Alert-level thresholds (WORLD_SIM_DESIGN §2.3). Republic = authority axis.
const LOCKDOWN_REPUBLIC := 70
const HIGH_ALERT_REPUBLIC := 50
const UNDERWORLD_HUTT := 70
const UNREST_CIS := 40
const LAX_MAX_INFLUENCE := 25

# Security overlay rules (security_zone.schema.json defaults).
const HUTT_SURGE_DOWNGRADE_AT := 80

# World events: the Director fires one at a time per zone, DETERMINISTICALLY (no LLM),
# from this fixed 12-event menu (faction_zone_state.schema.json), recast Clone Wars.
const EVENT_CHANCE := 30    # % chance per slow tick to fire when no event is active
const EVENT_DURATION := 4   # slow ticks an event lasts
const EVENT_HEADLINES := {
	"republic_crackdown": "Clone troopers lock down the district — papers out, no exceptions.",
	"republic_checkpoint": "Republic checkpoints throttle traffic through the spaceport.",
	"bounty_surge": "The Guild posts a fresh slate of bounties on local troublemakers.",
	"merchant_arrival": "A spice-laden caravan rolls in; the market swells with traders.",
	"sandstorm": "A wall of sand rolls off the Dune Sea, scouring the streets.",
	"cantina_brawl": "A blaster brawl erupts in the cantina; the band keeps playing.",
	"distress_signal": "A garbled distress signal pings from a downed freighter nearby.",
	"pirate_surge": "Pirate raiders prowl the approach lanes, hunting easy cargo.",
	"hutt_auction": "A Hutt kajidic opens a back-room auction for the discerning buyer.",
	"krayt_sighting": "Spacers swap nervous tales of a krayt dragon stalking the wastes.",
	"cis_propaganda": "Separatist sympathizers paper the walls with CIS broadsheets.",
	"trade_boom": "Credits flow freely — a trade boom lifts every vendor on the row.",
}

# Mechanical effects of an active event (E13). Bounded (-2..+2), owner-tunable signed
# modifiers OTHER systems read: smuggling success, vendor pricing/stock, creature
# spawns, NPC perception/patrol density. 0 = neutral. Surfaced in zone_summary
# ["effects"]; events were headline-only before this.
const NEUTRAL_EFFECTS := {"smuggling": 0, "vendor": 0, "spawn": 0, "perception": 0}
const EVENT_EFFECTS := {
	"republic_crackdown": {"smuggling": -2, "vendor": -1, "spawn": 1, "perception": 2},
	"republic_checkpoint": {"smuggling": -1, "vendor": 0, "spawn": 0, "perception": 1},
	"bounty_surge": {"smuggling": 0, "vendor": 0, "spawn": 2, "perception": 1},
	"merchant_arrival": {"smuggling": 1, "vendor": 2, "spawn": 1, "perception": 0},
	"sandstorm": {"smuggling": 1, "vendor": -1, "spawn": -2, "perception": -2},
	"cantina_brawl": {"smuggling": 0, "vendor": 0, "spawn": 1, "perception": -1},
	"distress_signal": {"smuggling": 0, "vendor": 0, "spawn": 1, "perception": 0},
	"pirate_surge": {"smuggling": 2, "vendor": -1, "spawn": 2, "perception": -1},
	"hutt_auction": {"smuggling": 2, "vendor": 1, "spawn": 1, "perception": -1},
	"krayt_sighting": {"smuggling": 0, "vendor": 0, "spawn": 1, "perception": 0},
	"cis_propaganda": {"smuggling": 1, "vendor": 0, "spawn": 0, "perception": -1},
	"trade_boom": {"smuggling": 1, "vendor": 2, "spawn": 1, "perception": 0},
}

# The documented event->influence causal loop (E13): an active event nudges its
# faction's influence +1 per slow tick, but ONLY up to a FOOTHOLD cap one step below
# the lockdown/underworld threshold (70). Events build presence; a true lockdown /
# underworld / Hutt-surge stays player- and territory-driven (and transient) — so a
# surge already above the cap is left to decay normally. Clamped, deterministic.
const EVENT_INFLUENCE_NUDGE := {
	"republic_crackdown": "republic",
	"republic_checkpoint": "republic",
	"cis_propaganda": "cis",
	"pirate_surge": "hutt",
	"bounty_surge": "hutt",
	"hutt_auction": "hutt",
}
const EVENT_INFLUENCE_CAP := LOCKDOWN_REPUBLIC - 1   # 69 (one below lockdown/underworld)

var zones: Dictionary = {}   # zone_id -> zone dict
var tick_index: int = 0

func add_zone(zone_id: String, security_base: String = "secured", influence: Dictionary = {}, baseline: Dictionary = {}, display_name: String = "") -> Dictionary:
	var inf := _normalize_influence(influence)
	var base := _normalize_influence(baseline) if not baseline.is_empty() else inf.duplicate()
	var zone := {
		"schema_version": SCHEMA_VERSION,
		"zone_id": zone_id,
		"display_name": display_name if display_name != "" else zone_id,
		"security_base": security_base if TIERS.has(security_base) else "secured",
		"influence": inf,
		"baseline": base,
		"active_events": [],
		"alert_level": "standard",
		"security_overlay": null,
		"tick": tick_index,
	}
	_recompute(zone)
	zones[zone_id] = zone
	return zone

func has_zone(zone_id: String) -> bool:
	return zones.has(zone_id)

func get_zone(zone_id: String) -> Dictionary:
	return zones.get(zone_id, {})

## Players/events feed influence into a zone (clamped 0-100). The Director tick then
## decays it back toward the zone baseline over time.
func apply_influence_delta(zone_id: String, axis: String, delta: int) -> void:
	if not zones.has(zone_id) or not FACTIONS.has(axis):
		return
	var zone: Dictionary = zones[zone_id]
	var inf: Dictionary = zone["influence"]
	inf[axis] = clampi(int(inf.get(axis, 0)) + delta, 0, 100)
	_recompute(zone)

## Advance every zone one SLOW Director tick: decay influence toward baseline, expire
## events, re-derive alert + security overlay. Deterministic (no RNG).
func director_tick() -> void:
	tick_index += 1
	for zone_id in zones:
		var zone: Dictionary = zones[zone_id]
		var inf: Dictionary = zone["influence"]
		var base: Dictionary = zone["baseline"]
		for axis in FACTIONS:
			var current := int(inf.get(axis, 0))
			var target := int(base.get(axis, 0))
			if current < target:
				inf[axis] = current + 1
			elif current > target:
				inf[axis] = current - 1
		var still_active: Array = []
		for ev in zone.get("active_events", []):
			if int((ev as Dictionary).get("expires_at_tick", 0)) > tick_index:
				still_active.append(ev)
		# Fire one new event (deterministic from tick + zone) when none is active.
		if still_active.is_empty():
			var roll := absi(hash("%d:%s" % [tick_index, zone_id])) % 100
			if roll < EVENT_CHANCE:
				still_active.append(_make_event(zone, zone_id, roll))
		zone["active_events"] = still_active
		# Active events nudge their faction's influence toward a foothold (E13 causal
		# loop), capped at EVENT_INFLUENCE_CAP so a surge above it just decays.
		for ev in still_active:
			var nudge_axis := String(EVENT_INFLUENCE_NUDGE.get(String((ev as Dictionary).get("type", "")), ""))
			if nudge_axis != "" and int(inf.get(nudge_axis, 0)) < EVENT_INFLUENCE_CAP:
				inf[nudge_axis] = clampi(int(inf.get(nudge_axis, 0)) + 1, 0, EVENT_INFLUENCE_CAP)
		zone["tick"] = tick_index
		_recompute(zone)

func effective_security(zone_id: String) -> String:
	var zone: Dictionary = zones.get(zone_id, {})
	if zone.is_empty():
		return "secured"
	var overlay: Variant = zone.get("security_overlay", null)
	return String(overlay) if overlay != null else String(zone.get("security_base", "secured"))

## Compact, RPC-serializable posture for the client (alert tag + security badge).
func zone_summary(zone_id: String) -> Dictionary:
	var zone: Dictionary = zones.get(zone_id, {})
	if zone.is_empty():
		return {}
	return {
		"zone_id": zone_id,
		"display_name": String(zone.get("display_name", zone_id)),
		"alert_level": String(zone.get("alert_level", "standard")),
		"effective_security": effective_security(zone_id),
		"security_base": String(zone.get("security_base", "secured")),
		"influence": (zone.get("influence", {}) as Dictionary).duplicate(),
		"event": String(_latest_event(zone_id).get("headline", "")),
		"event_type": String(_latest_event(zone_id).get("type", "")),
		"effects": effects_for_event(String(_latest_event(zone_id).get("type", ""))),
		"tick": int(zone.get("tick", 0)),
	}

## F58: serialize the MUTABLE world-sim state (player-driven influence, active events, per-zone tick)
## so the persistent-world territory survives a SERVER RESTART. The seed-fixed fields (baseline,
## security_base, display_name) are re-seeded by the zone loader on boot, so only runtime-mutated
## state is persisted; the DERIVED alert/security are recomputed on restore, never trusted from disk.
func to_dict() -> Dictionary:
	var out := {}
	for zone_id in zones:
		var zone: Dictionary = zones[zone_id]
		out[zone_id] = {
			"influence": (zone.get("influence", {}) as Dictionary).duplicate(),
			"active_events": (zone.get("active_events", []) as Array).duplicate(true),
			"tick": int(zone.get("tick", 0)),
		}
	return {"schema_version": SCHEMA_VERSION, "tick_index": tick_index, "zones": out}

## F58: restore the mutable state produced by to_dict() onto the ALREADY-SEEDED roster (call AFTER
## the zones are added). Zones in the data but not in the roster are ignored; seeded zones absent
## from the data keep their seed. Influence is re-normalized and alert/security are re-derived.
func apply_persisted(data: Dictionary) -> void:
	if data.is_empty():
		return
	tick_index = int(data.get("tick_index", tick_index))
	var saved_zones: Dictionary = data.get("zones", {})
	for zone_id in saved_zones:
		if not zones.has(zone_id):
			continue
		var saved: Dictionary = saved_zones[zone_id]
		var zone: Dictionary = zones[zone_id]
		zone["influence"] = _normalize_influence(saved.get("influence", zone.get("influence", {})))
		zone["active_events"] = (saved.get("active_events", []) as Array).duplicate(true)
		zone["tick"] = int(saved.get("tick", zone.get("tick", 0)))
		_recompute(zone)

## Bounded mechanical modifiers for an event type (E13). Returns a COPY of the
## NEUTRAL_EFFECTS shape (all 0) for an unknown/absent type. Owner-tunable.
static func effects_for_event(event_type: String) -> Dictionary:
	return (EVENT_EFFECTS.get(event_type, NEUTRAL_EFFECTS) as Dictionary).duplicate()

func _latest_event(zone_id: String) -> Dictionary:
	var events: Array = (zones.get(zone_id, {}) as Dictionary).get("active_events", [])
	return events[events.size() - 1] if not events.is_empty() else {}

func _make_event(zone: Dictionary, zone_id: String, roll: int) -> Dictionary:
	var inf: Dictionary = zone["influence"]
	var type := ""
	if int(inf.get("republic", 0)) >= 60:
		type = ["republic_crackdown", "republic_checkpoint"][roll % 2]
	elif int(inf.get("hutt", 0)) >= 50:
		type = ["bounty_surge", "hutt_auction"][roll % 2]
	elif int(inf.get("cis", 0)) >= 40:
		type = ["cis_propaganda", "pirate_surge"][roll % 2]
	else:
		var neutral := ["merchant_arrival", "sandstorm", "cantina_brawl", "distress_signal", "krayt_sighting", "trade_boom"]
		type = neutral[roll % neutral.size()]
	return {
		"event_id": "evt_%d_%s" % [tick_index, zone_id],
		"type": type,
		"headline": String(EVENT_HEADLINES.get(type, type)),
		"started_at_tick": tick_index,
		"expires_at_tick": tick_index + EVENT_DURATION,
	}

# --- pure derivation (static, no LLM) ---
static func derive_alert_level(influence: Dictionary) -> String:
	var rep := int(influence.get("republic", 0))
	var cis := int(influence.get("cis", 0))
	var hutt := int(influence.get("hutt", 0))
	if rep >= LOCKDOWN_REPUBLIC:
		return "lockdown"
	if hutt >= UNDERWORLD_HUTT:
		return "underworld"
	if cis >= UNREST_CIS:
		return "unrest"
	if rep >= HIGH_ALERT_REPUBLIC:
		return "high_alert"
	var highest := 0
	for axis in FACTIONS:
		highest = maxi(highest, int(influence.get(axis, 0)))
	if highest < LAX_MAX_INFLUENCE:
		return "lax"
	return "standard"

static func derive_security_overlay(security_base: String, influence: Dictionary, active_events: Array) -> Variant:
	var base_idx := TIERS.find(security_base)
	if base_idx < 0:
		base_idx = 0
	var idx := base_idx
	# Hutt surge: criminal dominance pulls patrols out -> one tier less safe.
	if int(influence.get("hutt", 0)) >= HUTT_SURGE_DOWNGRADE_AT:
		idx = mini(idx + 1, TIERS.size() - 1)
	# An active Republic crackdown upgrades a contested zone to secured for its run.
	for ev in active_events:
		if String((ev as Dictionary).get("type", "")) == "republic_crackdown" and security_base == "contested":
			idx = 0
	if idx == base_idx:
		return null  # overlay equals base
	return TIERS[idx]

func _recompute(zone: Dictionary) -> void:
	zone["alert_level"] = derive_alert_level(zone["influence"])
	zone["security_overlay"] = derive_security_overlay(zone["security_base"], zone["influence"], zone.get("active_events", []))

func _normalize_influence(influence: Dictionary) -> Dictionary:
	var inf := {}
	for axis in FACTIONS:
		inf[axis] = clampi(int(influence.get(axis, 0)), 0, 100)
	return inf
