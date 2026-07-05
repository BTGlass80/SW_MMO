extends CanvasLayer

const CHARACTER_DATA_PATH = "res://data/prototype_characters.json"

var _root: Control

# Top Panel
var _top_panel: ColorRect
var _title_label: Label
var _credits_label: Label
var _btn_sheet: Button
var _btn_bridge: Button
var _btn_sell_cargo: Button
var _btn_reset: Button
var _btn_pause: Button

# Left Info Panel
var _left_panel: ColorRect
var _health_label: Label
var _force_points_label: Label
var _defense_label: Label
var _cover_label: Label

# Bottom Console Panel
var _bottom_panel: ColorRect
var _log_label: Label
var _telemetry_label: Label

# Right Help Panel
var _right_panel: ColorRect
var _help_label: Label

# Properties
var log_text: String = "":
	set(val):
		log_text = val
		if _log_label != null:
			_log_label.text = val
var telemetry_text: String = "":
	set(val):
		telemetry_text = val
		if _telemetry_label != null:
			_telemetry_label.text = val

func _ready() -> void:
	_build_hud()
	_update_stats_loop()

func _build_hud() -> void:
	_root = Control.new()
	_root.name = "UnifiedHUDRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# --- 1. TOP PANEL (Title + Nav + Credits) ---
	_top_panel = ColorRect.new()
	_top_panel.position = Vector2(0, 0)
	_top_panel.size = Vector2(1280, 50)
	_top_panel.color = Color(0.06, 0.07, 0.09, 0.92)
	_root.add_child(_top_panel)

	# Border line below top panel
	var top_line := ColorRect.new()
	top_line.position = Vector2(0, 49)
	top_line.size = Vector2(1280, 1)
	top_line.color = Color(0.18, 0.32, 0.44, 0.5)
	_top_panel.add_child(top_line)

	_title_label = Label.new()
	_title_label.position = Vector2(18, 12)
	_title_label.text = "MOS EISLEY SIMULATOR"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.modulate = Color(0.95, 0.84, 0.28) # Warm yellow title
	_top_panel.add_child(_title_label)

	_credits_label = Label.new()
	_credits_label.position = Vector2(240, 14)
	_credits_label.text = "Credits: 0"
	_credits_label.add_theme_font_size_override("font_size", 13)
	_credits_label.modulate = Color(0.35, 0.88, 0.42) # Green credits
	_top_panel.add_child(_credits_label)

	# Navigation Buttons (Horizontal container)
	var nav_container := HBoxContainer.new()
	nav_container.position = Vector2(580, 8)
	nav_container.size = Vector2(680, 34)
	nav_container.alignment = BoxContainer.ALIGNMENT_END
	_top_panel.add_child(nav_container)

	_btn_sheet = Button.new()
	_btn_sheet.text = " Character Sheet [H] "
	_btn_sheet.add_theme_font_size_override("font_size", 12)
	_btn_sheet.pressed.connect(_on_character_sheet_pressed)
	nav_container.add_child(_btn_sheet)

	_btn_bridge = Button.new()
	_btn_bridge.text = " Space Bridge [M] "
	_btn_bridge.add_theme_font_size_override("font_size", 12)
	_btn_bridge.pressed.connect(_on_space_bridge_pressed)
	nav_container.add_child(_btn_bridge)

	_btn_sell_cargo = Button.new()
	_btn_sell_cargo.text = " Sell Cargo "
	_btn_sell_cargo.add_theme_font_size_override("font_size", 12)
	_btn_sell_cargo.pressed.connect(_on_sell_cargo_pressed)
	nav_container.add_child(_btn_sell_cargo)

	_btn_reset = Button.new()
	_btn_reset.text = " Reset Range [R] "
	_btn_reset.add_theme_font_size_override("font_size", 12)
	_btn_reset.pressed.connect(_on_reset_range_pressed)
	nav_container.add_child(_btn_reset)

	_btn_pause = Button.new()
	_btn_pause.text = " Pause Remotes [Z] "
	_btn_pause.add_theme_font_size_override("font_size", 12)
	_btn_pause.pressed.connect(_on_pause_remotes_pressed)
	nav_container.add_child(_btn_pause)

	# --- 2. LEFT VITAL PANEL (Stats) ---
	_left_panel = ColorRect.new()
	_left_panel.position = Vector2(18, 70)
	_left_panel.size = Vector2(250, 160)
	_left_panel.color = Color(0.08, 0.09, 0.11, 0.8)
	_root.add_child(_left_panel)

	# Thin panel border
	_add_panel_borders(_left_panel)

	var stats_title := Label.new()
	stats_title.position = Vector2(12, 10)
	stats_title.text = "VITAL STATUS"
	stats_title.add_theme_font_size_override("font_size", 12)
	stats_title.modulate = Color(0.62, 0.70, 0.73)
	_left_panel.add_child(stats_title)

	_health_label = Label.new()
	_health_label.position = Vector2(12, 36)
	_health_label.text = "Condition: Healthy\nWounds: None"
	_health_label.add_theme_font_size_override("font_size", 13)
	_left_panel.add_child(_health_label)

	_force_points_label = Label.new()
	_force_points_label.position = Vector2(12, 76)
	_force_points_label.text = "Force Points: 1\nCP: 5"
	_force_points_label.add_theme_font_size_override("font_size", 13)
	_left_panel.add_child(_force_points_label)

	_defense_label = Label.new()
	_defense_label.position = Vector2(12, 116)
	_defense_label.text = "Dodge: Normal\nCover: None"
	_defense_label.add_theme_font_size_override("font_size", 13)
	_defense_label.modulate = Color(0.74, 0.83, 0.74)
	_left_panel.add_child(_defense_label)

	# --- 3. RIGHT CONTROLS PANEL (Cheat sheet) ---
	_right_panel = ColorRect.new()
	_right_panel.position = Vector2(1012, 70)
	_right_panel.size = Vector2(250, 200)
	_right_panel.color = Color(0.08, 0.09, 0.11, 0.8)
	_root.add_child(_right_panel)

	_add_panel_borders(_right_panel)

	var help_title := Label.new()
	help_title.position = Vector2(12, 10)
	help_title.text = "CONTROLS"
	help_title.add_theme_font_size_override("font_size", 12)
	help_title.modulate = Color(0.62, 0.70, 0.73)
	_right_panel.add_child(help_title)

	_help_label = Label.new()
	_help_label.position = Vector2(12, 34)
	_help_label.text = "Movement: WASD / Space\nLook: Mouse\nAim Blaster: RMB\nFire Blaster: LMB\nInteract / Talk: E\n\n[H] Character Sheet\n[M] Space Map / Bridge\n[R] Reset Drill\n[Z] Toggle Remote Speed"
	_help_label.add_theme_font_size_override("font_size", 11)
	_help_label.modulate = Color(0.85, 0.85, 0.85)
	_right_panel.add_child(_help_label)

	# --- 4. BOTTOM LOG/CONSOLE PANEL ---
	_bottom_panel = ColorRect.new()
	_bottom_panel.position = Vector2(290, 520)
	_bottom_panel.size = Vector2(700, 170)
	_bottom_panel.color = Color(0.08, 0.09, 0.11, 0.88)
	_root.add_child(_bottom_panel)

	_add_panel_borders(_bottom_panel)

	var log_title := Label.new()
	log_title.position = Vector2(16, 8)
	log_title.text = "TACTICAL SYSTEM FEED"
	log_title.add_theme_font_size_override("font_size", 11)
	log_title.modulate = Color(0.18, 0.65, 0.85) # Teal neon
	_bottom_panel.add_child(log_title)

	_log_label = Label.new()
	_log_label.position = Vector2(16, 30)
	_log_label.size = Vector2(668, 90)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.text = "Combat log idle."
	_log_label.add_theme_font_size_override("font_size", 13)
	_bottom_panel.add_child(_log_label)

	_telemetry_label = Label.new()
	_telemetry_label.position = Vector2(16, 130)
	_telemetry_label.size = Vector2(668, 30)
	_telemetry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_telemetry_label.text = "Range state: Ready."
	_telemetry_label.add_theme_font_size_override("font_size", 12)
	_telemetry_label.modulate = Color(0.6, 0.65, 0.7)
	_bottom_panel.add_child(_telemetry_label)

