extends CanvasLayer

const SPACE_DATA_PATH = "res://data/space_tactical_slice.json"
const SpaceTacticalModel = preload("res://scripts/rules/space_tactical_model.gd")
const LiveClockModel = preload("res://scripts/rules/live_clock_model.gd")
const SpaceStatusModel = preload("res://scripts/rules/space_status_model.gd")
const SpaceOverlayLayoutModel = preload("res://scripts/rules/space_overlay_layout_model.gd")
const SpaceContactSelectionModel = preload("res://scripts/rules/space_contact_selection_model.gd")
const SpaceActionLogModel = preload("res://scripts/rules/space_action_log_model.gd")
const SpaceOverlayModeModel = preload("res://scripts/rules/space_overlay_mode_model.gd")
const SpaceStationStripModel = preload("res://scripts/rules/space_station_strip_model.gd")

class HazardZone:
	extends Control

	var radius := 10.0
	var fill_color := Color(0.76, 0.45, 0.22, 0.16)
	var line_color := Color(0.92, 0.66, 0.34, 0.72)

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, radius, fill_color)
		draw_arc(center, radius, 0.0, TAU, 48, line_color, 2.0)

var _root: Control
var _scan_label: Label
var _gunnery_label: Label
var _shield_label: Label
var _traffic_label: Label
var _mode_label: Label
var _selected_target_label: Label
var _action_log_label: Label
var _map_size := Vector2(760, 520)
var _map_origin := Vector2(32, 118)
var _mouse_mode_before_open := Input.MOUSE_MODE_CAPTURED
var _selected_contact_id := ""
var _contacts: Array = []
var _contact_visuals: Dictionary = {}
var _hazard_visuals: Array = []
var _range_bands: Array = []
var _player_ship: Dictionary = {}
var _gunnery_drill: Dictionary = {}
var _model := SpaceTacticalModel.new()
var _space_state := _model.initial_state()
var _space_action_log: Array = []
var _station_labels: Dictionary = {}
var _scan_rng := RandomNumberGenerator.new()
var _identify_rng := RandomNumberGenerator.new()
var _comms_rng := RandomNumberGenerator.new()
var _gunnery_rng := RandomNumberGenerator.new()
var _shield_rng := RandomNumberGenerator.new()
var _repair_rng := RandomNumberGenerator.new()
var _astrogation_rng := RandomNumberGenerator.new()
var _maneuver_rng := RandomNumberGenerator.new()
var _station_rng := RandomNumberGenerator.new()
var _station_assist_index := 0
var _live_traffic_enabled := true
var _live_traffic_tick_seconds := 5.0
var _live_traffic_accumulator := 0.0
var _live_traffic_tick_count := 0
var _last_viewport_size := Vector2.ZERO
var _last_bridge_cue := ""
var _pending_action_log_cue_level := ""

func _ready() -> void:
	layer = 20
	add_to_group("modal_gameplay_overlay")
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_scan_rng.randomize()
	_identify_rng.randomize()
	_comms_rng.randomize()
	_gunnery_rng.randomize()
	_shield_rng.randomize()
	_repair_rng.randomize()
	_astrogation_rng.randomize()
	_maneuver_rng.randomize()
	_station_rng.randomize()
	_load_space_data()
	_build_overlay()
	_last_viewport_size = get_viewport().get_visible_rect().size
	visible = false

