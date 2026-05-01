extends Control

## Displays the global World Log (Chronicle of the Jianghu) in a scrollable panel.

const TYPE_COLORS: Dictionary = {
	"war": Color(0.9, 0.3, 0.3),
	"politics": Color(0.9, 0.7, 0.3),
	"positive": Color(0.4, 0.9, 0.5),
	"event": Color(0.6, 0.7, 0.9),
	"succession": Color(0.8, 0.5, 0.9),
	"sect collapse": Color(0.95, 0.4, 0.2),
	"social": Color(0.9, 0.85, 0.5),
	"system": Color(0.7, 0.7, 0.7),
	"diplomacy": Color(0.5, 0.8, 0.9),
}

## Display labels for log type filter buttons (handles multi-word types).
const TYPE_LABELS: Dictionary = {
	"war": "War",
	"politics": "Politics",
	"positive": "Positive",
	"event": "Event",
	"succession": "Succession",
	"sect collapse": "Sect Collapse",
	"social": "Social",
	"system": "System",
	"diplomacy": "Diplomacy",
}
const DEFAULT_ACTIVE_TYPES: Array[String] = [
	"war", "politics", "succession", "sect collapse", "diplomacy", "event", "positive"
]

# Which types are currently visible (lower-cased)
var _active_filters: Dictionary = {}
# Button references for toggling (type_key → Button)
var _filter_buttons: Dictionary = {}

func _ready() -> void:
	UIManager.register_panel("world_log", self, UIManager.Layer.PANELS)
	%BtnClose.pressed.connect(func(): UIManager.close_panel("world_log"))
	WorldLogManager.log_added.connect(_on_log_added)
	_build_filter_bar()

## Bring this panel to the front whenever the player clicks anywhere on it.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		move_to_front()

func _build_filter_bar() -> void:
	var row: HFlowContainer = %FilterRow
	
	var lbl := Label.new()
	lbl.text = "Filter:"
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(lbl)
	
	var all_types: Array[String] = [
		"war", "politics", "succession", "sect collapse",
		"diplomacy", "event", "positive", "social", "system"
	]
	
	for t in all_types:
		var active: bool = DEFAULT_ACTIVE_TYPES.has(t)
		_active_filters[t] = active
		
		var btn := Button.new()
		btn.text = TYPE_LABELS.get(t, t.capitalize())
		btn.custom_minimum_size = Vector2(85, 24)
		btn.toggle_mode = true
		btn.button_pressed = active
		btn.add_theme_font_size_override("font_size", 11)
		
		var t_capture := t
		btn.toggled.connect(func(pressed: bool):
			_active_filters[t_capture] = pressed
			_rebuild_log()
		)
		
		row.add_child(btn)
		_filter_buttons[t] = btn

## Called by UIManager when the panel is opened.
func setup_panel(_payload: Variant = null) -> void:
	_rebuild_log()

func _rebuild_log() -> void:
	# Clear existing entries
	for child in %LogList.get_children():
		child.queue_free()
	
	for entry in WorldLogManager.global_logs:
		if _is_entry_visible(entry):
			_add_log_entry(entry)

func _is_entry_visible(entry: Dictionary) -> bool:
	var log_type: String = entry.get("type", "system").to_lower()
	# If the type is not in our filter map at all, show it by default
	if not _active_filters.has(log_type):
		return true
	return _active_filters[log_type]

func _on_log_added(entry: Dictionary) -> void:
	# Only update if the panel is currently visible
	if not visible:
		return
	if not _is_entry_visible(entry):
		return
	# Prepend the new entry at the top of the list
	_add_log_entry_at_top(entry)

func _add_log_entry(entry: Dictionary) -> void:
	var label := _create_log_label(entry)
	%LogList.add_child(label)

func _add_log_entry_at_top(entry: Dictionary) -> void:
	var label := _create_log_label(entry)
	%LogList.add_child(label)
	%LogList.move_child(label, 0)

func _create_log_label(entry: Dictionary) -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = false
	lbl.fit_content = true
	lbl.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	lbl.custom_minimum_size = Vector2(0, 24)
	
	var log_type = entry.get("type", "system").to_lower()
	var color = TYPE_COLORS.get(log_type, Color.WHITE)
	
	var date_str = str(entry.get("date", "?"))
	var msg = str(entry.get("message", ""))
	lbl.push_color(Color(0.533333, 0.533333, 0.533333))
	lbl.add_text("[%s]" % date_str)
	lbl.pop()
	lbl.add_text(" ")
	lbl.push_color(color)
	lbl.add_text(msg)
	lbl.pop()
	
	return lbl
