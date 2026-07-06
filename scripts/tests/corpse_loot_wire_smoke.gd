extends SceneTree
## Flow guard for the LIVE corpse-loot wiring (DIV-0025, Seam 3). network_manager is a Node autoload not
## headlessly instantiable, so — like death_flow_smoke / harvest_wire_smoke mirror the server composition
## around the pure models — this mirrors submit_loot_corpse + _despawn_expired_corpses around the pure
## CorpseDecay model + EconomyModel.grant_items: a lawless full-loot corpse + a same-zone third-party
## looter within the decay window -> the dropped set transfers into the looter's inventory + the victim
## manifest is nulled (no double-loot); a secured/contested corpse is NOT third-party lootable; an expired
## corpse yields nothing and is reaped; credits are NEVER on the corpse (DIV-0006). corpse_decay_model_smoke
## covers the pure gate math; this locks the manifest -> inventory transfer + null-out wiring.

const CorpseDecay := preload("res://scripts/rules/corpse_decay_model.gd")
const EconomyModel := preload("res://scripts/rules/economy_model.gd")

var _failures: Array[String] = []

# The tier a real corpse carries, derived from its own full_loot stamp (mirror of _tier_from_manifest).
func _tier_from_manifest(manifest) -> String:
	return "lawless" if (typeof(manifest) == TYPE_DICTIONARY and bool((manifest as Dictionary).get("full_loot", false))) else "contested"

# Mirror of submit_loot_corpse's record-side effects (no arena/state/RPC). Takes the victim + looter
# records, the corpse tier, and the server-supplied elapsed; returns {reason, items, victim, looter}.
# On a successful loot it transfers items into the looter's inventory and NULLS the victim manifest.
func _loot(victim: Dictionary, looter: Dictionary, tier: String, elapsed: int) -> Dictionary:
	var world_hooks: Dictionary = victim.get("world_hooks", {})
	var manifest = world_hooks.get("corpse", null)
	if typeof(manifest) != TYPE_DICTIONARY:
		return {"reason": "no_corpse", "items": [], "victim": victim, "looter": looter}
	var result: Dictionary = CorpseDecay.loot_for_third_party(manifest, tier, elapsed)
	if not bool(result.get("looted", false)):
		return {"reason": String(result.get("reason", "")), "items": [], "victim": victim, "looter": looter}
	var items: Array = result.get("items", [])
	looter["sheet"] = EconomyModel.grant_items(looter.get("sheet", {}), items)
	world_hooks["corpse"] = null
	victim["world_hooks"] = world_hooks
	return {"reason": "looted", "items": items, "victim": victim, "looter": looter}

func _victim(items: Array, full_loot: bool, decay_unix: float = 0.0) -> Dictionary:
	return {"world_hooks": {"corpse": {
		"zone_id": "dune_sea", "pos": {"x": 1.0, "y": 1.2, "z": 2.0},
		"items": items, "decay_unix": decay_unix, "full_loot": full_loot,
	}}}

func _looter(credits: int) -> Dictionary:
	return {"sheet": {"credits": credits, "equipment": {"weapon": "blaster_pistol"}, "inventory": ["blaster_pistol"]}}

