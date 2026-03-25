extends Node

# --- PATH CONSTANTS ---
const BASE_DATA_PATH = "res://Data/"
const MOD_DATA_PATH = "user://Mods/"

# --- REGISTRIES (The "Rules") ---
var traits_registry: Dictionary = {}
var name_pools: Dictionary = {}
var modifiers_registry: Dictionary = {}
var weapons_registry: Dictionary = {}

# --- AI LOGIC REGISTRIES ---
var micro_desires: Dictionary = {} # Dict[String, Array[Desire]] mapped by tag
var macro_desires: Dictionary = {} # Dict[String, Array[Desire]] mapped by tag
var action_scripts_registry: Dictionary = {} # Maps String IDs to GDScript references (The Factory)
var directive_scripts_registry: Dictionary = {} # Maps String IDs to GDScript references

# --- REPOSITORIES (The "Living Entities") ---
var character_repo: Dictionary = {} 

var next_char_id: int = 1

func _ready() -> void:
	load_all_data()
	TimeManager.day_passed.connect(_on_day_passed)

## Broadcasts the daily tick to all active characters in the simulation
func _on_day_passed(_day: int) -> void:
	var current_total_days = TimeManager.get_total_days_elapsed()
	
	# Duplicate the keys to safely allow repo modifications during the tick
	var active_keys = character_repo.keys().duplicate()
	
	for char_id in active_keys:
		# Double check it still exists (might have been removed by a previous character's action)
		if character_repo.has(char_id):
			var character = character_repo[char_id]
			if character.is_alive:
				character.process_daily_tick(current_total_days)
			
