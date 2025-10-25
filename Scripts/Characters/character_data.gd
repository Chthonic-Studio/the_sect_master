extends Node
class_name CharacterData

## --- Dynamic System Values ---
@export_category("System Values (Dynamic)")
## A character's unique ID, generated at spawn
@export var char_id: int = -1 

## The Definition Resource to pull initial values from
@export var char_definition: CharacterDefinition 

@export var char_age: int = 5
@export var potential: int = 1
@export var current_hp: int = 100 
@export var current_stamina: int = 100

## Reference to the character's progression state
@export var cultivation_state: CultivationState 

## --- Current Attributes (Dynamic Runtime Values) ---
# NOTE: In a production environment, you might use a Dictionary to store these dynamically, 
# but for clarity, we use individual variables matching the Definition.

# ... (Declare all 17 combat/personality stats here, but DO NOT use @export)
var strength: int
var constitution: int
# ... and so on for all 17 stats ...

var active_traits: Array[CharacterTrait] = []


func _ready() -> void:
	if char_definition:
		# Initialize dynamic stats from the static definition
		_initialize_from_definition()
		# Ensure a unique ID is assigned if not loaded from a save
		if char_id == -1:
			char_id = randi() # Placeholder: Replace with a proper ID generation system

func _initialize_from_definition() -> void:
	# Set the current, dynamic stats to the initial values from the static Definition
	strength = char_definition.strength
	constitution = char_definition.constitution
	# ... set all 17 stats similarly ...
	active_traits.append_array(char_definition.starting_traits)
	# The character's age and potential will start at their initial values or be set by the spawner


func get_stat(stat_name: String) -> int:
	# Use a dictionary or 'match' statement for safe access in GDScript
	match stat_name:
		"strength": return strength
		"morality": return morality
		# ... and so on for all 17 stats ...
		_: 
			push_error("Attempted to access non-existent stat: " + stat_name)
			return 0
			
func modify_stat(stat_name: String, amount: int) -> void:
	# Logic for modifying a stat, ensuring range limits (e.g., clamp(-100, 100))
	# ... update the relevant stat and potentially fire signals ...
	pass
