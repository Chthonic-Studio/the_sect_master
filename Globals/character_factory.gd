extends Node

@export var name_pool: NamePoolDef = preload("res://Resources/Characters/name_pool.tres")
@export var root_spawn_table: RootSpawnTableDef = preload("res://Resources/Characters/root_table_def.tres")
@export var default_definition: CharacterDefinition = preload("res://Resources/Characters/base_character_definition.tres")

@export var character_scene: PackedScene = preload("res://Scenes/character.tscn")

func generate_new_character() -> Character:
	var new_def: CharacterDefinition = default_definition.duplicate() as CharacterDefinition
	
	var selected_gender = [
		CharacterDefinition.Gender.MALE, 
		CharacterDefinition.Gender.FEMALE
	][randi() % 2]
	new_def.char_gender = selected_gender
	
	var selected_root = root_spawn_table.get_random_root()
	new_def.spiritual_root = selected_root

	# 3. Generate and Assign Names (Surname First)
	var first_name = name_pool.get_random_first_name(selected_gender)
	var last_name = name_pool.get_random_last_name()
	
	new_def.char_last_name = last_name
	new_def.char_first_name = first_name
	new_def.char_fullname = last_name + " " + first_name # Chinese Naming Convention

	# 4. Instantiate the Scene
	var character_instance = character_scene.instantiate()
	
	# 5. Inject the Configured Definition into the Data Component
	character_instance.data.char_definition = new_def
	
	# 6. Finalize Setup (e.g., set char_id, initialize cultivation)
	# The factory is responsible for giving the *initial* char_id
	character_instance.data.char_id = randi()
	
	# Initialization of sub-systems using the new_def
	character_instance.cultivation.initialize_cultivation(new_def.cultivation_path)
	
	return character_instance
