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
var culture: int = Definitions.Culture.CENTRAL_PLAINS
var avatar_index: int = 0 # Index into the portrait list (0-11 for placeholder grid)

# --- STATE ---
var sect_id: String = ""
var current_realm: int = 1
var is_alive: bool = true
var is_martial_artist: bool = false # TRUE for Martial Artists. FALSE for peasants/servants/merchants/etc.
var aptitude: int = 0 
var active_modifiers: Array[Dictionary] = []
var personal_log: Array[String] = []

# --- SIMULATION LOD ---
enum SimTier { MICRO, MACRO, FROZEN }
var current_sim_tier: SimTier = SimTier.MICRO

# --- AI ROLES & DIRECTIVES ---
var ai_tags: Array[String] = ["general"] # Default tags for baseline behavior
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

var directed_opinions: Dictionary = {} # Format: { "target_char_id": [ { "id": "insulted", "value": -20, "expiration_day": 850 } ] }
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
	"villainy": 0.0,      # Tied to Ruthlessness/Low Morality
	"work": 0.0
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
var death_day: int = -1 # Day this character died; -1 while alive

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
		
		# We initialize the character's stats and leave martial stats after deciding if 
		# character is a martial artist or not
		
	for p_name in Definitions.PERSONALITY_STATS:
		personality_values[p_name] = 50
		current_personality[p_name] = 50
	for a_name in Definitions.ALIGNMENT_STATS:
		alignment_values[a_name] = 50
		current_alignment[a_name] = 50



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

## Called when a non-martial formally enters the martial world.
func awaken_martial_artist() -> void:
	if is_martial_artist: return
	
	is_martial_artist = true
	if not ai_tags.has("martial_artist"):
		ai_tags.append("martial_artist")
		
	# Populate the dictionaries properly
	for s in Definitions.MartialStat.values():
		base_martial[s] = 0
		current_martial[s] = 0
	for w in Definitions.WeaponType.values():
		weapon_proficiencies[w] = 0.0
		current_weapon_affinities[w] = 1.0
		
	# Call out to the Generator to roll their innate initial stats based on aptitude
	CharacterGenerator.roll_martial_awakening(self)
	recalculate_all_stats()

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
	# Only calculate this for actual martial artists to respect our memory optimization
	if is_martial_artist:
		for s in Definitions.MartialStat.values():
			var total = base_martial.get(s, 0) + DataManager.get_total_martial_modifiers(traits, active_modifier_ids, s)
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
	# Gate this behind the martial artist check so we don't try to inject stats into null dictionaries
	if is_martial_artist and equipped_weapon_id != "" and DataManager.weapons_registry.has(equipped_weapon_id):
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

## Lightweight off-screen simulation.
## Purpose: keep background characters evolving without running full Utility AI.
func _process_macro_daily(current_total_days: int) -> void:
	# Coarse passive drift (very cheap).
	_apply_macro_daily_drift()
	
	# Monthly pulse based on absolute day count to avoid per-character counters in save format.
	# This keeps deterministic cadence and avoids extra serialization complexity.
	if current_total_days % 30 == 0:
		_process_macro_monthly_tick()

func _apply_macro_daily_drift() -> void:
	# Keep this intentionally gentle so macro does not outpace micro.
	var sociability = get_personality_value("sociability")
	var ambition = get_personality_value("ambition")
	var greed = get_personality_value("greed")
	
	state_vars["fatigue"] = minf(100.0, state_vars.get("fatigue", 0.0) + 1.0)
	state_vars["loneliness"] = minf(100.0, state_vars.get("loneliness", 0.0) + (0.4 + sociability * 0.01))
	state_vars["stress"] = minf(100.0, state_vars.get("stress", 0.0) + 0.2)
	
	needs["training"] = minf(100.0, needs.get("training", 0.0) + (0.2 + ambition * 0.01))
	needs["work"] = minf(100.0, needs.get("work", 0.0) + (0.5 + greed * 0.01))
	needs["socialization"] = minf(100.0, needs.get("socialization", 0.0) + 0.6)
	needs["entertainment"] = minf(100.0, needs.get("entertainment", 0.0) + 0.5)

