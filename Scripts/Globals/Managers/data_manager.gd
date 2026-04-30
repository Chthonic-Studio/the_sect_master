extends Node

# --- PATH CONSTANTS ---
const BASE_DATA_PATH = "res://Data/"
const MOD_DATA_PATH = "user://Mods/"

# --- CHARACTER REGISTRIES ---
var traits_registry: Dictionary = {}
var name_pools: Dictionary = {}
var modifiers_registry: Dictionary = {}
var weapons_registry: Dictionary = {}
var events_registry: Dictionary = {}

# --- SECT SYSTEM REGISTRIES ---
var premade_sects_registry: Dictionary = {}
var sect_laws_registry: Dictionary = {}
var buildings_registry: Dictionary = {}
var tenets_registry: Dictionary = {}      
var sect_names_registry: Dictionary = {}  

# --- MAP REGISTRIES ---
var regions_registry: Dictionary = {}    # region_id -> region data
var provinces_registry: Dictionary = {}  # province_id -> province data

# --- AI LOGIC REGISTRIES ---
var micro_desires: Dictionary = {} # Dict[String, Array[Desire]] mapped by tag
var macro_desires: Dictionary = {} # Dict[String, Array[Desire]] mapped by tag
var action_scripts_registry: Dictionary = {} # Maps String IDs to GDScript references (The Factory)
var directive_scripts_registry: Dictionary = {} # Maps String IDs to GDScript references

func _ready() -> void:
	load_all_data()
			
