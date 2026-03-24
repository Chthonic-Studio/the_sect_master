extends ActionPlan

func _init(duration: int = 1) -> void:
	super(duration)
	id = "action_birdwatching"

func process_tick(character: CharacterData) -> void:
	# Going out adds a tiny bit of fatigue but massively reduces boredom
	character.state_vars["fatigue"] = minf(100.0, character.state_vars["fatigue"] + 2.0)
	
	character.needs["entertainment"] = maxf(0.0, character.needs.get("entertainment", 0.0) - 30.0)
	character.needs["exploration"] = maxf(0.0, character.needs.get("exploration", 0.0) - 20.0)

func on_complete(_character: CharacterData) -> void:
	pass
