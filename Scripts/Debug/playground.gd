extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("test_char_creation")
	
	print("Playground ready calls for spawned new char")

func test_char_creation() -> void:
	CharacterManager.spawn_new_character()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
