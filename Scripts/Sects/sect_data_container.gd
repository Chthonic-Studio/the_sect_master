extends RefCounted
class_name SectData

signal modifier_expired(sect: SectData, modifier_id: String)
signal strength_recalculated(sect: SectData)
signal building_completed(sect: SectData, building_id: String)
signal law_changed(sect: SectData, law_id: String, new_option_id: String)
signal tenet_added(sect: SectData, tenet_id: String)
signal tenet_removed(sect: SectData, tenet_id: String)

# --- IDENTITY ---
var sect_id: String = ""
var sect_name: String = "Unnamed Sect"
var alignment: int = Definitions.SectAlignment.NEUTRAL
var culture: int = Definitions.Culture.CENTRAL_PLAINS
var org_type: int = Definitions.OrgType.SECT  # SECT, CLAN, or CULT
var rival_sect_id: String = ""
var province_id: String = ""  # Geographic location on the world map

# --- MACRO STATS & ECONOMY ---
var resources: Dictionary = {}
var stats: Dictionary = {}
var cached_sect_strength: int = 0

# --- MEMBERSHIP (O(1) Lookups) ---
# We strictly store String char_ids to avoid circular references and memory leaks.
var all_members: Array[String] = []

# Dictionary mapping Definitions.SectRank to an Array of char_ids
var members_by_rank: Dictionary = {}

# Dictionary mapping String position names (e.g. "cook", "spymaster") to an Array of char_ids
var members_by_position: Dictionary = {}

# --- STATE & PROGRESSION ---
var active_laws: Dictionary = {} # e.g., { "elder_stipends": "lavish", "succession": "strongest" }
var completed_buildings: Array[String] = []
var active_modifiers: Array[Dictionary] = []
var active_tenets: Array[String] = [] 
var unlocked_tags: Array[String] = []
var active_proposals: Array[SectProposal] = []

# Array of Dictionaries tracking ongoing construction. 
# Format: {"building_id": String, "days_remaining": int}
var construction_queue: Array[Dictionary] = []

# --- AI RAID SCHEDULING ---
# Absolute day on which this sect will next evaluate a raid against its worst rival.
# -1 = uninitialized; will be staggered on the first daily tick to avoid all sects
# evaluating on the same day. After each evaluation the next day is set ~1 year later.
var next_raid_day: int = -1

func _init() -> void:
	_setup_default_dictionaries()

func _setup_default_dictionaries() -> void:
	for r in Definitions.ResourceType.values():
		resources[r] = 0
		
	for s in Definitions.SectStat.values():
		stats[s] = 50 # Default to neutral 50 for things like Reputation/Karma
		if s == Definitions.SectStat.FACE:
			stats[s] = 0 # Face starts at 0

	for rank in Definitions.SectRank.values():
		members_by_rank[rank] = []

# --- MEMBERSHIP MANAGEMENT ---

## Safely adds a character to the sect data structures and updates strength.
func add_member(char_id: String, rank: int, position: String = "") -> void:
	if not all_members.has(char_id):
		all_members.append(char_id)
	
	# Scrub the character from any existing rank arrays before assigning the new one
	for r in members_by_rank.keys():
		if members_by_rank[r].has(char_id):
			members_by_rank[r].erase(char_id)
			
	if not members_by_rank.has(rank):
		members_by_rank[rank] = []
	members_by_rank[rank].append(char_id)
		
	if position != "":
		assign_position(char_id, position)

	# Promote to MICRO when joining the player's sect
	if GameManager.player_sect_id != "" and sect_id == GameManager.player_sect_id:
		var c: CharacterData = SimulationManager.get_character(char_id)
		if c and c.is_alive and c.current_sim_tier != CharacterData.SimTier.FROZEN:
			c.transition_to_micro()

	flag_strength_dirty()

