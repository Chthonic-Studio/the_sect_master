# CharacterMenu.gd
# Controls the character menu UI, populating it with character data.
# Attach this script to the root node of character_menu.tscn.

extends Control

# === Node References (Drag-and-drop these in the Inspector) ===
@export_group("Header")
@export var character_name_label: Label
@export var character_position_label: Label
@export var age_label: Label
@export var location_label: Label
@export var spiritual_root_icon: TextureRect
@export var cultivation_realm_icon: TextureRect
@export var traits_container: HBoxContainer

@export_group("Buttons")
@export var talk_button: TextureButton
@export var close_button: Button
@export var back_button: Button

@export_group("Tab Containers")
@export var overview_tab: Container
@export var cultivation_tab: Container
@export var relationships_tab: Container
@export var inventory_tab: Container
@export var logs_tab: Container

@export_group("Tab Buttons")
@export var overview_button: TextureButton
@export var cultivation_button: TextureButton
@export var relationships_button: TextureButton
@export var inventory_button: TextureButton
@export var logs_button: TextureButton

@export_group("Overview Tab")
@export var overview_reputation_label: Label
@export var overview_renown_label: Label
@export var overview_lifespan_label: Label
@export var overview_desires_label: Label
@export var overview_action_label: Label

@export_group("Cultivation Tab")
@export var cultivation_potential_label: Label
@export var cultivation_realm_label: Label
@export var cultivation_progress_label: Label
@export var cultivation_deviation_label: Label
@export var cultivation_breakthrough_label: Label
@export var cultivation_affinities_label: Label

@export_group("Relationships Tab")
@export var relationships_list_container: VBoxContainer # The container for relationship_entry instances

@export_group("Prefabs")
@export var relationship_entry_prefab: PackedScene # The relationship_entry.tscn
# @export var trait_icon_prefab: PackedScene # Future prefab for trait icons

var current_character: CharacterResource
var all_tabs: Array

func _ready() -> void:
	# --- Connect Signals ---
	close_button.pressed.connect(UIManager.hide_character_menu)
	back_button.pressed.connect(UIManager.show_previous_character)
	talk_button.pressed.connect(_on_talk_with_button_pressed)
	
	# --- Tab Setup ---
	all_tabs = [overview_tab, cultivation_tab, relationships_tab, inventory_tab, logs_tab]
	overview_button.pressed.connect(_on_tab_selected.bind(overview_tab))
	cultivation_button.pressed.connect(_on_tab_selected.bind(cultivation_tab))
	relationships_button.pressed.connect(_on_tab_selected.bind(relationships_tab))
	inventory_button.pressed.connect(_on_tab_selected.bind(inventory_tab))
	logs_button.pressed.connect(_on_tab_selected.bind(logs_tab))

# --- Public API (called by UIManager) ---
func populate_data(character_res: CharacterResource) -> void:
	current_character = character_res
	if not is_instance_of(current_character, CharacterResource):
		push_error("CharacterMenu: Invalid resource provided.")
		hide()
		return

	# --- Populate UI ---
	_populate_header()
	_populate_overview_tab()
	_populate_cultivation_tab()
	_populate_relationships_tab()
	# _populate_inventory_tab() # Future
	# _populate_logs_tab() # Future
	
	# Default to the overview tab every time a new character is selected
	_on_tab_selected(overview_tab)

# Hides the menu.
func hide_menu() -> void:
	current_character = null
	hide()

# --- Signal Handlers ---

func _on_talk_with_button_pressed() -> void:
	if not is_instance_valid(current_character):
		return
		
	# Create a temporary dialogue resource for testing.
	var test_dialogue = _create_test_dialogue_for_character(current_character)
	
	# Start the dialogue using the manager.
	DialogueManager.start_dialogue(current_character, test_dialogue)
	
	# Optionally hide the character menu when dialogue starts.
	hide_menu()

func _on_tab_selected(selected_tab: Container) -> void:
	for tab in all_tabs:
		tab.visible = (tab == selected_tab)

