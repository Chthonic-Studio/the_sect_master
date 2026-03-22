extends Node

# --- PATH CONSTANTS ---
const BASE_DATA_PATH = "res://Data/"
const MOD_DATA_PATH = "user://Mods/"

# --- REGISTRIES (The "Rules") ---
var traits_registry: Dictionary = {}
var name_pools: Dictionary = {}
var modifiers_registry: Dictionary = {}

# --- REPOSITORIES (The "Living Entities") ---
var character_repo: Dictionary = {} 

var next_char_id: int = 1

func _ready() -> void:
	load_all_data()
	TimeManager.day_passed.connect(_on_day_passed)

## Broadcasts the daily tick to all active characters in the simulation
func _on_day_passed(_day: int) -> void:
	var current_total_days = TimeManager.get_total_days_elapsed()
	
	for char_id in character_repo:
		var character = character_repo[char_id]
		if character.is_alive:
			character.process_daily_tick(current_total_days)
			
func load_all_data() -> void:
	# 1. Load vanilla game data
	_scan_directory_for_json(BASE_DATA_PATH + "Traits", _load_trait_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Names", _load_name_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Modifiers", _load_modifier_data)
	
	# 2. Load modded data (overwrites vanilla IDs or adds new ones)
	_scan_directory_for_json(MOD_DATA_PATH + "Traits", _load_trait_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Names", _load_name_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Modifiers", _load_modifier_data)

func _load_json_to_registry(path: String, target_dict: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		printerr("DataManager: File not found at ", path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data is Array:
		for item in data:
			if item.has("id"):
				target_dict[item["id"]] = item
	elif data is Dictionary:
		target_dict.merge(data)

func _load_names_pool(path: String) -> void:
	if not FileAccess.file_exists(path): return
	var file = FileAccess.open(path, FileAccess.READ)
	name_pools = JSON.parse_string(file.get_as_text())

func _load_modifier_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error != OK:
		printerr("DataManager: JSON Parse Error in Modifiers ", path)
		return
		
	var data = json.data
	if data is Dictionary:
		modifiers_registry.merge(data, true)

#region Character Repo Management
# --- CHARACTER REPO MANAGEMENT ---

func register_character(char_data: CharacterData) -> void:
	if char_data.char_id == "":
		char_data.char_id = _generate_sequential_id()
	character_repo[char_data.char_id] = char_data

func _generate_sequential_id() -> String:
	var id = "char_" + str(next_char_id)
	next_char_id += 1
	return id

func get_character(char_id: String) -> CharacterData:
	return character_repo.get(char_id, null)

#endregion

#region Calculator Functions
# --- CALCULATOR FUNCTIONS ---

func get_total_stat_modifiers(trait_ids: Array[String], modifier_ids: Array[String], stat_enum: int) -> int:
	var total = 0
	var stat_name = Definitions.Stat.keys()[stat_enum].to_lower()
	
	for tid in trait_ids:
		if traits_registry.has(tid):
			total += traits_registry[tid].get("stat_modifiers", {}).get(stat_name, 0)
			
	for mid in modifier_ids:
		if modifiers_registry.has(mid):
			total += modifiers_registry[mid].get("stat_modifiers", {}).get(stat_name, 0)
			
	return total

func get_total_personality_modifiers(trait_ids: Array[String], modifier_ids: Array[String], p_name: String) -> int:
	var total = 0
	for tid in trait_ids:
		if traits_registry.has(tid):
			total += traits_registry[tid].get("personality_modifiers", {}).get(p_name, 0)
			
	for mid in modifier_ids:
		if modifiers_registry.has(mid):
			total += modifiers_registry[mid].get("personality_modifiers", {}).get(p_name, 0)
			
	return total

func get_total_martial_modifiers(trait_ids: Array[String], modifier_ids: Array[String], stat_enum: int) -> int:
	var total = 0
	var stat_name = Definitions.MartialStat.keys()[stat_enum].to_lower()
	
	for tid in trait_ids:
		if traits_registry.has(tid):
			total += traits_registry[tid].get("martial_modifiers", {}).get(stat_name, 0)
			
	for mid in modifier_ids:
		if modifiers_registry.has(mid):
			total += modifiers_registry[mid].get("martial_modifiers", {}).get(stat_name, 0)
			
	return total

func get_total_alignment_modifiers(trait_ids: Array[String], modifier_ids: Array[String], a_name: String) -> int:
	var total = 0
	
	for tid in trait_ids:
		if traits_registry.has(tid):
			total += traits_registry[tid].get("alignment_modifiers", {}).get(a_name, 0)
			
	for mid in modifier_ids:
		if modifiers_registry.has(mid):
			total += modifiers_registry[mid].get("alignment_modifiers", {}).get(a_name, 0)
			
	return total

#endregion

#region Save Data
func get_save_data() -> Dictionary:
	var characters_dict = {}
	for char_id in character_repo:
		characters_dict[char_id] = character_repo[char_id].to_dictionary()
	
	return {
		"next_char_id": next_char_id,
		"characters": characters_dict
	}

func load_save_data(save_data: Dictionary) -> void:
	character_repo.clear()
	next_char_id = save_data.get("next_char_id", 1)
	
	var all_char_data = save_data.get("characters", {})
	for char_id in all_char_data:
		var new_char = CharacterData.new()
		new_char.from_dictionary(all_char_data[char_id])
		character_repo[char_id] = new_char
#endregion

#region Data Loaders & Mod Support

## Creates the user:// folder structure so players know where to put mods
func _ensure_mod_directories() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("Mods"):
		dir.make_dir("Mods")
		dir.make_dir("Mods/Traits")
		dir.make_dir("Mods/Names")
		dir.make_dir("Mods/Modifiers")

## Generic directory scanner that applies a specific loading Callable to each JSON found
func _scan_directory_for_json(path: String, load_func: Callable) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return # Directory doesn't exist yet, which is fine for empty mod folders
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "json":
			var full_path = path + "/" + file_name
			load_func.call(full_path)
		file_name = dir.get_next()

func _load_trait_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error != OK:
		printerr("DataManager: JSON Parse Error in ", path, " at line ", json.get_error_line(), ": ", json.get_error_message())
		return
		
	var data = json.data
	if data is Array:
		for item in data:
			if item.has("id"):
				# This assignment naturally overwrites existing data if a modder reuses an ID
				traits_registry[item["id"]] = item
	elif data is Dictionary:
		traits_registry.merge(data, true)

func _load_name_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	
	if typeof(data) != TYPE_DICTIONARY:
		printerr("DataManager: Name data in ", path, " must be a Dictionary.")
		return
		
	# For names, we do a deep merge so modders can just add 
	# one new culture without wiping the vanilla cultures.
	_deep_merge_dict(name_pools, data)

## Helper to merge nested dictionaries (crucial for names.json mods)
func _deep_merge_dict(target: Dictionary, patch: Dictionary) -> void:
	for key in patch:
		if target.has(key) and typeof(target[key]) == TYPE_DICTIONARY and typeof(patch[key]) == TYPE_DICTIONARY:
			_deep_merge_dict(target[key], patch[key])
		elif target.has(key) and typeof(target[key]) == TYPE_ARRAY and typeof(patch[key]) == TYPE_ARRAY:
			# Append modded names to vanilla arrays
			target[key].append_array(patch[key])
		else:
			target[key] = patch[key]
