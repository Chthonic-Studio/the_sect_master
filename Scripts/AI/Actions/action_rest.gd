extends ActionPlan

func _init(duration: int = 1) -> void:
	super(duration)
	id = "action_rest"

func process_tick(character: CharacterData) -> void:
	# Sleeping massively reduces fatigue and stress
	character.state_vars["fatigue"] = maxf(0.0, character.state_vars["fatigue"] - 40.0)
	character.state_vars["stress"] = maxf(0.0, character.state_vars["stress"] - 15.0)
	
func on_complete(character: CharacterData) -> void:
	# Wake up refreshed
	if character.state_vars["fatigue"] <= 10.0:
		character.needs["rest"] = 0.0
