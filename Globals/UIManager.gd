# UIManager.gd
# Autoload Singleton (name: UIManager)
# Central hub for managing and interacting with UI panels like the Character Menu and Dialogue Menu.

extends Node

# --- Node References ---
var character_menu: Control
var dialogue_menu: Control

# --- State ---
var _character_view_history: Array[CharacterResource] = []
const MAX_HISTORY_SIZE = 10
var _current_character_view: CharacterResource

# --- Initialization ---
func initialize_ui_references(main_ui_node: Control) -> void:
	character_menu = main_ui_node.find_child("CharacterMenu", true, false)
	dialogue_menu = main_ui_node.find_child("DialogueMenu", true, false)
	
	if not character_menu: push_error("UIManager: CharacterMenu not found.")
	if not dialogue_menu: push_error("UIManager: DialogueMenu not found.")
	
	character_menu.hide()
	dialogue_menu.hide()

# --- Public API ---

# Shows the character menu and populates it with data. Manages view history.
func show_character_menu(character_res: CharacterResource, is_navigating_back: bool = false) -> void:
	if not character_menu or not character_menu.has_method("populate_data"):
		push_warning("UIManager: CharacterMenu is not valid or lacks populate_data method.")
		return
	
	# --- History Management ---
	if not is_navigating_back and _current_character_view != null:
		# Add the character we were just viewing to the history stack
		_character_view_history.push_front(_current_character_view)
		# Prune history if it's too long
		if _character_view_history.size() > MAX_HISTORY_SIZE:
			_character_view_history.pop_back()
			
	_current_character_view = character_res
	
	character_menu.populate_data(character_res)
	character_menu.show()
	
	# Disable back button if history is empty
	var back_button = character_menu.find_child("MenuBackButton", true, false)
	if back_button:
		back_button.disabled = _character_view_history.is_empty()

# Shows the previously viewed character from the history.
func show_previous_character() -> void:
	if not _character_view_history.is_empty():
		var previous_char = _character_view_history.pop_front()
		show_character_menu(previous_char, true)

func hide_character_menu() -> void:
	if character_menu:
		character_menu.hide()
		# Clear history when menu is closed manually
		_character_view_history.clear()
		_current_character_view = null

func show_dialogue_menu(speaker_res: CharacterResource, dialogue_res: DialogueResource) -> void:
	if dialogue_menu and dialogue_menu.has_method("start_dialogue"):
		dialogue_menu.start_dialogue(speaker_res, dialogue_res)
		dialogue_menu.show()

func hide_dialogue_menu() -> void:
	if dialogue_menu:
		dialogue_menu.hide()
