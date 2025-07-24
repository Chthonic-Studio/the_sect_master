# SocializeAction.gd

extends UtilityActionResource
class_name SocializeAction

@export var min_duration: float = 4.0
@export var max_duration: float = 8.0

func start_action(character: Node) -> void:
	_start_timer(min_duration, max_duration)

func end_action(character: Node) -> void:
	super.end_action(character)
	var res = character.character_resource
	if res:
		print("%s finished socializing." % res.name_display)
