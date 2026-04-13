extends Control

## DEBUG_simulation_testing_grounds.gd
## A unified testing environment for demographics, succession, and player events.

@onready var time_label: Label = %WorldTime
@onready var demographics_label: Label = %DemographicsLabel
@onready var logs_container: VBoxContainer = %LogsContainer

func _ready() -> void:
	# 1. Hook up Time UI
	%BtnPause.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.PAUSED))
	%BtnNormal.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.NORMAL))
	%BtnFast.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.FAST))
	%BtnSuperFast.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.SUPER_FAST))
	
	TimeManager.day_passed.connect(_on_day_passed)
	WorldLogManager.log_added.connect(_on_world_log_added)
	
	# 2. Hook up Debug Actions
	%BtnGenerateWorld.pressed.connect(_generate_test_world)
	%BtnTriggerSuccession.pressed.connect(_force_player_death)
	%BtnTriggerPlayerEvent.pressed.connect(_trigger_player_event)

func _generate_test_world() -> void:
	SimulationManager.clear_simulation()
	WorldLogManager.clear_logs()
	for child in logs_container.get_children():
		child.queue_free()
		
	# Generate the base sects
	var generator = load("res://Scripts/Sects/sect_generator.gd").new()
	add_child(generator)
	generator.generate_world_sects(2, 1, 0)
	generator.queue_free()
	
	# Define the Player! We will grab the Sect Master of the first sect.
	if not SimulationManager.sect_repo.is_empty():
		var first_sect_id = SimulationManager.sect_repo.keys()[0]
		var sect = SimulationManager.get_sect(first_sect_id)
		
		# Get their Sect Master
		var masters = sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
		if not masters.is_empty():
			GameManager.set_player_character(masters[0])
			WorldLogManager.add_log("System", "Player assigned to " + SimulationManager.get_character(masters[0]).get_full_name())
	
	# Force the WorldManager to calculate the demographic deficit for Year 1
	TimeManager.year_passed.emit(TimeManager.year)
			
	_refresh_demographics()

func _on_day_passed(_day: int) -> void:
	time_label.text = TimeManager.get_date_string()
	
	# Only update demographics weekly to save some debug overhead
	if _day % 7 == 0:
		_refresh_demographics()

func _refresh_demographics() -> void:
	var total = SimulationManager.character_repo.size()
	var martials = 0
	var non_martials = 0
	
	for char_id in SimulationManager.character_repo:
		var c = SimulationManager.character_repo[char_id]
		if c.is_alive:
			if c.is_martial_artist:
				martials += 1
			else:
				non_martials += 1
				
	demographics_label.text = "Total Population: %d\nMartial Artists: %d\nNon-Martials: %d\nTarget Cap: %d" % [
		total, martials, non_martials, WorldManager.TARGET_WORLD_POPULATION
	]

func _force_player_death() -> void:
	if GameManager.player_char_id == "":
		return
		
	var player = SimulationManager.get_character(GameManager.player_char_id)
	if player and player.is_alive:
		# This will trigger CharacterData.die(), which hits SimulationManager, 
		# which hits SectData.handle_succession(), which emits player_succession_required!
		player.die("a sudden debug heart attack")

func _trigger_player_event() -> void:
	if GameManager.player_char_id == "": return
	
	# Force an event to trigger specifically for the player
	var context = { "initiator": GameManager.player_char_id }
	EventManager.trigger_event("debug_wealth_find", context)

func _on_world_log_added(log_entry: Dictionary) -> void:
	var lbl = Label.new()
	lbl.text = "[%s] %s" % [log_entry.get("date", ""), log_entry.get("message", "")]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if log_entry.get("type", "") == "System":
		lbl.add_theme_color_override("font_color", Color.AQUAMARINE)
		
	logs_container.add_child(lbl)
	logs_container.move_child(lbl, 0) # Add to top
