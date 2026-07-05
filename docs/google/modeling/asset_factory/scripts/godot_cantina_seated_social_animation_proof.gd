extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)
const OUT_ROOT := "res://docs/gpt/asset_factory/generated/godot_cantina_seated_social_anim_v0"
const SCENE_DIR := OUT_ROOT + "/review_scenes"
const CAPTURE_DIR := OUT_ROOT + "/captures"
const BAR_BAY_GLB := "res://docs/gpt/asset_factory/generated/blockbench_cantina_bar_booth_bay_v1/glb/blockbench_cantina_bar_booth_bay_v1.glb"
const ANIM_SCENE := SCENE_DIR + "/cantina_seated_social_animation_player.tscn"

var _captures: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_make_dirs()
	await _save_and_capture(
		"seated_social_contact_sheet",
		_build_contact_sheet_scene(),
		"Contact sheet: four key poses using the same booth anchors and kept bar/booth GLB."
	)
	await _save_and_capture(
		"seated_idle_pair",
		_build_pose_scene("SeatedIdlePair", "idle"),
		"Two blockcraft actors seated at named booth anchors. This proves scale and default sit posture."
	)
	await _save_and_capture(
		"lean_talk_keyframe",
		_build_pose_scene("LeanTalkKeyframe", "talk"),
		"Talk keyframe: the left actor leans forward and gestures while the right actor listens."
	)
	await _save_and_capture(
		"drink_loop_keyframe",
		_build_pose_scene("DrinkLoopKeyframe", "drink"),
		"Drink keyframe: right-hand cup socket and arm lift tested from the same camera."
	)
	await _save_and_capture(
		"turn_to_speaker_keyframe",
		_build_pose_scene("TurnToSpeakerKeyframe", "turn"),
		"Turn-to-speaker keyframe: heads and torsos rotate toward the active speaker."
	)
	_save_scene(_build_animation_player_scene(), ANIM_SCENE)
	_write_review()
	print("Godot Cantina seated-social animation proof generated %s captures" % _captures.size())
	quit()


