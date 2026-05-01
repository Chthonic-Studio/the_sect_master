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
	var ambition: float = character.get_personality_value("ambition")

	# Probabilistic gain: forms practice rewards those who persevere with discipline and drive.
	var gain_chance: float = (0.05 * apt_mult) + (discipline / 100.0 * 0.04) + (ambition / 100.0 * 0.02)
	if randf() > gain_chance:
		character.add_log("Practiced combat forms. Diligent repetition, but no breakthrough today.")
		return

	var building_mult: float = 1.0
	if character.ai_tags.has("sparring"):
		building_mult = 1.3

	var tech_gain: int = clampi(int(randf_range(1.0, 3.0) * building_mult), 1, 4)
	var qing_gain: int = clampi(int(randf_range(1.0, 2.0) * building_mult), 1, 3)

	character.base_martial[Definitions.MartialStat.TECHNIQUE] += tech_gain
	character.base_martial[Definitions.MartialStat.QINGGONG] += qing_gain
	character.recalculate_all_stats()
	character.check_realm_advancement()

	character.add_log("Practiced combat forms. The movements clicked into place today. (+%d Technique, +%d Qinggong)" % [tech_gain, qing_gain])
