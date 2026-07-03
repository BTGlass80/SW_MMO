extends RefCounted
## Pure siege / hostile-takeover state machine (docs/SIEGE_DESIGN.md §12.1). Deliberate-tempo,
## server-authoritative, socket-free, RNG-FREE (resolution is fully deterministic). This is the
## GAMEPLAY TRUTH for one-org-vs-org territory contests; the HOT netcode wiring (declare/join/status
## RPCs + Director-tick hook + effective-security gate) is a LATER slice and lives elsewhere.
##
## A siege is the only way one org (ATTACKER) takes a claimed node from another (DEFENDER) without
## consent. Spine: declared -> mustering -> assault(1..N) -> resolution -> cooldown, with an
## inter-assault 'lull' and three terminal archive states (captured / repelled / aborted). The
## contest is decided by a single scalar CONTROL METER [0..100] with a HIGH capture threshold (75)
## held for a duration; the meter accrues only from RESOLVED scoring events during assault windows
## and BLEEDS toward the defender (0) everywhere else. There is NO RNG anywhere here, so a siege is
## fully reproducible and resumes identically after a server restart (deterministic catch-up, §9).
##
## Two influence systems are kept separate (unchanged): the siege gate uses ORG/TERRITORY influence
## (territory_model.gd), NOT the Director's faction/zone influence (zone_state.gd).
##
## This model owns a COLLECTION of sieges (keyed by siege_id) because the declaration gate needs
## cross-siege facts: per-node "no active siege / not in cooldown" and per-org concurrency cap.
## It mirrors the to_dict()/apply_persisted() + slow-tick advance idioms of territory_model.gd /
## zone_state.gd. Divergence: DIV-0021 (docs/DIVERGENCE_LEDGER.md).
##
## Pure/socket-free so it is headlessly unit-testable. Config is SNAPSHOTTED into each siege at
## declaration so a live siege is immune to a mid-flight admin retune (§2/§8).

const SCHEMA_VERSION := 1
const TERMINAL_STATES := ["captured", "repelled", "aborted"]

# §8 — deliberate-tempo defaults. Every value is an owner-tunable named config field, snapshotted
# into a siege at declaration. Hours are wall-clock (converted to int seconds against `now`).
const DEFAULTS := {
	# Phase timers (hours)
	"declaration_grace_hours": 1.0,     # DECLARED dwell: cheap-withdraw grace + first notification
	"mustering_hours": 24.0,            # warning/prep window before assault #1 (allies commit here)
	"assault_count": 3,                 # number of scheduled assault windows (the N in assault(1..N))
	"assault_window_hours": 2.0,        # duration of each assault window
	"lull_hours": 6.0,                  # inter-assault regroup between windows
	"cooldown_hours": 168.0,            # node lockout after a resolved siege (7 days)
	"abort_cooldown_hours": 24.0,       # shorter node lockout after an aborted declaration
	# Capture math
	"control_min": 0.0,
	"control_max": 100.0,
	"control_start": 0.0,               # meter starts at the defender rest point
	"capture_threshold": 75.0,          # HIGH control needed to capture (early or final tally)
	"capture_hold_seconds": 900.0,      # continuous seconds >= threshold in an assault for early capture
	"control_bleed_per_hour": 10.0,     # meter decay toward control_min OUTSIDE assault windows
	# Scoring deltas (control-meter magnitudes; audit points are fixed in AUDIT_POINTS)
	"control_per_pvp_kill": 8.0,
	"control_per_guard_defeated": 12.0,
	"control_per_hold_tick": 2.0,
	"control_per_objective": 15.0,
	"control_per_sabotage": 6.0,
	# Gates & authority
	"attacker_min_influence": 40,       # Dominant tier (territory_model.gd DOMINANT_AT=40)
	"rank_to_declare": 4,               # attacker rank to declare / withdraw
	"rank_to_negotiate": 4,             # rank to concede / negotiate (either principal)
	"declare_cost_credits": 10000,      # war-chest escrowed from the attacker treasury at declaration
	"attacker_min_treasury": 10000,     # attacker treasury floor to declare (= declare_cost_credits)
	"withdraw_refund_fraction_grace": 1.0,  # war-chest refund on an in-grace withdrawal (0.0 after)
	# Concurrency & intervention
	"max_active_sieges_per_node": 1,
	"max_concurrent_attacks_per_org": 1,    # outgoing sieges an org may run at once (defenses unbounded)
	"intervention_mode": "mustering_only",  # none | mustering_only | open
	"max_allies_per_side": 1,
	"ally_min_influence": 20,           # claim-floor presence for an intervenor
	"ally_rank_to_commit": 4,
}

