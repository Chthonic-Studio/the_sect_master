# StudyDesire.gd
# The desire to read, research, or otherwise study.

extends UtilityDesireResource
class_name StudyDesire

func get_utility(character: Node) -> float:
	var res = character.character_resource
	if not res:
		return 0.0
		
	# Base desire to learn.
	var base_desire = 5.0
	
	# Curious and intelligent characters have a stronger desire to study.
	var curiosity_mod = res.curiosity / 10.0      # Range: -10 to 10
	var intelligence_mod = res.intelligence / 5.0 # Range: -20 to 20
	
	var desire_score = base_desire + curiosity_mod + intelligence_mod
	return max(0.0, desire_score)
