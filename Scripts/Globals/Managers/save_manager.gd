extends Node

const SAVE_DIR = "user://Saves/"

func _ready() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("Saves"):
		dir.make_dir("Saves")

func save_game(save_name: String) -> void:
	var save_path = SAVE_DIR + save_name + ".json"
	
	# 1. Gather all living data from the managers
	var characters_dict = {}
	for char_id in SimulationManager.character_repo:
		characters_dict[char_id] = SimulationManager.character_repo[char_id].to_dictionary()
		
	var sects_dict = {}
	for s_id in SimulationManager.sect_repo:
		sects_dict[s_id] = SimulationManager.sect_repo[s_id].to_dictionary()
	
	var save_data = {
		"time": {
			"year": TimeManager.year,
			"month": TimeManager.month,
			"day": TimeManager.day,
			"epoch_day": TimeManager.get_total_days_elapsed()
		},
		"player_char_id": GameManager.player_char_id,
		"simulation": {
			"next_char_id": SimulationManager.next_char_id,
			"next_sect_id": SimulationManager.next_sect_id,
			"characters": characters_dict,
			"sects": sects_dict,
			"sect_relationships": SimulationManager.sect_relationships,
			"delayed_events": EventManager._delayed_events
		},
		"world_logs": WorldLogManager.global_logs
	}
	
	# 2. Write to disk
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		print("SaveManager: Game saved successfully to ", save_path)
	else:
		printerr("SaveManager: Failed to write save file.")

func load_game(save_name: String) -> void:
	var save_path = SAVE_DIR + save_name + ".json"
	if not FileAccess.file_exists(save_path):
		printerr("SaveManager: Save file does not exist at ", save_path)
		return
		
	var file = FileAccess.open(save_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		printerr("SaveManager: Failed to parse save JSON.")
		return
		
	var data = json.data
	
	# 1. Restore Time
	var time_data = data.get("time", {})
	TimeManager.year = time_data.get("year", 740)
	TimeManager.month = time_data.get("month", 1)
	TimeManager.day = time_data.get("day", 1)
	TimeManager._epoch_day = time_data.get("epoch_day", 0)
	
	# 2. Restore Simulation
	var sim_data = data.get("simulation", {})
	SimulationManager.clear_simulation()
	
	if sim_data.has("sect_relationships"):
		SimulationManager.sect_relationships = sim_data["sect_relationships"].duplicate()
	
	if sim_data.has("delayed_events"):
		var parsed_events: Array[Dictionary] = []
		parsed_events.assign(sim_data["delayed_events"])
		EventManager._delayed_events = parsed_events
	else:
		EventManager._delayed_events.clear()
		
	SimulationManager.next_char_id = sim_data.get("next_char_id", 1)
	SimulationManager.next_sect_id = sim_data.get("next_sect_id", 1)
	
	var all_char_data = sim_data.get("characters", {})
	for char_id in all_char_data:
		var new_char = CharacterData.new()
		new_char.from_dictionary(all_char_data[char_id])
		SimulationManager.character_repo[char_id] = new_char
		# Rebuild the active processing list for alive characters
		if new_char.is_alive:
			SimulationManager._active_char_ids.append(char_id)
		
	var all_sect_data = sim_data.get("sects", {})
	for s_id in all_sect_data:
		var new_sect = SectData.new()
		new_sect.from_dictionary(all_sect_data[s_id])
		SimulationManager.sect_repo[s_id] = new_sect
	
	# 3. Restore Player State
	var player_id = data.get("player_char_id", "")
	if player_id != "":
		GameManager.set_player_character(player_id)
		
	# 4. Restore World Logs
	WorldLogManager.clear_logs()
	if data.has("world_logs"):
		var logs_array: Array[Dictionary] = []
		logs_array.assign(data["world_logs"])
		WorldLogManager.global_logs = logs_array
		
	print("SaveManager: Game loaded successfully from ", save_path)

## Returns a list of save header dictionaries for the Load Game UI.
## Each header contains: filename, player_name, date_string, epoch_day.
func get_all_save_headers() -> Array[Dictionary]:
	var headers: Array[Dictionary] = []
	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		return headers
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path = SAVE_DIR + file_name
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var data = json.data
					var time_data = data.get("time", {})
					var player_id = data.get("player_char_id", "")
					var chars = data.get("simulation", {}).get("characters", {})
					var player_name = "Unknown"
					if chars.has(player_id):
						var pc = chars[player_id]
						player_name = pc.get("last_name", "?") + " " + pc.get("first_name", "?")
					headers.append({
						"filename": file_name.get_basename(),
						"player_name": player_name,
						"year": time_data.get("year", 0),
						"month": time_data.get("month", 1),
						"day": time_data.get("day", 1)
					})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Sort by epoch_day descending (most recent first)
	headers.sort_custom(func(a, b): return a.get("year", 0) > b.get("year", 0))
	return headers
