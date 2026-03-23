extends Desire

func _init() -> void:
	id = "desire_rest"

func evaluate(character: CharacterData) -> float:
	var fatigue = character.state_vars.get("fatigue", 0.0)
	
	# If fatigue is low, we don't want to sleep.
	if fatigue < 30.0:
		return 0.0
		
	# The more fatigued they are, the exponentially higher the score.
	# At 100 fatigue, this will score around 100, overriding almost everything else.
	var score = (fatigue / 100.0) * 100.0
	
	# Diligent characters might push themselves further before sleeping
	var discipline = character.get_personality_value("discipline") # 0 to 100
	if discipline > 70:
		score *= 0.8 
		
	return score

func generate_action(character: CharacterData) -> ActionPlan:
	# Sleep duration depends on how tired they are (roughly 1 day of sleep per 30 fatigue)
	var fatigue = character.state_vars.get("fatigue", 0.0)
	var duration = maxi(1, int(fatigue / 30.0))
	return DataManager.create_action("action_rest", duration)
