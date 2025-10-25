extends Node
class_name CharacterAI

# Reference to the character's State and Controller
var data: CharacterData
var controller: Char

func _ready() -> void:
	# Get references to siblings/parent
	data = get_parent().get_node("Data") as CharacterData
	controller = get_parent() as Char
	
	if not data or not controller:
		push_error("CharacterAI requires 'Data' and 'Character' parent/sibling nodes.")
		set_process(false)
