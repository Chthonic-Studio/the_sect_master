# EatDesire.gd

extends UtilityDesireResource
class_name EatDesire

# The desire to eat is now a combination of physical need and personal appetite.
func get_utility(character: Node) -> float:
	var res = character.character_resource
	if not res:
		return 0.0

	# 1. Base Desire: A small, constant value so eating is always an option.
	var base_desire = 10.0

	# 2. Appetite Modifier: Strong and hardy characters have a bigger appetite.
	var appetite_mod = (res.strength / 10.0) + (res.constitution / 10.0) # Range: -20 to 20

	# 3. Hunger Modifier: The need to eat increases as health is lost.
	var hunger_mod = 0.0
	if res.max_hp > 0:
		var health_ratio = float(res.current_hp) / res.max_hp
		# This component can be up to 50 points when near death.
		hunger_mod = (1.0 - health_ratio) * 50.0

	# The final base utility is the sum of these factors.
	var desire_score = base_desire + appetite_mod + hunger_mod
	return max(0.0, desire_score)