func _make_dirs() -> void:
	for path in [OUT_ROOT, SCENE_DIR, CAPTURE_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _build_pose_scene(name: String, pose: String) -> Node3D:
	var root := _base_scene(name, Color("#6f4426"), Color("#6d8790"), 0.34)
	_add_room_context(root, Vector3.ZERO)
	_add_model(root, BAR_BAY_GLB, "kept_bar_booth_bay_glb", Vector3.ZERO, Vector3(0, 180, 0), 1.0)
	_add_booth_animation_anchors(root, Vector3.ZERO)
	_add_social_pair(root, Vector3.ZERO, pose)
	_add_mood_lighting_and_camera(root, Vector3(0, 0.94, -0.28), 6.0)
	return root


func _build_contact_sheet_scene() -> Node3D:
	var root := _base_scene("SeatedSocialContactSheet", Color("#6f4426"), Color("#738991"), 0.36)
	var poses := ["idle", "talk", "drink", "turn"]
	var labels := ["idle", "talk", "drink", "turn"]
	var offsets := [
		Vector3(-3.1, 0, -2.05),
		Vector3(3.1, 0, -2.05),
		Vector3(-3.1, 0, 2.05),
		Vector3(3.1, 0, 2.05),
	]
	for i in range(poses.size()):
		var offset: Vector3 = offsets[i]
		_add_room_context(root, offset)
		_add_model(root, BAR_BAY_GLB, "bar_booth_%s" % poses[i], offset, Vector3(0, 180, 0), 1.0)
		_add_booth_animation_anchors(root, offset)
		_add_social_pair(root, offset, poses[i])
		_add_floor_label_blocks(root, offset + Vector3(0, 0.08, -2.55), labels[i])
	_add_side_by_side_lighting_and_camera(root, Vector3(0, 0.9, 0.0), 12.0)
	return root


func _build_animation_player_scene() -> Node3D:
	var root := _build_pose_scene("CantinaSeatedSocialAnimationPlayer", "idle")
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("..")
	root.add_child(player)

	var library := AnimationLibrary.new()
	library.add_animation("sit_idle_loop", _make_sit_idle_animation())
	library.add_animation("lean_talk_loop", _make_lean_talk_animation())
	library.add_animation("drink_loop", _make_drink_animation())
	library.add_animation("turn_to_speaker_loop", _make_turn_to_speaker_animation())
	player.add_animation_library("", library)
	return root


func _add_social_pair(root: Node3D, offset: Vector3, pose: String) -> void:
	var actors := Node3D.new()
	actors.name = "Actors"
	root.add_child(actors)

	_add_seated_actor(
		actors,
		"LeftPatron",
		offset + Vector3(-0.58, 0.0, -1.42),
		Color("#d8e0dc"),
		Color("#aeb8bb"),
		Color("#2f4e8f"),
		pose,
		true
	)
	_add_seated_actor(
		actors,
		"RightPatron",
		offset + Vector3(0.58, 0.0, -1.42),
		Color("#9d6d3d"),
		Color("#6e5134"),
		Color("#202327"),
		pose,
		false
	)

	_add_box(root, "anim_booth_bench_left", offset + Vector3(-0.58, 0.34, -1.16), Vector3(0.62, 0.22, 0.88), Color("#963a32"))
	_add_box(root, "anim_booth_bench_right", offset + Vector3(0.58, 0.34, -1.16), Vector3(0.62, 0.22, 0.88), Color("#963a32"))
	_add_box(root, "anim_booth_back_left", offset + Vector3(-0.58, 0.72, -0.78), Vector3(0.68, 0.78, 0.18), Color("#6f2925"))
	_add_box(root, "anim_booth_back_right", offset + Vector3(0.58, 0.72, -0.78), Vector3(0.68, 0.78, 0.18), Color("#6f2925"))
	_add_box(root, "shared_booth_table", offset + Vector3(0, 0.48, -1.58), Vector3(1.05, 0.16, 0.72), Color("#6f4426"))
	_add_box(root, "table_warm_top", offset + Vector3(0, 0.58, -1.58), Vector3(1.1, 0.06, 0.77), Color("#dfba72"))
	_add_box(root, "table_cup_center", offset + Vector3(0.18, 0.74, -1.62), Vector3(0.12, 0.22, 0.12), Color("#27d7ff"))
	if pose == "talk":
		_add_box(root, "talk_beat_a", offset + Vector3(-0.34, 1.45, -1.73), Vector3(0.12, 0.12, 0.12), Color("#27d7ff"))
		_add_box(root, "talk_beat_b", offset + Vector3(-0.12, 1.56, -1.73), Vector3(0.09, 0.09, 0.09), Color("#27d7ff"))


func _add_seated_actor(parent: Node3D, actor_name: String, position: Vector3, body_color: Color, head_color: Color, visor_color: Color, pose: String, is_left_actor: bool) -> Node3D:
	var actor := Node3D.new()
	actor.name = actor_name
	actor.position = position
	actor.rotation_degrees.y = -12.0 if is_left_actor else 12.0
	parent.add_child(actor)

	var torso_rot := Vector3.ZERO
	var head_rot := Vector3.ZERO
	var left_arm_rot := Vector3(8, 0, -8)
	var right_arm_rot := Vector3(8, 0, 8)
	if pose == "talk" and is_left_actor:
		torso_rot = Vector3(-7, 0, 0)
		head_rot = Vector3(-4, -12, 0)
		left_arm_rot = Vector3(-28, 0, -62)
		right_arm_rot = Vector3(-16, 0, 42)
	elif pose == "talk":
		head_rot = Vector3(0, 18, 0)
	elif pose == "drink" and is_left_actor:
		right_arm_rot = Vector3(-65, 0, 26)
		head_rot = Vector3(-6, -8, 0)
	elif pose == "turn":
		torso_rot = Vector3(0, -16, 0) if is_left_actor else Vector3(0, 16, 0)
		head_rot = Vector3(0, -28, 0) if is_left_actor else Vector3(0, 28, 0)

	var torso := _add_box(actor, "Torso", Vector3(0, 0.76, 0), Vector3(0.38, 0.68, 0.28), body_color)
	torso.rotation_degrees = torso_rot
	var head := _add_box(actor, "Head", Vector3(0, 1.22, -0.02), Vector3(0.34, 0.3, 0.32), head_color)
	head.rotation_degrees = head_rot
	var visor := _add_box(actor, "Visor", Vector3(0, 1.23, -0.2), Vector3(0.22, 0.06, 0.04), visor_color)
	visor.rotation_degrees = head_rot
	var left_arm := _add_box(actor, "LeftArm", Vector3(-0.31, 0.77, -0.04), Vector3(0.12, 0.44, 0.12), body_color.darkened(0.08))
	left_arm.rotation_degrees = left_arm_rot
	var right_arm := _add_box(actor, "RightArm", Vector3(0.31, 0.77, -0.04), Vector3(0.12, 0.44, 0.12), body_color.darkened(0.08))
	right_arm.rotation_degrees = right_arm_rot

	_add_box(actor, "LeftThigh", Vector3(-0.11, 0.43, -0.2), Vector3(0.14, 0.16, 0.48), body_color.darkened(0.18))
	_add_box(actor, "RightThigh", Vector3(0.11, 0.43, -0.2), Vector3(0.14, 0.16, 0.48), body_color.darkened(0.18))
	_add_box(actor, "LeftBoot", Vector3(-0.11, 0.29, -0.54), Vector3(0.16, 0.14, 0.24), Color("#202327"))
	_add_box(actor, "RightBoot", Vector3(0.11, 0.29, -0.54), Vector3(0.16, 0.14, 0.24), Color("#202327"))

	if pose == "drink" and is_left_actor:
		_add_box(actor, "RightHandCup", Vector3(0.35, 1.03, -0.2), Vector3(0.1, 0.15, 0.1), Color("#27d7ff"))

	return actor


func _add_booth_animation_anchors(root: Node3D, offset: Vector3) -> void:
	_add_marker(root, "seat_anchor_a", offset + Vector3(-0.58, 0.13, -1.42), Color("#27d7ff"))
	_add_marker(root, "seat_anchor_b", offset + Vector3(0.58, 0.13, -1.42), Color("#27d7ff"))
	_add_marker(root, "table_anchor", offset + Vector3(0, 0.61, -1.58), Color("#ffb14a"))
	_add_marker(root, "look_target_a", offset + Vector3(-0.35, 1.28, -1.7), Color("#d7a736"))
	_add_marker(root, "look_target_b", offset + Vector3(0.35, 1.28, -1.7), Color("#d7a736"))


func _add_marker(root: Node3D, node_name: String, position: Vector3, color: Color) -> void:
	var marker := _add_box(root, node_name, position, Vector3(0.12, 0.06, 0.12), color)
	marker.name = node_name


func _add_room_context(root: Node3D, offset: Vector3) -> void:
	_add_box(root, "floor_plate", offset + Vector3(0, 0.02, 0), Vector3(5.8, 0.06, 4.1), Color("#2e2520"))
	_add_box(root, "booth_shadow_pool", offset + Vector3(0, 0.055, -0.78), Vector3(3.4, 0.03, 1.5), Color("#171312"))


func _add_floor_label_blocks(root: Node3D, position: Vector3, label: String) -> void:
	var color := Color("#27d7ff")
	if label == "talk":
		color = Color("#ffb14a")
	elif label == "drink":
		color = Color("#d7a736")
	elif label == "turn":
		color = Color("#e6eceb")
	for i in range(label.length()):
		_add_box(root, "label_%s_%s" % [label, i], position + Vector3(float(i) * 0.16 - 0.36, 0, 0), Vector3(0.1, 0.08, 0.1), color)


func _make_sit_idle_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 1.2
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(anim, "Actors/LeftPatron/Head:rotation_degrees", [
		{"time": 0.0, "value": Vector3(0, 0, 0)},
		{"time": 0.6, "value": Vector3(2, -4, 0)},
		{"time": 1.2, "value": Vector3(0, 0, 0)},
	])
	_add_value_track(anim, "Actors/RightPatron/Head:rotation_degrees", [
		{"time": 0.0, "value": Vector3(0, 0, 0)},
		{"time": 0.6, "value": Vector3(1, 5, 0)},
		{"time": 1.2, "value": Vector3(0, 0, 0)},
	])
	return anim


func _make_lean_talk_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 1.4
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(anim, "Actors/LeftPatron/Torso:rotation_degrees", [
		{"time": 0.0, "value": Vector3(0, 0, 0)},
		{"time": 0.7, "value": Vector3(-7, 0, 0)},
		{"time": 1.4, "value": Vector3(0, 0, 0)},
	])
	_add_value_track(anim, "Actors/LeftPatron/LeftArm:rotation_degrees", [
		{"time": 0.0, "value": Vector3(8, 0, -8)},
		{"time": 0.7, "value": Vector3(-28, 0, -62)},
		{"time": 1.4, "value": Vector3(8, 0, -8)},
	])
	return anim


func _make_drink_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 1.6
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(anim, "Actors/LeftPatron/RightArm:rotation_degrees", [
		{"time": 0.0, "value": Vector3(8, 0, 8)},
		{"time": 0.8, "value": Vector3(-65, 0, 26)},
		{"time": 1.6, "value": Vector3(8, 0, 8)},
	])
	_add_value_track(anim, "Actors/LeftPatron/Head:rotation_degrees", [
		{"time": 0.0, "value": Vector3(0, 0, 0)},
		{"time": 0.8, "value": Vector3(-6, -8, 0)},
		{"time": 1.6, "value": Vector3(0, 0, 0)},
	])
	return anim


func _make_turn_to_speaker_animation() -> Animation:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(anim, "Actors/LeftPatron/Head:rotation_degrees", [
		{"time": 0.0, "value": Vector3(0, 0, 0)},
		{"time": 0.5, "value": Vector3(0, -28, 0)},
		{"time": 1.0, "value": Vector3(0, 0, 0)},
	])
	_add_value_track(anim, "Actors/RightPatron/Head:rotation_degrees", [
		{"time": 0.0, "value": Vector3(0, 0, 0)},
		{"time": 0.5, "value": Vector3(0, 28, 0)},
		{"time": 1.0, "value": Vector3(0, 0, 0)},
	])
	return anim


func _add_value_track(animation: Animation, path: String, keys: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	for key in keys:
		animation.track_insert_key(track, key["time"], key["value"])


func _base_scene(name: String, ambient: Color, background: Color, ambient_energy: float) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient.lightened(0.12)
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_model(root: Node3D, path: String, node_name: String, position: Vector3, rotation_degrees: Vector3, scale_factor: float) -> Node3D:
	var imported: Node = null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(ProjectSettings.globalize_path(path), state)
	if err == OK:
		imported = document.generate_scene(state)

	if imported == null:
		push_error("Could not import GLB model: %s" % path)
		return _add_box(root, node_name + "_missing", position + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), Color("#ff00ff"))

	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	holder.rotation_degrees = rotation_degrees
	holder.scale = Vector3.ONE * scale_factor
	holder.add_child(imported)
	root.add_child(holder)
	return holder


func _add_box(root: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	root.add_child(inst)
	return inst


func _add_mood_lighting_and_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "WarmInteriorSun"
	sun.rotation_degrees = Vector3(-32, -42, -8)
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 2.35
	sun.shadow_enabled = true
	root.add_child(sun)

	var bar_fill := OmniLight3D.new()
	bar_fill.name = "WarmBarFill"
	bar_fill.position = target + Vector3(0, 0.8, 1.2)
	bar_fill.light_color = Color("#ffb45a")
	bar_fill.light_energy = 0.85
	bar_fill.omni_range = 5.2
	root.add_child(bar_fill)

	_add_camera(root, target, camera_size)


func _add_side_by_side_lighting_and_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "ContactSheetWarmSun"
	sun.rotation_degrees = Vector3(-34, -42, -8)
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 2.35
	sun.shadow_enabled = true
	root.add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "ContactSheetBarFill"
	fill.position = target + Vector3(0, 3, 2.2)
	fill.light_color = Color("#ffb45a")
	fill.light_energy = 0.72
	fill.omni_range = 18.0
	root.add_child(fill)

	_add_camera(root, target, camera_size)


func _add_camera(root: Node3D, target: Vector3, camera_size: float) -> void:
	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	var camera_vector := Vector3(1.0, 0.82, -1.0)
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color == Color("#27d7ff") or color == Color("#ffb14a") or color == Color("#d7a736"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.75
	return mat


func _save_and_capture(name: String, scene: Node3D, description: String) -> void:
	var scene_path := SCENE_DIR + "/%s.tscn" % name
	var capture_path := CAPTURE_DIR + "/%s.png" % name
	_save_scene(scene, scene_path)
	await _capture_scene(scene, capture_path)
	_captures.append({
		"id": name,
		"description": description,
		"scene_path": scene_path,
		"capture_path": capture_path,
	})
	scene.queue_free()


func _save_scene(root: Node3D, path: String) -> void:
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("Failed to pack %s: %s" % [path, pack_err])
		return
	var save_err := ResourceSaver.save(packed, path)
	if save_err != OK:
		push_error("Failed to save %s: %s" % [path, save_err])
	else:
		print("Saved scene: %s" % ProjectSettings.globalize_path(path))


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


func _capture_scene(scene: Node3D, out_path: String) -> void:
	get_root().size = CAPTURE_SIZE
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(CAPTURE_SIZE)
	get_root().add_child(scene)
	for i in range(8):
		await process_frame
	var image := get_root().get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		push_error("Failed to save capture %s: %s" % [out_path, err])
	else:
		print("Saved capture: %s" % ProjectSettings.globalize_path(out_path))
	get_root().remove_child(scene)


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# Godot Cantina Seated Social Animation v0")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/gpt/asset_factory/scripts/godot_cantina_seated_social_animation_proof.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Answer the first animation-protocol question with a concrete docs-only proof: two blockcraft actors can sit, talk, drink, and turn toward each other in the kept Cantina bar/booth module without changing the module GLB.")
	lines.append("")
	lines.append("## Controlled Change")
	lines.append("")
	lines.append("Baseline: `generated/godot_cantina_bar_booth_bay_v1/REVIEW.md`")
	lines.append("")
	lines.append("Changed variable: static social props -> named seated anchors, procedural blockcraft actors, key poses, and a saved Godot `AnimationPlayer` proof scene.")
	lines.append("")
	lines.append("Kept fixed:")
	lines.append("")
	lines.append("- `blockbench_cantina_bar_booth_bay_v1.glb` source and orientation")
	lines.append("- bar/booth material family")
	lines.append("- Godot review camera family")
	lines.append("- docs-only boundary")
	lines.append("")
	lines.append("## Generated Animation Proof Scene")
	lines.append("")
	lines.append("`review_scenes/cantina_seated_social_animation_player.tscn`")
	lines.append("")
	lines.append("Clip names in the proof scene:")
	lines.append("")
	lines.append("- `sit_idle_loop`")
	lines.append("- `lean_talk_loop`")
	lines.append("- `drink_loop`")
	lines.append("- `turn_to_speaker_loop`")
	lines.append("")
	lines.append("Anchor names used:")
	lines.append("")
	lines.append("- `seat_anchor_a`")
	lines.append("- `seat_anchor_b`")
	lines.append("- `table_anchor`")
	lines.append("- `look_target_a`")
	lines.append("- `look_target_b`")
	lines.append("")
	lines.append("Actor part names used:")
	lines.append("")
	lines.append("- `Actors/LeftPatron/Torso`")
	lines.append("- `Actors/LeftPatron/Head`")
	lines.append("- `Actors/LeftPatron/LeftArm`")
	lines.append("- `Actors/LeftPatron/RightArm`")
	lines.append("- matching `RightPatron` parts")
	lines.append("")
	lines.append("## Captures")
	lines.append("")
	for entry in _captures:
		var capture := String(entry["capture_path"]).replace(OUT_ROOT + "/", "")
		lines.append("### %s" % entry["id"])
		lines.append("")
		lines.append(entry["description"])
		lines.append("")
		lines.append("![%s](%s)" % [entry["id"], capture])
		lines.append("")
	lines.append("## Verdict")
	lines.append("")
	lines.append("Candidate protocol keep, not a final animation pack.")
	lines.append("")
	lines.append("This proof is useful because it gives Claude a concrete request shape for social/environment animation: name the scene baseline, name anchors, name clip loops, capture key poses, and save a Godot proof. It is not enough for clone-trooper combat movement, which still needs a shared rig and Blender/glTF animation validation.")
	lines.append("")
	lines.append("## Next One-Variable Recommendation")
	lines.append("")
	lines.append("Create a `shared_blockcraft_humanoid_rig_v0` contract and test only two clone rifleman clips next: `idle_rifle_loop` and `fire_rifle_once`. Keep the rifleman body scale fixed and validate the clip names after Godot import.")
	lines.append("")

	var file := FileAccess.open(OUT_ROOT + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("Saved review: %s" % ProjectSettings.globalize_path(OUT_ROOT + "/REVIEW.md"))