func _process(delta: float) -> void:
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _live_traffic_enabled or _contacts.is_empty():
		_update_traffic_label()
		return
	var tick_result := LiveClockModel.ticks_for_delta(delta, _live_traffic_accumulator, _live_traffic_tick_seconds)
	_live_traffic_accumulator = float(tick_result["accumulator"])
	for i in range(int(tick_result["ticks"])):
		_live_traffic_tick_count += 1
		_advance_contacts(true)
	_update_traffic_label()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and visible:
		_set_open(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_set_open(not visible)
		_update_traffic_label()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and _is_space_action_key(event.keycode):
		_set_open(true)
		_resolve_space_action_key(event.keycode)
		get_viewport().set_input_as_handled()

func _set_open(open: bool) -> void:
	if open == visible:
		return
	if open:
		_mouse_mode_before_open = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		visible = true
		_update_mode_label()
	else:
		visible = false
		Input.mouse_mode = _mouse_mode_before_open

func _on_viewport_size_changed() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size == _last_viewport_size or _root == null:
		return
	_last_viewport_size = viewport_size
	_rebuild_overlay_for_viewport()

func _rebuild_overlay_for_viewport() -> void:
	var readouts := {
		"scan": _scan_label.text if _scan_label != null else "Sensors idle.",
		"gunnery": _gunnery_label.text if _gunnery_label != null else "Gunnery idle.",
		"shield": _shield_label.text if _shield_label != null else "Shields idle.",
		"action_log": _action_log_label.text if _action_log_label != null else SpaceActionLogModel.summary_text(_space_action_log),
	}
	remove_child(_root)
	_root.free()
	_root = null
	_contact_visuals.clear()
	_hazard_visuals.clear()
	_station_labels.clear()
	_build_overlay()
	_scan_label.text = String(readouts["scan"])
	_gunnery_label.text = String(readouts["gunnery"])
	_shield_label.text = String(readouts["shield"])
	_action_log_label.text = String(readouts["action_log"])
	_refresh_contact_visibility()
	_update_selected_target_readout()
	_update_traffic_label()
	_update_mode_label()
	_update_station_strip()

func _load_space_data() -> void:
	if not FileAccess.file_exists(SPACE_DATA_PATH):
		return
	var file := FileAccess.open(SPACE_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	_contacts = data.get("contacts", [])
	_range_bands = data.get("range_bands", [])
	_player_ship = data.get("player_ship", {})
	_gunnery_drill = data.get("gunnery_drill", {})
	_selected_contact_id = String(_gunnery_drill.get("default_target_id", ""))

func _build_overlay() -> void:
	_configure_layout()
	_root = Control.new()
	_root.name = "SpaceTacticalOverlay"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.055, 1.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var title := Label.new()
	title.position = Vector2(32, 22)
	title.text = "Mos Eisley Approach - 2.5D Tactical Plane"
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(0.82, 0.88, 0.90)
	_root.add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(34, 58)
	subtitle.text = "Local flight-control bridge | WEG D6 ship actions | Mos Eisley approach vector"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.62, 0.70, 0.73)
	_root.add_child(subtitle)

	_mode_label = Label.new()
	_mode_label.position = _layout_vector("mode_status_position", Vector2(34, 82))
	_mode_label.size = _layout_vector("mode_status_size", Vector2(_map_size.x, 38))
	_mode_label.text = ""
	_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_label.add_theme_font_size_override("font_size", 13)
	_mode_label.modulate = Color(0.74, 0.83, 0.74)
	_root.add_child(_mode_label)

	_traffic_label = Label.new()
	_traffic_label.position = _layout_vector("traffic_status_position", Vector2(34, 122))
	_traffic_label.size = _layout_vector("traffic_status_size", Vector2(_map_size.x, 28))
	_traffic_label.text = ""
	_traffic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_traffic_label.add_theme_font_size_override("font_size", 13)
	_traffic_label.modulate = Color(0.66, 0.76, 0.77)
	_root.add_child(_traffic_label)

	_add_map_surface()
	_add_range_rings()
	_add_hazards()
	_add_contacts()
	_add_action_buttons()
	_add_selected_target_readout()
	_add_station_strip()
	_add_action_log_readout()
	_add_scan_readout()
	_add_gunnery_readout()
	_add_shield_readout()
	_update_mode_label()
	_update_traffic_label()

func _configure_layout() -> void:
	var layout := SpaceOverlayLayoutModel.layout_for_viewport(get_viewport().get_visible_rect().size)
	_map_origin = layout["map_origin"]
	_map_size = layout["map_size"]

func _panel_x() -> float:
	var layout := SpaceOverlayLayoutModel.layout_for_viewport(get_viewport().get_visible_rect().size)
	return float(layout["panel_x"])

func _panel_width() -> float:
	var layout := SpaceOverlayLayoutModel.layout_for_viewport(get_viewport().get_visible_rect().size)
	return float(layout["panel_width"])

func _layout_vector(key: String, fallback: Vector2) -> Vector2:
	var layout := SpaceOverlayLayoutModel.layout_for_viewport(get_viewport().get_visible_rect().size)
	return layout.get(key, fallback)

func _is_space_action_key(keycode: Key) -> bool:
	return [KEY_N, KEY_I, KEY_X, KEY_B, KEY_J, KEY_K, KEY_Y, KEY_L, KEY_U, KEY_T, KEY_SEMICOLON, KEY_TAB, KEY_PERIOD, KEY_COMMA].has(keycode)

func _resolve_space_action_key(keycode: Key) -> void:
	_pending_action_log_cue_level = _cue_level_for_action_key(keycode)
	match keycode:
		KEY_N:
			_resolve_sensor_sweep()
		KEY_TAB, KEY_PERIOD:
			_cycle_selected_contact(1)
		KEY_COMMA:
			_cycle_selected_contact(-1)
		KEY_I:
			_resolve_contact_identification()
		KEY_X:
			_resolve_comms_hail()
		KEY_B:
			_resolve_gunnery_drill()
		KEY_J:
			_resolve_shield_reroute()
		KEY_K:
			_resolve_damage_control()
		KEY_Y:
			_resolve_astrogation_plot()
		KEY_L:
			_resolve_maneuver_action()
		KEY_U:
			_resolve_station_assist()
		KEY_T:
			_toggle_live_traffic()
		KEY_SEMICOLON:
			_step_live_traffic()
	_pending_action_log_cue_level = ""

func _toggle_live_traffic() -> void:
	_live_traffic_enabled = not _live_traffic_enabled
	_update_traffic_label()
	_update_mode_label()
	_rebuild_action_buttons()
	var state_text := "resumed" if _live_traffic_enabled else "paused"
	_scan_label.text = "Live traffic %s after %d automatic update(s)." % [
		state_text,
		_live_traffic_tick_count,
	]
	_record_space_action("Traffic", _scan_label.text)

func _step_live_traffic() -> void:
	if _contacts.is_empty():
		_scan_label.text = "Traffic step unavailable: no contacts loaded."
		return
	_live_traffic_tick_count += 1
	_live_traffic_accumulator = 0.0
	_advance_contacts(false)

func _cycle_selected_contact(direction: int) -> void:
	var next_id := SpaceContactSelectionModel.cycle_contact_id(_contacts, _target_contact_id(), direction)
	if next_id == "":
		_scan_label.text = "No contacts available to select."
		return
	_select_contact(next_id)

func _record_space_action(category: String, text: String) -> void:
	var cue_tag := SpaceActionLogModel.consume_cue_tag(_pending_action_log_cue_level)
	_pending_action_log_cue_level = String(cue_tag.get("cue_level", ""))
	_space_action_log = SpaceActionLogModel.append_entry(_space_action_log, category, text, SpaceActionLogModel.DEFAULT_LIMIT, SpaceActionLogModel.DEFAULT_TEXT_LIMIT, String(cue_tag.get("tag", "")))
	_update_action_log_label()

func _update_action_log_label() -> void:
	if _action_log_label == null:
		return
	_action_log_label.text = SpaceActionLogModel.summary_text(_space_action_log)

func _update_traffic_label() -> void:
	if _traffic_label == null:
		return
	_traffic_label.text = SpaceStatusModel.telemetry_line(
		_space_state,
		_contacts,
		_player_ship,
		_live_traffic_enabled,
		_live_traffic_accumulator,
		_live_traffic_tick_seconds,
		_live_traffic_tick_count
	)
	_update_mode_label()

func _update_mode_label() -> void:
	if _mode_label == null:
		return
	var bridge_cue := _current_bridge_cue()
	_mode_label.text = SpaceOverlayModeModel.mode_status_text(
		_player_ship,
		_find_contact(_target_contact_id()),
		_space_state,
		_live_traffic_enabled,
		_live_traffic_tick_count,
		_current_route_preview(),
		bridge_cue
	)
	_mode_label.modulate = _mode_label_color_for_cue(bridge_cue)
	_update_station_strip()

func _mode_label_color_for_cue(bridge_cue: String) -> Color:
	match SpaceOverlayModeModel.cue_status_level(bridge_cue):
		"critical":
			return Color(1.0, 0.42, 0.32)
		"threat":
			return Color(1.0, 0.72, 0.34)
		"repair":
			return Color(0.92, 0.78, 0.46)
		"notice":
			return Color(0.70, 0.78, 0.82)
		"guidance":
			return Color(0.74, 0.86, 0.94)
		_:
			return Color(0.74, 0.83, 0.74)

func _current_route_preview() -> Dictionary:
	if _player_ship.is_empty():
		return {}
	return _model.maneuver_route_preview(_player_ship, _gunnery_drill.get("maneuver_action", {}))

func _add_map_surface() -> void:
	var surface := ColorRect.new()
	surface.position = _map_origin
	surface.size = _map_size
	surface.color = Color(0.08, 0.105, 0.12, 0.94)
	_root.add_child(surface)

	var x_axis := ColorRect.new()
	x_axis.position = _map_origin + Vector2(0, _map_size.y * 0.5)
	x_axis.size = Vector2(_map_size.x, 1)
	x_axis.color = Color(0.28, 0.36, 0.38, 0.7)
	_root.add_child(x_axis)

	var y_axis := ColorRect.new()
	y_axis.position = _map_origin + Vector2(_map_size.x * 0.5, 0)
	y_axis.size = Vector2(1, _map_size.y)
	y_axis.color = Color(0.28, 0.36, 0.38, 0.7)
	_root.add_child(y_axis)

func _add_range_rings() -> void:
	var center := _map_origin + _map_size * 0.5
	for band in _range_bands:
		if typeof(band) != TYPE_DICTIONARY:
			continue
		var radius := float(band.get("radius", 0.0))
		var ring := _ring_rect(center, radius)
		_root.add_child(ring)
		var label := Label.new()
		label.position = center + Vector2(radius + 6.0, -10.0)
		label.text = String(band.get("name", "Range"))
		label.add_theme_font_size_override("font_size", 11)
		label.modulate = Color(0.48, 0.62, 0.66)
		_root.add_child(label)

func _add_hazards() -> void:
	_hazard_visuals.clear()
	var maneuver: Dictionary = _gunnery_drill.get("maneuver_action", {})
	var hazards: Array = maneuver.get("hazards", [])
	for hazard in hazards:
		if typeof(hazard) != TYPE_DICTIONARY:
			continue
		var pos: Dictionary = hazard.get("position", {})
		var map_pos := _space_to_map(Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0))))
		var radius := float(hazard.get("radius", 0.0))
		if radius <= 0.0:
			continue
		var zone := HazardZone.new()
		zone.name = "Hazard_%s" % String(hazard.get("id", "zone"))
		zone.radius = radius
		zone.position = map_pos - Vector2(radius, radius)
		zone.size = Vector2(radius * 2.0, radius * 2.0)
		zone.mouse_filter = Control.MOUSE_FILTER_STOP
		zone.gui_input.connect(Callable(self, "_on_hazard_visual_gui_input").bind(hazard))
		_root.add_child(zone)

		var label := Label.new()
		label.position = map_pos + Vector2(radius + 8.0, -12.0)
		label.text = "%s +%d" % [
			String(hazard.get("name", "Hazard")),
			int(hazard.get("difficulty_modifier", hazard.get("modifier", 0))),
		]
		label.add_theme_font_size_override("font_size", 11)
		label.modulate = Color(0.94, 0.72, 0.44)
		_root.add_child(label)
		_hazard_visuals.append({"zone": zone, "label": label, "hazard": hazard})

