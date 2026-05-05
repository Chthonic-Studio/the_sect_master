extends Node

## Generates the world's sects at the start of a new game.
## Province-based generation: after loading premade sects, each province
## is populated with a big sect (if absent), 2-5 medium sects, and 3-7 small sects.
## Counts are inversely proportional to the dominant regional reputation.

## Emitted at major world-generation milestones so a loading screen can display progress.
signal generation_progress(stage: String, percent: float)

enum SectTier { MINOR = 1, AVERAGE = 2, MAJOR = 3, HEGEMON = 4 }

# Reputation thresholds used to classify sects by effective tier
const REP_MAJOR_THRESHOLD   := 70
const REP_AVERAGE_THRESHOLD := 40

func generate_world_sects() -> void:
	print("SectGenerator: Beginning World Generation...")
	generation_progress.emit("Loading historical sects...", 0.0)
	await Engine.get_main_loop().process_frame
	_load_premade_sects()

	generation_progress.emit("Populating the realm...", 0.25)
	await Engine.get_main_loop().process_frame
	var dynamic_sects := _populate_all_provinces()

	generation_progress.emit("Weaving the web of rivalries...", 0.85)
	await Engine.get_main_loop().process_frame
	_run_rival_matchmaker(dynamic_sects)

	generation_progress.emit("World generation complete.", 1.0)
	print("SectGenerator: World Generation Complete. Generated ",
		SimulationManager.sect_repo.size(), " active sects.")

#region Generation Pipeline

func _load_premade_sects() -> void:
	for s_id in DataManager.premade_sects_registry:
		var data = DataManager.premade_sects_registry[s_id]
		var sect = SectData.new()

		sect.sect_id       = data.get("id", "")
		sect.sect_name     = data.get("name", "Unknown Sect")
		sect.alignment     = data.get("alignment", Definitions.SectAlignment.NEUTRAL)
		sect.culture       = data.get("culture", Definitions.Culture.CENTRAL_PLAINS)
		sect.org_type      = data.get("org_type", Definitions.OrgType.SECT)
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

		if data.has("active_tenets"):
			sect.active_tenets.assign(data["active_tenets"])

		if data.has("relationships"):
			for target_id in data["relationships"]:
				SimulationManager.set_sect_relationship(sect.sect_id, target_id,
					int(data["relationships"][target_id]))

		if data.has("completed_buildings"):
			for b_id in data["completed_buildings"]:
				if DataManager.buildings_registry.has(b_id):
					sect.completed_buildings.append(b_id)
			sect.recalculate_sect_tags()

		_assign_starting_laws(sect)
		SimulationManager.register_sect(sect)
		_populate_sect(sect, randi_range(20, 40))

		# Province placement: use explicit province_id from JSON, else pick by culture
		if not DataManager.provinces_registry.is_empty():
			var province: String = data.get("province_id", "")
			if province == "":
				province = _pick_province_for_culture(sect.culture)
			if province != "":
				sect.province_id = province
				MapManager.assign_sect_to_province(sect.sect_id, province)

# -- Province Population --------------------------------------------------

## Iterates every known province and generates sects to populate it.
## Returns all dynamically generated sects for rival matchmaking.
func _populate_all_provinces() -> Array[SectData]:
	var dynamic: Array[SectData] = []
	for province_id in DataManager.provinces_registry:
		dynamic.append_array(_populate_province(province_id))
	return dynamic

## Generates sects for a single province. Returns the newly created sects.
func _populate_province(province_id: String) -> Array[SectData]:
	var region_id := MapManager.get_region_for_province(province_id)
	var region_data: Dictionary = DataManager.regions_registry.get(region_id, {})
	var culture_key: String = region_data.get("culture", "CENTRAL_PLAINS")
	var culture_val: int = Definitions.Culture.get(culture_key, Definitions.Culture.CENTRAL_PLAINS)

	# Strength factor: 0.0 (no dominant sect) -> 1.0 (max 100 rep)
	var region_max_rep := _get_region_max_reputation(region_id)
	var strength_factor := region_max_rep / 100.0

	# Classify sects already in this province
	var existing := _classify_province_sects(province_id)
	var spawned: Array[SectData] = []

	# 1. Big sect: spawn if none exists; probability inversely scaled by regional strength
	if existing["major"] == 0:
		var spawn_chance := 1.0 - strength_factor
		if randf() < spawn_chance:
			spawned.append(_generate_sect_in_province(SectTier.MAJOR, province_id, culture_val))

	# 2. Medium sects: 2-5 target, reduced by regional strength, minus existing
	var target_avg := roundi(lerpf(5.0, 2.0, strength_factor))
	var to_spawn_avg := maxi(0, target_avg - existing["average"])
	for _i in range(to_spawn_avg):
		spawned.append(_generate_sect_in_province(SectTier.AVERAGE, province_id, culture_val))

	# 3. Small sects: 3-7 target, minus existing
	var target_minor := randi_range(3, 7)
	var to_spawn_minor := maxi(0, target_minor - existing["minor"])
	for _i in range(to_spawn_minor):
		spawned.append(_generate_sect_in_province(SectTier.MINOR, province_id, culture_val))

	return spawned

