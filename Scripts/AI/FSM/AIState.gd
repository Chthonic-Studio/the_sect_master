# AIState.gd
# Base class for all AI states in the FSM.
# Defines the common interface for states.

class_name AIState extends Node

var fsm: UtilityAI # A reference to the state machine (UtilityAI node)

# Called by the FSM when this state is entered.
func enter() -> void:
	pass # Override in child states

# Called by the FSM every frame while this state is active.
func process_state(delta: float) -> void:
	pass # Override in child states

# Called by the FSM when this state is exited.
func exit() -> void:
	pass # Override in child states
