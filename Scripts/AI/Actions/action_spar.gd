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
	var disc_mult: float = 0.7 + (discipline / 100.0 * 0.6) # 0.7 – 1.3 range

	# Building bonus: "martial_training" tag means the sect has a proper training hall
	var building_mult: float = 1.0
	if character.ai_tags.has("sparring"):
		building_mult = 1.3

	var base_if_gain: float = randf_range(1.5, 3.5)
	var base_tech_gain: float = randf_range(1.0, 2.5)

	# Daily cap: prevent exploitation of high-speed simulation
	var if_gain: int = clampi(int(base_if_gain * apt_mult * disc_mult * building_mult), 1, 8)
	var tech_gain: int = clampi(int(base_tech_gain * apt_mult * disc_mult * building_mult), 1, 6)

	character.base_martial[Definitions.MartialStat.INTERNAL_FORCE] += if_gain
	character.base_martial[Definitions.MartialStat.TECHNIQUE] += tech_gain
	character.recalculate_all_stats()
	character.check_realm_advancement()

	character.add_log("Finished a sparring session. (+%d Internal Force, +%d Technique)" % [if_gain, tech_gain])
