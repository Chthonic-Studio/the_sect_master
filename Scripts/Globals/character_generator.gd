extends Node

enum GenerationContext {
	WORLD_GEN_MARTIAL,
	WORLD_GEN_PEASANT,
	BIRTH,
	RECRUIT_COMMON,
	RECRUIT_ELITE,
	SECT_MEMBER,
	REPOPULATE
}

func create_character(context: GenerationContext, overrides: Dictionary = {}) -> CharacterData:
	var character = CharacterData.new()
	
	# Determine if they are born into the Jianghu or the common world
	if context in [GenerationContext.WORLD_GEN_PEASANT, GenerationContext.REPOPULATE]:
		character.is_martial_artist = false
		var tags = overrides.get("ai_tags", ["peasant", "worker"])
		character.ai_tags.assign(tags) # Safely cast untyped array to Array[String]
	else:
		character.is_martial_artist = true
		character.ai_tags.assign(["general", "martial_artist"])
	
	_apply_demographics(character, context, overrides)
	_apply_talents(character, context, overrides)
	_apply_personality_and_traits(character, context, overrides)
	_calculate_initial_stats(character)
	
	if overrides.has("sect_id"):
		character.sect_id = overrides["sect_id"]
		
	# Calculate all stats and cache them once
	character.recalculate_all_stats()
	
	SimulationManager.register_character(character)
	return character

func _apply_demographics(_char: CharacterData, context: GenerationContext, overrides: Dictionary) -> void:
	_char.gender = overrides.get("gender", randi() % 3)
	
	# Inherit culture from sect if generating a sect member, otherwise roll from world proportions
	if overrides.has("culture"):
		_char.culture = overrides["culture"]
	elif overrides.has("sect_id"):
		var parent_sect = SimulationManager.get_sect(overrides["sect_id"])
		_char.culture = parent_sect.culture if parent_sect else _roll_world_culture()
	else:
		_char.culture = _roll_world_culture()
	
	# Select name pool from the character's own culture
	var culture_key = Definitions.Culture.keys()[_char.culture]
	var pools = DataManager.name_pools.get("cultures", {}).get(culture_key, {})
	if pools.is_empty():
		pools = DataManager.name_pools.get("cultures", {}).get("CENTRAL_PLAINS", {})
	if pools.is_empty(): return
	
	if _char.gender == Definitions.Gender.FEMALE:
		_char.first_name = overrides.get("first_name", pools.get("female_given", []).pick_random())
	elif _char.gender == Definitions.Gender.MALE:
		_char.first_name = overrides.get("first_name", pools.get("male_given", []).pick_random())
	else:
		# NON_BINARY / NON_HUMAN: draw from whichever pool is non-empty, or combine both
		var combined: Array = pools.get("male_given", []) + pools.get("female_given", [])
		_char.first_name = overrides.get("first_name", combined.pick_random() if not combined.is_empty() else "Unknown")
		
	_char.last_name = overrides.get("last_name", pools.get("surnames", []).pick_random())
	
	match context:
		GenerationContext.BIRTH: _char.age = 0
		GenerationContext.RECRUIT_COMMON: _char.age = randi_range(14, 20)
		GenerationContext.WORLD_GEN_MARTIAL: _char.age = _get_weighted_age_roll()
		GenerationContext.WORLD_GEN_PEASANT: _char.age = _get_weighted_age_roll()
		GenerationContext.SECT_MEMBER: _char.age = overrides.get("age", randi_range(16, 60))
		_: _char.age = overrides.get("age", randi_range(18, 40))

## Returns a culture enum value weighted toward Central Plains with smaller populations elsewhere.
func _roll_world_culture() -> int:
	# Weighted distribution: Central Plains 40%, others ~12% each
	var roll = randi_range(0, 99)
	if roll < 40: return Definitions.Culture.CENTRAL_PLAINS
	elif roll < 52: return Definitions.Culture.JIANGNAN
	elif roll < 64: return Definitions.Culture.SICHUAN
	elif roll < 76: return Definitions.Culture.LINGNAN
	elif roll < 88: return Definitions.Culture.NORTHERN_BORDER
	else: return Definitions.Culture.WESTERN_REGIONS

func _apply_talents(_char: CharacterData, context: GenerationContext, _overrides: Dictionary) -> void:
	# 1. Roll Realm
	var roll = randf()
	if context == GenerationContext.RECRUIT_ELITE: roll *= 0.5 
		
	if roll < 0.05: _char.current_realm = Definitions.MartialRealm.FIRST_RATE
	elif roll < 0.2: _char.current_realm = Definitions.MartialRealm.SECOND_RATE
	else: _char.current_realm = Definitions.MartialRealm.THIRD_RATE
	
	# 2. Roll Innate Aptitude (The "Martial Skeleton")
	var apt_roll = randf()
	if apt_roll < 0.01: _char.aptitude = Definitions.Aptitude.HEAVEN_SENT
	elif apt_roll < 0.05: _char.aptitude = Definitions.Aptitude.ENLIGHTENED
	elif apt_roll < 0.15: _char.aptitude = Definitions.Aptitude.GENIUS
	elif apt_roll < 0.40: 
		# 50/50 chance for physical or agility focus
		_char.aptitude = Definitions.Aptitude.STURDY if randf() > 0.5 else Definitions.Aptitude.FLEXIBLE
	elif apt_roll < 0.90: _char.aptitude = Definitions.Aptitude.MEDIOCRE
	else: _char.aptitude = Definitions.Aptitude.WITHERED

