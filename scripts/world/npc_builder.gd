extends RefCounted
## Procedural low-poly builder for NAMED NPCs (data/npcs_clone_wars.json) — the visual
## substrate for the game's persistent, story-flavored population, as distinct from the
## plain ambient-NPC capsules (scripts/net/net_world.gd:_spawn_npc) and the hostile combat
## targets (scripts/world/monster_builder.gd). Same blocky BoxMesh + StandardMaterial3D art
## language as scripts/world/world_builder.gd and monster_builder.gd — no textures, no
## per-vertex art.
##
## Pure construction: build_npc() returns a fresh, unparented Node3D tree that a future
## caller adds into the world and positions/orients. No gameplay state, no input, no
## autoloads, no RNG — every look is a deterministic hash of the NPC's own name (plus
## kind/faction_axis), so every client renders the exact same "Kayson" and the exact same
## "Djas Puhr" without any networked appearance data. Headlessly unit-testable.
##
## KINDS (role-flavored silhouette, independent of faction_axis):
##   "civilian" (default/fallback) - plain humanoid, no extra props.
##   "vendor"    - a crate/stall prop at their side (they're selling something).
##   "official"  - taller, narrower, cleaner build + a chest sash (customs/traffic control).
##   "hunter"    - darker palette + a shoulder pauldron (bounty hunter silhouette).
##   "thug"      - bulkier build + oversized fists (enforcer/highwayman silhouette).
##   "mechanic"  - a grimy apron + belt tool (Docking Bay repair trade).
##   "broker"    - a hooded cloak envelope (deal-maker who prefers the shadows).
##   "pilot"     - a flight helmet with a visor stripe.
## An unrecognized kind falls back to "civilian" rather than failing.
##
## FACTION_AXIS tint (data/npcs_clone_wars.json's five axes) gives every NPC a base body
## color, then a small deterministic per-name jitter keeps individuals within an axis from
## looking identical: republic bluish, cis grey, hutt greenish/olive, independent neutral
## tan, bounty_hunters_guild dark. An unrecognized axis falls back to a neutral tan.

const FACTION_TINTS := {
	"republic": Color(0.32, 0.40, 0.58),
	"cis": Color(0.53, 0.54, 0.56),
	"hutt": Color(0.40, 0.46, 0.27),
	"independent": Color(0.62, 0.52, 0.36),
	"bounty_hunters_guild": Color(0.22, 0.20, 0.19),
}
const DEFAULT_TINT := Color(0.52, 0.47, 0.40)

const KIND_LABELS := {
	"civilian": "Civilian",
	"vendor": "Vendor",
	"official": "Official",
	"hunter": "Bounty Hunter",
	"thug": "Thug",
	"mechanic": "Mechanic",
	"broker": "Broker",
	"pilot": "Pilot",
}

# A small deterministic palette of plausible skin/hide tones (human + a few alien reads)
# so distinct named NPCs vary in a species-plausible way without per-species art.
const SKIN_TONES := [
	Color(0.80, 0.62, 0.48),  # human tan
	Color(0.55, 0.38, 0.24),  # human dark tan
	Color(0.90, 0.78, 0.62),  # human pale
	Color(0.34, 0.55, 0.35),  # green (e.g. Ishi Tib / Twi'lek-adjacent read)
	Color(0.60, 0.62, 0.68),  # grey (droid-adjacent / Sakiyan-adjacent read)
	Color(0.45, 0.30, 0.55),  # purple (Twi'lek-adjacent read)
	Color(0.63, 0.45, 0.26),  # Jawa-adjacent hide tone
]

