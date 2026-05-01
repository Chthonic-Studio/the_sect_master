extends Control

## Popup allowing the player to assign a directive/mission to a sect member.
## Shows available mission types with duration, cost, and expected benefits.

var _target_char: CharacterData = null
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

## Available missions: id, display name, description, duration, directive class path
const MISSIONS: Array = [
	{
		"id":        "directive_scouting_patrol",
		"name":      "Scouting Patrol",
		"desc":      "Send this disciple on a scouting patrol. Gains sect FACE on return.\nDuration: 20 days.",
		"duration":  20,
		"path":      "res://Scripts/AI/Directives/directive_scouting_patrol.gd"
	},
	{
		"id":        "directive_diplomatic_envoy",
		"name":      "Diplomatic Envoy",
		"desc":      "Dispatch as a diplomatic envoy to improve relations with a rival sect.\nDuration: 30 days.",
		"duration":  30,
		"path":      "res://Scripts/AI/Directives/directive_diplomatic_envoy.gd"
	},
	{
		"id":        "directive_training_retreat",
		"name":      "Training Retreat",
		"desc":      "Intensive off-site training. Significant martial stat gains.\nDuration: 30 days.",
		"duration":  30,
		"path":      "res://Scripts/AI/Directives/directive_training_retreat.gd"
	},
	{
		"id":        "directive_seclusion_cultivation",
		"name":      "Secluded Cultivation",
		"desc":      "Deep seclusion meditation. Chance of realm breakthrough — or Qi Deviation.\nDuration: 90 days.",
		"duration":  90,
		"path":      "res://Scripts/AI/Directives/directive_seclusion_cultivation.gd"
	},
	{
		"id":        "directive_explore_ruins",
		"name":      "Explore Ancient Ruins",
		"desc":      "Venture into ruins. Risk of stress and injury, but chance of rare rewards.\nDuration: configurable (default 10 days).",
		"duration":  10,
		"path":      "res://Scripts/AI/Directives/directive_explore_ruins.gd"
	},
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(540, 480)
	set_anchors_preset(Control.PRESET_CENTER)
	_build_ui()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		move_to_front()

func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var abs_pos := get_global_rect().position
			anchor_left = 0.0; anchor_top = 0.0
			anchor_right = 0.0; anchor_bottom = 0.0
			position = abs_pos
			_drag_offset = event.global_position - abs_pos
			_dragging = true
			move_to_front()
			accept_event()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var new_pos = event.global_position - _drag_offset
		var vp := get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 0.0, max(0.0, vp.x - size.x))
		new_pos.y = clamp(new_pos.y, 0.0, max(0.0, vp.y - size.y))
		position = new_pos
		accept_event()

func setup_popup(character: CharacterData) -> void:
	_target_char = character
	if not is_node_ready():
		await ready
	_refresh_title()

func _refresh_title() -> void:
	if _target_char:
		var lbl = get_node_or_null("Margin/VBox/TitleRow/TitleLabel")
		if lbl:
			lbl.text = "Assign Mission — " + _target_char.get_full_name()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.mouse_filter = Control.MOUSE_FILTER_STOP
	title_row.mouse_default_cursor_shape = Control.CURSOR_DRAG
	title_row.gui_input.connect(_on_drag_input)
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = "Assign Mission"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_row.add_child(title_lbl)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.pressed.connect(queue_free)
	title_row.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	# Active directive status
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.text = "No mission currently active."
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_lbl)

	# Mission list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(list_vbox)

	for mission in MISSIONS:
		_build_mission_row(list_vbox, mission)

func _build_mission_row(parent: VBoxContainer, mission: Dictionary) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = mission["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	text_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = mission["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_lbl.add_theme_font_size_override("font_size", 11)
	text_vbox.add_child(desc_lbl)

	var assign_btn := Button.new()
	assign_btn.text = "Assign"
	assign_btn.custom_minimum_size = Vector2(80, 36)
	var mission_capture: Dictionary = mission
	assign_btn.pressed.connect(func(): _on_assign_pressed(mission_capture))
	hbox.add_child(assign_btn)

func _on_assign_pressed(mission: Dictionary) -> void:
	if not _target_char: return

	# Cannot assign a new directive if one is already active
	if _target_char.current_directive != null:
		return

	var directive_script = load(mission["path"])
	if not directive_script:
		printerr("MissionPickerPopup: Failed to load directive at ", mission["path"])
		return

	var new_directive: Directive = directive_script.new(mission["duration"])
	_target_char.current_directive = new_directive

	_target_char.add_log("Assigned to mission: " + mission["name"] + " (Duration: " + str(mission["duration"]) + " days).")
	WorldLogManager.add_log("politics", _target_char.get_full_name() + " has been assigned to: " + mission["name"] + ".")

	queue_free()
