extends Node
class_name CharacterAI

# Reference to the character's State and Controller
var data: CharacterData
var controller: Char

func _ready() -> void:
	# Get references to siblings/parent
	CharacterManager.spawn_new_character()
