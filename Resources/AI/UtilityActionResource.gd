# UtilityActionResource.gd
# Abstract base for all character actions in Utility AI system.
# Extend for concrete actions (Eat, Meditate, Idle, etc).

class_name UtilityActionResource extends Resource

signal action_started(action_name)
signal action_completed(action_name)

@export var action_name: String = "" # Name used for desire/action mapping and debug
@export_range(-200, 0, 5) var satiation_value: int = -100 # How much this action reduces the desire modifier.

var _timer := 0.0

func init() -> void:
	_timer = 0.0

# Returns true if this action can be performed by the character.
# Child classes should override this with specific conditions.
func can_perform(character: Node) -> bool:
	return true

# Called when an action is chosen. Child classes MUST override this.
func start_action(character: Node) -> void:
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
	var res = character.character_resource
	if res and satiation_value != 0:
		# Apply the satiation value to the desire modifier.
		# This makes the character less likely to perform this action again immediately.
		res.desire_modifiers[action_name] = res.desire_modifiers.get(action_name, 0) + satiation_value
		print("Applied satiation of %d to '%s' for %s." % [satiation_value, action_name, res.name_display])
	pass

# --- Helper Function (for children to use) ---
func _start_timer(min_duration: float, max_duration: float) -> void:
	var final_max = max(min_duration, max_duration)
	_timer = randf_range(min_duration, final_max)
	emit_signal("action_started", action_name)
