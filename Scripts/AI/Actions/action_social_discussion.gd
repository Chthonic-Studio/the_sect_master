extends ActionPlan

func _init(duration: int = 1) -> void:
	super(duration)
	id = "action_social_discussion"

func process_tick(character: CharacterData) -> void:
	# Note: This is currently mocked as a solo stat-reduction. 
	# Later, this action will require finding a valid target via a Blackboard system.
	
	character.needs["socialization"] = maxf(0.0, character.needs.get("socialization", 0.0) - 40.0)
	character.state_vars["loneliness"] = maxf(0.0, character.state_vars["loneliness"] - 50.0)
	
	# Talking also slightly satisfies entertainment
	character.needs["entertainment"] = maxf(0.0, character.needs.get("entertainment", 0.0) - 10.0)

func on_complete(_character: CharacterData) -> void:
	pass
