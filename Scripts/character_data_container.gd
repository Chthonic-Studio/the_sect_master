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
var personal_log: Array[String] = []

# --- SIMULATION LOD ---
enum SimTier { MICRO, MACRO, FROZEN }
var current_sim_tier: SimTier = SimTier.MICRO

# --- AI ROLES & DIRECTIVES ---
var ai_tags: Array[String] = ["general", "martial_artist"] # Default tags for baseline behavior
var current_directive: Directive = null

# --- DYNAMIC STATE VARIABLES ---
var wealth: int = 0
var is_hurt: bool = false
var state_vars: Dictionary = {
	"stress": 0.0,       # 0 = Calm, 100 = Mental breakdown
	"comfort": 50.0,     # Rises when in good rooms/using good items
	"loneliness": 0.0,   # Rises slowly, lowered by social interaction
	"fatigue": 0.0,      # Rises while awake/working, lowered by sleep
	"mood": 50.0         # The master variable, influenced by all the above
}
var equipped_weapon_id: String = ""
var weapon_proficiencies: Dictionary = {} # Tracks skill level per weapon type enum (e.g. { Definitions.WeaponType.SWORD : 45.0 })

# --- VOLATILE STATE & AI ---
# --- NEEDS (The Character's Drives, 0 = Satiated, 100 = Desperate) ---
var needs: Dictionary = {
	"creativity": 0.0,
	"exploration": 0.0,
	"helping": 0.0,
	"relaxation": 0.0,
	"rest": 0.0,         # Directly tied to Fatigue
	"shopping": 0.0,     # Tied to Greed/Wealth
	"training": 0.0,     # Tied to Ambition
	"socialization": 0.0,# Tied to Loneliness
	"spirituality": 0.0,
	"entertainment": 0.0,
	"studying": 0.0,
	"villainy": 0.0      # Tied to Ruthlessness/Low Morality
}

var action_cooldowns: Dictionary = {}
var brain: CharacterBrain

# --- THE DATA CONTAINERS ---
var base_stats = {}
var base_martial = {}
var personality_values = {}
var alignment_values = {}
var traits: Array[String] = []

# --- EVENT MEMORY & PULSE ---
var event_memory: Dictionary = {} # Maps event/flag ID -> Array[Dictionary] of payloads
var next_event_pulse_day: int = -1 # -1 means uninitialized

# --- CACHED DATA CONTAINERS (The final effective values) ---
# These are strictly for fast O(1) reading during the simulation loop.
var current_stats = {}
var current_martial = {}
var current_personality = {}
var current_alignment = {}

# Combat Caches (Recalculated alongside stats)
var max_health: float = 100.0
var current_resistances: Dictionary = {} # e.g. { Definitions.DamageType.SLASHING: 10 }
var current_affinities: Dictionary = {}  # e.g. { Definitions.DamageType.POISON: 25 }
var current_weapon_affinities: Dictionary = {} # e.g. "Sword Heart" gives a flat +50 to SWORD affinity.

# --- INITIALIZATION ---
func _init():
	brain = CharacterBrain.new()
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
	for w in Definitions.WeaponType.values():
		weapon_proficiencies[w] = 0.0
		current_weapon_affinities[w] = 1.0 # 1.0 is the baseline 100% learning speed

## Adds a log entry with the current date, maintaining a maximum size to save memory.
func add_log(message: String) -> void:
	var entry = "[%s] %s" % [TimeManager.get_date_string(), message]
	personal_log.push_front(entry)
	if personal_log.size() > 50: # Limit size to prevent infinite memory bloat
		personal_log.pop_back()

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
	return last_name + " " + first_name

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
	
	# 5. Recalculate Weapon Affinities
	# Reset affinities to baseline before recalculating
	# Apply equipped weapon stat and martial modifiers
	if equipped_weapon_id != "" and DataManager.weapons_registry.has(equipped_weapon_id):
		var weapon_data = DataManager.weapons_registry[equipped_weapon_id]
		
		# O(1) integer iteration. No strings!
		var w_stats = weapon_data.get("stat_modifiers", {})
		for stat_enum in w_stats:
			current_stats[stat_enum] = clampi(current_stats[stat_enum] + w_stats[stat_enum], 0, Definitions.STAT_CAP)
				
		var w_martial = weapon_data.get("martial_modifiers", {})
		for m_enum in w_martial:
			current_martial[m_enum] = maxi(current_martial[m_enum] + w_martial[m_enum], 0)
	
	# Notify external UI/Systems that this character's numbers have shifted
	stats_recalculated.emit(self)

# --- SIMULATION TRANSITIONS ---

## Wakes a character up to full daily RimWorld-style evaluation.
func transition_to_micro() -> void:
	current_sim_tier = SimTier.MICRO
	
	# Randomize needs slightly so a newly spawned character doesn't enter 
	# as a blank slate and immediately try to sleep or meditate simultaneously.
	var ambition = get_personality_value("ambition")
	needs["training"] = randf_range(20.0, 50.0 + (ambition * 0.5))
	state_vars["fatigue"] = randf_range(10.0, 40.0)