func load_all_data() -> void:
	_ensure_mod_directories()
	
	# 0. Mount Mod Packs FIRST (Injects modded scripts and assets into res://)
	_mount_mod_packs()
	# 1. Load vanilla game data
	_scan_directory_for_json(BASE_DATA_PATH + "Traits", _load_trait_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Names", _load_name_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Modifiers", _load_modifier_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Weapons", _load_weapon_data)
	
	# 2. Load modded data (overwrites vanilla IDs or adds new ones)
	_scan_directory_for_json(MOD_DATA_PATH + "Traits", _load_trait_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Names", _load_name_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Modifiers", _load_modifier_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Weapons", _load_weapon_data)
	
	# 3. Load AI Logic Scripts 
	_scan_directory_for_scripts("res://Scripts/AI/Desires", _load_desire_script)
	_scan_directory_for_scripts("res://Scripts/AI/Actions", _load_action_script)
	_scan_directory_for_scripts("res://Scripts/AI/Directives", _load_directive_script)

func _load_json_to_registry(path: String, target_dict: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		printerr("DataManager: File not found at ", path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("DataManager: Failed to open file for reading (_load_json_to_registry @ Data Manager): ", path)
		return
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
	if not file:
		printerr("DataManager: Failed to open file for reading (_load_names_pool @ Data Manager): ", path)
		return
	name_pools = JSON.parse_string(file.get_as_text())

func _load_modifier_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("DataManager: Failed to open file for reading (_load_modifier_data @ Data Manager): ", path)
		return
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error != OK:
		printerr("DataManager: JSON Parse Error in Modifiers ", path)
		return
		
	var data = json.data
	if data is Dictionary:
		modifiers_registry.merge(data, true)

func _load_weapon_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("DataManager: Failed to open file for reading (_load_weapon_data @ Data Manager): ", path)
		return
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK: return
	
	var data = json.data
	if data is Dictionary:
		for weapon_id in data:
			var weapon = data[weapon_id]
			
			# Pre-process stat modifiers (String keys to Enum integer keys)
			if weapon.has("stat_modifiers"):
				var parsed_stats = {}
				for key in weapon["stat_modifiers"]:
					var stat_enum = Definitions.get_stat_enum(key)
					if stat_enum != -1:
						parsed_stats[stat_enum] = weapon["stat_modifiers"][key]
				weapon["stat_modifiers"] = parsed_stats
				
			# Pre-process martial modifiers
			if weapon.has("martial_modifiers"):
				var parsed_martial = {}
				for key in weapon["martial_modifiers"]:
					var martial_enum = Definitions.get_martial_enum(key)
					if martial_enum != -1:
						parsed_martial[martial_enum] = weapon["martial_modifiers"][key]
				weapon["martial_modifiers"] = parsed_martial
				
			weapons_registry[weapon_id] = weapon

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
	if not file:
		printerr("DataManager: Failed to open file for reading (_load_trait_data @ Data Manager): ", path)
		return
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
	if not file:
		printerr("DataManager: Failed to open file for reading (_load_name_data @ Data Manager): ", path)
		return
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

## Scans the user://Mods directory for exported .zip or .pck files 
## and mounts them into the res:// virtual file system.
func _mount_mod_packs() -> void:
	var dir = DirAccess.open("user://Mods")
	if not dir:
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".zip") or file_name.ends_with(".pck")):
			var full_path = "user://Mods/" + file_name
			# This is the magic Godot function that merges the mod into res://
			var success = ProjectSettings.load_resource_pack(full_path)
			if success:
				print("DataManager: Successfully mounted mod pack -> ", file_name)
			else:
				printerr("DataManager: Failed to mount mod pack -> ", file_name)
		file_name = dir.get_next()

#endregion


#region AI Logic Loaders & The Action Factory

## Scans a directory for Godot scripts (.gd) or compiled scripts (.gdc) 
func _scan_directory_for_scripts(path: String, load_func: Callable) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return 
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			# Support both raw source (.gd) and exported bytecode (.gdc)
			if file_name.ends_with(".gd") or file_name.ends_with(".gdc") or file_name.ends_with(".remap"):
				# Godot 4 export remapping sometimes changes .gd to .gd.remap
				var clean_name = file_name.replace(".remap", "") 
				var full_path = path + "/" + clean_name
				load_func.call(full_path)
		file_name = dir.get_next()

func _load_desire_script(path: String) -> void:
	var script = load(path)
	if script and script is Script:
		# Instantiate the script to hold in memory globally
		var desire_instance = script.new()
		if desire_instance is Desire:
			# Determine which dictionary to route it to
			var target_registry = macro_desires if desire_instance.is_macro else micro_desires
			
			# Map the instance to every tag it supports
			for tag in desire_instance.ai_tags:
				if not target_registry.has(tag):
					target_registry[tag] = []
				target_registry[tag].append(desire_instance)
		else:
			printerr("DataManager: Script at ", path, " does not extend Desire.")

func _load_action_script(path: String) -> void:
	var script = load(path)
	if script and script is Script:
		# Replace .remap first, then use get_basename() to properly strip .gd or .gdc
		var clean_filename = path.get_file().replace(".remap", "")
		var action_id = clean_filename.get_basename()
		action_scripts_registry[action_id] = script

func create_action(action_id: String, duration: int) -> ActionPlan:
	if action_id == "":
		return null
		
	if action_scripts_registry.has(action_id):
		var script_ref = action_scripts_registry[action_id]
		# Only pass the duration. The script inherently knows its own ID.
		return script_ref.new(duration)
		
	printerr("ActionFactory: Attempted to create unknown action_id: ", action_id)
	
	# Fallback to prevent crashes
	var fallback = ActionPlan.new(duration)
	fallback.id = action_id 
	return fallback

func _load_directive_script(path: String) -> void:
	var script = load(path)
	if script and script is Script:
		# Same as above to ensure accurate ID mapping in exported builds
		var clean_filename = path.get_file().replace(".remap", "")
		var directive_id = clean_filename.get_basename()
		directive_scripts_registry[directive_id] = script

func create_directive(directive_id: String, duration: int, custom_modifiers: Dictionary = {}) -> Directive:
	if directive_id == "":
		return null
		
	if directive_scripts_registry.has(directive_id):
		var script_ref = directive_scripts_registry[directive_id]
		return script_ref.new(duration, custom_modifiers)
		
	printerr("ActionFactory: Attempted to create unknown directive_id: ", directive_id)
	var fallback = Directive.new(duration, custom_modifiers)
	fallback.id = directive_id
	return fallback

#endregion

# --- COMBAT HELPERS ---
## Returns 1.5 if attacker has advantage, 0.75 if disadvantage, 1.0 if neutral
func get_weapon_matchup_multiplier(attacker_weapon_id: String, defender_weapon_id: String) -> float:
	var attacker = weapons_registry.get(attacker_weapon_id)
	var defender = weapons_registry.get(defender_weapon_id)
	
	if not attacker or not defender: return 1.0
	
	var def_type = defender.get("weapon_type", "")
	
	if def_type in attacker.get("strong_against", []):
		return 1.5
	elif def_type in attacker.get("weak_against", []):
		return 0.75
		
	return 1.0
