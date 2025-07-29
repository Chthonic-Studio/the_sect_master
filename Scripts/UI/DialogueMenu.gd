# DialogueMenu.gd
# Controls the dialogue UI, displaying text and options.
# Attach this script to the root node of dialogue_menu.tscn.

extends Control

# === Node References (Drag-and-drop in Inspector) ===
@export_category("Portraits")
@export var player_name_label: Label
@export var speaker_name_label: Label
@export var speaker_title_label: Label

@export_category("Dialogue Flow")
@export var dialogue_history_container: VBoxContainer # The VBoxContainer inside the ScrollContainer
@export var options_container: VBoxContainer

# === Prefabs ===
@export_category("Prefabs")
@export var dialogue_entry_prefab: PackedScene # The dialogue_entry.tscn
@export var dialogue_option_prefab: PackedScene # The dialogue_option.tscn

var current_speaker: CharacterResource
var current_node: DialogueNodeResource

# --- Public API (called from DialogueManager) ---

# Called when the dialogue is first opened.
func start_dialogue(speaker: CharacterResource, dialogue: DialogueResource) -> void:
	current_speaker = speaker
	
	# Clear any previous conversation history
	for child in dialogue_history_container.get_children():
		child.queue_free()
	
	# Populate the UI with speaker and player info
	_update_portrait_info()

# Called by DialogueManager to display a new line from the NPC.
func update_node_display(speaker: CharacterResource, node: DialogueNodeResource) -> void:
	current_speaker = speaker
	current_node = node
	
	_add_history_entry(current_speaker.name_display, current_node.text)
	_populate_options()

# Called by the DialogueManager after the player selects an option.
func add_player_response_to_history(option: DialogueOptionResource) -> void:
	var player_res = PlayerManager.player_character_resource
	if player_res:
		_add_history_entry(player_res.name_display, option.text)

# --- Internal Logic ---

func _update_portrait_info() -> void:
	# Set speaker (NPC) info
	speaker_name_label.text = current_speaker.name_display
	
	var sect = SectManager.get_sect_by_character_id(current_speaker.id)
	var sect_name = "Unaffiliated"
	if sect:
		sect_name = sect.sect_name
	# You can expand this to get a more specific title/position later
	speaker_title_label.text = "%s - %s" % [current_speaker.title if current_speaker.title else "Wanderer", sect_name]

	# Set player info
	var player_res = PlayerManager.player_character_resource
	if player_res:
		player_name_label.text = player_res.name_display

func _populate_options() -> void:
	# Clear previous options
	for child in options_container.get_children():
		child.queue_free()
		
	if not current_node or not dialogue_option_prefab:
		return
		
	for i in range(current_node.options.size()):
		var option_res = current_node.options[i]
		var option_instance = dialogue_option_prefab.instantiate()
		
		# The root of dialogue_option.tscn is a Label, so we make it interactive here.
		# A better long-term solution is to change the root to a Button.
		# For now, we wrap it in a button.
		var button = Button.new()
		button.text = "%d. %s" % [i + 1, option_res.text]
		button.flat = true
		button.pressed.connect(DialogueManager.select_option.bind(option_res))
		
		options_container.add_child(button)

func _add_history_entry(speaker_name: String, text: String) -> void:
	if not dialogue_entry_prefab: return
	
	var entry = dialogue_entry_prefab.instantiate()
	entry.text = "[b]%s[/b]: %s" % [speaker_name, text] # Use BBCode for bolding the name
	dialogue_history_container.add_child(entry)
