extends Control

## Dynamic UI for Events
## Instantiated by UIManager.spawn_popup()

var current_event_id: String = ""
var current_context: Dictionary = {}

# ── DRAG STATE ───────────────────────────────────────────────────
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Ensure the popup blocks interactions behind it
	mouse_filter = Control.MOUSE_FILTER_STOP

## Bring this panel to the front whenever the player clicks anywhere on it.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		move_to_front()

## Handles drag-and-drop input from the title label.
func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var abs_pos := get_global_rect().position
			anchor_left = 0.0
			anchor_top = 0.0
			anchor_right = 0.0
			anchor_bottom = 0.0
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
		var max_x = max(0.0, vp.x - size.x)
		var max_y = max(0.0, vp.y - size.y)
		new_pos.x = clamp(new_pos.x, 0.0, max_x)
		new_pos.y = clamp(new_pos.y, 0.0, max_y)
		position = new_pos
		accept_event()

## Called automatically by UIManager.spawn_popup() if passed in payload
func setup_popup(payload: Dictionary) -> void:
	current_event_id = payload.get("event_id", "")
	current_context = payload.get("context", {})
	
	var event_data = DataManager.events_registry.get(current_event_id, {})
	
	# 1. Setup Text & Image
	%TitleLabel.text = event_data.get("title", "Event")
	%DescLabel.text = EventManager._format_string(event_data.get("description", ""), current_context)
	
	# 2. Wire TitleLabel as a drag handle
	%TitleLabel.mouse_filter = Control.MOUSE_FILTER_STOP
	%TitleLabel.mouse_default_cursor_shape = Control.CURSOR_DRAG
	if not %TitleLabel.gui_input.is_connected(_on_drag_input):
		%TitleLabel.gui_input.connect(_on_drag_input)
	
	# 3. Build Buttons
	_build_options(event_data.get("options", {}))

func _build_options(options: Dictionary) -> void:
	var container = %OptionsContainer
	for child in container.get_children():
		child.queue_free()
		
	for opt_id in options:
		var opt_data = options[opt_id]
		var btn = Button.new()
		
		# Replace dynamic text in the button itself if needed
		btn.text = EventManager._format_string(opt_data.get("text", "Confirm"), current_context)
		btn.custom_minimum_size = Vector2(0, 40)
		
		# Connect the click event
		btn.pressed.connect(func(): _on_option_selected(opt_id))
		container.add_child(btn)

func _on_option_selected(option_id: String) -> void:
	EventManager.select_player_option(current_event_id, option_id, current_context)
	queue_free() # Destroy the popup
