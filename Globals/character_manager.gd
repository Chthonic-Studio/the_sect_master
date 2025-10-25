extends Node

signal character_spawned(character: Node)

var char_ids: Dictionary = {}
var active_characters: Dictionary = {} # Key: char_id, Value: CharacterData

# Utility: Ensures unique IDs
func _generate_unique_char_id() -> int:
	var tries := 0
	while tries < 10000:
		var candidate := randi()
		if not char_ids.has(candidate):
			return candidate
		tries += 1
	push_error("Failed to generate unique char_id.")
	return -1
