# IdleAction.gd

extends UtilityActionResource
class_name IdleAction

@export var min_duration: float = 2.0
@export var max_duration: float = 5.0

func can_perform(character: Node) -> bool:
	return true

# This function now correctly overrides the parent's placeholder.
func start_action(character: Node) -> void:
	# It calls the parent's helper function with its own duration.
	_start_timer(min_duration, max_duration)
