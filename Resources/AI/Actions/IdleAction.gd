# IdleAction.gd

extends UtilityActionResource
class_name IdleAction

@export var min_duration: float = 2.0
@export var max_duration: float = 5.0

func can_perform(character: Node) -> bool:
	return true

func start_action(character: Node) -> void:
	_timer = randf_range(min_duration, max_duration)
	emit_signal("action_started", action_name)
