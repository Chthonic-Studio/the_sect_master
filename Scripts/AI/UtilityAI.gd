# UtilityAI.gd
# Attach to the Character node in the scene.
# Manages arrays of UtilityActionResource and UtilityDesireResource.
# Handles the core AI loop: action selection, execution, and transitions.

extends Node
class_name UtilityAI

# Emitted when a new action is chosen, so the UI can update.
signal action_changed(new_action_name)

# --- EXPORTS (Assign these in the Inspector on your Character scene) ---
# An array of all possible actions this character can perform.
@export var actions: Array[UtilityActionResource] = []
# An array of all desires that drive this character's decisions.
@export var desires: Array[UtilityDesireResource] = []

# --- AI State ---
# The action currently being performed. Null if the AI is deciding.
var current_action: UtilityActionResource = null
# The name of the last action that was completed.
var previous_action_name: String = "None"
# A reference to the parent Character node this AI is controlling.
var character: Node = null

# --- HOW & WHERE TO USE ---
# 1. Attach this script to your main Character scene (e.g., the root of Character.tscn).
# 2. In the Godot Inspector, populate the 'Actions' and 'Desires' arrays.
#    - Drag and drop your action .tres files (e.g., IdleAction.tres, EatAction.tres) into the 'Actions' array.
#    - Drag and drop your desire .tres files (e.g., EatDesire.tres, TrainingDesire.tres) into the 'Desires' array.
# 3. The AI will now run automatically.

func _ready() -> void:
	# Store a reference to the parent node for easy access.
	character = get_parent()
	if not character:
		push_error("UtilityAI must be a child of a Character node.")

# The main AI tick, called every frame.
func _process(delta: float) -> void:
	# If the character reference is missing, do nothing.
	if not character:
		return

	# --- AI Decision Loop ---
	# 1. If no action is being performed, it's time to choose a new one.
	if not current_action:
		_select_next_action()
		return

	# 2. If an action IS being performed, process it.
	# The process_action function returns 'true' when it's finished.
	if current_action.process_action(character, delta):
		# 3. The action has just finished. Time for cleanup and state change.
		# Store the name of the action that just completed.
		previous_action_name = current_action.action_name
		
		# Call the action's end function to apply any effects (e.g., restore HP).
		current_action.end_action(character)
		
		# Set current_action to null. This tells the AI to pick a new action on the next frame.
		current_action = null


# This function evaluates all desires and selects the best possible action.
func _select_next_action() -> void:
	# --- Start of AI Thought Process ---
	var char_name = character.character_resource.name_display if character.character_resource else "UnknownChar"
	print("\n--- AI TICK: %s is choosing an action ---" % char_name)
	
	var best_utility := -INF # Start with a very low score
	var best_action: UtilityActionResource = null

	# --- Step 1: Evaluate all desires ---
	# We loop through each desire to find out what the character wants to do most.
	print("1. Evaluating desires...")
	if desires.is_empty():
		print("  [WARNING] No desires assigned to this AI. Cannot make decisions.")
	
	for desire in desires:
		var utility_score = desire.get_utility(character)
		print("  - Desire '%s' utility score: %.2f" % [desire.desire_name, utility_score])
		
		# If this desire's score is the highest we've seen so far...
		if utility_score > best_utility:
			# ...find the action that corresponds to this desire.
			print("    > This is a new highest score. Checking for a matching action...")
			var corresponding_action = _find_action_for_desire(desire.desire_name)
			
			# Check if that action exists and if the character can currently perform it.
			if not corresponding_action:
				print("    [WARNING] No action found with name: '%s'. Check 'action_name' in your Action resources." % desire.desire_name)
				continue # Skip to the next desire

			print("    > Found action: '%s'. Checking if it can be performed." % corresponding_action.action_name)
			# Check if the character can currently perform it.
			if corresponding_action.can_perform(character):
				print("    [SUCCESS] '%s' can be performed. It is now the best candidate." % corresponding_action.action_name)
				# If so, this is our new top candidate.
				best_utility = utility_score
				best_action = corresponding_action
			else:
				print("    [INFO] '%s' cannot be performed right now." % corresponding_action.action_name)

	# --- Step 2: Choose the final action ---
	print("\n2. Making final decision...")
	print("   - Best candidate action: '%s' with utility: %.2f" % [best_action.action_name if best_action else "None", best_utility])
	
	# If we found a valid action and its score is meaningful (greater than 0)...
	if best_action and best_utility > 0:
		print("   [DECISION] Selecting '%s' as the current action." % best_action.action_name)
		current_action = best_action
	else:
		# ...otherwise, the character has no pressing needs. Default to Idle.
		print("   [DECISION] No pressing desires. Defaulting to 'Idle'.")
		current_action = _find_action_for_desire("Idle")

	# --- Step 3: Start the chosen action ---
	if current_action:
		print("3. Starting action: '%s'" % current_action.action_name)
		current_action.start_action(character)
		emit_signal("action_changed", current_action.action_name)
	else:
		# This is a fallback in case even the "Idle" action is missing.
		print("[ERROR] Could not select an action! Even the 'Idle' action is missing or invalid.")
		push_warning("AI could not select an action. No valid actions found, including Idle.")


# Helper function to find an action resource by its name.
func _find_action_for_desire(action_name: String) -> UtilityActionResource:
	for action in actions:
		if action.action_name == action_name:
			return action
	return null
