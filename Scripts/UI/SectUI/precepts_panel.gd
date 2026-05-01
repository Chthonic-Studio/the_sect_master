extends HBoxContainer
class_name PreceptsPanel

@export var law_item_scene: PackedScene = preload("res://Scenes/UI/law_list_item.tscn")
var active_sect: SectData

func setup_panel(sect: SectData) -> void:
	active_sect = sect
	_refresh_panel()

func _refresh_panel() -> void:
	if not active_sect: return
	
	var is_player_sect: bool = (active_sect.sect_id == GameManager.player_sect_id)
	
	# --- 1. TENETS ---
	var tenets_list: ItemList = $ActiveTenets/TenetsList
	tenets_list.clear()
	
	for t_id in active_sect.active_tenets:
		var t_data = DataManager.tenets_registry.get(t_id, {})
		tenets_list.add_item(t_data.get("name", t_id))
		
	# --- 2. LAWS ---
	var laws_list = $SectLaws/ScrollContainer/LawsList
	for child in laws_list.get_children():
		child.queue_free()
		
	for law_id in active_sect.active_laws:
		var current_option = active_sect.active_laws[law_id]
		var law_data = DataManager.sect_laws_registry.get(law_id, {})
		var options_dict = law_data.get("options", {})
		var option_keys = options_dict.keys()
		
		if is_player_sect:
			# Player's sect: show interactive dropdown for proposing law changes
			var item = law_item_scene.instantiate()
			laws_list.add_child(item)
			
			var label: Label = item.get_node("Label")
			var dropdown: OptionButton = item.get_node("OptionButton")
			
			label.text = law_data.get("name", law_id) + ":"
			
			# Populate the Dropdown options
			for i in range(option_keys.size()):
				var opt_key = option_keys[i]
				dropdown.add_item(options_dict[opt_key].get("name", opt_key))
				
				if opt_key == current_option:
					dropdown.selected = i
					
			# Listen for Player changes
			dropdown.item_selected.connect(func(index: int):
				var new_opt_key = option_keys[index]
				
				# Route through the political proposal system instead of changing it instantly
				active_sect.propose_action("change_law", {"law_id": law_id, "new_option_id": new_opt_key})
				
				# Tell the player what happened
				WorldLogManager.add_log("System", "A proposal to change " + law_data.get("name", law_id) + " has been submitted to the Elders.")
				
				# Re-select the old visual option for now, because the law hasn't ACTUALLY changed yet!
				# It will only change when the proposal_resolved signal fires.
				for j in range(option_keys.size()):
					if option_keys[j] == active_sect.active_laws[law_id]:
						dropdown.selected = j
						break
			)
		else:
			# Non-player sect: show read-only row (Label + Label)
			var row := HBoxContainer.new()
			laws_list.add_child(row)
			
			var name_label := Label.new()
			name_label.text = law_data.get("name", law_id) + ":"
			name_label.custom_minimum_size = Vector2(200, 0)
			row.add_child(name_label)
			
			var value_label := Label.new()
			var current_option_name: String = options_dict.get(current_option, {}).get("name", current_option)
			value_label.text = current_option_name
			value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value_label)

