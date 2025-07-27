# TimeMenu.gd
# Manages the UI for the time and speed controls.
# Place on the root Control node of time_menu.tscn.

extends Control

# === Node References (set these in the Inspector) ===
@export var date_label: Label
@export var speed_label: Label
@export var normal_speed_button: TextureButton
@export var fast_speed_button: TextureButton
@export var fastest_speed_button: TextureButton
@export var pause_button: TextureButton

# --- Initialization ---
func _ready() -> void:
	# Connect UI button presses to their handler functions.
	normal_speed_button.pressed.connect(Callable(TimeManager, "set_speed").bind(0))
	fast_speed_button.pressed.connect(Callable(TimeManager, "set_speed").bind(1))
	fastest_speed_button.pressed.connect(Callable(TimeManager, "set_speed").bind(2))
	pause_button.pressed.connect(Callable(TimeManager, "toggle_pause"))

	# Connect to TimeManager signals to receive updates.
	TimeManager.connect("day_passed", Callable(self, "_on_day_passed"))
	TimeManager.connect("speed_changed", Callable(self, "_on_speed_changed"))
	TimeManager.connect("time_paused", Callable(self, "_on_time_paused"))
	TimeManager.connect("time_resumed", Callable(self, "_on_time_resumed"))

	# Set initial state.
	_update_date_display()
	_on_speed_changed(TimeManager.speed_index, TimeManager.speed_multipliers[TimeManager.speed_index])
	if TimeManager.is_paused():
		_on_time_paused()

# --- Signal Handlers ---

func _on_day_passed(_year: int, _season: int, _period: int, _day: int) -> void:
	_update_date_display()

func _on_speed_changed(speed_index: int, speed_multiplier: float) -> void:
	speed_label.text = "%sx Speed" % speed_multiplier
	# Disable the button corresponding to the current speed.
	normal_speed_button.disabled = (speed_index == 0)
	fast_speed_button.disabled = (speed_index == 1)
	fastest_speed_button.disabled = (speed_index == 2)
	speed_label.modulate = Color.WHITE

func _on_time_paused() -> void:
	speed_label.text = "Paused"
	speed_label.modulate = Color.GRAY # Use color to indicate paused state.

func _on_time_resumed() -> void:
	# When resuming, restore the speed label to the current speed.
	var current_speed_idx = TimeManager.speed_index
	_on_speed_changed(current_speed_idx, TimeManager.speed_multipliers[current_speed_idx])

# --- Internal Logic ---

func _update_date_display() -> void:
	if is_instance_valid(date_label):
		date_label.text = TimeManager.get_date_string()
