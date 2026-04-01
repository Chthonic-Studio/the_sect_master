extends MarginContainer

func refresh_panel(character: CharacterData, dashboard: CharacterDashboard) -> void:
	var can_see_combat = dashboard.is_data_visible("martial_stats")
	
	# Weapon
	if character.equipped_weapon_id != "":
		var w_data = DataManager.weapons_registry.get(character.equipped_weapon_id, {})
		%WeaponLabel.text = "Weapon: " + w_data.get("name", "Unknown")
	else:
		%WeaponLabel.text = "Weapon: Unarmed"
	
	# Martial Stats Grid
	var grid = %MartialGrid
	for child in grid.get_children():
		child.queue_free()
		
	for stat_enum in Definitions.MartialStat.values():
		var stat_name = Definitions.MartialStat.keys()[stat_enum].capitalize()
		var stat_val = str(character.get_martial_stat(stat_enum)) if can_see_combat else "???"
		
		var name_lbl = Label.new()
		name_lbl.text = stat_name + ":"
		var val_lbl = Label.new()
		val_lbl.text = stat_val
		
		grid.add_child(name_lbl)
		grid.add_child(val_lbl)