# --- entry point ---
## Build a named NPC's low-poly figure. `kind` selects the role silhouette/props (falls
## back to "civilian" if unrecognized); `faction_axis` selects the base body tint (falls
## back to a neutral tan if unrecognized). Everything is a deterministic function of the
## three arguments — no RNG.
func build_npc(kind: String, display_name: String, faction_axis: String = "independent") -> Node3D:
	var k := kind if KIND_LABELS.has(kind) else "civilian"

	# Check for high-fidelity custom voxel actor scenes
	var actor_path := ""
	var name_lower := display_name.to_lower()
	if name_lower.contains("stamp") or name_lower.contains("dust") or name_lower.contains("clone"):
		actor_path = "res://assets/3d/generated/google/clone_commander_v1/clone_commander_actor.tscn"
	elif name_lower.contains("chalmun") or name_lower.contains("wookiee"):
		actor_path = "res://assets/3d/generated/google/wookiee_v1/wookiee_actor.tscn"
	elif name_lower.contains("ruzz-tha") or name_lower.contains("jawa"):
		actor_path = "res://assets/3d/generated/google/jawa_v1/jawa_actor.tscn"
	elif name_lower.contains("greeshk") or name_lower.contains("weequay"):
		actor_path = "res://assets/3d/generated/google/weequay_v1/weequay_actor.tscn"
	elif name_lower.contains("djas puhr") or name_lower.contains("abyssinian"):
		actor_path = "res://assets/3d/generated/google/abyssinian_v1/abyssinian_actor.tscn"
	elif name_lower.contains("talon") or name_lower.contains("officer"):
		actor_path = "res://assets/3d/generated/google/republic_officer_v1/republic_officer_actor.tscn"
	elif name_lower.contains("b1") or name_lower.contains("battle droid"):
		actor_path = "res://assets/3d/generated/google/droid_b1_character_v1/droid_b1_actor.tscn"


	if actor_path != "" and ResourceLoader.exists(actor_path):
		var root := Node3D.new()
		root.name = "NPC_" + display_name.replace(" ", "_").replace("\"", "")
		var actor: Node3D = load(actor_path).instantiate() as Node3D
		actor.name = "Actor"
		actor.position = Vector3(0, 0, 0)
		root.add_child(actor)
		
		# Play default animations based on role/status
		var anim_player: AnimationPlayer = actor.find_child("AnimationPlayer", true, false)
		if anim_player != null:
			if anim_player.has_animation("aim") and (name_lower.contains("guard") or name_lower.contains("patrol") or name_lower.contains("enforcer") or name_lower.contains("thug")):
				anim_player.play("aim")
			elif anim_player.has_animation("walk") and name_lower.contains("drifter"):
				anim_player.play("walk")
			else:
				anim_player.stop()
				
		_nameplate(root, display_name, kind_pretty(k), 1.9)
		return root

	var root := Node3D.new()
	root.name = "NPC_%s" % k.capitalize()


	var body_col := faction_tint(faction_axis, display_name)
	var skin_col := skin_tone(display_name)

	var height_mult := 1.0
	var width_mult := 1.0
	var torso_col := body_col
	match k:
		"official":
			height_mult = 1.08
			width_mult = 0.90
			torso_col = body_col.lightened(0.05)
		"thug":
			height_mult = 0.96
			width_mult = 1.22
			torso_col = body_col.darkened(0.10)
		"hunter":
			torso_col = body_col.darkened(0.22)
		"broker":
			width_mult = 0.94
			torso_col = body_col.darkened(0.14)

	var m := _build_body(root, torso_col, skin_col, height_mult, width_mult)

	match k:
		"vendor":
			_add_vendor_stall(root, m, body_col)
		"official":
			_add_official_sash(root, m, body_col)
		"hunter":
			_add_hunter_pauldron(root, m, body_col.darkened(0.35))
		"thug":
			_add_thug_fists(root, m, body_col.darkened(0.20))
		"mechanic":
			_add_mechanic_apron(root, m, body_col.darkened(0.42))
		"broker":
			_add_broker_cloak(root, m, body_col.darkened(0.25))
		"pilot":
			_add_pilot_helmet(root, m, body_col.darkened(0.45))
		_:
			pass  # civilian: plain body, no extra props

	_nameplate(root, display_name, kind_pretty(k), float(m["head_y"]) + 0.55)
	return root

## Pretty-print a kind for the nameplate's role line. Unrecognized kinds read "Civilian".
func kind_pretty(kind: String) -> String:
	return String(KIND_LABELS.get(kind, "Civilian"))

