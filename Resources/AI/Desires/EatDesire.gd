# EatDesire.gd

extends UtilityDesireResource
class_name EatDesire


func get_utility(character: Node) -> float:
	# Example: Higher utility if HP/Qi is low, or a "hunger" stat
	if character.character_resource.current_hp:
		return 100.0 - float(character.character_resource.current_hp) # The lower the HP, the higher the desire
	return 0.0
