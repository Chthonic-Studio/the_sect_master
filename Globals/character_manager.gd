extends Node

var char_ids: Dictionary
# Global Dictionary: The single source of truth for all characters
var active_characters: Dictionary = {} # Key: char_id, Value: CharacterData (Node)

# A persistent parent node that exists outside of the scene tree (e.g., the root of the CharacterManager itself)

func spawn_new_sect_member() -> Character:
	var new_character_node: Character = factory.generate_new_character()	
	var persistent_data: CharacterData = new_character_node.data
	active_characters[persistent_data.char_id] = persistent_data
	
	var new_character_data: CharacterData = factory.generate_new_character_data()
	active_characters[new_character_data.char_id] = new_character_data
	return new_character_data

func append_char_id( char_id: int ) -> bool:
	if char_ids.has(char_id):
		# Match found, ID is already present.
		return false
	else:
		# No match. Add the ID as a key. 
		char_ids[char_id] = true
		return true
