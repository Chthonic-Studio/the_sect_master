# UtilityAI.gd
# Attach to Character node in scene.
# Manages arrays of UtilityActionResource and UtilityDesireResource.
# Handles action selection, transitions, and signals.

extends Node
class_name UtilityAI

signal action_changed(new_action_name)

@export var actions: Array[UtilityActionResource] = []
@export var desires: Array[UtilityDesireResource] = []

var current_action: UtilityActionResource = null
var character: Node = null # Reference to parent Character node

func _ready() -> void:
	character = get_parent()
	# Optionally populate actions/desires here, or via Inspector

func tick_ai(delta: float) -> void:
	# If not performing an action, look for next action
	if not current_action:
		_select_next_action()
		return
	# Process current action
	if current_action.process_action(character, delta):
		current_action.end_action(character)
		current_action = null

# Selects the next action based on desire utility and can_perform
func _select_next_action() -> void:
	var best_utility := -INF
	var best_action: UtilityActionResource = null
	var desire_action_map := {}
	# Map desires to actions by name
	for desire in desires:
		desire_action_map[desire.desire_name] = desire.get_utility(character)
	for action in actions:
		if action.can_perform(character):
			var utility_val = desire_action_map.get(action.action_name, 0.0)
			if utility_val > best_utility:
				best_utility = utility_val
				best_action = action
	# If no desire is high, default to Idle
	if not best_action:
		for action in actions:
			if action.action_name == "Idle":
				best_action = action
				break
	if best_action:
		current_action = best_action
		current_action.start_action(character)
		emit_signal("action_changed", current_action.action_name)

# Optional: Call this from _process or via TimeManager tick
func _process(delta: float) -> void:
	tick_ai(delta)
