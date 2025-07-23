# MeditateAction.gd

extends UtilityActionResource
class_name MeditateAction

@export var min_duration: float = 3.0
@export var max_duration: float = 7.0

func can_perform(character: Node) -> bool:
	return true

func start_action(character: Node) -> void:
	_timer = randf_range(min_duration, max_duration)
	emit_signal("action_started", action_name)
