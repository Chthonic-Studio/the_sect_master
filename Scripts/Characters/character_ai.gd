extends Node
class_name CharacterAI

# Reference to the character's State and Controller
var data: CharacterData
var controller: Char

func _ready() -> void:
	# Get references to siblings/parent
	data = get_parent().get_node("Data") as CharacterData
	controller = get_parent() as Char
	
	if not data or not controller:
		push_error("CharacterAI requires 'Data' and 'Character' parent/sibling nodes.")
		set_process(false)

func _process(delta: float) -> void:
	# AI tick - determine the character's current highest priority "desire"
	_make_decision()

func _make_decision() -> void:
	# 1. Gather all current scores for needs/desires (e.g., Hunger, Social, Power)
	
	# Example of accessing the personality state:
	var current_morality = data.get_stat("morality") 
	var current_ambition = data.get_stat("ambition")
	
	var desire_power = _calculate_power_utility(current_ambition) # Utility function based on stats
	var desire_socialize = _calculate_social_utility(current_morality)
	
	# 2. Select the highest utility action (Utility AI Pattern)
	var highest_utility_action = "SeekPower" # Placeholder
	
	# 3. Tell the Controller what to do
	_execute_action(highest_utility_action)
	
func _execute_action(action_name: String) -> void:
	# Tell the Character (Controller) to execute the movement/interaction
	match action_name:
		"SeekPower":
			controller.start_cultivation() # Delegation to the Controller
		"Socialize":
			controller.initiate_interaction(null)
		_:
			pass

# Placeholder Utility functions
func _calculate_power_utility(ambition: int) -> float:
	# Logic based on ambition, current cultivation level, and known opportunities
	return float(ambition) / 20.0
	
func _calculate_social_utility(morality: int) -> float:
	# Logic based on morality, sociability (via Charisma), and current loneliness/loyalty
	return 0.0 # Placeholder
