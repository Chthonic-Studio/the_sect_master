# UtilityDesireResource.gd
# Abstract base for all character desires in Utility AI system.
# Extend for concrete desires (Eat, Train, etc).

class_name UtilityDesireResource extends Resource

@export var desire_name: String = "" # Used for action mapping and debug

# Returns a utility value (float) for this desire, given character state
# Child classes (EatDesire, TrainingDesire) will override this.
func get_utility(character: Node) -> float:
	# This function should be overridden in child classes like EatDesire.
	return 0.0

# This function wraps the desire's logic with the modifier calculation.
func get_final_utility(character: Node) -> float:
	# 1. Get the base utility from the specific desire's logic (e.g., how hungry they are).
	var base_utility = get_utility(character)

	# 2. Get the character's current modifier for this desire (e.g., how "satiated" they are).
	var res = character.character_resource
	if not res:
		return base_utility

	# 3. Retrieve the specific modifier. A positive value means they want to do it more,
	# a negative value means they just did it and want to do it less.
	var modifier = res.desire_modifiers.get(desire_name, 0.0)

	# 4. Add the modifier to the base utility. The result cannot be negative.
	var final_utility = max(0, base_utility + modifier)
	
	return final_utility
