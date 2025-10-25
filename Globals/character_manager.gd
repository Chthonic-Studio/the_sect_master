extends Node

var char_ids: Dictionary


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func append_char_id( char_id: int ) -> bool:
	if char_ids.has(char_id):
		# Match found, ID is already present.
		return false
	else:
		# No match. Add the ID as a key. 
		char_ids[char_id] = true
		return true
