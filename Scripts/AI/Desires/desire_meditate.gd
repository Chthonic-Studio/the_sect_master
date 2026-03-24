extends Desire

func _init() -> void:
	id = "desire_meditate"

func evaluate(character: CharacterData) -> float:
	var fatigue = character.state_vars.get("fatigue", 0.0)
	
	if fatigue > 70.0:
		return 0.0 # Too tired to meditate safely
		
	var training_need = character.needs.get("training", 0.0)
	
	# Personality acts as a multiplier to the need, not a flat base score.
	# High ambition makes them care MORE about their training need.
	var ambition = character.get_personality_value("ambition")
	var discipline = character.get_personality_value("discipline")
	var personality_mult = 0.5 + ((ambition + discipline) / 200.0) # Ranges from ~0.5 to ~1.5
	
	# If training_need is 0 (satiated), score is 0. They will stop meditating!
	var score = training_need * personality_mult
	
	# Fatigue slowly reduces the appeal of training
	score *= (1.0 - (fatigue / 100.0))
	
	return score

func generate_action(_character: CharacterData) -> ActionPlan:
	var duration = randi_range(3, 7)
	return DataManager.create_action("action_meditate", duration)
