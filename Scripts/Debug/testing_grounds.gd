extends Control

const STARTING_SPAWN_COUNT = 5

@onready var spawn_button: Button = $DEBUG_ButtonVbox/DEBUG_SpawnRandomChar
@onready var test_directive_button: Button = $DEBUG_ButtonVbox/DEBUG_SendLastCharToTestDirective
@onready var character_list: GridContainer = $DEBUG_List/DEBUG_CharacterList
@onready var time_label: Label = $DEBUG_WorldTime
@onready var char_info_grid: GridContainer = $DEBUG_LastCharInfo/GridContainer

@onready var btn_pause: Button = $DEBUG_TimePanel/"0"
@onready var btn_x1: Button = $DEBUG_TimePanel/"x1"
@onready var btn_x2: Button = $DEBUG_TimePanel/"x2"
@onready var btn_x3: Button = $DEBUG_TimePanel/"x3"

# UI Caches for performance
var _modifier_labels: Dictionary = {}
var _panel_containers: Dictionary = {}
var _detail_labels: Dictionary = {}

var _inspected_character: CharacterData = null

func _ready() -> void:
	spawn_button.pressed.connect(_on_spawn_button_pressed)
	test_directive_button.pressed.connect(_on_test_directive_pressed)
	
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

# --- TIME LOGIC ---

func _update_time_display() -> void:
	time_label.text = TimeManager.get_date_string()

func _on_day_passed(_day: int) -> void:
	_update_time_display()
	
	# Update the localized UIs for modifiers
	for char_id in _modifier_labels:
		if SimulationManager.character_repo.has(char_id):
			var character = SimulationManager.character_repo[char_id]
			_update_modifier_ui(character)
			
	# Real-time visualization of the Utility AI ticking
	if _inspected_character != null and _inspected_character.is_alive:
		_refresh_character_info(_inspected_character)

# --- UI & DEBUG LOGIC ---

func _on_spawn_button_pressed() -> void:
	var character = _generate_and_display_character()
	_print_deep_debug_info(character)

func _generate_and_display_character() -> CharacterData:
	var new_character = CharacterGenerator.create_character(CharacterGenerator.GenerationContext.WORLD_GEN)
	
	new_character.modifier_expired.connect(_on_modifier_expired)
	_create_ui_card(new_character)
	
	var available_weapons = DataManager.weapons_registry.keys()
	if not available_weapons.is_empty():
		new_character.equipped_weapon_id = available_weapons.pick_random()
		new_character.recalculate_all_stats()
	
	# Set this as the active character to track on the daily ticks
	_inspected_character = new_character
	_refresh_character_info(new_character)
	
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
	
	var mod_label = Label.new()
	mod_label.add_theme_font_size_override("font_size", 10)
	mod_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	mod_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(mod_label)
	
	_modifier_labels[character.char_id] = mod_label
	_update_modifier_ui(character)
	
	# --- Add the button to open the dashboard ---
	var open_dashboard_btn = Button.new()
	open_dashboard_btn.text = "View Dashboard"
	open_dashboard_btn.pressed.connect(func():
		UIManager.open_panel("character_dashboard", character)
	)
	vbox.add_child(open_dashboard_btn)
	# -------------------------------------------------
	
	character_list.add_child(card)

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
		text_parts.append("- %s (%d days left)" % [mod["id"], maxi(0, days_left)])
		
	label.text = "\n".join(text_parts)

func _on_modifier_expired(character: CharacterData, _mod_id: String) -> void:
	_update_modifier_ui(character)

func _print_deep_debug_info(character: CharacterData) -> void:
	print("\n================ NEW CHARACTER SPAWNED: %s ================" % character.char_id)
	print("Name: %s | Traits: %s" % [character.get_full_name(), character.traits])

