extends SceneTree
## Headless smoke for the pure corpse-decay + third-party-loot model (DIV-0006 decay windows +
## DIV-0019 lawless full-loot). Deterministic — NO RNG, NO clock (elapsed_seconds is injected).
## Consumes the EXACT world_hooks.corpse manifest shape the server writes
## (network_manager.gd: {zone_id, pos, items, decay_unix, full_loot} | null). Covers: secured =
## instant/no lootable corpse; contested + lawless decay windows match the ledger (7200 / 14400);
## a fresh lawless corpse yields the dropped set; contested is owner-protected (third party gets
## nothing); past-expiry yields nothing; the exact boundary; empty/null manifest; the manifest's
## own full_loot stamp is authoritative; credits are never lootable; loot never mutates the manifest.

const Corpse := preload("res://scripts/rules/corpse_decay_model.gd")

var _failures: Array[String] = []

func _init() -> void:
	# A representative lawless corpse manifest, exactly as _handle_player_death stamps it.
	var lawless_corpse := {
		"zone_id": "dune_sea",
		"pos": {"x": 1.0, "y": 1.2, "z": 2.0},
		"items": ["blast_helmet", "knife"],
		"decay_unix": 0.0,
		"full_loot": true,
	}

	# --- ledger decay windows (DIV-0006: secured instant, contested 2h, lawless 4h) ---
	_assert_equal(Corpse.decay_window_seconds("secured"), 0, "secured window is 0 (instant restore)")
	_assert_equal(Corpse.decay_window_seconds("contested"), 7200, "contested window is 2h = 7200s (ledger)")
	_assert_equal(Corpse.decay_window_seconds("lawless"), 14400, "lawless window is 4h = 14400s (ledger)")
	_assert_equal(Corpse.decay_window_seconds("bogus"), 0, "unknown tier -> 0 (safe, no lootable corpse)")

	# --- secured: instant restore, no lootable corpse (server writes corpse=null) ---
	_assert_equal(Corpse.is_expired("secured", 0), true, "secured is expired at t=0 (no window)")
	var s_null := Corpse.decay_state(null, "secured", 0)
	_assert_equal(bool(s_null["exists"]), false, "secured null manifest -> no corpse exists")
	_assert_equal((s_null["lootable_items"] as Array).size(), 0, "secured -> nothing lootable")
	var s_loot := Corpse.loot_for_third_party(null, "secured", 0)
	_assert_equal(String(s_loot["reason"]), "no_corpse", "secured null manifest -> no_corpse")
	_assert_equal(bool(s_loot["looted"]), false, "secured -> not looted")
	# Even if a body somehow existed in secured, the tier is never full-loot.
	_assert_equal(bool(Corpse.is_full_loot_tier("secured")), false, "secured is not a full-loot tier")

	# --- fresh lawless corpse yields the exact dropped set ---
	var fresh := Corpse.loot_for_third_party(lawless_corpse, "lawless", 0)
	_assert_equal(bool(fresh["looted"]), true, "fresh lawless corpse is lootable")
	_assert_equal(String(fresh["reason"]), "looted", "fresh lawless -> looted")
	_assert_equal((fresh["items"] as Array), ["blast_helmet", "knife"], "third party receives the dropped set")
	_assert_equal(int(fresh["credits"]), 0, "credits are KEPT by the owner (DIV-0006) -> 0 lootable")
	var fresh_state := Corpse.decay_state(lawless_corpse, "lawless", 0)
	_assert_equal(bool(fresh_state["exists"]), true, "fresh lawless corpse exists")
	_assert_equal(bool(fresh_state["expired"]), false, "fresh lawless corpse not expired")
	_assert_equal(int(fresh_state["remaining_seconds"]), 14400, "fresh lawless remaining = full 4h window")
	_assert_equal((fresh_state["lootable_items"] as Array), ["blast_helmet", "knife"], "decay_state lootable = dropped set")
	_assert_equal(int(fresh_state["lootable_credits"]), 0, "lootable_credits always 0")

	# --- lawless mid-window: still lootable, remaining counts down ---
	var mid := Corpse.decay_state(lawless_corpse, "lawless", 3600)
	_assert_equal(bool(mid["exists"]), true, "1h into a 4h lawless window -> still exists")
	_assert_equal(int(mid["remaining_seconds"]), 10800, "remaining after 1h = 3h = 10800s")

	# --- contested: DECAYS (2h) but is owner-protected, NOT third-party lootable (DIV-0019) ---
	# A contested manifest carries full_loot=false (the server derives it from the tier).
	var contested_corpse := {
		"zone_id": "cantina_row", "pos": {"x": 0, "y": 0, "z": 0},
		"items": ["stimpack"], "decay_unix": 0.0, "full_loot": false,
	}
	var c_state := Corpse.decay_state(contested_corpse, "contested", 0)
	_assert_equal(bool(c_state["exists"]), true, "a fresh contested corpse body exists (it decays over 2h)")
	_assert_equal(int(c_state["remaining_seconds"]), 7200, "contested remaining = full 2h window")
	_assert_equal((c_state["lootable_items"] as Array).size(), 0, "contested -> NOT third-party lootable")
	var c_loot := Corpse.loot_for_third_party(contested_corpse, "contested", 0)
	_assert_equal(String(c_loot["reason"]), "protected", "contested corpse is owner-protected, not full-loot")
	_assert_equal(bool(c_loot["looted"]), false, "contested -> third party gets nothing")

	# --- past-expiry lawless corpse yields nothing ---
	var gone := Corpse.loot_for_third_party(lawless_corpse, "lawless", 20000)
	_assert_equal(String(gone["reason"]), "expired", "past 4h -> expired")
	_assert_equal((gone["items"] as Array).size(), 0, "expired lawless corpse yields no items")
	var gone_state := Corpse.decay_state(lawless_corpse, "lawless", 20000)
	_assert_equal(bool(gone_state["exists"]), false, "expired corpse no longer exists")
	_assert_equal(bool(gone_state["expired"]), true, "expired corpse reports expired")
	_assert_equal(int(gone_state["remaining_seconds"]), 0, "expired corpse remaining = 0")

	# --- exact boundary (inclusive: elapsed == window -> expired) ---
	_assert_equal(Corpse.is_expired("lawless", 14399), false, "one second before the window: not expired")
	_assert_equal(Corpse.is_expired("lawless", 14400), true, "exactly at the window: expired")
	var edge_in := Corpse.loot_for_third_party(lawless_corpse, "lawless", 14399)
	_assert_equal(bool(edge_in["looted"]), true, "lootable up to the last second before expiry")
	var edge_at := Corpse.loot_for_third_party(lawless_corpse, "lawless", 14400)
	_assert_equal(String(edge_at["reason"]), "expired", "at exactly the boundary the corpse has expired")
	_assert_equal(int(Corpse.remaining_seconds("lawless", 14400)), 0, "remaining at boundary = 0")
	_assert_equal(int(Corpse.remaining_seconds("lawless", 14399)), 1, "remaining one second before boundary = 1")

	# --- empty / malformed manifests are safe ---
	_assert_equal(Corpse.has_corpse(null), false, "null manifest -> no corpse")
	_assert_equal(Corpse.has_corpse({}), false, "empty dict -> no corpse")
	_assert_equal(Corpse.has_corpse({"items": []}), false, "empty items array -> no corpse")
	_assert_equal(Corpse.has_corpse(lawless_corpse), true, "a manifest with items IS a corpse")
	var empty_state := Corpse.decay_state({}, "lawless", 0)
	_assert_equal(bool(empty_state["exists"]), false, "empty manifest -> no corpse exists")
	_assert_equal((empty_state["lootable_items"] as Array).size(), 0, "empty manifest -> nothing lootable")
	_assert_equal(String(Corpse.loot_for_third_party({}, "lawless", 0)["reason"]), "no_corpse", "empty manifest loot -> no_corpse")

	# --- the manifest's own full_loot stamp is authoritative over the tier ---
	# A lawless-zoned corpse explicitly stamped full_loot=false must NOT be third-party lootable.
	var stamped_no := {"items": ["knife"], "full_loot": false}
	_assert_equal(String(Corpse.loot_for_third_party(stamped_no, "lawless", 0)["reason"]), "protected", "explicit full_loot=false wins over lawless tier")
	# A manifest with NO full_loot key falls back to the tier table (lawless -> lootable).
	var no_flag := {"items": ["knife"]}
	_assert_equal(bool(Corpse.loot_for_third_party(no_flag, "lawless", 0)["looted"]), true, "missing full_loot key -> tier fallback (lawless lootable)")
	_assert_equal(String(Corpse.loot_for_third_party(no_flag, "contested", 0)["reason"]), "protected", "missing full_loot key -> tier fallback (contested protected)")

	# --- loot NEVER mutates the manifest (non-aliasing defensive copy) ---
	var loot_items := Corpse.loot_for_third_party(lawless_corpse, "lawless", 0)["items"] as Array
	loot_items.append("tampered")
	_assert_equal((lawless_corpse["items"] as Array), ["blast_helmet", "knife"], "looting does not mutate the source manifest")

	# --- OWNER-retrieval (loot_for_owner): the counterpart to third-party loot (audit fix 2026-07-03) ---
	# CONTESTED: the owner RECLAIMS their own dropped set within the 2h window (the case third parties get
	# "protected" for). Without this the contested drop was unrecoverable by anyone -> silently deleted.
	var own_contested := Corpse.loot_for_owner(contested_corpse, "contested", 0)
	_assert_equal(bool(own_contested["retrieved"]), true, "owner CAN retrieve their own contested corpse (owner-retrieval only)")
	_assert_equal(String(own_contested["reason"]), "retrieved", "contested owner-retrieval reason = retrieved")
	_assert_equal((own_contested["items"] as Array), ["stimpack"], "owner gets their full dropped set back from a contested corpse")
	_assert_equal(int(own_contested["credits"]), 0, "owner-retrieval credits always 0 (kept on the sheet)")
	# mid-window contested is still retrievable; at/after expiry it is gone.
	_assert_equal(bool(Corpse.loot_for_owner(contested_corpse, "contested", 7199)["retrieved"]), true, "owner can retrieve up to the last second of the 2h window")
	_assert_equal(String(Corpse.loot_for_owner(contested_corpse, "contested", 7200)["reason"]), "expired", "at the 2h boundary the contested corpse has decayed -> expired")
	# LAWLESS: the owner CANNOT self-recover a full-loot corpse — the DIV-0019 penalty stands (forfeit).
	var own_lawless := Corpse.loot_for_owner(lawless_corpse, "lawless", 0)
	_assert_equal(bool(own_lawless["retrieved"]), false, "owner CANNOT self-recover a lawless full-loot corpse")
	_assert_equal(String(own_lawless["reason"]), "forfeit", "lawless owner-retrieval -> forfeit (penalty stands, third parties race for it)")
	_assert_equal((own_lawless["items"] as Array).size(), 0, "a forfeited lawless corpse yields the owner nothing")
	# SECURED / null / empty: nothing to retrieve.
	_assert_equal(String(Corpse.loot_for_owner(null, "secured", 0)["reason"]), "no_corpse", "secured/null -> no_corpse to retrieve")
	_assert_equal(String(Corpse.loot_for_owner({}, "contested", 0)["reason"]), "no_corpse", "empty manifest -> no_corpse")
	# A stamped full_loot=false in a lawless zone is retrievable by the owner (stamp is authoritative).
	_assert_equal(bool(Corpse.loot_for_owner({"items": ["knife"], "full_loot": false}, "lawless", 0)["retrieved"]), true, "explicit full_loot=false -> owner may retrieve even in a lawless zone (stamp wins)")
	# owner-retrieval likewise never mutates the source manifest.
	var own_items := Corpse.loot_for_owner(contested_corpse, "contested", 0)["items"] as Array
	own_items.append("tampered")
	_assert_equal((contested_corpse["items"] as Array), ["stimpack"], "owner-retrieval does not mutate the source manifest")

	if _failures.is_empty():
		print("corpse_decay_model_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