# §8 — compressed "prototype/dev" profile for small-population dev + fast tests: only the timers that
# would otherwise span real hours are shortened; all capture/scoring/gate values are unchanged so the
# mechanics under test match production. This is the CONSTRUCTOR DEFAULT so tests run fast.
const PROTOTYPE_OVERRIDES := {
	"declaration_grace_hours": 0.05,    # 180 s
	"mustering_hours": 0.25,            # 900 s
	"assault_count": 2,
	"assault_window_hours": 0.1,        # 360 s
	"lull_hours": 0.1,                  # 360 s
	"cooldown_hours": 0.5,              # 1800 s
	"abort_cooldown_hours": 0.1,        # 360 s
	"capture_hold_seconds": 60.0,
	"control_bleed_per_hour": 60.0,
}

# Fixed AUDIT points per scoring kind (§5). Distinct from the control-meter magnitude (config-tuned):
# audit points feed the "who fought" record + any future CP reward; the control_delta drives victory.
const AUDIT_POINTS := {
	"pvp_kill": 6.0,
	"guard_defeated": 10.0,
	"control_hold_tick": 2.0,
	"objective": 12.0,
	"sabotage": 5.0,
}
# Scoring kind -> the config key holding its control-meter magnitude.
const CONTROL_KEYS := {
	"pvp_kill": "control_per_pvp_kill",
	"guard_defeated": "control_per_guard_defeated",
	"control_hold_tick": "control_per_hold_tick",
	"objective": "control_per_objective",
	"sabotage": "control_per_sabotage",
}
# Kinds that can only ever be the attacker's (§5): breaking the guard, sabotaging defenses.
const ATTACKER_ONLY_KINDS := ["guard_defeated", "sabotage"]

var config: Dictionary = {}          # live/default config used as the snapshot at declaration
var sieges: Dictionary = {}          # siege_id -> siege dict (see data/schemas/siege_state.schema.json)
var _node_active_siege: Dictionary = {}  # node_id -> siege_id (NON-terminal only; DERIVED, rebuilt on restore)
var _seq: int = 0                    # auto siege-id counter

## Construct with the compressed prototype profile by default; pass default_config() (or any dict)
## for the deliberate-tempo production profile / a custom retune.
func _init(profile_config: Dictionary = {}) -> void:
	config = profile_config.duplicate(true) if not profile_config.is_empty() else prototype_config()

# --- config profiles (static) ---
static func default_config() -> Dictionary:
	return DEFAULTS.duplicate(true)

static func prototype_config() -> Dictionary:
	var c := DEFAULTS.duplicate(true)
	for k in PROTOTYPE_OVERRIDES:
		c[k] = PROTOTYPE_OVERRIDES[k]
	return c

static func _hours_secs(hours: Variant) -> int:
	return int(round(float(hours) * 3600.0))

static func _is_terminal(state: String) -> bool:
	return TERMINAL_STATES.has(state)

# --- reads ---
func has_siege(siege_id: String) -> bool:
	return sieges.has(siege_id)

func get_siege(siege_id: String) -> Dictionary:
	return sieges.get(siege_id, {})

func siege_count() -> int:
	return sieges.size()

func state_of(siege_id: String) -> String:
	return String((sieges.get(siege_id, {}) as Dictionary).get("state", ""))

func active_siege_for_node(node_id: String) -> String:
	return String(_node_active_siege.get(node_id, ""))

## pvp_consent is TRANSIENT and DERIVED: active is true iff state == assault. Never trusted from disk.
func pvp_consent_for(siege_id: String) -> Dictionary:
	var s: Dictionary = sieges.get(siege_id, {})
	if s.is_empty():
		return {"active": false, "scope_node_ids": []}
	return {
		"active": String(s.get("state", "")) == "assault",
		"scope_node_ids": ((s.get("pvp_consent", {}) as Dictionary).get("scope_node_ids", []) as Array).duplicate(),
	}

## Is a node free to be sieged right now? Returns {available, reason}. Blocks on a live siege (state
## in the non-terminal set, incl. the cooldown lockout window) and on an aborted-siege abort_cooldown.
func is_node_available(node_id: String, now: int) -> Dictionary:
	if _node_active_siege.has(node_id):
		var live: Dictionary = sieges[_node_active_siege[node_id]]
		if String(live.get("state", "")) == "cooldown":
			return {"available": false, "reason": "node_in_cooldown"}
		return {"available": false, "reason": "node_under_siege"}
	# Terminal abort lockouts (captured/repelled release the node at the cooldown-state boundary,
	# so their lockout_until_unix == archive time and never blocks post-archive).
	for sid in sieges:
		var s: Dictionary = sieges[sid]
		if String(s.get("node_id", "")) != node_id:
			continue
		if not _is_terminal(String(s.get("state", ""))):
			continue
		var oc: Variant = s.get("outcome", null)
		if oc != null and int((oc as Dictionary).get("lockout_until_unix", 0)) > now:
			return {"available": false, "reason": "node_in_cooldown"}
	return {"available": true, "reason": ""}

