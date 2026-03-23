extends Desire

func _init() -> void:
	id = "desire_birdwatching"

func evaluate(character: CharacterData) -> float:
	var entertainment_need = character.needs.get("entertainment", 0.0)
	
	if entertainment_need < 20.0:
		return 0.0 # Not bored enough to go out
		
	# Curious and calm characters are more drawn to quiet observation
	var curiosity = character.get_personality_value("curiosity")
	var ruthlessness = character.get_personality_value("ruthlessness")
	
	var personality_mult = 0.5 + (curiosity / 100.0)
	
	# Cruel/Ruthless characters find birdwatching incredibly boring
	if ruthlessness > 70:
		personality_mult *= 0.2
		
	var score = entertainment_need * personality_mult
	
	return score

func generate_action(_character: CharacterData) -> ActionPlan:
	var duration = randi_range(1, 2)
	return DataManager.create_action("action_birdwatching", duration)
