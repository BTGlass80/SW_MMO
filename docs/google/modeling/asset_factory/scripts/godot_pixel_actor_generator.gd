extends SceneTree

const CAPTURE_SIZE := Vector2i(1280, 720)

var _character_id := ""
var _display_name := ""
var _cell_size := 0.075
var _output_dir := ""

var _palette_colors := {}
var _palette_hex := {}
var _parts_def := {}
var _skeleton_def := {}
var _anims_def := {}

var _source_paths := {}
var _stats := {}
var _captures := []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var spec_path := _parse_spec_path()
	if not _load_spec(spec_path):
		printerr("Failed to load character spec: %s" % spec_path)
		quit(1)
		return
		
	_make_dirs()
	_ensure_source_cards()
	
	# Generate captures
	await _save_and_capture(
		"body_part_source_cards",
		_build_source_cards_scene(),
		"Original B1 Battle Droid body-part front and side pixel cards, generated programmatically from the spec JSON."
	)
	await _save_and_capture(
		"body_part_neutral_vs_aim",
		_build_neutral_vs_aim_scene(),
		"B1 Battle Droid model. Left: neutral structural assembly using local bone pivots. Right: aim pose with E-5 blaster aimed forward."
	)
	await _save_and_capture(
		"body_part_rotation_contact_sheet",
		_build_rotation_sheet_scene(),
		"Four yaw angles (0, 90, 180, 270) of the assembled B1 Battle Droid model, demonstrating full 3D visual volume consistency."
	)
	await _save_and_capture(
		"body_part_walk_cycle_contact_sheet",
		_build_walk_cycle_scene(),
		"Four frames of the B1 Battle Droid walk animation (0.0s, 0.3s, 0.6s, 0.9s), demonstrating keyframe interpolation on joint nodes."
	)
	
	# Generate standalone clean actor scene
	var clean_holder := Node3D.new()
	var clean_actor := _assemble_actor(clean_holder, _character_id, Vector3.ZERO)
	_save_scene(clean_actor, _output_dir + "/%s_actor.tscn" % _character_id)
	clean_holder.queue_free()
	
	_write_manifest(spec_path)
	_write_review()
	
	print("Godot pixel actor generator completed: %s captures written to %s" % [_captures.size(), _output_dir])
	quit()


func _parse_spec_path() -> String:
	var user_args := OS.get_cmdline_user_args()
	var spec_path := ""
	for i in range(user_args.size()):
		if user_args[i] == "--spec" and i + 1 < user_args.size():
			spec_path = user_args[i + 1]
			break
	if spec_path == "":
		var args := OS.get_cmdline_args()
		for i in range(args.size()):
			if args[i] == "--spec" and i + 1 < args.size():
				spec_path = args[i + 1]
				break
	if spec_path == "":
		spec_path = "res://docs/google/modeling/asset_factory/specs/droid_b1_character.json"
	return spec_path