## Returns the highest REPUTATION among all sects currently in the given region.
func _get_region_max_reputation(region_id: String) -> float:
	var max_rep := 0.0
	for s_id in MapManager.get_sects_in_region(region_id):
		var sect: SectData = SimulationManager.sect_repo.get(s_id)
		if sect:
			max_rep = maxf(max_rep, float(sect.stats.get(Definitions.SectStat.REPUTATION, 0)))
	return max_rep

## Counts existing sects in a province by effective tier (based on REPUTATION).
func _classify_province_sects(province_id: String) -> Dictionary:
	var counts := {"major": 0, "average": 0, "minor": 0}
	for s_id in MapManager.get_sects_in_province(province_id):
		var sect: SectData = SimulationManager.sect_repo.get(s_id)
		if sect:
			var rep: int = sect.stats.get(Definitions.SectStat.REPUTATION, 0)
			if rep >= REP_MAJOR_THRESHOLD:
				counts["major"] += 1
			elif rep >= REP_AVERAGE_THRESHOLD:
				counts["average"] += 1
			else:
				counts["minor"] += 1
	return counts

func _generate_sect_in_province(tier: SectTier, province_id: String, culture: int) -> SectData:
	return generate_custom_sect(tier, {"culture": culture, "province_id": province_id})

## Spawns a sect, allowing specific parameters to be forced via the overrides Dictionary.
## Supported keys: "name", "alignment", "culture", "org_type", "province_id",
##                 "tenets", "resources", "laws", "members_count"
func generate_custom_sect(tier: SectTier, overrides: Dictionary = {}) -> SectData:
	var sect := SectData.new()

	# 1. Alignment
	if overrides.has("alignment"):
		sect.alignment = overrides["alignment"]
	else:
		sect.alignment = Definitions.SectAlignment.values().pick_random()

	# 2. Culture
	if overrides.has("culture"):
		sect.culture = overrides["culture"]
	else:
		sect.culture = _roll_sect_culture()

	# 3. Org Type
	if overrides.has("org_type"):
		sect.org_type = overrides["org_type"]
	else:
		sect.org_type = Definitions.OrgType.SECT  # Default to Sect for generated factions

	_roll_sect_stats(sect)

	# 3. Tenets
	if overrides.has("tenets"):
		sect.active_tenets.assign(overrides["tenets"])
	else:
		_roll_tenets(sect, int(tier))

	# 4. Name
	if overrides.has("name"):
		sect.sect_name = overrides["name"]
	else:
		sect.sect_name = _generate_sect_name(sect)

	# 5. Resources
	if overrides.has("resources"):
		for res_enum in overrides["resources"]:
			sect.resources[res_enum] = overrides["resources"][res_enum]
	else:
		var mult := int(tier)
		sect.resources[Definitions.ResourceType.WEALTH]    = randi_range(100 * mult, 500 * mult)
		sect.resources[Definitions.ResourceType.MATERIALS] = randi_range(200 * mult, 600 * mult)
		sect.resources[Definitions.ResourceType.MEDICINE]  = randi_range(50 * mult, 150 * mult)
		sect.resources[Definitions.ResourceType.ELIXIRS]   = randi_range(0, 5 * mult)

	# 6. Laws
	_assign_starting_laws(sect)
	if overrides.has("laws"):
		for law_id in overrides["laws"]:
			sect.active_laws[law_id] = overrides["laws"][law_id]

	SimulationManager.register_sect(sect)

	# 7. Population
	var starting_size: int = overrides.get("members_count",
		randi_range(10 * int(tier), 20 * int(tier)))
	_populate_sect(sect, starting_size)

	# 8. Province placement: prefer explicit override, then culture-based pick
	if not DataManager.provinces_registry.is_empty():
		var province: String = overrides.get("province_id", "")
		if province == "":
			province = _pick_province_for_culture(sect.culture)
		if province != "":
			sect.province_id = province
			MapManager.assign_sect_to_province(sect.sect_id, province)

	sect.recalculate_sect_tags()
	return sect