func _outgoing_attacks(org_id: String) -> int:
	var n := 0
	for sid in sieges:
		var s: Dictionary = sieges[sid]
		if String(s.get("attacker_org_id", "")) == org_id and not _is_terminal(String(s.get("state", ""))):
			n += 1
	return n

# --- §2 declaration validation ---
## Validate all declaration preconditions against `cfg` (defaults to params.config / self.config).
## Returns {ok, reason} — the first failed gate's reason, or {true, ""}.
func validate_declaration(params: Dictionary, cfg: Dictionary = {}) -> Dictionary:
	var c: Dictionary = cfg
	if c.is_empty():
		c = params.get("config", {})
	if c.is_empty():
		c = config
	var now := int(params.get("now", 0))
	# 2.2 base security is contested or lawless (secured / citizen-secured is immune)
	var base := String(params.get("zone_security_base", ""))
	if base != "contested" and base != "lawless":
		return {"ok": false, "reason": "base_not_contestable"}
	# 2.1/2.3 target node free (no active siege, not in cooldown)
	var avail := is_node_available(String(params.get("node_id", "")), now)
	if not bool(avail["available"]):
		return {"ok": false, "reason": String(avail["reason"])}
	# 2.4 attacker org influence in zone >= floor (Dominant tier)
	if int(params.get("attacker_influence", 0)) < int(c["attacker_min_influence"]):
		return {"ok": false, "reason": "influence_too_low"}
	# 2.5 declaring character rank >= rank_to_declare
	if int(params.get("declarer_rank", 0)) < int(c["rank_to_declare"]):
		return {"ok": false, "reason": "rank_too_low"}
	# 2.6 attacker treasury holds >= the war-chest cost
	var treasury := int(params.get("attacker_treasury", 0))
	if treasury < int(c["attacker_min_treasury"]) or treasury < int(c["declare_cost_credits"]):
		return {"ok": false, "reason": "insufficient_treasury"}
	# 2.7 attacker under its outgoing-attack concurrency cap
	if _outgoing_attacks(String(params.get("attacker_org_id", ""))) >= int(c["max_concurrent_attacks_per_org"]):
		return {"ok": false, "reason": "concurrency_cap"}
	return {"ok": true, "reason": ""}

## Declare a siege. Validates §2; on success snapshots `config`, escrows the war-chest onto the
## record (the CALLER debits the org treasury — this model is pure), and opens the DECLARED grace
## window. Returns {ok, reason, siege_id, war_chest_credits}. `params.scope_node_ids` (optional,
## default [node_id]) = the contested node + declared adjacency for the pvp_consent scope.
func declare(params: Dictionary) -> Dictionary:
	var cfg: Dictionary = params.get("config", {})
	if cfg.is_empty():
		cfg = config
	var v := validate_declaration(params, cfg)
	if not bool(v["ok"]):
		return {"ok": false, "reason": String(v["reason"]), "siege_id": "", "war_chest_credits": 0}
	var now := int(params["now"])
	var sid := String(params.get("siege_id", ""))
	if sid == "":
		_seq += 1
		sid = "sg_%04d" % _seq
	var grace := _hours_secs(cfg["declaration_grace_hours"])
	var node_id := String(params["node_id"])
	var scope: Array = params.get("scope_node_ids", [node_id])
	var wc := int(cfg["declare_cost_credits"])
	var siege := {
		"schema_version": SCHEMA_VERSION,
		"siege_id": sid,
		"claim_id": String(params.get("claim_id", "")),
		"node_id": node_id,
		"zone_id": String(params.get("zone_id", "")),
		"defender_org_id": String(params.get("defender_org_id", "")),
		"attacker_org_id": String(params["attacker_org_id"]),
		"declared_by_char_id": String(params.get("declared_by_char_id", "")),
		"state": "declared",
		"phase_started_unix": now,
		"phase_deadline_unix": now + grace,
		"declared_unix": now,
		"war_chest_credits": wc,
		"config": cfg.duplicate(true),
		"schedule": {"current_assault_index": 0, "assault_windows": []},
		"control_meter": {
			"value": float(cfg["control_start"]),
			"updated_unix": now,
			"hold_since_unix": null,
			"peak": float(cfg["control_start"]),
		},
		"pvp_consent": {"active": false, "scope_node_ids": scope.duplicate()},
		"intervenors": [],
		"score": {"attacker_points": 0.0, "defender_points": 0.0, "contributions": []},
		"outcome": null,
		"extra": {},
	}
	sieges[sid] = siege
	_node_active_siege[node_id] = sid
	return {"ok": true, "reason": "", "siege_id": sid, "war_chest_credits": wc}

