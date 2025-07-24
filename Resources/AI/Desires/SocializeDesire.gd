# SocializeDesire.gd
# The desire to interact with other characters.

extends UtilityDesireResource
class_name SocializeDesire

func get_utility(character: Node) -> float:
	var res = character.character_resource
	if not res:
		return 0.0
	
	# Base desire to be around others.
	var base_desire = 5.0
	
	# Sociable characters (high Charisma, high Empathy) have a stronger desire to socialize.
	var charisma_mod = res.charisma / 10.0 # Range: -10 to 10
	var empathy_mod = res.empathy / 20.0   # Range: -5 to 5
	
	var desire_score = base_desire + charisma_mod + empathy_mod
	return max(0.0, desire_score)
