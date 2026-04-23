extends ActionPlan

func _init(duration: int = 3) -> void:
	super(duration)
	id = "action_spar"

func process_tick(character: CharacterData) -> void:
	# Training is physically demanding
	character.state_vars["fatigue"] = minf(100.0, character.state_vars.get("fatigue", 0.0) + 18.0)
	
	# Satisfies the training need
	character.needs["training"] = maxf(0.0, character.needs.get("training", 0.0) - 30.0)
	character.needs["socialization"] = maxf(0.0, character.needs.get("socialization", 0.0) - 8.0)

func on_complete(character: CharacterData) -> void:
	character.add_log("Spent time sparring on the training ground.")
