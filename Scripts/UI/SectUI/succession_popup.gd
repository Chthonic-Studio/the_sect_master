extends Control

## Spawns when GameManager.player_succession_required is emitted.

var heir_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup_popup(payload: Dictionary) -> void:
	heir_id = payload.get("heir_id", "")
	var heir = SimulationManager.get_character(heir_id)
	
	if not heir:
		%DescLabel.text = "Your Sect Master has fallen... and there is no one left to take the mantle. The Sect has collapsed."
		%ConfirmButton.text = "Game Over"
		%ConfirmButton.pressed.connect(_on_game_over)
		return
		
	%DescLabel.text = "The Sect Master has fallen.\n\nAccording to the Sect's Succession Laws, %s is the rightful heir and will now ascend to the position of Sect Master." % heir.get_full_name()
	%ConfirmButton.text = "Play as Heir"
	%ConfirmButton.pressed.connect(_on_accept_succession)

func _on_accept_succession() -> void:
	# 1. Bind the player to the new character
	GameManager.set_player_character(heir_id)
	
	# 2. Command the Sect to execute the crowning
	var sect = SimulationManager.get_sect(GameManager.player_sect_id)
	if sect:
		sect.execute_succession(heir_id)
		
	# 3. Resume the game
	TimeManager.set_time_speed(TimeManager.Speed.NORMAL)
	queue_free()

func _on_game_over() -> void:
	print("Game Over triggered. (Return to Main Menu logic goes here)")
	# get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
