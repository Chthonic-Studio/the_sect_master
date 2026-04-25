extends Node2D

## The root node for the active gameplay session.
## Manages the map and tells the UIManager to bring up the HUD.

const HUD_SCENE = preload("res://Scenes/UI/hud.tscn")
const WORLD_LOG_PANEL_SCENE = preload("res://Scenes/UI/world_log_panel.tscn")
const SECT_DASHBOARD_SCENE = preload("res://Scenes/UI/sect_dashboard.tscn")
const CHARACTER_DASHBOARD_SCENE = preload("res://Scenes/UI/character_dashboard.tscn")
const DEBUG_SCREEN_SCENE = preload("res://Scenes/UI/debug_screen.tscn")

# Map dimensions — keep in sync with MapCameraController and MapRenderer
const MAP_WIDTH := 1200	
const MAP_HEIGHT := 800

func _ready() -> void:
	# 1. Instance map renderer and camera
	_setup_map()
	
	# 2. Instance all persistent UI panels so they register themselves with the UIManager.
	#    The order matters: HUD first so its buttons work immediately.
	var hud_instance = HUD_SCENE.instantiate()
	add_child(hud_instance)
	
	var world_log_instance = WORLD_LOG_PANEL_SCENE.instantiate()
	add_child(world_log_instance)
	
	var sect_dashboard_instance = SECT_DASHBOARD_SCENE.instantiate()
	add_child(sect_dashboard_instance)
	
	var character_dashboard_instance = CHARACTER_DASHBOARD_SCENE.instantiate()
	add_child(character_dashboard_instance)
	
	var debug_screen_instance = DEBUG_SCREEN_SCENE.instantiate()
	add_child(debug_screen_instance)
	
	# 3. Tell the UIManager to open the HUD
	UIManager.open_panel("hud")
	
	# 4. Ensure the simulation is unpaused
	TimeManager.set_time_speed(TimeManager.Speed.NORMAL)

func _setup_map() -> void:
	# Store map dimensions on the MapManager for other systems to query
	MapManager.map_width = MAP_WIDTH
	MapManager.map_height = MAP_HEIGHT
	
	# Renderer (draws polygons for regions and provinces)
	var renderer := MapRenderer.new()
	renderer.name = "MapRenderer"
	add_child(renderer)
	
	# Camera (WASD / scroll zoom)
	var camera := MapCameraController.new()
	camera.name = "MapCamera"
	camera.map_width = MAP_WIDTH
	camera.map_height = MAP_HEIGHT
	add_child(camera)