## Completely removes a character from the sect, clearing them from all categorized arrays.
func remove_member(char_id: String) -> void:
	all_members.erase(char_id)
	
	for rank in members_by_rank.keys():
		members_by_rank[rank].erase(char_id)
		
	for pos in members_by_position.keys():
		members_by_position[pos].erase(char_id)

	# Demote to MACRO when leaving the player's sect
	if GameManager.player_sect_id != "" and sect_id == GameManager.player_sect_id:
		var c: CharacterData = SimulationManager.get_character(char_id)
		if c and c.is_alive and c.current_sim_tier != CharacterData.SimTier.FROZEN:
			c.transition_to_macro()

	flag_strength_dirty()

## Assigns a sect job to a character. Removes them from their old job if they had one.
func assign_position(char_id: String, new_position: String) -> void:
	# First, remove them from any existing position
	for pos in members_by_position.keys():
		members_by_position[pos].erase(char_id)
		
	# Ensure the array exists for this job title
	if not members_by_position.has(new_position):
		members_by_position[new_position] = []
		
	members_by_position[new_position].append(char_id)
	
	# Note: AI Tag injection will happen in a higher-level manager or event, 
	# keeping this data container strictly decoupled from the Character objects.

# --- SIMULATION LOGIC ---

## We do not recalculate strength every time a member trains. 
## We set a flag, or do it on demand/monthly to save CPU.
func flag_strength_dirty() -> void:
	# For now, we will simply force recalculation, but in the future, 
	# this can be queued for the TimeManager's monthly tick.
	recalculate_sect_strength()

func recalculate_sect_strength() -> void:
	cached_sect_strength = 0
	# We query the SimulationManager to get the actual character objects safely
	for char_id in all_members:
		var character = SimulationManager.get_character(char_id)
		if character and character.is_alive:
			# A rough estimation of power: Realm tier * Base Internal Force
			var realm_mult = character.current_realm * 2
			cached_sect_strength += character.get_martial_stat(Definitions.MartialStat.INTERNAL_FORCE) * realm_mult
			
	strength_recalculated.emit(self)

## Processes the macro-level daily operations (Building and Modifiers)
func process_daily_tick(current_total_days: int) -> void:
	# 1. Process Modifiers Expiration
	if not active_modifiers.is_empty():
		var expired_ids: Array[String] = []
		for i in range(active_modifiers.size() - 1, -1, -1):
			if active_modifiers[i]["expiration_day"] <= current_total_days:
				expired_ids.append(active_modifiers[i]["id"])
				active_modifiers.remove_at(i)
				
		for mod_id in expired_ids:
			modifier_expired.emit(self, mod_id)
			# Re-eval economic bonuses if a sect-wide buff expires

	# 2. Process Construction Queue
	if not construction_queue.is_empty():
		var current_project = construction_queue[0]
		current_project["days_remaining"] -= 1
		
		if current_project["days_remaining"] <= 0:
			var finished_building = current_project["building_id"]
			
			# Handle replacing buildings
			var b_data = DataManager.buildings_registry.get(finished_building, {})
			var replaces = b_data.get("replaces", "")
			if replaces != "" and completed_buildings.has(replaces):
				completed_buildings.erase(replaces)
			
			completed_buildings.append(finished_building)
			construction_queue.remove_at(0)
			recalculate_sect_tags() # Update capabilities immediately
			building_completed.emit(self, finished_building)
			
	# 3. Process Political Proposals
	if not active_proposals.is_empty():
		for i in range(active_proposals.size() - 1, -1, -1):
			var proposal = active_proposals[i]
			proposal.process_daily_tick(self)
			if proposal.days_remaining <= 0:
				active_proposals.remove_at(i)

	# 4. Yearly AI raid evaluation for non-player sects
	if GameManager.player_sect_id != sect_id:
		if next_raid_day < 0:
			# First-time stagger: spread all sects across the first year so they don't
			# all evaluate on the same day.
			next_raid_day = current_total_days + randi_range(1, 360)
		elif current_total_days >= next_raid_day:
			_evaluate_yearly_raid()
			# Schedule next raid evaluation approximately one year from now, with jitter
			# so raids feel organic and never cluster on the 1st of a month.
			next_raid_day = current_total_days + randi_range(320, 400)