# --- §3 phase advancement (slow-tick / restart catch-up) ---
## Advance one siege to wall-clock `now`, crossing AS MANY phase boundaries as elapsed (the §9
## deterministic catch-up), applying control bleed for non-assault spans and re-deriving pvp_consent.
## Idempotent for a fixed `now`. Call this from the server slow tick; NEVER let a client drive it.
func advance(siege_id: String, now: int) -> void:
	if not sieges.has(siege_id):
		return
	_advance_siege(sieges[siege_id], now)

## Advance every non-terminal siege to `now` (Director slow-tick convenience).
func advance_all(now: int) -> void:
	for sid in sieges:
		var s: Dictionary = sieges[sid]
		if not _is_terminal(String(s["state"])):
			_advance_siege(s, now)

func _advance_siege(s: Dictionary, now: int) -> void:
	var guard := 0
	while not _is_terminal(String(s["state"])):
		guard += 1
		if guard > 100000:
			break  # safety valve against a mis-scheduled infinite loop
		if not _step(s, now):
			break
	_settle(s, now)

# Cross at most ONE boundary if its wall-clock has been reached. Returns whether it transitioned.
func _step(s: Dictionary, now: int) -> bool:
	var st := String(s["state"])
	if _is_terminal(st):
		return false
	var b := _boundary_for(s)
	if b > now:
		return false
	if st != "assault":
		_bleed_to(s, b)  # apply the non-assault bleed span up to the boundary before transitioning
	_transition_at(s, b)
	return true

# Wall-clock of the current state's next automatic transition. For an assault this is the earlier of
# the window end and the early-capture instant (hold_since + capture_hold_seconds).
func _boundary_for(s: Dictionary) -> int:
	var st := String(s["state"])
	if st == "assault":
		var end := int(s["phase_deadline_unix"])
		var hs: Variant = s["control_meter"]["hold_since_unix"]
		if hs != null:
			var cap := int(hs) + int(s["config"]["capture_hold_seconds"])
			return mini(end, cap)
		return end
	return int(s["phase_deadline_unix"])

func _transition_at(s: Dictionary, b: int) -> void:
	match String(s["state"]):
		"declared":
			_to_mustering(s, b)
		"mustering":
			_to_assault(s, b, 0)
		"assault":
			_assault_boundary(s, b)
		"lull":
			_to_assault(s, b, int(s["schedule"]["current_assault_index"]))
		"resolution":
			_to_cooldown(s, b)
		"cooldown":
			_to_archive(s, b)

func _to_mustering(s: Dictionary, b: int) -> void:
	var cfg: Dictionary = s["config"]
	# §3.3 fixed schedule: assault #0 starts at mustering end; windows are window+lull apart.
	var first_start := b + _hours_secs(cfg["mustering_hours"])
	s["schedule"] = {"current_assault_index": 0, "assault_windows": _build_windows(first_start, cfg)}
	s["state"] = "mustering"
	s["phase_started_unix"] = b
	s["phase_deadline_unix"] = first_start
	s["control_meter"]["updated_unix"] = b
	s["pvp_consent"]["active"] = false

func _to_assault(s: Dictionary, b: int, index: int) -> void:
	var cfg: Dictionary = s["config"]
	var win: Dictionary = s["schedule"]["assault_windows"][index]
	win["status"] = "active"
	s["schedule"]["current_assault_index"] = index
	s["state"] = "assault"
	s["phase_started_unix"] = b
	s["phase_deadline_unix"] = int(win["end_unix"])
	var m: Dictionary = s["control_meter"]
	m["updated_unix"] = b
	# A fresh window: only carry a hold if control already sits at/above threshold at window start.
	m["hold_since_unix"] = b if float(m["value"]) >= float(cfg["capture_threshold"]) else null
	s["pvp_consent"]["active"] = true

func _to_lull(s: Dictionary, b: int) -> void:
	var ci := int(s["schedule"]["current_assault_index"]) + 1
	s["schedule"]["current_assault_index"] = ci
	s["state"] = "lull"
	s["phase_started_unix"] = b
	s["phase_deadline_unix"] = int(s["schedule"]["assault_windows"][ci]["start_unix"])
	s["control_meter"]["updated_unix"] = b
	s["pvp_consent"]["active"] = false

