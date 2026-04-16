extends Node2D

## The root node for the active gameplay session.
## Manages the map and tells the UIManager to bring up the HUD.

const HUD_SCENE = preload("res://Scenes/UI/hud.tscn")

func _ready() -> void:
	# 1. Instance the HUD so it registers itself with the UIManager
	var hud_instance = HUD_SCENE.instantiate()
	add_child(hud_instance)
	
	# 2. Tell the UIManager to open the HUD
	UIManager.open_panel("hud")
	
	# 3. Ensure the simulation is unpaused
	TimeManager.set_time_speed(TimeManager.Speed.NORMAL)
