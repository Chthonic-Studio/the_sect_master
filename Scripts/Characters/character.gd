extends CharacterBody2D
class_name Char

# Internal references to the child nodes
@onready var data: CharacterData = $Data
@onready var ai: CharacterAI = $AI
@onready var cultivation: Cultivation = $Cultivation

func _ready() -> void:
	if not data or not ai:
		push_error("Character scene is missing required 'Data' or 'AI' child nodes.")
		set_process(false)
		return
		
	# Example of using the AI for initialization
	# ai.start_thinking()

## PUBLIC API for external systems (e.g., the player or a mission manager)

func start_cultivation() -> void:
	# Called by the AI or a player command
	print("Character %s starts cultivating." % data.char_definition.char_fullname)
	# The actual cultivation logic/scene change would start here.

# Physics movement loop
func _physics_process(delta: float) -> void:
	# The CharacterAI will typically set the 'velocity' or 'target'
	# We apply physics based on the CharacterData's strength or agility if needed.
	pass
