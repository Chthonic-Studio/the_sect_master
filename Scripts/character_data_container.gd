extends RefCounted
class_name CharacterData

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

# --- THE DATA CONTAINERS ---
var base_stats = {}
var base_cultivation = {}
var personality_values = {}
var alignment_values = {}
var traits: Array[String] = []

# --- INITIALIZATION ---
func _init():
	_setup_empty_stats()

func _setup_empty_stats():
	for s in Definitions.Stat.values():
		base_stats[s] = 0
	for s in Definitions.CultivationStat.values():
		base_cultivation[s] = 0
	for p_name in Definitions.PERSONALITY_STATS:
		personality_values[p_name] = 50
	for a_name in Definitions.ALIGNMENT_STATS:
		alignment_values[a_name] = 50

# --- DATA ACCESSORS ---

func get_stat(stat_enum: int) -> int:
	var total = base_stats[stat_enum]
	total += DataManager.get_trait_modifiers_for_stat(traits, stat_enum)
	return clampi(total, 0, Definitions.STAT_CAP)

func get_personality_value(p_name: String) -> int:
	if not personality_values.has(p_name):
		return 0
	var val = personality_values[p_name]
	val += DataManager.get_trait_modifiers_for_personality(traits, p_name)
	return clampi(val, 0, 100)

func get_full_name() -> String:
	return first_name + " " + last_name

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
		"base_cultivation": base_cultivation,
		"personality_values": personality_values,
		"traits": traits
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
	
	# We use merge(true) to overwrite defaults with saved values
	if data.has("base_stats"):
		base_stats.merge(data["base_stats"], true)
	if data.has("base_cultivation"):
		base_cultivation.merge(data["base_cultivation"], true)
	if data.has("personality_values"):
		personality_values.merge(data["personality_values"], true)
		
	if data.has("traits"):
		traits = Array(data["traits"], TYPE_STRING, &"", null)
