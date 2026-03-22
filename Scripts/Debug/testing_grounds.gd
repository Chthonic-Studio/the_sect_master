extends Control

## How-to-use:
## Attach this to the TestingGrounds root node. 
## Ensure CharacterGenerator and DataManager are set as Autoloads in Project Settings.

const STARTING_SPAWN_COUNT = 5

@onready var spawn_button: Button = $DEBUG_SpawnRandomChar
@onready var character_list: GridContainer = $DEBUG_CharacterList

func _ready() -> void:
	# 1. Connect signals decoupled from the editor UI
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	
	# 2. Spawn the initial batch to populate the grid
	for i in range(STARTING_SPAWN_COUNT):
		_generate_and_display_character()

func _on_spawn_button_pressed() -> void:
	_generate_and_display_character()

func _generate_and_display_character() -> void:
	# Trigger world gen context for maximum variety
	var new_character = CharacterGenerator.create_character(CharacterGenerator.GenerationContext.WORLD_GEN)
	
	_print_deep_debug_info(new_character)
	_create_ui_card(new_character)

## UI logic is strictly separated from simulation data
func _create_ui_card(character: CharacterData) -> void:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 80)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = character.get_full_name()
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	var info_label = Label.new()
	var realm_str = Definitions.MartialRealm.keys()[character.current_realm].capitalize()
	info_label.text = "Age: %d | %s\nTraits: %d" % [character.age, realm_str, character.traits.size()]
	info_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info_label)
	
	character_list.add_child(card)

## Heavy data logging kept in the console to avoid UI clutter.
## Dynamically iterates through Definitions so future stats are automatically included.
func _print_deep_debug_info(character: CharacterData) -> void:
	print("\n================ NEW CHARACTER SPAWNED: %s ================" % character.char_id)
	var realm_str = Definitions.MartialRealm.keys()[character.current_realm].capitalize()
	print("Name: %s | Age: %d | Realm: %s" % [character.get_full_name(), character.age, realm_str])
	print("Traits: ", character.traits)
	
	print("\n--- BASE STATS ---")
	for stat_key in Definitions.Stat.keys():
		var enum_val = Definitions.Stat[stat_key]
		# get_stat() correctly factors in trait modifiers
		print("- %s: %d" % [stat_key.capitalize(), character.get_stat(enum_val)])
		
	print("\n--- CULTIVATION STATS ---")
	for stat_key in Definitions.CultivationStat.keys():
		var enum_val = Definitions.CultivationStat[stat_key]
		print("- %s: %d" % [stat_key.capitalize(), character.get_cultivation_stat(enum_val)])
		
	print("\n--- PERSONALITY (Utility AI) ---")
	for p_name in Definitions.PERSONALITY_STATS:
		# get_personality_value() correctly factors in trait modifiers
		print("- %s: %d" % [p_name.capitalize(), character.get_personality_value(p_name)])
		
	print("\n--- ALIGNMENT ---")
	for a_name in Definitions.ALIGNMENT_STATS:
		print("- %s: %d" % [a_name.capitalize(), character.get_alignment_value(a_name)])
		
	print("==============================================================\n")
