extends Node

enum GenerationContext {
	WORLD_GEN,
	BIRTH,
	RECRUIT_COMMON,
	RECRUIT_ELITE,
	SECT_MEMBER,
	REPOPULATE
}

func create_character(context: GenerationContext, overrides: Dictionary = {}) -> CharacterData:
	var character = CharacterData.new()
	
	_apply_demographics(character, context, overrides)
	_apply_talents(character, context, overrides)
	_apply_personality_and_traits(character, context, overrides)
	_calculate_initial_stats(character)
	
	if overrides.has("sect_id"):
		character.sect_id = overrides["sect_id"]
	
	DataManager.register_character(character)
	return character

func _apply_demographics(_char: CharacterData, context: GenerationContext, overrides: Dictionary) -> void:
	_char.gender = overrides.get("gender", randi() % 3)
	
	# Using generic for fallback if specific cultures aren't passed yet
	var pools = DataManager.name_pools.get("cultures", {}).get("CENTRAL_PLAINS", {})
	if pools.is_empty(): return
	
	if _char.gender == 0:
		_char.first_name = pools.get("male_given", []).pick_random()
	else:
		_char.first_name = pools.get("female_given", []).pick_random()
		
	_char.last_name = overrides.get("last_name", pools.get("surnames", []).pick_random())
	
	match context:
		GenerationContext.BIRTH: _char.age = 0
		GenerationContext.RECRUIT_COMMON: _char.age = randi_range(14, 20)
		GenerationContext.WORLD_GEN: _char.age = _get_weighted_age_roll()
		GenerationContext.SECT_MEMBER: _char.age = overrides.get("age", randi_range(16, 60))
		_: _char.age = overrides.get("age", randi_range(18, 40))

func _apply_talents(_char: CharacterData, context: GenerationContext, _overrides: Dictionary) -> void:
	var roll = randf()
	if context == GenerationContext.RECRUIT_ELITE: roll *= 0.5 
		
	if roll < 0.05: _char.current_realm = 3
	elif roll < 0.2: _char.current_realm = 2
	else: _char.current_realm = 1

func _apply_personality_and_traits(_char: CharacterData, context: GenerationContext, overrides: Dictionary) -> void:
	# 1. Initialize base continuous axes (0-100)
	var all_axes = Definitions.PERSONALITY_STATS + Definitions.ALIGNMENT_STATS
	for p_name in all_axes:
		var base = 50
		if context == GenerationContext.BIRTH and overrides.has("parent_personalities"):
			base = overrides["parent_personalities"].get(p_name, 50) + randi_range(-10, 10)
		else:
			base = randi_range(30, 70) # Tighter grouping so traits have more impact
		_char.personality_values[p_name] = clampi(base, 0, 100)

	# 2. Separate available traits by type
	var personality_pool: Array[String] = []
	var common_pool: Array[String] = []
	
	for t_id in DataManager.traits_registry:
		var trait_data = DataManager.traits_registry[t_id]
		if trait_data.get("type", "common") == "personality":
			personality_pool.append(t_id)
		else:
			common_pool.append(t_id)
			
	# 3. Determine number of Personality Traits based on age thresholds
	var target_personality_traits = 0
	for age_cap in Definitions.PERSONALITY_AGE_THRESHOLDS.keys():
		if _char.age <= age_cap:
			target_personality_traits = Definitions.PERSONALITY_AGE_THRESHOLDS[age_cap]
			break
			
	# Apply Personality Traits
	_assign_traits_from_pool(_char, personality_pool, target_personality_traits)
	
	# Apply Common Traits (Randomly 0 to 3 for initial generation)
	var num_common = randi_range(0, 3)
	if _char.age > 50: num_common += 1 # Elders have seen more
	_assign_traits_from_pool(_char, common_pool, num_common)

## Helper to assign traits while checking conflicts
func _assign_traits_from_pool(_char: CharacterData, pool: Array[String], amount: int) -> void:
	var available = pool.duplicate()
	available.shuffle() # Randomize pool
	
	var applied = 0
	for t_id in available:
		if applied >= amount: break
		if _is_trait_valid(_char, t_id):
			_char.traits.append(t_id)
			applied += 1

func _is_trait_valid(_char: CharacterData, trait_id: String) -> bool:
	var trait_data = DataManager.traits_registry.get(trait_id, {})
	var conflicts = trait_data.get("conflicts", [])
	for existing in _char.traits:
		if existing in conflicts:
			return false
	return true

func _calculate_initial_stats(_char: CharacterData) -> void:
	var base_val = 10
	if _char.age < 12: base_val = Definitions.BASE_STATS_BY_AGE["child"]
	elif _char.age > 60: base_val = Definitions.BASE_STATS_BY_AGE["elder"]
	else: base_val = Definitions.BASE_STATS_BY_AGE["adult"]
	
	for s in Definitions.Stat.values():
		_char.base_stats[s] = base_val + randi_range(-2, 5)

func _get_weighted_age_roll() -> int:
	var r = randf()
	if r < 0.6: return randi_range(16, 30)
	if r < 0.9: return randi_range(31, 60)
	return randi_range(61, 150)
