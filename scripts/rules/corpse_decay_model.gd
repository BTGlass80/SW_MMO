extends RefCounted
## Pure player-corpse decay + third-party lootability (Wave F / DIV-0006 + DIV-0019). All-static,
## NO RNG, NO clock of its own — the SERVER owns the clock and passes `elapsed_seconds` (time since
## the corpse was created). This model READ-ONLY consumes the corpse manifest that
## `death_penalty_model.apply_death` produces and `_handle_player_death` stamps onto
## `record.world_hooks.corpse`. It NEVER mutates the manifest and NEVER invents an item.
##
## Manifest shape (exactly as the server writes it, network_manager.gd):
##   world_hooks.corpse = { "zone_id": String, "pos": {x,y,z}, "items": Array,
##                          "decay_unix": float(=0.0 placeholder), "full_loot": bool }
##   ...or `null` when nothing dropped (secured death / insured death / empty inventory).
##
## Decay windows by security tier come STRAIGHT from DIV-0006 (secured=instant restore,
## contested=2h, lawless=4h per Guide_19 §4). Third-party FULL-LOOT is LAWLESS-ONLY per DIV-0019
## (mirrors pvp_rules_model.FULL_LOOT_TIERS): a contested corpse still DECAYS (2h) but is the
## owner's to retrieve, not third-party lootable. Credits are NEVER on the corpse (DIV-0006:
## credits KEPT), so `lootable_credits` is always 0.
##
## `decay_unix` is a server-owned ABSOLUTE-time hook (currently 0.0); this pure model deliberately
## does NOT interpret it — it derives everything from `security_tier` + `elapsed_seconds`.

# Decay lifespan by security tier, in SECONDS (DIV-0006 numbers; secured has no lootable window).
const DECAY_WINDOW_SECONDS := {
	"secured": 0,        # instant restore — the server writes corpse=null; no lootable body
	"contested": 7200,   # 2 hours (DIV-0006 / Guide_19 §4) — decays, owner-retrieval only
	"lawless": 14400,    # 4 hours (DIV-0006 / Guide_19 §4) — decays AND full-loot (DIV-0019)
}
const DEFAULT_WINDOW := 0                 # unknown/unspecified tier -> no lootable corpse (safe)
const FULL_LOOT_TIERS := ["lawless"]      # third-party lootable ONLY here (mirrors DIV-0019 / PvpRules)

# --- tier helpers (RNG-free, manifest-free) -------------------------------------------------

# Decay lifespan for a tier in seconds (0 = no lootable corpse / instant restore).
static func decay_window_seconds(security_tier: String) -> int:
	return int(DECAY_WINDOW_SECONDS.get(security_tier, DEFAULT_WINDOW))

# Is a dropped corpse in this tier third-party lootable at all (before time)? Lawless only.
static func is_full_loot_tier(security_tier: String) -> bool:
	return FULL_LOOT_TIERS.has(security_tier)

# Has the decay window elapsed? Secured/unknown (window 0) is treated as ALWAYS expired
# (instant restore, no lootable window). Boundary is inclusive: elapsed == window -> expired.
static func is_expired(security_tier: String, elapsed_seconds: int) -> bool:
	var window := decay_window_seconds(security_tier)
	if window <= 0:
		return true
	return elapsed_seconds >= window

# Seconds left before the corpse despawns (0 once expired or for a no-window tier).
static func remaining_seconds(security_tier: String, elapsed_seconds: int) -> int:
	return maxi(decay_window_seconds(security_tier) - elapsed_seconds, 0)

# --- manifest helpers -----------------------------------------------------------------------

# True when the manifest is a real corpse body: a Dictionary carrying a non-empty items Array.
# `null` (secured/insured/empty-inventory death) and {} return false.
static func has_corpse(manifest) -> bool:
	if typeof(manifest) != TYPE_DICTIONARY:
		return false
	var items = (manifest as Dictionary).get("items", [])
	return typeof(items) == TYPE_ARRAY and not (items as Array).is_empty()

# A defensive copy of the dropped set (never aliases the manifest).
static func _items(manifest) -> Array:
	if typeof(manifest) != TYPE_DICTIONARY:
		return []
	var items = (manifest as Dictionary).get("items", [])
	if typeof(items) != TYPE_ARRAY:
		return []
	return (items as Array).duplicate()

# The manifest's own `full_loot` stamp is authoritative when present (the server derived it from the
# death tier); otherwise fall back to the tier table. Keeps model + server in agreement.
static func _manifest_full_loot(manifest, security_tier: String) -> bool:
	if typeof(manifest) == TYPE_DICTIONARY and (manifest as Dictionary).has("full_loot"):
		return bool((manifest as Dictionary)["full_loot"])
	return is_full_loot_tier(security_tier)

# --- primary API ----------------------------------------------------------------------------

# The full decay snapshot the server broadcasts / gates loot on. Returns:
#   { exists, expired, remaining_seconds, lootable_items, lootable_credits }
#     exists            : a live, un-decayed corpse body is present (has items AND within window)
#     expired           : the decay window has elapsed (pure time/tier; secured => true)
#     remaining_seconds : countdown to despawn (0 when expired / no window)
#     lootable_items    : what a THIRD PARTY may take RIGHT NOW (full-loot + present + not expired)
#     lootable_credits  : always 0 — credits are KEPT by the owner (DIV-0006), never on the corpse
static func decay_state(manifest, security_tier: String, elapsed_seconds: int) -> Dictionary:
	var present := has_corpse(manifest)
	var expired := is_expired(security_tier, elapsed_seconds)
	var exists := present and not expired
	var full_loot := _manifest_full_loot(manifest, security_tier)
	var lootable: Array = _items(manifest) if (exists and full_loot) else []
	return {
		"exists": exists,
		"expired": expired,
		"remaining_seconds": remaining_seconds(security_tier, elapsed_seconds),
		"lootable_items": lootable,
		"lootable_credits": 0,
	}

# What a THIRD-PARTY looter actually receives from the corpse right now. Returns:
#   { looted: bool, items: Array, credits: int, reason: String }
#     reason: "no_corpse"  (null/empty manifest — secured/insured/empty-inventory death)
#             "protected"  (not full-loot: secured/contested — owner-retrieval only)
#             "expired"    (past the decay window -> yields nothing)
#             "looted"     (fresh lawless full-loot corpse -> hands over the dropped set)
# credits is ALWAYS 0 (DIV-0006 credits KEPT). Never mutates the manifest.
static func loot_for_third_party(manifest, security_tier: String, elapsed_seconds: int) -> Dictionary:
	var reason := ""
	var items: Array = []
	if not has_corpse(manifest):
		reason = "no_corpse"
	elif not _manifest_full_loot(manifest, security_tier):
		reason = "protected"
	elif is_expired(security_tier, elapsed_seconds):
		reason = "expired"
	else:
		reason = "looted"
		items = _items(manifest)
	return {"looted": reason == "looted", "items": items, "credits": 0, "reason": reason}
