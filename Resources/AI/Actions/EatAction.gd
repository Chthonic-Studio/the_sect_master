# EatAction.gd

extends UtilityActionResource
class_name EatAction

@export var min_duration: float = 1.0
@export var max_duration: float = 2.0

func can_perform(character: Node) -> bool:
	return true

func start_action(character: Node) -> void:
	print("Starting EatAction with min_duration: %.2f, max_duration: %.2f" % [min_duration, max_duration])
	_start_timer(min_duration, max_duration)

func end_action(character: Node) -> void:
	super.end_action(character)

	var res = character.character_resource
	if res:
		var heal_amount = res.max_hp * 0.25
		res.current_hp = clamp(res.current_hp + heal_amount, 0, res.max_hp)
		print("%s finished eating. HP is now %d/%d." % [res.name_display, res.current_hp, res.max_hp])
		# This is a duplicate print statement.
		print("%s finished eating. HP is now %d." % [res.name_display, res.current_hp])
