# WanderAction.gd
# A low-priority action for moving around aimlessly.

extends UtilityActionResource
class_name WanderAction

@export var min_duration: float = 3.0
@export var max_duration: float = 6.0

func start_action(character: Node) -> void:
	_start_timer(min_duration, max_duration)

func end_action(character: Node) -> void:
	super.end_action(character)
	var res = character.character_resource
	if res:
		print("%s finished wandering." % res.name_display)
