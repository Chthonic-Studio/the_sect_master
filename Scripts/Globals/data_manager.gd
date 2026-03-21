extends Node

# --- REGISTRIES (The "Rules") ---
var traits_registry: Dictionary = {}
var personalities_registry: Dictionary = {}
var name_pools: Dictionary = {}

# --- REPOSITORIES (The "Living Entities") ---
var character_repo: Dictionary = {} 

# --- PERSISTENCE COUNTERS ---
# This ensures every character ever created gets a unique, incremental ID.
# This value MUST be saved and loaded to prevent ID reuse in a saved game.
var next_char_id: int = 1

# --- INITIALIZATION ---
func _ready() -> void:
	load_all_data()

func load_all_data() -> void:
	_load_json_to_registry("res://data/traits.json", traits_registry)
	_load_json_to_registry("res://data/personalities.json", personalities_registry)
	_load_names_pool("res://data/names.json")

func _load_json_to_registry(path: String, target_dict: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		printerr("DataManager: File not found at ", path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)
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

# --- CHARACTER REPO MANAGEMENT ---

func register_character(char_data: CharacterData) -> void:
	if char_data.char_id == "":
		char_data.char_id = _generate_sequential_id()
	character_repo[char_data.char_id] = char_data

## Guarantees uniqueness by using a simple counter.
func _generate_sequential_id() -> String:
	var id = "char_" + str(next_char_id)
	next_char_id += 1
	return id

func get_character(char_id: String) -> CharacterData:
	return character_repo.get(char_id, null)

# --- CALCULATOR FUNCTIONS ---

func get_trait_modifiers_for_stat(trait_ids: Array[String], stat_enum: int) -> int:
	var total_mod = 0
	var stat_name = Definitions.Stat.keys()[stat_enum].to_lower()
	for tid in trait_ids:
		if traits_registry.has(tid):
			var trait_data = traits_registry[tid]
			if trait_data.has("stat_modifiers"):
				total_mod += trait_data["stat_modifiers"].get(stat_name, 0)
	return total_mod

func get_trait_modifiers_for_personality(trait_ids: Array[String], p_name: String) -> int:
	var total_mod = 0
	for tid in trait_ids:
		if traits_registry.has(tid):
			var trait_data = traits_registry[tid]
			if trait_data.has("personality_modifiers"):
				total_mod += trait_data["personality_modifiers"].get(p_name, 0)
	return total_mod

# --- SAVE/LOAD LOGIC ---

func get_save_data() -> Dictionary:
	var characters_dict = {}
	for char_id in character_repo:
		characters_dict[char_id] = character_repo[char_id].to_dictionary()
	
	return {
		"next_char_id": next_char_id, # CRITICAL: Save the counter state
		"characters": characters_dict
	}

func load_save_data(save_data: Dictionary) -> void:
	character_repo.clear()
	
	# Restore the counter so new characters don't overwrite old IDs
	next_char_id = save_data.get("next_char_id", 1)
	
	var all_char_data = save_data.get("characters", {})
	for char_id in all_char_data:
		var new_char = CharacterData.new()
		new_char.from_dictionary(all_char_data[char_id])
		character_repo[char_id] = new_char
