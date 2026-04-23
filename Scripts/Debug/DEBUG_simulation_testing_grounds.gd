extends Control

var _sect_list_vbox: VBoxContainer

func _ready() -> void:
	# Instantiate required dashboards so they register with UIManager
	var sect_dashboard = preload("res://Scenes/UI/sect_dashboard.tscn").instantiate()
	add_child(sect_dashboard)
	
	var char_dashboard = preload("res://Scenes/UI/character_dashboard.tscn").instantiate()
	add_child(char_dashboard)

	# Set up time controls
	%BtnPause.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.PAUSED))
	%BtnNormal.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.NORMAL))
	%BtnFast.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.FAST))
	%BtnSuperFast.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.SUPER_FAST))
	
	TimeManager.day_passed.connect(_on_day_passed)
	
	# Setup main buttons
	%BtnGenerateWorld.pressed.connect(_on_generate_world)
	%BtnTriggerSuccession.pressed.connect(_on_trigger_succession)
	%BtnTriggerPlayerEvent.pressed.connect(_on_trigger_player_event)
	
	WorldLogManager.log_added.connect(_on_world_log_added)
	
	# Create the dynamic Sect List UI
	_create_sect_list_ui()

func _create_sect_list_ui() -> void:
	# Dynamically inject a Sect List panel in the center of the screen
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 400)
	panel.position = Vector2(350, 110) # Positioned between Controls and Logs
	add_child(panel)
	
	var scroll = ScrollContainer.new()
	panel.add_child(scroll)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	
	_sect_list_vbox = VBoxContainer.new()
	_sect_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sect_list_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(_sect_list_vbox)

func _on_generate_world() -> void:
	# Clear previous data
	SimulationManager.clear_simulation()
	WorldLogManager.clear_logs()
	for child in _sect_list_vbox.get_children():
		child.queue_free()
	for child in %LogsContainer.get_children():
		child.queue_free()
		
	# Generate sects and populate the world
	SectGenerator.generate_world_sects(3, 2, 1)
	
	# Automatically assign the player character to a random Sect Master so constraints work
	_assign_random_player()
	
	# Refresh the sect list UI
	_populate_sect_list()

func _assign_random_player() -> void:
	for sect_id in SimulationManager.sect_repo:
		var sect = SimulationManager.sect_repo[sect_id]
		var masters = sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
		if not masters.is_empty():
			var p_char = SimulationManager.get_character(masters[0])
			# Give them infinite money so you can test 'Gift Wealth' safely
			p_char.wealth = 9999
			GameManager.set_player_character(p_char.char_id)
			WorldLogManager.add_log("System", "Player assigned to: " + p_char.get_full_name())
			break

func _populate_sect_list() -> void:
	var header = Label.new()
	header.text = "Active Sects (Click to Open)"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sect_list_vbox.add_child(header)
	
	for sect_id in SimulationManager.sect_repo:
		var sect = SimulationManager.sect_repo[sect_id]
		var btn = Button.new()
		btn.text = sect.sect_name
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(func():
			# This is where we hook into the UIManager!
			UIManager.open_panel("sect_dashboard", sect)
		)
		_sect_list_vbox.add_child(btn)

func _on_trigger_succession() -> void:
	if GameManager.player_char_id != "":
		var p_char = SimulationManager.get_character(GameManager.player_char_id)
		if p_char: p_char.die("testing grounds forced death")

func _on_trigger_player_event() -> void:
	if GameManager.player_char_id != "":
		EventManager.trigger_event("social_brawl_minor", {"initiator": GameManager.player_char_id})

func _on_world_log_added(log_entry: Dictionary) -> void:
	var lbl = Label.new()
	lbl.text = "[%s] %s: %s" % [log_entry.get("date", ""), log_entry.get("type", ""), log_entry.get("message", "")]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%LogsContainer.add_child(lbl)
	%LogsContainer.move_child(lbl, 0) # Prepend

func _on_day_passed(_day: int) -> void:
	%WorldTime.text = TimeManager.get_date_string()
	%DemographicsLabel.text = "Total Population: %d" % SimulationManager.character_repo.size()