## Adds a predefined temporary macro-modifier (e.g. "+20% pill production for 30 days").
func add_temporary_modifier(modifier_id: String, duration_days: int) -> void:
	# Validation check against a registry will go here in Phase 2
	var expiration = TimeManager.get_total_days_elapsed() + duration_days
	
	for mod in active_modifiers:
		if mod["id"] == modifier_id:
			mod["expiration_day"] = maxi(mod["expiration_day"], expiration)
			return
			
	active_modifiers.append({
		"id": modifier_id,
		"expiration_day": expiration
	})

func get_relationship(other_sect_id: String) -> int:
	return SimulationManager.get_sect_relationship(self.sect_id, other_sect_id)


#region Progression & Mutators

## Safely attempts to change a sect law. Returns true if successful.
func change_law(law_id: String, new_option_id: String) -> bool:
	if not DataManager.sect_laws_registry.has(law_id):
		printerr("SectData: Attempted to change invalid law ID: ", law_id)
		return false
		
	var law_data = DataManager.sect_laws_registry[law_id]
	var options = law_data.get("options", {})
	
	if not options.has(new_option_id):
		printerr("SectData: Invalid option '", new_option_id, "' for law '", law_id, "'")
		return false
		
	# --- FUTURE EXPANSION HOOK ---
	# Here is where we will check `options[new_option_id].get("prerequisites")`
	# against the Sect's alignment or stats before allowing the change.
	
	active_laws[law_id] = new_option_id
	law_changed.emit(self, law_id, new_option_id)
	
	# If a law changes Elder stipends, the economic ledger will naturally 
	# read the new value on the next monthly tick.
	return true

## Safely adds a tenet if the sect's alignment permits it.
func add_tenet(tenet_id: String) -> bool:
	if active_tenets.has(tenet_id):
		return false
		
	if not DataManager.tenets_registry.has(tenet_id):
		return false
		
	var tenet_data = DataManager.tenets_registry[tenet_id]
	var alignment_str = Definitions.SectAlignment.keys()[alignment]
	
	if not alignment_str in tenet_data.get("allowed_alignments", []):
		printerr("SectData: Cannot add tenet '", tenet_id, "'. Invalid alignment.")
		return false
		
	active_tenets.append(tenet_id)
	tenet_added.emit(self, tenet_id)
	
	# Note: Adding a tenet does NOT change the sect's name automatically, 
	# just like changing religion in CK3 doesn't rename your empire.
	return true

## Safely removes a tenet.
func remove_tenet(tenet_id: String) -> void:
	if active_tenets.has(tenet_id):
		active_tenets.erase(tenet_id)
		tenet_removed.emit(self, tenet_id)

#endregion

#region Economy & Macro-Tick

func process_monthly_tick() -> void:
	var deltas = get_projected_monthly_deltas()
	
	for r_enum in deltas:
		resources[r_enum] += deltas[r_enum]
		
		# Prevent negative resources and apply bankruptcy penalties
		if resources[r_enum] < 0:
			resources[r_enum] = 0
			
			# If a sect goes bankrupt on Wealth, they lose Face in the Jianghu
			if r_enum == Definitions.ResourceType.WEALTH:
				stats[Definitions.SectStat.FACE] = clampi(stats[Definitions.SectStat.FACE] - 5, 0, 100)

	# AI macro behaviour for non-player sects
	if GameManager.player_sect_id != sect_id:
		_process_ai_monthly_tick()