func load_all_data() -> void:
	_ensure_mod_directories()
	
	# 0. Mount Mod Packs FIRST (Injects modded scripts and assets into res://)
	_mount_mod_packs()
	# 1. Load vanilla game data
	_scan_directory_for_json(BASE_DATA_PATH + "Traits", _load_trait_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Names", _load_name_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Modifiers", _load_modifier_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Weapons", _load_weapon_data)
	_scan_directory_for_json(BASE_DATA_PATH + "Events", _load_events)
	
	# 1b. Load vanilla Sect data
	_scan_directory_for_json(BASE_DATA_PATH + "Sects", _load_premade_sects)
	_scan_directory_for_json(BASE_DATA_PATH + "Laws", _load_sect_laws)
	_scan_directory_for_json(BASE_DATA_PATH + "Buildings", _load_buildings)
	_scan_directory_for_json(BASE_DATA_PATH + "Tenets", _load_tenets)
	_scan_directory_for_json(BASE_DATA_PATH + "SectNames", _load_sect_names)
	
	# 1c. Load Map data
	_scan_directory_for_json(BASE_DATA_PATH + "Map", _load_map_data)
	
	# 2. Load modded data (overwrites vanilla IDs or adds new ones)
	_scan_directory_for_json(MOD_DATA_PATH + "Traits", _load_trait_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Names", _load_name_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Modifiers", _load_modifier_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Weapons", _load_weapon_data)
	_scan_directory_for_json(MOD_DATA_PATH + "Tenets", _load_tenets)
	_scan_directory_for_json(MOD_DATA_PATH + "SectNames", _load_sect_names)
	_scan_directory_for_json(MOD_DATA_PATH + "Events", _load_events)
	
	# 3. Load AI Logic Scripts 
	_scan_directory_for_scripts("res://Scripts/AI/Desires", _load_desire_script)
	_scan_directory_for_scripts("res://Scripts/AI/Actions", _load_action_script)
	_scan_directory_for_scripts("res://Scripts/AI/Directives", _load_directive_script)
	
	_validate_loaded_data()

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

#region Calculator Functions
# --- CALCULATOR FUNCTIONS ---

func get_total_stat_modifiers(trait_ids: Array[String], modifier_ids: Array[String], stat_enum: int) -> int:
	var total = 0
	var stat_name = Definitions.STAT_NAMES[stat_enum] # O(1), no allocations
	
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
			var trait_data = traits_registry[tid]
			var align_block = trait_data.get("alignment_modifiers", trait_data.get("personality_modifiers", {}))
			total += align_block.get(a_name, 0)
			
	for mid in modifier_ids:
		if modifiers_registry.has(mid):
			var mod_data = modifiers_registry[mid]
			var align_block = mod_data.get("alignment_modifiers", mod_data.get("personality_modifiers", {}))
			total += align_block.get(a_name, 0)
			
	return total
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
		dir.make_dir("Mods/Weapons")
		dir.make_dir("Mods/Sects")
		dir.make_dir("Mods/Laws")
		dir.make_dir("Mods/Buildings")
		dir.make_dir("Mods/Tenets")
		dir.make_dir("Mods/SectNames")
		dir.make_dir("Mods/Events")
		dir.make_dir("Mods/Map")

## Generic directory scanner that applies a specific loading Callable to each JSON found
func _scan_directory_for_json(path: String, load_func: Callable) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return # Directory doesn't exist yet, which is fine for empty mod folders
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "json":
			
			# Skip any file prefixed with "debug_" if this is a production build
			if file_name.begins_with("debug_") and not OS.is_debug_build():
				file_name = dir.get_next()
				continue
				
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

func _load_tenets(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		tenets_registry.merge(json.data, true)

func _load_sect_names(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_deep_merge_dict(sect_names_registry, data)

# --- NEW SECT LOADERS ---
func _load_premade_sects(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		premade_sects_registry.merge(json.data, true)

func _load_sect_laws(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		sect_laws_registry.merge(json.data, true)

func _load_buildings(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		buildings_registry.merge(json.data, true)

func _load_events(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		events_registry.merge(json.data, true)

func _load_map_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		printerr("DataManager: JSON parse error in map file: ", path)
		return
	var data = json.data
	if not (data is Dictionary):
		return
	# Detect whether this file contains regions or provinces by its "type" key,
	# or by the presence of known root keys.
	if data.has("regions"):
		for r_id in data["regions"]:
			regions_registry[r_id] = data["regions"][r_id]
	elif data.has("provinces"):
		for p_id in data["provinces"]:
			provinces_registry[p_id] = data["provinces"][p_id]
	else:
		# Flat dictionary: try to detect by first entry's keys
		for key in data:
			var entry = data[key]
			if entry is Dictionary:
				if entry.has("culture"):
					regions_registry[key] = entry
				elif entry.has("region_id"):
					provinces_registry[key] = entry

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


#region Validation

const _KNOWN_EVENT_EFFECT_TYPES := {
	"add_trait": true,
	"modify_wealth": true,
	"modify_sect_wealth": true,
	"modify_stat": true,
	"modify_realm": true,
	"kill_character": true,
	"recruit_member": true,
	"assign_directive": true,
	"set_war_state": true,
	"add_memory": true,
	"trigger_event": true,
	"add_personal_log": true,
	"modify_sect_relationship": true,
	"add_world_log": true
}

func _validate_loaded_data() -> void:
	_validate_traits_registry()
	_validate_modifiers_registry()
	_validate_events_registry()

func _validate_traits_registry() -> void:
	for trait_id in traits_registry.keys():
		var trait_data: Dictionary = traits_registry[trait_id]
		
		_validate_stat_block_keys(
			trait_data.get("stat_modifiers", {}),
			"trait",
			trait_id,
			"stat_modifiers"
		)
		
		_validate_martial_block_keys(
			trait_data.get("martial_modifiers", {}),
			"trait",
			trait_id,
			"martial_modifiers"
		)
		
		_validate_personality_alignment_block_keys(
			trait_data.get("personality_modifiers", {}),
			"trait",
			trait_id,
			"personality_modifiers"
		)
		
		_validate_personality_alignment_block_keys(
			trait_data.get("alignment_modifiers", {}),
			"trait",
			trait_id,
			"alignment_modifiers"
		)

func _validate_modifiers_registry() -> void:
	for mod_id in modifiers_registry.keys():
		var mod_data: Dictionary = modifiers_registry[mod_id]
		
		_validate_stat_block_keys(
			mod_data.get("stat_modifiers", {}),
			"modifier",
			mod_id,
			"stat_modifiers"
		)
		
		_validate_martial_block_keys(
			mod_data.get("martial_modifiers", {}),
			"modifier",
			mod_id,
			"martial_modifiers"
		)
		
		_validate_personality_alignment_block_keys(
			mod_data.get("personality_modifiers", {}),
			"modifier",
			mod_id,
			"personality_modifiers"
		)
		
		_validate_personality_alignment_block_keys(
			mod_data.get("alignment_modifiers", {}),
			"modifier",
			mod_id,
			"alignment_modifiers"
		)

func _validate_events_registry() -> void:
	for event_id in events_registry.keys():
		var event_data: Dictionary = events_registry[event_id]
		
		# Root effects
		_validate_effect_array(event_data.get("effects", []), event_id, "root.effects")
		
		# Option effects
		var options: Dictionary = event_data.get("options", {})
		for opt_id in options.keys():
			var opt_data: Dictionary = options[opt_id]
			_validate_effect_array(opt_data.get("effects", []), event_id, "options.%s.effects" % opt_id)

func _validate_effect_array(effects: Array, event_id: String, path: String) -> void:
	for i in range(effects.size()):
		var effect: Dictionary = effects[i]
		var effect_type: String = effect.get("type", "")
		if effect_type == "" or not _KNOWN_EVENT_EFFECT_TYPES.has(effect_type):
			push_warning("DataManager Validation: Unknown event effect type '%s' in event '%s' at %s[%d]." % [effect_type, event_id, path, i])

func _validate_stat_block_keys(block: Dictionary, data_type: String, data_id: String, block_name: String) -> void:
	for key in block.keys():
		if Definitions.get_stat_enum(String(key)) == -1:
			push_warning("DataManager Validation: Invalid %s key '%s' in %s '%s' (%s)." % [block_name, key, data_type, data_id, block_name])

func _validate_martial_block_keys(block: Dictionary, data_type: String, data_id: String, block_name: String) -> void:
	for key in block.keys():
		if Definitions.get_martial_enum(String(key)) == -1:
			push_warning("DataManager Validation: Invalid %s key '%s' in %s '%s' (%s)." % [block_name, key, data_type, data_id, block_name])

func _validate_personality_alignment_block_keys(block: Dictionary, data_type: String, data_id: String, block_name: String) -> void:
	for key in block.keys():
		var k := String(key)
		var is_valid = (k in Definitions.PERSONALITY_STATS) or (k in Definitions.ALIGNMENT_STATS)
		if not is_valid:
			push_warning("DataManager Validation: Invalid %s key '%s' in %s '%s' (%s)." % [block_name, key, data_type, data_id, block_name])

#endregion