# Assault window boundary: either an early capture (hold-for-duration) short-circuit, or the window
# end -> lull (if more remain) / resolution final tally (if it was the last).
func _assault_boundary(s: Dictionary, b: int) -> void:
	var cfg: Dictionary = s["config"]
	var m: Dictionary = s["control_meter"]
	var end := int(s["phase_deadline_unix"])
	var ci := int(s["schedule"]["current_assault_index"])
	var early := false
	var hs: Variant = m["hold_since_unix"]
	if hs != null:
		var cap := int(hs) + int(cfg["capture_hold_seconds"])
		if cap <= b and cap <= end:
			early = true
	s["schedule"]["assault_windows"][ci]["status"] = "complete"
	m["hold_since_unix"] = null
	s["pvp_consent"]["active"] = false
	if early:
		_to_resolution(s, b, true, "")
	elif ci + 1 < int(cfg["assault_count"]):
		_to_lull(s, b)
	else:
		_to_resolution(s, b, false, "")

# Enter resolution (a 1-tick tally). `forced` overrides the control-tally result: "" = tally
# (value >= capture_threshold -> captured else repelled), "captured" = defender concede,
# "repelled" = attacker mid-siege concede/withdraw. War-chest is always forfeit past the grace window.
func _to_resolution(s: Dictionary, b: int, early: bool, forced: String) -> void:
	var cfg: Dictionary = s["config"]
	var m: Dictionary = s["control_meter"]
	var final_control := float(m["value"])
	var result := forced
	if result == "":
		result = "captured" if final_control >= float(cfg["capture_threshold"]) else "repelled"
	s["state"] = "resolution"
	s["phase_started_unix"] = b
	s["phase_deadline_unix"] = b  # single tick -> flushes to cooldown on the same advance
	m["hold_since_unix"] = null
	m["updated_unix"] = b
	s["pvp_consent"]["active"] = false
	s["outcome"] = {
		"result": result,
		"resolved_unix": b,
		"final_control": final_control,
		"early_capture": early,
		"war_chest_disposition": "forfeit",
		"news_headline": _headline(s, result),
		"lockout_until_unix": 0,
	}

func _to_cooldown(s: Dictionary, b: int) -> void:
	var cd := _hours_secs(s["config"]["cooldown_hours"])
	s["state"] = "cooldown"
	s["phase_started_unix"] = b
	s["phase_deadline_unix"] = b + cd
	s["control_meter"]["updated_unix"] = b
	s["pvp_consent"]["active"] = false
	s["war_chest_credits"] = 0  # forfeit on any resolved siege (spent on the war)
	if s["outcome"] != null:
		s["outcome"]["lockout_until_unix"] = b + cd

func _to_archive(s: Dictionary, b: int) -> void:
	s["state"] = String((s["outcome"] as Dictionary)["result"])  # captured / repelled
	s["phase_started_unix"] = b
	s["phase_deadline_unix"] = b
	s["pvp_consent"]["active"] = false
	_node_active_siege.erase(String(s["node_id"]))

# Apply the non-assault control bleed for the span [meter.updated_unix, to_time], clamped to bounds.
func _bleed_to(s: Dictionary, to_time: int) -> void:
	var m: Dictionary = s["control_meter"]
	var cfg: Dictionary = s["config"]
	var from := int(m["updated_unix"])
	if to_time <= from:
		return
	var hours := float(to_time - from) / 3600.0
	var bleed := float(cfg["control_bleed_per_hour"]) * hours
	var newv := clampf(float(m["value"]) - bleed, float(cfg["control_min"]), float(cfg["control_max"]))
	m["value"] = newv
	m["updated_unix"] = to_time
	if newv < float(cfg["capture_threshold"]):
		m["hold_since_unix"] = null

# After all boundaries at/<= now are crossed: apply residual non-assault bleed up to now (so a status
# read reflects a perishable lead) and RE-DERIVE pvp_consent from state (never from disk).
func _settle(s: Dictionary, now: int) -> void:
	var st := String(s["state"])
	if not _is_terminal(st) and st != "assault":
		_bleed_to(s, now)
	_derive_pvp(s)

func _derive_pvp(s: Dictionary) -> void:
	s["pvp_consent"]["active"] = String(s["state"]) == "assault"

static func _build_windows(first_start: int, cfg: Dictionary) -> Array:
	var count := int(cfg["assault_count"])
	var wsec := _hours_secs(cfg["assault_window_hours"])
	var lsec := _hours_secs(cfg["lull_hours"])
	var arr: Array = []
	for i in count:
		var start := first_start + i * (wsec + lsec)
		arr.append({"index": i, "start_unix": start, "end_unix": start + wsec, "status": "pending"})
	return arr

