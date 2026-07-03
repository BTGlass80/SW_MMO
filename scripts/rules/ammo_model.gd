extends RefCounted
## Pure WEG ammo / power-pack recurring-sink model (DIV-0029). No nodes, RNG, or sockets — it is
## the deterministic decision core the server wraps. WEG R&E: each ranged weapon carries an `ammo`
## count (shots per power pack) and a fresh pack costs 25 credits + refills the weapon to full; the
## MMO approximates WEG's reload-as-action by the sink itself (the pack IS the reload).
##
## STATE SHAPE (lives on the character sheet, persistence-friendly plain Dictionary of ints):
##   sheet.ammo = { <weapon_key>: shots_left(int), "packs": pack_count(int) }
## A weapon absent from the map is treated as a FULL magazine (lazy init on first fire, so an
## existing character with no `ammo` block is never stranded). MELEE weapons (no `ammo`) and
## single_use ordnance (grenades / thermal detonator) are NOT ammo-tracked — uses_ammo() returns
## false for them, so they never decrement or reject (single_use stays latent).
##
## Everything here is static + pure; the mutating helpers (consume / auto_reload / add_packs /
## remove_pack) operate ON and RETURN the plain `ammo` sub-dictionary so callers persist it as-is.

const PACK_COST := 25         # WEG R&E: a blaster power pack, 25 credits, refills to full (TUNABLE default, not an owner ruling)
const STARTING_PACKS := 2     # chargen grace kit — keeps a broke newbie off a no-ammo softlock (TUNABLE default)
const PACK_ITEM_KEY := "power_pack"   # the universal vendor pack (fits any pack-using weapon — a documented simplification)
const PACKS_KEY := "packs"    # the reserved key inside sheet.ammo holding the carried-pack count

## The weapon's full magazine size = the WEG `ammo` field. 0 / absent = not ammo-tracked.
static func shots_per_weapon(weapon_dict: Dictionary) -> int:
	return maxi(int(weapon_dict.get("ammo", 0)), 0)

## True when the weapon draws from a power pack: a positive `ammo` count AND not single_use. A
## single_use item (frag/thermal/incendiary grenade, flare) is one-and-done, not reloadable — it
## stays latent (never gated, never decremented) here.
static func uses_ammo(weapon_dict: Dictionary) -> bool:
	if bool(weapon_dict.get("single_use", false)):
		return false
	return shots_per_weapon(weapon_dict) > 0

## The starting ammo block chargen grants: STARTING_PACKS carried, no per-weapon entry yet (the
## equipped weapon lazy-inits to full on its first real shot). Plain-ints Dictionary.
static func initial_ammo() -> Dictionary:
	return {PACKS_KEY: STARTING_PACKS}

## Carried power-pack count (defaults to STARTING_PACKS when the block predates this system, so a
## legacy character's HUD/first-fire sees the migrated grace packs).
static func packs(ammo: Dictionary) -> int:
	return maxi(int(ammo.get(PACKS_KEY, STARTING_PACKS)), 0)

## Shots left in the given weapon's magazine. An untracked weapon (no entry yet) reads as FULL —
## a fresh magazine — so lazy migration never presents an empty gun.
static func shots_left(ammo: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> int:
	return maxi(int(ammo.get(weapon_key, shots_per_weapon(weapon_dict))), 0)

## Ensure the ammo block is initialized for this weapon (lazy migration). A block that predates the
## system (no `packs` key at all) is granted STARTING_PACKS; a known block simply gains this weapon
## at full shots. Mutates + returns `ammo`. No-op for a non-ammo weapon.
static func ensure_init(ammo: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> Dictionary:
	if not uses_ammo(weapon_dict):
		return ammo
	if not ammo.has(PACKS_KEY):
		ammo[PACKS_KEY] = STARTING_PACKS
	if not ammo.has(weapon_key):
		ammo[weapon_key] = shots_per_weapon(weapon_dict)
	return ammo

## Can this weapon fire right now? Always true for a non-ammo weapon (melee / single_use). For an
## ammo weapon: a shot in the magazine, OR a carried pack to reload from. This is the SUBMIT-time
## gate; a false result is the `out_of_ammo` reject (empty AND no pack).
static func can_fire(ammo: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> bool:
	if not uses_ammo(weapon_dict):
		return true
	if shots_left(ammo, weapon_key, weapon_dict) > 0:
		return true
	return packs(ammo) > 0

## Reload from a carried pack: spend one pack, refill this weapon to full. Returns {ok, packs_left}.
## ok=false (no pack) leaves state untouched. Mutates `ammo`.
static func auto_reload(ammo: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> Dictionary:
	var have := packs(ammo)
	if have <= 0:
		return {"ok": false, "packs_left": 0}
	ammo[PACKS_KEY] = have - 1
	ammo[weapon_key] = shots_per_weapon(weapon_dict)
	return {"ok": true, "packs_left": have - 1}

## Consume one shot for a RESOLVED real shot. Auto-reloads from a pack when the magazine is empty
## (the WEG reload-as-action, approximated by the sink). Returns {ok, shots_left, reloaded,
## packs_left}. ok=false ONLY when empty AND no pack (the submit gate normally prevents reaching
## here). A non-ammo weapon is a no-op success (ok=true, shots_left=-1). Mutates `ammo`.
static func consume(ammo: Dictionary, weapon_key: String, weapon_dict: Dictionary) -> Dictionary:
	if not uses_ammo(weapon_dict):
		return {"ok": true, "shots_left": -1, "reloaded": false, "packs_left": packs(ammo)}
	ensure_init(ammo, weapon_key, weapon_dict)
	var reloaded := false
	if int(ammo.get(weapon_key, 0)) <= 0:
		var r := auto_reload(ammo, weapon_key, weapon_dict)
		if not bool(r.get("ok", false)):
			return {"ok": false, "shots_left": 0, "reloaded": false, "packs_left": 0}
		reloaded = true
	ammo[weapon_key] = int(ammo[weapon_key]) - 1
	return {"ok": true, "shots_left": int(ammo[weapon_key]), "reloaded": reloaded, "packs_left": packs(ammo)}

## Add `n` power packs (the vendor buy path — packs stack onto sheet.ammo.packs, not inventory).
## Mutates + returns `ammo`.
static func add_packs(ammo: Dictionary, n: int) -> Dictionary:
	ammo[PACKS_KEY] = packs(ammo) + maxi(n, 0)
	return ammo

## Remove one power pack (the vendor SELL path). Returns {ok, packs_left}; ok=false when none held.
static func remove_pack(ammo: Dictionary) -> Dictionary:
	var have := packs(ammo)
	if have <= 0:
		return {"ok": false, "packs_left": 0}
	ammo[PACKS_KEY] = have - 1
	return {"ok": true, "packs_left": have - 1}