func _load_spec(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var content := file.get_as_text()
	var json = JSON.parse_string(content)
	if not json:
		return false
		
	_character_id = json["character_id"]
	_display_name = json["display_name"]
	_cell_size = float(json.get("cell_size", 0.075))
	_output_dir = json["output_dir"]
	
	# Load palette
	var pal: Dictionary = json["palette"]
	_palette_hex = {}
	_palette_colors = {}
	for hex in pal.keys():
		var category = pal[hex]
		var clean_hex = hex.to_lower().replace("#", "")
		_palette_hex[clean_hex] = category
		_palette_colors[category] = Color("#" + clean_hex)
		
	_parts_def = json["parts"]
	_skeleton_def = json["skeleton"]
	_anims_def = json["animations"]
	
	return true


func _make_dirs() -> void:
	for path in [_output_dir, _output_dir + "/source_images", _output_dir + "/review_scenes", _output_dir + "/captures"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _ensure_source_cards() -> void:
	for part_name in _parts_def.keys():
		var def: Dictionary = _parts_def[part_name]
		var front_path := _output_dir + "/source_images/%s_front.png" % part_name
		var side_path := _output_dir + "/source_images/%s_side.png" % part_name
		_source_paths[part_name] = {"front": front_path, "side": side_path}
		
		var fp_exists := FileAccess.file_exists(front_path)
		var sd_exists := FileAccess.file_exists(side_path)
		
		if not fp_exists or not sd_exists:
			var front_size: Array = def["front"]
			var side_size: Array = def["side"]
			var front := Image.create_empty(int(front_size[0]), int(front_size[1]), false, Image.FORMAT_RGBA8)
			var side := Image.create_empty(int(side_size[0]), int(side_size[1]), false, Image.FORMAT_RGBA8)
			front.fill(Color(0, 0, 0, 0))
			side.fill(Color(0, 0, 0, 0))
			_draw_default_part_cards(part_name, front, side)
			
			if not fp_exists:
				_save_image(front, front_path)
			if not sd_exists:
				_save_image(side, side_path)


func _draw_default_part_cards(part_name: String, front: Image, side: Image) -> void:
	if _character_id == "droid_b1":
		var tan := Color("#d3c19b")
		var shadow := Color("#a99672")
		var metal := Color("#30343a")
		var cyan := Color("#27d7ff")
		var wood := Color("#6c4b35")
		match part_name:
			"head":
				_fill_rect(front, 2, 7, 2, 2, metal) # Neck bracket
				_fill_rect(front, 1, 1, 4, 6, tan)
				_fill_rect(front, 2, 0, 2, 1, tan)
				_fill_rect(front, 1, 5, 4, 1, shadow) # Mouth line
				_fill_rect(front, 2, 2, 2, 1, cyan) # Photoreceptor eye
				# Side cone head
				_fill_rect(side, 3, 7, 2, 2, metal)
				_fill_rect(side, 3, 1, 3, 6, tan)
				_fill_rect(side, 1, 2, 3, 3, tan)
				_fill_rect(side, 1, 5, 3, 1, shadow)
				_fill_rect(side, 2, 2, 1, 1, cyan)
			"torso":
				# Front slender torso
				_fill_rect(front, 1, 1, 6, 4, tan)
				_fill_rect(front, 3, 1, 2, 4, shadow)
				_fill_rect(front, 3, 5, 2, 5, metal) # Spinal link
				_fill_rect(front, 2, 10, 4, 2, tan) # Hip block
				# Side slender torso
				_fill_rect(side, 1, 1, 4, 4, tan)
				_fill_rect(side, 2, 5, 2, 5, metal)
				_fill_rect(side, 1, 10, 3, 2, tan)
			"upper_arm":
				_fill_rect(front, 0, 0, 2, 8, metal)
				_fill_rect(front, 0, 0, 2, 2, tan) # Shoulder cap
				_fill_rect(side, 0, 0, 2, 8, metal)
				_fill_rect(side, 0, 0, 2, 2, tan)
			"forearm":
				_fill_rect(front, 0, 0, 2, 5, metal)
				_fill_rect(front, 0, 5, 2, 2, tan) # Hand clamp
				_fill_rect(side, 0, 0, 2, 5, metal)
				_fill_rect(side, 0, 5, 2, 2, tan)
			"leg":
				_fill_rect(front, 1, 0, 1, 9, metal)
				_fill_rect(front, 0, 9, 3, 2, tan) # Foot
				_fill_rect(side, 1, 0, 2, 9, metal)
				_fill_rect(side, 1, 1, 2, 3, tan) # Thigh plate
				_fill_rect(side, 0, 4, 3, 2, shadow) # Knee bend
				_fill_rect(side, 0, 9, 4, 2, tan) # Foot
			"backpack":
				_fill_rect(front, 0, 2, 4, 7, shadow)
				_fill_rect(front, 1, 0, 1, 2, metal) # Antenna 1
				_fill_rect(front, 2, 0, 1, 2, metal) # Antenna 2
				_fill_rect(side, 0, 2, 3, 7, shadow)
				_fill_rect(side, 1, 0, 1, 2, metal)
			"blaster":
				_fill_rect(front, 0, 2, 12, 1, metal) # Barrel
				_fill_rect(front, 12, 1, 4, 2, wood) # Stock
				_fill_rect(front, 3, 1, 6, 1, metal) # Scope
				_fill_rect(front, 8, 3, 2, 2, metal) # Grip
				_fill_rect(side, 0, 1, 3, 3, metal)
				
	elif _character_id == "clone_commander":
		var white := Color("#e8ece5")
		var shadow := Color("#aeb5b0")
		var black := Color("#15191d")
		var orange := Color("#f17829")
		var cyan := Color("#27d7ff")
		match part_name:
			"head":
				# Front (12x12)
				_fill_rect(front, 2, 1, 8, 10, white)
				_fill_rect(front, 3, 0, 6, 1, white)
				_fill_rect(front, 5, 0, 2, 5, orange) # Crest
				_fill_rect(front, 3, 4, 6, 2, black) # Visor T-bar
				_fill_rect(front, 5, 6, 2, 3, black) # Visor T-stem
				_fill_rect(front, 3, 9, 2, 2, shadow) # Cheek filters
				_fill_rect(front, 7, 9, 2, 2, shadow)
				_fill_rect(front, 2, 7, 1, 2, orange) # Rank dots
				# Side (10x12)
				_fill_rect(side, 1, 1, 8, 10, white)
				_fill_rect(side, 3, 0, 5, 1, orange)
				_fill_rect(side, 1, 4, 4, 2, black)
				_fill_rect(side, 1, 9, 3, 2, shadow)
				_fill_rect(side, 4, 3, 4, 1, orange)
			"torso":
				# Front (14x18)
				_fill_rect(front, 5, 0, 4, 2, black) # Neck
				_fill_rect(front, 2, 2, 10, 8, white) # Chest
				_fill_rect(front, 2, 3, 3, 1, orange) # Markings
				_fill_rect(front, 9, 3, 3, 1, orange)
				_fill_rect(front, 5, 4, 4, 1, orange)
				_fill_rect(front, 4, 10, 6, 5, black) # Under-suit
				_fill_rect(front, 2, 15, 10, 2, white) # Utility belt
				_fill_rect(front, 3, 15, 2, 2, shadow)
				_fill_rect(front, 9, 15, 2, 2, shadow)
				_fill_rect(front, 5, 17, 4, 1, white)
				# Side (10x18)
				_fill_rect(side, 1, 2, 8, 8, white)
				_fill_rect(side, 5, 3, 3, 2, orange)
				_fill_rect(side, 2, 10, 6, 5, black)
				_fill_rect(side, 1, 15, 8, 2, white)
			"upper_arm":
				_fill_rect(front, 0, 0, 4, 3, orange) # Pauldron
				_fill_rect(front, 1, 3, 2, 4, white)
				_fill_rect(front, 1, 7, 2, 1, black)
				_fill_rect(side, 0, 0, 4, 3, orange)
				_fill_rect(side, 1, 3, 2, 4, white)
				_fill_rect(side, 1, 7, 2, 1, black)
			"forearm":
				_fill_rect(front, 1, 0, 2, 2, black)
				_fill_rect(front, 0, 2, 4, 5, white)
				_fill_rect(front, 1, 7, 2, 1, black)
				_fill_rect(side, 1, 0, 2, 2, black)
				_fill_rect(side, 0, 2, 4, 5, white)
				_fill_rect(side, 1, 7, 2, 1, black)
			"thigh":
				_fill_rect(front, 0, 2, 4, 6, white)
				_fill_rect(front, 1, 0, 2, 2, black)
				_fill_rect(front, 1, 2, 2, 4, orange)
				_fill_rect(front, 1, 8, 2, 2, black)
				_fill_rect(side, 0, 2, 4, 6, white)
				_fill_rect(side, 1, 0, 2, 2, black)
				_fill_rect(side, 1, 8, 2, 2, black)
			"shin":
				_fill_rect(front, 0, 0, 4, 2, white)
				_fill_rect(front, 0, 2, 4, 6, white)
				_fill_rect(front, 0, 8, 4, 2, black)
				_fill_rect(side, 0, 0, 3, 2, white)
				_fill_rect(side, 0, 2, 4, 6, white)
				_fill_rect(side, 0, 8, 4, 2, black)
			"blaster":
				_fill_rect(front, 0, 3, 24, 2, black)
				_fill_rect(front, 4, 3, 10, 1, shadow)
				_fill_rect(front, 4, 1, 14, 1, black)
				_fill_rect(front, 18, 2, 6, 3, black)
				_fill_rect(front, 14, 5, 2, 3, black)
				_fill_rect(side, 1, 2, 2, 4, black)
	elif _character_id == "wookiee":
		var brown := Color("#3b251a")
		var dark := Color("#281810")
		var highlight := Color("#664d3b")
		var silver := Color("#dbcb83")
		var belt := Color("#5c483b")
		match part_name:
			"head":
				# Front (12x14)
				_fill_rect(front, 1, 1, 10, 12, brown)
				_fill_rect(front, 3, 0, 6, 1, brown)
				_fill_rect(front, 2, 3, 2, 2, dark) # eyes
				_fill_rect(front, 8, 3, 2, 2, dark)
				_fill_rect(front, 5, 6, 2, 2, dark) # nose
				_fill_rect(front, 4, 10, 4, 1, dark) # mouth
				_fill_rect(front, 2, 7, 2, 4, highlight) # cheeks
				_fill_rect(front, 8, 7, 2, 4, highlight)
				# Side (12x14)
				_fill_rect(side, 2, 1, 9, 12, brown)
				_fill_rect(side, 1, 5, 2, 4, dark) # muzzle
			"torso":
				# Front (14x22)
				_fill_rect(front, 2, 1, 10, 20, brown)
				# Diagonal bandolier
				for i in range(12):
					_fill_rect(front, 2 + i, 2 + i, 1, 1, silver)
				_fill_rect(front, 2, 18, 10, 2, belt)
				# Side (12x22)
				_fill_rect(side, 2, 1, 8, 20, brown)
				_fill_rect(side, 5, 1, 2, 18, silver)
				_fill_rect(side, 2, 18, 8, 2, belt)
			"upper_arm":
				_fill_rect(front, 1, 0, 2, 10, brown)
				_fill_rect(side, 1, 0, 2, 10, brown)
			"forearm":
				_fill_rect(front, 1, 0, 2, 10, brown)
				_fill_rect(side, 1, 0, 2, 10, brown)
			"thigh":
				_fill_rect(front, 1, 0, 3, 12, brown)
				_fill_rect(side, 1, 0, 3, 12, brown)
			"shin":
				_fill_rect(front, 1, 0, 3, 12, brown)
				_fill_rect(side, 1, 0, 3, 12, brown)
			"blaster": # Bowcaster!
				_fill_rect(front, 0, 4, 24, 2, dark) # stock and barrel
				_fill_rect(front, 2, 1, 2, 8, silver) # bow limb left
				_fill_rect(front, 2, 1, 4, 1, silver)
				_fill_rect(front, 2, 8, 4, 1, silver)
				_fill_rect(side, 1, 3, 4, 4, dark)
	elif _character_id == "jawa":
		var brown := Color("#4d2e16")
		var dark := Color("#2b1709")
		var yellow := Color("#ffd626")
		match part_name:
			"head":
				# Front (10x10)
				_fill_rect(front, 1, 1, 8, 8, brown) # hood outer
				_fill_rect(front, 3, 3, 4, 4, dark) # face void
				_fill_rect(front, 3, 4, 1, 1, yellow) # eyes
				_fill_rect(front, 6, 4, 1, 1, yellow)
				# Side (10x10)
				_fill_rect(side, 1, 1, 8, 8, brown)
				_fill_rect(side, 1, 3, 2, 4, dark)
			"torso":
				# Front (12x14)
				_fill_rect(front, 2, 0, 8, 14, brown)
				_fill_rect(front, 3, 2, 6, 12, dark) # folds
				# Side (10x14)
				_fill_rect(side, 2, 0, 6, 14, brown)
			"upper_arm":
				_fill_rect(front, 0, 0, 3, 6, brown)
				_fill_rect(side, 0, 0, 3, 6, brown)
			"forearm":
				_fill_rect(front, 0, 0, 3, 6, brown)
				_fill_rect(side, 0, 0, 3, 6, brown)
			"leg":
				_fill_rect(front, 0, 0, 3, 6, dark)
				_fill_rect(side, 0, 0, 3, 6, dark)
			"blaster": # Ion Blaster
				_fill_rect(front, 0, 2, 16, 2, dark) # Barrel
				_fill_rect(front, 10, 1, 6, 3, brown) # Stock
				_fill_rect(side, 1, 2, 2, 2, dark)
	elif _character_id == "weequay":
		var skin := Color("#ab8b55")
		var shadow := Color("#786139")
		var hair := Color("#2b1c10")
		var clothes := Color("#4d4435")
		var red := Color("#f2382a")
		match part_name:
			"head":
				# Front (10x10)
				_fill_rect(front, 2, 1, 6, 8, skin)
				_fill_rect(front, 3, 3, 1, 1, hair) # eyes
				_fill_rect(front, 6, 3, 1, 1, hair)
				_fill_rect(front, 1, 4, 1, 5, hair) # braid loop
				# Side (10x10)
				_fill_rect(side, 2, 1, 6, 8, skin)
				_fill_rect(side, 1, 4, 1, 6, hair) # long braid
			"torso":
				# Front (12x16)
				_fill_rect(front, 3, 0, 6, 16, clothes)
				_fill_rect(front, 2, 10, 8, 2, red) # Sash belt
				# Side (10x16)
				_fill_rect(side, 2, 0, 6, 16, clothes)
				_fill_rect(side, 1, 10, 8, 2, red)
			"upper_arm":
				_fill_rect(front, 1, 0, 2, 8, clothes)
				_fill_rect(side, 1, 0, 2, 8, clothes)
			"forearm":
				_fill_rect(front, 1, 0, 2, 6, clothes)
				_fill_rect(front, 1, 6, 2, 2, skin) # skin hand
				_fill_rect(side, 1, 0, 2, 6, clothes)
				_fill_rect(side, 1, 6, 2, 2, skin)
			"thigh":
				_fill_rect(front, 1, 0, 2, 10, clothes)
				_fill_rect(side, 1, 0, 2, 10, clothes)
			"shin":
				_fill_rect(front, 1, 0, 2, 6, clothes)
				_fill_rect(front, 1, 6, 2, 4, hair) # leather boot
				_fill_rect(side, 1, 0, 2, 6, clothes)
				_fill_rect(side, 1, 6, 2, 4, hair)
			"blaster":
				_fill_rect(front, 0, 3, 20, 2, hair)
				_fill_rect(side, 1, 2, 3, 3, hair)
	elif _character_id == "abyssinian":
		var green := Color("#4d664c")
		var shadow := Color("#354d34")
		var brown := Color("#2b2019")
		var red := Color("#bf3024")
		var cyan := Color("#27d7ff")
		match part_name:
			"head":
				# Front (10x10)
				_fill_rect(front, 2, 1, 6, 8, green)
				_fill_rect(front, 4, 3, 2, 2, red) # Single large eye
				_fill_rect(front, 5, 4, 1, 1, cyan) # Pupil glow
				_fill_rect(front, 3, 7, 4, 1, shadow) # Mouth slit
				# Side (10x10)
				_fill_rect(side, 2, 1, 6, 8, green)
				_fill_rect(side, 1, 3, 2, 2, red)
			"torso":
				# Front (12x16)
				_fill_rect(front, 3, 0, 6, 16, brown)
				# Side (10x16)
				_fill_rect(side, 2, 0, 6, 16, brown)
			"upper_arm":
				_fill_rect(front, 1, 0, 2, 8, green)
				_fill_rect(side, 1, 0, 2, 8, green)
			"forearm":
				_fill_rect(front, 1, 0, 2, 8, green)
				_fill_rect(side, 1, 0, 2, 8, green)
			"thigh":
				_fill_rect(front, 1, 0, 2, 10, green)
				_fill_rect(side, 1, 0, 2, 10, green)
			"shin":
				_fill_rect(front, 1, 0, 2, 10, green)
				_fill_rect(side, 1, 0, 2, 10, green)
			"blaster":
				_fill_rect(front, 0, 3, 20, 2, shadow)
				_fill_rect(side, 1, 2, 3, 3, shadow)
	elif _character_id == "republic_officer":
		var grey := Color("#606a75")
		var shadow := Color("#414850")
		var yellow := Color("#ffd626")
		var peach := Color("#f0efed")
		var black := Color("#15191d")
		match part_name:
			"head":
				# Front (10x10)
				_fill_rect(front, 2, 2, 6, 7, peach) # skin face
				_fill_rect(front, 2, 0, 6, 2, grey) # military cap
				_fill_rect(front, 1, 2, 8, 1, grey) # cap brim
				_fill_rect(front, 4, 1, 2, 1, yellow) # cap badge
				_fill_rect(front, 3, 4, 1, 1, black) # eyes
				_fill_rect(front, 6, 4, 1, 1, black)
				# Side (10x10)
				_fill_rect(side, 2, 2, 6, 7, peach)
				_fill_rect(side, 2, 0, 6, 2, grey)
				_fill_rect(side, 1, 2, 4, 1, grey)
			"torso":
				# Front (12x16)
				_fill_rect(front, 3, 0, 6, 16, grey)
				_fill_rect(front, 3, 3, 2, 1, yellow) # Rank plaque
				_fill_rect(front, 2, 14, 8, 2, black) # belt
				# Side (10x16)
				_fill_rect(side, 2, 0, 6, 16, grey)
				_fill_rect(side, 2, 14, 6, 2, black)
			"upper_arm":
				_fill_rect(front, 1, 0, 2, 8, grey)
				_fill_rect(side, 1, 0, 2, 8, grey)
			"forearm":
				_fill_rect(front, 1, 0, 2, 6, grey)
				_fill_rect(front, 1, 6, 2, 2, peach)
				_fill_rect(side, 1, 0, 2, 6, grey)
				_fill_rect(side, 1, 6, 2, 2, peach)
			"thigh":
				_fill_rect(front, 1, 0, 2, 10, grey)
				_fill_rect(side, 1, 0, 2, 10, grey)
			"shin":
				_fill_rect(front, 1, 0, 2, 6, grey)
				_fill_rect(front, 1, 6, 2, 4, black) # black boots
				_fill_rect(side, 1, 0, 2, 6, grey)
				_fill_rect(side, 1, 6, 2, 4, black)
			"blaster":
				_fill_rect(front, 0, 3, 18, 2, black)
				_fill_rect(side, 1, 2, 2, 2, black)



func _save_image(image: Image, path: String) -> void:
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save image %s: %s" % [path, err])


func _load_image(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _build_source_cards_scene() -> Node3D:
	var root := _base_scene(_character_id + "_source_cards", Color("#101720"))
	var order := _parts_def.keys()
	var count := order.size()
	for i in range(count):
		var part_name: String = order[i]
		var front := _load_image(_source_paths[part_name]["front"])
		var side := _load_image(_source_paths[part_name]["side"])
		var x := (float(i) - float(count - 1) / 2.0) * 0.76
		_extrude_card(root, front, "%s_front" % part_name, Vector3(x, 1.3, -0.12), _cell_size * 0.9, _cell_size * 0.28)
		_extrude_card(root, side, "%s_side" % part_name, Vector3(x, 0.45, -0.12), _cell_size * 0.9, _cell_size * 0.28)
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(float(count) * 0.8 + 0.4, 0.08, 2.0), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.85, 0), 4.2, Vector3(0, 0.78, -1.0))
	return root


func _build_neutral_vs_aim_scene() -> Node3D:
	var root := _base_scene(_character_id + "_neutral_vs_aim", Color("#0b1017"))
	
	var neutral := _assemble_actor(root, "neutral_actor", Vector3(-0.8, 0, 0))
	neutral.rotation_degrees = Vector3(0, -18, 0)
	
	var aim := _assemble_actor(root, "aim_actor", Vector3(0.8, 0, 0))
	aim.rotation_degrees = Vector3(0, -18, 0)
	_apply_pose(aim, "aim", 0.0)
	
	_add_floor(root, Vector3(0, -0.04, 0), Vector3(3.2, 0.08, 2.0), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.95, 0), 3.4, Vector3(0, 0.78, -1.0))
	return root


