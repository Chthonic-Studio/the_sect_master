extends Directive

## Right now this is a directive meant for testing, its not optimized for proper gameplay

## Assign this to a character's 'current_directive' to send them away.
## Example: character.current_directive = DataManager.create_directive("directive_explore_ruins", 10)

func _init(duration: int = 5, custom_mods: Dictionary = {}) -> void:
	# If no custom mods are passed by the factory, we provide grueling defaults for exploring.
	var applied_mods = custom_mods if not custom_mods.is_empty() else {
		"fatigue_rate": 15.0,  # 3x normal fatigue (Grueling travel)
		"stress_rate": 5.0,    # Slowly drives them insane with paranoia
		"loneliness_rate": 5.0 # Isolated from the sect's social life
	}
	
	super(duration, applied_mods)
	id = "directive_explore_ruins"

func process_tick(character: CharacterData) -> void:
	# Note: Baseline need decay is handled automatically by CharacterData._apply_daily_decay()
	# This function is strictly for custom, unique events that happen during the mission.
	
	# Example: 10% chance every day they trigger a trap, adding instant burst stress.
	if randf() < 0.10:
		character.state_vars["stress"] = minf(100.0, character.state_vars.get("stress", 0.0) + 15.0)

func on_complete(character: CharacterData) -> void:
	# The mission is over. Grant the character their rewards!
	character.wealth += randi_range(50, 200)
	
	# 30% chance to return with sudden martial enlightenment
	if randf() < 0.30:
		character.add_temporary_modifier("meditation_insight", 7)
		
	# A simple debug print so you can see it working in the output console
	print("DIRECTIVE COMPLETE: ", character.get_full_name(), " returned from exploring ruins with ", character.state_vars.get("fatigue", 0), " fatigue!")