## Calculates the net income/expenses for the sect. 
## Separated from the tick so the UI can safely read it for tooltips.
func get_projected_monthly_deltas() -> Dictionary:
	var deltas: Dictionary = {}
	for r in Definitions.ResourceType.values():
		deltas[r] = 0
		
	# 1. Process Completed Buildings (Yields and Upkeeps)
	for b_id in completed_buildings:
		var b_data = DataManager.buildings_registry.get(b_id, {})
		
		var yields = b_data.get("yields", {})
		for res_key in yields:
			var r_enum = Definitions.get_resource_enum(res_key)
			if r_enum != -1: 
				deltas[r_enum] += yields[res_key]
				
		var upkeep = b_data.get("monthly_upkeep", {})
		for res_key in upkeep:
			var r_enum = Definitions.get_resource_enum(res_key)
			if r_enum != -1: 
				deltas[r_enum] -= upkeep[res_key]
				
	# 2. Process Laws (Elder Stipends)
	var elder_stipend_opt = active_laws.get("elder_stipends", "")
	if elder_stipend_opt != "":
		var law_data = DataManager.sect_laws_registry.get("elder_stipends", {})
		var opt_data = law_data.get("options", {}).get(elder_stipend_opt, {})
		
		var cost_per_elder = opt_data.get("cost_per_elder", 0)
		var num_elders = members_by_rank.get(Definitions.SectRank.ELDER, []).size()
		
		deltas[Definitions.ResourceType.WEALTH] -= (cost_per_elder * num_elders)
		
	# 3. Base income: disciples contribute monthly dues to the sect.
	# Elders and masters are excluded here — their costs are covered by the elder_stipends law.
	# Value: 3 gold/month per disciple is calibrated so a sect of 20 members (with ~2 elders and
	# 17 disciples) earns ~51 gold/month before upkeep, covering basic operational costs.
	const DISCIPLE_MONTHLY_DUES: int = 3
	var disciple_ranks: Array = [
		Definitions.SectRank.OUTER_DISCIPLE,
		Definitions.SectRank.INNER_DISCIPLE,
		Definitions.SectRank.CORE_DISCIPLE,
	]
	var total_disciples: int = 0
	for rank in disciple_ranks:
		total_disciples += members_by_rank.get(rank, []).size()
	deltas[Definitions.ResourceType.WEALTH] += total_disciples * DISCIPLE_MONTHLY_DUES
		
	return deltas

## AI monthly decision loop for non-player sects.
## Simple probability rolls that modify sect relationships and member counts.
func _process_ai_monthly_tick() -> void:
	var all_sect_ids = SimulationManager.sect_repo.keys()

	# 1. desire_macro_expand: recruit from world population
	# TODO: spawn a new CharacterData and add them once world population API is available

	# 2. desire_macro_seek_alliance: improve relation with neutral neighbour (~10% monthly)
	if randf() < 0.10:
		var neutral_id = ""
		for s_id in all_sect_ids:
			if s_id == sect_id: continue
			var rel = SimulationManager.get_sect_relationship(sect_id, s_id)
			if absf(rel) < 30:
				neutral_id = s_id
				break
		if neutral_id != "":
			SimulationManager.modify_sect_relationship(sect_id, neutral_id, randi_range(3, 8))

