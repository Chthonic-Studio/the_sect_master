extends Node2D
class_name Char

# Internal references to the child nodes
@onready var data: Character = $Data
@onready var ai: CharacterAI = $AI
@onready var cultivation: Cultivation = $Cultivation

func _ready() -> void:
	if not data or not ai:
		push_error("Character scene is missing required 'Data' or 'AI' child nodes.")
		set_process(false)
		return

## PUBLIC API for external systems (e.g., the player or a mission manager)

# Physics movement loop
func _physics_process(delta: float) -> void:
	# The CharacterAI will typically set the 'velocity' or 'target'
	# We apply physics based on the CharacterData's strength or agility if needed.
	pass
