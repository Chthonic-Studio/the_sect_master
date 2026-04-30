extends Desire

## Active for martial artists who want structured forms practice.
## Unlocked by the "sparring" ai_tag (training hall building).

func _init() -> void:
	id = "desire_train_forms"
	ai_tags = ["sparring"]

func evaluate(character: CharacterData) -> float:
	if not character.is_martial_artist:
		return 0.0

	var training_need = character.needs.get("training", 0.0)
	if training_need < 15.0:
		return 0.0

	# Slightly lower priority than sparring so they mix both
	var score = (training_need / 100.0) * 45.0

	var discipline = character.get_personality_value("discipline")
	var curiosity = character.get_personality_value("curiosity")
	if discipline > 60:
		score *= 1.3
	if curiosity > 60:
		score *= 1.2

	var last_forms = character.action_cooldowns.get("desire_train_forms", -999)
	var current_day = TimeManager.get_total_days_elapsed()
	if current_day - last_forms < 4:
		return 0.0

	return score

func generate_action(character: CharacterData) -> ActionPlan:
	character.action_cooldowns["desire_train_forms"] = TimeManager.get_total_days_elapsed()
	return DataManager.create_action("action_train_forms", 2)