func _build_rotation_sheet_scene() -> Node3D:
	var root := _base_scene(_character_id + "_rotation_sheet", Color("#0b1017"))
	var yaws := [0, 90, 180, 270]
	for i in range(yaws.size()):
		var offset := Vector3((float(i) - 1.5) * 1.2, 0, 0)
		var actor := _assemble_actor(root, "actor_yaw_%s" % yaws[i], offset)
		actor.rotation_degrees = Vector3(0, yaws[i], 0)
		_apply_pose(actor, "aim", 0.0)
		_add_floor(root, offset + Vector3(0, -0.06, 0), Vector3(1.0, 0.06, 1.0), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.95, 0), 5.0, Vector3(0, 0.78, -1.0))
	return root


func _build_walk_cycle_scene() -> Node3D:
	var root := _base_scene(_character_id + "_walk_cycle_sheet", Color("#0b1017"))
	var frames := [0.0, 0.3, 0.6, 0.9]
	for i in range(frames.size()):
		var offset := Vector3((float(i) - 1.5) * 1.25, 0, 0)
		var actor := _assemble_actor(root, "walk_frame_%s" % i, offset)
		actor.rotation_degrees = Vector3(0, -25, 0)
		_apply_pose(actor, "walk", frames[i])
		_add_floor(root, offset + Vector3(0, -0.06, 0), Vector3(1.1, 0.06, 1.1), Color("#20252b"))
	_add_camera_light(root, Vector3(0, 0.95, 0), 5.2, Vector3(0, 0.78, -1.0))
	return root


