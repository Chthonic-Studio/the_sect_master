extends Control

## Handles the base entry point of the game.

func _ready() -> void:
	%BtnNewGame.pressed.connect(_on_new_game_pressed)
	%BtnLoadGame.pressed.connect(_on_load_game_pressed)
	%BtnQuit.pressed.connect(_on_quit_pressed)
	
	# Make sure the game is fully reset when returning here
	SceneManager.reset_game_state()

func _on_new_game_pressed() -> void:
	# Proceed to the setup screen to create a character/sect
	get_tree().change_scene_to_file("res://Scenes/setup_screen.tscn")

func _on_load_game_pressed() -> void:
	# For the MVP, we just load the first available save slot for testing.
	# Later, this will open a Load Game UI panel reading SaveManager.get_all_save_headers()
	var headers = SaveManager.get_all_save_headers()
	if headers.is_empty():
		print("MainMenu: No saves found!")
	else:
		SaveManager.load_game(headers[0].get("filename", "save_1"))

func _on_quit_pressed() -> void:
	get_tree().quit()
