# EatAction.gd

extends UtilityActionResource
class_name EatAction

@export var min_duration: float = 1.0
@export var max_duration: float = 2.0

func can_perform(character: Node) -> bool:
	# Example: Only allow if character has food resource or is hungry
	return true # Add logic as needed

func start_action(character: Node) -> void:
	_timer = randf_range(min_duration, max_duration)
	emit_signal("action_started", action_name)

func end_action(character: Node) -> void:
	# Example: Restore HP/Qi or update food stat
	pass