## Picks a culture for a new dynamically-generated sect.
func _roll_sect_culture() -> int:
	var roll := randi_range(0, 99)
	if roll < 35:    return Definitions.Culture.CENTRAL_PLAINS
	elif roll < 47:  return Definitions.Culture.JIANGNAN
	elif roll < 59:  return Definitions.Culture.SICHUAN
	elif roll < 71:  return Definitions.Culture.LINGNAN
	elif roll < 82:  return Definitions.Culture.NORTHERN_BORDER
	elif roll < 93:  return Definitions.Culture.WESTERN_REGIONS
	else:            return Definitions.Culture.GORYEO

## Returns a province_id appropriate for the sect's culture (region match).
func _pick_province_for_culture(culture: int) -> String:
	const CULTURE_REGION := {
		Definitions.Culture.CENTRAL_PLAINS:  "central_plains",
		Definitions.Culture.JIANGNAN:        "jiangnan",
		Definitions.Culture.SICHUAN:         "sichuan",
		Definitions.Culture.LINGNAN:         "lingnan",
		Definitions.Culture.NORTHERN_BORDER: "northern_border",
		Definitions.Culture.WESTERN_REGIONS: "western_regions",
		Definitions.Culture.GORYEO:          "goryeo"
	}
	var region_id: String = CULTURE_REGION.get(culture, "central_plains")
	return MapManager.get_random_province(region_id)

func _roll_tenets(sect: SectData, amount: int) -> void:
	var alignment_string : String = Definitions.SectAlignment.keys()[sect.alignment]
	var valid_tenets := []
	for t_id in DataManager.tenets_registry:
		var tenet = DataManager.tenets_registry[t_id]
		if alignment_string in tenet.get("allowed_alignments", []):
			valid_tenets.append(t_id)
	valid_tenets.shuffle()
	for i in range(min(amount, valid_tenets.size())):
		sect.active_tenets.append(valid_tenets[i])
	sect.recalculate_sect_tags()

func _generate_sect_name(sect: SectData) -> String:
	var name_db := DataManager.sect_names_registry
	if name_db.is_empty():
		return "Unnamed Sect"

	var pool_prefixes: Array[String] = []
	var pool_nouns:    Array[String] = []
	var pool_suffixes: Array[String] = []

	var base = name_db.get("base", {})
	pool_prefixes.append_array(base.get("prefixes", []))
	pool_nouns.append_array(base.get("nouns", []))
	pool_suffixes.append_array(base.get("suffixes", []))

	var culture_str = Definitions.Culture.keys()[sect.culture]
	var culture_db  = name_db.get("cultures", {}).get(culture_str, {})
	pool_prefixes.append_array(culture_db.get("prefixes", []))
	pool_nouns.append_array(culture_db.get("nouns", []))
	pool_suffixes.append_array(culture_db.get("suffixes", []))

	var align_str = Definitions.SectAlignment.keys()[sect.alignment]
	var align_db  = name_db.get("alignments", {}).get(align_str, {})
	pool_prefixes.append_array(align_db.get("prefixes", []))
	pool_nouns.append_array(align_db.get("nouns", []))
	pool_suffixes.append_array(align_db.get("suffixes", []))

	for t_id in sect.active_tenets:
		var t_data = DataManager.tenets_registry.get(t_id, {})
		var contributions = t_data.get("name_contributions", {})
		for _i in range(3):
			pool_prefixes.append_array(contributions.get("prefixes", []))
			pool_nouns.append_array(contributions.get("nouns", []))
			pool_suffixes.append_array(contributions.get("suffixes", []))

	if pool_prefixes.is_empty(): pool_prefixes.append("Mystic")
	if pool_nouns.is_empty():    pool_nouns.append("Lotus")
	if pool_suffixes.is_empty():
		# Fallback ensures every generated name has a recognisable organisational suffix
		# even when no tenet/culture/alignment pools contribute suffix entries.
		match sect.org_type:
			Definitions.OrgType.CLAN: pool_suffixes.append("Clan")
			Definitions.OrgType.CULT: pool_suffixes.append("Cult")
			_:                        pool_suffixes.append("Sect")

	return "%s %s %s" % [pool_prefixes.pick_random(), pool_nouns.pick_random(), pool_suffixes.pick_random()]