func _bone_to_part_name(bone_name: String) -> String:
	var clean := bone_name.replace("left_", "").replace("right_", "")
	return clean


func _assemble_actor(root: Node3D, node_name: String, origin: Vector3) -> Node3D:
	var actor := Node3D.new()
	actor.name = node_name
	actor.position = origin
	root.add_child(actor)
	
	# Build skeleton
	var bone_nodes := {}
	var root_bone_name: String = _skeleton_def["root"]
	var bones_config: Dictionary = _skeleton_def["bones"]
	
	# 1. Create all bone Node3Ds
	for bone_name in bones_config.keys():
		var config: Dictionary = bones_config[bone_name]
		var bone := Node3D.new()
		bone.name = "bone_%s" % bone_name
		var def_pos: Array = config["default_position"]
		bone.position = Vector3(def_pos[0], def_pos[1], def_pos[2])
		bone_nodes[bone_name] = bone
		
		# Generate a fresh visual hull for this bone
		var part_name := _bone_to_part_name(bone_name)
		var front := _load_image(_source_paths[part_name]["front"])
		var side := _load_image(_source_paths[part_name]["side"])
		var mesh_node := _visual_hull_z_runs(front, side, bone_name + "_mesh", Vector3.ZERO, _cell_size)
		
		# Offset the visual mesh by -pivot and attach it to the bone
		var pivot: Array = config["pivot"]
		mesh_node.position = -Vector3(pivot[0], pivot[1], pivot[2])
		bone.add_child(mesh_node)
		
	# 2. Establish parenting
	for bone_name in bones_config.keys():
		var config: Dictionary = bones_config[bone_name]
		var bone: Node3D = bone_nodes[bone_name]
		var parent_name: String = config["parent"]
		if parent_name == "":
			actor.add_child(bone)
		else:
			var parent_bone: Node3D = bone_nodes[parent_name]
			parent_bone.add_child(bone)
			
	# Construct AnimationPlayer and animations
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	actor.add_child(anim_player)
	
	# Create animation library
	var lib := AnimationLibrary.new()
	for anim_name in _anims_def.keys():
		var anim := _create_godot_animation(anim_name, bones_config)
		lib.add_animation(anim_name, anim)
	anim_player.add_animation_library("", lib)
	
	return actor


