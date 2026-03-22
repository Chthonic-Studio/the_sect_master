class_name CharacterBrain extends RefCounted 

## Handles daily decision making and state progression for an individual character.

# --- UTILITY SETTINGS ---
# Easily adjust this variance. 0.15 means scores fluctuate by +/- 15%.
# This prevents characters from getting stuck in deterministic loops.
const UTILITY_NOISE_VARIANCE: float = 0.15 

var current_action: ActionPlan = null
var available_desires: Array[Desire] = [] # We will populate this from a DataManager registry later

## Evaluates the daily tick for the character's actions.
func process_daily_tick(character: CharacterData) -> void:
	# 1. Process existing action
	if current_action != null:
		current_action.duration_remaining -= 1
		current_action.process_tick(character)
		
		if current_action.duration_remaining <= 0:
			current_action.on_complete(character)
			current_action = null
			
	# 2. If no action (or if action just finished), pick a new one
	if current_action == null:
		_choose_new_action(character)

func _choose_new_action(character: CharacterData) -> void:
	# If there are no desires loaded yet, safely abort.
	if available_desires.is_empty():
		return
		
	var best_score: float = -1.0
	var best_desire: Desire = null
	
	for desire in available_desires:
		var raw_score = desire.evaluate(character)
		
		# Skip invalid or blocked desires
		if raw_score <= 0.0:
			continue
			
		# Apply Utility Noise to introduce organic variation
		var noise_modifier = randf_range(1.0 - UTILITY_NOISE_VARIANCE, 1.0 + UTILITY_NOISE_VARIANCE)
		var final_score = raw_score * noise_modifier
		
		if final_score > best_score:
			best_score = final_score
			best_desire = desire
			
	# Apply the winning desire
	if best_desire:
		current_action = best_desire.generate_action(character)
