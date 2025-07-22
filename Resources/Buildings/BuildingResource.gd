# BuildingResource.gd
# Base resource for all sect buildings (halls, refineries, dorms, etc)
# Easily extensible for new types, upgrades, and effects.
# Place in: res://scripts/data/building_resource.gd

extends Resource
class_name BuildingResource

# === Identification & Display ===
@export_category("Identification & Display")
@export var building_id: String = "" # Unique string ID (e.g., "training_hall_1")
@export var display_name: String = "" # Name for UI
@export var description: String = "" # Flavor/tooltip text

# === Visuals ===
@export_category("Visuals")
@export var icon: Texture2D # UI icon (set in Inspector)
@export var scene: PackedScene # Optional: for building placement in-game

# === Construction & Upgrade ===
@export_category("Construction & Upgrade")
@export var construction_cost: Dictionary = {
	"materials": 100,
	"spirit_qi": 0
} # Resource costs, extensible
@export var build_time: int = 1 # Time (ticks/days) to build
@export var required_buildings: Array[String] = [] # Building IDs required before this can be built
@export var upgrade_from_id: String = "" # ID of previous building in upgrade chain ("" if none)
@export var upgrade_to_id: String = "" # ID of next upgrade ("" if none)

# === Effects & Properties ===
@export_category("Effect & Properties")
@export var effects: Dictionary = {} 
# Example: {"training_speed_bonus": 0.1, "max_members": 5}
# Define in data, apply in gameplay logic

@export_category("Tags")
@export var tags: Array[String] = [] # For filtering, e.g., ["training", "production"]

# === Utility ===
func get_summary() -> String:
	return "[%s] %s | Cost: %s | Effects: %s" % [
		building_id,
		display_name,
		str(construction_cost),
		str(effects)
	]

# --- How & Where to Use ---
# 1. Place at res://scripts/data/building_resource.gd
# 2. Create .tres assets for each building in the Inspector.
# 3. Reference in building placement, UI, and logic systems.
# 4. Access effects/tags in simulation and UI code for modular application.