func _create_godot_animation(anim_name: String, bones_config: Dictionary) -> Animation:
	var anim_spec: Dictionary = _anims_def[anim_name]
	var anim := Animation.new()
	anim.length = float(anim_spec["length"])
	anim.loop_mode = Animation.LOOP_LINEAR if bool(anim_spec.get("loop", false)) else Animation.LOOP_NONE
	
	var keyframes: Array = anim_spec["keyframes"]
	
	# Determine relative node paths for transform tracks
	var bone_paths := {}
	for bone_name in bones_config.keys():
		var path := _get_bone_path(bone_name, bones_config)
		bone_paths[bone_name] = path
		
	# For each keyframe
	for frame in keyframes:
		var time := float(frame["time"])
		var bones_state: Dictionary = frame["bones"]
		
		for bone_name in bones_state.keys():
			var state: Dictionary = bones_state[bone_name]
			var rot_deg: Array = state["rotation"]
			var rot_rad := Vector3(deg_to_rad(rot_deg[0]), deg_to_rad(rot_deg[1]), deg_to_rad(rot_deg[2]))
			var q := Quaternion.from_euler(rot_rad)
			
			var path: String = bone_paths[bone_name]
			var track_idx := anim.find_track(path, Animation.TYPE_ROTATION_3D)
			if track_idx == -1:
				track_idx = anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(track_idx, path)
				
			anim.rotation_track_insert_key(track_idx, time, q)
			
	return anim


