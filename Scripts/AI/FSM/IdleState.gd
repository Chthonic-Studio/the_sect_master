# IdleState.gd
# The default state. The character is waiting for a decision.
# This state immediately transitions to ChoosingAction.

class_name IdleState extends AIState

func enter() -> void:
	super.enter()
	# As soon as we are idle, we should decide what to do next.
	fsm.change_state("ChoosingAction")
