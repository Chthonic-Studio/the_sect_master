extends Node

## Generates the world's sects at the start of a new game.

enum SectTier { MINOR = 1, AVERAGE = 2, MAJOR = 3, HEGEMON = 4 }

func generate_world_sects(num_minor: int = 3, num_average: int = 2, num_major: int = 1) -> void:
	print("SectGenerator: Beginning World Generation...")
	
	_load_premade_sects()
	
	var dynamic_sects: Array[SectData] = []
	
	# Generate dynamically sized sects
	for i in range(num_minor):
		dynamic_sects.append(_generate_dynamic_sect(SectTier.MINOR))
	for i in range(num_average):
		dynamic_sects.append(_generate_dynamic_sect(SectTier.AVERAGE))
	for i in range(num_major):
		dynamic_sects.append(_generate_dynamic_sect(SectTier.MAJOR))
		
	_run_rival_matchmaker(dynamic_sects)
	
	print("SectGenerator: World Generation Complete. Generated ", SimulationManager.sect_repo.size(), " active sects.")

#region Generation Pipeline

func _load_premade_sects() -> void:
	for s_id in DataManager.premade_sects_registry:
		var data = DataManager.premade_sects_registry[s_id]
		var sect = SectData.new()
		
		sect.sect_id = data.get("id", "")
		sect.sect_name = data.get("name", "Unknown Sect")
		sect.alignment = data.get("alignment", Definitions.SectAlignment.NEUTRAL)
		sect.rival_sect_id = data.get("rival_sect_id", "")
		
		var res_data = data.get("resources", {})
		for r_key in res_data:
			var r_enum = Definitions.get_resource_enum(r_key)
			if r_enum != -1:
				sect.resources[r_enum] = res_data[r_key]
				
		var stat_data = data.get("stats", {})
		for s_key in stat_data:
			var s_enum = Definitions.get_sect_stat_enum(s_key)
			if s_enum != -1:
				sect.stats[s_enum] = stat_data[s_key]
				
		# Assuming premades have their tenets defined in JSON, otherwise empty
		if data.has("active_tenets"):
			sect.active_tenets.assign(data["active_tenets"])
				
		if data.has("relationships"):
			for target_id in data["relationships"]:
				var rel_value = int(data["relationships"][target_id])
				SimulationManager.set_sect_relationship(sect.sect_id, target_id, rel_value)
		
		# Add pre-built buildings
		if data.has("completed_buildings"):
			for b_id in data["completed_buildings"]:
				if DataManager.buildings_registry.has(b_id):
					sect.completed_buildings.append(b_id)
			sect.recalculate_sect_tags() # Ensure tags activate immediately
			
		_assign_starting_laws(sect)
		SimulationManager.register_sect(sect)
		_populate_sect(sect, randi_range(20, 40))

## Spawns a sect, allowing specific parameters to be forced via the overrides Dictionary.
## Supported keys: "name" (String), "alignment" (int), "tenets" (Array[String]), 
## "resources" (Dictionary), "laws" (Dictionary), "members_count" (int)
func generate_custom_sect(tier: SectTier, overrides: Dictionary = {}) -> SectData:
	var sect = SectData.new()
	
	# 1. Alignment
	if overrides.has("alignment"):
		sect.alignment = overrides["alignment"]
	else:
		sect.alignment = Definitions.SectAlignment.values().pick_random()
		
	_roll_sect_stats(sect) # Establish baseline face/reputation/karma
	
	# 2. Tenets
	if overrides.has("tenets"):
		sect.active_tenets.assign(overrides["tenets"])
	else:
		_roll_tenets(sect, int(tier))
		
	# 3. Name
	if overrides.has("name"):
		sect.sect_name = overrides["name"]
	else:
		sect.sect_name = _generate_sect_name(sect)
		
	# 4. Resources
	if overrides.has("resources"):
		for res_enum in overrides["resources"]:
			sect.resources[res_enum] = overrides["resources"][res_enum]
	else:
		var mult = int(tier)
		sect.resources[Definitions.ResourceType.WEALTH] = randi_range(100 * mult, 500 * mult)
		sect.resources[Definitions.ResourceType.MATERIALS] = randi_range(200 * mult, 600 * mult)
		sect.resources[Definitions.ResourceType.MEDICINE] = randi_range(50 * mult, 150 * mult)
		sect.resources[Definitions.ResourceType.ELIXIRS] = randi_range(0, 5 * mult)
		
	# 5. Laws
	_assign_starting_laws(sect)
	if overrides.has("laws"):
		for law_id in overrides["laws"]:
			# Note: During gameplay, we'd use sect.change_law(), but during 
			# generation we just inject it directly to save processing time.
			sect.active_laws[law_id] = overrides["laws"][law_id]
			
	SimulationManager.register_sect(sect)
	
	# 6. Population
	var starting_size = overrides.get("members_count", randi_range(10 * int(tier), 20 * int(tier)))
	_populate_sect(sect, starting_size)
	
	return sect

