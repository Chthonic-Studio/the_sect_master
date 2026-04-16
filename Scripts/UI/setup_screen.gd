extends Control

func _ready() -> void:
	# Populate Alignments
	for align_key in Definitions.SectAlignment.keys():
		%AlignmentDropdown.add_item(align_key.capitalize())
		
	%BtnStart.pressed.connect(_on_start_pressed)
	%BtnBack.pressed.connect(_on_back_pressed)

func _on_start_pressed() -> void:
	var char_name = %CharNameInput.text.strip_edges()
	var sect_name = %SectNameInput.text.strip_edges()
	var alignment_enum = %AlignmentDropdown.selected
	
	if char_name == "" or sect_name == "":
		print("SetupScreen: Please fill out all fields.")
		return
		
	_generate_game(char_name, sect_name, alignment_enum)

func _generate_game(player_last_name: String, player_sect_name: String, align_val: int) -> void:
	# 1. Generate the world (NPCs and rival sects)
	SectGenerator.generate_world_sects(3, 2, 1)
	
	# 2. Generate the Player's Sect
	var player_sect = SectGenerator.generate_custom_sect(SectGenerator.SectTier.MINOR, {
		"name": player_sect_name,
		"alignment": align_val,
		"members_count": 5 # Start small
	})
	
	# 3. Locate the generated Sect Master of this new sect and claim them
	var masters = player_sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
	if not masters.is_empty():
		var master_char = SimulationManager.get_character(masters[0])
		master_char.last_name = player_last_name
		master_char.first_name = "Master"
		
		# Give the player high aptitude and traits to survive
		master_char.aptitude = Definitions.Aptitude.GENIUS
		master_char.add_trait("martial_prodigy")
		master_char.recalculate_all_stats()
		
		GameManager.set_player_character(master_char.char_id)
		
	# 4. Transition to Game
	SceneManager.goto_game_scene()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
