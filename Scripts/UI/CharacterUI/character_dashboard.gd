extends Control
class_name CharacterDashboard

var active_character: CharacterData

@export_group("UI Panel Connections")
@export var tab_container: TabContainer
@export var close_btn: Button

@export_group("Identity Header")
@export var name_label: Label
@export var sect_label: Label
@export var realm_label: Label

func _ready() -> void:
	# Register with UIManager on the PANELS layer
	UIManager.register_panel("character_dashboard", self, UIManager.Layer.PANELS)
	close_btn.pressed.connect(func(): UIManager.close_panel("character_dashboard"))
	tab_container.tab_changed.connect(_on_tab_changed)

	# Hide the debug tab if this is a released/production build
	if not OS.is_debug_build():
		var debug_tab_idx = tab_container.get_tab_count() - 1
		tab_container.set_tab_hidden(debug_tab_idx, true)
	
	TimeManager.day_passed.connect(_on_day_passed)

## Called by the UIManager when opening the panel
func setup_dashboard(character: CharacterData) -> void:
	if active_character and active_character.stats_recalculated.is_connected(_refresh_ui):
		active_character.stats_recalculated.disconnect(_refresh_ui)
		
	active_character = character
	
	if active_character and not active_character.stats_recalculated.is_connected(_refresh_ui):
		active_character.stats_recalculated.connect(_refresh_ui)
	
	_refresh_identity_header()
	_refresh_active_tab()

## Updates the left-side panel that is always visible
func _refresh_identity_header() -> void:
	if not is_instance_valid(active_character): return
	
	%NameLabel.text = active_character.get_full_name()
	
	if active_character.sect_id != "":
		var sect = SimulationManager.get_sect(active_character.sect_id)
		%SectLabel.text = sect.sect_name if sect else "Rogue Cultivator"
	else:
		%SectLabel.text = "Unaffiliated"
		
	# Granular Fog of War Check: Do we know their realm?
	if is_data_visible("realm"):
		%RealmLabel.text = Definitions.MartialRealm.keys()[active_character.current_realm].capitalize()
	else:
		%RealmLabel.text = "Realm: ???"

## Master hook for signal updates to save CPU.
func _refresh_ui(_char_ref: CharacterData = null) -> void:
	if not is_visible_in_tree():
		return
	_refresh_identity_header()
	_refresh_active_tab()

## Only updates the tab the player is actively looking at.
func _refresh_active_tab() -> void:
	if not is_instance_valid(active_character): return
	
	var active_tab_node = tab_container.get_current_tab_control()
	if active_tab_node.has_method("refresh_panel"):
		# We pass 'self' so the child tabs can query our is_data_visible() function
		active_tab_node.refresh_panel(active_character, self)

func _on_tab_changed(_tab_index: int) -> void:
	_refresh_active_tab()

# --- FOG OF WAR LOGIC ---

func is_data_visible(category: String) -> bool:
	if active_character.sect_id == GameManager.player_sect_id and GameManager.player_sect_id != "": 
		return true
		
	match category:
		"base_stats": return true
		"martial_stats": return true
		"needs": return true
		"traits": return true
		"realm": return true
		"log": return true # DEBUG: Set to true for prototype testing so we can see other people's logs!
		_: return true

func _on_day_passed(_day: int) -> void:
	# Only spend CPU cycles updating the text if the panel is actually open
	if is_visible_in_tree() and active_character != null:
		_refresh_active_tab()
