extends Desire

func _init() -> void:
	id = "desire_social_discussion"

func evaluate(character: CharacterData) -> float:
	var social_need = character.needs.get("socialization", 0.0)
	var loneliness = character.state_vars.get("loneliness", 0.0)
	
	# The drive is a combination of the raw need and the emotional loneliness
	var total_drive = (social_need + loneliness) / 2.0
	
	if total_drive < 20.0:
		return 0.0 
		
	var sociability = character.get_personality_value("sociability")
	
	# Extroverts multiply the score, introverts diminish it
	var personality_mult = 0.2 + (sociability / 100.0 * 1.5)
	
	return total_drive * personality_mult

func generate_action(_character: CharacterData) -> ActionPlan:
	# A conversation usually takes a portion of a day, so we map it to 1 tick
	var duration = 1
	return DataManager.create_action("action_social_discussion", duration)
