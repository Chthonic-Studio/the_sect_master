# NameGenerator.gd
# Procedural name generator for characters.
# Now supports gendered first names per sub-pool.
# Place at: res://scripts/data/name_generator.gd

extends Node
class_name NameGenerator

# Enum reference (must match CharacterResource)
enum CultureGroup { WESTERN, TRADITIONAL }
enum Gender { MALE, FEMALE, OTHER }

# === Name Data Pools ===
const NAME_POOLS := {
	"WESTERN": {
		"English": {
			"male_first_names": ["John", "William", "Henry"],
			"female_first_names": ["Alice", "Emma", "Sophia"],
			"last_names": ["Smith", "Johnson", "Williams"]
		},
		"German": {
			"male_first_names": ["Lukas", "Leon", "Finn"],
			"female_first_names": ["Mia", "Hannah", "Emilia"],
			"last_names": ["Müller", "Schmidt", "Schneider"]
		},
		"French": {
			"male_first_names": ["Louis", "Jean", "Pierre"],
			"female_first_names": ["Marie", "Camille", "Juliette"],
			"last_names": ["Dubois", "Martin", "Bernard"]
		}
	},
	"TRADITIONAL": {
		"Chinese": {
			"male_first_names": ["Wei", "Lei", "Jun"],
			"female_first_names": ["Xia", "Mei", "Hua"],
			"last_names": ["Li", "Wang", "Zhang"]
		},
		"Japanese": {
			"male_first_names": ["Haruto", "Sota", "Ren"],
			"female_first_names": ["Yui", "Hina", "Aoi"],
			"last_names": ["Sato", "Suzuki", "Takahashi"]
		},
		"Korean": {
			"male_first_names": ["Min-Jun", "Ji-ho", "Joon"],
			"female_first_names": ["Seo-yeon", "Ha-eun", "Soo"],
			"last_names": ["Kim", "Lee", "Park"]
		}
	}
}

# === API ===

# Returns a Dictionary: { "first_name", "last_name", "sub_pool", "full_name", "gender_source" }
static func generate_name(culture_group: int, gender: int) -> Dictionary:
	var pool_key := ""
	match culture_group:
		CultureGroup.WESTERN:
			pool_key = "WESTERN"
		CultureGroup.TRADITIONAL:
			pool_key = "TRADITIONAL"
		_:
			push_error("Unknown culture_group: %s" % [culture_group])
			return {}

	var sub_pools = NAME_POOLS[pool_key]
	var sub_pool_keys = sub_pools.keys()
	if sub_pool_keys.is_empty():
		push_error("No sub-pools for: %s" % [pool_key])
		return {}

	var chosen_sub_pool = sub_pool_keys[randi() % sub_pool_keys.size()]
	var pool = sub_pools[chosen_sub_pool]

	# Gendered first names logic
	var use_gender = gender
	var gender_source = ""
	var first_names = []
	match gender:
		Gender.MALE:
			if pool.has("male_first_names"):
				first_names = pool["male_first_names"]
				gender_source = "MALE"
			elif pool.has("female_first_names"):
				first_names = pool["female_first_names"]
				gender_source = "FEMALE"
		Gender.FEMALE:
			if pool.has("female_first_names"):
				first_names = pool["female_first_names"]
				gender_source = "FEMALE"
			elif pool.has("male_first_names"):
				first_names = pool["male_first_names"]
				gender_source = "MALE"
		Gender.OTHER:
			var candidate_keys = []
			if pool.has("male_first_names"):
				candidate_keys.append("male_first_names")
			if pool.has("female_first_names"):
				candidate_keys.append("female_first_names")
			if candidate_keys.size() > 0:
				var chosen_key = candidate_keys[randi() % candidate_keys.size()]
				first_names = pool[chosen_key]
				gender_source = "MALE" if chosen_key == "male_first_names" else "FEMALE"
	if first_names.size() == 0:
		push_error("No first names for gender in sub-pool: %s" % [chosen_sub_pool])
		return {}

	var last_names = pool["last_names"]
	var first_name = first_names[randi() % first_names.size()]
	var last_name = last_names[randi() % last_names.size()]

	var full_name = ""
	if culture_group == CultureGroup.WESTERN:
		full_name = "%s %s" % [first_name, last_name]
	else:
		full_name = "%s %s" % [last_name, first_name]

	return {
		"first_name": first_name,
		"last_name": last_name,
		"sub_pool": chosen_sub_pool,
		"full_name": full_name,
		"gender_source": gender_source
	}

# For convenience, return just the full name string
static func generate_full_name(culture_group: int, gender: int) -> String:
	var name_data = generate_name(culture_group, gender)
	return name_data.get("full_name", "")

# === How & Where to Use ===
# 1. Place in res://scripts/data/name_generator.gd
# 2. Use as singleton or preload.
# 3. Call: var name_dict = NameGenerator.generate_name(CharacterResource.CultureGroup.TRADITIONAL, CharacterResource.Gender.FEMALE)
# 4. Use name_dict["first_name"], name_dict["last_name"], name_dict["full_name"], etc.