func _on_hazard_visual_gui_input(event: InputEvent, hazard: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_scan_label.text = SpaceStatusModel.hazard_detail_text(hazard, _current_route_preview())
		_record_space_action("Hazard", _scan_label.text)
		get_viewport().set_input_as_handled()

func _ring_rect(center: Vector2, radius: float) -> ColorRect:
	var ring := ColorRect.new()
	ring.position = center - Vector2(radius, radius)
	ring.size = Vector2(radius * 2.0, radius * 2.0)
	ring.color = Color(0.12, 0.18, 0.2, 0.23)
	return ring

func _add_contacts() -> void:
	_contact_visuals.clear()
	for contact in _contacts:
		if typeof(contact) != TYPE_DICTIONARY:
			continue
		var pos: Dictionary = contact.get("position", {})
		var map_pos := _space_to_map(Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0))))
		var contact_id := String(contact.get("id", ""))
		var selector := ColorRect.new()
		selector.position = map_pos - Vector2(9, 9)
		selector.size = Vector2(18, 18)
		selector.color = Color(0.96, 0.78, 0.24, 0.9)
		selector.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selector.visible = false
		_root.add_child(selector)

		var dot := ColorRect.new()
		dot.position = map_pos - Vector2(5, 5)
		dot.size = Vector2(10, 10)
		dot.color = _contact_color(String(contact.get("kind", "")))
		dot.mouse_filter = Control.MOUSE_FILTER_STOP
		dot.gui_input.connect(Callable(self, "_on_contact_visual_gui_input").bind(contact_id))
		_root.add_child(dot)

		var heading := ColorRect.new()
		var heading_angle := deg_to_rad(float(contact.get("heading_degrees", 0.0)))
		heading.position = map_pos + Vector2(cos(heading_angle), -sin(heading_angle)) * 8.0 - Vector2(1.5, 1.5)
		heading.size = Vector2(3, 3)
		heading.color = Color(0.95, 0.90, 0.62, 0.9)
		_root.add_child(heading)

		var label := Label.new()
		label.position = map_pos + Vector2(10, -11)
		label.text = "%s - %s" % [String(contact.get("name", "Contact")), String(contact.get("status", ""))]
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = Color(0.84, 0.86, 0.78)
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(Callable(self, "_on_contact_visual_gui_input").bind(contact_id))
		_root.add_child(label)
		_contact_visuals[contact_id] = {
			"selector": selector,
			"dot": dot,
			"heading": heading,
			"label": label,
			"contact": contact,
		}
	_refresh_contact_visibility()