## Yearly AI raid evaluation — called from process_daily_tick on the pre-scheduled raid day.
## Checks whether this sect has a clear rival to strike, then resolves the raid outcome.
func _evaluate_yearly_raid() -> void:
	# Minimum relationship score required for a sect to consider raiding.
	# Must be hostile enough to justify the risk (-75 or worse on a -100..100 scale).
	const RAID_RELATIONSHIP_THRESHOLD: int = -75

	# 75% chance to skip this evaluation entirely — raids should be rare, not constant.
	if randf() > 0.25:
		return

	var all_sect_ids = SimulationManager.sect_repo.keys()
	var worst_rel = 0
	var worst_id = ""
	for s_id in all_sect_ids:
		if s_id == sect_id: continue
		var rel = SimulationManager.get_sect_relationship(sect_id, s_id)
		if rel < worst_rel:
			worst_rel = rel
			worst_id = s_id

	if worst_id == "" or worst_rel > RAID_RELATIONSHIP_THRESHOLD:
		return  # No sufficiently hostile rival to raid this year

	var target_sect = SimulationManager.get_sect(worst_id)
	if not target_sect:
		return

	# If the target is the player's sect, present the player with a decision event.
	# initiator = player character (the responder), target = attacker's sect master.
	if worst_id == GameManager.player_sect_id:
		var player_char_id = GameManager.player_char_id
		var attacker_master_ids: Array = members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
		var attacker_master_id: String = attacker_master_ids[0] if not attacker_master_ids.is_empty() else ""
		var event_context := {
			"initiator": player_char_id,
			"initiator_sect": worst_id,
			"target_sect": sect_id
		}
		if attacker_master_id != "":
			event_context["target"] = attacker_master_id
		EventManager.trigger_event("raid_incoming", event_context)
		return

	# AI-vs-AI raid: resolve based on strength comparison
	# The defending sect master's personality determines how they respond.
	var defender_master_ids: Array = target_sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
	var defender_master: CharacterData = null
	if not defender_master_ids.is_empty():
		defender_master = SimulationManager.get_character(defender_master_ids[0])

	# Determine defender response based on personality if a master exists
	var defender_fights_back: bool = true
	if defender_master:
		var honor: float = defender_master.get_personality_value("honor")
		var ruthlessness: float = defender_master.get_personality_value("ruthlessness")
		var cunning: float = defender_master.get_personality_value("cunning")
		# Diplomatic/cunning masters prefer negotiation over direct defense
		if cunning > 65 and honor < 50:
			defender_fights_back = false
		elif honor > 70:
			defender_fights_back = true

	# Raid outcome: compare member count + reputation as a simple strength proxy
	var attacker_str = all_members.size() + stats.get(Definitions.SectStat.REPUTATION, 0)
	var defender_str = target_sect.all_members.size() + target_sect.stats.get(Definitions.SectStat.REPUTATION, 0)
	if defender_fights_back and attacker_str > defender_str * 0.8:
		# Attacker wins: gain Face, target loses
		stats[Definitions.SectStat.FACE] = clampi(stats.get(Definitions.SectStat.FACE, 0) + 8, 0, 100)
		target_sect.stats[Definitions.SectStat.FACE] = clampi(target_sect.stats.get(Definitions.SectStat.FACE, 0) - 8, 0, 100)
		WorldLogManager.add_log("war", sect_name + " launched a raid on " + target_sect.sect_name + " and emerged victorious!")
	elif not defender_fights_back:
		# Defender chose to negotiate or stand down
		SimulationManager.modify_sect_relationship(sect_id, worst_id, 5)
		WorldLogManager.add_log("war", target_sect.sect_name + " negotiated a swift resolution to " + sect_name + "'s raid, avoiding full conflict.")
	else:
		# Attacker repelled
		stats[Definitions.SectStat.FACE] = clampi(stats.get(Definitions.SectStat.FACE, 0) - 5, 0, 100)
		WorldLogManager.add_log("war", sect_name + " launched a raid on " + target_sect.sect_name + " but was repelled.")

#endregion

#region Politics & Proposals

## Checks if the sect has a specific systemic flag (e.g. "absolute_authority")
## It scans both active tenets and the selected options of active laws.
func has_sect_flag(flag_name: String) -> bool:
	# 1. Check Tenets
	for t_id in active_tenets:
		var t_data = DataManager.tenets_registry.get(t_id, {})
		if flag_name in t_data.get("flags", []):
			return true
			
	# 2. Check Laws
	for law_id in active_laws:
		var option_id = active_laws[law_id]
		var law_data = DataManager.sect_laws_registry.get(law_id, {})
		var opt_data = law_data.get("options", {}).get(option_id, {})
		if flag_name in opt_data.get("flags", []):
			return true
			
	return false

