# TrainingDesire.gd

extends UtilityDesireResource
class_name TrainingDesire


func get_utility(character: Node) -> float:
	# Example: Higher utility if potential is high
	if character.character_resource.potential:
		return float(character.character_resource.potential)
	return 0.0
