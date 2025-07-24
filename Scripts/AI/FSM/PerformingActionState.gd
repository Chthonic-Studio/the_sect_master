# PerformingActionState.gd
# The character is actively executing the chosen action.

class_name PerformingActionState extends AIState

func enter() -> void:
	super.enter()
	if fsm.current_action:
		fsm.current_action.init()
		fsm.current_action.start_action(fsm.character)
		fsm.emit_signal("action_changed", fsm.current_action.action_name)

func process_state(delta: float) -> void:
	if not fsm.current_action:
		fsm.change_state("Idle")
		return

	var is_action_finished = fsm.current_action.process_action(fsm.character, delta)
	if is_action_finished:
		# Action is complete, apply effects and clean up.
		fsm.previous_action_name = fsm.current_action.action_name
		fsm.current_action.end_action(fsm.character)
		fsm.current_action = null
		
		# Transition back to Idle to decide what to do next.
		fsm.change_state("Idle")
