extends Node

# --- REPOSITORIES (The "Living Entities") ---
var character_repo: Dictionary = {} 
var next_char_id: int = 1

var sect_repo: Dictionary = {}
var next_sect_id: int = 1

func _ready() -> void:
	TimeManager.day_passed.connect(_on_day_passed)

## Broadcasts the daily tick to all active characters and sects in the simulation
func _on_day_passed(_day: int) -> void:
	var current_total_days = TimeManager.get_total_days_elapsed()
	
	# Duplicate the keys to safely allow repo modifications during the tick
	var active_char_keys = character_repo.keys().duplicate()
	for char_id in active_char_keys:
		if character_repo.has(char_id):
			var character = character_repo[char_id]
			if character.is_alive:
				character.process_daily_tick(current_total_days)

	var active_sect_keys = sect_repo.keys().duplicate()
	for s_id in active_sect_keys:
		if sect_repo.has(s_id):
			sect_repo[s_id].process_daily_tick(current_total_days)

#region Character Management
func register_character(char_data: CharacterData) -> void:
	if char_data.char_id == "":
		char_data.char_id = "char_" + str(next_char_id)
		next_char_id += 1
	character_repo[char_data.char_id] = char_data

func get_character(char_id: String) -> CharacterData:
	return character_repo.get(char_id, null)
#endregion

#region Sect Management
func register_sect(sect_data: SectData) -> void:
	if sect_data.sect_id == "":
		sect_data.sect_id = "sect_" + str(next_sect_id)
		next_sect_id += 1
	sect_repo[sect_data.sect_id] = sect_data

func get_sect(sect_id: String) -> SectData:
	return sect_repo.get(sect_id, null)
#endregion

func clear_simulation() -> void:
	character_repo.clear()
	sect_repo.clear()
	next_char_id = 1
	next_sect_id = 1
