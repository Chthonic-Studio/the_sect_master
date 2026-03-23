extends ActionPlan

func _init(duration: int = 1) -> void:
	super(duration)
	id = "action_meditate"

func process_tick(character: CharacterData) -> void:
	# Hard work increases fatigue
	character.state_vars["fatigue"] = minf(100.0, character.state_vars["fatigue"] + 15.0)
	
	# Satisfies the training need
	character.needs["training"] = maxf(0.0, character.needs.get("training", 0.0) - 10.0)
	
	# SMALL chance to permanently increase their base internal force (Cultivation)
	# Influenced by their innate aptitude and comprehension
	var comprehension = character.get_martial_stat(Definitions.MartialStat.INSIGHT)
	var growth_chance = 0.05 + (comprehension / 500.0) # 5% base chance per day
	
	if randf() < growth_chance:
		# Directly modify the BASE martial stat, then trigger a recalculation
		character.base_martial[Definitions.MartialStat.INTERNAL_FORCE] += randi_range(1, 3)
		character.recalculate_all_stats()
		
func on_complete(character: CharacterData) -> void:
	# After a long session, they might gain a temporary buff
	if randf() < 0.2:
		character.add_temporary_modifier("meditation_insight", 5)
