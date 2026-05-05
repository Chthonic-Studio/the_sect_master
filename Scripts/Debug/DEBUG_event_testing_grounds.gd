extends Control

@onready var log_vbox: VBoxContainer = %LogVBox
@onready var event_dropdown: OptionButton = %EventDropdown
@onready var initiator_dropdown: OptionButton = %InitiatorDropdown
@onready var target_dropdown: OptionButton = %TargetDropdown
@onready var world_time_lbl: Label = %DEBUG_WorldTime

var available_events: Array[String] = []
var available_characters: Array[String] = []

func _ready() -> void:
	# Time Controls
	%Btn0.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.PAUSED))
	%Btn1.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.NORMAL))
	%Btn2.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.FAST))
	%Btn3.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.SUPER_FAST))
	
	%GenerateWorldBtn.pressed.connect(_on_generate_world_pressed)
	%ForceEventBtn.pressed.connect(_on_force_event_pressed)
	%ClearLogBtn.pressed.connect(_on_clear_log_pressed)
	
	# Connect to WorldLogManager to catch background AI events and global logs
	WorldLogManager.log_added.connect(_on_world_log_added)
	
	_add_log_entry("System", "Event Testing Grounds Initialized. Awaiting World Generation.")

func _process(_delta: float) -> void:
	world_time_lbl.text = TimeManager.get_date_string()

func _on_generate_world_pressed() -> void:
	SimulationManager.clear_simulation()
	# Generate a small world for testing purposes
	await SectGenerator.generate_world_sects()
	
	_populate_dropdowns()
	_add_log_entry("System", "World Generated with " + str(SimulationManager.sect_repo.size()) + " Sects and " + str(SimulationManager.character_repo.size()) + " Characters.")

func _populate_dropdowns() -> void:
	event_dropdown.clear()
	initiator_dropdown.clear()
	target_dropdown.clear()
	available_events.clear()
	available_characters.clear()
	
	# Populate Events
	for e_id in DataManager.events_registry:
		available_events.append(e_id)
		var e_name = DataManager.events_registry[e_id].get("title", e_id)
		event_dropdown.add_item(e_name + " (" + e_id + ")")
		
	# Populate Characters (Sort them by sect for easier reading)
	target_dropdown.add_item("None (Empty Target)")
	available_characters.append("") # Index 0 for target is empty
	
	for s_id in SimulationManager.sect_repo:
		var sect = SimulationManager.sect_repo[s_id]
		for c_id in sect.all_members:
			var char_obj = SimulationManager.get_character(c_id)
			if char_obj:
				var display_name = char_obj.get_full_name() + " [" + sect.sect_name + "]"
				available_characters.append(c_id)
				initiator_dropdown.add_item(display_name)
				target_dropdown.add_item(display_name)

func _on_force_event_pressed() -> void:
	if available_events.is_empty() or available_characters.is_empty():
		_add_log_entry("Error", "Please generate the world first.")
		return
		
	var selected_event_id = available_events[event_dropdown.selected]
	# initiator dropdown is offset by -1 because target dropdown has "None" at index 0, but they share the same array
	# Wait, initiator dropdown does NOT have "None". So initiator index + 1 maps to available_characters
	var initiator_id = available_characters[initiator_dropdown.selected + 1] 
	var target_id = available_characters[target_dropdown.selected]
	
	var context = {
		"initiator": initiator_id
	}
	
	var initiator_char = SimulationManager.get_character(initiator_id)
	if initiator_char:
		context["initiator_sect"] = initiator_char.sect_id
		
	if target_id != "":
		context["target"] = target_id
		var target_char = SimulationManager.get_character(target_id)
		if target_char:
			context["target_sect"] = target_char.sect_id
			
	_add_log_entry("Debug", "Force triggering event: " + selected_event_id + " on " + initiator_id)
	EventManager.trigger_event(selected_event_id, context)

func _on_world_log_added(entry: Dictionary) -> void:
	_add_log_entry(entry.get("type", "Log"), entry.get("message", ""))

func _add_log_entry(category: String, message: String) -> void:
	var lbl = Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Color code based on category
	match category:
		"System", "Debug":
			lbl.add_theme_color_override("font_color", Color.LIGHT_SLATE_GRAY)
		"Error":
			lbl.add_theme_color_override("font_color", Color.INDIAN_RED)
		"war":
			lbl.add_theme_color_override("font_color", Color.CRIMSON)
		_:
			lbl.add_theme_color_override("font_color", Color.WHITE)
			
	lbl.text = "[%s] [%s] %s" % [TimeManager.get_date_string(), category.to_upper(), message]
	
	log_vbox.add_child(lbl)
	log_vbox.move_child(lbl, 0) # Add to top of the list

func _on_clear_log_pressed() -> void:
	for child in log_vbox.get_children():
		child.queue_free()
