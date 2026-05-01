extends Control

## Popup that narrates the result of a duel in text form.
## Instantiated by UIManager.spawn_popup() with a result Dictionary from CombatManager.
## All static UI elements are defined in combat_result_popup.tscn.

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Connect drag handle on the title row
	var title_row = $MarginContainer/VBoxContainer/TitleRow
	title_row.gui_input.connect(_on_drag_input)
	%BtnClose.pressed.connect(queue_free)
	%BtnDismiss.pressed.connect(queue_free)

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

func setup_popup(result: Dictionary) -> void:
	if not is_node_ready():
		await ready

	# Populate round narrations
	for line in result.get("round_narrations", []):
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
		%NarrationVBox.add_child(lbl)

	# Summary in gold/green/red
	var summary: String = result.get("final_summary", "The battle concludes.")
	%SummaryLabel.text = summary
	if result.get("draw", false):
		%SummaryLabel.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	else:
		var winner_id: String = result.get("winner_id", "")
		var player_char = SimulationManager.get_character(GameManager.player_char_id)
		if player_char and winner_id == player_char.char_id:
			%SummaryLabel.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		else:
			%SummaryLabel.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

	# Append any consequence notes
	if result.get("loser_delta", {}).get("injured", false):
		var loser_char = SimulationManager.get_character(result.get("loser_id", ""))
		if loser_char:
			var note := Label.new()
			note.text = "⚠  " + loser_char.get_full_name() + " has been injured in the fight."
			note.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			%NarrationVBox.add_child(note)

