# StudyAction.gd

extends UtilityActionResource
class_name StudyAction

@export var min_duration: float = 5.0
@export var max_duration: float = 10.0

func start_action(character: Node) -> void:
	_start_timer(min_duration, max_duration)

func end_action(character: Node) -> void:
	super.end_action(character)
	var res = character.character_resource
	if res:
		# Future: Add a small bonus to intelligence or a related skill.
		print("%s finished studying." % res.name_display)
