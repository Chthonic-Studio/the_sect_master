extends Node

# --- REPOSITORIES (The "Living Entities") ---
var character_repo: Dictionary = {} 
var next_char_id: int = 1

var sect_repo: Dictionary = {}
var next_sect_id: int = 1

var sect_relationships: Dictionary = {} # Maps "sect_a|sect_b" -> int (-100 to 100)

func _ready() -> void:
	TimeManager.day_passed.connect(_on_day_passed)
	TimeManager.month_passed.connect(_on_month_passed)

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

## Broadcasts the macro monthly tick to all active sects
func _on_month_passed(_month: int) -> void:
	var active_sect_keys = sect_repo.keys().duplicate()
	for s_id in active_sect_keys:
		if sect_repo.has(s_id):
			sect_repo[s_id].process_monthly_tick()

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

# Add these functions anywhere in the script
#region Diplomacy & Relationships

## Generates an alphabetically sorted, unique key for any two sects.
func _get_relationship_key(id_a: String, id_b: String) -> String:
	if id_a < id_b:
		return id_a + "|" + id_b
	return id_b + "|" + id_a

## Gets the relationship between two sects. Defaults to 0 if they haven't interacted.
func get_sect_relationship(id_a: String, id_b: String) -> int:
	if id_a == id_b: return 100 # A sect always loves itself
	var key = _get_relationship_key(id_a, id_b)
	return sect_relationships.get(key, 0)

## Sets the relationship value, clamping it between -100 and 100.
func set_sect_relationship(id_a: String, id_b: String, value: int) -> void:
	if id_a == id_b: return
	var key = _get_relationship_key(id_a, id_b)
	sect_relationships[key] = clampi(value, -100, 100)

## Modifies the relationship by a delta amount safely.
func modify_sect_relationship(id_a: String, id_b: String, amount: int) -> void:
	var current = get_sect_relationship(id_a, id_b)
	set_sect_relationship(id_a, id_b, current + amount)

#endregion




func clear_simulation() -> void:
	character_repo.clear()
	sect_repo.clear()
	next_char_id = 1
	next_sect_id = 1
