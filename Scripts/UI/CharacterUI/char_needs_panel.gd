extends MarginContainer

@export var vbox : VBoxContainer

func refresh_panel(character: CharacterData, dashboard: CharacterDashboard) -> void:
	for child in vbox.get_children():
		child.queue_free()
		
	if not dashboard.is_data_visible("needs"):
		var lbl = Label.new()
		lbl.text = "Mental State Unknown"
		vbox.add_child(lbl)
		return

	# Add Master Mood
	_add_progress_bar(vbox, "Mood", character.state_vars.get("mood", 50.0), Color.CORNFLOWER_BLUE)
	
	# Add negative states (Fatigue, Stress)
	_add_progress_bar(vbox, "Fatigue", character.state_vars.get("fatigue", 0.0), Color.INDIAN_RED)
	_add_progress_bar(vbox, "Stress", character.state_vars.get("stress", 0.0), Color.ORANGE_RED)

func _add_progress_bar(parent: Control, label_text: String, value: float, color: Color) -> void:
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(80, 0)
	
	var bar = ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 100.0
	bar.value = value
	bar.modulate = color # Simple tinting
	
	hbox.add_child(lbl)
	hbox.add_child(bar)
	parent.add_child(hbox)