func _add_station_strip() -> void:
	_station_labels.clear()
	var rows := SpaceStationStripModel.station_rows(_player_ship, _space_state)
	var column_width := maxf(_panel_width() * 0.5, 96.0)
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var label := Label.new()
		label.position = Vector2(_panel_x() + (i % 2) * column_width, 166 + int(i / 2) * 24)
		label.size = Vector2(column_width - 8.0, 22)
		label.text = SpaceStationStripModel.station_line(row)
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = _station_row_color(row)
		_root.add_child(label)
		_station_labels[String(row.get("station", ""))] = label

func _update_station_strip() -> void:
	if _station_labels.is_empty():
		return
	for row in SpaceStationStripModel.station_rows(_player_ship, _space_state):
		var station := String(row.get("station", ""))
		if not _station_labels.has(station):
			continue
		var label: Label = _station_labels[station]
		if label == null:
			continue
		label.text = SpaceStationStripModel.station_line(row)
		label.modulate = _station_row_color(row)

func _station_row_color(row: Dictionary) -> Color:
	if bool(row.get("has_wound", false)):
		return Color(0.96, 0.54, 0.42)
	if bool(row.get("has_assist", false)):
		return Color(0.92, 0.78, 0.46)
	return Color(0.72, 0.82, 0.84)

func _add_action_log_readout() -> void:
	_action_log_label = Label.new()
	_action_log_label.position = Vector2(_panel_x(), 254)
	_action_log_label.size = Vector2(_panel_width(), 58)
	_action_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_log_label.text = SpaceActionLogModel.summary_text(_space_action_log)
	_action_log_label.add_theme_font_size_override("font_size", 12)
	_action_log_label.modulate = Color(0.67, 0.74, 0.72)
	_root.add_child(_action_log_label)

