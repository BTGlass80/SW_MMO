extends SceneTree
## Headless smoke test for the named-NPC visual builder (scripts/world/npc_builder.gd) —
## the richer, role/faction-distinct figure a future caller will render for
## data/npcs_clone_wars.json entries (as opposed to net_world.gd's plain ambient-NPC
## capsules or monster_builder.gd's hostile combat targets). Verifies every KIND builds a
## nameplated humanoid mesh tree, that faction-axis tint is DETERMINISTIC per name+axis and
## visibly differs across axes, and that an unrecognized kind/axis falls back gracefully
## instead of crashing.

const NpcBuilder := preload("res://scripts/world/npc_builder.gd")

const KINDS := ["civilian", "vendor", "official", "hunter", "thug", "mechanic", "broker", "pilot"]
const AXES := ["republic", "cis", "hutt", "independent", "bounty_hunters_guild"]

var _failures: Array[String] = []

func _init() -> void:
	var builder := NpcBuilder.new()

	# --- every known kind builds a Node3D with a nameplate carrying the NPC's name ---
	for kind in KINDS:
		var npc := builder.build_npc(kind, "Test NPC %s" % kind, "independent")
		_assert_true(npc is Node3D, "kind '%s' builds a Node3D" % kind)
		_assert_true(_mesh_count(npc) >= 6, "kind '%s' builds a blocky torso/head/limb body (got %d meshes)" % [kind, _mesh_count(npc)])
		_assert_true(_has_nameplate(npc, "Test NPC %s" % kind), "kind '%s' carries a nameplate with its name" % kind)
		npc.free()

	# --- faction tint: deterministic per name+axis ---
	var t1 := builder.faction_tint("republic", "Lt. Vesh Talon")
	var t2 := builder.faction_tint("republic", "Lt. Vesh Talon")
	_assert_true(t1.is_equal_approx(t2), "faction_tint is deterministic for the same name+axis")

	# --- faction tint: differs across axes (same name held constant) ---
	var seen_colors: Array[Color] = []
	for axis in AXES:
		seen_colors.append(builder.faction_tint(axis, "Same Name"))
	for i in range(seen_colors.size()):
		for j in range(i + 1, seen_colors.size()):
			_assert_true(not seen_colors[i].is_equal_approx(seen_colors[j]), "faction_tint('%s') differs from faction_tint('%s')" % [AXES[i], AXES[j]])

	# --- faction tint: two different NPCs on the same axis still individuate (jitter) ---
	var a := builder.faction_tint("hutt", "Hutt Enforcer Greeshk")
	var b := builder.faction_tint("hutt", "Some Other Hutt Goon")
	_assert_true(not a.is_equal_approx(b), "same-axis NPCs with different names get distinct tint jitter")

	# --- unknown kind falls back gracefully (no crash) ---
	var fallback_npc := builder.build_npc("some_totally_unknown_kind", "Mystery Figure", "independent")
	_assert_true(fallback_npc is Node3D, "unknown kind still returns a Node3D")
	_assert_true(_has_nameplate(fallback_npc, "Mystery Figure"), "unknown kind still carries a nameplate")
	fallback_npc.free()

	# --- unknown faction_axis falls back gracefully (no crash) ---
	var fallback_axis_npc := builder.build_npc("civilian", "Nobody Special", "some_unknown_axis")
	_assert_true(fallback_axis_npc is Node3D, "unknown faction_axis still returns a Node3D")
	fallback_axis_npc.free()

	# --- empty name falls back gracefully (no crash) ---
	var empty_name_npc := builder.build_npc("civilian", "", "independent")
	_assert_true(empty_name_npc is Node3D, "empty display_name still returns a Node3D")
	empty_name_npc.free()

	_finish()

func _has_nameplate(root: Node3D, name_text: String) -> bool:
	var label := root.get_node_or_null("Nameplate") as Label3D
	return label != null and label.text.begins_with(name_text)

func _mesh_count(root: Node3D) -> int:
	var n := 0
	for child in root.get_children():
		if child is MeshInstance3D:
			n += 1
	return n

func _finish() -> void:
	if _failures.is_empty():
		print("npc_builder_smoke: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(actual: bool, label: String) -> void:
	if not actual:
		_failures.append("%s: expected true" % label)
