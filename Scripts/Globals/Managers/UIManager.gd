extends Node

## Centralized UI Router. Manages z-layers, panel registration, and modal stacks.
## Avoids hardcoded references; relies on panels registering themselves.

signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)
## Emitted when the player requests the map camera to fit to screen (world_screen while map is clean).
signal map_fit_requested()

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

# Track last character and sect that were opened so keyboard shortcuts can reopen them
var _last_character_id: String = ""
var _last_sect_id: String = ""

# Pause-token counter: the speed is only restored when the last event popup closes.
# Incremented each time an event popup opens; decremented on each tree_exited.
var _event_popup_count: int = 0
# The speed to restore once _event_popup_count drops back to 0.
var _speed_before_events: TimeManager.Speed = TimeManager.Speed.NORMAL

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
		
	if not _layers.has(default_layer):
		printerr("UIManager: Invalid layer for panel registration: ", default_layer)
		return
	
	_registered_panels[panel_id] = panel_node
	
	var target_layer: CanvasLayer = _layers[default_layer]
	
	# Immediate deterministic reparent to avoid frame-order races during setup/open.
	if panel_node.get_parent() != target_layer:
		panel_node.reparent(target_layer, false)
	
	panel_node.hide()

func open_panel(panel_id: String, payload: Variant = null) -> void:
	if not _registered_panels.has(panel_id):
		printerr("UIManager: Attempted to open unregistered panel: ", panel_id)
		return
		
	var panel: Control = _registered_panels[panel_id]
	
	# Guard against calls made before the panel is fully in-tree.
	if not panel.is_inside_tree():
		await panel.ready
	
	# Route payload to dashboard-style setup (requires a non-null entity to display).
	if payload != null and panel.has_method("setup_dashboard"):
		panel.setup_dashboard(payload)
	# Route payload to generic panel-style setup (always called so panels can refresh on open).
	elif panel.has_method("setup_panel"):
		panel.setup_panel(payload)
		
	panel.show()
	panel.move_to_front()
	
	if _ui_stack.has(panel):
		_ui_stack.erase(panel)
	_ui_stack.append(panel)
	
	# Track last-opened character and sect for keyboard shortcut recall
	if panel_id == "character_dashboard" and payload != null:
		_last_character_id = (payload as CharacterData).char_id if payload is CharacterData else _last_character_id
	elif panel_id == "sect_dashboard" and payload != null:
		_last_sect_id = (payload as SectData).sect_id if payload is SectData else _last_sect_id
	
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

## Frees all registered panel nodes and clears the registry.
## Call this before reloading the game scene so that new panel instances can register fresh.
func free_registered_panels() -> void:
	for panel_id in _registered_panels:
		var panel = _registered_panels[panel_id]
		if is_instance_valid(panel):
			panel.queue_free()
	_registered_panels.clear()
	_ui_stack.clear()
	_last_character_id = ""
	_last_sect_id = ""

func is_panel_open(panel_id: String) -> bool:
	if not _registered_panels.has(panel_id):
		return false
	return _registered_panels[panel_id].visible

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
	var event_scene = load("res://Scenes/UI/event_popup.tscn")
	var popup = spawn_popup(event_scene, {"event_id": event_id, "context": context})
	
	# Only snapshot the speed for the *first* event popup that opens.
	# If another popup was already open (and time already paused), we just
	# increment the counter and don't overwrite the original speed.
	if _event_popup_count == 0:
		_speed_before_events = TimeManager.current_speed
		TimeManager.set_time_speed(TimeManager.Speed.PAUSED)
	
	_event_popup_count += 1
	
	# Restore the pre-event speed only once the last event popup has closed.
	popup.tree_exited.connect(func():
		_event_popup_count = max(0, _event_popup_count - 1)
		if _event_popup_count == 0 and TimeManager.current_speed == TimeManager.Speed.PAUSED:
			TimeManager.set_time_speed(_speed_before_events)
	, CONNECT_ONE_SHOT)

func _on_player_succession_required(heir_char_id: String) -> void:
	var succ_scene = load("res://Scenes/UI/succession_popup.tscn")
	# Spawn on the highest system layer so it eclipses everything
	var _popup = spawn_popup(succ_scene, {"heir_id": heir_char_id})

# --- INPUT HANDLING ---

func _unhandled_input(event: InputEvent) -> void:
	# Keyboard shortcut: open character screen
	if event.is_action_pressed("char_screen"):
		_handle_char_screen()
		get_viewport().set_input_as_handled()
		return
	
	# Keyboard shortcut: open sect screen
	if event.is_action_pressed("sect_screen"):
		_handle_sect_screen()
		get_viewport().set_input_as_handled()
		return
	
	# Keyboard shortcut: open debug screen (debug builds only)
	if OS.is_debug_build() and event.is_action_pressed("debug_screen"):
		_handle_debug_screen()
		get_viewport().set_input_as_handled()
		return
	
	# Keyboard shortcut: return to map / reset zoom
	if event.is_action_pressed("world_screen"):
		_handle_world_screen()
		get_viewport().set_input_as_handled()
		return
	
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

# --- KEYBOARD SHORTCUT HANDLERS ---

func _handle_char_screen() -> void:
	if is_panel_open("character_dashboard"):
		close_panel("character_dashboard")
		return
	
	var char_id = _last_character_id if _last_character_id != "" else GameManager.player_char_id
	var character = SimulationManager.get_character(char_id)
	if character:
		_last_character_id = char_id
		open_panel("character_dashboard", character)
	else:
		printerr("UIManager: char_screen shortcut — no valid character to display.")

func _handle_sect_screen() -> void:
	if is_panel_open("sect_dashboard"):
		close_panel("sect_dashboard")
		return
	
	var sect_id = _last_sect_id if _last_sect_id != "" else GameManager.player_sect_id
	var sect = SimulationManager.get_sect(sect_id)
	if sect:
		_last_sect_id = sect_id
		open_panel("sect_dashboard", sect)
	else:
		printerr("UIManager: sect_screen shortcut — no valid sect to display.")

func _handle_debug_screen() -> void:
	if not OS.is_debug_build():
		return
	if is_panel_open("debug_screen"):
		close_panel("debug_screen")
	else:
		open_panel("debug_screen")

func _handle_world_screen() -> void:
	var any_panel_open := false
	for id in _registered_panels:
		if id != "hud" and _registered_panels[id].visible:
			any_panel_open = true
			break
	
	if any_panel_open:
		for id in _registered_panels:
			if id != "hud":
				close_panel(id)
	else:
		# Already on the map — request camera to fit the map to screen
		map_fit_requested.emit()