## The new unified entry point for Sect Actions (Law changes, War, etc.)
func propose_action(action_type: String, payload: Dictionary) -> void:
	# If the master has absolute authority, bypass the council entirely
	if has_sect_flag("absolute_authority"):
		_execute_proposal_action(action_type, payload)
		# TODO: Notify UIManager/WorldLog that the Master decreed something unilaterally
		return
		
	# Otherwise, we must consult the Elders
	var elders: Array[String] = []
	if members_by_rank.has(Definitions.SectRank.ELDER):
		elders.assign(members_by_rank[Definitions.SectRank.ELDER])

	# If there are no elders, the master naturally has absolute authority by default
	if elders.is_empty():
		_execute_proposal_action(action_type, payload)
		return

	var proposal = SectProposal.new(action_type, payload, 7, elders)
	proposal.proposal_resolved.connect(_on_proposal_resolved)
	active_proposals.append(proposal)

func _on_proposal_resolved(proposal: SectProposal, passed: bool) -> void:
	if passed:
		_execute_proposal_action(proposal.type, proposal.payload)
		# TODO: Fire World Log event: "Council passed a new law..."
	else:
		pass
		# TODO: Fire World Log event: "Council rejected the Master's proposal..."

func _execute_proposal_action(action_type: String, payload: Dictionary) -> void:
	match action_type:
		"change_law":
			# This routes to your existing change_law function
			change_law(payload.get("law_id"), payload.get("new_option_id"))
		"declare_war":
			var target_sect = payload.get("target_sect_id")
			SimulationManager.set_sect_relationship(self.sect_id, target_sect, -100)
			# Add world logs and trigger the actual war state here

#endregion

#region Succession

## Triggered by SimulationManager when the active Sect Master dies
func handle_succession() -> void:
	var heir_id = _evaluate_heir()
	
	if heir_id == "":
		# Everyone is dead. Sect collapse logic goes here.
		WorldLogManager.add_log("Sect Collapse", sect_name + " has collapsed following the death of its final members.")
		# TODO: Phase 4 - Implement Sect Disbandment/Ruins state
		return

	# If this is the player's sect, we pause the game and invoke the UI Manager
	if GameManager.player_sect_id == self.sect_id:
		TimeManager.set_time_speed(TimeManager.Speed.PAUSED)
		# We pass the proposed heir to the GameManager so the UI can display it
		GameManager.trigger_player_succession(heir_id)
	else:
		# AI Sects instantly execute the succession
		execute_succession(heir_id)

## Resolves the crowning of the new Sect Master
func execute_succession(heir_id: String) -> void:
	var heir = SimulationManager.get_character(heir_id)
	if not heir: return
	
	# Remove any old masters (they are likely dead, but just in case of abdication)
	var old_masters = members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
	for old_id in old_masters:
		if old_id != heir_id:
			members_by_rank[Definitions.SectRank.SECT_MASTER].erase(old_id)
			
	# Promote the Heir
	add_member(heir_id, Definitions.SectRank.SECT_MASTER, "sect_master")
	
	WorldLogManager.add_log("Succession", heir.get_full_name() + " has ascended as the new Sect Master of " + sect_name + ".")

## Determines who rightfully inherits the sect based on active laws
func _evaluate_heir() -> String:
	# Get all living members
	var valid_candidates = []
	for char_id in all_members:
		var c = SimulationManager.get_character(char_id)
		if c and c.is_alive and not members_by_rank.get(Definitions.SectRank.SECT_MASTER, []).has(char_id):
			valid_candidates.append(c)
			
	if valid_candidates.is_empty():
		return ""
		
	var law = active_laws.get("succession", "strongest")
	
	match law:
		"seniority":
			# Sort by age (Oldest first)
			valid_candidates.sort_custom(func(a, b): return a.age > b.age)
		"strongest", _:
			# Sort by raw internal force
			valid_candidates.sort_custom(func(a, b): 
				var a_power = a.get_martial_stat(Definitions.MartialStat.INTERNAL_FORCE)
				var b_power = b.get_martial_stat(Definitions.MartialStat.INTERNAL_FORCE)
				return a_power > b_power
			)
			
	return valid_candidates[0].char_id