## Demotes a character to background CK3-style monthly evaluations.
func transition_to_macro() -> void:
	current_sim_tier = SimTier.MACRO
	# Clear out micro-specific volatile state to save memory
	if brain.current_action != null:
		brain.current_action = null

## Halts all AI processing (e.g., dead, imprisoned, or secluded meditation).
func transition_to_frozen() -> void:
	current_sim_tier = SimTier.FROZEN
	if brain.current_action != null:
		brain.current_action = null

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
	# If frozen (dead, deep secluded meditation), completely skip the loop
	if current_sim_tier == SimTier.FROZEN:
		return
		
	# 1. Process Modifiers Expiration
	if not active_modifiers.is_empty():
		var expired_ids: Array[String] = []
		var needs_recalculation = false
		
		for i in range(active_modifiers.size() - 1, -1, -1):
			if active_modifiers[i]["expiration_day"] <= current_total_days:
				expired_ids.append(active_modifiers[i]["id"])
				active_modifiers.remove_at(i)
				needs_recalculation = true
				
		if needs_recalculation:
			recalculate_all_stats()
			for mod_id in expired_ids:
				modifier_expired.emit(self, mod_id)
	
	# 2. AI & Overrides
	if current_directive != null:
		# Directives bypass normal AI and decay
		_apply_daily_decay(current_directive.decay_modifiers)
		current_directive.process_tick(self)
		current_directive.duration_remaining -= 1
		
		if current_directive.is_complete():
			current_directive.on_complete(self)
			current_directive = null
	else:
		# ONLY process intensive Utility AI if the character is active on-screen
		if current_sim_tier == SimTier.MICRO:
			_apply_daily_decay()
			brain.process_daily_tick(self)
		elif current_sim_tier == SimTier.MACRO:
			# TODO: Apply a monthly macro-evaluation here later.
			# For now, we do nothing to save CPU time.
			pass
	
	# 2.5. EVENT ENGINE PULSE
	if current_sim_tier != SimTier.FROZEN:
		if next_event_pulse_day <= 0:
			# Initialize with a random stagger so the world doesn't evaluate everyone on Day 1
			next_event_pulse_day = current_total_days + randi_range(1, 30)
			
		if current_total_days >= next_event_pulse_day:
			EventManager.evaluate_character_pulse(self)
			# Jitter - Next evaluation happens randomly between 20 and 40 days from now
			next_event_pulse_day = current_total_days + randi_range(20, 40)
	
	# 3. Master State Calculation (Only necessary for on-screen UI feedback)
	if current_sim_tier == SimTier.MICRO:
		_calculate_mood()

## Applies baseline creeping of needs and state variables simply from existing.
## Can be overridden by Directives to simulate arduous missions or deep rest.
func _apply_daily_decay(custom_modifiers: Dictionary = {}) -> void:
	# --- STATE VARS ---
	var base_fatigue_rate = custom_modifiers.get("fatigue_rate", 5.0)
	state_vars["fatigue"] = minf(100.0, state_vars.get("fatigue", 0.0) + base_fatigue_rate)
	
	var sociability = get_personality_value("sociability")
	var base_loneliness_rate = custom_modifiers.get("loneliness_rate", 1.0 + (sociability / 100.0 * 2.0))
	state_vars["loneliness"] = minf(100.0, state_vars.get("loneliness", 0.0) + base_loneliness_rate)
	
	# --- NEEDS ---
	var ambition = get_personality_value("ambition")
	var base_train_rate = custom_modifiers.get("training_rate", 0.5 + (ambition / 100.0 * 2.5))
	needs["training"] = minf(100.0, needs.get("training", 0.0) + base_train_rate)
	
	var base_ent_rate = custom_modifiers.get("entertainment_rate", 1.5)
	needs["entertainment"] = minf(100.0, needs.get("entertainment", 0.0) + base_ent_rate)
	
	var base_soc_rate = custom_modifiers.get("socialization_rate", 1.5)
	needs["socialization"] = minf(100.0, needs.get("socialization", 0.0) + base_soc_rate)
	
	# Stress is special; it doesn't passively rise normally, but a Directive can force it to.
	if custom_modifiers.has("stress_rate"):
		state_vars["stress"] = minf(100.0, state_vars.get("stress", 0.0) + custom_modifiers["stress_rate"])


