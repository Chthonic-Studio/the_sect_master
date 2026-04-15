extends MarginContainer

## Handles the display of the Player's relationship with the target, 
## and the target's notable relationships with the rest of the world.

var _left_vbox: VBoxContainer
var _right_vbox: VBoxContainer
var _target_opinion_label: Label
var _player_opinion_label: Label

func _ready() -> void:
	# Clear any placeholders from the editor
	for child in get_children():
		child.queue_free()
		
	# --- DYNAMIC UI CONSTRUCTION ---
	var main_hbox = HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_hbox)
	
	# Left Side: Player Relationship
	_left_vbox = VBoxContainer.new()
	_left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_vbox.size_flags_stretch_ratio = 1.0
	main_hbox.add_child(_left_vbox)
	
	main_hbox.add_child(VSeparator.new())
	
	# Right Side: Notable World Relationships
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.5
	main_hbox.add_child(scroll)
	
	_right_vbox = VBoxContainer.new()
	_right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_right_vbox)
	
	# Left Panel Setup
	var title_left = Label.new()
	title_left.text = "Player Relationship"
	title_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_vbox.add_child(title_left)
	_left_vbox.add_child(HSeparator.new())
	
	_target_opinion_label = Label.new()
	_target_opinion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left_vbox.add_child(_target_opinion_label)
	
	_left_vbox.add_child(Control.new()) # Spacer
	
	_player_opinion_label = Label.new()
	_player_opinion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left_vbox.add_child(_player_opinion_label)

func refresh_panel(character: CharacterData, _dashboard: CharacterDashboard) -> void:
	var player_char = SimulationManager.get_character(GameManager.player_char_id)
	
	_refresh_player_side(player_char, character)
	_refresh_notable_side(player_char, character)

func _refresh_player_side(player_char: CharacterData, character: CharacterData) -> void:
	if not player_char:
		_target_opinion_label.text = "No Player Character assigned."
		_player_opinion_label.text = ""
		return
		
	if player_char == character:
		_target_opinion_label.text = "This is you."
		_player_opinion_label.text = ""
		return
		
	var target_op = OpinionManager.get_opinion(character, player_char)
	var player_op = OpinionManager.get_opinion(player_char, character)
	
	_target_opinion_label.text = "Their Opinion of You:\n%d" % target_op
	_player_opinion_label.text = "Your Opinion of Them:\n%d" % player_op
	
	# Apply standard CK3 coloring
	_apply_opinion_color(_target_opinion_label, target_op)
	_apply_opinion_color(_player_opinion_label, player_op)

func _refresh_notable_side(player_char: CharacterData, character: CharacterData) -> void:
	for child in _right_vbox.get_children():
		child.queue_free()
		
	var title_right = Label.new()
	title_right.text = "Notable Relationships"
	title_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_vbox.add_child(title_right)
	_right_vbox.add_child(HSeparator.new())
	
	# We use a Dictionary as a Set to collect unique IDs without duplicates
	var special_ids: Dictionary = {}
	
	# 1. Temporal Modifiers (Grudges, Favors, Insults)
	for target_id in character.directed_opinions.keys():
		special_ids[target_id] = true
		
	# 2. Sect Members
	if character.sect_id != "":
		var sect = SimulationManager.get_sect(character.sect_id)
		if sect:
			for member_id in sect.all_members:
				special_ids[member_id] = true
				
	# 3. Family Members (Hook for future implementation)
	# if character.family_members.size() > 0:
	# 	for relative_id in character.family_members:
	# 		special_ids[relative_id] = true
				
	# Erase self and the player (player is handled on the left side)
	special_ids.erase(character.char_id)
	if player_char:
		special_ids.erase(player_char.char_id)
		
	if special_ids.is_empty():
		var lbl = Label.new()
		lbl.text = "No notable relationships."
		lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		_right_vbox.add_child(lbl)
		return
		
	# Fetch characters and calculate opinions
	var relations_data: Array[Dictionary] = []
	for rel_id in special_ids.keys():
		var rel_char = SimulationManager.get_character(rel_id)
		if rel_char and rel_char.is_alive:
			var op_val = OpinionManager.get_opinion(character, rel_char)
			relations_data.append({"char": rel_char, "opinion": op_val})
			
	# Sort by absolute opinion (strongest feelings first, positive or negative)
	relations_data.sort_custom(func(a, b): return abs(a["opinion"]) > abs(b["opinion"]))
	
	for data in relations_data:
		var rel_char = data["char"]
		var op_val = data["opinion"]
		
		var hbox = HBoxContainer.new()
		
		var name_lbl = Label.new()
		name_lbl.text = rel_char.get_full_name()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var op_lbl = Label.new()
		op_lbl.text = str(op_val)
		op_lbl.custom_minimum_size = Vector2(40, 0)
		op_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_apply_opinion_color(op_lbl, op_val)
		
		hbox.add_child(name_lbl)
		hbox.add_child(op_lbl)
		_right_vbox.add_child(hbox)

func _apply_opinion_color(label: Label, value: int) -> void:
	if value >= 20:
		label.add_theme_color_override("font_color", Color.PALE_GREEN)
	elif value <= -20:
		label.add_theme_color_override("font_color", Color.INDIAN_RED)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
