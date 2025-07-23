# EatAction.gd

extends UtilityActionResource
class_name EatAction

@export var min_duration: float = 1.0
@export var max_duration: float = 2.0

func can_perform(character: Node) -> bool:
	# For now, anyone can eat if they are not at full health.
	# Later, we could check for a food resource in their inventory.
	var res = character.character_resource
	return res and res.current_hp < res.max_hp

# This function now correctly overrides the parent's placeholder.
func start_action(character: Node) -> void:
	# It calls the parent's helper function with its own duration.
	_start_timer(min_duration, max_duration)

func end_action(character: Node) -> void:
	# Example effect: Restore some HP when eating finishes.
	var res = character.character_resource
	if res:
		res.current_hp = clamp(res.current_hp + 15, 0, res.max_hp)
		print("%s finished eating. HP is now %d." % [res.name_display, res.current_hp])
