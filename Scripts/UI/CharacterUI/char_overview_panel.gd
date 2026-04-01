extends MarginContainer

## Handles static numbers and traits.

func refresh_panel(character: CharacterData, dashboard: CharacterDashboard) -> void:
	_refresh_stats(character, dashboard)
	_refresh_traits(character, dashboard)

func _refresh_stats(character: CharacterData, dashboard: CharacterDashboard) -> void:
	var grid = %StatsGrid
	for child in grid.get_children():
		child.queue_free()
		
	var can_see_stats = dashboard.is_data_visible("base_stats")
	
	for stat_enum in Definitions.Stat.values():
		var stat_name = Definitions.Stat.keys()[stat_enum].capitalize()
		var stat_val = str(character.get_stat(stat_enum)) if can_see_stats else "???"
		
		var name_lbl = Label.new()
		name_lbl.text = stat_name + ":"
		
		var val_lbl = Label.new()
		val_lbl.text = stat_val
		
		grid.add_child(name_lbl)
		grid.add_child(val_lbl)

func _refresh_traits(character: CharacterData, dashboard: CharacterDashboard) -> void:
	var list = %TraitsList
	for child in list.get_children():
		child.queue_free()
		
	var can_see_traits = dashboard.is_data_visible("traits")
	
	if not can_see_traits:
		var lbl = Label.new()
		lbl.text = "Traits Hidden"
		list.add_child(lbl)
		return
		
	for t_id in character.traits:
		var t_data = DataManager.traits_registry.get(t_id, {})
		var lbl = Label.new()
		# Encapsulate in brackets for a clean look, or use standard tooltips
		lbl.text = "[" + t_data.get("display_name", t_id) + "]" 
		lbl.tooltip_text = t_data.get("description", "")
		lbl.add_theme_color_override("font_color", Color.AQUAMARINE)
		list.add_child(lbl)
