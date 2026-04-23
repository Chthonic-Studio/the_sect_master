extends Control

## Dynamic UI for Events
## Instantiated by UIManager.spawn_popup()

var current_event_id: String = ""
var current_context: Dictionary = {}

func _ready() -> void:
	# Ensure the popup blocks interactions behind it
	mouse_filter = Control.MOUSE_FILTER_STOP

## Called automatically by UIManager.spawn_popup() if passed in payload
func setup_popup(payload: Dictionary) -> void:
	current_event_id = payload.get("event_id", "")
	current_context = payload.get("context", {})
	
	var event_data = DataManager.events_registry.get(current_event_id, {})
	
	# 1. Setup Text & Image
	%TitleLabel.text = event_data.get("title", "Event")
	%DescLabel.text = EventManager._format_string(event_data.get("description", ""), current_context)
	
	# 2. Pause Game if requested
	if event_data.get("requires_pause", false):
		TimeManager.set_time_speed(TimeManager.Speed.PAUSED)
		
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
