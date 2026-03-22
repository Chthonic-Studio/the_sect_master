extends Control

const STARTING_SPAWN_COUNT = 5

@onready var spawn_button: Button = $DEBUG_SpawnRandomChar
@onready var character_list: GridContainer = $DEBUG_CharacterList

@onready var time_label: Label = $DEBUG_WorldTime
@onready var btn_pause: Button = $"DEBUG_TimePanel/0"
@onready var btn_x1: Button = $DEBUG_TimePanel/x1
@onready var btn_x2: Button = $DEBUG_TimePanel/x2
@onready var btn_x3: Button = $DEBUG_TimePanel/x3

func _ready() -> void:
	# 1. Connect Character Spawning
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	
	# 2. Connect Time Controls (Using lambdas for clean, one-line signal connections)
	btn_pause.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.PAUSED))
	btn_x1.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.NORMAL))
	btn_x2.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.FAST))
	btn_x3.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.SUPER_FAST))
	
	# 3. Connect Time Manager Signals to UI Updates
	TimeManager.day_passed.connect(_update_time_display)
	TimeManager.month_passed.connect(_update_time_display)
	TimeManager.year_passed.connect(_update_time_display)
	
	# Initialize Display
	_update_time_display(0) # Passing a dummy 0 just to initialize the text
	TimeManager.set_time_speed(TimeManager.Speed.NORMAL) # Start the clock!
	
	# Spawn initial batch
	for i in range(STARTING_SPAWN_COUNT):
		_generate_and_display_character()

# --- TIME LOGIC ---

## Triggered by TimeManager signals.
## The underscore parameter ignores the specific int (day/month/year) passed by the signal,
## as we just grab the fully formatted string from the TimeManager directly.
func _update_time_display(_value_passed: int) -> void:
	time_label.text = TimeManager.get_date_string()
	

# --- CHARACTER LOGIC ---

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
