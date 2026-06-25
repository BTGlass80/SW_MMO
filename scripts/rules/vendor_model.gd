extends RefCounted

# NPC vendor / price model (Wave E - E11).
#
# Pure, deterministic, NO RNG. Computes the stock an NPC vendor offers for sale
# and the price quoted for a given item, factoring in:
#   * a bargain discount earned by a Bargain skill / commerce-droid Bargain
#     processor (bargain_dice + bargain_pips), and
#   * a Director event multiplier (trade booms / scarcity move base prices).
#
# Data consumed (res://data/*.json):
#   weapons_clone_wars.json : top-level "weapons" map; each weapon =
#       {name, cost(int), vendor_stocked(bool), type, ...}. Faction-issued and
#       contraband weapons carry vendor_stocked:false (per that file's note),
#       so requiring vendor_stocked == true already excludes them.
#   armor_clone_wars.json   : top-level "armor" map; each armor =
#       {name, cost(int), vendor_stocked(bool), coverage, ...}. Armor rows carry
#       a real vendor_stocked field. We honor it; and as a defensive fallback
#       (per the E11 rule) we still exclude any armor flagged contraband or
#       faction_issued even if it lacked vendor_stocked.
#   droids_clone_wars.json  : top-level "droids" map; each droid =
#       {name, tier, cost, bargain_dice(int), bargain_pips(int), buy_orders,...}.
#       A vendor droid's bargain_dice/bargain_pips feed bargain_discount().

# 3% price discount per effective bargain die (a pip = 1/3 of a die in WEG D6).
const BARGAIN_PCT_PER_DIE := 0.03

# Discount is clamped to this fraction so a vendor can never give it away.
const MAX_BARGAIN_DISCOUNT := 0.5

# list_stock(weapons_data, armor_data) -> Array
#
# Returns the items a vendor offers for sale. Each entry is a Dictionary:
#   {key, kind ("weapon"|"armor"), name, base_cost (int)}
# Inclusion rules:
#   * weapons: included only when vendor_stocked == true (this already excludes
#     faction-issued and contraband weapons, which carry vendor_stocked:false).
#   * armor: included when vendor-stocked AND not contraband / faction_issued.
#     If an armor row lacks a vendor_stocked field it is treated as stocked
#     unless it carries a truthy contraband or faction_issued flag.
# Entries are returned in a stable order, sorted by key.
func list_stock(weapons_data: Dictionary, armor_data: Dictionary) -> Array:
	var stock := []
	var weapons: Dictionary = weapons_data.get("weapons", {})
	for key in weapons.keys():
		var weapon: Dictionary = weapons.get(key, {})
		if typeof(weapon) != TYPE_DICTIONARY:
			continue
		if bool(weapon.get("vendor_stocked", false)):
			stock.append({
				"key": String(key),
				"kind": "weapon",
				"name": String(weapon.get("name", String(key))),
				"base_cost": int(weapon.get("cost", 0)),
			})
	var armors: Dictionary = armor_data.get("armor", {})
	for key in armors.keys():
		var armor: Dictionary = armors.get(key, {})
		if typeof(armor) != TYPE_DICTIONARY:
			continue
		if _armor_is_stocked(armor):
			stock.append({
				"key": String(key),
				"kind": "armor",
				"name": String(armor.get("name", String(key))),
				"base_cost": int(armor.get("cost", 0)),
			})
	stock.sort_custom(func(a, b): return String(a["key"]) < String(b["key"]))
	return stock

# Decide whether an armor row is offered for sale.
# Armor has a real vendor_stocked field in data; honor it. As a fallback (per
# the E11 rule), exclude contraband / faction_issued armor even without the
# field, and treat a missing vendor_stocked field as "stocked" otherwise.
func _armor_is_stocked(armor: Dictionary) -> bool:
	if bool(armor.get("contraband", false)) or bool(armor.get("faction_issued", false)):
		return false
	if armor.has("vendor_stocked"):
		return bool(armor.get("vendor_stocked", false))
	return true

# bargain_discount(bargain_dice, bargain_pips) -> float
#
# Effective bargain dice = bargain_dice + bargain_pips/3 (WEG D6: 3 pips = 1 die).
# Discount fraction = effective_dice * BARGAIN_PCT_PER_DIE (3% per die),
# clamped to [0.0, MAX_BARGAIN_DISCOUNT].
func bargain_discount(bargain_dice: int, bargain_pips: int) -> float:
	var effective_dice := float(bargain_dice) + float(bargain_pips) / 3.0
	var discount := effective_dice * BARGAIN_PCT_PER_DIE
	return clampf(discount, 0.0, MAX_BARGAIN_DISCOUNT)

# quote(base_cost, director_multiplier, bargain_dice, bargain_pips) -> int
#
# Price = base_cost * director_multiplier * (1 - bargain_discount), rounded to
# the nearest whole credit.
#   * director_multiplier reflects a Director event: trade_boom / merchant_arrival
#     push it below 1.0 (cheaper); scarcity pushes it above 1.0 (dearer).
#   * bargain_discount is the buyer's negotiated reduction.
func quote(base_cost: int, director_multiplier: float, bargain_dice: int, bargain_pips: int) -> int:
	var p := float(base_cost) * director_multiplier * (1.0 - bargain_discount(bargain_dice, bargain_pips))
	return int(round(p))

# director_multiplier_for_event(event_type) -> float
#
# Maps a Director world-event type to a price multiplier on base cost:
#   "trade_boom"       -> 0.85 (prices fall ~15%)
#   "merchant_arrival" -> 0.90 (prices fall ~10%)
#   anything else      -> 1.00 (no effect)
# Bounded to known events; unknown events are a no-op multiplier.
func director_multiplier_for_event(event_type: String) -> float:
	match event_type:
		"trade_boom":
			return 0.85
		"merchant_arrival":
			return 0.9
		_:
			return 1.0
