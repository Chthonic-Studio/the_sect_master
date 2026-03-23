class_name CharacterBrain extends RefCounted 

## Handles daily decision making and state progression for an individual character.

# --- UTILITY SETTINGS ---
# Easily adjust this variance. 0.15 means scores fluctuate by +/- 15%.
# This prevents characters from getting stuck in deterministic loops.
const UTILITY_NOISE_VARIANCE: float = 0.15 

var current_action: ActionPlan = null

## Evaluates the daily tick for the character's actions.
func process_daily_tick(character: CharacterData) -> void:
	if current_action != null:
		current_action.duration_remaining -= 1
		current_action.process_tick(character)
		
		if current_action.duration_remaining <= 0:
			current_action.on_complete(character)
			current_action = null
			
	if current_action == null:
		_choose_new_action(character)

func _choose_new_action(character: CharacterData) -> void:
	# Rely on the centralized DataManager array to save memory
	if DataManager.desires_registry.is_empty():
		return
		
	var best_score: float = -1.0
	var best_desire: Desire = null
	
	for desire in DataManager.desires_registry:
		var raw_score = desire.evaluate(character)
		
		if raw_score <= 0.0:
			continue
			
		var noise_modifier = randf_range(1.0 - UTILITY_NOISE_VARIANCE, 1.0 + UTILITY_NOISE_VARIANCE)
		var final_score = raw_score * noise_modifier
		
		if final_score > best_score:
			best_score = final_score
			best_desire = desire
			
	if best_desire:
		current_action = best_desire.generate_action(character)

## Used during game load to restore the character's active task
func restore_action_state(action_id: String, duration: int) -> void:
	if action_id == "":
		return
	# TODO: Call an ActionPlan factory to generate the correct derived class
	# current_action = ActionFactory.create(action_id, duration)
	current_action = ActionPlan.new(action_id, duration) 