## Derives the master 'Mood' variable from all other state variables and unmet needs.
## 0-20 = Breakdown risk | 21-40 = Unhappy | 41-60 = Content | 61-80 = Happy | 81-100 = Euphoric
func _calculate_mood() -> void:
	var base_mood = 50.0
	
	# 1. State Penalties
	var stress_penalty = state_vars.get("stress", 0.0) * 0.4
	var fatigue_penalty = 0.0
	# Fatigue only hurts mood if they are exhausted (> 60)
	if state_vars.get("fatigue", 0.0) > 60.0:
		fatigue_penalty = (state_vars.get("fatigue", 0.0) - 60.0) * 0.5
		
	var loneliness_penalty = state_vars.get("loneliness", 0.0) * 0.2
	
	# 2. Comfort Bonus
	var comfort_bonus = (state_vars.get("comfort", 50.0) - 50.0) * 0.2
	
	# 3. Unmet Needs Penalty
	# We find the single highest unmet need and penalize mood based on it.
	# We don't stack all needs, otherwise they'd always be miserable.
	var highest_need_val = 0.0
	for need_key in needs:
		if needs[need_key] > highest_need_val:
			highest_need_val = needs[need_key]
			
	var need_penalty = 0.0
	if highest_need_val > 50.0:
		need_penalty = (highest_need_val - 50.0) * 0.3
	
	# Final Calculation
	var final_mood = base_mood + comfort_bonus - stress_penalty - fatigue_penalty - loneliness_penalty - need_penalty
	
	# Clamp and assign
	state_vars["mood"] = clampi(int(final_mood), 0, 100)


# --- EVENT MEMORY API ---

func add_memory(memory_id: String, payload: Dictionary = {}) -> void:
	if not event_memory.has(memory_id):
		event_memory[memory_id] = []
	
	payload["day_recorded"] = TimeManager.get_total_days_elapsed()
	event_memory[memory_id].append(payload)

func has_memory(memory_id: String) -> bool:
	return event_memory.has(memory_id) and not event_memory[memory_id].is_empty()

## Checks if the memory exists AND if the payload contains a specific key-value pair.
func has_memory_matching(memory_id: String, key: String, value: Variant) -> bool:
	if not has_memory(memory_id): return false
	
	for payload in event_memory[memory_id]:
		if payload.has(key) and payload[key] == value:
			return true
	return false


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
		"active_modifiers": active_modifiers,
		"personal_log": personal_log,
		"wealth": wealth,
		
		# AI Values
		"needs": needs,
		"current_sim_tier": current_sim_tier,
		"ai_tags": ai_tags,
		"action_cooldowns": action_cooldowns,
		"current_action_id": brain.current_action.id if brain.current_action else "",
		"action_duration": brain.current_action.duration_remaining if brain.current_action else 0,
		
		# Directive State
		"current_directive_id": current_directive.id if current_directive else "",
		"directive_duration": current_directive.duration_remaining if current_directive else 0,
		"directive_modifiers": current_directive.decay_modifiers if current_directive else {},
		
		# Combat Values 
		"equipped_weapon_id": equipped_weapon_id,
		"weapon_proficiencies": weapon_proficiencies,
		
		# Event status
		"event_memory": event_memory,
		"next_event_pulse_day": next_event_pulse_day,
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
	equipped_weapon_id = data.get("equipped_weapon_id", "")
	
	current_sim_tier = data.get("current_sim_tier", SimTier.MICRO)
	
	if data.has("ai_tags"):
		ai_tags.assign(data["ai_tags"])
	
	if data.has("base_stats"):
		for key in data["base_stats"]:
			base_stats[int(key) if key.is_valid_int() else key] = int(data["base_stats"][key])
	if data.has("base_martial"):
		for key in data["base_martial"]:
			base_martial[int(key) if key.is_valid_int() else key] = int(data["base_martial"][key])
	if data.has("personality_values"):
		for key in data["personality_values"]:
			personality_values[key] = int(data["personality_values"][key])
	if data.has("alignment_values"):
		for key in data["alignment_values"]:
			alignment_values[key] = int(data["alignment_values"][key])
		
	if data.has("traits"):
		# Avoid Godot 3 Array() constructor syntax
		traits.assign(data["traits"])
	
	if data.has("active_modifiers"):
		# Ensure we load it cleanly into our typed array structure
		# It wipes the slate perfectly clean before we inject the save data
		active_modifiers.clear()
		for mod in data["active_modifiers"]:
			active_modifiers.append(mod)
	
	if data.has("personal_log"):
		personal_log.assign(data["personal_log"])
	
	if data.has("needs"):
		needs.merge(data["needs"], true)
	if data.has("action_cooldowns"):
		action_cooldowns.merge(data["action_cooldowns"], true)
	
	if data.has("weapon_proficiencies"):
		for key_str in data["weapon_proficiencies"]:
			var w_enum = int(key_str)
			weapon_proficiencies[w_enum] = data["weapon_proficiencies"][key_str]
	
	if data.has("event_memory"):
		event_memory.merge(data["event_memory"], true)
	next_event_pulse_day = data.get("next_event_pulse_day", -1)
		
	# Reconstruct the AI's current action immediately
	var saved_action_id = data.get("current_action_id", "")
	var saved_action_duration = data.get("action_duration", 0)
	if saved_action_id != "" and saved_action_duration > 0:
		brain.restore_action_state(saved_action_id, saved_action_duration)
	
	# Reconstruct the Directive
	var dir_id = data.get("current_directive_id", "")
	var dir_dur = data.get("directive_duration", 0)
	var dir_mods = data.get("directive_modifiers", {})
	
	if dir_id != "" and dir_dur > 0:
		current_directive = DataManager.create_directive(dir_id, dir_dur, dir_mods)
	
	# Rebuild the cache after loading from save
	recalculate_all_stats()
		
#endregion
