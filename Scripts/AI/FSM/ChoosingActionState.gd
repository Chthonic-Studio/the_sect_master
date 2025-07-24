# ChoosingActionState.gd
# The AI evaluates desires and selects the best action.
# This is where all the utility calculations happen.

class_name ChoosingActionState extends AIState

# A minimum score an action must have to be considered worth doing.
# Prevents characters from doing major actions for trivial desires.
const MIN_UTILITY_THRESHOLD = 20.0

func enter() -> void:
	super.enter()
	var best_action = _select_next_action()
	
	if best_action:
		# We found an action, now let's perform it.
		fsm.current_action = best_action.duplicate() # Create a unique instance
		fsm.change_state("PerformingAction")
	else:
		# This should be very rare, but as a safeguard, default to Idle.
		push_warning("AI for %s could not select ANY action, not even Idle." % fsm.character.character_resource.name_display)
		fsm.current_action = fsm.get_action_by_name("Idle").duplicate()
		fsm.change_state("PerformingAction")


# This logic is moved from the old UtilityAI._select_next_action()
func _select_next_action() -> UtilityActionResource:
	var best_utility := -INF
	var best_action_template: UtilityActionResource = null

	for desire in fsm.desires:
		var corresponding_action_template = fsm.get_action_by_name(desire.desire_name)
		if not corresponding_action_template:
			continue

		if not corresponding_action_template.can_perform(fsm.character):
			continue
			
		var utility_score = desire.get_final_utility(fsm.character)
		
		if utility_score > best_utility:
			best_utility = utility_score
			best_action_template = corresponding_action_template

	# --- DECISION LOGIC ---
	# If the best action isn't compelling enough, just wander around.
	if best_utility < MIN_UTILITY_THRESHOLD:
		# Check if Wander action exists, otherwise fall back to Idle.
		var wander_action = fsm.get_action_by_name("Wander")
		if wander_action:
			return wander_action
		else:
			return fsm.get_action_by_name("Idle")

	return best_action_template