func _generate_dynamic_sect(tier: SectTier) -> SectData:
	return generate_custom_sect(tier, {})

func _roll_tenets(sect: SectData, amount: int) -> void:
	var alignment_string = Definitions.SectAlignment.keys()[sect.alignment]
	var valid_tenets = []
	
	for t_id in DataManager.tenets_registry:
		var tenet = DataManager.tenets_registry[t_id]
		if alignment_string in tenet.get("allowed_alignments", []):
			valid_tenets.append(t_id)
			
	valid_tenets.shuffle()
	
	for i in range(min(amount, valid_tenets.size())):
		sect.active_tenets.append(valid_tenets[i])

func _generate_sect_name(sect: SectData) -> String:
	var name_db = DataManager.sect_names_registry
	if name_db.is_empty():
		return "Unnamed Sect"
		
	var pool_prefixes: Array[String] = []
	var pool_nouns: Array[String] = []
	var pool_suffixes: Array[String] = []
	
	# 1. Add Base Words
	var base = name_db.get("base", {})
	pool_prefixes.append_array(base.get("prefixes", []))
	pool_nouns.append_array(base.get("nouns", []))
	pool_suffixes.append_array(base.get("suffixes", []))
	
	# 2. Add Alignment Words
	var align_str = Definitions.SectAlignment.keys()[sect.alignment]
	var align_db = name_db.get("alignments", {}).get(align_str, {})
	pool_prefixes.append_array(align_db.get("prefixes", []))
	pool_nouns.append_array(align_db.get("nouns", []))
	pool_suffixes.append_array(align_db.get("suffixes", []))
	
	# 3. Add Tenet Specific Words
	for t_id in sect.active_tenets:
		var t_data = DataManager.tenets_registry.get(t_id, {})
		var contributions = t_data.get("name_contributions", {})
		
		# Tenet words are added multiple times to artificially weight them 
		# so the sect is highly likely to reflect its core belief in its name!
		for i in range(3): 
			pool_prefixes.append_array(contributions.get("prefixes", []))
			pool_nouns.append_array(contributions.get("nouns", []))
			pool_suffixes.append_array(contributions.get("suffixes", []))

	# Fallbacks in case pools are empty
	if pool_prefixes.is_empty(): pool_prefixes.append("Mystic")
	if pool_nouns.is_empty(): pool_nouns.append("Lotus")
	if pool_suffixes.is_empty(): pool_suffixes.append("Sect")
	
	return "%s %s %s" % [pool_prefixes.pick_random(), pool_nouns.pick_random(), pool_suffixes.pick_random()]

func _roll_sect_stats(sect: SectData) -> void:
	sect.stats[Definitions.SectStat.FACE] = randi_range(10, 50)
	
	match sect.alignment:
		Definitions.SectAlignment.ORTHODOX:
			sect.stats[Definitions.SectStat.REPUTATION] = randi_range(60, 100)
			sect.stats[Definitions.SectStat.KARMA] = randi_range(60, 100)
		Definitions.SectAlignment.DEMONIC, Definitions.SectAlignment.EVIL:
			sect.stats[Definitions.SectStat.REPUTATION] = randi_range(0, 30)
			sect.stats[Definitions.SectStat.KARMA] = randi_range(0, 30)
		_:
			sect.stats[Definitions.SectStat.REPUTATION] = randi_range(30, 70)
			sect.stats[Definitions.SectStat.KARMA] = randi_range(30, 70)
	
		