func _get_bone_path(bone_name: String, config: Dictionary) -> String:
	var path_parts := ["bone_%s" % bone_name]
	var curr := bone_name
	while config[curr]["parent"] != "":
		curr = config[curr]["parent"]
		path_parts.push_front("bone_%s" % curr)
	return "/".join(path_parts)


func _apply_pose(actor: Node3D, anim_name: String, time: float) -> void:
	var player: AnimationPlayer = actor.get_node("AnimationPlayer")
	var anim: Animation = player.get_animation(anim_name)
	
	# Apply animation frame values to bone nodes manually for review screenshot
	for track in range(anim.get_track_count()):
		var path := anim.track_get_path(track)
		var q := anim.rotation_track_interpolate(track, time)
		var bone := actor.get_node(path)
		if bone:
			bone.quaternion = q


func _extrude_card(root: Node3D, image: Image, node_name: String, origin: Vector3, cell: float, depth: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	root.add_child(holder)
	var count := 0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		var x := 0
		while x < width:
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				x += 1
				continue
			var run_start := x
			var key := color.to_html(true)
			while x < width and image.get_pixel(x, y).a > 0.05 and image.get_pixel(x, y).to_html(true) == key:
				x += 1
			var run_length := x - run_start
			var px := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(width - 1) / 2.0) * cell
			var py := (float(height - 1 - y) - float(height - 1) / 2.0) * cell
			holder.add_child(_new_box("%s_run_%s_%s" % [node_name, run_start, y], Vector3(px, py, 0), Vector3(float(run_length) * cell, cell, depth), color))
			count += 1
	return holder


