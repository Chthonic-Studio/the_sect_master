extends Desire

## Drives non-martial characters to perform their daily jobs.

func _init() -> void:
	id = "desire_profession"
	ai_tags = ["peasant", "merchant", "blacksmith", "beggar", "worker"]
	is_macro = false

func evaluate(character: CharacterData) -> float:
	var work_need = character.needs.get("work", 0.0)
	var fatigue = character.state_vars.get("fatigue", 0.0)
	
	# If they are exhausted, the desire to work plummets
	if fatigue > 80.0:
		return 0.0
		
	var ambition = character.get_personality_value("ambition")
	var greed = character.get_personality_value("greed")
	
	# Greedy and ambitious characters will prioritize work heavily over socializing or resting
	var personality_mult = 0.5 + ((ambition + greed) / 200.0)
	
	# Fatigue slowly drains the motivation to work
	var fatigue_penalty = 1.0 - (fatigue / 100.0)
	
	return work_need * personality_mult * fatigue_penalty

func generate_action(_character: CharacterData) -> ActionPlan:
	# A work shift lasts a few days
	var duration = randi_range(2, 5)
	return DataManager.create_action("action_profession", duration)