func _add_action_buttons() -> void:
	var bridge_cue := _current_bridge_cue()
	_last_bridge_cue = bridge_cue
	var actions := SpaceOverlayModeModel.action_definitions(_live_traffic_enabled, _current_route_preview(), bridge_cue)
	var x := _panel_x()
	var y := 24.0
	var button_width := 94.0
	var button_height := 28.0
	var gap := 8.0
	var buttons_per_row := maxi(int(floor((_panel_width() + gap) / (button_width + gap))), 1)
	for i in range(actions.size()):
		var action: Dictionary = actions[i]
		var button := Button.new()
		button.add_to_group("space_action_button")
		button.position = Vector2(x + (i % buttons_per_row) * (button_width + gap), y + int(i / buttons_per_row) * (button_height + gap))
		button.size = Vector2(button_width, button_height)
		button.text = String(action["button_text"])
		if action.has("tooltip_text"):
			button.tooltip_text = String(action["tooltip_text"])
		if bool(action.get("cue_highlight", false)):
			button.modulate = _cue_button_color_for_level(String(action.get("cue_status_level", "guidance")))
			button.add_theme_color_override("font_color", Color(0.08, 0.075, 0.04))
			button.add_theme_color_override("font_hover_color", Color(0.06, 0.055, 0.025))
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(Callable(self, "_resolve_space_action_key").bind(action["key"]))
		_root.add_child(button)

	var close_button := Button.new()
	close_button.add_to_group("space_action_button")
	close_button.position = Vector2(x + (actions.size() % buttons_per_row) * (button_width + gap), y + int(actions.size() / buttons_per_row) * (button_height + gap))
	close_button.size = Vector2(button_width, button_height)
	close_button.text = "Close"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(Callable(self, "_set_open").bind(false))
	_root.add_child(close_button)

func _cue_button_color_for_level(level: String) -> Color:
	match level:
		"critical":
			return Color(1.0, 0.52, 0.42)
		"threat":
			return Color(1.0, 0.76, 0.38)
		"repair":
			return Color(0.92, 0.82, 0.48)
		"notice":
			return Color(0.74, 0.82, 0.86)
		"guidance":
			return Color(0.68, 0.84, 1.0)
		_:
			return Color(1.0, 0.88, 0.48)

func _cue_level_for_action_key(keycode: Key) -> String:
	var actions := SpaceOverlayModeModel.action_definitions(_live_traffic_enabled, _current_route_preview(), _current_bridge_cue())
	for action in actions:
		if int(action.get("key", 0)) == int(keycode) and bool(action.get("cue_highlight", false)):
			return String(action.get("cue_status_level", ""))
	return ""

func _rebuild_action_buttons() -> void:
	if _root == null:
		return
	for button in get_tree().get_nodes_in_group("space_action_button"):
		if button is Node and _root.is_ancestor_of(button):
			(button as Node).queue_free()
	_add_action_buttons()

func _add_selected_target_readout() -> void:
	_selected_target_label = Label.new()
	_selected_target_label.position = Vector2(_panel_x(), 118)
	_selected_target_label.size = Vector2(_panel_width(), 42)
	_selected_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_target_label.text = ""
	_selected_target_label.add_theme_font_size_override("font_size", 12)
	_selected_target_label.modulate = Color(0.88, 0.80, 0.56)
	_root.add_child(_selected_target_label)
	_update_selected_target_readout()

func _add_scan_readout() -> void:
	_scan_label = Label.new()
	_scan_label.position = Vector2(_panel_x(), 324)
	_scan_label.size = Vector2(_panel_width(), 136)
	_scan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scan_label.text = "Sensors idle."
	_scan_label.add_theme_font_size_override("font_size", 14)
	_scan_label.modulate = Color(0.78, 0.84, 0.82)
	_root.add_child(_scan_label)

func _add_gunnery_readout() -> void:
	_gunnery_label = Label.new()
	_gunnery_label.position = Vector2(_panel_x(), 462)
	_gunnery_label.size = Vector2(_panel_width(), 132)
	_gunnery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gunnery_label.text = "Gunnery idle."
	_gunnery_label.add_theme_font_size_override("font_size", 14)
	_gunnery_label.modulate = Color(0.84, 0.80, 0.70)
	_root.add_child(_gunnery_label)

func _add_shield_readout() -> void:
	_shield_label = Label.new()
	_shield_label.position = Vector2(_panel_x(), 596)
	_shield_label.size = Vector2(_panel_width(), 104)
	_shield_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shield_label.text = "Shields idle."
	_shield_label.add_theme_font_size_override("font_size", 14)
	_shield_label.modulate = Color(0.70, 0.84, 0.90)
	_root.add_child(_shield_label)