## Deterministic body tint: FACTION_TINTS[faction_axis] (or a neutral fallback) lightened
## or darkened by a small hash-derived jitter (+/-8%) keyed on the NPC's own name, so two
## NPCs sharing an axis still read as individuals while the axis stays recognizable.
func faction_tint(faction_axis: String, display_name: String) -> Color:
	var base: Color = FACTION_TINTS.get(faction_axis, DEFAULT_TINT)
	var h := absi(hash("%s|%s" % [display_name, faction_axis]))
	var t := fposmod(float(h) * 0.6180339887, 1.0)  # 0..1, deterministic per name+axis
	var amount: float = (t - 0.5) * 0.16  # -0.08 .. 0.08
	if amount >= 0.0:
		return base.lightened(amount)
	return base.darkened(-amount)

## Deterministic skin/hide tone hashed from the NPC's own name (independent of faction).
func skin_tone(display_name: String) -> Color:
	var h := absi(hash("%s|skin" % display_name))
	var idx := h % SKIN_TONES.size()
	return SKIN_TONES[idx]

# --- humanoid body (torso + head + limbs from boxes, ~1.7m at height_mult 1.0) ---
# Returns key measurements ({hip_y, shoulder_y, head_y, torso_w, torso_h}) so kind-specific
# prop helpers can attach at the right height regardless of height_mult/width_mult.
func _build_body(root: Node3D, torso_col: Color, skin_col: Color, height_mult: float, width_mult: float) -> Dictionary:
	var leg_h := 0.85 * height_mult
	var torso_h := 0.55 * height_mult
	var neck_h := 0.12
	var head_h := 0.28

	var leg_w := 0.16 * width_mult
	var leg_d := 0.18 * width_mult
	var leg_spread := 0.13 * width_mult
	var torso_w := 0.46 * width_mult
	var torso_d := 0.26 * width_mult
	var arm_w := 0.14 * width_mult

	var hip_y := leg_h
	var shoulder_y := hip_y + torso_h
	var head_y := shoulder_y + neck_h + head_h * 0.5

	var limb_col := torso_col.darkened(0.28)

	# Legs.
	add_box(root, Vector3(-leg_spread, leg_h * 0.5, 0.0), Vector3(leg_w, leg_h, leg_d), limb_col)
	add_box(root, Vector3(leg_spread, leg_h * 0.5, 0.0), Vector3(leg_w, leg_h, leg_d), limb_col)
	# Torso.
	add_box(root, Vector3(0.0, hip_y + torso_h * 0.5, 0.0), Vector3(torso_w, torso_h, torso_d), torso_col)
	# Arms.
	var arm_x := torso_w * 0.5 + arm_w * 0.5
	add_box(root, Vector3(-arm_x, hip_y + torso_h * 0.55, 0.0), Vector3(arm_w, torso_h * 0.9, arm_w * 1.1), torso_col.darkened(0.12))
	add_box(root, Vector3(arm_x, hip_y + torso_h * 0.55, 0.0), Vector3(arm_w, torso_h * 0.9, arm_w * 1.1), torso_col.darkened(0.12))
	# Neck + head.
	add_box(root, Vector3(0.0, shoulder_y + neck_h * 0.5, 0.0), Vector3(0.14, neck_h, 0.14), skin_col)
	add_box(root, Vector3(0.0, head_y, 0.0), Vector3(0.30, head_h, 0.30), skin_col)

	return {
		"hip_y": hip_y,
		"shoulder_y": shoulder_y,
		"head_y": head_y,
		"torso_w": torso_w,
		"torso_h": torso_h,
	}

# --- kind-specific props (small, tasteful, blocky) ---
func _add_vendor_stall(root: Node3D, m: Dictionary, base_col: Color) -> void:
	var x := float(m["torso_w"]) * 0.5 + 0.55
	add_box(root, Vector3(x, 0.35, 0.0), Vector3(0.5, 0.7, 0.5), Color(0.35, 0.25, 0.16))
	add_box(root, Vector3(x, 0.72, 0.0), Vector3(0.58, 0.06, 0.58), base_col.darkened(0.2))

