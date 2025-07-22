# cultivator_resource.gd
# Resource for all cultivator characters.
# Inherits CharacterResource and adds cultivation-specific data.

extends CharacterResource
class_name CultivatorResource

const Definitions = preload("res://Scripts/Data/Definitions.gd")

# --- Cultivation State ---
@export_category("Cultivation State")
@export var cultivation_realm: Definitions.CultivationRealm = Definitions.CultivationRealm.QI_GATHERING
@export_range(0, 100, 1) var realm_progress: int = 0 # Progress to next realm (0-100, or larger if you want)
@export var lifespan: int = 0

# --- Techniques & Skills ---
@export_category("Techniques & Skills")
@export var learned_techniques: Array[String] = [] # IDs or paths to TechniqueResource

# --- Cultivation Risks ---
@export_category("Cultivation Risks")
@export_range(0, 100, 1)
var qi_deviation_risk: int = 0
@export_range(0, 100, 1)
var breakthrough_modifier: int = 0

# --- Elemental/Other Affinities ---
@export_category("Affinities")
@export var elemental_affinity: Dictionary = {} # e.g. { "FIRE": 80, "WATER": 20 }

# --- Utility Functions ---
func clamp_cultivation_stats() -> void:
	realm_progress = clamp(realm_progress, 0, 100)
	qi_deviation_risk = clamp(qi_deviation_risk, 0, 100)
	breakthrough_modifier = clamp(breakthrough_modifier, 0, 100)
	# For elemental_affinity, optionally clamp values 0-100 for all

# Override get_summary() for cultivators
func get_summary() -> String:
	return "%s | Realm: %s | Progress: %d%% | Lifespan: %d/%d | Qi Dev Risk: %d | Breakthrough Fail: %d" % [
		first_name + " " + last_name,
		Definitions.cultivation_realm_to_string(cultivation_realm),
		realm_progress,
		lifespan,
		qi_deviation_risk,
		breakthrough_modifier
	]

# --- How & Where to Use ---
# 1. Place this at res://scripts/data/cultivator_resource.gd
# 2. Use for any character who can cultivate (Sect Master, elders, etc.)
# 3. Reference Definitions for enums/affinities in logic/UI.
# 4. When creating Cultivators, use CharacterManager as before, but instantiate CultivatorResource.
