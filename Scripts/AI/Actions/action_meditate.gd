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
	var insight_val: float = character.get_martial_stat(Definitions.MartialStat.INSIGHT)

	# Probabilistic gain: meditation rewards disciplined, insightful cultivators.
	# Insight and discipline both raise the chance of a genuine breakthrough.
	var gain_chance: float = (0.05 * apt_mult) + (discipline / 100.0 * 0.03) + (insight_val / 100.0 * 0.03)
	if randf() > gain_chance:
		character.add_log("Finished a meditation session. The Qi moved, but no breakthrough today.")
		return

	# Building bonus: dedicated meditation chamber
	var building_mult: float = 1.0
	if character.ai_tags.has("meditator"):
		building_mult = 1.4

	var if_gain: int = clampi(int(randf_range(1.0, 3.0) * building_mult), 1, 5)
	var qi_gain: int = clampi(int(randf_range(1.0, 2.0) * building_mult), 1, 3)

	character.base_martial[Definitions.MartialStat.INTERNAL_FORCE] += if_gain
	character.base_martial[Definitions.MartialStat.QI_FLOW] += qi_gain
	character.recalculate_all_stats()
	character.check_realm_advancement()

	# Rare chance to gain INSIGHT for disciplined, insightful meditators
	if discipline > 65 and randf() < 0.15:
		character.base_martial[Definitions.MartialStat.INSIGHT] += 1
		character.recalculate_all_stats()

	# After a long session, they might gain a temporary insight buff
	if randf() < 0.15:
		character.add_temporary_modifier("meditation_insight", 5)
	
	character.add_log("Finished a meditation session. The Qi stirs — a genuine improvement. (+%d Internal Force, +%d Qi Flow)" % [if_gain, qi_gain])