func _add_panel_borders(rect: ColorRect) -> void:
	var border_col := Color(0.18, 0.32, 0.44, 0.5)
	
	# Top line
	var t_line := ColorRect.new()
	t_line.position = Vector2(0, 0)
	t_line.size = Vector2(rect.size.x, 1)
	t_line.color = border_col
	rect.add_child(t_line)

	# Bottom line
	var b_line := ColorRect.new()
	b_line.position = Vector2(0, rect.size.y - 1)
	b_line.size = Vector2(rect.size.x, 1)
	b_line.color = border_col
	rect.add_child(b_line)

	# Left line
	var l_line := ColorRect.new()
	l_line.position = Vector2(0, 0)
	l_line.size = Vector2(1, rect.size.y)
	l_line.color = border_col
	rect.add_child(l_line)

	# Right line
	var r_line := ColorRect.new()
	r_line.position = Vector2(rect.size.x - 1, 0)
	r_line.size = Vector2(1, rect.size.y)
	r_line.color = border_col
	rect.add_child(r_line)

func _update_stats_loop() -> void:
	while true:
		_refresh_character_stats()
		await get_tree().create_timer(1.0).timeout

func _refresh_character_stats() -> void:
	if not FileAccess.file_exists(CHARACTER_DATA_PATH):
		return
	var file := FileAccess.open(CHARACTER_DATA_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var characters: Dictionary = parsed.get("characters", {})
		var sheet: Dictionary = characters.get("range_trainee", {})
		
		# Credits
		var cr := int(sheet.get("credits", 5000))
		if _credits_label != null:
			_credits_label.text = "Credits: %d" % cr
			
		# CP / FP
		var cp := int(sheet.get("character_points", 5))
		var fp := int(sheet.get("force_points", 1))
		
		# Wound status
		var wound_sev := int(sheet.get("wound_severity", 0))
		var cond := "Healthy"
		if wound_sev == 1:
			cond = "Stunned"
		elif wound_sev == 2:
			cond = "Wounded"
		elif wound_sev >= 3:
			cond = "Incapacitated"
			
		# Check range state if active for live player parameters
		var live_state := _live_range_state()
		if not live_state.is_empty():
			cp = int(live_state.get("player_character_points", cp))
			fp = int(live_state.get("player_force_points", fp))
			wound_sev = int(live_state.get("player_wound_severity", wound_sev))
			if wound_sev == 1:
				cond = "Stunned"
			elif wound_sev == 2:
				cond = "Wounded"
			elif wound_sev >= 3:
				cond = "Incapacitated"
				
			var def_str := String(live_state.get("player_defense", "none"))
			var cov_val := int(live_state.get("player_cover_level", 0))
			
			if _defense_label != null:
				_defense_label.text = "Dodge: %s\nCover: %d" % [def_str.capitalize(), cov_val]

		if _health_label != null:
			_health_label.text = "Condition: %s\nWound Tier: %d" % [cond, wound_sev]
		if _force_points_label != null:
			_force_points_label.text = "Force Points: %d\nCP remaining: %d" % [fp, cp]

func _live_range_state() -> Dictionary:
	var range_controller = get_tree().root.find_child("BlasterRangeController", true, false)
	if range_controller == null or not range_controller.has_method("get_range_state"):
		return {}
	return range_controller.get_range_state()

# --- Nav button callback triggers ---
func _on_character_sheet_pressed() -> void:
	var sheet = get_tree().root.find_child("CharacterSheetOverlay", true, false)
	if sheet != null:
		sheet.visible = not sheet.visible
		if sheet.visible and sheet.has_method("_refresh"):
			sheet.call("_refresh")

func _on_space_bridge_pressed() -> void:
	var map = get_tree().root.find_child("SpaceMapOverlay", true, false)
	if map != null and map.has_method("_set_open"):
		map.call("_set_open", not map.visible)

func _on_sell_cargo_pressed() -> void:
	var global_net = get_node_or_null("/root/Net")
	if global_net != null and global_net.connected:
		global_net.send_space_sell_cargo()

func _on_reset_range_pressed() -> void:
	var range_controller = get_tree().root.find_child("BlasterRangeController", true, false)
	if range_controller != null and range_controller.has_method("_reset_drill"):
		range_controller.call("_reset_drill")

func _on_pause_remotes_pressed() -> void:
	var range_controller = get_tree().root.find_child("BlasterRangeController", true, false)
	if range_controller != null and range_controller.has_method("_toggle_live_pressure"):
		range_controller.call("_toggle_live_pressure")
