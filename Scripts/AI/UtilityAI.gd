extends Node 
class_name UtilityAI

# Emitted when a new action is chosen, so the UI can update.
signal action_changed(new_action_name)

# An array of all possible actions this character can perform.
@export var actions: Array[UtilityActionResource] = []
# An array of all desires that drive this character's decisions.
@export var desires: Array[UtilityDesireResource] = []

# --- FSM State ---
var current_state: AIState
var states: Dictionary = {} # Stores references to the state nodes.

# --- AI Context ---
var current_action: UtilityActionResource = null # The action being performed.
var previous_action_name: String = "None"
var character: Node = null


func _ready() -> void:
	character = get_parent()
	
	# Setup the FSM by getting references to the child state nodes.
	# Assumes you have added Idle, ChoosingAction, PerformingAction, and Interrupted nodes as children.
	for child in get_children():
		if child is AIState:
			states[child.name] = child
			child.fsm = self # Give each state a reference back to this FSM.
			
	if states.is_empty():
		push_error("UtilityAI has no child states! Please add state nodes.")
		return

	# Start in the Idle state.
	change_state("Idle")


# The main AI tick now delegates to the current state.
func _process(delta: float) -> void:
	if current_state:
		current_state.process_state(delta)


# Manages transitions between states.
func change_state(state_name: String) -> void:
	if not states.has(state_name):
		push_error("Attempted to change to unknown state: %s" % state_name)
		return
		
	if current_state:
		current_state.exit()
		
	current_state = states[state_name]
	current_state.enter()


# --- Public Methods for External Control ---

# Call this from other systems (dialogue, player commands) to interrupt the AI.
func interrupt() -> void:
	change_state("Interrupted")

# Call this to release the AI from the interrupted state.
func resume_from_interrupt() -> void:
	if current_state is InterruptedState:
		(current_state as InterruptedState).resume()
	else:
		push_warning("Attempted to resume, but AI was not in InterruptedState.")


# --- Helper Functions ---

# Helper function to find an action resource by its name.
func get_action_by_name(action_name: String) -> UtilityActionResource:
	for action in actions:
		if action.action_name == action_name:
			return action
	return null
