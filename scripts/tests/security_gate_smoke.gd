extends SceneTree
## Headless smoke test for the effective-security gate (E7).
## Verifies each §3.2 precedence case INDEPENDENTLY: room override replace, city-citizen
## upgrade + safety floor (holds against a later overlay downgrade), territory-claim
## upgrade, Director overlay (hutt surge / republic crackdown), the tier helpers, and
## that a plain base with empty ctx returns the base unchanged.

const SecurityGate := preload("res://scripts/net/security_gate.gd")

var _failures: Array[String] = []

func _init() -> void:
	var gate: SecurityGate = SecurityGate.new()

	# (0) Plain base, empty ctx -> base unchanged (for each tier).
	_assert_equal(gate.get_effective_security("secured", {}), "secured", "empty ctx returns base secured")
	_assert_equal(gate.get_effective_security("contested", {}), "contested", "empty ctx returns base contested")
	_assert_equal(gate.get_effective_security("lawless", {}), "lawless", "empty ctx returns base lawless")

	# (1) Room faction override REPLACES the base.
	_assert_equal(
		gate.get_effective_security("secured", {"room_override": "lawless"}),
		"lawless",
		"room override lawless on secured base -> lawless")

	# (2) City citizen upgrade one step...
	_assert_equal(
		gate.get_effective_security("contested", {"is_city_citizen": true}),
		"secured",
		"citizen on contested base -> secured")
	# ...AND the citizen safety floor HOLDS against a later overlay downgrade.
	_assert_equal(
		gate.get_effective_security("contested", {"is_city_citizen": true, "hutt_influence": 90}),
		"secured",
		"citizen floor holds: contested + hutt_influence 90 still -> secured")

	# (3) Territory claim upgrade: claimed lawless node -> contested for owning-org member.
	_assert_equal(
		gate.get_effective_security("lawless", {"is_claim_member": true}),
		"contested",
		"claim member on lawless base -> contested")

	# (4) Director overlay (transient).
	_assert_equal(
		gate.get_effective_security("secured", {"hutt_influence": 85}),
		"contested",
		"hutt_influence 85 on secured base downgrades -> contested")
	_assert_equal(
		gate.get_effective_security("contested", {"republic_crackdown_active": true}),
		"secured",
		"active republic crackdown on contested base upgrades -> secured")

	# (5) Tier helpers (clamped at the ends; more_secure picks the safer).
	_assert_equal(gate.upgrade_tier("secured"), "secured", "upgrade clamps at secured")
	_assert_equal(gate.upgrade_tier("lawless"), "contested", "upgrade lawless -> contested")
	_assert_equal(gate.upgrade_tier("contested"), "secured", "upgrade contested -> secured")
	_assert_equal(gate.downgrade_tier("lawless"), "lawless", "downgrade clamps at lawless")
	_assert_equal(gate.downgrade_tier("secured"), "contested", "downgrade secured -> contested")
	_assert_equal(gate.downgrade_tier("contested"), "lawless", "downgrade contested -> lawless")
	_assert_equal(gate.upgrade_tier("nonsense"), "secured", "unknown tier upgrade -> secured")
	_assert_equal(gate.downgrade_tier("nonsense"), "secured", "unknown tier downgrade -> secured")
	_assert_equal(gate.more_secure("contested", "lawless"), "contested", "more_secure picks contested over lawless")
	_assert_equal(gate.more_secure("secured", "contested"), "secured", "more_secure picks secured over contested")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("security_gate_smoke: OK")
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
