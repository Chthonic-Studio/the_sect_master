extends ActionPlan

## Executes the work shift, calculating economic output based on the character's tags.

func _init(duration: int = 1) -> void:
	super(duration)
	id = "action_profession"

func process_tick(character: CharacterData) -> void:
	# Working is tiring
	character.state_vars["fatigue"] = minf(100.0, character.state_vars.get("fatigue", 0.0) + 15.0)
	
	# Satisfies the work need aggressively
	character.needs["work"] = maxf(0.0, character.needs.get("work", 0.0) - 25.0)
	
	# Calculate daily economic output based on their specific profession tag
	var income = 0
	
	if character.ai_tags.has("merchant"):
		income = randi_range(5, 20)
		# Merchants might organically increase their socialization need
		character.needs["socialization"] = maxf(0.0, character.needs.get("socialization", 0.0) - 5.0)
		
	elif character.ai_tags.has("blacksmith"):
		income = randi_range(10, 15)
		# Hard labor adds extra fatigue
		character.state_vars["fatigue"] = minf(100.0, character.state_vars.get("fatigue", 0.0) + 5.0)
		
	elif character.ai_tags.has("beggar"):
		income = randi_range(0, 3)
		# Beggars suffer hits to comfort and mood
		character.state_vars["comfort"] = maxf(0.0, character.state_vars.get("comfort", 50.0) - 2.0)
		
	else:
		# Generic peasant/laborer
		income = randi_range(1, 5)
		
	character.wealth += income

func on_complete(character: CharacterData) -> void:
	# Small chance for an organic life event upon finishing a work week
	if randf() < 0.05:
		# e.g., A merchant finds a strange artifact, a peasant finds a low-grade spirit stone
		pass 