func _roll_sect_stats(sect: SectData) -> void:
	sect.stats[Definitions.SectStat.FACE] = randi_range(10, 50)
	match sect.alignment:
		Definitions.SectAlignment.ORTHODOX:
			sect.stats[Definitions.SectStat.REPUTATION] = randi_range(60, 100)
			sect.stats[Definitions.SectStat.KARMA]      = randi_range(60, 100)
		Definitions.SectAlignment.DEMONIC, Definitions.SectAlignment.EVIL:
			sect.stats[Definitions.SectStat.REPUTATION] = randi_range(0, 30)
			sect.stats[Definitions.SectStat.KARMA]      = randi_range(0, 30)
		_:
			sect.stats[Definitions.SectStat.REPUTATION] = randi_range(30, 70)
			sect.stats[Definitions.SectStat.KARMA]      = randi_range(30, 70)

func _assign_starting_laws(sect: SectData) -> void:
	for law_id in DataManager.sect_laws_registry:
		var law_data = DataManager.sect_laws_registry[law_id]
		var default_opt: String = law_data.get("default_option", "")
		if default_opt != "":
			sect.active_laws[law_id] = default_opt
	sect.recalculate_sect_tags()

#endregion

#region Population & Hierarchy

func _populate_sect(sect: SectData, total_members: int) -> void:
	var master := CharacterGenerator.create_character(
		CharacterGenerator.GenerationContext.SECT_MEMBER,
		{"sect_id": sect.sect_id, "age": randi_range(50, 90)})
	master.current_realm = randi_range(Definitions.MartialRealm.PEAK_MASTER, Definitions.MartialRealm.GRANDMASTER)
	master.recalculate_all_stats()
	sect.add_member(master.char_id, Definitions.SectRank.SECT_MASTER, "sect_master")

	var num_elders := maxi(1, int(total_members / 10.0))
	for _i in range(num_elders):
		var elder := CharacterGenerator.create_character(
			CharacterGenerator.GenerationContext.SECT_MEMBER,
			{"sect_id": sect.sect_id, "age": randi_range(40, 80)})
		elder.current_realm = randi_range(Definitions.MartialRealm.FIRST_RATE, Definitions.MartialRealm.PEAK_MASTER)
		elder.recalculate_all_stats()
		sect.add_member(elder.char_id, Definitions.SectRank.ELDER, "elder")
		total_members -= 1

	for _i in range(total_members - 1):
		var disciple := CharacterGenerator.create_character(
			CharacterGenerator.GenerationContext.SECT_MEMBER,
			{"sect_id": sect.sect_id, "age": randi_range(16, 35)})
		var rank := Definitions.SectRank.OUTER_DISCIPLE
		if disciple.current_realm >= Definitions.MartialRealm.FIRST_RATE:
			rank = Definitions.SectRank.CORE_DISCIPLE
		elif disciple.current_realm >= Definitions.MartialRealm.SECOND_RATE:
			rank = Definitions.SectRank.INNER_DISCIPLE
		sect.add_member(disciple.char_id, rank)

	sect.recalculate_sect_strength()

#endregion

#region Rival Matchmaker

func _run_rival_matchmaker(dynamic_sects: Array[SectData]) -> void:
	var unassigned := dynamic_sects.duplicate()
	unassigned.shuffle()

	while unassigned.size() >= 2:
		var current: SectData = unassigned.pop_back()
		var best_rival: SectData = null
		var highest_friction := -1.0

		for potential in unassigned:
			var friction := _calculate_sect_friction(current, potential)
			if friction > highest_friction:
				highest_friction = friction
				best_rival = potential

		if best_rival:
			current.rival_sect_id = best_rival.sect_id
			best_rival.rival_sect_id = current.sect_id
			SimulationManager.set_sect_relationship(current.sect_id, best_rival.sect_id, -100)
			unassigned.erase(best_rival)

func _calculate_sect_friction(sect_a: SectData, sect_b: SectData) -> float:
	var friction := 0.0
	if sect_a.alignment != sect_b.alignment:
		friction += 50.0
		var a := sect_a.alignment
		var b := sect_b.alignment
		if (a == Definitions.SectAlignment.ORTHODOX and
			(b == Definitions.SectAlignment.DEMONIC or b == Definitions.SectAlignment.EVIL)) or \
		   (b == Definitions.SectAlignment.ORTHODOX and
			(a == Definitions.SectAlignment.DEMONIC or a == Definitions.SectAlignment.EVIL)):
			friction += 100.0
	var rep_diff = abs(
		sect_a.stats.get(Definitions.SectStat.REPUTATION, 50) -
		sect_b.stats.get(Definitions.SectStat.REPUTATION, 50))
	friction += rep_diff
	return friction

#endregion
