# UtilityActionResource.gd
# Abstract base for all character actions in Utility AI system.
# Extend for concrete actions (Eat, Meditate, Idle, etc).

extends Resource
class_name UtilityActionResource

signal action_started(action_name)
signal action_completed(action_name)

@export var action_name: String = "" # Name used for desire/action mapping and debug

var _timer := 0.0

# --- Public Functions (to be called by AI) ---

# Returns true if this action can be performed by the character.
# Child classes should override this with specific conditions.
func can_perform(character: Node) -> bool:
	return true

# Called when an action is chosen. Child classes MUST override this.
# This ensures every action defines how it should start.
func start_action(character: Node) -> void:
	# This function must be overridden by child actions (e.g., IdleAction).
	# It should call _start_timer() with its own duration values.
	push_error("Base start_action() called. Child class must override this method.")

# Processes the action's duration. Called every frame by the AI.
# Returns true when the action is finished, false otherwise.
func process_action(character: Node, delta: float) -> bool:
	_timer -= delta
	if _timer <= 0:
		emit_signal("action_completed", action_name)
		return true # Signal that the action is complete
	return false # Action is still ongoing

# Called when action ends. Child classes can override this for cleanup/effects.
func end_action(character: Node) -> void:
	pass

# --- Helper Function (for children to use) ---

# Protected helper function for child classes to initialize the action timer.
func _start_timer(min_duration: float, max_duration: float) -> void:
	_timer = randf_range(min_duration, max_duration)
	emit_signal("action_started", action_name)