#endregion

#region Construction

## Checks if the sect can afford and legally build this building.
func can_build(building_id: String) -> bool:
	if not DataManager.buildings_registry.has(building_id):
		return false
		
	# 1. Enforce uniqueness: Only one of each building type
	# (Future: Upgrades could be handled by requiring a previous building ID to be removed)
	if completed_buildings.has(building_id):
		return false
		
	for project in construction_queue:
		if project.get("building_id", "") == building_id:
			return false
			
	# 2. Check Affordability
	var b_data = DataManager.buildings_registry[building_id]
	var prereqs = b_data.get("prerequisite_tags", [])
	for req in prereqs:
		if not unlocked_tags.has(req):
			return false # Missing a required tag
	var cost = b_data.get("cost", {})
	
	for res_key in cost:
		var r_enum = Definitions.get_resource_enum(res_key)
		if r_enum != -1 and resources.get(r_enum, 0) < cost[res_key]:
			return false # Cannot afford this specific resource
			
	return true

## Attempts to start construction. Deducts resources and adds to queue.
func start_construction(building_id: String) -> bool:
	if not can_build(building_id):
		return false
		
	var b_data = DataManager.buildings_registry[building_id]
	var cost = b_data.get("cost", {})
	
	# 1. Deduct resources
	for res_key in cost:
		var r_enum = Definitions.get_resource_enum(res_key)
		if r_enum != -1:
			resources[r_enum] -= cost[res_key]
			
	# 2. Calculate Build Time
	var build_days = b_data.get("build_days_base", 30)
	
	# --- FUTURE EXPANSION HOOK ---
	# Here we can modify build_days based on Sect Tenets or the Sect Master's Intelligence
	
	# 3. Add to queue
	construction_queue.append({
		"building_id": building_id,
		"days_remaining": build_days
	})
	
	return true

## Cancels a project in the queue and refunds the cost.
func cancel_construction(queue_index: int) -> void:
	if queue_index < 0 or queue_index >= construction_queue.size():
		return
		
	var project = construction_queue[queue_index]
	var b_data = DataManager.buildings_registry.get(project["building_id"], {})
	var cost = b_data.get("cost", {})
	
	# Refund resources perfectly
	for res_key in cost:
		var r_enum = Definitions.get_resource_enum(res_key)
		if r_enum != -1:
			resources[r_enum] += cost[res_key]
			
	construction_queue.remove_at(queue_index)

#endregion

## Safely rebuilds the sect's capability tags based on existing buildings and tenets.
func recalculate_sect_tags() -> void:
	unlocked_tags.clear()
	
	# 1. Tags from Buildings
	for b_id in completed_buildings:
		var b_data = DataManager.buildings_registry.get(b_id, {})
		var tags = b_data.get("unlocks_sect_tags", [])
		for t in tags:
			if not unlocked_tags.has(t):
				unlocked_tags.append(t)
				
	# 2. Tags from Tenets (Future-proofing for things like "Demonic Arts Allowed")
	for t_id in active_tenets:
		var t_data = DataManager.tenets_registry.get(t_id, {})
		var tags = t_data.get("unlocks_sect_tags", [])
		for t in tags:
			if not unlocked_tags.has(t):
				unlocked_tags.append(t)


# --- SERIALIZATION ---

func to_dictionary() -> Dictionary:
	return {
		"sect_id": sect_id,
		"sect_name": sect_name,
		"alignment": alignment,
		"culture": culture,
		"org_type": org_type,
		"rival_sect_id": rival_sect_id,
		"province_id": province_id,
		"resources": resources,
		"stats": stats,
		"cached_sect_strength": cached_sect_strength,
		"all_members": all_members,
		"members_by_rank": members_by_rank,
		"members_by_position": members_by_position,
		"active_laws": active_laws,
		"active_tenets": active_tenets,
		"unlocked_tags": unlocked_tags,
		"completed_buildings": completed_buildings,
		"active_modifiers": active_modifiers,
		"construction_queue": construction_queue,
		"active_proposals": _serialize_active_proposals(),
		"next_raid_day": next_raid_day
	}

