extends CanvasLayer

const CHARACTER_DATA_PATH = "res://data/prototype_characters.json"
const WEAPONS_DATA_PATH = "res://data/weapons_clone_wars.json"

var _root: Control
var _dialogue_box: ColorRect
var _name_label: Label
var _text_label: Label
var _options_container: HBoxContainer
var _shop_container: VBoxContainer
var _credits_label: Label

var current_npc_id: String = ""
var current_npc_name: String = ""
var current_dialogue_lines: Array = []
var current_npc_desc: String = ""
var current_npc_role: String = ""

var _player_credits: int = 5000

func _ready() -> void:
	add_to_group("modal_gameplay_overlay")
	_build_overlay()
	visible = false

func open_dialogue(npc_id: String, npc_name: String, role: String, desc: String, dialogue_lines: Array) -> void:
	current_npc_id = npc_id
	current_npc_name = npc_name
	current_npc_role = role
	current_npc_desc = desc
	current_dialogue_lines = dialogue_lines
	
	_load_player_credits()
	
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_name_label.text = "%s (%s)" % [npc_name, role]
	_text_label.text = desc
	
	_show_main_menu()

func close_dialogue() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Refresh character sheet overlay if open
	var tree := get_tree()
	if tree != null:
		var sheet_overlay = tree.root.find_child("CharacterSheetOverlay", true, false)
		if sheet_overlay != null and sheet_overlay.has_method("_refresh"):
			sheet_overlay.call("_refresh")

func _load_player_credits() -> void:
	if not FileAccess.file_exists(CHARACTER_DATA_PATH):
		return
	var file := FileAccess.open(CHARACTER_DATA_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var characters: Dictionary = parsed.get("characters", {})
		var sheet: Dictionary = characters.get("range_trainee", {})
		_player_credits = int(sheet.get("credits", 5000))

func _save_player_credits_and_weapon(new_weapon_id: String) -> void:
	if not FileAccess.file_exists(CHARACTER_DATA_PATH):
		return
	var file := FileAccess.open(CHARACTER_DATA_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var characters: Dictionary = parsed.get("characters", {})
		var sheet: Dictionary = characters.get("range_trainee", {})
		sheet["credits"] = _player_credits
		if new_weapon_id != "":
			var equipment: Dictionary = sheet.get("equipment", {})
			equipment["weapon"] = new_weapon_id
			
		# Write back to file
		var write_file := FileAccess.open(CHARACTER_DATA_PATH, FileAccess.WRITE)
		write_file.store_string(JSON.stringify(parsed, "  "))

func _build_overlay() -> void:
	_root = Control.new()
	_root.name = "DialogueOverlay"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)


	# Main translucent box
	_dialogue_box = ColorRect.new()
	_dialogue_box.position = Vector2(100, 440)
	_dialogue_box.size = Vector2(1080, 250)
	_dialogue_box.color = Color(0.08, 0.09, 0.11, 0.94)
	_root.add_child(_dialogue_box)

	# NPC name header
	_name_label = Label.new()
	_name_label.position = Vector2(25, 15)
	_name_label.size = Vector2(1030, 30)
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.modulate = Color(0.95, 0.84, 0.28) # Warm yellow accent
	_dialogue_box.add_child(_name_label)

	# NPC dialog box text
	_text_label = Label.new()
	_text_label.position = Vector2(25, 55)
	_text_label.size = Vector2(1030, 110)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 15)
	_text_label.modulate = Color(0.90, 0.90, 0.90)
	_dialogue_box.add_child(_text_label)

	# Options container for choices
	_options_container = HBoxContainer.new()
	_options_container.position = Vector2(25, 185)
	_options_container.size = Vector2(1030, 45)
	_options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialogue_box.add_child(_options_container)

	# Shop list container (VBox)
	_shop_container = VBoxContainer.new()
	_shop_container.position = Vector2(25, 55)
	_shop_container.size = Vector2(1030, 120)
	_shop_container.visible = false
	_dialogue_box.add_child(_shop_container)
	
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 14)
	_credits_label.modulate = Color(0.35, 0.88, 0.42) # Green credits
	_shop_container.add_child(_credits_label)

func _show_main_menu() -> void:
	_text_label.visible = true
	_shop_container.visible = false
	_clear_options()
	
	# Option 1: Speak/Chat
	var btn_talk := Button.new()
	btn_talk.text = " [1] Talk "
	btn_talk.add_theme_font_size_override("font_size", 14)
	btn_talk.pressed.connect(_on_talk_pressed)
	_options_container.add_child(btn_talk)

	# Option 2: Trade
	var btn_trade := Button.new()
	btn_trade.text = " [2] Trade / View Shop "
	btn_trade.add_theme_font_size_override("font_size", 14)
	btn_trade.pressed.connect(_on_trade_pressed)
	_options_container.add_child(btn_trade)

	# Option 3: Leave
	var btn_leave := Button.new()
	btn_leave.text = " [3] Bid Farewell "
	btn_leave.add_theme_font_size_override("font_size", 14)
	btn_leave.pressed.connect(close_dialogue)
	_options_container.add_child(btn_leave)

func _clear_options() -> void:
	for child in _options_container.get_children():
		child.queue_free()

func _on_talk_pressed() -> void:
	if current_dialogue_lines.size() > 0:
		var index := randi() % current_dialogue_lines.size()
		_text_label.text = "\"%s\"" % current_dialogue_lines[index]
	else:
		_text_label.text = "\"I have nothing to say to you right now, citizen.\""

func _on_trade_pressed() -> void:
	_text_label.visible = false
	_shop_container.visible = true
	_clear_options()
	
	# Clear previous items from shop list except credits label
	for child in _shop_container.get_children():
		if child != _credits_label:
			child.queue_free()
			
	_credits_label.text = "Your Balance: %d Credits" % _player_credits
	
	# Add item buttons
	var items := [
		{"id": "blaster_pistol", "name": "Blaster Pistol", "cost": 500},
		{"id": "blaster_rifle", "name": "Blaster Rifle", "cost": 1000},
		{"id": "bowcaster", "name": "Wookiee Bowcaster", "cost": 1500},
		{"id": "lightsaber", "name": "Lightsaber", "cost": 3000},
		{"id": "thermal_detonator", "name": "Thermal Detonator", "cost": 350}
	]
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_container.add_child(hbox)
	
	for item in items:
		var btn := Button.new()
		btn.text = "Buy %s (%d cr)" % [item["name"], item["cost"]]
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_buy_item.bind(item["id"], item["name"], item["cost"]))
		hbox.add_child(btn)

	# Back Option
	var btn_back := Button.new()
	btn_back.text = " [Back] Return "
	btn_back.pressed.connect(_show_main_menu)
	_options_container.add_child(btn_back)

func _on_buy_item(item_id: String, item_name: String, cost: int) -> void:
	if _player_credits >= cost:
		_player_credits -= cost
		_save_player_credits_and_weapon(item_id)
		_credits_label.text = "Your Balance: %d Credits - Successfully purchased %s!" % [_player_credits, item_name]
	else:
		_credits_label.text = "Your Balance: %d Credits - Insufficient credits to purchase %s!" % [_player_credits, item_name]
