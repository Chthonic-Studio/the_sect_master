# DialogueManager.gd
# Autoload Singleton (name: DialogueManager)
# Manages the state and flow of conversations.

extends Node

var active_dialogue: DialogueResource
var active_speaker: CharacterResource
var current_node_key: String

# This signal is emitted when a dialogue is started.
signal dialogue_started(speaker, dialogue)
# This signal is emitted when the player chooses an option.
signal option_selected(option)
# This signal is emitted when the dialogue ends.
signal dialogue_ended

# --- Public API ---

func start_dialogue(speaker: CharacterResource, dialogue: DialogueResource) -> void:
	active_speaker = speaker
	active_dialogue = dialogue
	current_node_key = dialogue.start_node_key
	
	UIManager.show_dialogue_menu(active_speaker, active_dialogue)
	emit_signal("dialogue_started", active_speaker, active_dialogue)
	
	_update_dialogue_node()

func select_option(option: DialogueOptionResource) -> void:
	emit_signal("option_selected", option)
	
	# Add the player's choice to the history FIRST.
	if UIManager.dialogue_menu and UIManager.dialogue_menu.has_method("add_player_response_to_history"):
		UIManager.dialogue_menu.add_player_response_to_history(option)

	if option.closes_dialogue:
		end_dialogue()
		return
	
	if active_dialogue.nodes.has(option.destination_node_key):
		current_node_key = option.destination_node_key
		_update_dialogue_node()
	else:
		push_error("DialogueManager: Destination node key '%s' not found." % option.destination_node_key)
		end_dialogue()

func end_dialogue() -> void:
	UIManager.hide_dialogue_menu()
	emit_signal("dialogue_ended")
	
	active_dialogue = null
	active_speaker = null
	current_node_key = ""

# --- Internal Logic ---

func _update_dialogue_node() -> void:
	var node_resource = active_dialogue.nodes[current_node_key]
	# The UIManager will pass this to the actual UI node to display.
	# This keeps the logic separate from the visual presentation.
	if UIManager.dialogue_menu and UIManager.dialogue_menu.has_method("update_node_display"):
		UIManager.dialogue_menu.update_node_display(active_speaker, node_resource)