func _init() -> void:
	# --- lawless full-loot corpse + same-zone looter within the window -> items transfer, manifest nulled ---
	var victim := _victim(["blast_helmet", "knife"], true)
	var looter := _looter(500)
	var out := _loot(victim, looter, _tier_from_manifest(victim["world_hooks"]["corpse"]), 3600)  # 1h into the 4h window
	_assert_equal(String(out["reason"]), "looted", "a fresh lawless corpse is third-party lootable")
	_assert_equal((out["items"] as Array), ["blast_helmet", "knife"], "the looter receives the exact dropped set")
	var l_inv: Array = ((out["looter"] as Dictionary)["sheet"] as Dictionary)["inventory"]
	var has_helmet = false
	var has_knife = false
	var has_blaster = false
	for item in l_inv:
		if typeof(item) == TYPE_DICTIONARY:
			var tid = item.get("template_id", "")
			if tid == "blast_helmet": has_helmet = true
			if tid == "knife": has_knife = true
			if tid == "blaster_pistol": has_blaster = true
	_assert_true(has_helmet and has_knife, "the dropped items landed in the looter's inventory")
	_assert_true(has_blaster, "the looter's pre-existing inventory is preserved")
	_assert_equal(int(((out["looter"] as Dictionary)["sheet"] as Dictionary)["credits"]), 500, "credits are NEVER on the corpse (DIV-0006) — looter credits unchanged")
	_assert_equal(((out["victim"] as Dictionary)["world_hooks"] as Dictionary)["corpse"], null, "the victim manifest is nulled after a successful loot")

	# --- no double-loot: a second attempt on the now-nulled corpse yields nothing ---
	var again := _loot(out["victim"], out["looter"], "lawless", 3600)
	_assert_equal(String(again["reason"]), "no_corpse", "a nulled corpse cannot be double-looted")
	_assert_equal((again["items"] as Array).size(), 0, "the second loot attempt transfers no items")

	# --- contested corpse: owner-protected, NOT third-party lootable ---
	var c_victim := _victim(["stimpack"], false)
	var c_looter := _looter(500)
	var c_out := _loot(c_victim, c_looter, _tier_from_manifest(c_victim["world_hooks"]["corpse"]), 60)
	_assert_equal(String(c_out["reason"]), "protected", "a contested corpse is owner-protected from a third party")
	_assert_equal((((c_out["victim"] as Dictionary)["world_hooks"] as Dictionary)["corpse"] as Dictionary)["items"], ["stimpack"], "a protected corpse is left intact (not nulled)")
	var c_inv: Array = ((c_out["looter"] as Dictionary)["sheet"] as Dictionary)["inventory"]
	var c_has_stim = false
	for item in c_inv:
		if typeof(item) == TYPE_DICTIONARY and item.get("template_id", "") == "stimpack":
			c_has_stim = true
	_assert_true(not c_has_stim, "a third party gains nothing from a contested corpse")

	# --- secured death writes corpse=null: no body to loot ---
	var s_victim := {"world_hooks": {"corpse": null}}
	var s_out := _loot(s_victim, _looter(500), "secured", 0)
	_assert_equal(String(s_out["reason"]), "no_corpse", "a secured death leaves no lootable corpse")

	# --- expired lawless corpse: past the 4h window -> nothing, and the despawn tick reaps it ---
	var e_victim := _victim(["blast_helmet"], true, 0.0)
	var e_out := _loot(e_victim, _looter(500), "lawless", 20000)  # > 14400s window
	_assert_equal(String(e_out["reason"]), "expired", "a corpse past its decay window yields nothing")
	_assert_true(CorpseDecay.is_expired("lawless", 20000), "the despawn tick's is_expired gate agrees the corpse is gone")
	_assert_true(not CorpseDecay.is_expired("lawless", 3600), "a corpse still inside the window is NOT reaped")

	# --- the model's full_loot stamp is authoritative: a lawless-zoned corpse stamped full_loot=false rejects ---
	var stamped := _victim(["knife"], false)
	var st_out := _loot(stamped, _looter(500), "lawless", 0)
	_assert_equal(String(st_out["reason"]), "protected", "an explicit full_loot=false stamp wins over the lawless tier")

	# --- SELF-LOOT guard (verify: gating-safety, HIGH): a corpse's record identity is the SANITIZED
	#     filename, so submit_loot_corpse must reject when the target resolves to the LOOTER's own record
	#     via store.record_path — a raw-string compare is bypassable (a raw id like "my.corpse" sanitizes
	#     to the same file as "my_corpse", letting a player loot their own full-loot drops and defeat the
	#     DIV-0006/0019 death penalty). Assert the record_path canonicalization the fix relies on. ---
	var ps = load("res://scripts/net/persistence_store.gd").new("user://corpse_loot_wire_smoke_ps")
	_assert_equal(ps.record_path("my.corpse"), ps.record_path("my_corpse"), "distinct RAW ids that sanitize to the same file share a record_path (the self-loot guard's canonical compare catches this)")
	_assert_true(ps.record_path("looter_a") != ps.record_path("victim_b"), "genuinely different ids keep distinct record_paths (real third-party loot still allowed)")

	if _failures.is_empty():
		print("corpse_loot_wire_smoke: OK")
		quit(0)
	else:
		for f in _failures:
			printerr(f)
		quit(1)

func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