func _headline(s: Dictionary, result: String) -> String:
	var a := String(s["attacker_org_id"])
	var d := String(s["defender_org_id"])
	var n := String(s["node_id"])
	match result:
		"captured":
			return "%s seizes %s from %s." % [a, n, d]
		"repelled":
			return "%s holds %s against %s." % [d, n, a]
		"aborted":
			return "%s calls off the siege of %s." % [a, n]
	return ""

# --- §5 scoring (assault-window only; RESOLVED server outcomes, never raw client input) ---
## Apply a resolved scoring event to the control meter + audit. event = {kind, side?, char_id?,
## org_id?}. kind in {pvp_kill, guard_defeated, objective, sabotage} (use apply_hold_tick for holds).
## Only mutates during an assault window. Returns {ok, reason, control_delta, value}.
func apply_scoring_event(siege_id: String, event: Dictionary, now: int) -> Dictionary:
	if not sieges.has(siege_id):
		return {"ok": false, "reason": "unknown_siege"}
	var s: Dictionary = sieges[siege_id]
	if String(s["state"]) != "assault":
		return {"ok": false, "reason": "not_in_assault"}
	var kind := String(event.get("kind", ""))
	if not CONTROL_KEYS.has(kind):
		return {"ok": false, "reason": "bad_kind"}
	if kind == "control_hold_tick":
		return {"ok": false, "reason": "use_apply_hold_tick"}
	var side := String(event.get("side", ""))
	if ATTACKER_ONLY_KINDS.has(kind):
		side = "attacker"
	if side != "attacker" and side != "defender":
		return {"ok": false, "reason": "bad_side"}
	return _apply_control(s, now, side, kind, String(event.get("char_id", "")), String(event.get("org_id", "")))

## §5 control-hold tick: whichever side has strictly MORE living in-scope members gains
## control_per_hold_tick toward its direction; a tie does nothing. Deterministic from presence counts.
func apply_hold_tick(siege_id: String, attacker_present: int, defender_present: int, now: int) -> Dictionary:
	if not sieges.has(siege_id):
		return {"ok": false, "reason": "unknown_siege"}
	var s: Dictionary = sieges[siege_id]
	if String(s["state"]) != "assault":
		return {"ok": false, "reason": "not_in_assault"}
	var side := ""
	if attacker_present > defender_present:
		side = "attacker"
	elif defender_present > attacker_present:
		side = "defender"
	else:
		return {"ok": true, "reason": "tie", "control_delta": 0.0, "value": float(s["control_meter"]["value"])}
	return _apply_control(s, now, side, "control_hold_tick", "", "")

# Shared control-meter mutation: clamp the meter, accrue UNCLAMPED audit points, track peak + the
# early-capture hold window, and append a replayable contributions[] row (raw points + control_delta).
func _apply_control(s: Dictionary, now: int, side: String, kind: String, char_id: String, org_id: String) -> Dictionary:
	var cfg: Dictionary = s["config"]
	var m: Dictionary = s["control_meter"]
	var mag := float(cfg.get(CONTROL_KEYS[kind], 0.0))
	var pts := float(AUDIT_POINTS.get(kind, 0.0))
	var old := float(m["value"])
	var signed := mag if side == "attacker" else -mag
	var newv := clampf(old + signed, float(cfg["control_min"]), float(cfg["control_max"]))
	var delta := newv - old  # ACTUAL applied delta after clamping (schema: "after clamping context")
	m["value"] = newv
	m["updated_unix"] = now
	if newv > float(m["peak"]):
		m["peak"] = newv
	# Early-capture continuity: set hold_since the instant we reach threshold; clear it the instant we drop below.
	if newv >= float(cfg["capture_threshold"]):
		if m["hold_since_unix"] == null:
			m["hold_since_unix"] = now
	else:
		m["hold_since_unix"] = null
	# Audit totals are cumulative + UNCLAMPED (never bled): they drive the "who fought" record.
	if side == "attacker":
		s["score"]["attacker_points"] = float(s["score"]["attacker_points"]) + pts
	else:
		s["score"]["defender_points"] = float(s["score"]["defender_points"]) + pts
	var row := {
		"unix": now,
		"side": side,
		"kind": kind,
		"assault_index": int(s["schedule"]["current_assault_index"]),
		"points": pts,
		"control_delta": delta,
	}
	if char_id != "":
		row["char_id"] = char_id
	if org_id != "":
		row["org_id"] = org_id
	(s["score"]["contributions"] as Array).append(row)
	return {"ok": true, "reason": "", "control_delta": delta, "value": newv}

