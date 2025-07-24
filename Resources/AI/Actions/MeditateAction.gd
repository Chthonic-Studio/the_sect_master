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
	# Call parent to apply cooldown.
	super.end_action(character)

	# Basic training can slightly increase stats over a long time.
	# For now, we'll just print a message.
	var res = character.character_resource
	if res:
		print("%s finished a basic training session." % res.name_display)
