extends RefCounted
## Pure WEG D6 R&E character advancement (C3). Grounds Guide_09.
##
## Cost to advance a skill by one pip = the number of DICE in the current TOTAL pool
## (governing attribute + skill bonus). Raising adds one pip to the skill BONUS; every
## third pip rolls up to a new die, so the per-pip cost steps up at each die boundary
## (e.g. total 4D+1->4D+2 costs 4 CP, 4D+2->5D costs 4 CP, 5D->5D+1 costs 5 CP). An
## optional guild discount multiplier applies (cost = max(1, floor(cost * discount))).
##
## CP is a DUAL-TRACK wallet (DIV-0007): {gameplay_cp, rp_cp}. Both are spendable
## advancement currency; gameplay CP is spent first, RP-prestige CP second. Tracked
## separately for provenance/display.
##
## Pure/socket-free: pool math is delegated to a passed `rules` object (D6Rules).

static func total_pool(rules: Object, attribute_code: String, skill_bonus_code: String) -> Dictionary:
	return rules.add_pools(rules.parse_pool(attribute_code), rules.parse_pool(skill_bonus_code))

## CP to add one pip, given the current total-pool dice count.
static func pip_cost(total_pool_dice: int) -> int:
	return maxi(total_pool_dice, 1)

## CP to raise a skill by one pip from its current state, with an optional discount.
static func skill_raise_cost(rules: Object, attribute_code: String, skill_bonus_code: String, discount: float = 1.0) -> int:
	var pool := total_pool(rules, attribute_code, skill_bonus_code)
	var cost := pip_cost(int(pool["dice"]))
	return maxi(1, int(floor(float(cost) * discount)))

static func wallet_total(wallet: Dictionary) -> int:
	return int(wallet.get("gameplay_cp", 0)) + int(wallet.get("rp_cp", 0))

static func can_raise(rules: Object, wallet: Dictionary, attribute_code: String, skill_bonus_code: String, discount: float = 1.0) -> bool:
	return wallet_total(wallet) >= skill_raise_cost(rules, attribute_code, skill_bonus_code, discount)

## Raise a skill by one pip. Returns {ok, cost, new_skill_bonus, wallet} on success, or
## {ok=false, reason, cost, wallet} when the wallet is short. Never mutates the inputs.
static func raise_skill(rules: Object, wallet: Dictionary, attribute_code: String, skill_bonus_code: String, discount: float = 1.0) -> Dictionary:
	var cost := skill_raise_cost(rules, attribute_code, skill_bonus_code, discount)
	if wallet_total(wallet) < cost:
		return {"ok": false, "reason": "insufficient_cp", "cost": cost, "wallet": wallet.duplicate(true)}
	var new_bonus: Dictionary = rules.add_pips(rules.parse_pool(skill_bonus_code), 1)
	var purse := _spend(wallet, cost)
	return {
		"ok": true,
		"cost": cost,
		"new_skill_bonus": String(rules.pool_to_string(new_bonus)),
		"wallet": purse,
	}

## Credit CP to one track. track = "gameplay" (default) or "rp".
static func award(wallet: Dictionary, track: String, amount: int) -> Dictionary:
	var purse := wallet.duplicate(true)
	var key := "rp_cp" if track == "rp" else "gameplay_cp"
	purse[key] = int(purse.get(key, 0)) + maxi(amount, 0)
	return purse

static func new_wallet(gameplay_cp: int = 0, rp_cp: int = 0) -> Dictionary:
	return {"gameplay_cp": maxi(gameplay_cp, 0), "rp_cp": maxi(rp_cp, 0)}

# Spend `cost` CP, gameplay track first then RP-prestige. Caller guarantees affordability.
static func _spend(wallet: Dictionary, cost: int) -> Dictionary:
	var purse := wallet.duplicate(true)
	var remaining := cost
	var gameplay := int(purse.get("gameplay_cp", 0))
	var from_gameplay := mini(gameplay, remaining)
	purse["gameplay_cp"] = gameplay - from_gameplay
	remaining -= from_gameplay
	purse["rp_cp"] = maxi(int(purse.get("rp_cp", 0)) - remaining, 0)
	return purse
