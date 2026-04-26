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
	"system": Color(0.7, 0.7, 0.7)
}

func _ready() -> void:
	UIManager.register_panel("world_log", self, UIManager.Layer.PANELS)
	%BtnClose.pressed.connect(func(): UIManager.close_panel("world_log"))
	WorldLogManager.log_added.connect(_on_log_added)

## Called by UIManager when the panel is opened.
func setup_panel(_payload: Variant = null) -> void:
	_rebuild_log()

func _rebuild_log() -> void:
	# Clear existing entries
	for child in %LogList.get_children():
		child.queue_free()
	
	for entry in WorldLogManager.global_logs:
		_add_log_entry(entry)

func _on_log_added(entry: Dictionary) -> void:
	# Only update if the panel is currently visible
	if not visible:
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
