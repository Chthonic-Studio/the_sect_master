# UtilityDesireResource.gd
# Abstract base for all character desires in Utility AI system.
# Extend for concrete desires (Eat, Train, etc).

extends Resource
class_name UtilityDesireResource

@export var desire_name: String = "" # Used for action mapping and debug

# Returns a utility value (float) for this desire, given character state
func get_utility(character: Node) -> float:
	return 0.0 # Override in child classes
