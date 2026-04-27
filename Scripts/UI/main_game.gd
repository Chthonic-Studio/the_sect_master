extends Node2D

## The root node for the active gameplay session.
## Manages the map and tells the UIManager to bring up the HUD.

const HUD_SCENE = preload("res://Scenes/UI/hud.tscn")
const WORLD_LOG_PANEL_SCENE = preload("res://Scenes/UI/world_log_panel.tscn")
const SECT_DASHBOARD_SCENE = preload("res://Scenes/UI/sect_dashboard.tscn")
const CHARACTER_DASHBOARD_SCENE = preload("res://Scenes/UI/character_dashboard.tscn")
const DEBUG_SCREEN_SCENE = preload("res://Scenes/UI/debug_screen.tscn")
const PROVINCE_VIEW_SCENE = preload("res://Scenes/UI/province_view.tscn")
const REGION_VIEW_SCENE = preload("res://Scenes/UI/region_view.tscn")

## Map dimensions — keep in sync with actual map image size (Assets/Map/*.png).
## Exposed as export vars so they can be tweaked from the editor without touching code.
@export var map_width: int = 3840
@export var map_height: int = 2160

## Viewport (game resolution) — must match Project Settings → Display → Window.
## The camera uses these to compute the fit-to-screen zoom and to clamp the pan position.
@export var viewport_width: int = 1200
@export var viewport_height: int = 800

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
	
	var province_view_instance = PROVINCE_VIEW_SCENE.instantiate()
	add_child(province_view_instance)
	
	var region_view_instance = REGION_VIEW_SCENE.instantiate()
	add_child(region_view_instance)
	
	# 3. Connect map click signals to open the appropriate view panels
	MapManager.province_clicked.connect(_on_province_clicked)
	MapManager.region_clicked.connect(_on_region_clicked)
	
	# 4. Tell the UIManager to open the HUD
	UIManager.open_panel("hud")
	
	# 5. Ensure the simulation is unpaused
	TimeManager.set_time_speed(TimeManager.Speed.NORMAL)

func _setup_map() -> void:
	# Store map dimensions on the MapManager for other systems to query
	MapManager.map_width = map_width
	MapManager.map_height = map_height
	
	# Renderer (draws polygons for regions and provinces)
	var renderer := MapRenderer.new()
	renderer.name = "MapRenderer"
	add_child(renderer)
	
	# Camera (WASD / scroll zoom)
	var camera := MapCameraController.new()
	camera.name = "MapCamera"
	camera.map_width = map_width
	camera.map_height = map_height
	camera.viewport_width = viewport_width
	camera.viewport_height = viewport_height
	add_child(camera)

func _on_province_clicked(province_id: String) -> void:
	UIManager.open_panel("province_view", province_id)

func _on_region_clicked(region_id: String) -> void:
	UIManager.open_panel("region_view", region_id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("province_mode"):
		MapManager.set_map_layer(MapManager.MapLayer.PROVINCES)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("region_mode"):
		MapManager.set_map_layer(MapManager.MapLayer.REGIONS)
		get_viewport().set_input_as_handled()
