extends Node

## Handles top-level scene transitions and ensures all singleton states are wiped when returning to the Main Menu.

signal scene_changed(new_scene_name: String)

const MAIN_MENU_PATH = "res://Scenes/main_menu.tscn"
const GAME_SCENE_PATH = "res://Scenes/main_game.tscn"

## Performs a hard reset of all simulation data. Crucial before starting a new game or loading.
func reset_game_state() -> void:
	# 1. Halt time
	TimeManager.set_time_speed(TimeManager.Speed.PAUSED)
	TimeManager.year = 740
	TimeManager.month = 1
	TimeManager.day = 1
	TimeManager._epoch_day = 0
	
	# 2. Clear simulation entities
	SimulationManager.clear_simulation()
	
	# 3. Clear transient managers
	GameManager.player_char_id = ""
	GameManager.player_sect_id = ""
	EventManager._delayed_events.clear()
	WorldLogManager.clear_logs()
	UIManager.close_all_panels()
	
	print("SceneManager: Game state fully reset.")

func goto_main_menu() -> void:
	reset_game_state()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
	scene_changed.emit("main_menu")

func goto_game_scene() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
	scene_changed.emit("main_game")
