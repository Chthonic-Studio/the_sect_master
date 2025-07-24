# UtilityDesireResource.gd
# Abstract base for all character desires in Utility AI system.
# Extend for concrete desires (Eat, Train, etc).

extends Resource
class_name UtilityDesireResource

@export var desire_name: String = "" # Used for action mapping and debug

# Returns a utility value (float) for this desire, given character state
# Child classes (EatDesire, TrainingDesire) will override this.
func get_utility(character: Node) -> float:
	# This function should be overridden in child classes like EatDesire.
	return 0.0

# --- New Final Calculation Function ---
# This function wraps the desire's logic with the cooldown calculation.
func get_final_utility(character: Node) -> float:
	# 1. Get the base utility from the specific desire's logic.
	var base_utility = get_utility(character)

	# 2. Check for a cooldown on the character.
	var res = character.character_resource
	if not res:
		return base_utility

	# 3. Retrieve the specific cooldown for this desire.
	var cooldown_modifier = res.desire_cooldowns.get(desire_name, 0.0)

	# 4. Subtract the cooldown from the base utility. The result cannot be negative.
	var final_utility = max(0, base_utility - cooldown_modifier)
	
	return final_utility
