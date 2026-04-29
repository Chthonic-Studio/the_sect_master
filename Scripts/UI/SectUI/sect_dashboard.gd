extends Control
class_name SectDashboard

## Master controller for the Sect UI. 
## Routes the active SectData down to the specialized sub-panels.

var active_sect: SectData

# ── DRAG STATE ───────────────────────────────────────────────────
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Tell the UIManager this panel exists and is ready to receive data, and put it in the PANELS layer.
	UIManager.register_panel("sect_dashboard", self, UIManager.Layer.PANELS)
	$CloseButton.pressed.connect(func(): UIManager.close_panel("sect_dashboard"))
	# Wire the header as a drag handle
	var header := $MarginContainer/VBoxContainer/Header
	if header:
		header.mouse_filter = Control.MOUSE_FILTER_STOP
		header.mouse_default_cursor_shape = Control.CURSOR_DRAG
		header.gui_input.connect(_on_drag_input)

## Bring this panel to the front whenever the player clicks anywhere on it.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		move_to_front()

## Handles drag-and-drop input from the header bar.
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
		var new_pos := event.global_position - _drag_offset
		var vp := get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 0.0, vp.x - size.x)
		new_pos.y = clamp(new_pos.y, 0.0, vp.y - size.y)
		position = new_pos
		accept_event()

func setup_dashboard(sect: SectData) -> void:
	if active_sect and active_sect.strength_recalculated.is_connected(_on_strength_recalculated):
		active_sect.strength_recalculated.disconnect(_on_strength_recalculated)
		
	active_sect = sect
	
	%SectNameLabel.text = active_sect.sect_name
	_on_strength_recalculated(active_sect)
	
	if not active_sect.strength_recalculated.is_connected(_on_strength_recalculated):
		active_sect.strength_recalculated.connect(_on_strength_recalculated)
	
	if %LedgerPanel.has_method("setup_panel"):
		%LedgerPanel.setup_panel(active_sect)
	if %HierarchyPanel.has_method("setup_panel"):
		%HierarchyPanel.setup_panel(active_sect)
	if %InfrastructurePanel.has_method("setup_panel"):
		%InfrastructurePanel.setup_panel(active_sect)
	if %PreceptsPanel.has_method("setup_panel"):
		%PreceptsPanel.setup_panel(active_sect)

func _on_strength_recalculated(sect: SectData) -> void:
	%SectStrengthLabel.text = "SS: " + str(sect.cached_sect_strength)
