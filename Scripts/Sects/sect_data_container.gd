extends RefCounted
class_name SectData

signal modifier_expired(sect: SectData, modifier_id: String)
signal strength_recalculated(sect: SectData)
signal building_completed(sect: SectData, building_id: String)

# --- IDENTITY ---
var sect_id: String = ""
var sect_name: String = "Unnamed Sect"
var alignment: int = Definitions.SectAlignment.NEUTRAL
var rival_sect_id: String = ""

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

# Array of Dictionaries tracking ongoing construction. 
# Format: {"building_id": String, "days_remaining": int}
var construction_queue: Array[Dictionary] = []

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
		
	if not members_by_rank.has(rank):
		members_by_rank[rank] = []
	if not members_by_rank[rank].has(char_id):
		members_by_rank[rank].append(char_id)
		
	if position != "":
		assign_position(char_id, position)
		
	flag_strength_dirty()

## Completely removes a character from the sect, clearing them from all categorized arrays.
func remove_member(char_id: String) -> void:
	all_members.erase(char_id)
	
	for rank in members_by_rank.keys():
		members_by_rank[rank].erase(char_id)
		
	for pos in members_by_position.keys():
		members_by_position[pos].erase(char_id)
		
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
		# Only process the first item in the queue (Sects build one thing at a time)
		var current_project = construction_queue[0]
		current_project["days_remaining"] -= 1
		
		if current_project["days_remaining"] <= 0:
			var finished_building = current_project["building_id"]
			completed_buildings.append(finished_building)
			construction_queue.remove_at(0)
			building_completed.emit(self, finished_building)

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

# --- SERIALIZATION ---

func to_dictionary() -> Dictionary:
	return {
		"sect_id": sect_id,
		"sect_name": sect_name,
		"alignment": alignment,
		"rival_sect_id": rival_sect_id,
		"resources": resources,
		"stats": stats,
		"cached_sect_strength": cached_sect_strength,
		"all_members": all_members,
		"members_by_rank": members_by_rank,
		"members_by_position": members_by_position,
		"active_laws": active_laws,
		"completed_buildings": completed_buildings,
		"active_modifiers": active_modifiers,
		"construction_queue": construction_queue
	}

func from_dictionary(data: Dictionary) -> void:
	sect_id = data.get("sect_id", "")
	sect_name = data.get("sect_name", "Unnamed Sect")
	alignment = data.get("alignment", Definitions.SectAlignment.NEUTRAL)
	rival_sect_id = data.get("rival_sect_id", "")
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
		
	if data.has("completed_buildings"):
		completed_buildings.assign(data["completed_buildings"])
		
	if data.has("active_modifiers"):
		active_modifiers.clear()
		for mod in data["active_modifiers"]:
			active_modifiers.append(mod)
			
	if data.has("construction_queue"):
		construction_queue.clear()
		for b in data["construction_queue"]:
			construction_queue.append(b)
