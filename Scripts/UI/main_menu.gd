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
	# Disable immediately to prevent multiple rapid presses triggering repeated resets.
	%BtnQuickStart.disabled = true
	# Skip setup and dive straight into the game with sensible debug defaults.
	SceneManager.goto_loading_screen({
		"start_year":    740,
		"pop_scale":     3000,
		"first_name":    "Wei",
		"last_name":     "Chen",
		"gender":        -1,
		"char_culture":  -1,
		"aptitude":      -1,
		"avatar_idx":    0,
		"starting_trait": "disciplined",
		"sect_name":     "Iron Hammer Sect",
		"alignment":     Definitions.SectAlignment.NEUTRAL,
		"org_type":      Definitions.OrgType.SECT,
		"sect_culture":  Definitions.Culture.CENTRAL_PLAINS,
		"province_id":   "kaifeng",
		"tenet_id":      "",
		"law_preset":    "council_rule",
		"sect_tier":     SectGenerator.SectTier.AVERAGE,
		"members_count": 20,
	})

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
