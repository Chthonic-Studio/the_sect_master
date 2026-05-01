extends Control

## Handles the base entry point of the game.


func _ready() -> void:
	%BtnNewGame.pressed.connect(_on_new_game_pressed)
	%BtnQuickStart.pressed.connect(_on_quick_start_pressed)
	%BtnLoadGame.pressed.connect(_on_load_game_pressed)
	%BtnQuit.pressed.connect(_on_quit_pressed)
	
	# Quick Start is a debug-only feature — hide it in exported/release builds.
	%BtnQuickStart.visible = OS.is_debug_build()
	
	# Make sure the game is fully reset when returning here
	SceneManager.reset_game_state()

func _on_new_game_pressed() -> void:
	# Proceed to the setup screen to create a character/sect
	get_tree().change_scene_to_file("res://Scenes/setup_screen.tscn")

func _on_quick_start_pressed() -> void:
	# Skip setup and dive straight into the game with sensible debug defaults.
	%BtnQuickStart.disabled = true
	
	TimeManager.year = 740
	WorldManager.target_world_population = 3000
	
	# Generate the world
	SectGenerator.generate_world_sects()
	
	# Generate the player's sect
	var player_sect: SectData = SectGenerator.generate_custom_sect(
		SectGenerator.SectTier.AVERAGE,
		{
			"name":          "Iron Hammer Sect",
			"alignment":     Definitions.SectAlignment.NEUTRAL,
			"culture":       Definitions.Culture.CENTRAL_PLAINS,
			"province_id":   "kaifeng",
			"tenets":        [],
			"laws":          {"sect_authority": "council_rule"},
			"members_count": 20
		}
	)
	
	# Set up the player character
	var masters: Array = player_sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
	if not masters.is_empty():
		var master_char: CharacterData = SimulationManager.get_character(masters[0])
		if master_char:
			master_char.first_name = "Wei"
			master_char.last_name = "Chen"
			master_char.add_trait("disciplined")
			master_char.recalculate_all_stats()
			GameManager.set_player_character(master_char.char_id)
	
	SceneManager.goto_game_scene()

func _on_load_game_pressed() -> void:
	# For the MVP, we just load the first available save slot for testing.
	# Later, this will open a Load Game UI panel reading SaveManager.get_all_save_headers()
	var headers = SaveManager.get_all_save_headers()
	if headers.is_empty():
		print("MainMenu: No saves found!")
	else:
		SaveManager.load_game(headers[0].get("filename", "save_1"))
		SceneManager.goto_game_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
