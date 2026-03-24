extends ActionPlan

func _init(duration: int = 1) -> void:
	super(duration)
	id = "action_idle"

func process_tick(character: CharacterData) -> void:
	# Idling slightly reduces stress and fatigue over time
	character.state_vars["stress"] = maxf(0.0, character.state_vars["stress"] - 5.0)
	character.state_vars["fatigue"] = maxf(0.0, character.state_vars["fatigue"] - 2.0)
	
	# Slowly builds up the need for entertainment or socialization
	character.needs["entertainment"] = minf(100.0, character.needs.get("entertainment", 0.0) + 5.0)

func on_complete(_character: CharacterData) -> void:
	# Just naturally terminates so the Brain can re-evaluate
	pass
