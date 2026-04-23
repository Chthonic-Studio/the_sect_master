extends MarginContainer

@export var vbox : VBoxContainer
var _cached_bars: Dictionary = {}

func refresh_panel(character: CharacterData, dashboard: CharacterDashboard) -> void:
	if not dashboard.is_data_visible("needs"):
		_hide_all_bars()
		# Optionally show a single static label here
		return

	# We update existing bars instead of creating new ones
	_update_progress_bar("Mood", character.state_vars.get("mood", 50.0), Color.CORNFLOWER_BLUE)
	_update_progress_bar("Fatigue", character.state_vars.get("fatigue", 0.0), Color.INDIAN_RED)
	_update_progress_bar("Stress", character.state_vars.get("stress", 0.0), Color.ORANGE_RED)

func _update_progress_bar(need_key: String, value: float, color: Color) -> void:
	var bar_data
	
	if _cached_bars.has(need_key):
		bar_data = _cached_bars[need_key]
		bar_data.container.show()
	else:
		# Create it only once
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = need_key
		lbl.custom_minimum_size = Vector2(80, 0)
		
		var bar = ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.max_value = 100.0
		
		hbox.add_child(lbl)
		hbox.add_child(bar)
		vbox.add_child(hbox)
		
		bar_data = { "container": hbox, "bar": bar }
		_cached_bars[need_key] = bar_data
		
	# Update the existing node
	bar_data.bar.value = value
	bar_data.bar.modulate = color

func _hide_all_bars() -> void:
	for key in _cached_bars:
		_cached_bars[key].container.hide()