## Monthly macro outcome roll.
## Keep probabilities modest to avoid explosive growth in large populations.
func _process_macro_monthly_tick() -> void:
	# 1) Coarse wealth movement based on work pressure and greed.
	var work_need = needs.get("work", 0.0)
	var greed = get_personality_value("greed")
	var discipline = get_personality_value("discipline")
	
	var wealth_shift = int((work_need * 0.05) + (greed * 0.02) - (state_vars.get("stress", 0.0) * 0.02))
	wealth += clampi(wealth_shift + randi_range(-3, 3), -15, 25)
	wealth = maxi(wealth, 0)
	
	# 2) Minor martial progression chance for off-screen martial artists.
	if is_martial_artist:
		var insight = get_martial_stat(Definitions.MartialStat.INSIGHT)
		var chance = 0.03 + (insight / 2000.0) + (discipline / 5000.0)
		if randf() < chance:
			base_martial[Definitions.MartialStat.INTERNAL_FORCE] += randi_range(1, 2)
			recalculate_all_stats()
	
	# 3) Recovery pressure release so macro actors do not spiral to 100 on all tracks forever.
	state_vars["fatigue"] = maxf(0.0, state_vars.get("fatigue", 0.0) - randf_range(8.0, 18.0))
	state_vars["stress"] = maxf(0.0, state_vars.get("stress", 0.0) - randf_range(5.0, 15.0))
	state_vars["loneliness"] = maxf(0.0, state_vars.get("loneliness", 0.0) - randf_range(4.0, 12.0))
	
	needs["work"] = maxf(0.0, needs.get("work", 0.0) - randf_range(8.0, 20.0))
	needs["training"] = maxf(0.0, needs.get("training", 0.0) - randf_range(5.0, 15.0))
	needs["socialization"] = maxf(0.0, needs.get("socialization", 0.0) - randf_range(6.0, 18.0))
	needs["entertainment"] = maxf(0.0, needs.get("entertainment", 0.0) - randf_range(6.0, 16.0))

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

## Adds a temporal opinion modifier directed at another specific character.
func add_directed_opinion(target_id: String, opinion_id: String, value: int, duration_days: int) -> void:
	if not directed_opinions.has(target_id):
		directed_opinions[target_id] = []
		
	var expiration = TimeManager.get_total_days_elapsed() + duration_days
	
	# Refresh duration if it already exists, rather than stacking infinitely
	for mod in directed_opinions[target_id]:
		if mod["id"] == opinion_id:
			mod["expiration_day"] = maxi(mod["expiration_day"], expiration)
			return
			
	directed_opinions[target_id].append({
		"id": opinion_id,
		"value": value,
		"expiration_day": expiration
	})


## Checks whether this character qualifies to attempt a realm breakthrough.
## Called after training actions complete and in the daily tick.
func check_realm_advancement() -> void:
	if not is_martial_artist: return
	if current_realm >= Definitions.MartialRealm.SUMMIT: return

	var threshold = Definitions.REALM_THRESHOLDS.get(current_realm, 9999)
	var current_if = get_martial_stat(Definitions.MartialStat.INTERNAL_FORCE)
	if current_if < threshold: return

	# Already pending breakthrough? Don't fire again.
	if has_memory("pending_breakthrough"): return

	add_memory("pending_breakthrough", {"realm": current_realm})
	EventManager.trigger_event("cultivation_breakthrough_attempt", {"initiator": char_id})

