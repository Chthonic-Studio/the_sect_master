# UtilityActionResource.gd
# Abstract base for all character actions in Utility AI system.
# Extend for concrete actions (Eat, Meditate, Idle, etc).

extends Resource
class_name UtilityActionResource

signal action_started(action_name)
signal action_completed(action_name)

@export var action_name: String = "" # Name used for desire/action mapping and debug
@export_range(0, 200, 5) var cooldown_to_apply: int = 100 # How much this action suppresses the desire.

var _timer := 0.0

func init() -> void:
	_timer = 0.0

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
	# --- New Cooldown Logic ---
	var res = character.character_resource
	if res and cooldown_to_apply > 0:
		# Add the cooldown value to the character's personal dictionary.
		# This will suppress the desire that triggered this action.
		res.desire_cooldowns[action_name] = res.desire_cooldowns.get(action_name, 0) + cooldown_to_apply
		print("Applied cooldown of %d to '%s' for %s." % [cooldown_to_apply, action_name, res.name_display])

	# Child classes can still add their own logic using super().
	pass

# --- Helper Function (for children to use) ---

func _start_timer(min_duration: float, max_duration: float) -> void:
	# --- REASON FOR CHANGE ---
	# We are adding a critical safeguard. This 'assert' will cause the game to pause
	# with an error if an action ever tries to start with a non-positive duration.
	# This immediately tells us if the duration values from the child action are invalid.
	assert(min_duration > 0 and max_duration > 0, "Action '%s' was started with a zero or negative duration." % action_name)
	
	# We also ensure max_duration is always greater than or equal to min_duration.
	var final_max = max(min_duration, max_duration)
	
	_timer = randf_range(min_duration, final_max)

	emit_signal("action_started", action_name)
