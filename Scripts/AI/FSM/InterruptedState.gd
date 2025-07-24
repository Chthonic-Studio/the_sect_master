# InterruptedState.gd
# The AI is paused, typically by an external event like dialogue or a direct player command.
# It waits until it is told to resume.

class_name InterruptedState extends AIState

var can_resume_previous_action := false

func enter() -> void:
	super.enter()
	# When interrupted, we check if the action we were doing is resumable.
	# For now, we'll assume most actions are not, but this can be expanded later.
	# e.g., a Crafting action might be resumable, but a social chat might not.
	if fsm.current_action:
		# Let's add a property to actions later if needed, e.g., `is_resumable`
		can_resume_previous_action = false 
	else:
		can_resume_previous_action = false


func resume() -> void:
	# This function is called externally to exit the interrupted state.
	if can_resume_previous_action and fsm.current_action:
		# If we can resume, go back to performing the action.
		fsm.change_state("PerformingAction")
	else:
		# Otherwise, clear the old action and choose a new one.
		fsm.current_action = null
		fsm.change_state("ChoosingAction")