func from_dictionary(data: Dictionary) -> void:
	sect_id = data.get("sect_id", "")
	sect_name = data.get("sect_name", "Unnamed Sect")
	alignment = data.get("alignment", Definitions.SectAlignment.NEUTRAL)
	culture = data.get("culture", Definitions.Culture.CENTRAL_PLAINS)
	org_type = data.get("org_type", Definitions.OrgType.SECT)
	rival_sect_id = data.get("rival_sect_id", "")
	province_id = data.get("province_id", "")
	cached_sect_strength = data.get("cached_sect_strength", 0)
	
	if data.has("resources"):
		for key in data["resources"]:
			resources[int(key) if key.is_valid_int() else key] = data["resources"][key]
			
	if data.has("stats"):
		for key in data["stats"]:
			stats[int(key) if key.is_valid_int() else key] = data["stats"][key]
			
	if data.has("all_members"):
		all_members.assign(data["all_members"])
		
	if data.has("members_by_rank"):
		for key in data["members_by_rank"]:
			# Ensure type safety coming out of JSON
			var rank_enum = int(key) if key.is_valid_int() else key
			
			var rank_array: Array[String] = []
			rank_array.assign(data["members_by_rank"][key])
			members_by_rank[rank_enum] = rank_array
			
	if data.has("members_by_position"):
		for pos in data["members_by_position"]:
			var pos_array: Array[String] = []
			pos_array.assign(data["members_by_position"][pos])
			members_by_position[pos] = pos_array
			
	if data.has("active_laws"):
		active_laws = data["active_laws"].duplicate()
	 
	if data.has("active_tenets"):
		var tenets_array: Array[String] = []
		tenets_array.assign(data["active_tenets"])
		active_tenets = tenets_array	
		
	if data.has("completed_buildings"):
		completed_buildings.assign(data["completed_buildings"])
	
	if data.has("unlocked_tags"):
		unlocked_tags.assign(data["unlocked_tags"])
		
	if data.has("active_modifiers"):
		active_modifiers.clear()
		for mod in data["active_modifiers"]:
			active_modifiers.append(mod)
			
	if data.has("construction_queue"):
		construction_queue.clear()
		for b in data["construction_queue"]:
			construction_queue.append(b)
	
	if data.has("active_proposals"):
		active_proposals.clear()
		for a in data["active_proposals"]:
			if typeof(a) != TYPE_DICTIONARY:
				continue

			var p_type: String = a.get("type", "")
			if p_type == "":
				continue

			var p_payload: Dictionary = a.get("payload", {})
			var p_days: int = int(a.get("days_remaining", 0))

			var p_undecided: Array[String] = []
			if a.has("undecided"):
				p_undecided.assign(a["undecided"])

			var restored = SectProposal.new(p_type, p_payload, p_days, p_undecided)
			restored.proposal_id = a.get("proposal_id", restored.proposal_id)

			restored.supporters.clear()
			if a.has("supporters"):
				restored.supporters.assign(a["supporters"])

			restored.opposers.clear()
			if a.has("opposers"):
				restored.opposers.assign(a["opposers"])

			restored.proposal_resolved.connect(_on_proposal_resolved)
			active_proposals.append(restored)

	next_raid_day = data.get("next_raid_day", -1)

func _serialize_active_proposals() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for proposal in active_proposals:
		serialized.append({
			"proposal_id": proposal.proposal_id,
			"type": proposal.type,
			"payload": proposal.payload,
			"days_remaining": proposal.days_remaining,
			"supporters": proposal.supporters,
			"opposers": proposal.opposers,
			"undecided": proposal.undecided
		})
	return serialized