# --- UI Population Logic ---
func _populate_header() -> void:
	# REASON FOR CHANGE:
	# This function is now solely responsible for all header elements, including icons.
	# It correctly shows/hides cultivation-related icons based on character type.
	character_name_label.text = current_character.name_display
	
	var sect = SectManager.get_sect_by_character_id(current_character.id)
	var sect_name = "Unaffiliated"
	if sect:
		sect_name = sect.sect_name
	character_position_label.text = "%s - %s" % [current_character.title if current_character.title else "Wanderer", sect_name]
	
	age_label.text = "Age: %d" % current_character.age
	location_label.text = "Location: Unknown" # Placeholder for now

	if current_character is CultivatorResource:
		var realm: CultivationRealmResource = CultivationManager.get_realm(current_character.cultivation_realm)
		if realm:
			cultivation_realm_icon.texture = realm.icon
		else:
			cultivation_realm_icon.texture = null
		
		cultivation_realm_icon.show()
		spiritual_root_icon.show() # TODO: Add logic for spiritual root icon
	else:
		# For mortals, hide cultivation-specific icons in the header.
		cultivation_realm_icon.hide()
		spiritual_root_icon.hide()

func _populate_overview_tab() -> void:
	overview_reputation_label.text = "Reputation: %s" % current_character.reputation
	overview_renown_label.text = "Renown: %s (%d)" % [current_character.renown_title, current_character.renown]
	
	if current_character is CultivatorResource:
		overview_lifespan_label.text = "Lifespan: %d years" % current_character.lifespan
	else:
		overview_lifespan_label.text = "Lifespan: Mortal"
		
	# TODO: Get current desires and action from AI node
	overview_desires_label.text = "Top Desire: (Not Implemented)"
	overview_action_label.text = "Current Action: (Not Implemented)"

func _populate_cultivation_tab() -> void:
	# REASON FOR CHANGE:
	# This function now only manages elements within the Cultivation Tab.
	# It no longer incorrectly tries to update the header icon.
	if current_character is CultivatorResource:
		cultivation_tab.show()
		cultivation_button.show()
		
		cultivation_potential_label.text = "Potential: %d" % current_character.potential
		
		# Get the realm resource to display its name.
		var realm: CultivationRealmResource = CultivationManager.get_realm(current_character.cultivation_realm)
		if realm:
			cultivation_realm_label.text = "Realm: %s" % realm.display_name
		else:
			cultivation_realm_label.text = "Realm: Unknown"
			
		cultivation_progress_label.text = "Progress: %d%%" % current_character.realm_progress
		cultivation_deviation_label.text = "Qi Deviation Risk: %d%%" % current_character.qi_deviation_risk
		cultivation_breakthrough_label.text = "Breakthrough Modifier: %d%%" % current_character.breakthrough_modifier
		
		var affinities_text = "Affinities: "
		for element in current_character.elemental_affinity:
			affinities_text += "%s (%d) " % [element, current_character.elemental_affinity[element]]
		cultivation_affinities_label.text = affinities_text
	else:
		# Hide the cultivation tab and button for non-cultivators
		cultivation_tab.hide()
		cultivation_button.hide()

func _populate_relationships_tab() -> void:
	for child in relationships_list_container.get_children():
		child.queue_free()
	
	if not current_character or not relationship_entry_prefab:
		return
		
	for char_id in current_character.relationships:
		var other_char = CharManager.get_character_by_id(char_id)
		var relationship_value = current_character.relationships[char_id]
		
		if other_char:
			var entry = relationship_entry_prefab.instantiate()
			entry.find_child("CharacterName").text = other_char.name_display
			var value_label = entry.find_child("RelationshipValue")
			value_label.text = "%+d" % relationship_value
			value_label.modulate = Color.GREEN if relationship_value > 0 else (Color.RED if relationship_value < 0 else Color.WHITE)
			relationships_list_container.add_child(entry)

# --- Placeholder for testing ---
func _create_test_dialogue_for_character(character: CharacterResource) -> DialogueResource:
	var dialogue = DialogueResource.new()
	dialogue.dialogue_id = "test_greeting"
	dialogue.start_node_key = "start"

	# --- Create Options ---
	var option1 = DialogueOptionResource.new()
	option1.text = "Tell me about yourself."
	option1.destination_node_key = "about_self"

	var option2 = DialogueOptionResource.new()
	option2.text = "Goodbye."
	option2.closes_dialogue = true

	# --- Create Nodes ---
	var start_node = DialogueNodeResource.new()
	start_node.text = "Hello, Sect Master. You wished to speak with me?"
	start_node.options = [option1, option2] as Array[DialogueOptionResource]

	var about_self_node = DialogueNodeResource.new()
	about_self_node.text = "My name is %s. I am currently trying my best to cultivate and bring honor to the sect." % character.name_display
	about_self_node.options = [option2] as Array[DialogueOptionResource]

	# Add nodes to the dialogue's dictionary.
	dialogue.nodes = {
		"start": start_node,
		"about_self": about_self_node
	}
	
	return dialogue
