extends ActionPlan

func _init(duration: int = 1) -> void:
	super(duration)
	id = "action_meditate"

func process_tick(character: CharacterData) -> void:
	# Hard work increases fatigue
	character.state_vars["fatigue"] = minf(100.0, character.state_vars["fatigue"] + 15.0)
	
	# Satisfies the training need
	character.needs["training"] = maxf(0.0, character.needs.get("training", 0.0) - 10.0)

func on_complete(character: CharacterData) -> void:
	if not character.is_martial_artist:
		return

	var apt_mult: float = Definitions.APTITUDE_TRAINING_MULT.get(character.aptitude, 1.0)
	var discipline: float = character.get_personality_value("discipline")
	var insight_bonus: float = character.get_martial_stat(Definitions.MartialStat.INSIGHT) / 200.0

	# Building bonus: dedicated meditation chamber
	var building_mult: float = 1.0
	if character.ai_tags.has("meditator"):
		building_mult = 1.4

	var base_if_gain: float = randf_range(1.0, 2.5) + insight_bonus
	var base_qi_gain: float = randf_range(1.0, 2.0) + (insight_bonus * 0.5)

	var if_gain: int = clampi(int(base_if_gain * apt_mult * building_mult), 1, 6)
	var qi_gain: int = clampi(int(base_qi_gain * apt_mult * building_mult), 1, 4)

	character.base_martial[Definitions.MartialStat.INTERNAL_FORCE] += if_gain
	character.base_martial[Definitions.MartialStat.QI_FLOW] += qi_gain
	character.recalculate_all_stats()
	character.check_realm_advancement()

	# Bonus: chance to add INSIGHT as well for disciplined meditators
	if discipline > 65 and randf() < 0.3:
		character.base_martial[Definitions.MartialStat.INSIGHT] += 1
		character.recalculate_all_stats()

	# After a long session, they might gain a temporary insight buff
	if randf() < 0.2:
		character.add_temporary_modifier("meditation_insight", 5)
	
	character.add_log("Finished a meditation session. (+%d Internal Force, +%d Qi Flow)" % [if_gain, qi_gain])
