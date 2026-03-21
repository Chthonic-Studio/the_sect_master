extends Node

## The CharacterGenerator acts as a "Factory" that assembles CharacterData 
## instances based on specific contexts (Birth, Recruitment, World Gen).

# --- ENUMS FOR CONTEXT ---
enum GenerationContext {
	WORLD_GEN,      # Initial world population
	BIRTH,          # Character born to parents
	RECRUIT_COMMON, # Low-tier random commoner
	RECRUIT_ELITE,  # High-tier potential
	SECT_MEMBER,    # Specifically for a rival or player sect
	REPOPULATE      # Filling gaps in the world simulation
}

## Main entry point for creating a character.
## Returns a fully registered CharacterData object.
func create_character(context: GenerationContext, overrides: Dictionary = {}) -> CharacterData:
	var character = CharacterData.new()
	
	# 1. Determine Demographics
	_apply_demographics(character, context, overrides)
	
	# 2. Determine Talent and Affinities (The "Potential")
	_apply_talents(character, context, overrides)
	
	# 3. Assign Personality and Traits
	_apply_personality_and_traits(character, context, overrides)
	
	# 4. Calculate Starting Stats based on Age and Talent
	_calculate_initial_stats(character)
	
	# 5. Apply Affiliations
	if overrides.has("sect_id"):
		character.sect_id = overrides["sect_id"]
	
	# 6. Register in the Global Repository
	DataManager.register_character(character)
	
	return character

func _apply_demographics(_char: CharacterData, context: GenerationContext, overrides: Dictionary):
	# Gender
	_char.gender = overrides.get("gender", randi() % 3)
	
	# Names from DataManager pools
	var pools = DataManager.name_pools
	if _char.gender == 0:
		_char.first_name = pools["male_first"].pick_random()
	elif _char.gender == 1:
		_char.first_name = pools["female_first"].pick_random()
	else:
		_char.first_name = pools["neutral_first"].pick_random()
	
	_char.last_name = overrides.get("last_name", pools["last_names"].pick_random())
	
	# Age Logic
	match context:
		GenerationContext.BIRTH:
			_char.age = 0
		GenerationContext.RECRUIT_COMMON:
			_char.age = randi_range(14, 20)
		GenerationContext.WORLD_GEN:
			_char.age = _get_weighted_age_roll()
		GenerationContext.SECT_MEMBER:
			_char.age = overrides.get("age", randi_range(16, 60))
		_:
			_char.age = overrides.get("age", randi_range(18, 40))

func _apply_talents(_char: CharacterData, context: GenerationContext, _overrides: Dictionary):
	# In Wuxia, talent is often weighted. World Gen gets a normal distribution,
	# but "Elite Recruits" get better odds.
	var roll = randf()
	if context == GenerationContext.RECRUIT_ELITE:
		roll *= 0.5 # Shift roll toward rarer tiers
		
	if roll < 0.05: 
		_char.current_realm = 3 # High Talent
	elif roll < 0.2: _char.current_realm = 2 # Mid Talent
	else: 
		_char.current_realm = 1 # Low Talent

func _apply_personality_and_traits(_char: CharacterData, context: GenerationContext, overrides: Dictionary):
	# Personality initialization
	for p_name in Definitions.PERSONALITY_STATS:
		var base = 50
		# Birth inherits some leanings from parents (if in overrides)
		if context == GenerationContext.BIRTH and overrides.has("parent_personalities"):
			base = overrides["parent_personalities"][p_name] + randi_range(-10, 10)
		else:
			base = randi_range(20, 80)
		_char.personality_values[p_name] = clampi(base, 0, 100)
	
	# Trait Assignment
	var available_traits = DataManager.traits_registry.keys()
	var num_traits = randi_range(1, 3)
	
	# Increase traits for world-gen elders
	if _char.age > 50: num_traits += 2
	
	for i in range(num_traits):
		var t_id = available_traits.pick_random()
		if not _char.traits.has(t_id) and _is_trait_valid(_char, t_id):
			_char.traits.append(t_id)

func _is_trait_valid(_char: CharacterData, trait_id: String) -> bool:
	var trait_data = DataManager.traits_registry.get(trait_id, {})
	var conflicts = trait_data.get("conflicts", [])
	for existing in _char.traits:
		if existing in conflicts:
			return false
	return true

func _calculate_initial_stats(_char: CharacterData):
	# Base stats by age bracket
	var base_val = 10
	if _char.age < 12: base_val = 5
	elif _char.age > 60: base_val = 15
	else: base_val = 20
	
	for s in Definitions.Stat.values():
		_char.base_stats[s] = base_val + randi_range(-2, 5)

func _get_weighted_age_roll() -> int:
	# Simple curve: more young people than ancient masters
	var r = randf()
	if r < 0.6: return randi_range(16, 30)
	if r < 0.9: return randi_range(31, 60)
	return randi_range(61, 150)
