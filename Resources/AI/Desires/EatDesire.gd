# EatDesire.gd

extends UtilityDesireResource
class_name EatDesire


func get_utility(character: Node) -> float:
	# The desire to eat is driven by the percentage of missing health.
	var res = character.character_resource
	if res and res.max_hp > 0:
		# Calculate the percentage of health remaining (0.0 to 1.0)
		var health_ratio = float(res.current_hp) / res.max_hp
		# The desire is the inverse of the health ratio, scaled to 0-100.
		# A character at 30% health will have a desire of 70.
		var desire_score = (1.0 - health_ratio) * 100
		return desire_score
	return 0.0
