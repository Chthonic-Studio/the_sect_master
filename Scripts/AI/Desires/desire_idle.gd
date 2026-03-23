extends Desire

func _init() -> void:
	id = "desire_idle"

## Idle is the baseline. It always returns a low, flat score.
## If no other pressing needs exist, the AI defaults to this.
func evaluate(_character: CharacterData) -> float:
	return 15.0 # A low baseline score

func generate_action(_character: CharacterData) -> ActionPlan:
	# Idle for a short burst (1 to 3 days)
	var duration = randi_range(1, 3)
	return DataManager.create_action("action_idle", duration)
