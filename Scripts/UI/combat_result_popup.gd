extends Control

## Popup that narrates the result of a duel in text form.
## Instantiated by UIManager.spawn_popup() with a result Dictionary from CombatManager.

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(520, 420)
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

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row (drag handle)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_STOP
	title_row.mouse_default_cursor_shape = Control.CURSOR_DRAG
	title_row.gui_input.connect(_on_drag_input)
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "⚔  Duel — Chronicle of the Jianghu"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_row.add_child(title_lbl)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.pressed.connect(queue_free)
	title_row.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	# Scrollable narration area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var narration_vbox := VBoxContainer.new()
	narration_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narration_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(narration_vbox)
	narration_vbox.set_meta("_narration_vbox", true)
	set_meta("narration_vbox", narration_vbox)

	vbox.add_child(HSeparator.new())

	# Summary label
	var summary_lbl := RichTextLabel.new()
	summary_lbl.bbcode_enabled = false
	summary_lbl.fit_content = true
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(summary_lbl)
	set_meta("summary_lbl", summary_lbl)

	# Close button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var dismiss_btn := Button.new()
	dismiss_btn.text = "Dismiss"
	dismiss_btn.custom_minimum_size = Vector2(120, 40)
	dismiss_btn.pressed.connect(queue_free)
	btn_row.add_child(dismiss_btn)

func setup_popup(result: Dictionary) -> void:
	await ready  # Ensure _build_ui ran first
	var narration_vbox: VBoxContainer = get_meta("narration_vbox")
	var summary_lbl: RichTextLabel = get_meta("summary_lbl")

	# Populate round narrations
	for line in result.get("round_narrations", []):
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
		narration_vbox.add_child(lbl)

	# Summary in gold/green/red
	var summary: String = result.get("final_summary", "The battle concludes.")
	summary_lbl.text = summary
	if result.get("draw", false):
		summary_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	else:
		var winner_id: String = result.get("winner_id", "")
		var player_char = SimulationManager.get_character(GameManager.player_char_id)
		if player_char and winner_id == player_char.char_id:
			summary_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		else:
			summary_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	# Append any consequence notes
	if result.get("loser_delta", {}).get("injured", false):
		var loser_char = SimulationManager.get_character(result.get("loser_id", ""))
		if loser_char:
			var note := Label.new()
			note.text = "⚠  " + loser_char.get_full_name() + " has been injured in the fight."
			note.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			narration_vbox.add_child(note)
