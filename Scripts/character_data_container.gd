extends RefCounted
class_name CharacterData

signal modifier_expired(character: CharacterData, modifier_id: String)
signal stats_recalculated(character: CharacterData)

# --- IDENTITY ---
var char_id: String = ""
var first_name: String = ""
var last_name: String = ""
var age: int = 0
var gender: int = 0 # 0: Male, 1: Female, 2: Neutral

# --- STATE ---
var sect_id: String = ""
var current_realm: int = 1
var is_alive: bool = true
var aptitude: int = 0 
var active_modifiers: Array[Dictionary] = []

# --- THE DATA CONTAINERS ---
var base_stats = {}
var base_martial = {}
var personality_values = {}
var alignment_values = {}
var traits: Array[String] = []

# --- CACHED DATA CONTAINERS (The final effective values) ---
# These are strictly for fast O(1) reading during the simulation loop.
var current_stats = {}
var current_martial = {}
var current_personality = {}
var current_alignment = {}

# --- INITIALIZATION ---
func _init():
	_setup_empty_stats()

func _setup_empty_stats():
	for s in Definitions.Stat.values():
		base_stats[s] = 0
		current_stats[s] = 0
	for s in Definitions.MartialStat.values():
		base_martial[s] = 0
		current_martial[s] = 0
	for p_name in Definitions.PERSONALITY_STATS:
		personality_values[p_name] = 50
		current_personality[p_name] = 50
	for a_name in Definitions.ALIGNMENT_STATS:
		alignment_values[a_name] = 50
		current_alignment[a_name] = 50

# --- DATA ACCESSORS (Now O(1) Instant Lookups) ---

func get_stat(stat_enum: int) -> int:
	return current_stats.get(stat_enum, 0)

func get_martial_stat(stat_enum: int) -> int:
	return current_martial.get(stat_enum, 0)

func get_personality_value(p_name: String) -> int:
	return current_personality.get(p_name, 0)

func get_alignment_value(a_name: String) -> int:
	return current_alignment.get(a_name, 0)

func get_full_name() -> String:
	return first_name + " " + last_name

# --- CACHE MANAGEMENT ---

## Called once after bulk operations (generation or loading) 
## or automatically when a single trait is added/removed.
func recalculate_all_stats() -> void:
	# Extract just the string IDs from the active_modifiers array for the calculators
	var active_modifier_ids: Array[String] = []
	for mod in active_modifiers:
		active_modifier_ids.append(mod["id"])

	# 1. Recalculate Base Stats
	for s in Definitions.Stat.values():
		var total = base_stats[s] + DataManager.get_total_stat_modifiers(traits, active_modifier_ids, s)
		current_stats[s] = clampi(total, 0, Definitions.STAT_CAP)
		
	# 2. Recalculate Martial Stats (Previously Cultivation)
	for s in Definitions.MartialStat.values():
		var total = base_martial[s] + DataManager.get_total_martial_modifiers(traits, active_modifier_ids, s)
		current_martial[s] = maxi(total, 0)
		
	# 3. Recalculate Personality
	for p_name in Definitions.PERSONALITY_STATS:
		var total = personality_values.get(p_name, 50) + DataManager.get_total_personality_modifiers(traits, active_modifier_ids, p_name)
		current_personality[p_name] = clampi(total, 0, 100)
		
	# 4. Recalculate Alignment (Uses personality_modifiers block in JSON)
	for a_name in Definitions.ALIGNMENT_STATS:
		var total = alignment_values.get(a_name, 50) + DataManager.get_total_alignment_modifiers(traits, active_modifier_ids, a_name)
		current_alignment[a_name] = clampi(total, 0, 100)
	
	# Notify external UI/Systems that this character's numbers have shifted
	stats_recalculated.emit(self)

# --- GAMEPLAY MODIFIERS ---

## Safely apply traits and update the cache to avoid redundant recalculations

func add_trait(trait_id: String) -> void:
	if not traits.has(trait_id):
		traits.append(trait_id)
		recalculate_all_stats()

func remove_trait(trait_id: String) -> void:
	if traits.has(trait_id):
		traits.erase(trait_id)
		recalculate_all_stats()

## Adds a predefined temporary modifier from the JSON registry.
func add_temporary_modifier(modifier_id: String, duration_days: int) -> void:
	if not DataManager.modifiers_registry.has(modifier_id):
		printerr("CharacterData: Attempted to add invalid modifier ID: ", modifier_id)
		return
		
	var expiration = TimeManager.get_total_days_elapsed() + duration_days
	
	# If we already have it, just refresh the duration (don't stack stats infinitely)
	for mod in active_modifiers:
		if mod["id"] == modifier_id:
			mod["expiration_day"] = maxi(mod["expiration_day"], expiration)
			return # No stats changed, so no recalculation needed
			
	# If it's new, append and recalculate
	active_modifiers.append({
		"id": modifier_id,
		"expiration_day": expiration
	})
	recalculate_all_stats()

## Called by DataManager's daily tick
func process_daily_tick(current_total_days: int) -> void:
	if active_modifiers.is_empty():
		return
		
	var expired_ids: Array[String] = []
	var needs_recalculation = false
	
	# Loop backwards when erasing from an array to avoid index shifting
	for i in range(active_modifiers.size() - 1, -1, -1):
		if active_modifiers[i]["expiration_day"] <= current_total_days:
			expired_ids.append(active_modifiers[i]["id"])
			active_modifiers.remove_at(i)
			needs_recalculation = true
			
	if needs_recalculation:
		recalculate_all_stats()
		
		# Broadcast the expirations AFTER stats are accurate again
		for mod_id in expired_ids:
			modifier_expired.emit(self, mod_id)


#region Serialization
# --- SERIALIZATION (For Saving/Loading) ---

## Converts this object into a Dictionary that can be saved as JSON.
func to_dictionary() -> Dictionary:
	return {
		"char_id": char_id,
		"first_name": first_name,
		"last_name": last_name,
		"age": age,
		"gender": gender,
		"sect_id": sect_id,
		"current_realm": current_realm,
		"is_alive": is_alive,
		"base_stats": base_stats,
		"base_martial": base_martial,
		"personality_values": personality_values,
		"alignment_values": alignment_values, 
		"traits": traits,
		"aptitude": aptitude, 
		"active_modifiers": active_modifiers
	}

## Populates this object from a Dictionary loaded from JSON.
func from_dictionary(data: Dictionary) -> void:
	char_id = data.get("char_id", "")
	first_name = data.get("first_name", "")
	last_name = data.get("last_name", "")
	age = data.get("age", 0)
	gender = data.get("gender", 0)
	sect_id = data.get("sect_id", "")
	current_realm = data.get("current_realm", 1)
	is_alive = data.get("is_alive", true)
	aptitude = data.get("aptitude", 0) 
	
	if data.has("base_stats"):
		base_stats.merge(data["base_stats"], true)
	if data.has("base_martial"):
		base_martial.merge(data["base_martial"], true)
	if data.has("personality_values"):
		personality_values.merge(data["personality_values"], true)
	if data.has("alignment_values"):
		alignment_values.merge(data["alignment_values"], true)
		
	if data.has("traits"):
		traits = Array(data["traits"], TYPE_STRING, &"", null)
	
	if data.has("active_modifiers"):
		# Ensure we load it cleanly into our typed array structure
		# It wipes the slate perfectly clean before we inject the save data
		active_modifiers.clear()
		for mod in data["active_modifiers"]:
			active_modifiers.append(mod)
		
	# Rebuild the cache after loading from save
	recalculate_all_stats()
		
#endregion
