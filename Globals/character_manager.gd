extends Node

signal character_spawned(character: Node)

var char_ids: Dictionary = {}
var active_characters: Dictionary = {} # Key: char_id, Value: CharacterData

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rng_inited: bool = false

func _ready() -> void:
	# Try to initialize RNG
	if not _rng_inited:
		_rng.randomize()
		_rng_inited = true

# Public: generate and reserve a unique char id (returns -1 on failure)
func get_new_char_id() -> int:
	var tries := 0
	while tries < 10000:
		var candidate := _rng.randi()
		if not char_ids.has(candidate):
			char_ids[candidate] = true
			return candidate
		tries += 1
	push_error("Failed to generate unique char_id.")
	return -1

# Public: register a spawned character (stores CharacterData in active_characters)
# Expects the node to have a 'Data' child of type CharacterData or a direct CharacterData reference.
func register_character(character_node: Node) -> void:
	var data = character_node.get_node_or_null("Data")
	active_characters[data.char_id] = data
	emit_signal("character_spawned", character_node)

# Public high-level helper that combines factory create + register
# params is an optional Dictionary to send creation overrides (future-proof)
func spawn_new_character(params: Dictionary = {}) -> Node:
	# Request a new unique id
	var new_id := get_new_char_id()
	if new_id == -1:
		return null

	var char_node = CharacterFactory.create_character(new_id, params)
	if not char_node:
		push_error("Factory failed to create character.")
		return null

	# Register and emit
	register_character(char_node)
	return char_node
