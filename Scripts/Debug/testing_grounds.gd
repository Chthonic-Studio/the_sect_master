extends Control

const STARTING_SPAWN_COUNT = 5

@onready var spawn_button: Button = $DEBUG_SpawnRandomChar
@onready var character_list: GridContainer = $DEBUG_CharacterList
@onready var time_label: Label = $DEBUG_WorldTime

@onready var btn_pause: Button = $"DEBUG_TimePanel/0"
@onready var btn_x1: Button = $DEBUG_TimePanel/x1
@onready var btn_x2: Button = $DEBUG_TimePanel/x2
@onready var btn_x3: Button = $DEBUG_TimePanel/x3

# UI Map: Links a char_id to the specific Label node that displays their modifiers
var _modifier_labels: Dictionary = {}

func _ready() -> void:
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	
	# Connect Time Controls
	btn_pause.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.PAUSED))
	btn_x1.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.NORMAL))
	btn_x2.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.FAST))
	btn_x3.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.SUPER_FAST))
	
	# Connect Time Manager Signals
	TimeManager.day_passed.connect(_on_day_passed)
	TimeManager.month_passed.connect(func(_m): _update_time_display())
	TimeManager.year_passed.connect(func(_y): _update_time_display())
	
	_update_time_display()
	TimeManager.set_time_speed(TimeManager.Speed.NORMAL)
	
	# --- TEST SCENARIO ---
	for i in range(STARTING_SPAWN_COUNT):
		var character = _generate_and_display_character()
		
		# Specifically infect the FIRST character spawned with a 5-day buff
		if i == 0:
			print("\n>>> INJECTING MODIFIER TO FIRST CHARACTER: ", character.get_full_name())
			character.add_temporary_modifier("demonic_blood_pill", 5)
			_update_modifier_ui(character)
			
		# Print debug info for EVERY character after setup is complete
		_print_deep_debug_info(character)

# --- TIME LOGIC ---

func _update_time_display() -> void:
	time_label.text = TimeManager.get_date_string()

func _on_day_passed(_day: int) -> void:
	_update_time_display()
	
	# Every day, update the dynamic visual countdown for all tracked characters
	for char_id in _modifier_labels:
		if DataManager.character_repo.has(char_id):
			var character = DataManager.character_repo[char_id]
			_update_modifier_ui(character)

# --- UI & DEBUG LOGIC ---

func _on_spawn_button_pressed() -> void:
	var character = _generate_and_display_character()
	_print_deep_debug_info(character)

func _generate_and_display_character() -> CharacterData:
	var new_character = CharacterGenerator.create_character(CharacterGenerator.GenerationContext.WORLD_GEN)
	
	# Listen for when modifiers fall off
	new_character.modifier_expired.connect(_on_modifier_expired)
	
	_create_ui_card(new_character)
	return new_character

func _create_ui_card(character: CharacterData) -> void:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 100)
	
	var vbox = VBoxContainer.new()
	card.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = character.get_full_name()
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	var info_label = Label.new()
	var realm_str = Definitions.MartialRealm.keys()[character.current_realm].capitalize()
	info_label.text = "Age: %d | %s" % [character.age, realm_str]
	info_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info_label)
	
	# Dedicated space for Modifiers
	var mod_label = Label.new()
	mod_label.add_theme_font_size_override("font_size", 10)
	mod_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	mod_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(mod_label)
	
	# Register the label so the time tick can update it efficiently
	_modifier_labels[character.char_id] = mod_label
	_update_modifier_ui(character)
	
	character_list.add_child(card)

## Updates only the localized text for modifiers, saving CPU UI cycles
func _update_modifier_ui(character: CharacterData) -> void:
	if not _modifier_labels.has(character.char_id):
		return
		
	var label: Label = _modifier_labels[character.char_id]
	if character.active_modifiers.is_empty():
		label.text = "No active modifiers."
		return
		
	var text_parts = []
	var current_abs_day = TimeManager.get_total_days_elapsed()
	
	for mod in character.active_modifiers:
		var days_left = mod["expiration_day"] - current_abs_day
		text_parts.append("- %s (%d days left)" % [mod["id"], maxi(0, days_left)]) # maxi ensures we never show negative visually briefly
		
	label.text = "\n".join(text_parts)

## The event-driven callback for when a buff naturally expires
func _on_modifier_expired(character: CharacterData, mod_id: String) -> void:
	print("\n[!!!] TEMPORARY MODIFIER EXPIRED [!!!]")
	print("Character: ", character.get_full_name())
	print("Modifier Lost: ", mod_id)
	print(">>> Recalculating Stats...")
	
	_update_modifier_ui(character)
	_print_deep_debug_info(character)

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
		
	print("\n--- MARTIAL STATS ---")
	for stat_key in Definitions.MartialStat.keys():
		var enum_val = Definitions.MartialStat[stat_key]
		print("- %s: %d" % [stat_key.capitalize(), character.get_martial_stat(enum_val)])
		
	print("\n--- PERSONALITY (Utility AI) ---")
	for p_name in Definitions.PERSONALITY_STATS:
		# get_personality_value() correctly factors in trait modifiers
		print("- %s: %d" % [p_name.capitalize(), character.get_personality_value(p_name)])
		
	print("\n--- ALIGNMENT ---")
	for a_name in Definitions.ALIGNMENT_STATS:
		print("- %s: %d" % [a_name.capitalize(), character.get_alignment_value(a_name)])
		
	print("==============================================================\n")