func _apply_personality_and_traits(_char: CharacterData, context: GenerationContext, overrides: Dictionary) -> void:
	# 1. Initialize base continuous axes (0-100)
	var all_axes = Definitions.PERSONALITY_STATS + Definitions.ALIGNMENT_STATS
	for p_name in all_axes:
		# Reputation is handled separately based on Martial Realm
		if p_name == "reputation":
			continue
			
		var base = 50
		if context == GenerationContext.BIRTH and overrides.has("parent_personalities"):
			base = overrides["parent_personalities"].get(p_name, 50) + randi_range(-30, 30)
		else:
			base = randi_range(30, 70) # Tighter grouping so traits have more impact
			
		if p_name in Definitions.PERSONALITY_STATS:
			_char.personality_values[p_name] = clampi(base, 0, 100)
		else:
			_char.alignment_values[p_name] = clampi(base, 0, 100)

	# Setup Reputation based on their generated realm
	_char.alignment_values["reputation"] = _roll_reputation_by_realm(_char.current_realm)

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

## Generates a starting reputation strictly based on the character's martial standing
func _roll_reputation_by_realm(realm: int) -> int:
	match realm:
		Definitions.MartialRealm.UNINITIATED: return 0
		Definitions.MartialRealm.THIRD_RATE: return randi_range(0, 10)
		Definitions.MartialRealm.SECOND_RATE: return randi_range(10, 30)
		Definitions.MartialRealm.FIRST_RATE: return randi_range(30, 50)
		Definitions.MartialRealm.PEAK_MASTER: return randi_range(50, 70)
		Definitions.MartialRealm.GRANDMASTER: return randi_range(70, 90)
		Definitions.MartialRealm.TRANSCENDENT: return randi_range(80, 100)
		Definitions.MartialRealm.SUMMIT: return randi_range(90, 100)
		_: return 0

## Helper to assign traits while checking conflicts
## Optimized to prevent array duplication and shuffling per character.
func _assign_traits_from_pool(_char: CharacterData, pool: Array[String], amount: int) -> void:
	if pool.is_empty() or amount <= 0:
		return
		
	var attempts = 0
	var max_attempts = amount * 5 # Prevent infinite loops if valid traits are exhausted
	var applied = 0
	
	while applied < amount and attempts < max_attempts:
		attempts += 1
		var t_id = pool.pick_random()
		
		# Skip if we already have it
		if t_id in _char.traits:
			continue
			
		# Check conflicts
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
	# --- CORE STATS (Dictated by Age/Biology) ---
	var base_val = 10
	if _char.age <= 12: base_val = Definitions.BASE_STATS_BY_AGE["child"]
	elif _char.age <= 19: base_val = Definitions.BASE_STATS_BY_AGE["teen"]
	elif _char.age <= 60: base_val = Definitions.BASE_STATS_BY_AGE["adult"]
	else: base_val = Definitions.BASE_STATS_BY_AGE["elder"]
	
	for s in Definitions.Stat.values():
		_char.base_stats[s] = base_val + randi_range(-2, 5)

	# --- MARTIAL STATS ---
	if _char.is_martial_artist:
		roll_martial_awakening(_char)
		
## A public function so non-martials can have their martial stats generated 
## organically later in their life if an event triggers it.
func roll_martial_awakening(_char: CharacterData) -> void:
	var realm_tier = _char.current_realm
	var is_withered = _char.aptitude == Definitions.Aptitude.WITHERED
	
	for ms in Definitions.MartialStat.values():
		# 1. Destiny (Innate plot armor 1-100, ignores realm)
		if ms == Definitions.MartialStat.DESTINY:
			var destiny_val = randi_range(1, 100)
			if _char.aptitude == Definitions.Aptitude.HEAVEN_SENT: 
				destiny_val = maxi(destiny_val, randi_range(70, 100)) # Protagonist luck
			_char.base_martial[ms] = destiny_val
			continue
			
		# 2. Internal Force (Qi Pool scales exponentially with Realm)
		if ms == Definitions.MartialStat.INTERNAL_FORCE:
			if is_withered:
				_char.base_martial[ms] = randi_range(0, 10) # Blocked meridians
			else:
				_char.base_martial[ms] = (realm_tier * realm_tier * 100) + randi_range(10, 50 * maxi(1, realm_tier))
			continue

		# 3. Combat Skills (Linear scaling for Technique, Insight, Qinggong, etc.)
		var stat_val = (realm_tier * 15) + randi_range(0, 10)
		
		match _char.aptitude:
			Definitions.Aptitude.GENIUS:
				if ms == Definitions.MartialStat.TECHNIQUE: stat_val += 20
			Definitions.Aptitude.ENLIGHTENED:
				if ms == Definitions.MartialStat.INSIGHT or ms == Definitions.MartialStat.QI_FLOW: stat_val += 25
			Definitions.Aptitude.FLEXIBLE:
				if ms == Definitions.MartialStat.QINGGONG: stat_val += 20
			Definitions.Aptitude.HEAVEN_SENT:
				stat_val += 20 
				
		_char.base_martial[ms] = maxi(0, stat_val)

func _get_weighted_age_roll() -> int:
	var r = randf()
	if r < 0.6: return randi_range(16, 30)
	if r < 0.9: return randi_range(31, 60)
	return randi_range(61, 150)
