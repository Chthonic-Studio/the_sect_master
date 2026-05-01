extends ActionPlan

func _init(duration: int = 3) -> void:
	super(duration)
	id = "action_spar"

func process_tick(character: CharacterData) -> void:
	# Training is physically demanding
	character.state_vars["fatigue"] = minf(100.0, character.state_vars.get("fatigue", 0.0) + 18.0)
	
	# Satisfies the training need
	character.needs["training"] = maxf(0.0, character.needs.get("training", 0.0) - 30.0)
	character.needs["socialization"] = maxf(0.0, character.needs.get("socialization", 0.0) - 8.0)

func on_complete(character: CharacterData) -> void:
	if not character.is_martial_artist:
		character.add_log("Spent time sparring on the training ground.")
		return

	var apt_mult: float = Definitions.APTITUDE_TRAINING_MULT.get(character.aptitude, 1.0)
	var discipline: float = character.get_personality_value("discipline")
	var ambition: float = character.get_personality_value("ambition")

	# Probabilistic gain: stat improvements are rare and meaningful, not guaranteed every session.
	# Chance scales with aptitude, discipline, and ambition so dedicated cultivators progress faster.
	var gain_chance: float = (0.05 * apt_mult) + (discipline / 100.0 * 0.03) + (ambition / 100.0 * 0.02)
	if randf() > gain_chance:
		character.add_log("Finished a sparring session. Hard training, but no breakthrough today.")
		return

	# Building bonus: "martial_training" tag means the sect has a proper training hall
	var building_mult: float = 1.0
	if character.ai_tags.has("sparring"):
		building_mult = 1.3

	var if_gain: int = clampi(int(randf_range(1.0, 3.0) * building_mult), 1, 4)
	var tech_gain: int = clampi(int(randf_range(1.0, 2.0) * building_mult), 1, 3)

	character.base_martial[Definitions.MartialStat.INTERNAL_FORCE] += if_gain
	character.base_martial[Definitions.MartialStat.TECHNIQUE] += tech_gain
	character.recalculate_all_stats()
	character.check_realm_advancement()

	character.add_log("Finished a sparring session. Insight struck — a genuine improvement. (+%d Internal Force, +%d Technique)" % [if_gain, tech_gain])
