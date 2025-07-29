# cultivator_resource.gd
# Resource for all cultivator characters.
# Inherits CharacterResource and adds cultivation-specific data.

extends CharacterResource
class_name CultivatorResource

# --- Cultivation State ---
@export_category("Cultivation State")
# NEW: This is now a StringName ID that references a CultivationRealmResource.
@export var cultivation_realm: StringName
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
	var realm_res = CultivationManager.get_realm(cultivation_realm)
	var realm_name = realm_res.display_name if realm_res else "Unknown Realm"
	
	return "%s | Realm: %s | Progress: %d%% | Lifespan: %d | Qi Dev Risk: %d | Breakthrough Mod: %d" % [
		first_name + " " + last_name,
		realm_name,
		realm_progress,
		lifespan,
		qi_deviation_risk,
		breakthrough_modifier
	]
