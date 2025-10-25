extends Node

@export var name_pool: NamePoolDef = preload("res://Resources/Characters/name_pool.tres")
@export var root_spawn_table: RootSpawnTableDef = preload("res://Resources/Characters/root_table_def.tres")
@export var default_definition: CharacterDefinition = preload("res://Resources/Characters/base_character_definition.tres")

@export var character_scene: PackedScene = preload("res://Scenes/character.tscn")

func generate_new_character() -> Char:
	var new_def: CharacterDefinition = default_definition.duplicate() as CharacterDefinition
	
	var selected_gender = [
		CharacterDefinition.Gender.MALE, 
		CharacterDefinition.Gender.FEMALE
	][randi() % 2]
	new_def.char_gender = selected_gender
	
	var selected_root = root_spawn_table.get_random_root()
	new_def.spiritual_root = selected_root

	var first_name = name_pool.get_random_first_name(selected_gender)
	var last_name = name_pool.get_random_last_name()
	new_def.char_last_name = last_name
	new_def.char_first_name = first_name
	new_def.char_fullname = last_name + " " + first_name # Chinese Naming Convention

	var character_instance = character_scene.instantiate()
	
	# --- FIX: Access Data node directly ---
	var data_node = character_instance.get_node("Data") as CharacterData
	data_node.char_definition = new_def
	data_node.char_id = randi()
	
	# Cultivation initialization, same fix
	var cultivation_node = character_instance.get_node("Cultivation")
	cultivation_node.initialize_cultivation(new_def.cultivation_path)
	
	return character_instance