func _visual_hull_z_runs(front: Image, side: Image, node_name: String, origin: Vector3, cell: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = origin
	var count := 0
	var raw_voxels := 0
	var width := front.get_width()
	var height := front.get_height()
	var depth := side.get_width()
	for y in range(height):
		for x in range(width):
			var front_color := front.get_pixel(x, y)
			if front_color.a <= 0.05:
				continue
			var z := 0
			while z < depth:
				var side_color := side.get_pixel(z, y)
				if side_color.a <= 0.05:
					z += 1
					continue
				var run_start := z
				while z < depth and side.get_pixel(z, y).a > 0.05:
					z += 1
				var run_length := z - run_start
				raw_voxels += run_length
				var px := (float(x) - float(width - 1) / 2.0) * cell
				var py := (float(height - 1 - y) - float(height - 1) / 2.0) * cell
				var pz := (float(run_start) + float(run_length) / 2.0 - 0.5 - float(depth - 1) / 2.0) * cell
				
				# Base color blending
				var color := _blend_front_side(front_color, side.get_pixel(run_start, y))
				
				# Skip noise/shadow on emissive photoreceptors/visors
				if front_color != Color("#27d7ff") and side_color != Color("#27d7ff"):
					# Voxel coordinate deterministic hash noise (Minecraft textured variety)
					var hash_val: float = sin(float(x) * 12.9898 + float(y) * 78.233 + float(run_start) * 437.287) * 43758.5453
					var noise: float = (hash_val - floor(hash_val)) * 0.12 - 0.06
					
					# Ambient occlusion depth-shadow (darken inner voxels relative to card borders)
					var dist_to_x_edge: float = float(min(x, width - 1 - x))
					var dist_to_z_edge: float = float(min(run_start, depth - 1 - run_start))
					var min_edge: float = min(dist_to_x_edge, dist_to_z_edge)
					var depth_shadow: float = 1.0 - clamp(min_edge * 0.06, 0.0, 0.22)
					
					color.r = clamp(color.r * depth_shadow + noise, 0.0, 1.0)
					color.g = clamp(color.g * depth_shadow + noise, 0.0, 1.0)
					color.b = clamp(color.b * depth_shadow + noise, 0.0, 1.0)
				
				holder.add_child(_new_box("%s_x%s_y%s_z%s" % [node_name, x, y, run_start], Vector3(px, py, pz), Vector3(cell, cell, float(run_length) * cell), color))
				count += 1
				
	_stats[node_name] = {"boxes": count, "raw_voxels": raw_voxels}
	return holder


func _blend_front_side(front_color: Color, side_color: Color) -> Color:
	# Keep visors/photoreceptors glowing and pure
	if front_color == Color("#27d7ff") or front_color == Color("#15191d"):
		return front_color
	if side_color == Color("#15191d"):
		return side_color
	return front_color.lerp(side_color, 0.18)


func _fill_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for px in range(x, x + width):
		for py in range(y, y + height):
			if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)


