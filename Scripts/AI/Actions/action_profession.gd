extends ActionPlan

## Executes the work shift, calculating economic output based on the character's position and tags.

func _init(duration: int = 1) -> void:
	super(duration)
	id = "action_profession"

func process_tick(character: CharacterData) -> void:
	# Working is tiring
	character.state_vars["fatigue"] = minf(100.0, character.state_vars.get("fatigue", 0.0) + 15.0)
	
	# Satisfies the work need aggressively
	character.needs["work"] = maxf(0.0, character.needs.get("work", 0.0) - 25.0)
	
	# --- PERSONAL INCOME (tags) ---
	var personal_income = 0
	
	if character.ai_tags.has("merchant"):
		personal_income = randi_range(5, 20)
		character.needs["socialization"] = maxf(0.0, character.needs.get("socialization", 0.0) - 5.0)
	elif character.ai_tags.has("blacksmith"):
		personal_income = randi_range(10, 15)
		character.state_vars["fatigue"] = minf(100.0, character.state_vars.get("fatigue", 0.0) + 5.0)
	elif character.ai_tags.has("beggar"):
		personal_income = randi_range(0, 3)
		character.state_vars["comfort"] = maxf(0.0, character.state_vars.get("comfort", 50.0) - 2.0)
	else:
		personal_income = randi_range(1, 5)
		
	character.wealth += personal_income
	
	# --- SECT RESOURCE CONTRIBUTION (position-based) ---
	# Sect members contribute a portion of their output to the sect's coffers.
	if character.sect_id == "":
		return
	
	var sect = SimulationManager.get_sect(character.sect_id)
	if not sect:
		return
	
	# Determine the character's position contribution
	var contribution_wealth = 0
	var contribution_materials = 0
	var has_position = false
	
	# Check assigned position in sect
	for pos_name in sect.members_by_position:
		if sect.members_by_position[pos_name].has(character.char_id):
			has_position = true
			match pos_name:
				"cook":
					# Cooks improve the sect's food security (not a resource, but reduce upkeep cost)
					contribution_wealth = randi_range(0, 2)
				"quartermaster":
					contribution_wealth = randi_range(3, 8)
					contribution_materials = randi_range(1, 4)
				"treasurer":
					contribution_wealth = randi_range(5, 12)
				_:
					contribution_wealth = randi_range(1, 4)
			break
	
	# Generic sect member labor contribution (when not assigned a specific position)
	if not has_position:
		contribution_wealth = randi_range(1, 3)
	
	# Bonus from trade network tag
	if sect.unlocked_tags.has("trade_network"):
		contribution_wealth += randi_range(1, 3)
	
	# Add to sect resources
	if contribution_wealth > 0:
		sect.resources[Definitions.ResourceType.WEALTH] = sect.resources.get(Definitions.ResourceType.WEALTH, 0) + contribution_wealth
	if contribution_materials > 0:
		sect.resources[Definitions.ResourceType.MATERIALS] = sect.resources.get(Definitions.ResourceType.MATERIALS, 0) + contribution_materials

func on_complete(character: CharacterData) -> void:
	pass
