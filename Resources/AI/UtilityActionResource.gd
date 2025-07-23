# UtilityActionResource.gd
# Abstract base for all character actions in Utility AI system.
# Extend for concrete actions (Eat, Meditate, Idle, etc).

extends Resource
class_name UtilityActionResource

signal action_started(action_name)
signal action_completed(action_name)

@export var action_name: String = "" # Name used for desire/action mapping and debug


var _timer := 0.0

# Returns true if this action can be performed by the character
func can_perform(character: Node) -> bool:
	return true # Override for specific requirements

# Called when action ends
func end_action(character: Node) -> void:
	pass # Override for cleanup