## Refreshes the UIs at the bottom. No longer destroys/recreates nodes if they already exist.
func _refresh_character_info(character: CharacterData) -> void:
	
	_update_info_panel("Identity", {
		"Name": character.get_full_name(),
		"Age": str(character.age),
		"Gender": Definitions.Gender.keys()[character.gender].capitalize(),
		"Realm": Definitions.MartialRealm.keys()[character.current_realm].capitalize(),
		"Aptitude": Definitions.Aptitude.keys()[character.aptitude].capitalize(),
		"Weapon": character.equipped_weapon_id if character.equipped_weapon_id != "" else "Unarmed"
	})
	
	var core_stats = {}
	for s in Definitions.Stat.values():
		core_stats[Definitions.Stat.keys()[s].capitalize()] = str(character.get_stat(s))
	_update_info_panel("Core Stats", core_stats)
	
	var martial_stats = {}
	for ms in Definitions.MartialStat.values():
		martial_stats[Definitions.MartialStat.keys()[ms].capitalize()] = str(character.get_martial_stat(ms))
	_update_info_panel("Martial Stats", martial_stats)
	
	var personality = {}
	for p in Definitions.PERSONALITY_STATS:
		personality[p.capitalize()] = str(character.get_personality_value(p))
	_update_info_panel("Personality", personality)
	
	var alignment = {}
	for a in Definitions.ALIGNMENT_STATS:
		alignment[a.capitalize()] = str(character.get_alignment_value(a))
	_update_info_panel("Alignment", alignment)
	
	var traits_str = ", ".join(character.traits) if character.traits.size() > 0 else "None"
	_update_info_panel("Traits", {"Active": traits_str})
	
	# --- NEW AI VISUALIZATION PANELS ---
	
	var states = {}
	for k in character.state_vars:
		states[k.capitalize()] = "%.1f" % character.state_vars[k] # Formats float to 1 decimal
	_update_info_panel("State Vars", states)
	
	var needs_data = {}
	for k in character.needs:
		needs_data[k.capitalize()] = "%.1f" % character.needs[k]
	_update_info_panel("Needs", needs_data)
	
	var ai_data = {}
	if character.brain.current_action:
		ai_data["Current Action"] = character.brain.current_action.id
		ai_data["Days Remaining"] = str(character.brain.current_action.duration_remaining)
	else:
		ai_data["Current Action"] = "None (Evaluating)"
		ai_data["Days Remaining"] = "0"
	_update_info_panel("AI Brain", ai_data)
	
	var directive_data = {}
	if character.current_directive != null:
		directive_data["Active Mission"] = character.current_directive.id
		directive_data["Days Remaining"] = str(character.current_directive.duration_remaining)
		# Optionally, show how grueling it is:
		directive_data["Fatigue Rate"] = "+%.1f/day" % character.current_directive.decay_modifiers.get("fatigue_rate", 5.0)
	else:
		directive_data["Active Mission"] = "None"
		directive_data["Days Remaining"] = "0"
	
	_update_info_panel("Directives", directive_data)

## Highly optimized procedural UI. Builds the nodes once, then just updates their strings.
func _update_info_panel(title: String, data: Dictionary) -> void:
	var vbox: VBoxContainer
	
	# Check if the panel exists. If not, build it.
	if not _panel_containers.has(title):
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		vbox = VBoxContainer.new()
		panel.add_child(vbox)
		
		var title_label = Label.new()
		title_label.text = "- " + title + " -"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(title_label)
		
		vbox.add_child(HSeparator.new())
		char_info_grid.add_child(panel)
		
		_panel_containers[title] = vbox
	else:
		vbox = _panel_containers[title]
		
	# Update or create the individual labels
	for key in data:
		var map_key = title + "_" + key
		var label: Label
		
		if _detail_labels.has(map_key):
			label = _detail_labels[map_key]
		else:
			label = Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(label)
			_detail_labels[map_key] = label
			
		label.text = key + ": " + str(data[key])

func _on_test_directive_pressed() -> void:
	if _inspected_character == null or not _inspected_character.is_alive:
		print("No valid character selected to send on a directive.")
		return
		
	# Create a 7-day expedition to the ruins.
	# The DataManager factory automatically constructs it and injects default decay modifiers.
	_inspected_character.current_directive = DataManager.create_directive("directive_explore_ruins", 7)
	
	print("\n>>> ASSIGNED DIRECTIVE TO: ", _inspected_character.get_full_name())
	
	# Immediately force the UI to refresh so we see the change without waiting for a day to pass
	_refresh_character_info(_inspected_character)