func _new_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.position = position
	inst.material_override = _material(color)
	return inst


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if color == Color("#27d7ff"):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
	return mat


func _base_scene(name: String, background: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#29313b")
	env.ambient_light_energy = 0.86
	env_node.environment = env
	root.add_child(env_node)
	return root


func _add_floor(root: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	var floor_mesh := _new_box("floor", position, size, color)
	root.add_child(floor_mesh)


func _add_camera_light(root: Node3D, target: Vector3, camera_size: float, camera_vector: Vector3) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "RuntimeActorSun"
	sun.rotation_degrees = Vector3(-36, -42, -8)
	sun.light_color = Color("#ffe2aa")
	sun.light_energy = 2.5
	sun.shadow_enabled = true
	root.add_child(sun)
	
	var fill := OmniLight3D.new()
	fill.name = "RuntimeActorFill"
	fill.position = target + Vector3(-2.5, 2.5, 2.5)
	fill.light_color = Color("#7fd7ff")
	fill.light_energy = 0.35
	fill.omni_range = 8.0
	root.add_child(fill)
	
	var camera := Camera3D.new()
	camera.name = "ReviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = camera_size
	camera.near = 0.05
	camera.far = 100.0
	camera.position = target + camera_vector.normalized() * 14.0
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	root.add_child(camera)


func _save_and_capture(name: String, scene: Node3D, description: String) -> void:
	var scene_path := _output_dir + "/review_scenes/%s.tscn" % name
	var capture_path := _output_dir + "/captures/%s.png" % name
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
	get_root().remove_child(scene)


func _write_manifest(spec_path: String) -> void:
	var manifest := {
		"generator": "docs/google/modeling/asset_factory/scripts/godot_pixel_actor_generator.gd",
		"spec_path": spec_path,
		"character_id": _character_id,
		"display_name": _display_name,
		"source_images": _source_paths,
		"stats": _stats,
		"captures": _captures,
	}
	var file := FileAccess.open(_output_dir + "/actor_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()


func _write_review() -> void:
	var lines: Array[String] = []
	lines.append("# %s - Voxel Character Review" % _display_name)
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Generator: `docs/google/modeling/asset_factory/scripts/godot_pixel_actor_generator.gd`")
	lines.append("")
	lines.append("## Purpose")
	lines.append("")
	lines.append("Synthesizes a full 3D visual hull character assembled into a hierarchical bone-and-pivot joint rig and equipped with native Godot animations.")
	lines.append("")
	lines.append("## Part Voxel Stats")
	lines.append("")
	lines.append("| Part Name | Box Count | Raw Voxels |")
	lines.append("| --- | ---: | ---: |")
	for part in _stats.keys():
		lines.append("| `%s` | %s | %s |" % [part, _stats[part]["boxes"], _stats[part]["raw_voxels"]])
	lines.append("")
	lines.append("## Captures")
	lines.append("")
	for entry in _captures:
		var capture := String(entry["capture_path"]).replace(_output_dir + "/", "")
		lines.append("### %s" % entry["id"])
		lines.append("")
		lines.append(entry["description"])
		lines.append("")
		lines.append("![%s](%s)" % [entry["id"], capture])
		lines.append("")
		
	var file := FileAccess.open(_output_dir + "/REVIEW.md", FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
