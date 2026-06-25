extends RefCounted
## Pure equipment / inventory model (Wave E E22 / D3).
##
## Validates an equipment swap against the loaded weapon/armor catalogs AND the
## character's owned-item inventory, then produces the updated sheet. No nodes, RNG,
## or sockets — the server's submit_equip RPC drives it and equip_smoke tests it
## headlessly. The combat read-path (combat_arena building damage/armor pools from
## sheet.equipment) already exists; this completes the WRITE path.

const SLOTS := ["weapon", "armor"]

## The catalog (weapons or armor) a slot draws its items from.
static func catalog_for_slot(slot: String, weapons: Dictionary, armor: Dictionary) -> Dictionary:
	if slot == "weapon":
		return weapons
	if slot == "armor":
		return armor
	return {}

## The item keys a sheet owns. Uses sheet.inventory when present + non-empty;
## otherwise falls back to whatever is currently equipped, so a pre-inventory save
## still "owns" its own gear (and can re-equip it) without being granted anything.
static func owned_items(sheet: Dictionary) -> Array:
	var inv: Variant = sheet.get("inventory", null)
	if typeof(inv) == TYPE_ARRAY and not (inv as Array).is_empty():
		return inv
	var equipped: Array = []
	var eq: Dictionary = sheet.get("equipment", {})
	for slot in SLOTS:
		var key := String(eq.get(slot, ""))
		if key != "" and not equipped.has(key):
			equipped.append(key)
	return equipped

static func owns_item(sheet: Dictionary, item_key: String) -> bool:
	return owned_items(sheet).has(item_key)

## Validate an equip request. Returns {ok: bool, reason: String}. The reason names the
## FIRST failure: "bad_slot" / "unknown_item" (not in the slot's catalog) / "not_owned".
static func can_equip(sheet: Dictionary, slot: String, item_key: String, weapons: Dictionary, armor: Dictionary) -> Dictionary:
	if not SLOTS.has(slot):
		return {"ok": false, "reason": "bad_slot"}
	var catalog: Dictionary = catalog_for_slot(slot, weapons, armor)
	if not catalog.has(item_key):
		return {"ok": false, "reason": "unknown_item"}
	if not owns_item(sheet, item_key):
		return {"ok": false, "reason": "not_owned"}
	return {"ok": true, "reason": ""}

## Apply an equip swap. Returns {ok, reason, sheet}. On success, sheet is a NEW copy
## with equipment[slot] = item_key (NON-mutating); on failure the original sheet is
## returned unchanged.
static func equip(sheet: Dictionary, slot: String, item_key: String, weapons: Dictionary, armor: Dictionary) -> Dictionary:
	var check: Dictionary = can_equip(sheet, slot, item_key, weapons, armor)
	if not bool(check["ok"]):
		return {"ok": false, "reason": String(check["reason"]), "sheet": sheet}
	var next: Dictionary = sheet.duplicate(true)
	var equipment: Dictionary = next.get("equipment", {})
	equipment[slot] = item_key
	next["equipment"] = equipment
	return {"ok": true, "reason": "", "sheet": next}
