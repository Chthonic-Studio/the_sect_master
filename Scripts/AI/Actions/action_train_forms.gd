extends ActionPlan

## Dedicated forms practice action. Focuses on TECHNIQUE and QINGGONG growth.
## Triggered by desire_train_forms when the sect has a training hall.

func _init(duration: int = 2) -> void:
	super(duration)
	id = "action_train_forms"

func process_tick(character: CharacterData) -> void:
	character.state_vars["fatigue"] = minf(100.0, character.state_vars.get("fatigue", 0.0) + 14.0)
	character.needs["training"] = maxf(0.0, character.needs.get("training", 0.0) - 25.0)

func on_complete(character: CharacterData) -> void:
	if not character.is_martial_artist:
		return

	var apt_mult: float = Definitions.APTITUDE_TRAINING_MULT.get(character.aptitude, 1.0)
	var discipline: float = character.get_personality_value("discipline")
	var disc_mult: float = 0.7 + (discipline / 100.0 * 0.6)

	var building_mult: float = 1.0
	if character.ai_tags.has("sparring"):
		building_mult = 1.3

	var tech_gain: int = clampi(int(randf_range(2.0, 4.0) * apt_mult * disc_mult * building_mult), 1, 8)
	var qing_gain: int = clampi(int(randf_range(1.5, 3.0) * apt_mult * disc_mult * building_mult), 1, 6)

	character.base_martial[Definitions.MartialStat.TECHNIQUE] += tech_gain
	character.base_martial[Definitions.MartialStat.QINGGONG] += qing_gain
	character.recalculate_all_stats()
	character.check_realm_advancement()

	character.add_log("Practiced combat forms. (+%d Technique, +%d Qinggong)" % [tech_gain, qing_gain])
