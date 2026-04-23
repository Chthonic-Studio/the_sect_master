extends MarginContainer

func refresh_panel(character: CharacterData, dashboard: CharacterDashboard) -> void:
	var vbox = %LogVBox
	for child in vbox.get_children():
		child.queue_free()
		
	if not dashboard.is_data_visible("log"):
		var lbl = Label.new()
		lbl.text = "You do not have the intelligence level to view this character's private log."
		lbl.add_theme_color_override("font_color", Color.GRAY)
		vbox.add_child(lbl)
		return
		
	if character.personal_log.is_empty():
		var lbl = Label.new()
		lbl.text = "No recent events."
		vbox.add_child(lbl)
		return
		
	for log_entry in character.personal_log:
		var lbl = Label.new()
		lbl.text = log_entry
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)
