extends SceneTree
## Route-check smoke for Seam 5 (Wave G): the SIX server-side telemetry event
## field-dicts that network_manager.gd builds at its live [death]/[buy]/[sell]/
## [loot]/[zone]/[combat] print sites, round-tripped through a real TelemetryLog
## (append + read_all) under a throwaway user:// path.
##
## This mirrors the COMPOSITION the server performs — it constructs the same
## dicts (same keys the wired log_event calls pass) with a server-stamped `ts`,
## logs one line per event, reads them all back, and asserts each `type` plus its
## load-bearing key fields survive the JSONL round-trip. It does NOT boot a
## server; it pins the schema the routing depends on so a field rename breaks a
## test rather than silently corrupting telemetry.
##
## Writes only under a throwaway user:// dir and cleans up (no engine-level ERROR
## to stderr, which the PowerShell gate treats as failure).

const TelemetryLog := preload("res://scripts/net/telemetry_log.gd")
const TEST_DIR := "user://telemetry_wire_smoke_test"
const TEST_PATH := TEST_DIR + "/events.jsonl"

var _failures: Array[String] = []

func _init() -> void:
	_clean()

	var log: TelemetryLog = TelemetryLog.new(TEST_PATH)
	# A fixed server clock stand-in — the real server passes Time.get_unix_time_from_system();
	# the writer never calls Time itself, so ts is just another supplied field here.
	var ts := 1_700_000_000.0

	# --- death (network_manager _handle_player_death: "[death] peer ...") ---
	_assert_true(log.log_event("death", {
		"ts": ts, "character_id": "char_a", "zone": "tatooine.mos_eisley.dune_sea",
		"tier": "lawless", "killer": "a krayt dragon", "durability_delta": 20,
		"dropped": 2, "insured": false, "credits": 850,
	}), "death event logs")

	# --- buy (submit_buy: "[buy] ...") ---
	_assert_true(log.log_event("buy", {
		"ts": ts, "character_id": "char_a", "item_key": "blaster_pistol",
		"price": 350, "credits": 500,
	}), "buy event logs")

	# --- sell (submit_sell: "[sell] ...") ---
	_assert_true(log.log_event("sell", {
		"ts": ts, "character_id": "char_a", "item_key": "vibro_knife",
		"price": 40, "credits": 540,
	}), "sell event logs")

	# --- loot (_resolve_combat_window: "[loot] ...") — character_id is the PERSISTENT string (joinable to
	#     the other economy events), with the transient peer id kept separately as peer_id ---
	_assert_true(log.log_event("loot", {
		"ts": ts, "character_id": "char_a", "peer_id": 7, "creature_key": "womp_rat",
		"loot_credits": 12, "salvage_credits": 5,
	}), "loot event logs")

	# --- travel (submit_change_zone: "[zone] peer ... traveled ...") ---
	_assert_true(log.log_event("travel", {
		"ts": ts, "character_id": "char_a", "zone_id": "tatooine.mos_eisley.cantina",
		"security_tier": "contested",
	}), "travel event logs")

	# --- window_resolve (_resolve_combat_window: "[combat] window ... resolved") ---
	_assert_true(log.log_event("window_resolve", {
		"ts": ts, "window": 42, "envelope_count": 3,
	}), "window_resolve event logs")

	var events := log.read_all()
	_assert_equal(events.size(), 6, "read_all returns all six routed events")

	# Index by type so the assertions do not depend on append order.
	var by_type := {}
	for e in events:
		by_type[String((e as Dictionary).get("type", ""))] = e
	for t in ["death", "buy", "sell", "loot", "travel", "window_resolve"]:
		_assert_true(by_type.has(t), "%s event present after round-trip" % t)
	# Every event carries a server-stamped ts.
	for e in events:
		_assert_true((e as Dictionary).has("ts"), "%s carries a server ts" % String((e as Dictionary).get("type", "")))

	var death: Dictionary = by_type.get("death", {})
	_assert_equal(String(death.get("character_id", "")), "char_a", "death character_id round-trips")
	_assert_equal(String(death.get("zone", "")), "tatooine.mos_eisley.dune_sea", "death zone round-trips")
	_assert_equal(String(death.get("tier", "")), "lawless", "death tier round-trips")
	_assert_equal(String(death.get("killer", "")), "a krayt dragon", "death killer round-trips")
	_assert_equal(int(death.get("durability_delta", -1)), 20, "death durability_delta round-trips")
	_assert_equal(int(death.get("dropped", -1)), 2, "death dropped round-trips")
	_assert_equal(bool(death.get("insured", true)), false, "death insured round-trips")
	_assert_equal(int(death.get("credits", -1)), 850, "death credits round-trips")

	var buy: Dictionary = by_type.get("buy", {})
	_assert_equal(String(buy.get("item_key", "")), "blaster_pistol", "buy item_key round-trips")
	_assert_equal(int(buy.get("price", -1)), 350, "buy price round-trips")
	_assert_equal(int(buy.get("credits", -1)), 500, "buy credits round-trips")

	var sell: Dictionary = by_type.get("sell", {})
	_assert_equal(String(sell.get("item_key", "")), "vibro_knife", "sell item_key round-trips")
	_assert_equal(int(sell.get("price", -1)), 40, "sell price round-trips")
	_assert_equal(int(sell.get("credits", -1)), 540, "sell credits round-trips")

	var loot: Dictionary = by_type.get("loot", {})
	_assert_equal(String(loot.get("character_id", "")), "char_a", "loot character_id is the PERSISTENT string (joinable to death/buy/sell/travel), not a peer int")
	_assert_equal(int(loot.get("peer_id", -1)), 7, "loot keeps the transient peer id separately as peer_id")
	_assert_equal(String(loot.get("creature_key", "")), "womp_rat", "loot creature_key round-trips")
	_assert_equal(int(loot.get("loot_credits", -1)), 12, "loot loot_credits round-trips")
	_assert_equal(int(loot.get("salvage_credits", -1)), 5, "loot salvage_credits round-trips")

	var travel: Dictionary = by_type.get("travel", {})
	_assert_equal(String(travel.get("character_id", "")), "char_a", "travel character_id round-trips")
	_assert_equal(String(travel.get("zone_id", "")), "tatooine.mos_eisley.cantina", "travel zone_id round-trips")
	_assert_equal(String(travel.get("security_tier", "")), "contested", "travel security_tier round-trips")

	var win: Dictionary = by_type.get("window_resolve", {})
	_assert_equal(int(win.get("window", -1)), 42, "window_resolve window round-trips")
	_assert_equal(int(win.get("envelope_count", -1)), 3, "window_resolve envelope_count round-trips")

	_clean()
	_finish()

func _clean() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(TEST_DIR)

func _finish() -> void:
	if _failures.is_empty():
		print("telemetry_wire_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)

func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])
