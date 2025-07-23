# MeditateAction.gd

extends UtilityActionResource
class_name MeditateAction

@export var min_duration: float = 3.0
@export var max_duration: float = 7.0

func can_perform(character: Node) -> bool:
	# A cultivator can always meditate.
	return character.character_resource is CultivatorResource

# This function now correctly overrides the parent's placeholder.
func start_action(character: Node) -> void:
	# It calls the parent's helper function with its own duration.
	_start_timer(min_duration, max_duration)

func end_action(character: Node) -> void:
	# Example effect: Restore some Qi when meditation finishes.
	var res = character.character_resource
	if res:
		res.current_qi = clamp(res.current_qi + 10, 0, res.max_qi)
		print("%s finished meditating. Qi is now %d." % [res.name_display, res.current_qi])
