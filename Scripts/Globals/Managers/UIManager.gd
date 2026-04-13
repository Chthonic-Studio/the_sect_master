extends Node

## Centralized UI Router. Manages z-layers, panel registration, and modal stacks.
## Avoids hardcoded references; relies on panels registering themselves.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

enum Layer {
	HUD = 0,      # Constantly visible elements (Time controls, mini-map)
	PANELS = 1,   # Heavy management screens (Sect Dashboard, Character Sheet)
	POPUPS = 2,   # Events, Confirmations, Dialogs
	SYSTEM = 3,   # Pause Menu, Settings
	TOOLTIPS = 4  # Hover information
}

# Maps String IDs to their instanced Node references
var _registered_panels: Dictionary = {}
# Maps Layer enums to their CanvasLayer nodes
var _layers: Dictionary = {}

# Stack to track which popups/panels are open so the 'Escape' key closes the topmost one
var _ui_stack: Array[Node] = []

func _ready() -> void:
	_setup_canvas_layers()
	
	# Listen for Global Events that require player input
	if EventManager.has_signal("player_event_triggered"):
		EventManager.player_event_triggered.connect(_on_player_event_triggered)
	
	# Catch the succession requirement!
	GameManager.player_succession_required.connect(_on_player_succession_required)

func _setup_canvas_layers() -> void:
	# Dynamically create strict Z-indexed layers so UI always sorts correctly
	# regardless of the underlying 2D/3D SceneTree structure.
	for layer_enum in Layer.values():
		var canvas = CanvasLayer.new()
		canvas.name = "Layer_" + Layer.keys()[layer_enum].capitalize()
		canvas.layer = layer_enum * 10 # Spread out the Z-index (0, 10, 20, 30...)
		add_child(canvas)
		_layers[layer_enum] = canvas

# --- PANEL ROUTING (Heavy, persistent screens) ---

## Called by individual UI scenes in their _ready() function to register themselves.
func register_panel(panel_id: String, panel_node: Control, default_layer: int = Layer.PANELS) -> void:
	if _registered_panels.has(panel_id):
		printerr("UIManager: Panel ID '%s' is already registered!" % panel_id)
		return
		
	_registered_panels[panel_id] = panel_node
	
	var target_layer = _layers[default_layer]
	panel_node.reparent.call_deferred(target_layer, false)
	
	panel_node.hide()

## Opens a registered panel and passes it an optional data payload.
func open_panel(panel_id: String, payload: Variant = null) -> void:
	if not _registered_panels.has(panel_id):
		printerr("UIManager: Attempted to open unregistered panel: ", panel_id)
		return
		
	var panel = _registered_panels[panel_id]
	
	# If it has a setup/init function, pass the data
	if payload != null and panel.has_method("setup_dashboard"):
		panel.setup_dashboard(payload)
		
	panel.show()
	
	# Manage the stack (bring to front)
	if _ui_stack.has(panel):
		_ui_stack.erase(panel)
	_ui_stack.append(panel)
	
	panel_opened.emit(panel_id)

func close_panel(panel_id: String) -> void:
	if _registered_panels.has(panel_id):
		var panel = _registered_panels[panel_id]
		panel.hide()
		_ui_stack.erase(panel)
		panel_closed.emit(panel_id)

func close_all_panels() -> void:
	for id in _registered_panels:
		close_panel(id)

# --- POPUPS (Transient, instantiated on demand) ---

## Spawns a transient popup, adds it to the POPUPS layer, and tracks it.
func spawn_popup(packed_scene: PackedScene, payload: Variant = null) -> Node:
	if not packed_scene: return null
	
	var popup = packed_scene.instantiate()
	_layers[Layer.POPUPS].add_child(popup)
	
	if payload != null and popup.has_method("setup_popup"):
		popup.setup_popup(payload)
		
	_ui_stack.append(popup)
	
	# Clean up the stack when the popup frees itself
	popup.tree_exited.connect(func(): _ui_stack.erase(popup))
	
	return popup

# --- EVENT INTEGRATION ---

func _on_player_event_triggered(event_id: String, context: Dictionary) -> void:
	# You will need to create this generic event_popup.tscn later
	var event_scene = load("res://Scenes/UI/event_popup.tscn")
	var _popup = spawn_popup(event_scene, {"event_id": event_id, "context": context})
	
	# Auto-pause the game when an event fires
	TimeManager.set_time_speed(TimeManager.Speed.PAUSED)

func _on_player_succession_required(heir_char_id: String) -> void:
	var succ_scene = load("res://Scenes/UI/sucession_popup.tscn")
	# Spawn on the highest system layer so it eclipses everything
	var _popup = spawn_popup(succ_scene, {"heir_id": heir_char_id})

# --- INPUT HANDLING ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # Usually the 'Escape' key
		if not _ui_stack.is_empty():
			var top_node = _ui_stack.pop_back()
			if top_node.has_method("close"):
				top_node.close()
			else:
				top_node.hide()
			# Consume the input so it doesn't open the pause menu simultaneously
			get_viewport().set_input_as_handled() 
		else:
			# If the stack is empty, open the System Pause Menu
			open_panel("system_menu")
