extends Node 
class_name UtilityAI

# Emitted when a new action is chosen, so the UI can update.
signal action_changed(new_action_name)

# An array of all possible actions this character can perform.
@export var actions: Array[UtilityActionResource] = []
# An array of all desires that drive this character's decisions.
@export var desires: Array[UtilityDesireResource] = []

# --- AI State ---
# The action currently being performed. Null if the AI is deciding.
var current_action: UtilityActionResource = null
# The name of the last action that was completed.
var previous_action_name: String = "None"
var character: Node = null

func _ready() -> void:
	character = get_parent()

# The main AI tick, called every frame.
func _process(delta: float) -> void:
	# If an action IS currently being performed, process it and do nothing else.
	if current_action:
		# The process_action function returns 'true' when it's finished.
		var is_action_finished = current_action.process_action(character, delta)
		
		if is_action_finished:
			# The action has just finished. Time for cleanup.
			# Store the name of the action that just completed.
			previous_action_name = current_action.action_name
			
			# Call the action's end function to apply any effects (e.g., restore HP).
			current_action.end_action(character)
			
			# Set current_action to null. The duplicated resource will be freed from memory.
			current_action = null
		
		# VERY IMPORTANT: We return here to ensure we don't try to pick a new
		# action in the same frame that we are processing or finishing one.
		return

	# If we reach this point, it means current_action is null.
	# It is time to choose a new action.
	_select_next_action()


# This function evaluates all desires and selects the best possible action.
func _select_next_action() -> void:
	# --- Start of AI Thought Process ---
	var char_name = character.character_resource.name_display if character.character_resource else "UnknownChar"
	print("\n--- AI TICK: %s is choosing an action ---" % char_name)
	
	var best_utility := -INF # Start with a very low score
	var best_action_template: UtilityActionResource = null # We will find the best TEMPLATE

	# --- Step 1: Evaluate all desires ---
	print("1. Evaluating desires...")
	if desires.is_empty():
		print("  [WARNING] No desires assigned to this AI. Cannot make decisions.")
	
	for desire in desires:
		var utility_score = desire.get_final_utility(character)
		print("  - Desire '%s' utility score: %.2f" % [desire.desire_name, utility_score])
		
		if utility_score > best_utility:
			var corresponding_action_template = _find_action_for_desire(desire.desire_name)
			
			if not corresponding_action_template:
				print("    [WARNING] No action found with name: '%s'." % desire.desire_name)
				continue

			if corresponding_action_template.can_perform(character):
				best_utility = utility_score
				best_action_template = corresponding_action_template
			else:
				print("    [INFO] '%s' cannot be performed right now." % corresponding_action_template.action_name)

	# --- Step 2: Choose the final action ---
	print("\n2. Making final decision...")
	var chosen_template: UtilityActionResource = null
	if best_action_template:
		print("   [DECISION] Selecting '%s' as the current action." % best_action_template.action_name)
		chosen_template = best_action_template
	else:
		print("   [DECISION] No valid actions could be performed. Defaulting to 'Idle'.")
		chosen_template = _find_action_for_desire("Idle")

	# --- Step 3: Instantiate and Start the chosen action ---
	if chosen_template:
		# We DUPLICATE the chosen template to create a unique instance.
		current_action = chosen_template.duplicate()
		
		current_action.init()
		
		print("3. Starting action: '%s'" % current_action.action_name)
		current_action.start_action(character)
		emit_signal("action_changed", current_action.action_name)
	else:
		print("[ERROR] Could not select an action! Even the 'Idle' action is missing or invalid.")
		push_warning("AI could not select an action. No valid actions found, including Idle.")


# Helper function to find an action resource by its name.
func _find_action_for_desire(action_name: String) -> UtilityActionResource:
	for action in actions:
		if action.action_name == action_name:
			return action
	return null
