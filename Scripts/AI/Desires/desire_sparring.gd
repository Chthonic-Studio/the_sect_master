extends Desire

## Active when the sect has a sparring arena (injected via "sparring" ai_tag on building complete).

func _init() -> void:
	id = "desire_sparring"
	ai_tags = ["sparring"]

func evaluate(character: CharacterData) -> float:
	if not character.is_martial_artist:
		return 0.0
	
	# Base score from the training need
	var training_need = character.needs.get("training", 0.0)
	if training_need < 20.0:
		return 0.0
	
	var score = (training_need / 100.0) * 60.0
	
	# Disciplined characters prioritize structured training
	var discipline = character.get_personality_value("discipline")
	if discipline > 65:
		score *= 1.5
	
	# Avoid spamming — apply a cooldown
	var last_spar = character.action_cooldowns.get("desire_sparring", -999)
	var current_day = TimeManager.get_total_days_elapsed()
	if current_day - last_spar < 3:
		return 0.0
	
	return score

func generate_action(character: CharacterData) -> ActionPlan:
	character.action_cooldowns["desire_sparring"] = TimeManager.get_total_days_elapsed()
	return DataManager.create_action("action_spar", 3)
