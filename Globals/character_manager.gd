extends Node

signal character_spawned(character: Node)

var char_ids: Dictionary = {}
var char_id_counter: int = 1
var active_characters: Dictionary = {} # Key: char_id, Value: CharacterData

func _ready() -> void:
	pass

# Public: generate and reserve a unique char id (returns -1 on failure)
func get_new_char_id() -> int:
	var char_id: int
	char_id = char_id_counter
	char_id_counter += 1
	return char_id

# Public: register a spawned character (stores CharacterData in active_characters)
# Expects the node to have a 'Data' child of type CharacterData or a direct CharacterData reference.
func register_character(character_node: Node) -> void:
	var data = character_node.get_node_or_null("Data")
	active_characters[data.char_id] = data
	emit_signal("character_spawned", character_node)

# Public high-level helper that combines factory create + register
# params is an optional Dictionary to send creation overrides (future-proof)
func spawn_new_character(params: Dictionary = {}) -> Node:
	var new_id = get_new_char_id()

	var char_node = CharacterFactory.create_character(new_id, params)
	if not char_node:
		push_error("Factory failed to create character.")
		return null

	register_character(char_node)
	return char_node