func _resolve_sensor_sweep() -> void:
	var seed := int(_scan_rng.randi() & 0x7fffffff)
	var result: Dictionary = _model.resolve_sensor_sweep(D6Rules, _space_state, _contacts, seed, _player_ship)
	_space_state = result["state"]
	_scan_label.text = SpaceStatusModel.sensor_sweep_text(result, _contacts, seed)
	_record_space_action("Sensors", _scan_label.text)
	_refresh_contact_visibility()
	_update_selected_target_readout()
	_update_traffic_label()

func _resolve_contact_identification() -> void:
	var target_id := _target_contact_id()
	var target := _find_contact(target_id)
	if target.is_empty():
		_scan_label.text = "No contact selected for identification."
		return
	var action: Dictionary = _gunnery_drill.get("identification_action", {
		"name": "Identify contact",
		"difficulty": 15,
	})
	var seed := int(_identify_rng.randi() & 0x7fffffff)
	var result: Dictionary = _model.resolve_contact_identification(D6Rules, _space_state, target, action, seed, _player_ship)
	_space_state = result["state"]
	var event: Dictionary = result["event"]
	_scan_label.text = SpaceStatusModel.contact_identification_text(event, seed)
	_record_space_action("ID", _scan_label.text)
	_refresh_contact_visibility()
	_update_selected_target_readout()
	_update_traffic_label()

func _resolve_comms_hail() -> void:
	if _player_ship.is_empty():
		_scan_label.text = "No ship loaded."
		return
	var target_id := _target_contact_id()
	var target := _find_contact(target_id)
	if target.is_empty():
		_scan_label.text = "No contact selected for comms hail."
		return
	var action: Dictionary = _gunnery_drill.get("comms_hail_action", {
		"name": "Hail selected contact",
		"difficulty": 10,
	})
	var seed := int(_comms_rng.randi() & 0x7fffffff)
	var result: Dictionary = _model.resolve_comms_hail(D6Rules, _space_state, _player_ship, target, action, seed)
	_space_state = result["state"]
	var event: Dictionary = result["event"]
	_scan_label.text = SpaceStatusModel.comms_hail_text(event, seed)
	_record_space_action("Comms", _scan_label.text)
	_refresh_contact_visibility()
	_update_selected_target_readout()
	_update_traffic_label()

func _resolve_gunnery_drill() -> void:
	if _player_ship.is_empty():
		_gunnery_label.text = "No ship loaded."
		return

	var target_id := _target_contact_id()
	var target := _find_contact(target_id)
	if target.is_empty():
		_gunnery_label.text = "No gunnery target."
		return

	var seed := int(_gunnery_rng.randi() & 0x7fffffff)
	var result: Dictionary = _model.resolve_gunnery_exchange_with_counterfire(D6Rules, _space_state, _player_ship, target, seed)
	_space_state = result["state"]
	var updated_target: Dictionary = result.get("target", {})
	_player_ship = result.get("attacker", _player_ship)
	_update_contact_from_result(String(target.get("id", "")), updated_target)
	var event: Dictionary = result["event"]
	_gunnery_label.text = SpaceStatusModel.gunnery_action_text(
		event,
		updated_target,
		result.get("lock_disruption", {}),
		result.get("counterfire", {}),
		seed
	)
	_record_space_action("Gunnery", _gunnery_label.text)
	_update_selected_target_readout()
	_update_traffic_label()

func _update_contact_from_result(contact_id: String, updated_contact: Dictionary) -> void:
	if contact_id == "" or updated_contact.is_empty():
		return
	for i in range(_contacts.size()):
		if typeof(_contacts[i]) == TYPE_DICTIONARY and String(_contacts[i].get("id", "")) == contact_id:
			_contacts[i] = updated_contact
			break
	if _contact_visuals.has(contact_id):
		var visual: Dictionary = _contact_visuals[contact_id]
		visual["contact"] = updated_contact
		_contact_visuals[contact_id] = visual
		_update_contact_visual_position(contact_id, updated_contact)
	_update_selected_target_readout()

func _advance_contacts(auto_tick: bool = false) -> void:
	var result: Dictionary = _model.advance_tactical_round(_space_state, _player_ship, _contacts)
	_space_state = result["state"]
	_player_ship = result.get("ship", _player_ship)
	_contacts = result["contacts"]
	if not result.get("ready_hostile_fire_events", []).is_empty():
		var fire_seed := (_live_traffic_tick_count * 10007) + 503
		var fire_result: Dictionary = _model.resolve_ready_hostile_fire(D6Rules, _space_state, _player_ship, _contacts, result.get("ready_hostile_fire_events", []), fire_seed)
		_space_state = fire_result["state"]
		_player_ship = fire_result.get("ship", _player_ship)
		_contacts = fire_result.get("contacts", _contacts)
		result["state"] = _space_state
		result["ship"] = _player_ship
		result["contacts"] = _contacts
		result["automatic_hostile_fire_events"] = fire_result.get("events", [])
	for contact in _contacts:
		if typeof(contact) == TYPE_DICTIONARY:
			_update_contact_visual_position(String(contact.get("id", "")), contact)
	_refresh_contact_visibility()
	_update_selected_target_readout()
	_scan_label.text = SpaceStatusModel.traffic_tick_text(result, auto_tick)
	if not auto_tick:
		_record_space_action("Traffic", _scan_label.text)
	_update_traffic_label()

