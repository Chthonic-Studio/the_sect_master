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
		# --- URGENCY INTERRUPTION ---
		# High-urgency needs can preempt the current action.
		# This mirrors Rimworld's "pawn drops what they're doing to address a critical need."
		if _should_interrupt_for_urgency(character):
			current_action = null
		else:
			current_action.duration_remaining -= 1
			current_action.process_tick(character)
			
			if current_action.duration_remaining <= 0:
				current_action.on_complete(character)
				current_action = null
			
	_pick_action_if_idle(character)

## Compute-only brain tick: runs action logic but defers on_complete to
## CharacterData._pending_effects so it runs on the main thread.
## Safe to call from any worker thread.
func compute_tick(character: CharacterData) -> void:
	if current_action != null:
		if _should_interrupt_for_urgency(character):
			current_action = null
		else:
			current_action.duration_remaining -= 1
			current_action.process_tick(character)

			if current_action.duration_remaining <= 0:
				# Defer on_complete to the apply phase (main thread)
				character._pending_effects.append({"type": "action_complete", "action": current_action})
				current_action = null

	_pick_action_if_idle(character)

## Chooses a new action when the brain is idle. Shared by both tick variants.
func _pick_action_if_idle(character: CharacterData) -> void:
	if current_action == null:
		_choose_new_action(character)

## Returns true if a critical need exceeds the threshold and should preempt the current action.
func _should_interrupt_for_urgency(character: CharacterData) -> bool:
	# Critical rest need: if fatigue is above 90, rest overrides everything
	var fatigue = character.state_vars.get("fatigue", 0.0)
	if fatigue >= 90.0 and current_action != null and current_action.id != "action_rest":
		return true
	
	# Critical social need: extreme loneliness causes the character to drop tasks,
	# unless they are already fulfilling that need.
	var loneliness = character.state_vars.get("loneliness", 0.0)
	if loneliness >= 95.0 and current_action != null and current_action.id != "action_social_discussion":
		return true
	
	# High rest need: if the rest need is critically high, interrupt non-rest actions
	var rest_need = character.needs.get("rest", 0.0)
	if rest_need >= 95.0 and current_action != null and current_action.id != "action_rest":
		return true
	
	return false

func _choose_new_action(character: CharacterData) -> void:
	var best_score: float = -1.0
	var best_desire: Desire = null
	
	# Keep track of what we've evaluated to avoid duplicates 
	# (e.g., if a Desire has both "general" and "martial_artist" tags)
	var evaluated_ids = {}
	
	for tag in character.ai_tags:
		var desires_for_tag = DataManager.micro_desires.get(tag, [])
		
		for desire in desires_for_tag:
			if evaluated_ids.has(desire.id):
				continue
			evaluated_ids[desire.id] = true
			
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
	# Hooking into our centralized Action Factory to reconstruct the correct script
	current_action = DataManager.create_action(action_id, duration)