# --- §6 third-party intervention ---
## Validate an ally commit (§6): intervention_mode window, rank/influence floors, per-side cap, not a
## principal, not already committed. Returns {ok, reason}.
func validate_ally_commit(siege_id: String, params: Dictionary) -> Dictionary:
	if not sieges.has(siege_id):
		return {"ok": false, "reason": "unknown_siege"}
	var s: Dictionary = sieges[siege_id]
	var cfg: Dictionary = s["config"]
	var mode := String(cfg["intervention_mode"])
	var st := String(s["state"])
	if mode == "none":
		return {"ok": false, "reason": "intervention_disabled"}
	elif mode == "mustering_only":
		if st != "mustering":
			return {"ok": false, "reason": "not_mustering"}
	elif mode == "open":
		# Allies may commit any time BEFORE the final assault begins.
		var last := int(cfg["assault_count"]) - 1
		var ok_window := st == "mustering" or st == "lull" or (st == "assault" and int(s["schedule"]["current_assault_index"]) < last)
		if not ok_window:
			return {"ok": false, "reason": "window_closed"}
	var side := String(params.get("side", ""))
	if side != "attacker" and side != "defender":
		return {"ok": false, "reason": "bad_side"}
	if int(params.get("committer_rank", 0)) < int(cfg["ally_rank_to_commit"]):
		return {"ok": false, "reason": "rank_too_low"}
	if int(params.get("ally_influence", 0)) < int(cfg["ally_min_influence"]):
		return {"ok": false, "reason": "influence_too_low"}
	var org := String(params.get("org_id", ""))
	if org == String(s["attacker_org_id"]) or org == String(s["defender_org_id"]):
		return {"ok": false, "reason": "is_principal"}
	var count_side := 0
	for iv in s["intervenors"]:
		if String((iv as Dictionary)["org_id"]) == org:
			return {"ok": false, "reason": "already_committed"}
		if String((iv as Dictionary)["side"]) == side:
			count_side += 1
	if count_side >= int(cfg["max_allies_per_side"]):
		return {"ok": false, "reason": "ally_cap"}
	return {"ok": true, "reason": ""}

## Commit an intervening org to a side. Validates via validate_ally_commit; on success appends an
## intervenor row. Returns {ok, reason, intervenor}.
func commit_ally(siege_id: String, params: Dictionary, now: int) -> Dictionary:
	var v := validate_ally_commit(siege_id, params)
	if not bool(v["ok"]):
		return {"ok": false, "reason": String(v["reason"]), "intervenor": {}}
	var s: Dictionary = sieges[siege_id]
	var iv := {
		"org_id": String(params["org_id"]),
		"side": String(params["side"]),
		"committed_unix": now,
		"committed_by_char_id": String(params.get("committed_by_char_id", "")),
	}
	(s["intervenors"] as Array).append(iv)
	return {"ok": true, "reason": "", "intervenor": iv}

# --- rank-gated mid-siege actions (§2 table) ---
## Attacker withdraws (rank_to_declare). declared -> aborted+refund (per withdraw_refund_fraction_grace);
## mustering -> aborted (war-chest forfeit); assault/lull -> concede down the repelled path (resolution
## -> cooldown, forfeit). Returns {ok, reason, result, war_chest_disposition, refund_credits}.
func withdraw(siege_id: String, char_rank: int, now: int) -> Dictionary:
	if not sieges.has(siege_id):
		return {"ok": false, "reason": "unknown_siege"}
	var s: Dictionary = sieges[siege_id]
	var cfg: Dictionary = s["config"]
	if char_rank < int(cfg["rank_to_declare"]):
		return {"ok": false, "reason": "rank_too_low"}
	var st := String(s["state"])
	if st == "declared":
		var frac := float(cfg["withdraw_refund_fraction_grace"])
		var refund := int(round(float(s["war_chest_credits"]) * frac))
		var disp := "refunded_full" if frac >= 1.0 else ("refunded_partial" if frac > 0.0 else "forfeit")
		_abort(s, now, disp)
		return {"ok": true, "reason": "", "result": "aborted", "war_chest_disposition": disp, "refund_credits": refund}
	elif st == "mustering":
		_abort(s, now, "forfeit")
		return {"ok": true, "reason": "", "result": "aborted", "war_chest_disposition": "forfeit", "refund_credits": 0}
	elif st == "assault" or st == "lull":
		_to_resolution(s, now, false, "repelled")
		_advance_siege(s, now)  # flush resolution -> cooldown
		return {"ok": true, "reason": "", "result": "repelled", "war_chest_disposition": "forfeit", "refund_credits": 0}
	return {"ok": false, "reason": "not_withdrawable"}

