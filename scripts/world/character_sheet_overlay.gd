extends CanvasLayer

const CHARACTER_DATA_PATH = "res://data/prototype_characters.json"
const SKILL_CATALOG_PATH = "res://data/prototype_skill_catalog.json"
const COMBATANT_DATA_PATH = "res://data/prototype_combatants.json"
const CharacterSheetModel = preload("res://scripts/rules/character_sheet_model.gd")
const ModalOverlayModel = preload("res://scripts/rules/modal_overlay_model.gd")

var _root: Control
var _label: Label
var _model := CharacterSheetModel.new()

func _ready() -> void:
	add_to_group("ground_gameplay_layer")
	_build_overlay()
	visible = false

func _input(event: InputEvent) -> void:
	if ModalOverlayModel.is_modal_overlay_active(get_tree()):
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		visible = not visible
		if visible:
			_refresh()

func _build_overlay() -> void:
	_root = Control.new()
	_root.name = "CharacterSheetOverlay"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var shade := ColorRect.new()
	shade.position = Vector2(18, 185)
	shade.size = Vector2(420, 420)
	shade.color = Color(0.07, 0.075, 0.07, 0.88)
	_root.add_child(shade)

	_label = Label.new()
	_label.position = Vector2(36, 205)
	_label.size = Vector2(380, 380)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 14)
	_label.modulate = Color(0.86, 0.84, 0.74)
	_root.add_child(_label)
	_set_mouse_filter_recursive(_root)

func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_recursive(child)

func _refresh() -> void:
	var character_data := _load_json_file(CHARACTER_DATA_PATH)
	var skill_catalog := _load_json_file(SKILL_CATALOG_PATH)
	var gear := _load_json_file(COMBATANT_DATA_PATH)
	var characters: Dictionary = character_data.get("characters", {})
	var sheet: Dictionary = characters.get("range_trainee", {})
	if sheet.is_empty():
		_label.text = "No character sheet loaded."
		return
	var live_state := _live_range_state()
	var character_points := int(sheet.get("character_points", 0))
	var force_points := int(sheet.get("force_points", 0))
	var wound_severity := int(sheet.get("wound_severity", 0))
	var armor_quality_pips := 0
	if not live_state.is_empty():
		character_points = int(live_state.get("player_character_points", character_points))
		force_points = int(live_state.get("player_force_points", force_points))
		wound_severity = int(live_state.get("player_wound_severity", wound_severity))
		armor_quality_pips = int(live_state.get("player_armor_quality_pips", armor_quality_pips))

	var lines := PackedStringArray()
	lines.append("%s - %s" % [String(sheet.get("name", "Character")), String(sheet.get("species", "Species"))])
	lines.append("CP %d  FP %d  DSP %d  Wound %d" % [
		character_points,
		force_points,
		int(sheet.get("dark_side_points", 0)),
		wound_severity,
	])
	if not live_state.is_empty():
		lines.append("Window %d  Defense %s  Cover %d" % [
			int(live_state.get("round", 1)),
			String(live_state.get("player_defense", "none")),
			int(live_state.get("player_cover_level", 0)),
		])
	lines.append("")
	lines.append("Attributes")
	var attributes: Dictionary = sheet.get("attributes", {})
	for attribute in _model.ATTRIBUTE_KEYS:
		lines.append("  %s %s" % [String(attribute).capitalize(), String(attributes.get(attribute, "0D"))])

	lines.append("")
	lines.append("Skills")
	var skill_names := ["blaster", "dodge", "sensors", "starship_gunnery"]
	for skill_name in skill_names:
		var pool: Dictionary = _model.skill_pool(D6Rules, sheet, skill_catalog, skill_name)
		lines.append("  %s %s" % [String(skill_name).replace("_", " ").capitalize(), D6Rules.pool_to_string(pool)])

	lines.append("")
	var equipment: Dictionary = sheet.get("equipment", {})
	var weapons: Dictionary = gear.get("weapons", {})
	var armors: Dictionary = gear.get("armors", {})
	var weapon: Dictionary = weapons.get(String(equipment.get("weapon", "")), {})
	var armor: Dictionary = armors.get(String(equipment.get("armor", "")), {})
	lines.append("Gear")
	lines.append("  Weapon: %s %s" % [String(weapon.get("name", "None")), String(weapon.get("damage", ""))])
	for armor_line in _model.armor_summary_lines(armor, armor_quality_pips):
		lines.append("  %s" % armor_line)
	_label.text = "\n".join(lines)

func _live_range_state() -> Dictionary:
	var tree := get_tree()
	if tree == null:
		return {}
	var range_controller := tree.root.find_child("BlasterRangeController", true, false)
	if range_controller == null or not range_controller.has_method("get_range_state"):
		return {}
	return range_controller.get_range_state()

func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