## Called by EventManager effects or directives to advance the realm.
func advance_realm(amount: int = 1) -> void:
	var new_realm = clampi(current_realm + amount, 0, Definitions.MartialRealm.SUMMIT)
	if new_realm != current_realm:
		current_realm = new_realm
		# Clear the pending flag so another breakthrough can be triggered later
		event_memory.erase("pending_breakthrough")
		var realm_keys = Definitions.MartialRealm.keys()
		var realm_name: String = realm_keys[current_realm] if current_realm < realm_keys.size() else "Unknown"
		WorldLogManager.add_log("cultivation", get_full_name() + " has broken through to " +
			realm_name.capitalize() + " realm!")
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
				
	# 1.5. Process Directed Opinions Expiration
	if not directed_opinions.is_empty():
		var empty_targets: Array[String] = []
		for target_id in directed_opinions:
			var ops: Array = directed_opinions[target_id]
			for i in range(ops.size() - 1, -1, -1):
				if ops[i]["expiration_day"] <= current_total_days:
					ops.remove_at(i)
			if ops.is_empty():
				empty_targets.append(target_id)
				
		for t_id in empty_targets:
			directed_opinions.erase(t_id)
	
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
			_process_macro_daily(current_total_days)
	
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

	# 4. Daily realm advancement check (martial artists only, low-frequency)
	if is_martial_artist and current_total_days % 7 == 0:
		check_realm_advancement()

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
	
	var greed = get_personality_value("greed")
	var base_work_rate = custom_modifiers.get("work_rate", 5.0 + (greed / 100.0 * 5.0))
	needs["work"] = minf(100.0, needs.get("work", 0.0) + base_work_rate)
	
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

# --- MORTALITY ---

## Centralized death function. Halts AI, logs death, and alerts the Simulation.
func die(cause: String = "natural causes") -> void:
	if not is_alive: return
	
	is_alive = false
	death_day = TimeManager.get_total_days_elapsed()
	transition_to_frozen()
	add_log("Died from " + cause + ".")
	
	# Alert the global simulation so Sects or Relatives can react
	SimulationManager.handle_character_death(self)

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
		"culture": culture,
		"avatar_index": avatar_index,
		"sect_id": sect_id,
		"current_realm": current_realm,
		"is_alive": is_alive,
		"is_martial_artist": is_martial_artist,
		"base_stats": base_stats,
		"base_martial": base_martial,
		"personality_values": personality_values,
		"alignment_values": alignment_values, 
		"traits": traits,
		"aptitude": aptitude, 
		"active_modifiers": active_modifiers,
		"personal_log": personal_log,
		"wealth": wealth,
		"directed_opinions": directed_opinions,
		"state_vars": state_vars,
		
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
		"death_day": death_day,
	}

## Populates this object from a Dictionary loaded from JSON.
func from_dictionary(data: Dictionary) -> void:
	char_id = data.get("char_id", "")
	first_name = data.get("first_name", "")
	last_name = data.get("last_name", "")
	age = data.get("age", 0)
	gender = data.get("gender", 0)
	culture = data.get("culture", Definitions.Culture.CENTRAL_PLAINS)
	avatar_index = data.get("avatar_index", 0)
	sect_id = data.get("sect_id", "")
	current_realm = data.get("current_realm", 1)
	is_alive = data.get("is_alive", true)
	is_martial_artist = data.get("is_martial_artist", false)
	aptitude = data.get("aptitude", 0) 
	equipped_weapon_id = data.get("equipped_weapon_id", "")
	
	current_sim_tier = data.get("current_sim_tier", SimTier.MICRO)
	
	if data.has("directed_opinions"):
		directed_opinions.merge(data["directed_opinions"], true)
	
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
	if data.has("state_vars"):
		state_vars.merge(data["state_vars"], true)
	if data.has("action_cooldowns"):
		action_cooldowns.merge(data["action_cooldowns"], true)
	
	if data.has("weapon_proficiencies"):
		for key_str in data["weapon_proficiencies"]:
			var w_enum = int(key_str)
			weapon_proficiencies[w_enum] = data["weapon_proficiencies"][key_str]
	
	if data.has("event_memory"):
		event_memory.merge(data["event_memory"], true)
	next_event_pulse_day = data.get("next_event_pulse_day", -1)
	death_day = data.get("death_day", -1)
		
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