func _add_official_sash(root: Node3D, m: Dictionary, base_col: Color) -> void:
	var shoulder_y: float = m["shoulder_y"]
	add_box(root, Vector3(0.0, shoulder_y - 0.10, 0.14), Vector3(0.34, 0.10, 0.05), base_col.lightened(0.35))
	add_box(root, Vector3(0.12, shoulder_y - 0.04, 0.15), Vector3(0.08, 0.08, 0.05), Color(0.85, 0.75, 0.25))

func _add_hunter_pauldron(root: Node3D, m: Dictionary, col: Color) -> void:
	var shoulder_y: float = m["shoulder_y"]
	var arm_x: float = float(m["torso_w"]) * 0.5 + 0.05
	add_box(root, Vector3(arm_x, shoulder_y - 0.02, 0.0), Vector3(0.22, 0.16, 0.24), col)

func _add_thug_fists(root: Node3D, m: Dictionary, col: Color) -> void:
	var hip_y: float = m["hip_y"]
	var arm_x: float = float(m["torso_w"]) * 0.5 + 0.20
	add_box(root, Vector3(-arm_x, hip_y + 0.05, 0.0), Vector3(0.18, 0.18, 0.18), col)
	add_box(root, Vector3(arm_x, hip_y + 0.05, 0.0), Vector3(0.18, 0.18, 0.18), col)

func _add_mechanic_apron(root: Node3D, m: Dictionary, col: Color) -> void:
	var hip_y: float = m["hip_y"]
	var torso_w: float = m["torso_w"]
	var torso_h: float = m["torso_h"]
	add_box(root, Vector3(0.0, hip_y + torso_h * 0.35, 0.14), Vector3(torso_w * 0.9, torso_h * 0.75, 0.05), col)
	add_box(root, Vector3(0.20, hip_y + 0.05, 0.16), Vector3(0.08, 0.08, 0.08), Color(0.62, 0.55, 0.16))

func _add_broker_cloak(root: Node3D, m: Dictionary, col: Color) -> void:
	var shoulder_y: float = m["shoulder_y"]
	var head_y: float = m["head_y"]
	var torso_w: float = m["torso_w"]
	var torso_h: float = m["torso_h"]
	add_box(root, Vector3(0.0, shoulder_y - torso_h * 0.3, -0.10), Vector3(torso_w + 0.12, torso_h + 0.35, 0.28), col)
	add_box(root, Vector3(0.0, head_y + 0.12, -0.06), Vector3(0.36, 0.14, 0.36), col.darkened(0.1))

func _add_pilot_helmet(root: Node3D, m: Dictionary, col: Color) -> void:
	var head_y: float = m["head_y"]
	add_box(root, Vector3(0.0, head_y, 0.0), Vector3(0.34, 0.30, 0.34), col)
	add_box(root, Vector3(0.0, head_y - 0.02, -0.15), Vector3(0.24, 0.10, 0.06), Color(0.16, 0.55, 0.65))

# --- primitives (mesh-only; named NPCs are dialogue targets, not combat targets, so no
# collision is built here — a future caller adds interaction volumes as needed) ---
func add_box(parent: Node3D, local_pos: Vector3, size: Vector3, color: Color, roughness: float = 0.9) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = local_pos
	mesh_instance.material_override = make_material(color, roughness)
	parent.add_child(mesh_instance)
	return mesh_instance

func make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _nameplate(root: Node3D, display_name: String, role_text: String, y: float) -> void:

	var label := Label3D.new()
	label.name = "Nameplate"
	var name_text := display_name if display_name != "" else "Local"
	label.text = "%s\n%s" % [name_text, role_text] if role_text != "" else name_text
	label.position = Vector3(0.0, y, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.modulate = Color(0.09, 0.08, 0.06)
	label.visible = OS.get_cmdline_args().has("--debug-world-labels")
	root.add_child(label)