func _assign_starting_laws(sect: SectData) -> void:
	
	for law_id in DataManager.sect_laws_registry:
		var law_data = DataManager.sect_laws_registry[law_id]
		var default_opt = law_data.get("default_option", "")
		if default_opt != "":
			sect.active_laws[law_id] = default_opt

#endregion

#region Population & Hierarchy
# -- Keep EXACTLY the same _populate_sect() as the previous snippet --
func _populate_sect(sect: SectData, total_members: int) -> void:
	var master = CharacterGenerator.create_character(CharacterGenerator.GenerationContext.SECT_MEMBER, {
		"sect_id": sect.sect_id, "age": randi_range(50, 90)
	})
	master.current_realm = randi_range(Definitions.MartialRealm.PEAK_MASTER, Definitions.MartialRealm.GRANDMASTER)
	master.recalculate_all_stats()
	sect.add_member(master.char_id, Definitions.SectRank.SECT_MASTER, "sect_master")
	
	var num_elders = maxi(1, int(total_members / 10.0))
	for i in range(num_elders):
		var elder = CharacterGenerator.create_character(CharacterGenerator.GenerationContext.SECT_MEMBER, {
			"sect_id": sect.sect_id, "age": randi_range(40, 80)
		})
		elder.current_realm = randi_range(Definitions.MartialRealm.FIRST_RATE, Definitions.MartialRealm.PEAK_MASTER)
		elder.recalculate_all_stats()
		sect.add_member(elder.char_id, Definitions.SectRank.ELDER, "elder")
		total_members -= 1
		
	for i in range(total_members - 1):
		var disciple = CharacterGenerator.create_character(CharacterGenerator.GenerationContext.SECT_MEMBER, {
			"sect_id": sect.sect_id, "age": randi_range(16, 35)
		})
		var rank = Definitions.SectRank.OUTER_DISCIPLE
		if disciple.current_realm >= Definitions.MartialRealm.SECOND_RATE:
			rank = Definitions.SectRank.INNER_DISCIPLE
		elif disciple.current_realm >= Definitions.MartialRealm.FIRST_RATE:
			rank = Definitions.SectRank.CORE_DISCIPLE
		sect.add_member(disciple.char_id, rank)

	sect.recalculate_sect_strength()
#endregion

#region Rival Matchmaker
# -- Keep EXACTLY the same Rival Matchmaker block as the previous snippet --
func _run_rival_matchmaker(dynamic_sects: Array[SectData]) -> void:
	var unassigned: Array[SectData] = dynamic_sects.duplicate()
	unassigned.shuffle() 
	
	while unassigned.size() >= 2:
		var current = unassigned.pop_back()
		var best_rival: SectData = null
		var highest_friction_score: float = -1.0
		
		for potential in unassigned:
			var friction = _calculate_sect_friction(current, potential)
			if friction > highest_friction_score:
				highest_friction_score = friction
				best_rival = potential
				
		if best_rival:
			current.rival_sect_id = best_rival.sect_id
			best_rival.rival_sect_id = current.sect_id
			
			SimulationManager.set_sect_relationship(current.sect_id, best_rival.sect_id, -100)
			
			unassigned.erase(best_rival)

func _calculate_sect_friction(sect_a: SectData, sect_b: SectData) -> float:
	var friction: float = 0.0
	var align_a = sect_a.alignment
	var align_b = sect_b.alignment
	
	if align_a != align_b:
		friction += 50.0 
		if (align_a == Definitions.SectAlignment.ORTHODOX and (align_b == Definitions.SectAlignment.DEMONIC or align_b == Definitions.SectAlignment.EVIL)) or \
		   (align_b == Definitions.SectAlignment.ORTHODOX and (align_a == Definitions.SectAlignment.DEMONIC or align_a == Definitions.SectAlignment.EVIL)):
			friction += 100.0
			
	var rep_diff = abs(sect_a.stats.get(Definitions.SectStat.REPUTATION, 50) - sect_b.stats.get(Definitions.SectStat.REPUTATION, 50))
	friction += rep_diff
	return friction
#endregion