func _resolve_shield_reroute() -> void:
	if _player_ship.is_empty():
		_shield_label.text = "No ship loaded."
		return

	var requested_arcs: Array = _gunnery_drill.get("shield_reroute_arcs", ["front", "rear"])
	var seed := int(_shield_rng.randi() & 0x7fffffff)
	var result: Dictionary = _model.resolve_shield_reroute(D6Rules, _space_state, _player_ship, requested_arcs, seed)
	_space_state = result["state"]
	_player_ship = result["ship"]
	var event: Dictionary = result["event"]
	_shield_label.text = SpaceStatusModel.shield_reroute_text(event, seed)
	_record_space_action("Shields", _shield_label.text)
	_update_traffic_label()

func _resolve_damage_control() -> void:
	var target_id := _target_contact_id()
	var target := _find_contact(target_id)
	var target_selection: Dictionary = _model.damage_control_target(_player_ship, target)
	var repair_target: Dictionary = target_selection.get("ship", {})
	var system := String(target_selection.get("system", ""))
	if repair_target.is_empty() or system == "":
		_shield_label.text = "Damage control idle: no repairable local or target condition."
		return
	var repairs_player := String(target_selection.get("role", "")) == "player"

	var seed := int(_repair_rng.randi() & 0x7fffffff)
	var repair_pool := String(_gunnery_drill.get("damage_control_pool", "5D"))
	var result: Dictionary = _model.resolve_damage_control(D6Rules, _space_state, repair_target, system, repair_pool, seed, true)
	_space_state = result["state"]
	var repaired_ship: Dictionary = result.get("ship", {})
	if repairs_player:
		_player_ship = repaired_ship
	else:
		_update_contact_from_result(String(repair_target.get("id", "")), repaired_ship)
	var event: Dictionary = result["event"]
	_shield_label.text = SpaceStatusModel.damage_control_text(event, repaired_ship, seed)
	_record_space_action("Repair", _shield_label.text)
	_update_selected_target_readout()
	_update_traffic_label()

func _resolve_astrogation_plot() -> void:
	if _player_ship.is_empty():
		_shield_label.text = "No ship loaded."
		return
	var action: Dictionary = _gunnery_drill.get("astrogation_action", {
		"name": "Plot local jump corridor",
		"difficulty": 15,
	})
	var seed := int(_astrogation_rng.randi() & 0x7fffffff)
	var result: Dictionary = _model.resolve_astrogation_plot(D6Rules, _space_state, _player_ship, action, seed)
	_space_state = result["state"]
	_player_ship = result["ship"]
	var event: Dictionary = result["event"]
	_shield_label.text = SpaceStatusModel.astrogation_plot_text(event, _player_ship, seed)
	_record_space_action("Astro", _shield_label.text)
	_update_traffic_label()

func _resolve_station_assist() -> void:
	if _player_ship.is_empty():
		_shield_label.text = "No ship loaded."
		return

	var actions := _station_assist_actions()
	if actions.is_empty():
		_shield_label.text = "No station assist actions loaded."
		return

	var assist: Dictionary = actions[_station_assist_index % actions.size()]
	_station_assist_index += 1
	var seed := int(_station_rng.randi() & 0x7fffffff)
	var result: Dictionary = _model.resolve_crew_station_assist(D6Rules, _space_state, _player_ship, assist, seed)
	_space_state = result["state"]
	var event: Dictionary = result["event"]
	_shield_label.text = SpaceStatusModel.station_assist_action_text(event, seed)
	_record_space_action("Assist", _shield_label.text)
	_update_traffic_label()

func _resolve_maneuver_action() -> void:
	if _player_ship.is_empty():
		_shield_label.text = "No ship loaded."
		return

	var maneuver: Dictionary = _gunnery_drill.get("maneuver_action", {
		"name": "Bank",
		"difficulty": 10,
		"modifier": 0,
		"turn_degrees": 45,
		"move_units": 24,
	})
	var seed := int(_maneuver_rng.randi() & 0x7fffffff)
	var result: Dictionary = _model.resolve_maneuver_action(D6Rules, _space_state, _player_ship, maneuver, seed)
	_space_state = result["state"]
	_player_ship = result["ship"]
	var event: Dictionary = result["event"]
	_shield_label.text = SpaceStatusModel.maneuver_action_text(event, _player_ship, seed)
	_record_space_action("Maneuver", _shield_label.text)
	_update_traffic_label()
	_rebuild_action_buttons()

func _find_contact(contact_id: String) -> Dictionary:
	for contact in _contacts:
		if typeof(contact) == TYPE_DICTIONARY and String(contact.get("id", "")) == contact_id:
			return contact
	return {}