## Defender concedes / surrenders the node (rank_to_negotiate) -> resolution captured -> cooldown.
## Returns {ok, reason, result, refund_credits}.
func concede(siege_id: String, char_rank: int, now: int) -> Dictionary:
	if not sieges.has(siege_id):
		return {"ok": false, "reason": "unknown_siege"}
	var s: Dictionary = sieges[siege_id]
	var cfg: Dictionary = s["config"]
	if char_rank < int(cfg["rank_to_negotiate"]):
		return {"ok": false, "reason": "rank_too_low"}
	var st := String(s["state"])
	if st == "declared" or st == "mustering" or st == "assault" or st == "lull":
		_to_resolution(s, now, false, "captured")
		_advance_siege(s, now)  # flush resolution -> cooldown
		return {"ok": true, "reason": "", "result": "captured", "refund_credits": 0}
	return {"ok": false, "reason": "not_concedable"}

## Server-fed guard: if the attacker's zone influence falls below the gate during declared/mustering,
## the siege aborts (refund in grace, forfeit after). Returns {ok, aborted, ...}.
func enforce_influence_gate(siege_id: String, attacker_influence: int, now: int) -> Dictionary:
	if not sieges.has(siege_id):
		return {"ok": false, "aborted": false, "reason": "unknown_siege"}
	var s: Dictionary = sieges[siege_id]
	var cfg: Dictionary = s["config"]
	var st := String(s["state"])
	if (st == "declared" or st == "mustering") and attacker_influence < int(cfg["attacker_min_influence"]):
		if st == "declared":
			var frac := float(cfg["withdraw_refund_fraction_grace"])
			var refund := int(round(float(s["war_chest_credits"]) * frac))
			var disp := "refunded_full" if frac >= 1.0 else ("refunded_partial" if frac > 0.0 else "forfeit")
			_abort(s, now, disp)
			return {"ok": true, "aborted": true, "result": "aborted", "war_chest_disposition": disp, "refund_credits": refund}
		_abort(s, now, "forfeit")
		return {"ok": true, "aborted": true, "result": "aborted", "war_chest_disposition": "forfeit", "refund_credits": 0}
	return {"ok": true, "aborted": false}

func _abort(s: Dictionary, now: int, disposition: String) -> void:
	var cfg: Dictionary = s["config"]
	var lock := now + _hours_secs(cfg["abort_cooldown_hours"])
	s["state"] = "aborted"
	s["phase_started_unix"] = now
	s["phase_deadline_unix"] = now
	s["war_chest_credits"] = 0  # refund (if any) is credited back to the treasury by the caller
	s["pvp_consent"]["active"] = false
	s["outcome"] = {
		"result": "aborted",
		"resolved_unix": now,
		"final_control": float(s["control_meter"]["value"]),
		"early_capture": false,
		"war_chest_disposition": disposition,
		"news_headline": _headline(s, "aborted"),
		"lockout_until_unix": lock,
	}
	_node_active_siege.erase(String(s["node_id"]))

# --- §9 persistence & restart survival ---
## Serialize every siege. pvp_consent.active is stored but RE-DERIVED from state on restore (never
## trusted from disk). The _node_active_siege index is DERIVED and rebuilt on restore.
func to_dict() -> Dictionary:
	var out := {}
	for sid in sieges:
		out[sid] = (sieges[sid] as Dictionary).duplicate(true)
	return {"schema_version": SCHEMA_VERSION, "seq": _seq, "sieges": out}

## Restore the state produced by to_dict(). Re-derives pvp_consent.active from state and rebuilds the
## node->active-siege index. The first advance() after boot applies the deterministic catch-up (§9).
func apply_persisted(data: Dictionary) -> void:
	if data.is_empty():
		return
	_seq = int(data.get("seq", _seq))
	sieges = {}
	_node_active_siege = {}
	var saved: Dictionary = data.get("sieges", {})
	for sid in saved:
		var s: Dictionary = (saved[sid] as Dictionary).duplicate(true)
		if not s.has("pvp_consent"):
			s["pvp_consent"] = {"active": false, "scope_node_ids": []}
		# Re-derive transient consent from state; never trust the persisted flag.
		s["pvp_consent"]["active"] = String(s.get("state", "")) == "assault"
		sieges[sid] = s
		if not _is_terminal(String(s.get("state", ""))):
			_node_active_siege[String(s.get("node_id", ""))] = sid
