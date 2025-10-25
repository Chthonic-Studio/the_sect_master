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

func spawn_new_character() -> Char:
	var character_node: Char = CharacterFactory.generate_new_character()
	
	var data = character_node.data
	if not data:
		push_error("Character node missing 'data' property.")
		return null
	data.char_id = _generate_unique_char_id()
	char_ids[data.char_id] = true
	active_characters[data.char_id] = data
	
	# 3. Optional: Add to scene tree under a 'Characters' node or self
	if not character_node.get_parent():
		add_child(character_node)
	
	# 4. Emit signal for observers (UI, systems, etc.)
	emit_signal("character_spawned", character_node)
	
	return character_node # Node2D (Character), not CharacterData or Resource