func _target_contact_id() -> String:
	if _selected_contact_id != "":
		return _selected_contact_id
	return String(_gunnery_drill.get("default_target_id", ""))

func _on_contact_visual_gui_input(event: InputEvent, contact_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_contact(contact_id)
		get_viewport().set_input_as_handled()

func _select_contact(contact_id: String) -> void:
	if contact_id == "" or _find_contact(contact_id).is_empty():
		return
	_selected_contact_id = contact_id
	_refresh_contact_visibility()
	_update_selected_target_readout()
	_scan_label.text = SpaceStatusModel.selected_contact_action_text(_find_contact(contact_id), _space_state, contact_id)
	_record_space_action("Target", _scan_label.text)
	_update_mode_label()

func _update_selected_target_readout() -> void:
	if _selected_target_label == null:
		return
	var target_id := _target_contact_id()
	var target := _find_contact(target_id)
	var targeting_context := _model.targeting_context_for_contact(_space_state, target) if not target.is_empty() else {}
	_selected_target_label.text = SpaceStatusModel.selected_contact_detail_text(target, _space_state, target_id, targeting_context)
	_refresh_action_button_cues()

func _current_bridge_cue() -> String:
	var target_id := _target_contact_id()
	var target := _find_contact(target_id)
	var targeting_context := _model.targeting_context_for_contact(_space_state, target) if not target.is_empty() else {}
	return SpaceStatusModel.bridge_cue_label(target, _space_state, _player_ship, target_id, targeting_context)

func _refresh_action_button_cues() -> void:
	if _root == null:
		return
	var bridge_cue := _current_bridge_cue()
	if bridge_cue == _last_bridge_cue:
		return
	_last_bridge_cue = bridge_cue
	_rebuild_action_buttons()

func _station_assist_actions() -> Array:
	var actions: Array = _gunnery_drill.get("station_assist_actions", [])
	if not actions.is_empty():
		return actions
	var legacy: Dictionary = _gunnery_drill.get("station_assist_action", {
		"name": "Copilot vectors",
		"station": "copilot",
		"target_action": "maneuver",
		"pool": "4D",
		"bonus_pool": "1D",
		"difficulty": 10,
	})
	return [legacy]

func _refresh_contact_visibility() -> void:
	var revealed: Array = _space_state.get("revealed_contacts", [])
	for contact_id in _contact_visuals.keys():
		var entry: Dictionary = _contact_visuals[contact_id]
		var contact: Dictionary = entry.get("contact", {})
		var selector: ColorRect = entry.get("selector")
		var dot: ColorRect = entry.get("dot")
		var label: Label = entry.get("label")
		if dot == null or label == null:
			continue
		if selector != null:
			selector.visible = String(contact_id) == _target_contact_id()
		var hidden := bool(contact.get("hidden_until_revealed", false)) and not revealed.has(contact_id)
		if hidden:
			dot.color = Color(0.36, 0.34, 0.30, 0.82)
			label.text = SpaceStatusModel.contact_visual_label_text(contact, _space_state, contact_id)
			label.modulate = Color(0.54, 0.53, 0.46)
		else:
			dot.color = _contact_color(String(contact.get("kind", "")))
			label.text = SpaceStatusModel.contact_visual_label_text(contact, _space_state, contact_id)
			label.modulate = Color(0.84, 0.86, 0.78)

func _update_contact_visual_position(contact_id: String, contact: Dictionary) -> void:
	if contact_id == "" or not _contact_visuals.has(contact_id):
		return
	var visual: Dictionary = _contact_visuals[contact_id]
	var selector: ColorRect = visual.get("selector")
	var dot: ColorRect = visual.get("dot")
	var heading: ColorRect = visual.get("heading")
	var label: Label = visual.get("label")
	var pos: Dictionary = contact.get("position", {})
	var map_pos := _space_to_map(Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0))))
	if selector != null:
		selector.position = map_pos - Vector2(9, 9)
	if dot != null:
		dot.position = map_pos - Vector2(5, 5)
	if heading != null:
		var heading_angle := deg_to_rad(float(contact.get("heading_degrees", 0.0)))
		heading.position = map_pos + Vector2(cos(heading_angle), -sin(heading_angle)) * 8.0 - Vector2(1.5, 1.5)
	if label != null:
		label.position = map_pos + Vector2(10, -11)

func _space_to_map(pos: Vector2) -> Vector2:
	var normalized := Vector2(
		clampf((pos.x + 320.0) / 640.0, 0.0, 1.0),
		clampf((180.0 - pos.y) / 360.0, 0.0, 1.0)
	)
	return _map_origin + normalized * _map_size

func _contact_color(kind: String) -> Color:
	match kind:
		"landing_beacon":
			return Color(0.92, 0.72, 0.24)
		"freighter":
			return Color(0.34, 0.74, 0.86)
		"patrol":
			return Color(0.45, 0.66, 0.95)
		"courier":
			return Color(0.74, 0.52, 0.86)
		"unknown":
			return Color(0.92, 0.36, 0.34)
		_:
			return Color(0.82, 0.84, 0.78)
